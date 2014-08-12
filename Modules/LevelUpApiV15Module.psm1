## Base Uris ##
$productionBaseURI = "https://api.thelevelup.com/"
$stagingBaseURI = "https://api.staging-levelup.com/"
$sandboxBaseURI = "https://sandbox.thelevelup.com/"

#####################
## LEVELUP API v14 ##
#####################

$v15BaseURI = $productionBaseURI + "v15/"
#$baseURI = $sandboxBaseURI + "v14/"
$baseURI = $v15BaseURI

$formatHeaders = @{"Content-Type" = "application/json"; "Accept" = "application/json"}

Import-Module C:\dev\personal\Powershell\modules\REST.psm1 -Force

function Format-LevelUpHeaders([string]$appToken, [string]$merchantToken, [string]$userToken) {
    $authString = "Authorization"
    $headers = @{}
    $headers += $formatHeaders

    if($appToken) {
        if($headers.ContainsKey($authString)) {            
            $headers[$authString] = "token $appToken"
        } else {
            $headers.Add($authString, "token $appToken")
        }
    }

    if($merchantToken) {
        if($headers.ContainsKey($authString)) {
            $previousVal = $headers[$authString]
            $headers[$authString] = "$previousVal merchant=$merchantToken"
        } else {
            $headers.Add($authString, "token merchant=$merchantToken")
        }
    }

    if($userToken) {
        if($headers.ContainsKey($authString)) {
            $previousVal = $headers[$authString]
            $headers[$authString] = "$previousVal user=$userToken"
        } else {
            $headers.Add($authString, "token user=$userToken")
        }
    }

    return $headers
}

function Get-LevelUpGodToken([string]$apikey, [string]$username, [string]$password) {
    $tokenRequest = @{ "access_token" = @{ "client_id" = $apikey; "username" = $username; "password" = $password } }

    $headers = Format-LevelUpHeaders $null $null $null

    $body = $tokenRequest | ConvertTo-Json

    $theURI = $baseURI + "access_tokens"
    
    $response = Submit-PostRequest $theURI $body $headers

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.access_token
}

function Get-LevelUpAppAccessToken([string]$apiKey, [string]$clientSecret) {
    $tokenRequest = @{ "api_key" = $apiKey; "client_secret" = $clientSecret }

    $headers = Format-LevelUpHeaders $null $null $null

    $body = $tokenRequest | ConvertTo-Json

    $theURI = $baseURI + "access_tokens"
    
    $response = Submit-PostRequest $theURI $body $headers

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.access_token
}

function Create-LevelUpPermissionsRequest([string]$userEmail, $permissionsDesired, [string]$appAccessToken) {
    $permissionRequest = @{ "permissions_request" = @{ "email" = $userEmail; "permission_keynames" = $permissionsDesired } }

    $headers = Format-LevelUpHeaders $appAccessToken $null $null

    $body = $permissionRequest | ConvertTo-Json

    $theURI = $baseURI + "apps/permissions_requests"
    
    $response = Submit-PostRequest $theURI $body $headers

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.permissions_request
}

function Get-LevelUpPermissionRequestStatus([int]$requestId, [string]$appAccessToken) {
    $headers = Format-LevelUpHeaders $appAccessToken $null $null

    $theURI = $baseURI + "apps/permissions_requests/$requestId"

    $response = Submit-GetRequest $theURI $headers

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.permissions_request
}

function Override-LevelUpAcceptPermissionsRequest([int]$requestId, [string]$godToken) {
    $override = @{ "event" = "accept" }
    
    $headers = Format-LevelUpHeaders $godToken $null $null

    $body = $override | ConvertTo-Json

    $theURI = $baseURI + "permissions_requests/$requestId"

    $response = Submit-PutRequest $theURI $body $headers

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.permissions_request
}

function Get-LevelUpMerchantFundedCredit([string]$locationId, [string]$qrCode, [string]$merchantToken) {
    
    $headers = Format-LevelUpHeaders $null $merchantToken $null

    $theURI = $baseURI + "locations/$locationId/merchant_funded_credit?payment_token_data=$qrCode"

    $response = Submit-GetRequest $theURI $headers

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.credit
}

function Grant-LevelUpMerchantFundedCredit([string]$userEmail, [int]$merchantId, [int]$valueAmount, [string]$merchantToken) {
    
    $headers = Format-LevelUpHeaders $null $merchantToken $null

    $addCreditRequest = @{ 
        "merchant_funded_credit" = @{
            "email" = $userEmail;
            "merchant_id" = $merchantId;
            "value_amount" = $valueAmount;
            }
         }

    $body = $addCreditRequest | ConvertTo-Json

    $theURI = $baseURI + "merchant_funded_credits"

    $response = Submit-PostRequest $theURI $body $headers
}

function Get-LevelUpUserDetails([string]$userToken) {
    $headers = Format-LevelUpHeaders $null $null $userToken

    $theURI = $baseURI + "users"

    $response = Submit-GetRequest $theURI $headers

    $parsed = $response.Content | ConvertFrom-Json

    return $parsed.user
}