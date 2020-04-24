
Import-Module $PSScriptRoot\JsonFileOperations.psm1 -force
Import-Module $PSScriptRoot\REST.psm1 -force

####################
# Vibes API Module #
####################

$Script:vibesBaseUrl = 'https://public-api.vibescm.com'
$Script:vibesMobileDbRoot = $null
$Script:vibesHeaders = @{ 'Content-Type' = 'application/json' }

function Create-VibesAuthenticationToken{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$username,
        [Parameter(Mandatory=$true)]
        [string]$password
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($username + ':' + $password)
    $base64encode = [Convert]::ToBase64String($bytes)
    write-verbose "Base64 encoded: $base64encode"

    return $base64encode
}

function Set-VibesCompanyKey{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$companyKey
    )
    $Script:vibesMobileDbRoot = "/companies/$companyKey/mobiledb"
    write-verbose ("Base url: {0}" -f (Create-Uri -base $Script:vibesBaseUrl -path $Script:vibesMobileDbRoot))
}

function Set-VibesAuthorizationHeader{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$authorizationToken
    )

    $Script:vibesHeaders['Authorization'] = "Basic $authorizationToken"
    write-verbose ("Headers: {0}" -f ($Script:vibesHeaders | Out-String))
}

function Get-VibesPerson{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$externalPersonId
    )
    if (!$Script:vibesHeaders['Authorization']) {
        Write-Error "Vibes authorization veader is not set!"
        exit 1
    }

    if (!$Script:vibesMobileDbRoot) {
        Write-Error "Vibes company key is not set!"
        exit 1
    }

    $uri = Create-Uri -base $Script:vibesBaseUrl -path "$Script:vibesMobileDbRoot/persons/external/$externalPersonId"

    $result = Submit-GetRequest -uri $uri -headers $Script:vibesHeaders -verbose:$VerbosePreference

    if($result.StatusCode -ne 200) { Write-Host $result }

    return $result.content | ConvertFrom-Json
}

function Find-VibesPerson{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$phoneMDN
    )
    if (!$Script:vibesHeaders['Authorization']) {
        Write-Error "Vibes authorization veader is not set!"
        exit 1
    }

    if (!$Script:vibesMobileDbRoot) {
        Write-Error "Vibes company key is not set!"
        exit 1
    }

    $query_params = @{ 'mdn' = $phoneMDN }
    $uri = Create-Uri -base $Script:vibesBaseUrl -path "$Script:vibesMobileDbRoot/persons" -parameters $query_params

    $result = Submit-GetRequest -uri $uri -headers $Script:vibesHeaders -verbose:$VerbosePreference

    if($result.StatusCode -ne 200) { Write-Host $result }

    return $result.content | ConvertFrom-Json
}


function Update-VibesPersonByKey{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$personKey,
        [Parameter(Mandatory=$true)]
        [Hashtable]$updates
    )

    if (!$Script:vibesHeaders['Authorization']) {
        Write-Error "Vibes authorization veader is not set!"
        exit 1
    }

    if (!$Script:vibesMobileDbRoot) {
        Write-Error "Vibes company key is not set!"
        exit 1
    }

    $uri = Create-Uri -base $Script:vibesBaseUrl -path "$Script:vibesMobileDbRoot/persons/$personKey"

    $body = $update | ConvertTo-Json

    $result = Submit-PutRequest -uri $uri -body $body -headers $Script:vibesHeaders -verbose:$VerbosePreference

    if($result.StatusCode -ne 200) { Write-Host $result }

    return $result.content | ConvertFrom-Json
}

function Update-VibesPersonByExternalId{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$externalPersonId,
        [Parameter(Mandatory=$true)]
        [Hashtable]$updates
    )

    if (!$Script:vibesHeaders['Authorization']) {
        Write-Error "Vibes authorization veader is not set!"
        exit 1
    }

    if (!$Script:vibesMobileDbRoot) {
        Write-Error "Vibes company key is not set!"
        exit 1
    }

    $uri = Create-Uri -base $Script:vibesBaseUrl -path "$Script:vibesMobileDbRoot/persons/external/$externalPersonId"

    $body = $update | ConvertTo-Json

    $result = Submit-PutRequest -uri $uri -body $body -headers $Script:vibesHeaders -verbose:$VerbosePreference

    if($result.StatusCode -ne 200) { Write-Host $result }

    return $result.content | ConvertFrom-Json
}
