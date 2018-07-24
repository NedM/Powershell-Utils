function Read-JsonFile{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [Alias('p')]
        [string]$path
    )

    Write-Debug ("Attempting to import data from {0}" -f $path)

    if(-not (Test-Path $path)) {
        Write-Error ("{0} does not exist! Cannot read from file." -f $path)
        return
    }
    
    Write-Debug ("Reading content from {0}..." -f $path)
    $fromFile = Get-Content -Path $path

    Write-Debug ('Converting from JSON...')
    $fromJson = $fromFile | ConvertFrom-Json

    return $fromJson
}

function Write-JsonFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [Alias('p')]
        [string]$path,
        [Parameter(Mandatory = $true)]
        [Alias('d')]
        [Hashtable]$data
    )

    if(Test-Path $path) {
        Write-Host ("{0} already exists!" -f $path)

        $overwrite = GetUserInputBool -prompt ("Do you want to overwrite {0}?" -f $path)

        if(-not $overwrite) { 
            Write-Debug ("Not overwriting {0}. Exiting..." -f $path)
            return; 
        }
    }

    Write-Debug ('Converting to JSON...')
    $jsonified = $data | ConvertTo-Json

    Write-Debug ("Writing JSON content to {0}..." -f $path)
    $jsonified | Out-File -FilePath $path -Force
}

function GetUserInput([string]$prompt, [string[]]$allowedResponses) {
    if(-not $allowedResponses.Contains('exit')) {
        $allowedResponses +=  @('exit')
    }

    $prompt += (" [{0}]" -f ($allowedResponses -join ', '))
    $response = ''

    do {
        $response = Read-Host -Prompt $prompt
        $response = $response.Trim().ToLowerInvariant()
    } while(-not $allowedResponses.Contains($response))

    return $response
}

function GetUserInputBool([string]$prompt) {
    $affirmativeResponses = @('yes', 'y')
    $negativeResponses = @('no', 'n')

    $response = GetUserInput -prompt $prompt -allowedResponses ($affirmativeResponses + $negativeResponses)

    if($affirmativeResponses.Contains($response)) {
        return $true
    }

    return $false
}
