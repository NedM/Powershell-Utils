$modulePath = (Join-Path -path $PSScriptRoot -ChildPath '/../modules/MbtaModule.psm1')

Import-Module $modulePath -Force
# # Route Type 0 = light rail (e.g. green line), 1 = heavy rail (Red line, orange line, blue line)
# $sort = 'sort=name'

# $routes_uri = "$mbta_api_v3_base_uri/routes?filter[type]=0,1"
# $subway_stops_uri = "$mbta_api_v3_base_uri/stops?$sort&filter[route_type]=0,1"
# #Caution: filter by route is case sensitive!
# $orange_line_stops_uri = "$mbta_api_v3_base_uri/stops?$sort&filter[route]=Orange"

# $parsed = MakeMBTARequest -uri "$mbta_api_v3_base_uri/stops" -filters 'filter[route_type]=0,1' -sort $sort

# $stops_data = $parsed.data | select -Property id,@{Name='Stop Name'; Expression={$_.attributes.name}}

# $parsed = MakeMBTARequest -uri "$mbta_api_v3_base_uri/routes" -filters 'filter[type]=0,1'

# $routes_data = $parsed.data | select -Property id,@{Name="Name"; Expression = {$_.attributes.long_name}}

# $parsed = MakeMBTARequest -uri "$mbta_api_v3_base_uri/stops" -filters 'filter[route]=Orange' -sort $sort

# $orange_line_stops_data = $parsed.data | select -Property id,@{Name = "Station Name"; Expression = {$_.attributes.name}}

Load-MbtaConfigFromFile

$predictions = Get-Predictions -routeId 'orange' -stopId 'state_street_forest_hills'
$departurePredictions = Get-DepartureTimePredictions -predictions $predictions 
$minutesAway = Convert-PredictedTimes -predictedTimes ($departurePredictions | Select-Object -ExpandProperty 'departure_time')
Write-Predictions -predictions $minutesAway -routeId 'orange' -stationId 'state_street' -directionId 'forest_hills'