[cmdletbinding()]
param([string]$resDir,
[int]$interfaceNumber)

function Copy-File($sourceFile, $destinationDir) {    
    Copy-Item -Path $sourceFile -Destination $destinationDir
    
    if(Test-Path -Path $destinationDir) {
        Write-Host -ForegroundColor Green "Copied $sourceFile to $destinationDir."
    } else {
        Write-Host -ForegroundColor Red "Failed to copy $sourceFile to $destinationDir!"
    }
}

[string[]]$filesToCopy = @( 'pmsXX.isl'; 'LevelUpSubroutines.isl')

$simDirs = @(
Join-Path -Path $resDir -ChildPath '\CAL\Win32\Files\Micros\Res\Pos\Etc';
Join-Path -Path $resDir -ChildPath '\CAL\WS5\Files\CF\Micros\Etc';
Join-Path -Path $resDir -ChildPath '\Pos\Etc';
Join-Path -Path $resDir -ChildPath 'CAL\Win32\Files\Micros\Common\Etc';
)

foreach($dir in $simDirs) {
    if(Test-Path -Path $dir) {

        $newFileName = $filesToCopy[0].Replace('XX', $interfaceNumber)
        Copy-File -sourceFile $filesToCopy[0] -destinationDir (Join-Path -Path $dir -ChildPath $newFileName)

        Copy-File -sourceFile $filesToCopy[1] -destinationDir (Join-Path -Path $dir -ChildPath $filesToCopy[1])  
    } else {
        Write-Verbose "$dir does not exist on this machine. Skipping..."
    }
}