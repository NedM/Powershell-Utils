# Powershell HMAC SHA 256
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Alias("m")]
    [string]$message,
    [Parameter(Mandatory=$false)]
    [string]$secret
)

$hmacsha = New-Object System.Security.Cryptography.HMACSHA256
$hmacsha.key = [Text.Encoding]::ASCII.GetBytes($secret)
$signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($message))
$encoded = [Convert]::ToBase64String($signature)

write-host "Signature: "
$encoded
