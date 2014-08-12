[cmdletbinding()]
Param(
    [parameter(Mandatory=$true)]
    [alias("j")]
    [string]$ProposedOrderRequestBody
    )

$global:formatError = $false

function Add-Warning([string]$msg) {
    Write-Host $msg -ForegroundColor Yellow
}

function Add-Error([string]$msg) {
    Write-Host $msg -ForegroundColor Red
    $global:formatError = $true
}

function Validate-Item($item) {

}

try {
    $parsed = $ProposedOrderRequestBody | ConvertFrom-Json
} catch {
    Write-Host "Error while parsing request body as JSON"
    throw
}

$proposedOrderBody = $parsed.proposed_order

if($proposedOrderBody.location_id -eq $null) {
    Add-Error "Location id is required but not present!"
} elseif($proposedOrderBody.location_id.GetType().Name -ne [Int32].Name) {
    Add-Error "Location Id `"$propsedOrderBody.location_id`" is not an integer!"    
}

if(!$proposedOrderBody.items) {
    Add-Error "Null items list!"
} if($proposedOrderBody.items.count -eq 0) {
    Add-Error "No items!"    
}

foreach($item in $proposedOrderBody.items) {
    $i = $item.item
    $prefix = "Item with name `"{0}`" " -f $i.item.name
    if(!$i.charged_price_amount) { Add-Error ($prefix + "charged price is not present!") }
    if($i.charged_price_amount.GetType().Name -ne [Int32].Name) { Add-Error ($prefix + "charged price is not an integer!") }
    if(!$i.standard_price_amount) { Add-Warning ($prefix + "standard price is not present!") }
    if($i.standard_price_amount.GetType().Name -ne [Int32].Name) { Add-Error ($prefix + "standard price is not an integer!") }
}

if(!$global:formatError) {
    Write-Host -ForegroundColor Green "Proposed order request is valid!"
}