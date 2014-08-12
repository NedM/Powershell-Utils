[cmdletbinding()]
param ([ValidateNotNullOrEmpty()] 
       [parameter(Mandatory=$true)]
       [alias("u")]
       [string]$user,
       [ValidateNotNullOrEmpty()]
       [parameter(Mandatory=$true)]
       [alias("p")]
       [string]$password
       )

import-module "C:\dev\Personal\Powershell\Modules\LevelUpApiModule.psm1" -Force

$apiKey = ''
$use_sandbox = $true
## Sandbox ##
$sandbox_apiKey = "ClientIdGoesHere"
## Production ##
$posAtClientId = "ClientIdGoesHere"

if($use_sandbox) {
    Set-LevelUpEnvironment -envName 'Sandbox'
    $apiKey = $sandbox_apiKey
} else {
    Set-LevelUpEnvironment -envName 'Production'
    $apiKey = $posAtClientId
}

$access = Get-LevelUpAccessToken -apikey $apiKey -username $user -password $password

if(!$access) { 
    Write-Error "Failed to get access token!"
    exit 1
}

Set-LevelUpAccessToken -token $access.Token

$locationId = Read-Host -Prompt "Enter the location ID"
$startDate = Read-Host -Prompt "Enter Start Date (YYYY/MM/DD)"
$endDate = Read-Host -Prompt "Enter End Date (YYYY/MM/DD)"

# Validate locationId & Dates
if(!$locationId) {
    Write-Error "Location Id not valid!"
    exit 1
}

if($startDate) {
    $startDate = $startDate | Get-Date
} else { $startDate = $null }

if($endDate) {
    $endDate = $endDate | Get-Date
} else { $endDate = $null }

$ordersFromLocation = Get-LevelUpOrdersByLocation -locationId $locationId -startDate $startDate -endDate $endDate -Verbose

if($ordersFromLocation -eq $null) {
    Write-Host "Encountered error while getting orders from location id $locationId!"
    exit 1
}

if($ordersFromLocation.Count -lt 1) { 
    Write-Host "Found no orders for location id $locationId"
    exit 1
}

$additionalInfo = ""
if($startDate -or $endDate) {
    $formatStr = " between {0} and {1}"
    if($startDate -and $endDate) { 
        $additionalInfo = $formatStr -f $startDate.ToShortDateString(), $endDate.ToShortDateString() 
    } elseif(!$startDate) {
        $additionalInfo = $formatStr -f [DateTime]::MinValue.ToShortDateString(), $endDate.ToShortDateString()
    } elseif(!$endDate) {
        $additionalInfo = $formatStr -f $startDate.ToShortDateString(), [DateTime]::MaxValue.ToShortDateString()
    }
}

Write-Verbose ("Found {0} orders at location id $locationId{1}" -f $ordersFromLocation.Count, $additionalInfo)
$ordersFromLocation.order | Format-Table | Write-Verbose

return $ordersFromLocation