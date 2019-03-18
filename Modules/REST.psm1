###############
# REST Module #
###############

# Force TLS v1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

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
    $uriParts = @($base, $path) | foreach { $_.Trim('/') }
    $request = [System.UriBuilder]($uriParts -join '/')
    $request.Query = $params.ToString()

    return $request.Uri.ToString()
}

function Submit-GetRequest{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri,
        [Parameter(Mandatory=$false)]
        [Hashtable]$headers
    )

    Write-Verbose "Calling +[GET]+ on $uri"

    try {
        return Invoke-WebRequest -Method Get -Uri $uri -Headers $headers -ErrorAction:Stop
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
    }
    catch [Microsoft.Powershell.Commands.HttpResponseException] {
        HandleHttpResponseException($_.Exception)
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
        [Hashtable]$headers
    )

    Write-Verbose "Calling +[POST]+ on $uri`nBody:`n$body"

    try {
        return Invoke-WebRequest -Method Post -Uri $uri -Body $body -Headers $headers -ErrorAction:Stop
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
    }
    catch [Microsoft.Powershell.Commands.HttpResponseException] {
        HandleHttpResponseException($_.Exception)
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
        [Hashtable]$headers
    )
    Write-Verbose "Calling +[PUT]+ on $uri`nBody:`n$body"

    try {
        return Invoke-WebRequest -Method Put -Uri $uri -Body $body -Headers $headers -ErrorAction:Stop
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
    }
    catch [Microsoft.Powershell.Commands.HttpResponseException] {
        HandleHttpResponseException($_.Exception)
    }
}

function HandleHttpResponseException {
    [CmdletBinding()]
    param(
        [Parameter()]
        [Microsoft.Powershell.Commands.HttpResponseException]$exception
    )
    if (!$exception.Response) {
        Write-Host $exception -ForegroundColor Red
        break
    }

    $statusCode = [int]$exception.Response.StatusCode
    $statusDescription = $exception.Response.ReasonPhrase
    Write-Host -ForegroundColor:Red "HTTP Error [$statusCode]: $statusDescription"

    $lastError = $Global:Error | Select-Object -Last 1
    if ($lastError -and $lastError.ErrorDetails.Message) {
        $parsed = $lastError.ErrorDetails.Message | ConvertFrom-Json
        Write-Host "Error message:" -ForegroundColor:DarkGray
        Write-Host "`t" $parsed.Error.Message -ForegroundColor:DarkGray
    }
    break
}

function HandleWebException([System.Net.WebException]$exception) {

    if(!$exception.Response) {
        Write-Host $exception -ForegroundColor:Red
        break
    }

    $statusCode = [int]$exception.Response.StatusCode
    $statusDescription = $exception.Response.StatusDescription
    Write-Host -ForegroundColor:Red "HTTP Error [$statusCode]: $statusDescription"

    $responseStream = $null
    try {
        # Get the response body as JSON
        $responseStream = $exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $global:responseBody = $reader.ReadToEnd()

        if($global:responseBody) {
            Write-Host "Error message:" -ForegroundColor:DarkGray
            try {
                $json = $global:responseBody | ConvertFrom-JSON
                $json | ForEach-Object { Write-Host  "`t" $_.error.message -ForegroundColor:DarkGray }
            }
            catch {
                # Just output the body as raw data
                Write-Host $global:responseBody -ForegroundColor:DarkGray
            }
        }
    } finally {
        if($responseStream) {
            $responseStream.Close()
            $responseStream.Dispose()
        }
    }
    break
}
