###############
# REST Module #
###############

# Force TLS v1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$Script:commonHeaders = @{ 'Content-Type' = 'application/json'; Accept = 'application/json' }
function Create-Uri {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$base,
        [Parameter(Mandatory=$false)]
        [string]$path = $null,
        [Parameter(Mandatory=$false)]
        [Hashtable]$parameters = $null
    )

    $params = ''

    if($null -ne $parameters -and $parameters.Count -gt 0) {
        $params = [System.Web.HttpUtility]::ParseQueryString([string]::Empty)
        foreach($kvp in $parameters.GetEnumerator()) {
            if($kvp.Value -is [array]) {
                foreach($val in $kvp.Value) {
                    $params.Add($kvp.Key, $val)
                }
            } else {
                $params.Add($kvp.Key, $kvp.Value)
            }
        }
    }
    $uriParts = @($base, $path) | ForEach-Object { $_.Trim('/') }
    $request = [System.UriBuilder]($uriParts -join '/')
    $request.Query = $params.ToString()

    return $request.Uri.ToString()
}

function Submit-DeleteRequest {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$uri,
        [Parameter(Mandatory = $false)]
        [string]$body = $null,
        [Parameter(Mandatory = $false)]
        [Hashtable]$headers = $Script:commonHeaders
    )


    try {
        if ($body) {
            Write-Verbose "Calling +[DELETE]+ on $uri`nBody:`n$body"
            return Invoke-WebRequest -Method Delete -Uri $uri -Body $body -Headers $theHeaders
        }
        else {
            Write-Verbose "Calling +[DELETE]+ on $uri"
            return Invoke-WebRequest -Method Delete -Uri $uri -Headers $theHeaders
        }
    }
    catch {
        HandleWebRequestException($_)
    }
}

function Submit-GetRequest{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri,
        [Parameter(Mandatory=$false)]
        [Hashtable]$headers = $Script:commonHeaders
    )

    try {
        Write-Verbose "Calling +[GET]+ on $uri"
        return Invoke-WebRequest -Method Get -Uri $uri -Headers $headers -ErrorAction:Stop
    }
    catch {
        HandleWebRequestException($_)
    }
}

function Submit-PostRequest{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri,
        [Parameter(Mandatory=$true)]
        [string]$body,
        [Parameter(Mandatory=$false)]
        [Hashtable]$headers = $Script:commonHeaders
    )

    try {
        Write-Verbose "Calling +[POST]+ on $uri`nBody:`n$body"
        return Invoke-WebRequest -Method Post -Uri $uri -Body $body -Headers $headers -ErrorAction:Stop
    }
    catch {
        HandleWebRequestException($_)
    }
}

function Submit-PutRequest{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri,
        [Parameter(Mandatory=$true)]
        [string]$body,
        [Parameter(Mandatory=$false)]
        [Hashtable]$headers = $Script:commonHeaders
    )

    try {
        Write-Verbose "Calling +[PUT]+ on $uri`nBody:`n$body"
        return Invoke-WebRequest -Method Put -Uri $uri -Body $body -Headers $headers -ErrorAction:Stop
    }
    catch {
        HandleWebRequestException($_)
    }
}

function HandleWebRequestException {
    [CmdletBinding()]
    param (
        [Parameter()]
        $error
    )

    $errorDetailsLengthLimit = 300
    $response = $error.Exception | Select-Object -ExpandProperty 'Response' -ErrorAction Ignore

    if (!$response) {
        Write-Error -ErrorRecord $error
    }
    else {
        $statusCode = [int]$response.StatusCode
        $statusDescription = [string]$response.StatusCode

        if ($response.StatusDescription) {
            $statusDescription = $response.StatusDescription
        }

        Write-Host "HTTP Error [$statusCode]: $statusDescription" -ForegroundColor:Red

        $details = $error.ErrorDetails

        if ($details) {
            if ($details.Message.length -gt $errorDetailsLengthLimit) {
                Write-Host ("Error message:`n`t{0}" -f $details.Message.substring(0, $errorDetailsLengthLimit)) -ForegroundColor:White
                Write-Verbose ("Full details:`n`t{0}" -f $details)
            }
            else {
                Write-Debug "Details: $details"
                $detailsArray = $details | ConvertFrom-Json | ForEach-Object { $_.error.message }
                $joined = $detailsArray -join "`n"
                Write-Host ("Error message:`n`t{0}" -f $joined) -ForegroundColor:White
            }
        }
    }
    break
}
