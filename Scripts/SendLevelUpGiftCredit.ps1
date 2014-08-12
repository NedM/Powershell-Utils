Param([ValidateNotNullOrEmpty()] 
      [parameter(Mandatory=$true)]
      [alias("u")]
      [string]$user,
      [ValidateNotNullOrEmpty()]
      [parameter(Mandatory=$true)]
      [alias("p")]
      [string]$password,
      [parameter(Mandatory=$true)]
      [alias("e")]
      [string]$recipientEmail,
      [parameter(Mandatory=$true)]
      [alias("a")]
      [int]$amount,
      [parameter(Mandatory=$false)]
      [alias("m")]
      [string]$message,
      [parameter(Mandatory=$false)]
      [alias("n")]
      [string]$recipientName)

$levelupCafeClientId = "ClientIdGoesHere"

Import-Module C:\dev\personal\Powershell\Modules\LevelUpApiModule.psm1 -Force

## Get Access Token
$accessToken = Get-LevelUpAccessToken $levelupCafeClientId $user $password

if(!$accessToken) { exit 1 }

Set-LevelUpAccessToken $accessToken.token

if(-not $message) {
  $date = Get-Date
  $message = "MTG packs {0}" -f $date.ToShortDateString()
}

$amountInDollars = $amount/100
$promptMsg = "Do you want to send {0} to {1} (y/n)?" -f $amountInDollars.ToString("C2"), $recipientEmail
$answer = Read-Host -Prompt $promptMsg

if($answer.ToLowerInvariant() -eq 'y') {
    Create-LevelUpGiftCardOrder -amount $amount -recipientEmail $recipientEmail -recipientName $recipientName -message $message
} else {
    Write-Host "Aborted!"
}