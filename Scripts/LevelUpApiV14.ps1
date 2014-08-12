## ClientIds ##
$clientId1 = "ClientIdGoesHere"
$levelUpCafeAppclientId = "ClientIdGoesHere"

$posAtClientId = "ClientIdGoesHere"
$posTeamAppClientId = "ClientIdGoesHere"

## QR Codes ##
$TestAccountCode = ""
$RejectsChargesOver50USD = ""
$GiftCard_DC0Usd_GC20Usd = "LU020017VB0EGFEKQPDIC587030000LU"
$GiftCard_DC0Usd_GC15Usd_NLA = "LU020014IWO0D5K957TSZWP9030000LU" #"NLA" = "No Linked Payment Account"
$GiftCard_DC9Usd_GC10Usd_NLA = "LU020014IVMI0S4BMPDE0JCO030000LU"
$NedsTestCode = "" #(rejects charges over $10)

$apiKey = $posAtClientId
$pos_username = "username"
$pos_password = need a password
$ned_test_user = "username"
$ned_test_pass = need a password

## Sandbox ##
$ned_sandbox_apikey = "ClientIdGoesHere"
$ned_sandbox_user = "Username"
$ned_sandbox_pass = need a password

$testSpendAmount = 10

Import-Module "C:\dev\levelup\API-Csharp-SDK\Powershell\LevelUpApiV14Module.psm1" -Force

## Get Access Token
$accessToken = Get-LevelUpAccessToken $posAtClientId $pos_username $pos_password

Set-LevelUpAuthorizationHeader $accessToken.token

## Get Locations
$locations = Get-LevelUpMerchantLocations $accessToken.merchant_id
$location = $locations[0].location
$locationId = $location.id

# Get Merchant Funded Credit
$credit = Get-LevelUpMerchantCredit $locationId $TestAccountCode

$addGiftCredit = $false
$giftCardCreditToAdd = 1000
if($credit.gift_card_amount -eq 0 -and $addGiftCredit) {
    $valueAdded = Add-LevelUpGiftCardValue $accessToken.merchant_id $TestAccountCode $giftCardCreditToAdd

    # Get Merchant Funded Credit
    $credit = Get-LevelUpMerchantCredit $locationId $TestAccountCode
}

$destroyGiftCredit = $true
if($credit.gift_card_amount -gt 0 -and $destroyGiftCredit) {
    $valueDestroyed = Remove-LevelUpGiftCardValue $accessToken.merchant_id $NedsTestCode $giftCardCreditToAdd

    $credit = Get-LevelUpMerchantCredit $locationId $TestAccountCode
}

## Place Order
$useGiftCards = $false
$partialAuthEnabled = $true
if($useGiftCards){
    $orderResponse = Submit-LevelUpOrder $locationId $TestAccountCode $testSpendAmount $credit.discount_amount $credit.gift_card_amount $partialAuthEnabled
} else {
    $orderResponse = Submit-LevelUpOrder $locationId $TestAccountCode $testSpendAmount $credit.discount_amount $null $partialAuthEnabled
}

$orderId = $orderResponse.uuid

## Get Order Details
$detailsResponse = Get-LevelUpOrderDetailsForMerchant $accessToken.merchant_id $orderId

## Refund Order
$refundResponse = Undo-LevelUpOrder $orderId

## Get Order Details again
$detailsResponse = Get-LevelUpOrderDetailsForMerchant $accessToken.merchant_id $orderId

## Get Orders by Location
$orders = Get-LevelUpOrdersByLocation $locationId