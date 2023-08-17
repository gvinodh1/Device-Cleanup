<#
  .Synopsis
    This script identifies and deletes the list of duplicate devices based on the serial number.

  .NOTES
    Name: Device Cleanup
    Version: 1.0
    Created: August, 2023
    Created By: Vinodh G gvinodh@vmware.com
    Github: https://github.com/gvinodh1/Device-Cleanup
  .Description: 
    This script identifies the list of duplicate devices to be deleted from the Workspace ONE UEM Inventory based on the serial number (excludes the recently synced device among the duplicates) 
    
    This Powershell script:
    1. Fetches the list of devices from UEM using API.
    2. Sorts the devices in ascending order based on Serial Number.
    3. Identifies the list of Duplicate devices to be deleted, excluding the recently synced device among the duplicates.
    4. Delete identified duplicates.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
    VMWARE,INC. OR CREATOR OF THE SCRIPT BE LIABLE FOR ANY CLAIM, DAMAGES OR 
    OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
    IN THE SOFTWARE.

  .REQUIREMENTS
    1. Administrator credentials (Username and Password)
    2. Tenant API Key.
    3. API URL of the tenant.
    4. Provide the path on the local machine to store the results. 
    Provide all the required details in the script below inside "double quotes"

  .Note
    RECOMMENDED TO TEST THIS SCRIPT IN UAT BEFORE EXECUTING IN PRODUCTION.
#>

##############################################################################

#Requirements
$userNameFromForm="PROVIDE_USERNAME_HERE"
$passwordFromForm="PROVIDE_PASSWORD_HERE"
$tenantAPIKeyFromForm="PROVIDE_TENANT_API_KEY"
$APIURLFromForm="PROVIDE_API_URL_HERE"
$filePath = "PROVIDE_THE_PATH_TO_STORE_RESULTS";

Function Get-BasicUserForAuth {

	Param([string]$func_username)

	$userNameWithPassword = $func_username
	$encoding = [System.Text.Encoding]::ASCII.GetBytes($userNameWithPassword)
	$encodedString = [Convert]::ToBase64String($encoding)

	Return "Basic " + $encodedString
}

Function Build-Headers {

    Param([string]$authoriztionString, [string]$tenantCode, [string]$acceptType, [string]$contentType)

    $authString = $authoriztionString
    $tcode = $tenantCode
    $accept = $acceptType
    $content = $contentType

    $header = @{"Authorization" = $authString; "aw-tenant-code" = $tcode; "Accept" = $useJSON; "Content-Type" = $useJSON}
    Return $header
}

$tenantAPIKey = $tenantAPIKeyFromForm
$userName = $userNameFromForm
$password = $passwordFromForm
$concateUserInfo = $userName + ":" + $password
$restUserName = Get-BasicUserForAuth ($concateUserInfo)
$useJSON = "application/json"
$headers = Build-Headers $restUserName $tenantAPIKey $useJSON $useJSON
$APIURL = $APIURLFromForm

#ResultFile
$ResultfileName = Get-date -Format "dd/MM/yyyy HHmmss"
$ResultFile = $filepath + "\" + $ResultfileName + ".txt"

#Get all the devices along with its last sync
#https://as2061.awmdm.com/API/mdm/devices/search?page=0
$restHost = "https://" + $APIURL;
$AllDevices = $null
$k=0
do
{
$Devices = $null
$apiPrefix = "/API/mdm/devices/search?page="+$k;
Write-Host "Getting Devices from Page: "$k -ForegroundColor Green >> $ResultFile
Write-Output "Getting Devices from Page: $k" >> $ResultFile
$postSmartGroupMethod = "Get"
$method = $postSmartGroupMethod
$uri = $restHost + $apiPrefix

$Devices = Invoke-restmethod -Uri $uri -DisableKeepAlive -Method $method -Headers $headers -ContentType "application/json";
$AllDevices += $Devices.Devices
$k++
}
while ($Devices.devices.count -eq 500)

Write-Host "Total Number of Devices in Inventory: "$AllDevices.Count -ForegroundColor Yellow
Write-Output "Total Number of Devices in Inventory: "$AllDevices.Count >> $ResultFile

#Sort the fetched list of devices based on Serial Number
$SortedDevices = $AllDevices | Sort-Object SerialNumber


#Identify the list of duplicate devices to be deleted
Write-Host "Identifying the list of Duplicate Devices to be deleted..." -ForegroundColor Green
Write-Output "Identifying the list of Duplicate Devices to be deleted..." >> $ResultFile
[array]$DuplicateDevices = $null
$i=0
for ($j=1; $j -le $SortedDevices.count; $j++)
{
    if ($SortedDevices.serialnumber[$i] -eq $SortedDevices.SerialNumber[$j])
    {
        if ($SortedDevices.lastseen[$i] -lt $SortedDevices.lastseen[$j])
        {
            $DuplicateDevices += $SortedDevices.id.value[$i]
            $i=$j
        }
        else
        {
            $DuplicateDevices += $SortedDevices.id.value[$j]
        }
    }
    else
    {
        $i=$j
    }
}


#Delete devices based on device id
#https://as1106.awmdm.com/API/mdm/devices/123
Write-Host "Total Number of Devices to be Deleted: "$DuplicateDevices.count -ForegroundColor Red
Write-Output "Total Number of Devices to be Deleted: "$DuplicateDevices.count >> $ResultFile
Write-Output "List of Devices by Device ID which will be deleted: "$DuplicateDevices >> $ResultFile

$restHost = "https://" + $APIURL;
$apiPrefix = "/API/mdm/devices/";
$postSmartGroupMethod = "DELETE"
$method = $postSmartGroupMethod

for ($i = 0; $i -lt $DuplicateDevices.count ; $i++) 
{
    $uri = $restHost + $apiPrefix + $DuplicateDevices[$i];
    Write-Host "Deleting device with ID: "$DuplicateDevices[$i] -ForegroundColor Yellow
    Write-Output "Deleting device with ID: "$DuplicateDevices[$i] >> $ResultFile
    $response = Invoke-restmethod -Uri $uri -DisableKeepAlive -Method $method -Headers $headers -ContentType "application/json";
    Write-Host "Status: $response" -ForegroundColor Red
    Write-Output "Status: $response" >> $ResultFile
}

