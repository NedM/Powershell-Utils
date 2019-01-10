[cmdletbinding()]
param ()

import-module ("{0}\..\Modules\LevelUpApiModule.psm1" -f $PSScriptRoot) -Force

$config = Get-LevelUpModuleConfig
$access_token = $config.user_access_token
$username = $config.username

if(!$access_token) {
    $psCred = $null
    if($config.username -and $config.password) {
        $psCred = [pscredential]::New($config.username,
            ($config.password | ConvertTo-SecureString))
    } else {
        $psCred = Get-Credential
    }

    $access = Get-LevelUpAccessToken -apikey $config.api_key -username $psCred.UserName -password $psCred.Password
    $access_token = $access.token
    $username = $pscred.UserName
}

if(!$access_token) { exit 1 }

$amount = Get-LevelUpGlobalCreditForUser -userAccessToken $access_token

$char = "+"
$userStr = (" {0}" -f $username)
$msg1 = " has"
$amountStr = " {0}{1} {2}" -f $amount.currency_symbol, $amount.formatted_amount, $amount.currency_code
$msg2 = " in global credit "
$bars = $char*($userStr.Length + $msg1.Length + $amountStr.Length + $msg2.Length + 2*$char.Length)
Write-Host
Write-Host $bars
Write-Host $char -NoNewline
Write-Host $userStr -ForegroundColor Cyan -NoNewline
Write-Host $msg1 -NoNewline
Write-Host $amountStr -ForegroundColor Green -NoNewline
Write-Host $msg2 -NoNewline
Write-Host $char
Write-Host $bars
