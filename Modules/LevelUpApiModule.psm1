## PowerShell module for LevelUp API
## Copyright(c) 2016 SCVNGR, Inc. d/b/a LevelUp. All rights reserved.

# Force TLS v1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$v13 = "v13/"
$v14 = "v14/"
$v15 = "v15/"

$Script:pathToConfig = ("{0}\LevelUpConfig.json" -f $PSScriptRoot)

$Script:allowed_fulfillment_types = @('in_store', 'pickup', 'delivery')
$Script:environments = @{
    localhost = "http://localhost:5001/";
    production = "https://api.thelevelup.com/";
    sandbox = "https://sandbox.thelevelup.com/";
    staging = "https://api.staging-levelup.com/"
}

$Script:ver = $v15
$Script:baseURI = $Script:environments['production']
$Script:uri = $Script:baseURI + $Script:ver

# Common HTTP Headers not including Authorization Header
$commonHeaders = @{ 'Content-Type' = 'application/json'; Accept = 'application/json' }

$Script:apiKey = ''
$Script:credentials = $null
$Script:environment = ''
$Script:merchantAccessToken = ''
$Script:serviceAccessToken = ''
$Script:userAccessToken = ''

Import-Module $PSScriptRoot\JsonFileOperations.psm1 -force

################
# LevelUp API #
###############

## Authenticate ##
function Get-LevelUpAccessToken {
    [cmdletbinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$apikey,
        [Parameter()]
        [string]$username,
        [Parameter()]
        [System.Security.SecureString]$password
    )

    $psCred = $null
    if(!$username -and !$password) {
        $psCred = Get-Credential
    } elseif(!$username) {
        $username = Read-Host -Prompt 'Username'
        $psCred = [pscredential]::New($username, $password)
    } elseif(!$password) {
        $password = Read-Host -Prompt 'Password' -AsSecureString
        $psCred = [pscredential]::new($username, $password)
    } else {
        $psCred = [pscredential]::New($username, $password)
    }

    $tokenRequest = @{
        access_token = @{
            client_id = $apikey;
            username = $psCred.username;
            password = $psCred.GetNetworkCredential().Password;
        }
    }

    $body = $tokenRequest | ConvertTo-Json

    $theURI = $Script:uri + "access_tokens"

    $response = Submit-PostRequest -uri $theURI -body $body -headers $commonHeaders

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.access_token
}

## Get Merchant Locations ##
function Get-LevelUpMerchantLocations {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$merchantId,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )

    $theURI = $Script:uri + "merchants/$merchantId/locations"

    $response = Submit-GetRequest -uri $theURI -accessToken $merchantAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed
}

function Get-LevelUpManagedLocations {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )

    $theUri = $Script:baseURI + $v15 + "managed_locations"

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
    $theUri = $Script:uri + "locations/$locationId"

    $response = Submit-GetRequest -uri $theUri -headers $commonHeaders

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed
}

## Create Proposed Order ##
function Submit-GrubHubProposedOrder {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [Parameter(Mandatory=$true)]
        [string]$userId,
        [Parameter(Mandatory=$true)]
        [int]$spendAmount,
        [Parameter()]
        [int]$taxAmount = 0,
        [Parameter()]
        [string]$fulfillmentType = 'pickup',
        [Parameter()]
        [string]$grubhubServiceAccessToken = $Script:serviceAccessToken,
        [Parameter()]
        [switch]$partialAuthAllowed
    )

    $theURI = $Script:baseURI + "grubhub/proposed_orders"

    $proposed_order = @{
        proposed_order = @{
            exemption_amount              = $exemptionAmount;
            discount_only                 = $true;
            fulfillment_type              = $fulfillmentType;
            location_id                   = $locationId;
            partial_authorization_allowed = $partialAuthAllowed.IsPresent;
            rewards_set_uuid              = $null;
            spend_amount                  = $spendAmount;
            tax_amount                    = $taxAmount;
            user_id                       = $userId;
            items                         = Get-LevelUpSampleItemList;
        }
    }

    $body = $proposed_order | ConvertTo-Json -Depth 5

    $accessToken = "service=" + $grubhubServiceAccessToken

    $response = Submit-PostRequest -uri $theURI -body $body -accessToken $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.proposed_order
}

function Submit-LevelUpProposedOrder {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [Parameter(Mandatory=$true)]
        [string]$qrCode,
        [Parameter(Mandatory=$true)]
        [int]$spendAmount,
        [Parameter()]
        [int]$taxAmount = 0,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken,
        [Parameter()]
        [switch]$partialAuthAllowed
    )

    $theURI = $Script:baseURI + $v15 + "proposed_orders"

    $proposed_order = @{
        proposed_order = @{
            cashier = 'LevelUp Powershell Script';
            exemption_amount = $exemptionAmount;
            identifier_from_merchant = 'Check # TEST # Check';
            location_id = $locationId;
            partial_authorization_allowed = $partialAuthAllowed.IsPresent;
            payment_token_data = $qrCode;
            register = '3.14159';
            spend_amount = $spendAmount;
            tax_amount = $taxAmount;
            items = Get-LevelUpSampleItemList;
        }
    }

    $body = $proposed_order | ConvertTo-Json -Depth 10

    $accessToken = "merchant=" + $merchantAccessToken

    $response = Submit-PostRequest -uri $theURI -body $body -accessToken $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.proposed_order
}

## Complete Order ##
function Submit-GrubHubCompleteOrder {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [Parameter(Mandatory=$true)]
        [string]$userId,
        [Parameter(Mandatory = $true)]
        [int]$spendAmount,
        [Parameter(Mandatory=$true)]
        [string]$proposedOrderUuid,
        [Parameter()]
        [Nullable[int]]$appliedDiscount=$null,
        [Parameter()]
        [int]$taxAmount=0,
        [Parameter()]
        [int]$exemptionAmount=0,
        [Parameter()]
        [string]$fulfillmentType='pickup',
        [Parameter()]
        [string]$grubhubServiceAccessToken = $Script:serviceAccessToken,
        [Parameter()]
        [switch]$partialAuthAllowed
    )

    $theURI = $Script:baseURI + "grubhub/completed_orders"

    $completed_order = @{
        completed_order = @{
            applied_discount_amount = $appliedDiscount;
            discount_only = $true;
            exemption_amount = $exemptionAmount;
            fulfillment_type = $fulfillmentType;
            grubhub_order_uuid = $proposedOrderUuid;
            user_id = $userId;
            location_id = $locationId;
            partial_authorization_allowed = $partialAuthAllowed.IsPresent;
            progress_only = $false;
            proposed_order_uuid = $proposedOrderUuid;
            spend_amount = $spendAmount;
            tax_amount = $taxAmount;
            items = Get-LevelUpSampleItemList;
        }
    }

    $body = $completed_order | ConvertTo-Json -Depth 5

    $accessToken = "service=" + $grubhubServiceAccessToken

    $response = Submit-PostRequest $theURI $body $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

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
        [Parameter()]
        [Nullable[int]]$appliedDiscount=$null,
        [Parameter()]
        [int]$taxAmount = 0,
        [Parameter()]
        [int]$exemptionAmount = 0,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken,
        [Parameter()]
        [switch]$partialAuthAllowed
    )

    $theURI = $Script:baseURI + $v15 + "completed_orders"

    $completed_order = @{
        completed_order = @{
            applied_discount_amount = $appliedDiscount;
            cashier = 'LevelUp Powershell Script';
            exemption_amount = $exemptionAmount;
            identifier_from_merchant = 'Check # TEST # Check';
            location_id = $locationId;
            partial_authorization_allowed = $partialAuthAllowed.IsPresent;
            payment_token_data = $qrCode;
            proposed_order_uuid = $proposedOrderUuid;
            register = '3.14159';
            spend_amount = $spendAmount;
            tax_amount = $taxAmount;
            items = Get-LevelUpSampleItemList;
        }
    }

    $body = $completed_order | ConvertTo-Json -Depth 10

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
        [Parameter()]
        [int]$spendAmount = 1,
        [Parameter()]
        [Nullable[int]]$appliedDiscount = $null,
        [Parameter()]
        [Nullable[int]]$availableGiftCard = $null,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken,
        [Parameter()]
        [switch]$partialAuthAllowed
    )

    $theURI = $Script:uri + "orders"

    $order = @{
      order = @{
        location_id = $locationId;
        payment_token_data = $qrCode;
        spend_amount = $spendAmount;
        applied_discount_amount = $appliedDiscount;
        available_gift_card_amount = $availableGiftCard;
        identifier_from_merchant = 'Check # TEST # Check';
        cashier = "LevelUp Powershell Script";
        register = "3.14159";
        partial_authorization_allowed = $partialAuthAllowed.IsPresent;
        items = Get-LevelUpSampleItemList;
      }
    }

    $body = $order | ConvertTo-Json -Depth 10

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
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )
    $theURI = "{0}/apps/orders" -f ($Script:baseURI + $v15)

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
        [string]$orderId,
        [Parameter()]
        [string]$managerConfirmation = $null,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )
    $theURI = "{0}orders/{1}/refund" -f $Script:uri, $orderId

    $refundRequest = @{ refund = @{ manager_confirmation = $managerConfirmation } }

    $body = $refundRequest | ConvertTo-Json

    # Access token for refund endpoint depends on API version
    $accessToken = $merchantAccessToken
    if ($ver -ne $v14) {
        $accessToken = "merchant=" + $merchantAccessToken
    }

    $response = Submit-PostRequest -uri $theURI -body $body -accessToken $accessToken

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
        [int]$amountToAdd,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )
    $theUri = "{0}merchants/{1}/gift_card_value_additions" -f ($Script:baseURI + $v15), $merchantId

    $addValueRequest = @{
        gift_card_value_addition = @{
            payment_token_data = $qrData;
            value_amount = $amountToAdd
        }
    }

    $body = $addValueRequest | ConvertTo-Json

    $response = Submit-PostRequest -uri $theUri -body $body -accessToken $merchantAccessToken

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
        [int]$amountToDestroy,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )
    $theUri = "{0}merchants/{1}/gift_card_value_removals" -f ($Script:baseURI + $v15), $merchantId

    $destroyValueRequest = @{
        gift_card_value_removal = @{
            payment_token_data = $qrData;
            value_amount = $amountToDestroy;
        }
    }

    $body = $destroyValueRequest | ConvertTo-Json

    $response = Submit-PostRequest -uri $theUri -body $body -accessToken $merchantAccessToken

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
        [Parameter()]
        [string]$recipientName,
        [Parameter()]
        [string]$message,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )
     $theUri = "{0}users/gift_card_value_orders" -f ($Script:baseURI + $v15)

    $createGCOrderRequest = @{
        gift_card_value_order = @{
            value_amount = $amount;
            web_purchase = $false;
            recipient_email = $recipientEmail;
            recipient_message = $message;
            recipient_name = $recipientName;
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
        [int]$amountToAdd,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )

    $theUri = "{0}detached_refunds" -f $Script:uri

    $detachedRefundRequest = @{
        detached_refund = @{
            cashier = "LevelUp Powershell Script";
            credit_amount = $amountToAdd;
            customer_facing_reason = "Sorry about your coffee!";
            identifier_from_merchant = "123abc";
            internal_reason = "Customer did not like his coffee";
            location_id = $locationId;
            manager_confirmation = $null;
            payment_token_data = $qrData;
            register = "3";
        }
    }

    $body = $detachedRefundRequest | ConvertTo-Json

    # Access token for depends on API version
    $accessToken = $merchantAccessToken
    if ($ver -ne $v14) {
        $accessToken = "merchant=" + $merchantAccessToken
    }

    $response = Submit-PostRequest -uri $theUri -body $body -accessToken $accessToken

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
        [string]$qrCode,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )
    $theUri = "{0}locations/{1}/get_merchant_funded_gift_card_credit" -f ($Script:baseURI+$v15), $locationId

    $merchantFundedGiftCardRequest = @{
        get_merchant_funded_gift_card_credit = @{
            payment_token_data = $qrCode;
        }
    }

    $body = $merchantFundedGiftCardRequest | ConvertTo-Json

    $accessToken = "merchant=" + $merchantAccessToken

    $response = Submit-PostRequest -uri $theUri -body $body -accessToken $accessToken

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
        [string]$qrCode,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )
    $theUri = "{0}locations/{1}/merchant_funded_credit?payment_token_data={2}" -f $Script:uri, $locationId, $qrCode

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
# function Get-LevelUpGlobalCreditForUser {
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory=$true)]
#         [int]$userId,
#         [Parameter(Mandatory=$false)]
#         [string]$userAccessToken = $Script:merchantAccessToken
#     )
#     # v13 only! See http://agbaber.github.io/ for documentation
#     $theUri = "{0}{1}users/{2}.json?access_token={3}" -f $Script:baseURI, $v13, $userId, $userAccessToken

#     $response = Submit-GetRequest $theUri $userAccessToken

#     $parsed = $response.Content | ConvertFrom-Json

#     return $parsed.user.credit
# }

function Get-LevelUpGlobalCreditForUser {
    [cmdletbinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )
    $theUri = "{0}users" -f ($Script:baseURI + $v15)

    $accessToken = "user=" + $userAccessToken

    $response = Submit-GetRequest $theUri $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    $cents = $parsed.user.global_credit_amount
    $props = @{
        amount = $cents;
        currency_code = 'USD';
        currency_symbol = '$';
        formatted_amount = $cents/100;
    }

    return New-Object psobject -Property $props
}

## Get Recent Orders At Location ##
function Get-LevelUpOrdersByLocation {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [Parameter()]
        [Nullable[DateTime]]$startDate = $null,
        [Parameter()]
        [Nullable[DateTime]]$endDate = $null,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )

    if($startDate -and $endDate -and $endDate -lt $startDate) {
        Write-Error ("End Date: {0} cannot be prior to Start Date: {1}" -f $endDate.ToShortDateString(), $startDate.ToShortDateString())
        exit 1
    }

    # v14 only!
    $theURI = "{0}locations/{1}/orders" -f ($Script:baseURI + $v14), $locationId

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
        [string]$orderId,
        [Parameter()]
        [string]$merchantAccessToken = $Script:merchantAccessToken
    )
    $theURI = "{0}merchants/{1}/orders/{2}" -f $Script:uri, $merchantId, $orderId

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
        [Parameter()]
        [string[]]$fulfillmentTypes = @("pickup", "in_store", "delivery"),
        [Parameter()]
        [float]$lat = 42.355884,
        [Parameter()]
        [float]$lng = -71.056926,
        [Parameter()]
        [int]$page = 0
    )

    $fulfillmentTypeString = $fulfillmentTypes -join ','
    $pageString = ''
    if($page -gt 1) { $pageString = ("&page={0}" -f $page) }

    $theUri = "{0}apps/{1}/locations?fulfillment_types={2}&lat={3}&lng={4}&deduplicate=true{5}" -f $Script:uri, $appId, $fulfillmentTypeString, $lat, $lng, $pageString

    $response = Submit-GetRequest -uri $theUri -headers $commonHeaders

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.location
}

## RECEIPT SCANS ##
# Get Receipt Deposit Location #
function Get-LevelUpReceiptScanLocation{
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]$userAccessToken = $Script:merchantAccessToken
    )

    $accessToken = "user={0}" -f $userAccessToken

    $theUri = "{0}receipt_scans/image_upload" -f ($Script:baseURI+$v15)

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
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )

    $currentDateTime = Get-Date -format "yyyy-MM-ddTHH:mm"
    $receiptScan = @{
        receipt_scan = @{
            campaign_ids = $campaignIds;  # Campaigns must be a type that can be forwarded and active at location
            location_id = $locationId;  # Location must be running the campaigns specified above
            check_identifier = $checkId;
            scan_reason = 'I am making a test!';
            receipt_at = $currentDateTime;
            subtotal_amount = $subtotalAmount;
            image_url = $urlToPhoto;  # Url to photo on any publicly shared hosting service (e.g. dropbox, google etc.)
        }
    }

    $accessToken = "user={0}" -f $userAccessToken

    $theUri = "{0}receipt_scans" -f ($Script:baseURI+$v15)

    $body = $receiptScan | ConvertTo-Json

    $response = Submit-PostRequest -uri $theURI -accessToken $accessToken -body $body

    return $response.StatusCode # HTTP status 204 [No content] indicates success
}

function Get-LevelUpSubscriptions {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )
    $theUri = "{0}subscriptions" -f ($Script:baseURI + $v15)

    $response = Submit-GetRequest -uri $theUri -headers $commonHeaders -accessToken $userAccessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.subscription
}


function New-LevelUpSubscription {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$acquisition_id,
        [Parameter()]
        [string]$provider = 'vibes',
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )
    $theUri = "{0}subscriptions" -f ($Script:baseURI + $v15)

    $subscription = @{
        'subscription' = @{
            'provider' = $provider;
            'id'       = $acquisition_id;
        }
    }

    $body = $subscription | ConvertTo-Json

    $response = Submit-PostRequest -uri $theUri -headers $commonHeaders -body $body -accessToken $userAccessToken

    return $response
}

function Remove-LevelUpSubscription {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$list_id,
        [Parameter()]
        [string]$provider = 'vibes',
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )
    $baseUri = ("{0}subscriptions/{1}" -f ($Script:baseURI + $v15), $list_id)
    $params = @{ provider = $provider; }
    $theUri = Create-Uri -base $baseUri -parameters $params

    $response = Submit-DeleteRequest -uri $theUri -headers $commonHeaders -accessToken $userAccessToken

    return $response
}

#################################
# LevelUp Order Ahead API Calls #
#################################

# Get Menu
function Get-LevelUpOAMenu {
    [cmdletbinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [int]$menuId
    )
    $theUri = "{0}order_ahead/menus/{1}" -f ($Script:baseURI+$v15), $menuId

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
        [string]$orderUuid,
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )

    $theUri = ("{0}order_ahead/order/{1}/complete" -f ($Script:baseURI+$v15), $orderUuid)

    return Complete-LevelUpOAOrder -url $theUri -userAccessToken $userAccessToken
}

function Complete-LevelUpOAOrder {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$url,
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )
    $accessToken = ("user={0}" -f $userAccessToken)

    $response = Submit-PostRequest -uri $url -headers $commonHeaders -body $null -accessToken $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.order
}

function Get-LevelUpOACompletedOrderStatusById {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$orderUuid,
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )

    $theUri = ("{0}order_ahead/order/{1}/complete" -f ($Script:baseURI+$v15), $orderUuid)

    return Get-LevelUpOACompletedOrderStatus -url $theUri -userAccessToken $userAccessToken
}

function Get-LevelUpOACompletedOrderStatus {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$url,
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )
    $accessToken = ("user={0}" -f $userAccessToken)

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
        [string]$orderUuid,
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )

    $theUri = "{0}order_ahead/order/{1}" -f ($Script:baseURI+$v15), $orderUuid

    return Get-LevelUpOAProposedOrderStatus -url $theUri -userAccessToken $userAccessToken
}

function Get-LevelUpOAProposedOrderStatus {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$url,
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )
    $accessToken = ("user={0}" -f $userAccessToken)

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
        [int]$locationId,
        [Parameter()]
        [string]$fulfillmentType = 'in_store',
        [Parameter()]
        [string]$serviceToken = $Script:serviceAccessToken
    )

    if(-not $Script:allowed_fulfillment_types.Contains($fulfillmentType)) {
        Write-Host ("Warning! `"{0}`" is not a valid fulfillment type. Valid types are [{1}]" -f $fulfillmentType, ($Script:allowed_fulfillment_types -join ', ')) -ForegroundColor Yellow
        Write-Host "Using fulfillment_type `"in_store`""
        $fulfillmentType = 'in_store'
    }

    $accessToken = ("service={0}" -f $serviceToken)

    $theUri = ("{0}order_ahead/locations/{1}/provider?fulfillment_type={2}" -f $Script:baseURI, $locationId, $fulfillmentType)

    $response = Submit-GetRequest -uri $theUri -headers $commonHeaders -accessToken $accessToken

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.location_order_provider
}

#Create order ahead order
function Start-LevelUpOAOrder {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$locationId,
        [Parameter(Mandatory=$false)]
        [string]$fulfillment = 'pickup',
        [Parameter(Mandatory=$false)]
        [string]$specialOrderInstructions = 'please place in automat',
        [Parameter(Mandatory=$false)]
        [int]$tipAmount = 2,
        [Parameter()]
        [string]$userAccessToken = $Script:userAccessToken
    )
    $theUri = "{0}order_ahead/orders" -f ($Script:baseURI+$v15)

    $accessToken = ("user={0}" -f $userAccessToken)

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
        [string]$accessToken = $null,
        [Parameter(Mandatory=$false)]
        [Hashtable]$headers = $commonHeaders
    )

    $theHeaders = $headers
    # Add HTTP Authorization header if access token specified
    if ($accessToken) {
        $theHeaders = Add-LevelUpAuthorizationHeader $accessToken $headers
    }

    Write-Verbose "Calling +[GET]+ on $uri"
    try {
        return Invoke-WebRequest -Method Get -Uri $uri -Headers $theHeaders
    }
    catch { 
        HandleWebRequestException($_) 
    }
}

function Submit-DeleteRequest {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$uri,
        [Parameter(Mandatory = $false)]
        [string]$body = $null,
        [Parameter(Mandatory = $false)]
        [string]$accessToken = $null,
        [Parameter(Mandatory = $false)]
        [Hashtable]$headers = $commonHeaders
    )

    $theHeaders = $headers
    # Add HTTP Authorization header if access token specified
    if ($accessToken) {
        $theHeaders = Add-LevelUpAuthorizationHeader $accessToken $headers
    }

    Write-Verbose ("Calling +[DELETE]+ on {0}`nBody:`n{1}`n" -f $uri, $body)
    try {
        if($body) {
            return Invoke-WebRequest -Method Delete -Uri $uri -Body $body -Headers $theHeaders
        } else {
            return Invoke-WebRequest -Method Delete -Uri $uri -Headers $theHeaders
        }
    }
    catch { 
        HandleWebRequestException($_) 
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
    if ($accessToken) {
        $theHeaders = Add-LevelUpAuthorizationHeader $accessToken $headers
    }

    Write-Verbose ("Calling +[POST]+ on {0}`nBody:`n{1}`n" -f $uri, $body)
    try {
        return Invoke-WebRequest -Method Post -Uri $uri -Body $body -Headers $theHeaders
    }
    catch { 
        HandleWebRequestException($_) 
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
    if ($accessToken) {
        $theHeaders = Add-LevelUpAuthorizationHeader $accessToken $headers
    }

    Write-Verbose ("Calling +[PUT]+ on {0}`nBody:`n{1}`n" -f $uri, $body)
    try {
        return Invoke-WebRequest -Method Put -Uri $uri -Body $body -Headers $theHeaders
    }
    catch { 
        HandleWebRequestException($_) 
    }

}

##################
# Helper Methods #
##################

# Add Authorization header to common headers and return new headers
function Add-LevelUpAuthorizationHeader {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$token,
        [Parameter()]
        [Hashtable]$headers = $commonHeaders
    )

    $authKey = "Authorization"
    $tokenString = "token"

    $newHeaders = @{}
    if ($headers) {
        $newHeaders += $headers
    }

    if($newHeaders.ContainsKey($authKey)) {
        $newHeaders[$authKey] = "$tokenString $token"
    } else {
        $newHeaders.Add($authKey, "$tokenString $token")
    }

    return $newHeaders
}

function Create-Uri {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$base,
        [Parameter()]
        [string]$path = $null,
        [Parameter()]
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

    $uriParts = @($base, $path) | ForEach-Object { $_.Trim('/') }
    $request = [System.UriBuilder]($uriParts -join '/')
    $request.Query = $params.ToString()

    return $request.Uri.ToString()
}

function Get-LevelUpSampleItemList() {
    $gravy = Format-LevelUpItem -name "Gibblet Gravy" -description "Gravy for your sprockets" -category "Sauces" -upc "111" -sku "0101" -chargedPriceAmount 50 -quantity 1 -children $null
    $item1 = Format-LevelUpItem "Sprockets" "Lovely sprockets with gravy" "Weird stuff" "4321" "1234" 999 7 -children @($gravy)
    $whupped = Format-LevelUpItem -name "Whupped Cream" -description "Cream thats been given a whuppin" -category "toppings" -upc $null -sku $null -quantity 1 -children $null -chargedPriceAmount 10
    $item2 = Format-LevelUpItem -name "Pumpkin Pie On Pumpernickel" -description "A toasty pumpernickel dessert snack" -category "desserts" -upc $null -sku $null -chargedPriceAmount 499 -quantity 1 -children @($whupped)
    $hot = Format-LevelUpItem -name "Secret Armadillo" -description "hot Hot HOT sauce!" -category "Sauces" -upc $null -sku '666' -chargedPriceAmount 0 -quantity 2 -children $null
    $soylent = Format-LevelUpItem "Soylent Green Eggs & Spam" "Highly processed comestibles" "Food. Or perhaps something darker..." "0101001" "55555" 550 1 -children @($hot)
    $bepis = Format-LevelUpItem -name "Bepis!" -description "The Thirst Quoncher!" -category "Bevs" -upc 123321 -sku 777 -chargedPriceAmount 199 -quantity 1 -children $null
    $combo = Format-LevelUpItem -name "Lunch Special" -description "C-C-C-Combo!" -category "Combos" -upc $null -sku '2' -chargedPriceAmount 0 -quantity 1 -children @($soylent, $bepis)

    return @($item1, $item2, $combo)
}

function Get-LevelUpOASampleItemList() {
    $cheese_steak = Format-LevelUpOAItem -id 2139027 -quantity 2 -specialItemInstructions 'Roast thoroughly in the heat of active volcano.' -optionIds $null
    $chix_pesto = Format-LevelUpOAItem -id 2139028 -quantity 1 -specialItemInstructions 'Lightly sauce on the underside during the waning moon.' -optionIds $null

    return @($cheese_steak, $chix_pesto)
}

function Format-LevelUpItem([string]$name, [string]$description, [string]$category, [string]$upc, [string]$sku, [int]$chargedPriceAmount, [int]$quantity = 1, [PSObject[]]$children = $null) {
    $item = @{
      "item" = @{
        "name" = $name;
        "description" = $description;
        "category" = $category;
        "children" = $children;
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

function Get-LevelUpSampleItemList() {
    $item1 = Format-LevelUpItem "Sprockets" "Lovely sprockets with gravy" "Weird stuff" "4321" "1234" 0 7
    $item2 = Format-LevelUpItem "Soylent Green Eggs & Spam" "Highly processed comestibles" "Food. Or perhaps something darker..." "0101001" "55555" 100 1

    return @($item1,$item2)
}

function Get-LevelUpOASampleItemList() {
    $cheese_steak = Format-LevelUpOAItem -id 2139027 -quantity 2 -specialItemInstructions 'Roast thoroughly in the heat of active volcano.' -optionIds $null
    $chix_pesto = Format-LevelUpOAItem -id 2139028 -quantity 1 -specialItemInstructions 'Lightly sauce on the underside during the waning moon.' -optionIds $null

    return @($cheese_steak, $chix_pesto)
}

## Read config file ##
function Get-LevelUpModuleConfig {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [Alias('e')]
        [string]$environment,
        [Parameter()]
        [Alias('p')]
        [string]$pathToConfig = $Script:pathToConfig
    )

    $config = $null

    Write-Verbose "Attempting to read config at $pathToConfig..."

    if(Test-Path $pathToConfig) {
        $config = Read-JsonFile -path $pathToConfig

        if($environment) {
            $environment = $environment.ToLower()
            Write-Verbose "Reading config for $environment..."

            $config = $config | select-object -ExpandProperty $environment
        }
    } else {
        Write-Host "Failed to find a config file at $pathToConfig!" -ForegroundColor Yellow
    }

    if(!$config.user_access_token -and !$config.merchant_access_token) {
        if(!$config.api_key) { $config | Add-Member -NotePropertyName 'api_key' -NotePropertyValue (Read-Host -Prompt 'Api Key') }
        if(!$config.username) { $config | Add-Member -NotePropertyName 'username' -NotePropertyValue (Read-Host -Prompt 'Username') }
        if(!$config.password) { $config | Add-Member -NotePropertyName 'password' -NotePropertyValue ((Read-Host -Prompt 'Password' -AsSecureString | ConvertFrom-SecureString)) }
    }

    return $config
}

function Get-LevelUpEnvironment() {
    return $Script:uri
}

# [Obsolete(@"This method is no longer the preferred method for error handling due to cross " +
#            "platform incompatibility. Use HandleWebRequestException instead")]
function HandleHttpResponseException {
    [CmdletBinding()]
    param(
        [Parameter()]
        [Microsoft.Powershell.Commands.HttpResponseException]$exception
    )

    if (!$exception.Response) {
        Write-Host $exception -ForegroundColor Red
        break
    }

    $statusCode = [int]$exception.Response.StatusCode
    $statusDescription = $exception.Response.ReasonPhrase
    Write-Host -ForegroundColor:Red "HTTP Error [$statusCode]: $statusDescription"

    $lastError = $Global:Error | Select-Object -First 1
    if($lastError -and $lastError.Exception -eq $exception) {
        Write-Verbose $lastError.ErrorDetails

        $parsed = $lastError.ErrorDetails.Message | ConvertFrom-Json
        Write-Host "Error message:`n`t" $parsed.Error.Message -ForegroundColor:DarkGray
    }
    break
}

# [Obsolete(@"This method is no longer the preferred method for error handling due to cross " +
#            "platform incompatibility. Use HandleWebRequestException instead")]
function HandleWebException {
    [CmdletBinding()]
    param(
        [Parameter()]
        [System.Net.WebException]$exception
    )

    if(!$exception.Response) {
        Write-Host $exception -ForegroundColor Red
        break
    }

    $statusCode = [int]$exception.Response.StatusCode
    $statusDescription = $exception.Response.StatusDescription
    Write-Host -ForegroundColor:Red "HTTP Error [$statusCode]: $statusDescription"

    $responseStream = $null
    try {
        # Get the response body as JSON
        $responseStream = $exception.Response.GetResponseStream()

        if($responseStream.Length -gt 0) {
            $reader = New-Object System.IO.StreamReader($responseStream)
            if($responseStream.Position -eq $responseStream.Length) {
                $responseStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            }

            $global:responseBody = $reader.ReadToEnd()

            if($global:responseBody) {
                Write-Host "Error message:" -ForegroundColor:DarkGray
                try {
                    $json = $global:responseBody | ConvertFrom-JSON
                    $json | ForEach-Object { Write-Host  "`t" $_.error.message -ForegroundColor:DarkGray }
                }
                catch {
                    # Just output the body as raw data
                    Write-Host $global:responseBody -ForegroundColor:DarkGray
                }
            }
        }
    } finally {
        if($responseStream) {
            $responseStream.Close()
            $responseStream.Dispose()
        }
    }
    break
}

function HandleWebRequestException {
    [CmdletBinding()]
    param (
        [Parameter()]
        $error
    )

    $errorDetails = $null
    $response = $error.Exception | Select-Object -ExpandProperty 'Response' -ErrorAction Ignore

    if(!$response) {
        Write-Error -ErrorRecord $error
    } else {
        $statusCode = [int]$response.StatusCode
        $statusDescription = $response.StatusDescription
        $details = $error.ErrorDetails

        Write-Host "HTTP Error [$statusCode]: $statusDescription" -ForegroundColor:Red
        if($details){ Write-Host "Error message:`n`t" $details -ForegroundColor:White }
    }
    break
}

function Load-LevelUpConfigFromFile {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [Alias('e')]
        [string]$environment,
        [Parameter()]
        [Alias('p')]
        [string]$pathToConfig = $Script:pathToConfig
    )

    $config = Get-LevelUpModuleConfig -pathToConfig $pathToConfig -environment $environment

    Load-LevelUpConfig -config $config
}

function Load-LevelUpConfig {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [Alias('c')]
        $config
    )

    if(!$config) {
        $config = Get-LevelUpModuleConfig
    }

    if($config) {
        $Script:merchantAccessToken = $config.merchant_access_token
        $Script:serviceAccessToken = $config.service_access_token
        $Script:userAccessToken = $config.user_access_token
        $Script:apiKey = $config.api_key
        $Script:environment = $config.environment
        $version = $config.version

        $username = $config.username
        $password = $config.password
        if($username -and $password) {
            $Script:credentials = [pscredential]::New($username,
                ($password | ConvertTo-SecureString))
        }
    }

    if(!$Script:environment) { $Script:environment = Read-Host -Prompt 'Environment' }
    if(!$version) { $version = Read-Host -Prompt 'Version (14|15)' }

    Set-LevelUpEnvironment -envName $Script:environment -version $version

    if(!$Script:apiKey) { $Script:apiKey = Read-Host -Prompt 'Api Key' }

    $access_token = $Script:userAccessToken
    $username = ''
    $password = ''

    if(!$access_token) {
        if(!$Script:credentials.UserName -or !$Script:credentials.Password) {
            if(!$Script:credentials.UserName) { $username = Read-Host -Prompt 'Username' }
            if(!$Script:credentials.Password) { $password = Read-Host -Prompt 'Password' -AsSecureString }
            $Script:credentials = [pscredential]::New($username, $password)
        }

        $access = Get-LevelUpAccessToken -apikey $Script:apiKey `
            -username $Script:credentials.UserName `
            -password $Script:credentials.Password
        $access_token = $access.Token
    }

    if(!$access_token) { exit 1 }

    if(!$Script:merchantAccessToken) { $Script:merchantAccessToken = $access_token }
    if(!$Script:userAccessToken) { $Script:userAccessToken = $access_token }

    Write-Host 'Done configuring LevelUp module!' -ForegroundColor Green
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

function Set-LevelUpEnvironment{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$envName,
        [Parameter()]
        [int]$version = 15
    )

    if(!$Script:environments.Contains($envName.ToLower())){
        Write-Host ("WARNING: Invalid entry! Please choose one of the following: [{0}]" `
            -f ($Script:environments.Keys -join ',')) -ForegroundColor Yellow

        $Script:baseURI = $envName
    } else {
        $Script:baseURI = $Script:environments[$envName.ToLower()]
    }

    if(!$Script:baseURI.EndsWith('/')) {
        $Script:baseURI += '/'
    }

    switch($version) {
        0 { $Script:ver = $null }
        13 { $Script:ver = $v13 }
        14 { $Script:ver = $v14 }
        default { $Script:ver = $v15 }
    }

    $Script:uri = (@($Script:baseURI.TrimEnd('/'), $Script:ver) -join '/')

    Write-Host ("Set environment as: {0}" -f $Script:uri) -ForegroundColor Cyan
}

