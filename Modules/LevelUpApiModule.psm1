[cmdletbinding()]
## PowerShell module for LevelUp API
## Copyright(c) 2016 SCVNGR, Inc. d/b/a LevelUp. All rights reserved.

## Base Uris ##
$productionBaseURI = "https://api.thelevelup.com/"
$stagingBaseURI = "https://api.staging-levelup.com/"
$sandboxBaseURI = "https://sandbox.thelevelup.com/"

#################
## LEVELUP API ##
#################

$v13 = "v13/"
$v14 = "v14/"
$v15 = "v15/"

$global:ver = $v14
$global:baseURI = $productionBaseURI
$global:uri = $global:baseURI + $global:ver

# Common HTTP Headers not including Authorization Header
$commonHeaders = @{"Content-Type" = "application/json"; "Accept" = "application/json"}

# Store the merchant access token here
$Script:merchantAccessToken = ''

$environments = @{"production" = $productionBaseURI; "sandbox" = $sandboxBaseURI; "staging" = $stagingBaseURI }

## Manage Environment ##
function Get-LevelUpEnvironment() {
    return $global:uri
}

function Set-LevelUpEnvironment([string]$envName) {
    Set-LevelUpEnvironment $envName 14
}

function Set-LevelUpEnvironment([string]$envName, [int]$version) {
    $global:ver = $v14

    if(!$environments.Contains($envName.ToLower())){
        Write-Host "WARNING: Invalid entry! Please choose one of the following: " $environments.Keys        

        $global:baseURI = $envName
    } else {
        $global:baseURI = $environments[$envName.ToLower()]
    }

    if($version -eq 15) {
        $global:ver = $v15
    }
        
    $global:uri = $global:baseURI + $global:ver

    Write-Host "Set environment: " $global:uri
}

#####################
# LevelUp API Calls #
#####################

## Authenticate ##
function Get-LevelUpAccessToken([string]$apikey, [string]$username, [string]$password) {
    $tokenRequest = @{ "access_token" = @{ "client_id" = $apikey; "username" = $username; "password" = $password } }

    $body = $tokenRequest | ConvertTo-Json

    $theURI = $global:uri + "access_tokens"

    $response = Submit-PostRequest -uri $theURI -body $body -headers $commonHeaders

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.access_token
}

# Add Authorization header to common headers and return new headers
function Add-LevelUpAuthorizationHeader([string]$token, $headers = $commonHeaders) {

    $authKey = "Authorization"
    $tokenString = "token"

    $newHeaders = @{}
    if ($headers -ne $null) {
        $newHeaders += $headers
    }

    if($newHeaders.ContainsKey($authKey)) {
        $newHeaders[$authKey] = "$tokenString $token"
    } else {
        $newHeaders.Add($authKey, "$tokenString $token")
    }
    $newHeaders
}

# Set the LevelUp acceess token value used within the Authorization Header
function Set-LevelUpAccessToken([string]$token) {
    $Script:merchantAccessToken = $token
}

## Get Merchant Locations ##
function Get-LevelUpMerchantLocations([int]$merchantId) {
    $theURI = $global:uri + "merchants/$merchantId/locations"

    $response = Submit-GetRequest $theURI $merchantAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed
}

function Get-LevelUpManagedLocations() {
    $theUri = $global:baseURI + $v15 + "managed_locations"

    $response = Submit-GetRequest -uri $theUri -accessToken "merchant=$merchantAccessToken" -headers $commonHeaders

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed
}

function Get-LevelUpLocationDetails([int]$locationId) {
    $theUri = $global:uri + "locations/$locationId"

    $response = Submit-GetRequest -uri $theUri -headers $commonHeaders

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed
}

## Create Proposed Order ##
function Submit-LevelUpProposedOrder {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [Parameter(Mandatory=$true)]
        [string]$qrCode,
        [Parameter(Mandatory=$true)]
        [int]$spendAmount,
        [int]$taxAmount=0,
        [bool]$partialAuthAllowed=$true
    )

    $theURI = $global:baseURI + $v15 + "proposed_orders"

    $proposed_order = @{
      "proposed_order" = @{
        "location_id" = $locationId;
        "payment_token_data" = $qrCode;
        "spend_amount" = $spendAmount;
        "tax_amount" = $taxAmount;
        "identifier_from_merchant" = "Check #TEST";
        "cashier" = "LevelUp Powershell Script";
        "register" = "3.14159";
        "partial_authorization_allowed" = $partialAuthAllowed;
        "items" = Get-LevelUpSampleItemList;
      }
    }

    $body = $proposed_order | ConvertTo-Json -Depth 5

    $accessToken = "merchant=" + $merchantAccessToken

    $response = Submit-PostRequest $theURI $body $accessToken
    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.proposed_order
}

## Complete Order **
function Submit-LevelUpCompleteOrder {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$locationId,

        [Parameter(Mandatory=$true)]
        [string]$qrCode,

        [Parameter(Mandatory = $true)]
        [int]$spendAmount,

        [Parameter(Mandatory=$true)]
        [string]$proposedOrderUuid,

        [Nullable[int]]$appliedDiscount=$null,

        [int]$taxAmount=0,

        [bool]$partialAuthAllowed=$true,

        [int]$exemptionAmount=0
    )

    $theURI = $global:baseURI + $v15 + "completed_orders"

    $completed_order = @{
      "completed_order" = @{
        "location_id" = $locationId;
        "payment_token_data" = $qrCode;
        "proposed_order_uuid" = $proposedOrderUuid;
        "applied_discount_amount" = $appliedDiscount;
        "spend_amount" = $spendAmount;
        "tax_amount" = $taxAmount;
        "exemption_amount" = $exemptionAmount;
        "identifier_from_merchant" = "Check #TEST";
        "cashier" = "LevelUp Powershell Script";
        "register" = "3.14159";
        "partial_authorization_allowed" = $partialAuthAllowed;
        "items" = Get-LevelUpSampleItemList;
      }
    }

    $body = $completed_order | ConvertTo-Json -Depth 5

    $accessToken = "merchant=" + $merchantAccessToken
    $response = Submit-PostRequest $theURI $body $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

## Create Order ##
function Submit-LevelUpOrder([int]$locationId, [string]$qrCode, [int]$spendAmount) {
    return Submit-LevelUpOrder $locationId $qrCode $spendAmount $null $null
}

function Submit-LevelUpOrder([int]$locationId, [string]$qrCode, [int]$spendAmount, [Nullable[int]]$appliedDiscount) {
    return Submit-LevelUpOrder $locationId $qrCode $spendAmount $appliedDiscount $null
}

function Submit-LevelUpOrder([int]$locationId, [string]$qrCode, [int]$spendAmount, [Nullable[int]]$appliedDiscount, [Nullable[int]]$availableGiftCard) {
    return Submit-LevelUpOrder $locationId $qrCode $spendAmount $appliedDiscount $availableGiftCard $false
}

function Submit-LevelUpOrder([int]$locationId, [string]$qrCode, [int]$spendAmount, [Nullable[int]]$appliedDiscount, [Nullable[int]]$availableGiftCard, [bool]$partialAuthAllowed) {

    $theURI = $global:uri + "orders"

    $order = @{
      "order" = @{
        "location_id" = $locationId;
        "payment_token_data" = $qrCode;
        "spend_amount" = $spendAmount;
        "applied_discount_amount" = $appliedDiscount;
        "available_gift_card_amount" = $availableGiftCard;
        "identifier_from_merchant" = "Check #TEST";
        "cashier" = "LevelUp Powershell Script";
        "register" = "3.14159";
        "partial_authorization_allowed" = $partialAuthAllowed;
        "items" = Get-LevelUpSampleItemList;
      }
    }

    $body = $order | ConvertTo-Json -Depth 5

    # Access token for orders endpoint depends on API version
    $accessToken = $merchantAccessToken
    if ($ver -ne $v14) {
        $accessToken = 'merchant=' + $merchantAccessToken
    }

    $response = Submit-PostRequest $theURI $body $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

## List Orders for User ##
function Get-LevelUpOrdersForUser([string]$userAccessToken = $Script:merchantAccessToken) {
    $theURI = "{0}/apps/orders" -f ($global:baseURI + $v15)

    $response = Submit-GetRequest -accessToken "user=$userAccessToken" -uri $theURI

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

## Refund Order ##
function Undo-LevelUpOrder([string]$orderId) {
    $theURI = "{0}orders/{1}/refund" -f $global:uri, $orderId

    $refundRequest = @{"refund" = @{"manager_confirmation" = $null } }
    $body = $refundRequest | ConvertTo-Json

    # Access token for refund endpoint depends on API version
    $accessToken = $merchantAccessToken
    if ($ver -ne $v14) {
        $accessToken = "merchant=" + $merchantAccessToken
    }

    $response = Submit-PostRequest $theURI $null $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

## Gift Card Add Value ##
function Add-LevelUpGiftCardValue([int]$merchantId, [string]$qrData, [int]$amountToAdd) {

    $theUri = "{0}merchants/{1}/gift_card_value_additions" -f ($global:baseURI + $v15), $merchantId

    $addValueRequest = @{ "gift_card_value_addition" = @{ "payment_token_data" = $qrData; "value_amount" = $amountToAdd } }
    $body = $addValueRequest | ConvertTo-Json

    $response = Submit-PostRequest $theUri $body $merchantAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.gift_card_value_addition
}

## Gift Card Destroy Value ##
function Remove-LevelUpGiftCardValue([int]$merchantId, [string]$qrData, [int]$amountToDestroy) {
    $theUri = "{0}merchants/{1}/gift_card_value_removals" -f ($global:baseURI + $v15), $merchantId

    $destroyValueRequest = @{ "gift_card_value_removal" = @{ "payment_token_data" = $qrData; "value_amount" = $amountToDestroy } }
    $body = $destroyValueRequest | ConvertTo-Json

    $response = Submit-PostRequest $theUri $body $merchantAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.gift_card_value_removal
}

## Send Gift Card To  User ##
 function Create-LevelUpGiftCardOrder([int]$amount, [string]$recipientEmail, [string]$recipientName, [string]$message) {
     $theUri = "{0}users/gift_card_value_orders" -f ($global:baseURI + $v15)
 
     $createGCOrderRequest = @{
         "gift_card_value_order" = 
             @{ "value_amount" = $amount; 
                 "web_purchase" = $false;
                 "recipient_email" = $recipientEmail;
                 "recipient_message" = $message;
                 "recipient_name" = $recipientName
             }
         }
 
     $body = $createGCOrderRequest | ConvertTo-Json
      
     $response = Submit-PostRequest $theUri $body $merchantAccessToken
 
     $parsed = $response | ConvertFrom-Json
 
     return $parsed.gift_card_value_order
 }

## Detached Refund ##
function Add-LevelUpMerchantFundedCredit([int]$locationId, [string]$qrData, [int]$amountToAdd) {
    $theUri = "{0}detached_refunds" -f $global:uri

    $detachedRefundRequest = @{
        "detached_refund" = @{
            "cashier" = "LevelUp Powershell Script";
            "credit_amount" = $amountToAdd;
            "customer_facing_reason" = "Sorry about your coffee!";
            "identifier_from_merchant" = "123abc";
            "internal_reason" = "Customer did not like his coffee";
            "location_id" = $locationId;
            "manager_confirmation" = $null;
            "payment_token_data" = $qrData;
            "register" = "3"
            }
         }
    $body = $detachedRefundRequest | ConvertTo-Json

    # Access token for depends on API version
    $accessToken = $merchantAccessToken
    if ($ver -ne $v14) {
        $accessToken = "merchant=" + $merchantAccessToken
    }

    $response = Submit-PostRequest $theUri $body $accessToken

    $parsed = $response | ConvertFrom-Json

    return $parsed.detached_refund
}

## Get Available Merchant Gift Card Credit ##
function Get-LevelUpMerchantGiftCardCredit([int]$locationId, [string]$qrCode) {
    $theUri = "{0}locations/{1}/get_merchant_funded_gift_card_credit" -f ($global:baseURI+$v15), $locationId

    $merchantFundedGiftCardRequest = @{
        "get_merchant_funded_gift_card_credit" = @{
            "payment_token_data" = $qrCode
        }
    }

    $body = $merchantFundedGiftCardRequest | ConvertTo-Json

    $accessToken = "merchant=" + $merchantAccessToken

    $response = Submit-PostRequest $theUri $body $accessToken

    $parsed = $response | ConvertFrom-Json

    return $parsed.merchant_funded_gift_card_credit
}

## Get Available Merchant Credit ##
function Get-LevelUpMerchantCredit([int]$locationId, [string]$qrCode) {

    $theUri = "{0}locations/{1}/merchant_funded_credit?payment_token_data={2}" -f $global:uri, $locationId, $qrCode

    # Access token for depends on API version
    $accessToken = $merchantAccessToken
    if ($ver -ne $v14) {
        $accessToken = "merchant=" + $merchantAccessToken
    }

    $response = Submit-GetRequest $theUri $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.merchant_funded_credit
}

## Get Available Global Credit for User ##
function Get-LevelUpGlobalCreditForUser([int]$userId, [string]$userAccessToken = $Script:merchantAccessToken) { 
    # v13 only! See http://agbaber.github.io/ for documentation
    $theUri = "{0}{1}users/{2}.json?access_token={3}" -f $global:baseURI, $v13, $userId, $userAccessToken

    $response = Submit-GetRequest $theUri $userAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.user.credit
}

## Get Available Global Credit for User ##
#function Get-LevelUpGlobalCreditForUser([string]$userAccessToken = $Script:merchantAccessToken) { 
#    $theUri = "{0}users" -f ($global:baseURI + $v15)
#    $accessToken = "user=" + $userAccessToken
#    
#    $response = Submit-GetRequest $theUri $accessToken
#
#    $parsed = $response.Content | ConvertFrom-Json
#
#    return $parsed.user.global_credit_amount
#}

## Get Recent Orders At Location ##
function Get-LevelUpOrdersByLocation {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$locationId,

        [Parameter()]
        [Nullable[DateTime]]$startDate = $null,

        [Parameter()]
        [Nullable[DateTime]]$endDate = $null)

    if($startDate -and $endDate -and $endDate -lt $startDate) {
        Write-Error ("End Date: {0} cannot be prior to Start Date: {1}" -f $endDate.ToShortDateString(), $startDate.ToShortDateString())
        exit 1
    }

    # v14 only!
    $theURI = "{0}locations/{1}/orders" -f ($global:baseURI + $v14), $locationId

    $orders = New-Object System.Collections.ArrayList($null)
    $pageCounter = 0

    if(!$startDate -and !$endDate) { 
        $response = Submit-GetRequest $theURI $merchantAccessToken

        $ords = $response.Content | ConvertFrom-Json
        $orders.AddRange($ords)
        $pageCounter += 1
    } else {
      if(!$startDate) { $startDate = [DateTime]::MinValue }
      if(!$endDate) { $endDate = [DateTime]::MaxValue } 
      Write-Verbose ("Searching for orders between {0} and {1}..." -f $startDate.ToShortDateString(), $endDate.ToShortDateString())

      do {
        $response = Submit-GetRequest $theURI $merchantAccessToken
      
        if(!$response) { break; }
      
        $theURI = $null
        if($response.Headers.Link) {
          $response.Headers.Link -match '(?<=<)\S*(?=>)' | Out-Null # RegEx pattern match with lookahead and lookbehind
          if($Matches) {
            $theURI = $Matches[0]            
          }
        }
      
        $pageOrders = $response.Content | ConvertFrom-Json
        if(!$pageOrders) { break; }
        
        $earliestOrderDateOnPage = $pageOrders[-1].Order.created_at | Get-Date
        if($earliestOrderDateOnPage -gt $endDate) { continue; }

        $latestOrderDateOnPage = $pageOrders[0].Order.created_at | Get-Date
        if($latestOrderDateOnPage -lt $startDate) { break; }        
            
        if($earliestOrderDateOnPage -ge $startDate -and $latestOrderDateOnPage -le $endDate) {
          $orders.AddRange($pageOrders)
          $pageCounter += 1
          continue
        }
         
        $foundSomeOrders = $false
        foreach($order in $pageOrders) {
          $date = $order.order.created_at | Get-Date
          
          if($date -gt $endDate) { continue; }  
          if($date -lt $startDate) { break; }          
        
          $orders.Add($order) | Out-Null # Evil Powershell magic to format the arraylist properly
          $foundSomeOrders = $true
        }

        if($foundSomeOrders) { $pageCounter += 1 }

      } while($theURI)
    }

    Write-Verbose ("Found {0} orders on {1} pages" -f $orders.Count, $pageCounter)
    return $orders.ToArray()
}

## Get Order Details ##
function Get-LevelUpOrderDetailsForMerchant([int]$merchantId, [string]$orderId) {

    $theURI = "{0}merchants/{1}/orders/{2}" -f $global:uri, $merchantId, $orderId

    $response = Submit-GetRequest $theURI $merchantAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

## Get Apps Locations ##
function Get-LevelUpLocationsForApp{
[cmdletbinding()]
Param([int]$appId, [string[]]$fulfillmentTypes = @("pickup", "in_store", "delivery"), [float]$lat=42.355884, [float]$lng=-71.056926, [int]$page=0) 

    $fulfillmentTypeString = $fulfillmentTypes -join ','
    $pageString = ''
    if($page -gt 1) { $pageString = ("&page={0}" -f $page) }

    $theUri = "{0}apps/{1}/locations?fulfillment_types={2}&lat={3}&lng={4}&deduplicate=true{5}" -f $global:uri, $appId, $fulfillmentTypeString, $lat, $lng, $pageString

    $response = Submit-GetRequest -uri $theUri -headers $commonHeaders

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.location
}

#################################
# LevelUp Order Ahead API Calls #
#################################

# Get Menu
function Get-LevelUpMenu([int]$menuId) {
    $theUri = "{0}order_ahead/menus/{1}" -f ($global:baseURI+$v15), $menuId

    $response = Submit-GetRequest -uri $theUri -headers $commonHeaders

    if($response.StatusCode -eq 204) {
        return $null
    }

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.menu
}


################
# REST Methods #
################
function Submit-GetRequest{
[cmdletbinding()]
Param([string]$uri, [string]$accessToken=$null, $headers=$commonHeaders)

    $theHeaders = $headers
    # Add HTTP Authorization header if access token specified
    if ($accessToken -ne $null) {
        $theHeaders = Add-LevelUpAuthorizationHeader $accessToken $headers
    }

    Write-Verbose "Calling GET on $uri"
    try {
        return iwr -Method Get -Uri $uri -Headers $theHeaders
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
    }
}

function Submit-PostRequest{
[cmdletbinding()]
Param([string]$uri, [string]$body, [string]$accessToken=$null, $headers=$commonHeaders)

    $theHeaders = $headers
    # Add HTTP Authorization header if access token specified
    if ($accessToken -ne $null -and $accessToken.Length -gt 0) {
        $theHeaders = Add-LevelUpAuthorizationHeader $accessToken $headers
    }

    Write-Verbose "Calling POST on $uri`nBody:`n$body"
    try {
        return iwr -Method Post -Uri $uri -Body $body -Headers $theHeaders
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
    }
}

function Submit-PutRequest {
[cmdletbinding()]
Param([string]$uri, [string]$body, [string]$accessToken=$null, $headers=$commonHeaders)

    $theHeaders = $headers
    # Add HTTP Authorization header if access token specified
    if ($accessToken -ne $null) {
        $theHeaders = Add-LevelUpAuthorizationHeader $accessToken $headers
    }

    Write-Verbose "Calling PUT on $uri`nBody:`n$body"
    try {
        return iwr -Method Put -Uri $uri -Body $body -Headers $theHeaders
    }
    catch [System.Net.WebException] {
        HandleWebException($_.Exception)
    }
}

##################
# Helper Methods #
##################

function Get-LevelUpSampleItemList() {
    $item1 = Format-LevelUpItem "Sprockets" "Lovely sprockets with gravy" "Weird stuff" "4321" "1234" 0 7
    $item2 = Format-LevelUpItem "Soylent Green Eggs & Spam" "Highly processed comestibles" "Food. Or perhaps something darker..." "0101001" "55555" 100 1

    return @($item1,$item2)
}

function Format-LevelUpItem([string]$name, [string]$description, [string]$category, [string]$upc, [string]$sku, [int]$chargedPriceAmount, [int]$quantity = 1) {
    $item = @{
      "item" = @{
        "name" = $name;
        "description" = $description;
        "category" = $category;
        "upc" = $upc;
        "sku" = $sku;        
        "charged_price_amount" = $chargedPriceAmount;
        "quantity" = $quantity;
      }
    }

    return $item;
}

function Redact-LevelUpQrCode([string]$qrCode) {
    $startIndex = 11
    $tokenLength = 13

    if($qrCode.Length -le ($startIndex + $tokenLength)){
        return $qrCode
    } else {
        return $qrCode.Replace($qrCode.Substring($startIndex, $tokenLength), "[** Redacted **]")
    }
}

function HandleWebException([System.Net.WebException]$exception) {
    $statusCode = [int]$exception.Response.StatusCode
    $statusDescription = $exception.Response.StatusDescription
    Write-Host -ForegroundColor:Red "HTTP Error: $statusCode $statusDescription"

    # Get the response body as JSON
    $responseStream = $exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($responseStream)
    $global:responseBody = $reader.ReadToEnd()
    Write-Host "Error message:"
    try {
        $json = $global:responseBody | ConvertFrom-JSON
        $json | ForEach-Object { Write-Host  "    " $_.error.message }
    }
    catch {
        # Just output the body as raw data
        Write-Host -ForegroundColor:Red $global:responseBody
    }
    break
}