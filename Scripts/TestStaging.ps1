[cmdletbinding()]
Param()

Import-Module "C:\dev\Personal\Powershell\Modules\LevelUpApiModule.psm1" -Force

$username = "TheUserNameGoesHere"
$clientId = "TheApiKeyGoesHere"

Set-LevelUpEnvironment -envName 'staging' -version 15
$access = Get-LevelUpAccessToken -username $username -password "*********" -apikey $clientId

if(!$access) { exit 1 }

$env = Get-LevelUpEnvironment
$theUri = "{0}apps/100/locations" -f $env

$stagingResponse = Submit-GetRequest -uri $theUri -accessToken $access.Token
$stgAppsLocs = $stagingResponse.Content | ConvertFrom-Json

Set-LevelUpEnvironment -envName 'production' -version 15
$access = Get-LevelUpAccessToken -username $username -password '********' -apikey $clientId

if(!$access) { exit 1 }

$env = Get-LevelUpEnvironment
$theUri = "{0}apps/100/locations" -f $env

$productionResponse = Submit-GetRequest -uri $theUri -accessToken $access.Token
$prodAppsLocs = $productionResponse.Content | ConvertFrom-Json

$prodAppsLocs | Format-Table @{Label = "Tips on Delivery";Expression={$_.location.accepts_tips_on_delivery}}, @{Label = "Tips on Pickup";Expression={$_.location.accepts_tips_on_pickup}},@{Label = "Tips in Store";Expression={$_.location.accepts_tips_in_store}}
$stgAppsLocs | Format-Table @{Label = "Tips on Delivery";Expression={$_.location.accepts_tips_on_delivery}}, @{Label = "Tips on Pickup";Expression={$_.location.accepts_tips_on_pickup}},@{Label = "Tips in Store";Expression={$_.location.accepts_tips_in_store}}
