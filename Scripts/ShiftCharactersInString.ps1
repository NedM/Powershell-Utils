[cmdletbinding()]
Param([parameter(Mandatory=$true)]
    [string]$OriginalString,
    [parameter(Mandatory=$true)]
    [int]$ShiftBy)
    
$lowerCaseAValue = [int]('a'[0])
$lowerCaseZValue = [int]('z'[0])
$upperCaseAValue = [int]('A'[0])
$upperCaseZValue = [int]('Z'[0])
$numAlphabetChars = ($lowerCaseZValue - $lowerCaseAValue) + 1 # + 1 to fix modulo math. This should just be 26.

function ShiftCharacter([char]$char, [int]$amount) {
    $charValue = [int]$char

    # Determine case
    if($charValue -ge $upperCaseAValue -and $charValue -le $upperCaseZValue) {
        ShiftCasedCharacter -char $char -amount $amount -aValue $upperCaseAValue -zValue $upperCaseZValue
    } elseif($charValue -ge $lowerCaseAValue -and $charValue -le $lowerCaseZValue) {
        ShiftCasedCharacter -char $char -amount $amount
    } else {
        # Skip non-letter characters
        $char
    }
}

function ShiftCasedCharacter([char]$char, [int]$amount, [int]$aValue = $lowerCaseAValue, [int]$zValue = $lowerCaseZValue) {
    $charValue = [int]$char
    $normalized = $charValue - $aValue
    $shifted = $normalized + $amount

    # Handle negative shift amounts
    if($shifted -lt 0) { 
        $shifted += $numAlphabetChars 
    }

    $shiftedNormalized = $shifted % $numAlphabetChars
    $restored = $shiftedNormalized + $aValue
    [char]$restored
}

$ShiftBy = $ShiftBy % $numAlphabetChars
$shifted = $OriginalString.ToCharArray() | foreach { ShiftCharacter $_ $ShiftBy }

Write-Host "Input: `'$OriginalString`'`n"
Write-Host ("Shifted by {0}: {1}" -f $ShiftBy, ($shifted -join ''))
