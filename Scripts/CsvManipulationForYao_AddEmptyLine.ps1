Param([parameter(Mandatory=$true)]
    [alias("f")]
    $targetFile)

Write-Host "Attempting to import data from " $targetFile

if(!(Test-Path $targetFile)) {
    Write-Host $targetFile "does not exist! Make sure you entered the path to the file correctly."
    return
}

$raw = Import-Csv $targetFile
$contents = $raw | Where-Object { $_.MRN -ne "" }

$doubled = $contents.Clone()
$doubled.Clear()

$emptyLine = ""

for($i = 0; $i -lt $contents.Length; $i++) {

    if($contents[$i].Name -ne "") {
        $j = $i * 2
        $k = $j + 1

        if($j -lt $contents.Length) {
            $doubled[$j] = $contents[$i]
            
            if($k -lt $contents.Length) {
#                $doubled[$k] = $contents[$i]
                $doubled[$k] = $emptyLine
            }
            else {
#                $doubled += $contents[$i]
                $doubled += $emptyLine
            }
        }
        else {
            $doubled += $contents[$i]
#            $doubled += $contents[$i]
            $doubled += $emptyLine
        }

        Write-Host "Added" $contents[$i].Name "to output. Output length is now" $doubled.Length -ForegroundColor DarkGreen
    }
    else {
        Write-Host "Skipped blank row" -ForegroundColor DarkGray
    }
}

$ender = Split-Path -Leaf $targetFile
$outputFile = "Output_" + $ender

$doubled | Export-Csv -Path $outputFile -NoTypeInformation
Write-Host "Exported results to" $outputFile -ForegroundColor Cyan


Write-Host "Done!" -ForegroundColor Green