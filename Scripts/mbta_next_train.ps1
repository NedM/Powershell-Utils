$mbta_api_v3_base_uri = "https://api-v3.mbta.com"
$application_vnd_api_json = 'application/vnd.api+json'
$headers = @{ 'accept' = $application_vnd_api_json; 'content-type' = "$application_vnd_api_json; charset=utf8" }

function MakeMBTARequest($uri, $filters, $sort) {
    if($filters -or $sort) {
        $uri += "?$sort&$filters"
    }

    $response = Invoke-WebRequest -Method Get -Uri $uri -Headers $headers
    $decoded = [system.text.encoding]::UTF8.GetString($response.Content)
    $parsed = $decoded | ConvertFrom-Json

    $parsed
}

# Route Type 0 = light rail (e.g. green line), 1 = heavy rail (Red line, orange line, blue line)
$sort = 'sort=name'

$routes_uri = "$mbta_api_v3_base_uri/routes?filter[type]=0,1"
$subway_stops_uri = "$mbta_api_v3_base_uri/stops?$sort&filter[route_type]=0,1"
#Caution: filter by route is case sensitive!
$orange_line_stops_uri = "$mbta_api_v3_base_uri/stops?$sort&filter[route]=Orange"

$parsed = MakeMBTARequest -uri "$mbta_api_v3_base_uri/stops" -filters 'filter[route_type]=0,1' -sort $sort

$stops_data = $parsed.data | select -Property id,@{Name='Stop Name'; Expression={$_.attributes.name}}

$parsed = MakeMBTARequest -uri "$mbta_api_v3_base_uri/routes" -filters 'filter[type]=0,1'

$routes_data = $parsed.data | select -Property id,@{Name="Name"; Expression = {$_.attributes.long_name}}

$parsed = MakeMBTARequest -uri "$mbta_api_v3_base_uri/stops" -filters 'filter[route]=Orange' -sort $sort

$orange_line_stops_data = $parsed.data | select -Property id,@{Name = "Station Name"; Expression = {$_.attributes.name}}

Write-Host 'Done' -ForegroundColor Green