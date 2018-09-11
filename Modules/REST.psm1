###############
# REST Module #
###############

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

    Write-Verbose "Calling GET on $uri"

    try {
        return Invoke-WebRequest -Method Get -Uri $uri -Headers $headers
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
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

    Write-Verbose "Calling POST on $uri`nBody:`n$body"

    try {
        return Invoke-WebRequest -Method Post -Uri $uri -Body $body -Headers $headers
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
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
    Write-Verbose "Calling PUT on $uri`nBody:`n$body"

    try {
        return Invoke-WebRequest -Method Put -Uri $uri -Body $body -Headers $headers
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
    }
}

function HandleWebException([System.Net.WebException]$exception) {
    $statusCode = [int]$exception.Response.StatusCode
    $statusDescription = $exception.Response.StatusDescription
    Write-Host -ForegroundColor:Red "HTTP Error: $statusCode $statusDescription"

    # Get the response body as JSON
    $responseStream = $exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($responseStream)
    $global:responseBody = $reader.ReadToEnd()
    Write-Host "Error message:"
    try {
        $json = $global:responseBody | ConvertFrom-JSON
        $json | ForEach-Object { Write-Host  "    " $_.error.message }
    }
    catch {
        # Just output the body as raw data
        Write-Host -ForegroundColor:Red $global:responseBody
    }
    break
}
