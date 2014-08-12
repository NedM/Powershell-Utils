$name = "EMPTY"
$responseStatus = "OK"
$merchant;
$i = 1;

do{
    $response = iwr https://api.thelevelup.com/v13/merchants/$i.json
    $responseStatus = $response.StatusDescription
    if($responseStatus -eq "OK")
    {
        $temp = $response.Content | ConvertFrom-Json
        $merchant = $temp.merchant
        $merchant.name
        $i++
    }

}while($responseStatus -eq "OK" -and $merchant.name -notmatch "Simon")

$merchant