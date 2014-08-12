[cmdletbinding()]
Param([parameter(Mandatory=$true)]
    [alias("t")]
    $TargetLocationId,
    [parameter(Mandatory=$false)]
    [alias("a")]
    $AppId = 1,
    [parameter(Mandatory=$false)]
    [alias("e")]
    $Environment = "production")

import-module "C:\dev\Personal\Powershell\Modules\LevelUpApiModule.psm1" -Force

Set-LevelUpEnvironment -envName $Environment -version 15

$fulfillment = @("delivery", "pickup", "in_store")

for($i = 1; $i -lt 50; $i++) {   
    $locations = Get-LevelUpLocationsForApp -appId $AppId -page $i -fulfillmentTypes $fulfillment
    if($null -eq $locations -or $locations.count -eq 0) { break; }

    $locationIds = $locations | select -Property id | select -ExpandProperty id

    if($locationIds.contains($targetLocationId)) {
        Write-Host "Location id $targetLocationId found!" -ForegroundColor Green
        return $response
    }
}

Write-Host "Location id $targetLocationId NOT FOUND" -ForegroundColor Yellow