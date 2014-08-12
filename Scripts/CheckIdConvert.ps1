Param(
    [parameter(Mandatory=$false)]
    [alias("i")]
    $Id,
    [parameter(Mandatory=$false)]
    [alias("n")]
    $Num)

function GetTerminalNumFromCheckId([int]$checkId) {
    return $checkId -shr 20
}

function GetCheckNumberFromCheckId([int]$checkId) {
    return $checkId -band 0xffff
}

function GetCheckIdFromCheckNumber([int]$checkNum) {
    $terminal = $checkNum / 10000
    $check = $checkNum %= 10000
    $shifted = $terminal -shl 20 
    return $shifted + $check
}

$IdIsBlank = -not $Id
$NumIsBlank = -not $Num
$neitherSpecified = $IdIsBlank -and $NumIsBlank
$bothSpecified = (-not $IdIsBlank) -and (-not $NumIsBlank)

if($neitherSpecified -or $bothSpecified) {
    Write-Host "Usage: CheckIdConvert.ps1 [-n CheckNumber] || [-i CheckId]"
}
elseif(-not $IdIsBlank) {
    $terminal = GetTerminalNumFromCheckId($Id)
    $check = GetCheckNumberFromCheckId($Id)
    $output = $terminal * 10000 + $check
    Write-Host "Check Number:" $output
}
else {
    $output = GetCheckIdFromCheckNumber($Num)
    Write-Host "Check Id:" $output
}

return $output
