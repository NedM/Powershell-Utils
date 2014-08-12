[cmdletbinding()]
param ([ValidateNotNullOrEmpty()] 
       [parameter(Mandatory=$true)]       
       [int]$startMenuId,
       [ValidateNotNullOrEmpty()] 
       [parameter(Mandatory=$false)]
       [int]$endMenuId=$startMenuId,
       [parameter(Mandatory=$false)]
       [alias("e")]
       $environment = "production"
       )    

import-module "C:\dev\Personal\Powershell\Modules\LevelUpApiModule.psm1" -Force

Set-LevelUpEnvironment -envName $environment -version 15

$items = $null

for($i = $startMenuId; $i -le $endMenuId; $i++) {   
    # $theUri = "https://api.thelevelup.com/v15/order_ahead/menus/$i"

    $menu = Get-LevelUpMenu -menuId $i

    if(-not $menu) { continue; }

    $items = $menu.menu.categories | Select-Object -ExpandProperty category | Select-Object -ExpandProperty items | Select-Object -ExpandProperty item
    
    $timescopes = $items | Select-Object -Property timescopes

    $timescopesWithContent = $timescopes | where {$_.timescopes.Length -gt 0 }

    if($timescopesWithContent.Length -gt 0) {
        Write-Host ("Found non-empty timescopes for menuId {0}" -f $i) -ForegroundColor Green
        $timescopesWithContent
        break
    }

    Write-Verbose ("Found no timescopes for menuId {0}. Continuing search..." -f $i)
    #$ans = Read-Host -Prompt "Continue?"

    #if(-not $ans.ToLowerInvariant().Contains('y')) { break; }
}


