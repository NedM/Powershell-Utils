[cmdletbinding()]
param([ValidateNotNullOrEmpty()]
      $OrdersToRefund,
      [alias("u")]
      $User,
      [alias("p")]
      $Password
      )

import-module "C:\dev\Personal\Powershell\Modules\LevelUpApiModule.psm1" -Force

function RefundOrders($orders, $confirmEach = $false) {
    foreach($order in $orders) {
        if($order.order.refunded_at) { 
          Write-Verbose ("Order {0} already refunded. Skipping..." -f $order.order.uuid)
          continue
        }

        if($confirmEach) {
            $order.order | Format-List | Out-Host
            $doRefund = Read-Host -Prompt "Refund this order? (y/n)"
            if($doRefund.ToLowerInvariant() -ne 'y') { continue; }
        }

        Undo-LevelUpOrder -orderId $order.order.uuid
    }
}
$apiKey = ''
$use_sandbox = $true
## Sandbox ##
$sandbox_apiKey = "ClientIdGoesHere"
## Production ##
$posAtClientId = "ClientIdGoesHere"

if($use_sandbox) {
    Set-LevelUpEnvironment -envName 'Sandbox'
    $apiKey = $sandbox_apiKey
} else {
    Set-LevelUpEnvironment -envName 'Production'
    $apiKey = $posAtClientId
}

$access = Get-LevelUpAccessToken -apikey $apiKey -username $user -password $password

if(!$access) { 
    Write-Error "Failed to get access token!"
    exit 1
}

Set-LevelUpAccessToken -token $access.Token

$ordersFromLocation.order | Format-Table | Out-Host

$response = Read-Host -Prompt "Do you want to refund all of the orders above? (y/n)"

if($response.ToLowerInvariant() -eq "yes!") {
  RefundOrders -orders $ordersFromLocation -confirmEach $false
} elseif ($response.ToLowerInvariant() -eq "y") {
  RefundOrders -orders $ordersFromLocation -confirmEach $true    
}