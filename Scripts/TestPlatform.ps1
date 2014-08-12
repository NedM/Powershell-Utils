[cmdletbinding()]
Param(
    [parameter(Mandatory=$false)]
    [alias("h")]
    [string]$HostName,
    [parameter(Mandatory=$false)]
    [alias("p")]
    [int]$Port,
    [switch]
    $Fiddler
    )

Import-Module "C:\dev\Personal\Powershell\Modules\LevelUpApiModule.psm1" -Force

$username = "TheUserNameGoesHere"
$clientId = "MZJXGqYU624avFfQtbGSLvCNFGUM9RuFZDURbT5yyPBQVbjueSsDpcRYKYNKMsFL"

if(!$Port) { $Port = 5001 }
if(!$HostName) { $HostName = "http://localhost" }
if($fiddler) { 
    $HostName = $HostName + ".fiddler" 
    Start-Process -FilePath 'C:\Program Files (x86)\Fiddler2\Fiddler.exe'
    sleep 3
}

$target = "{0}:{1}/" -f $HostName, $Port

Set-LevelUpEnvironment -envName $target -version 15

$access = Get-LevelUpAccessToken -username $username -password "N00dl3" -apikey $clientId

if(!$access) { exit 1 }

Write-Host $access

Set-LevelUpAccessToken -token $access.Token

$locs = Get-LevelUpManagedLocations

if(!$locs -or $locs.Count -eq 0) { exit 1 }

$msg = "Found {0} managed locations for user id {1}. Using`n{2}." -f $locs.Count, $access.user_id, $locs[0].location
Write-Host $msg

$locId = $locs[0].location.id

$qrCode = "LU020000006GEL8SF5SNSU8V030000LU"

$credit = Get-LevelUpMerchantCredit -locationId $locId -qrCode $qrCode

if($credit) { Write-Host $credit }

[int]$subTotal = 100
[int]$tax = 100
[int]$spend = $subTotal + $tax

if($credit) { 
  $discountAmount = [Math]::Min($credit.discount_amount, $subTotal)
  $giftCardAmount = [Math]::Min($spend - $discountAmount, $credit.gift_card_amount)
}

$proposeOrderResponse = Submit-LevelUpProposedOrder -locationId $locId -spendAmount $spend -taxAmount $tax -qrCode $qrCode

$completeOrderResponse = $null
if($proposeOrderResponse) {
    Write-Host $proposeOrderResponse
    $completeOrderResponse = Submit-LevelUpCompleteOrder -locationId $locId -proposedOrderUuid $proposeOrderResponse.uuid -qrCode $qrCode -spendAmount $spend -appliedDiscount $proposeOrderResponse.discount_amount -taxAmount $tax -exemptionAmount 0

    if($completeOrderResponse) {
        Write-Host $completeOrderResponse
    }
}