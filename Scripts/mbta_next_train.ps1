$modulePath = (Join-Path -path $PSScriptRoot -ChildPath '/../Modules/MbtaModule.psm1')

Import-Module $modulePath -Force

Load-MbtaConfigFromFile

$predictions = Get-Predictions -routeId 'orange' -stopId 'state_street_forest_hills'
$departurePredictions = Get-DepartureTimePredictions -predictions $predictions
$minutesAway = Convert-PredictedTimes -predictedTimes ($departurePredictions | Select-Object -ExpandProperty 'departure_time')
Write-Predictions -predictions $minutesAway -routeId 'orange' -stationId 'state_street' -directionId 'forest_hills'