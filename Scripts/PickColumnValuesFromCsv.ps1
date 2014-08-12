Param([parameter(Mandatory=$true)]
    [alias("f")]
    $TargetFile,
    [parameter(Mandatory=$true)]
    $ColumnName)


Write-Host "Attempting to import data from " $TargetFile

if(!(Test-Path $TargetFile)) {
    Write-Host $TargetFile "does not exist! Make sure you entered the path to the file correctly."
    return
}

$columnValues = $TargetFile | Import-Csv | Select-Object -ExpandProperty $ColumnName

$joined = ([int[]]$columnValues | sort) -join ','

Write-Output ("{0}s: [$joined]" -f $ColumnName)