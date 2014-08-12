[cmdletbinding()]
param ([ValidateNotNullOrEmpty()] 
       [parameter(Mandatory=$true)]
       [alias("u")]
       [string]$user,
       [ValidateNotNullOrEmpty()] 
       [parameter(Mandatory=$true)]
       [alias("p")]
       [string]$password
       )

import-module "C:\dev\Personal\Powershell\Modules\LevelUpApiModule.psm1" -Force

$posAtClientId = "ClientIdGoesHere"

$access = Get-LevelUpAccessToken -apikey $posAtClientId -username $user -password $password

if(!$access) { exit 1 }

Set-LevelUpAccessToken -token $access.token

$amount = Get-LevelUpGlobalCreditForUser -userId $access.user_id

$char = "+"
$userStr = " $user"
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
