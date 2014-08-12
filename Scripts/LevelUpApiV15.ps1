## ClientIds ##
$clientId1 = "ClientIdGoesHere"
$clientId2 = "ClientIdGoesHere"
$posAtClientId = "ClientIdGoesHere"

## QR Codes ##
$TestAccountCode = ""
$posPlusTestCode = ""
$NedsTestCode = "" #(rejects charges over $10)

## Base Uris ##
$productionBaseURI = "https://api.thelevelup.com/"
$stagingBaseURI = "https://api.staging-levelup.com/"
$sandboxBaseURI = "https://sandbox.thelevelup.com/"

#####################
## LEVELUP API v15 ##
#####################

$clientId = $posAtClientId
$merchantUsername = "username"
$merchantPassword = need password
$connectedAppsClientId = "ClientIDGoesHere"  #POS Team App ID: 103
$connectedAppsClientSecret = "ClientIdGoesHere"  #POS Team App ID: 103
$username = "UserNameGoesHere"
$password = need password
$nedTestUser = "UserNameGoesHere"

Import-Module C:\dev\personal\Powershell\Modules\LevelUpApiV15Module.psm1 -Force

#App Authentication
$token = Get-LevelUpAppAccessToken $connectedAppsClientId $connectedAppsClientSecret
$appAccessToken = $token.token
$merchantId = $token.merchant_id
$appId = $token.app_id

#Create User Permissions Request
$requestUserPermissions = @("read_user_orders", "create_orders", "read_user_basic_info", "manage_user_campaigns")
$response = Create-LevelUpPermissionsRequest $username $requestUserPermissions $appAccessToken
$permissionRequestId = $response.id

#'Accept' User Permissions Request
$response = Get-LevelUpGodToken $connectedAppsClientId $username $password
$userGodToken = $response.token

$response = Override-LevelUpAcceptPermissionsRequest $permissionRequestId $userGodToken
$userToken = $response.token
$userPermissionsGranted = $response.permissions.permission

#Create Merchant Permissions Request
$requestMerchantPermissions = @("manage_merchant_orders", "give_merchant_funded_credit", "read_merchant_locations", "read_merchant_transaction_history", "read_customer_list")
$response = Create-LevelUpPermissionsRequest $merchantUsername $requestMerchantPermissions $appAccessToken
$permissionRequestId = $response.id

#'Accept' Merchant Permissions Request
$response = Get-LevelUpGodToken $connectedAppsClientId $merchantUsername $merchantPassword
$merchantGodToken = $response.token

$response = Override-LevelUpAcceptPermissionsRequest $permissionRequestId $merchantGodToken
$merchantToken = $response.token
$merchantPermissionsGranted = $response.permissions.permission

Write-Host "User God token: " -NoNewline
Write-Host $userGodToken -ForegroundColor Yellow
Write-Host "User permissions token: " -NoNewline
Write-Host $userToken -ForegroundColor Green
Write-Host "Permissions granted:"
$userPermissionsGranted | Format-Table -AutoSize

Write-Host "Merchant Id: " -NoNewline
Write-Host $merchantId -ForegroundColor Cyan
Write-Host "Merchant God token: " -NoNewline
Write-Host $merchantGodToken -ForegroundColor Yellow
Write-Host "Merchant permissions token: " -NoNewline
Write-Host $merchantToken -ForegroundColor Green
Write-Host "Permissions granted:"
$merchantPermissionsGranted | Format-Table -AutoSize

#Get User Orders
