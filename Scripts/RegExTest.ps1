$testString = "<https://sandbox.thelevelup.com/v14/locations/199/orders?page=2>; rel=`"next`""
$match = $testString -match '(?<=<)\S*(?=>)' | Out-Null; $Matches[0]