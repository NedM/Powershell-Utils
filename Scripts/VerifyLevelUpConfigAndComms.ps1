[cmdletbinding()]
param()

$failLogName = "VerifyLevelUp.ERROR.log"
$successLogName = "VerifyLevelUp.SUCCESS.log" 

function WriteErrorMessage([string]$path, [System.Text.StringBuilder]$stringBuilder) {
    $message = $sb.ToString()
    Add-Content "$path\$failLogName" -Value $message
    Write-Error $message
}

# Ensure logs directory exists
$pathToLogsDir = ".\Logs"
if(!(Test-Path -Path $pathToLogsDir)) {
    New-Item -ItemType Directory -Force -Path $pathToLogsDir
}

# Get full path to logs directory
$pathToLogsDir = (Get-Item -path .\Logs).FullName

$sb = New-Object -TypeName "System.Text.StringBuilder"

# Clear out old logs
Get-ChildItem -path $pathToLogsDir -Filter "VerifyLevelUp.*.log" | Remove-Item

if($PSVersionTable.PSVersion.Major -lt 3) {
    ([void]$sb.AppendLine('Powershell version does not support ConvertFrom-Json! Please upgrade to Powershell 3.0.'))
    WriteErrorMessage -path $pathToLogsDir -message $sb.AppendLine(($PSVersionTable | Format-Table | Out-String))
    Write-Host "Powershell version info:"
    Write-Output $PSVersionTable
    Write-Host "Cannot proceed. Exiting..."
    Exit
}

$pathToConfigFile = (Get-ChildItem levelup.config -Recurse).FullName

# Verify Config File exists in the subtree
if(!$pathToConfigFile) {
    $currentDir = (get-item -Path ".\").FullName
    WriteErrorMessage -path $pathToLogsDir -message $sb.AppendLine("Failed to find LevelUp.config file in the directory sub-tree under $currentDir!")
    Exit
}

$config = Get-Content $pathToConfigFile | ConvertFrom-Json

if(!$config) {    
    WriteErrorMessage -path $pathToLogsDir -message $sb.AppendLine("Failed to read config from $pathToConfigFile!")
    Exit
}

$levelUpConfig = $config.levelup_config_data.'LevelUp.Integrations.Configuration.LevelUpData'

# Write out config data to file and output
([void]$sb.AppendLine("LevelUp config data:"))
([void]$sb.AppendLine(($levelUpConfig | Format-List | Out-String)))
Write-Host "`nLevelUp Config:"
Write-Output $levelUpConfig

# Verify Access Token is present
if(!$levelUpConfig.access_token) {
    WriteErrorMessage -path $pathToLogsDir -message $sb.AppendLine("Access token not found in $pathToConfigFile!")
    Exit
}

# Verify Merchant Id is present
if(!$levelUpConfig.merchant_id) {
    WriteErrorMessage -path $pathToLogsDir -message $sb.AppendLine("Merchant ID not found in $pathToConfigFile!")
    Exit
}

$merchantId = $levelUpConfig.merchant_id

# Verify Location Id is present
if(!$levelUpConfig.location_id) {
    WriteErrorMessage -path $pathToLogsDir -message $sb.AppendLine("Location ID not found in $pathToConfigFile!")
    Exit
}

$locId = $levelUpConfig.location_id

import-module .\LevelUpApiModule.psm1 -Force -DisableNameChecking

Set-LevelUpEnvironment "production"

Set-LevelUpAccessToken -token $levelUpConfig.access_token

try {
    # Verify we can call the LevelUp Api
    $locations = Get-LevelUpManagedLocations -merchantId $merchantId
} catch {
    ([void]$sb.AppendLine("Failed to get locations for Merchant $merchantId"))
    $ex = $_.Exception.Message
    WriteErrorMessage -path $pathToLogsDir -message $sb.AppendLine("Exception:`n`t$ex") 
    Exit
}

$locationIds = $locations | Select-Object -ExpandProperty location | Select-Object -ExpandProperty id | Sort-Object

# Verify the location id is in the list of locations managed by the merchant
if($locationIds -contains $locId) {
    $successLogPath = "$pathToLogsDir\$successLogName"
    $message = "`n!! Success !!"
    Write-Host -ForegroundColor Green $message
    
    ([void]$sb.AppendLine($message))

    $message = "Location $locId is a location managed by merchant $merchantId"
    Write-Host $message
    Add-Content -Path $successLogPath -Value $sb.AppendLine($message)
} else {    
    Write-Host -ForegroundColor Red "`n!! Error !!"    

    WriteErrorMessage -path $pathToLogsDir -message $sb.AppendLine("Location $locId does NOT appear to be a location managed by $merchantId")
}