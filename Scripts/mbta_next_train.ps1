$Script:mbta_api_v3_base_uri = "https://api-v3.mbta.com"
$Script:apiKey = "5e44686f7e394dab992135e893b8a9f4"
$application_vnd_api_json = 'application/vnd.api+json'
$Script:headers = @{ 'accept' = $application_vnd_api_json; 'content-type' = "$application_vnd_api_json; charset=utf8" }
$Script:routeIds = @{
    'orange' = 'Orange';
    'red' = 'Red';
    'blue' = 'Blue';
    'green_b' = 'Green-B';
    'green_c' = 'Green-C';
    'green_d' = 'Green-D';
    'green_e' = 'Green-E';
}
$Script:stopIds = @{
    'downtown_crossing_alewife' = 70078;
    'downtown_crossing_ashmont_braintree' = 70077;
    'downtown_crossing_forest_hills' = 70020;
    'downtown_crossing_oak_grove' = 70021;
    'stony_brook_oak_gove' = 70005;
    'stony_brook_forest_hills' = 70004;
    'state_street_oak_grove' = 70023;
    'state_street_forest_hills' = 70022;
    'state_street_bowdoin' = 70041;
    'state_street_wonderland' = 70042;
}

function MakeMBTARequest($uri, $filters, $sort) {
    if($filters -or $sort) {
        $uri += "?$sort&$filters"
    }

    $response = Invoke-WebRequest -Method Get -Uri $uri -Headers $headers
    $decoded = [system.text.encoding]::UTF8.GetString($response.Content)
    $parsed = $decoded | ConvertFrom-Json

    return $parsed
}

function GetPredictions($routeID, $stopID, $directionID = $null) {
    $response = $null
    $predictionsUrl = '{0}/predictions?filter[route]={1}&filter[stop]={2}&filter[direction_id]={3}' -f $Script:mbta_api_v3_base_uri, $routeID, $stopID, $directionID

    try {
        $response = Invoke-WebRequest -Uri $predictionsUrl -Headers $Script:headers
    } catch {
        Write-Error "Error getting predictions from MBTA API!"
        return $null
    }

    if(-not $response) { Write-Error "Response from GET to $predictionsUrl was NULL!" }

    $decoded = [System.text.encoding]::UTF8.GetString($response.Content)

    $parsed = $decoded | ConvertFrom-Json

    return $parsed.data
}

function GetArrivalTimePredictions($routeID, $stopID, $directionID = $null) {
    $predictions = GetPredictions -routeID $routeID -stopID $stopID -directionID $directionID

    if(-not $predictions) { Write-Error "I HAVE NO PREDICTIONS!" }

    $arrivalTimes = $predictions | Select-Object -ExpandProperty 'attributes' | Select-Object -Property 'arrival_time'

    return $arrivalTimes
}

function ConvertPredictedArrivalTimeToMinutesAway($arrivalPrediction) {
    $currentTime = Get-Date
    $prediction = $arrivalPrediction | Get-Date
    $timeAway = ($prediction - $currentTime)
    # Write-Debug "Predicted Time: $prediction`nCurrent Time: $currentTime`nTime Away:$timeAway"
    return $timeAway | Select-Object -Property 'TotalMinutes'
}

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

$arrivalTimes = GetArrivalTimePredictions -routeID $Script:routeIds['orange'] -stopID $Script:stopIds['state_street_forest_hills']
$minutesFromNow = $arrivalTimes | Select-Object -First 5 | ForEach-Object { ConvertPredictedArrivalTimeToMinutesAway -arrivalPrediction $_.arrival_time }
$minutePredictions = $minutesFromNow | Select-Object -ExpandProperty 'TotalMinutes' | ForEach-Object { [Math]::Floor($_) }
Write-Host 'The next' -NoNewline
Write-Host ' Orange Line ' -ForegroundColor Yellow -NoNewline
Write-Host 'trains going to' -NoNewline
Write-Host ' Forest Hills ' -NoNewline -ForegroundColor Cyan
Write-Host 'are predicted to arrive at' -NoNewline
write-Host ' State Street ' -NoNewline -ForegroundColor Cyan
Write-Host 'in' -NoNewline
write-Host (" [{0}] " -f ($minutePredictions -join ', ')) -ForegroundColor Cyan -NoNewline
Write-Host 'minutes'
Write-Host 'Done' -ForegroundColor Green