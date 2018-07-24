[cmdletbinding()]
param ()

import-module ("{0}\..\Modules\LevelUpApiModule.psm1" -f $PSScriptRoot) -Force

$config = Get-LevelUpModuleConfig

if($config.password.GetType().Name -eq 'SecureString') {
    $config.password = $config.password | ConvertFrom-SecureString
}

$access = Get-LevelUpAccessToken -apikey $config.api_key -username $config.username -password $config.password

if(!$access) { exit 1 }

Set-LevelUpAccessToken -token $access.token

$amount = Get-LevelUpGlobalCreditForUser -userId $access.user_id

$char = "+"
$userStr = (" {0}" -f $config.username)
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
