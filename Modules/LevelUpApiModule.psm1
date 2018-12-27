﻿[cmdletbinding()]
## PowerShell module for LevelUp API
## Copyright(c) 2016 SCVNGR, Inc. d/b/a LevelUp. All rights reserved.

## Config ##
$Script:pathToConfig = ("{0}\LevelUpConfig.json" -f $PSScriptRoot)

## Base Uris ##
$localhostURI = "http://localhost:5001/"
$productionBaseURI = "https://api.thelevelup.com/"
$stagingBaseURI = "https://api.staging-levelup.com/"
$sandboxBaseURI = "https://sandbox.thelevelup.com/"

#################
## LEVELUP API ##
#################

# Force TLS v1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$v13 = "v13/"
$v14 = "v14/"
$v15 = "v15/"

$global:ver = $v15
$global:baseURI = $productionBaseURI
$global:uri = $global:baseURI + $global:ver

# Common HTTP Headers not including Authorization Header
$commonHeaders = @{"Content-Type" = "application/json"; "Accept" = "application/json"}

# Store the merchant access token here
$Script:merchantAccessToken = ''
$Script:apiKey = ''
$Script:username = ''
$Script:password = ''
$Script:environment = ''
[int]$Script:version = ''
$Script:allowed_fulfillment_types = @('in_store', 'pickup', 'delivery')

$environments = @{
    "localhost" = $localhostURI;
    "production" = $productionBaseURI;
    "sandbox" = $sandboxBaseURI;
    "staging" = $stagingBaseURI
}

Import-Module $PSScriptRoot\JsonFileOperations.psm1 -force

## Read config file ##
function Get-LevelUpModuleConfig {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [Alias('p')]
        [string]$pathToConfig = $Script:pathToConfig,
        [Parameter(Mandatory = $false)]
        [Alias('e')]
        [string]$environment
    )

    $config = $null

    Write-Verbose "Attempting to read config at $pathToConfig..."

    if(Test-Path $pathToConfig) {
        $config = Read-JsonFile -path $pathToConfig

        if($environment) {
            $environment = $environment.ToLower()
            Write-Verbose "Reading config for $environment..."

            $config = $config | select-object -property $environment -ExpandProperty $environment
        }
    } else {
        Write-Host "Failed to find a config file at $pathToConfig!" -ForegroundColor Yellow
    }

    if(!$config.api_key) { $config.Add('api_key', (Read-Host -Prompt 'Api Key')) }
    if(!$config.username) { $config.Add('username', (Read-Host -Prompt 'Username')) }
    if(!$config.password) { $config.Add('password', (Read-Host -Prompt 'Password' -AsSecureString)) }

    return $config
}

## Manage Environment ##
function Get-LevelUpEnvironment() {
    return $global:uri
}

function Set-LevelUpEnvironment{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$envName,
        [Parameter(Mandatory=$false)]
        [int]$version = 15
    )

    if(!$environments.Contains($envName.ToLower())){
        Write-Host ("WARNING: Invalid entry! Please choose one of the following: [{0}]" -f ($environments.Keys -join ',')) -ForegroundColor Yellow

        $global:baseURI = $envName
    } else {
        $global:baseURI = $environments[$envName.ToLower()]
    }

    if(!$global:baseURI.EndsWith('/')) {
        $global:baseURI += '/'
    }

    switch($version) {
        0 { $global:ver = $null }
        13 { $global:ver = $v13 }
        14 { $global:ver = $v14 }
        default { $global:ver = $v15 }
    }

    $global:uri = (@($global:baseURI.TrimEnd('/'), $global:ver) -join '/')

    Write-Host ("Set environment as: {0}" -f $global:uri) -ForegroundColor Cyan
}

function Load-LevelUpConfigFromFile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [Alias('p')]
        [string]$pathToConfig = $Script:pathToConfig,
        [Parameter(Mandatory = $false)]
        [Alias('e')]
        [string]$environment
    )

    $config = Get-LevelUpModuleConfig -pathToConfig $pathToConfig -environment $environment

    Load-LevelUpConfig($config)
}

function Load-LevelUpConfig {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [Alias('c')]
        $config
    )

    if(!$config) {
        $config = Get-LevelUpModuleConfig
    }

    if($config) {
        $Script:apiKey = $config.api_key
        $Script:username = $config.username
        $Script:password = $config.password
        $Script:environment = $config.environment
        $Script:version = $config.version
    }

    if(!$Script:apiKey) { $Script:apiKey = Read-Host -Prompt 'Api Key' }
    if(!$Script:username) { $Script:username = Read-Host -Prompt 'Username' }
    if(!$Script:password) { $Script:password = Read-Host -Prompt 'Password' -AsSecureString }
    if(!$Script:environment) { $Script:environment = Read-Host -Prompt 'Environment' }
    if(!$Script:version) { $Script:version = Read-Host -Prompt 'Version (14|15)' }

    Set-LevelUpEnvironment -envName $Script:environment -version $Script:version

    $access = Get-LevelUpAccessToken -apikey $Script:apiKey -username $Script:username -password $Script:password

    if(!$access) { exit 1 }

    Set-LevelUpAccessToken -token $access.Token

    Write-Host 'Done configuring LevelUp module!' -ForegroundColor Green
}

#####################
# LevelUp API Calls #
#####################

## Authenticate ##
function Get-LevelUpAccessToken {
    [cmdletbinding()]
    Param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true)]
    [string]$apikey,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true)]
    [string]$username,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true)]
    [string]$password
    )

    $tokenRequest = @{ "access_token" = @{ "client_id" = $apikey; "username" = $username; "password" = $password } }

    $body = $tokenRequest | ConvertTo-Json

    $theURI = $global:uri + "access_tokens"

    $response = Submit-PostRequest -uri $theURI -body $body -headers $commonHeaders

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.access_token
}

# Add Authorization header to common headers and return new headers
function Add-LevelUpAuthorizationHeader {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$token,
        [Parameter(Mandatory=$false)]
        [Hashtable]$headers = $commonHeaders
    )

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

    return $newHeaders
}

# Set the LevelUp acceess token value used within the Authorization Header
function Set-LevelUpAccessToken {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$token
     )
    $Script:merchantAccessToken = $token
}

## Get Merchant Locations ##
function Get-LevelUpMerchantLocations {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$merchantId
    )

    $theURI = $global:uri + "merchants/$merchantId/locations"

    $response = Submit-GetRequest $theURI $merchantAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed
}

function Get-LevelUpManagedLocations {
    [CmdletBinding()]
    Param()

    $theUri = $global:baseURI + $v15 + "managed_locations"

    $response = Submit-GetRequest -uri $theUri -accessToken "merchant=$merchantAccessToken" -headers $commonHeaders

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed
}

function Get-LevelUpLocationDetails {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$locationId
    )
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

    $response = Submit-PostRequest -uri $theURI -body $body -accessToken $accessToken
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
function Submit-LevelUpOrder {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [int]$locationId,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$qrCode,

        [Parameter(Mandatory=$false)]
        [int]$spendAmount = 1,

        [Parameter(Mandatory=$false)]
        [Nullable[int]]$appliedDiscount = $null,

        [Parameter(Mandatory=$false)]
        [Nullable[int]]$availableGiftCard = $null,

        [Parameter(Mandatory=$false)]
        [bool]$partialAuthAllowed = $false
    )
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
function Get-LevelUpOrdersForUser {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$userAccessToken = $Script:merchantAccessToken
    )
    $theURI = "{0}/apps/orders" -f ($global:baseURI + $v15)

    $response = Submit-GetRequest -accessToken "user=$userAccessToken" -uri $theURI

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

## Refund Order ##
function Undo-LevelUpOrder {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$orderId
    )
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
function Add-LevelUpGiftCardValue {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [int]$merchantId,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$qrData,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [int]$amountToAdd
    )
    $theUri = "{0}merchants/{1}/gift_card_value_additions" -f ($global:baseURI + $v15), $merchantId

    $addValueRequest = @{ "gift_card_value_addition" = @{ "payment_token_data" = $qrData; "value_amount" = $amountToAdd } }
    $body = $addValueRequest | ConvertTo-Json

    $response = Submit-PostRequest $theUri $body $merchantAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.gift_card_value_addition
}

## Gift Card Destroy Value ##
function Remove-LevelUpGiftCardValue {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [int]$merchantId,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$qrData,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [int]$amountToDestroy
    )
    $theUri = "{0}merchants/{1}/gift_card_value_removals" -f ($global:baseURI + $v15), $merchantId

    $destroyValueRequest = @{ "gift_card_value_removal" = @{ "payment_token_data" = $qrData; "value_amount" = $amountToDestroy } }
    $body = $destroyValueRequest | ConvertTo-Json

    $response = Submit-PostRequest $theUri $body $merchantAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.gift_card_value_removal
}

## Send Gift Card To  User ##
 function Create-LevelUpGiftCardOrder {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [int]$amount,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$recipientEmail,

        [Parameter(Mandatory=$false)]
        [string]$recipientName,

        [Parameter(Mandatory=$false)]
        [string]$message
    )
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
function Add-LevelUpMerchantFundedCredit {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [int]$locationId,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$qrData,

        [Parameter(Mandatory=$true)]
        [int]$amountToAdd
    )
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
function Get-LevelUpMerchantGiftCardCredit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$qrCode
    )
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
function Get-LevelUpMerchantCredit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$qrCode
    )
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
function Get-LevelUpGlobalCreditForUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$userId,
        [Parameter(Mandatory=$false)]
        [string]$userAccessToken = $Script:merchantAccessToken
    )
    # v13 only! See http://agbaber.github.io/ for documentation
    $theUri = "{0}{1}users/{2}.json?access_token={3}" -f $global:baseURI, $v13, $userId, $userAccessToken

    $response = Submit-GetRequest $theUri $userAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.user.credit
}

## Get Available Global Credit for User ##
#function Get-LevelUpGlobalCreditForUser([string]$userAccessToken = $Script:merchantAccessToken) {
#    [cmdletbinding()]
#    param(
#        [ValidateNotNullOrEmpty()]
#        [Parameter(Mandatory=$false)]
#        [string]$userAccessToken = $Script:merchantAccessToken
#    )
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
function Get-LevelUpOrderDetailsForMerchant {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$merchantId,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$orderId
    )
    $theURI = "{0}merchants/{1}/orders/{2}" -f $global:uri, $merchantId, $orderId

    $response = Submit-GetRequest $theURI $merchantAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

## Get Apps Locations ##
function Get-LevelUpLocationsForApp{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$appId,
        [Parameter(Mandatory=$false)]
        [string[]]$fulfillmentTypes = @("pickup", "in_store", "delivery"),
        [Parameter(Mandatory=$false)]
        [float]$lat=42.355884,
        [Parameter(Mandatory=$false)]
        [float]$lng=-71.056926,
        [Parameter(Mandatory=$false)]
        [int]$page=0
    )

    $fulfillmentTypeString = $fulfillmentTypes -join ','
    $pageString = ''
    if($page -gt 1) { $pageString = ("&page={0}" -f $page) }

    $theUri = "{0}apps/{1}/locations?fulfillment_types={2}&lat={3}&lng={4}&deduplicate=true{5}" -f $global:uri, $appId, $fulfillmentTypeString, $lat, $lng, $pageString

    $response = Submit-GetRequest -uri $theUri -headers $commonHeaders

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.location
}

## RECEIPT SCANS ##
# Get Receipt Deposit Location #
function Get-LevelUpReceiptScanLocation{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$userAccessToken = $Script:merchantAccessToken
    )

    $accessToken = "user={0}" -f $userAccessToken

    $theUri = "{0}receipt_scans/image_upload" -f ($global:baseURI+$v15)

    $response = Submit-GetRequest -uri $theURI -accessToken $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.receipt_scan_image_upload
}

## Upload Receipt ##
function Send-LevelUpReceiptScan{
    [cmdletbinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [int[]]$campaignIds,
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [Parameter(Mandatory=$true)]
        [string]$checkId,
        [Parameter(Mandatory=$true)]
        [int]$subtotalAmount,
        [Parameter(Mandatory=$true)]
        [string]$urlToPhoto,
        [Parameter(Mandatory=$true)]
        [string]$userAccessToken
    )

    $currentDateTime = Get-Date -format "yyyy-MM-ddTHH:mm"
    $receiptScan = @{
        'receipt_scan' = @{
            'campaign_ids' = $campaignIds;  # Campaigns must be a type that can be forwarded and active at location
            'location_id' = $locationId;  # Location must be running the campaigns specified above
            'check_identifier' = $checkId;
            'scan_reason' = 'I am making a test!';
            'receipt_at' = $currentDateTime;
            'subtotal_amount' = $subtotalAmount;
            'image_url' = $urlToPhoto;  # Url to photo on any publicly shared hosting service (e.g. dropbox, google etc.)
        }
    }

    $accessToken = "user={0}" -f $userAccessToken

    $theUri = "{0}receipt_scans" -f ($global:baseURI+$v15)

    $body = $receiptScan | ConvertTo-Json

    $response = Submit-PostRequest -uri $theURI -accessToken $accessToken -body $body

    return $response.StatusCode # HTTP status 204 [No content] indicates success
}

#################################
# LevelUp Order Ahead API Calls #
#################################

# Get Menu
function Get-LevelUpOAMenu{
    [cmdletbinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [int]$menuId
    )
    $theUri = "{0}order_ahead/menus/{1}" -f ($global:baseURI+$v15), $menuId

    $response = Submit-GetRequest -uri $theUri -headers $commonHeaders

    if($response.StatusCode -eq 204) {
        return $null
    }

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.menu
}

function Complete-LevelUpOAOrderById {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$userToken,
        [Parameter(Mandatory=$true)]
        [string]$orderUuid
    )
    return Complete-LevelUpOAOrder -userToken $userToken -url ("{0}order_ahead/order/{1}/complete" -f ($global:baseURI+$v15), $orderUuid)
}

function Complete-LevelUpOAOrder {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$userToken,
        [Parameter(Mandatory=$true)]
        [string]$url
    )
    $accessToken = ("user={0}" -f $userToken)

    $response = Submit-PostRequest -uri $url -headers $commonHeaders -body $null -accessToken $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

function Get-LevelUpOACompletedOrderStatus {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$userToken,
        [Parameter(Mandatory=$true)]
        [string]$orderUuid
    )
    return Get-LevelUpOACompletedOrderStatus -userToken $userToken -url ("{0}order_ahead/order/{1}/complete" -f ($global:baseURI+$v15), $orderUuid)
}

function Get-LevelUpOACompletedOrderStatus {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$userToken,
        [Parameter(Mandatory=$true)]
        [string]$url
    )
    $accessToken = ("user={0}" -f $userToken)

    $response = Submit-GetRequest -uri $url -headers $commonHeaders -accessToken $accessToken

    if($response.StatusCode -eq 202) {
        Write-Output 'Order still submitting...'
        return $null
    } elseif ($response.StatusCode -eq 200) {
        Write-Host 'Order submitted!' -ForegroundColor Green
    }

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

function Get-LevelUpOAProposedOrderStatusById {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$userToken,
        [Parameter(Mandatory=$true)]
        [string]$orderUuid
    )
    return Get-LevelUpOAProposedOrderStatus -userToken $userToken -url ("{0}order_ahead/order/{1}" -f ($global:baseURI+$v15), $orderUuid)
}

function Get-LevelUpOAProposedOrderStatus {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$userToken,
        [Parameter(Mandatory=$true)]
        [string]$url
    )
    $accessToken = ("user={0}" -f $userToken)

    $response = Submit-GetRequest -uri $url -headers $commonHeaders -accessToken $accessToken

    if($response.StatusCode -eq 202) {
        Write-Output 'Order still processing...'
        return $null
    } elseif ($response.StatusCode -eq 200) {
        Write-Host 'Order ready for completion!' -ForegroundColor Green
    }

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

function Get-LevelUpOAProviderInfo {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$serviceToken,
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [Parameter(Mandatory=$false)]
        [string]$fulfillmentType = 'in_store'
    )

    if(-not $Script:allowed_fulfillment_types.Contains($fulfillmentType)) {
        Write-Host ("Warning! `"{0}`" is not a valid fulfillment type. Valid types are [{1}]" -f $fulfillmentType, ($Script:allowed_fulfillment_types -join ', ')) -ForegroundColor Yellow
        Write-Host "Using fulfillment_type `"in_store`""
        $fulfillmentType = 'in_store'
    }

    $accessToken = ("service={0}" -f $serviceToken)

    $theUri = ("{0}order_ahead/locations/{1}/provider?fulfillment_type={2}" -f $global:baseURI, $locationId, $fulfillmentType)

    $response = Submit-GetRequest -uri $theUri -headers $commonHeaders -accessToken $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.location_order_provider
}

#Create order ahead order
function Start-LevelUpOAOrder {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$userToken,
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [Parameter(Mandatory=$false)]
        [string]$fulfillment = 'pickup',
        [Parameter(Mandatory=$false)]
        [string]$specialOrderInstructions = 'please place in automat',
        [Parameter(Mandatory=$false)]
        [int]$tipAmount = 2
    )
    $theUri = "{0}order_ahead/orders" -f ($global:baseURI+$v15)

    $accessToken = ("user={0}" -f $userToken)

    $fulfillment = $fulfillment.ToLowerInvariant()
    $allowedFulfillmentTypes = $Script:allowed_fulfillment_types[1..$Script:allowed_fulfillment_types.Length]

    if(-not $allowedFulfillmentTypes.Contains($fulfillment)) {
        Write-Host ("Warning! {0} is not a permitted fulfillment type. Allowed values are [{1}]" -f $fulfillment, ($allowedFulfillmentTypes -join ', '))
        $fulfillment = $allowedFulfillmentTypes[0]
    }

    $deliveryAddressId = $null

    if($fulfillment -eq 'delivery') {
        $deliveryAddressId = 17309 # 1 Federal St.
    }

    $order = @{
      'order' = @{
        'location_id' = $locationId;
        'conveyance' = @{
            'fulfillment_type' = $fulfillment;
            'desired_ready_time' = $null;  #NULL means ASAP
            'delivery_address_id' = $deliveryAddressId;
         }
         'items' = Get-LevelUpOASampleItemList;
         'special_instructions' = $specialOrderInstructions;
         'tip_amount' = $tipAmount;
      }
    }

    $body = $order | ConvertTo-Json -Depth 10

    $response = Submit-PostRequest -uri $theUri -headers $commonHeaders -body $body -accessToken $accessToken

#    if($response.StatusCode -eq 204) {
#        return $null
#    }

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}


################
# REST Methods #
################
function Submit-GetRequest{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri,
        [Parameter(Mandatory=$false)]
        [string]$accessToken=$null,
        [Parameter(Mandatory=$false)]
        [Hashtable]$headers=$commonHeaders
    )

    $theHeaders = $headers
    # Add HTTP Authorization header if access token specified
    if ($accessToken -ne $null -and $accessToken.Length -gt 0) {
        $theHeaders = Add-LevelUpAuthorizationHeader $accessToken $headers
    }

    Write-Verbose "Calling GET on $uri"
    try {
        return Invoke-WebRequest -Method Get -Uri $uri -Headers $theHeaders
    }
    catch [System.Net.WebException] {
        Write-Verbose ("++ GET ++`nUrl: {0}`n" -f $uri)
        HandleWebException($_.Exception)
    }
}

function Submit-PostRequest{
    [cmdletbinding()]
    Param(
    [Parameter(Mandatory=$true)]
        [string]$uri,
        [Parameter(Mandatory=$true)]
        [string]$body,
        [Parameter(Mandatory=$false)]
        [string]$accessToken=$null,
        [Parameter(Mandatory=$false)]
        [Hashtable]$headers=$commonHeaders
    )

    $theHeaders = $headers
    # Add HTTP Authorization header if access token specified
    if ($accessToken -ne $null -and $accessToken.Length -gt 0) {
        $theHeaders = Add-LevelUpAuthorizationHeader $accessToken $headers
    }

    Write-Verbose ("Calling POST on {0}`nBody:`n{1}`n" -f $uri, $body)
    try {
        return Invoke-WebRequest -Method Post -Uri $uri -Body $body -Headers $theHeaders
    }
    catch [System.Net.WebException] {
        Write-Verbose ("++ POST ++`nUrl: {0}`nBody:`n{1}`n" -f $uri, $body)
        HandleWebException($_.Exception)
    }
}

function Submit-PutRequest {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri,
        [Parameter(Mandatory=$true)]
        [string]$body,
        [Parameter(Mandatory=$false)]
        [string]$accessToken=$null,
        [Parameter(Mandatory=$false)]
        [Hashtable]$headers=$commonHeaders
    )

    $theHeaders = $headers
    # Add HTTP Authorization header if access token specified
    if ($accessToken -ne $null -and $accessToken.Length -gt 0) {
        $theHeaders = Add-LevelUpAuthorizationHeader $accessToken $headers
    }

    Write-Verbose ("Calling PUT on {0}`nBody:`n{1}`n" -f $uri, $body)
    try {
        return Invoke-WebRequest -Method Put -Uri $uri -Body $body -Headers $theHeaders
    }
    catch [System.Net.WebException] {
        Write-Verbose ("++ PUT ++`nUrl: {0}`nBody:`n{1}`n" -f $uri, $body)
        HandleWebException($_.Exception)
    }
}

##################
# Helper Methods #
##################

function Create-Uri {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$base,
        [Parameter(Mandatory=$false)]
        [string]$path = $null,
        [Parameter(Mandatory=$false)]
        [Hashtable]$parameters = $null
    )

    $params = ''

    if($null -ne $parameters -and $parameters.Count -gt 0) {
        $params = [System.Web.HttpUtility]::ParseQueryString([string]::Empty)
        foreach($kvp in $parameters.GetEnumerator()) {
            if($kvp.Value -is [array]) {
                foreach($val in $kvp.Value) {
                    $params.Add($kvp.Key, $val)
                }
            } else {
                $params.Add($kvp.Key, $kvp.Value)
            }
        }
    }

    $uriParts = @($base, $path) | foreach { $_.Trim('/') }
    $request = [System.UriBuilder]($uriParts -join '/')
    $request.Query = $params.ToString()

    return $request.Uri.ToString()
}

function Get-LevelUpSampleItemList() {
    $item1 = Format-LevelUpItem "Sprockets" "Lovely sprockets with gravy" "Weird stuff" "4321" "1234" 0 7
    $item2 = Format-LevelUpItem "Soylent Green Eggs & Spam" "Highly processed comestibles" "Food. Or perhaps something darker..." "0101001" "55555" 100 1

    return @($item1,$item2)
}

function Get-LevelUpOASampleItemList() {
    # $sprockets = Format-LevelUpOAItem -id 74853984 -quantity 4 -specialItemInstructions 'Roast thoroughly in the heat of active volcano. Lightly sauce on the underside.' -optionIds @(100, 92, 80)
    # $soylentEggs = Format-LevelUpOAItem -id 74853985 -quantity 2 -specialItemInstructions "I like `'em extra bouncy!" -optionIds @(78)

    # return @($sprockets, $soylentEggs)

    $cheese_steak = Format-LevelUpOAItem -id 2139027 -quantity 2 -specialItemInstructions 'Roast thoroughly in the heat of active volcano.' -optionIds $null
    $chix_pesto = Format-LevelUpOAItem -id 2139028 -quantity 1 -specialItemInstructions 'Lightly sauce on the underside during the waning moon.' -optionIds $null

    return @($cheese_steak, $chix_pesto)
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

function Format-LevelUpOAItem([int]$id, [int]$quantity, [string]$specialItemInstructions, [int[]]$optionIds) {
    $item = @{
      'item' = @{
        'id' = $id;
        'quantity' = $quantity;
        'special_instructions' = $specialItemInstructions;
      }
    }

    if ($option_ids) { $item['item'].add('option_ids', $optionIds) }

    return $item
}

function Redact-LevelUpQrCode {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$qrCode
    )
    $startIndex = 11
    $tokenLength = 13

    if($qrCode.Length -le ($startIndex + $tokenLength)){
        return $qrCode
    } else {
        return $qrCode.Replace($qrCode.Substring($startIndex, $tokenLength), "[** Redacted **]")
    }
}

function HandleWebException {
    [CmdletBinding()]
    param(
        [Parameter()]
        [System.Net.WebException]$exception
    )

    if(!$exception.Response) {
        Write-Host $exception -ForegroundColor Red
        return 1;
    }

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
        Write-Host $global:responseBody -ForegroundColor Red
    }
    break
}