[cmdletbinding()]
param ([ValidateNotNullOrEmpty()] 
       [parameter(Mandatory=$true)]
       [alias("u")]
       [string]$user,
       [ValidateNotNullOrEmpty()] 
       [parameter(Mandatory=$true)]
       [alias("p")]
       [string]$password
       )

$posAtClientId = "ClientIdGoesHere"
$enUS = New-Object System.Globalization.CultureInfo("en-US")
$currencyColumnWidth = 8

function Format-CurrencyAmount {
[cmdletBinding()]
Param(
    [parameter(ValueFromPipeline)]
    $currencyAmount,
    [parameter()]
    $culture = $enUS
)
    if($currencyAmount -eq 0) {
        $currencyAmount.toString("C0", $culture)
    } else {
        $currencyAmount.toString("C2", $culture)
    }
}

function ConvertTo-Dollars{
[cmdletBinding()]
Param(
    [parameter(ValueFromPipeline)]
    [int]$cents
)
    $cents / 100
}

import-module "C:\dev\Personal\Powershell\Modules\LevelUpApiModule.psm1" -Force

$access = Get-LevelUpAccessToken -apikey $posAtClientId -username $user -password $password

if(!$access) { exit 1 }

$orders = Get-LevelUpOrdersForUser $access.token

$orders | Format-Table @{Label = "UUID";Expression={$_.uuid};Width = 15},`
@{Label = "Date";Expression={$_.transacted_at | Get-Date -Format 'MMM d'};Width = 8},`
@{Label = "Merchant";Expression={$_.merchant_name};Width = 40},`
@{Label = "Spend";Expression={$_.spend_amount | ConvertTo-Dollars | Format-CurrencyAmount};Width = $currencyColumnWidth;Alignment="Right"},`
@{Label = "Tip";Expression={$_.tip_amount | ConvertTo-Dollars | Format-CurrencyAmount};Width = $currencyColumnWidth;Alignment="Right"},`
@{Label = "Total";Expression={$_.total_amount | ConvertTo-Dollars | Format-CurrencyAmount};Width = $currencyColumnWidth;Alignment="Right"},`
@{Label = "Credit";Expression={$_.credit_applied_amount | ConvertTo-Dollars | Format-CurrencyAmount};Width = $currencyColumnWidth;Alignment="Right"},`
@{Label = "Refunded?";Expression={if(!$_.refunded_at){'No'} else {'Yes'}};Width = 9;Alignment="Right"}