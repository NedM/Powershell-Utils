Param([parameter(Mandatory=$true)]
    [alias("f")]
    $targetFile)

function ConvertTo-LevelUpQrCode($code){
    $qrCode = "LU02{0}030000LU" -f $code
    return $qrCode
}

Write-Host "Attempting to import data from " $targetFile

if(!(Test-Path $targetFile)) {
    Write-Host $targetFile "does not exist! Make sure you entered the path to the file correctly."
    return
}

$raw = Import-Csv $targetFile

Import-Module "C:\dev\personal\Powershell\Scripts\LevelUpApiV14Module.psm1" -force

## Constants
$posAtClientId = "ClientIdGoesHere"
$nedTestUser = "UsernameHere"
$nedTestPass = need password
$dazbogMerchantId = 5932
$dazbogBostonLocationId = 9011

#$jakesMerchantId = 2561
#$jakesLocationId = 2997

## Authenticate
$authToken = Get-LevelUpAccessToken $posAtClientId $nedTestUser $nedTestPass

Set-LevelUpAuthorizationHeader $authToken.Token

foreach($item in $raw) { 
    if(!$item) { continue }

    if(!$item.Converted) { 
        $item.Converted = ConvertTo-LevelUpQrCode $item.Code 
    } 

    $expectedLength = 32
    if($item.Converted.Length -ne $expectedLength) {
        $warnText = "Warning: {0} is not {1} characters! May be invalid" -f $item.Converted, $expectedLength
        Write-Host $warnText -ForegroundColor Cyan
    }
    
    if($item.Activated -ne "TRUE") {
        $giftCardCreditToAdd = [int]([decimal]$item.Amount * 100)
#        $amountAdded = AddGiftCardValue $jakesMerchantId $item.Converted $giftCardCreditToAdd
        $amountAdded = Add-LevelUpGiftCardValue $dazbogMerchantId $item.Converted $giftCardCreditToAdd

        if($amountAdded.added_value_amount -eq $giftCardCreditToAdd){
            $item.Activated = "TRUE"
        }
    }
}

$ender = Split-Path -Leaf $targetFile
$outputFile = "Output_" + $ender

$raw | Export-Csv -Path $outputFile -NoTypeInformation

$raw