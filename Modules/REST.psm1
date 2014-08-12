###############
# REST Module #
###############

function Submit-GetRequest{
[cmdletbinding()]
Param([string]$uri, $headers)
    Write-Verbose "Calling GET on $uri"
    try {
        return iwr -Method Get -Uri $uri -Headers $headers
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
    }
}

function Submit-PostRequest{
[cmdletbinding()]
Param([string]$uri, [string]$body, $headers)
    Write-Verbose "Calling POST on $uri`nBody:`n$body"
    try {
        return iwr -Method Post -Uri $uri -Body $body -Headers $headers
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
    }
}

function Submit-PutRequest{
[cmdletbinding()]
Param([string]$uri, [string]$body, $headers)
    Write-Verbose "Calling PUT on $uri`nBody:`n$body"
    try {
        return iwr -Method Put -Uri $uri -Body $body -Headers $headers
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
