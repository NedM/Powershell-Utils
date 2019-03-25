[cmdletbinding()]
Param(
    [parameter(Mandatory=$true)]
    [alias("f")]
    [string[]]$FileNames
    )

$format = 'yyyyMMddHHmmss'

$fileNames | ForEach-Object {
    if(-not (Test-Path -Path $_)) {
        Write-Host "Skipping $_ because it does not exist in the current directory" -ForegroundColor Yellow
        return;
    }

    if($_.Length -lt $format.Length) {
        Write-Host "Skipping $_ because the filename is too short" -ForegroundColor Red
        return;
    }

    [int64]$b = $null
    if(![int64]::TryParse($_.Substring(0, $format.Length), [ref]$b)) {
        Write-Host "Skipping $_ because the filename does not have the correct format" -ForegroundColor Red
        return;
    }

    $dateTimeUTC = (Get-Date).ToUniversalTime()
    $NewName = $dateTimeUTC.ToString($format) + $_.Substring($format.Length)
    Write-Host "Updating $_ with new name: $NewName" -ForegroundColor Green
    Rename-Item -Path $_ -NewName $NewName

    Start-Sleep 1
}