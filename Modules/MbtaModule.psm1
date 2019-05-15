$Script:mbta_api_v3_base_uri = "https://api-v3.mbta.com"
$Script:apiKey = ''
$Script:defaultPathToConfig = (Join-Path -path $PSScriptRoot -ChildPath 'MbtaConfig.json')
$Script:application_vnd_api_json = 'application/vnd.api+json'
$Script:headers = @{ 'accept' = $application_vnd_api_json; 'content-type' = "$application_vnd_api_json; charset=utf8" }
$Script:routeColors = @{
    'orange' = [System.ConsoleColor]::Yellow;
    'red' = [System.ConsoleColor]::Red;
    'blue' = [System.ConsoleColor]::Blue;
    'green_b' = [System.ConsoleColor]::Green;
    'green_c' = [System.ConsoleColor]::Green;
    'green_d' = [System.ConsoleColor]::Green;
    'green_e' = [System.ConsoleColor]::Green;
}
$Script:routeIds = @{
    'orange' = 'Orange';
    'red' = 'Red';
    'blue' = 'Blue';
    'green_b' = 'Green-B';
    'green_c' = 'Green-C';
    'green_d' = 'Green-D';
    'green_e' = 'Green-E';
}
$Script:routeNames = @{
    'orange' = 'Orange Line';
    'red' = 'Red Line';
    'blue' = 'Blue Line';
    'green_b' = 'Green Line (B)';
    'green_c' = 'Green Line (C)';
    'green_d' = 'Green Line (D)';
    'green_e' = 'Green Line (E)';
}
$Script:stationNames = @{
    'downtown_crossing' = 'Downtown Crossing';
    'state_street' = 'State Street';
    'green_street' = 'Green Street';
    'forest_hills' = 'Forest Hills';
    'oak_grove' = 'Oak Grove';
    'alewife' = 'Alewife';
    'ashmont' = 'Ashmont';
    'braintree' = 'Braintree';
    'ashmont_braintree' = 'Ashmont/Braintree';
    'bowdoin' = 'Bowdoin';
    'wonderland' = 'Wonderland';
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

Import-Module (Join-Path -path $PSScriptRoot -ChildPath 'JsonFileOperations.psm1')
Import-Module (Join-Path -path $PSScriptRoot -ChildPath 'REST.psm1')

function Convert-PredictedTime {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$predictedTime
    )
    $currentTime = Get-Date
    $prediction = $predictedTime | Get-Date
    $timeAway = ($prediction - $currentTime)
    
    Write-Debug "Current Time: $currentTime`nPredicted Time: $prediction`nTime Away:$timeAway"

    return $timeAway | Select-Object -Property 'TotalMinutes'
}

function Convert-PredictedTimes {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $predictedTimes,
        [Parameter()]
        [int]$numPredictions = 5
    )
    $minutesFromNow = $predictedTimes | Select-Object -First $numPredictions | ForEach-Object { Convert-PredictedTime -predictedTime $_ }
    $minutePredictions = $minutesFromNow | Select-Object -ExpandProperty 'TotalMinutes' | ForEach-Object { [Math]::Floor($_) }

    return $minutePredictions
}

function Write-Predictions {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $predictions,
        [Parameter()]
        [string]$routeId = 'orange',
        [Parameter()]
        [string]$directionId = 'forest_hills',
        [Parameter()]
        [string]$stationId = 'state_street',
        [Parameter()]
        [bool]$isDeparture = $true
    )
    $routeName = $routeId
    $stationName = $stationId
    $directionTerminus = $directionId

    $foregroundColor = $Script:routeColors[$routeId]
    if($Script:routeNames.ContainsKey($routeId)) { $routeName = $Script:routeNames[$routeId] }
    if($Script:stationNames.ContainsKey($stationId)) { $stationName = $Script:stationNames[$stationId] }
    if($Script:stationNames.ContainsKey($directionId)) { $directionTerminus = $Script:stationNames[$directionId] }

    $arriveDepartString = 'arrive at'
    if($isDeparture) { $arriveDepartString = 'depart from' }

    Write-Host 'The next' -NoNewline
    Write-Host " $routeName " -ForegroundColor $foregroundColor -NoNewline
    Write-Host 'trains going to' -NoNewline
    Write-Host " $directionTerminus " -NoNewline -ForegroundColor Cyan
    Write-Host "are predicted to $arriveDepartString" -NoNewline
    write-Host " $stationName " -NoNewline -ForegroundColor Cyan
    Write-Host 'in' -NoNewline
    write-Host (" [{0}] " -f ($predictions -join ', ')) -ForegroundColor Cyan -NoNewline
    Write-Host 'minutes'
    Write-Host 'Done' -ForegroundColor Green
}

function Get-Predictions {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$routeId,
        [Parameter(Mandatory=$true)]
        [string]$stopId,
        [Parameter()]
        $directionId = $null
    )
    $response = $null

    if($Script:routeIds.ContainsKey($routeId)) { $routeId = $Script:routeIds[$routeId] }
    if($Script:stopIds.ContainsKey($stopId)) { $stopId = $Script:stopIds[$stopId] }

    $paramMap = @{ 'filter[route]' = $routeId; 'filter[stop]' = $stopId; 'filter[direction_id]' = $directionId }
    $predictionsUrl = Create-Uri -base $Script:mbta_api_v3_base_uri -path 'predictions' -parameters $paramMap #'{0}/predictions?filter[route]={1}&filter[stop]={2}&filter[direction_id]={3}' -f $Script:mbta_api_v3_base_uri, $routeID, $stopID, $directionID

    $parsed = Request-MbtaData -uri $predictionsUrl

    if(-not $parsed) {
        Write-Error "Error getting predictions from MBTA API!"
        return $null
    } else {
        return $parsed.data
    }
}

function Get-ArrivalTimePredictions {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $predictions
    )
    if(-not $predictions) { 
        Write-Error "I HAVE NO PREDICTIONS!" 
        return $null
    }

    $arrivalTimes = $predictions | Select-Object -ExpandProperty 'attributes' | Select-Object -Property 'arrival_time'

    return $arrivalTimes
}

function Get-DepartureTimePredictions {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $predictions
    )
    if(-not $predictions) { 
        Write-Error "I HAVE NO PREDICTIONS!" 
        return $null
    }

    $departureTimes = $predictions | Select-Object -ExpandProperty 'attributes' | Select-Object -Property 'departure_time'

    return $departureTimes
}

function Load-MbtaConfigFromFile {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]$pathToConfig = $Script:defaultPathToConfig
    )
    if(-not $pathToConfig -or -not (Test-Path $pathToConfig)) {
        $pathToConfig = (Join-Path -path $PSScriptRoot -ChildPath 'MbtaConfig.json')
    }

    $config = $null

    Write-Verbose "Attempting to read config at $pathToConfig..."

    if(-not (Test-Path $pathToConfig)) {
      Write-Error "Failed to find a config file at $pathToConfig!"
      exit 1
    }
    
    $config = Read-JsonFile -path $pathToConfig

    $Script:apiKey = $config.api_key

    if(!$Script:apiKey) { Write-Error "Failed to load MBTA API key from $pathToConfig" }
}

function Request-MbtaData {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri
    )
    $response = Submit-GetRequest -uri $uri -headers $Script:headers

    if(-not $response) {
        Write-Error "Failed to GET response from $uri"
        return $null
    } else {
        $decoded = [system.text.encoding]::UTF8.GetString($response.Content)
        Write-Debug "Decoded response:`n$decoded"
        $parsed = $decoded | ConvertFrom-Json
        Write-Debug "Parsed response:`n$parsed"

        return $parsed
    }
}