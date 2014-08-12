$powershellRegKeyPath = "HKCU:Console\%SystemRoot%_system32_WindowsPowerShell_v1.0_powershell.exe"
$DwordType = "DWORD"

function SetItemProperty([string]$name, [string]$type, [string]$value) {
    $itemProp = Get-ItemProperty -Path $powershellRegKeyPath -Name $name

    if($itemProp -eq $null) {
        New-ItemProperty -Path $powershellRegKeyPath -Name $name -PropertyType $type -Value $value
    } elseif($itemProp.$name -ne $value) {
        Set-ItemProperty -Path $powershellRegKeyPath -Name $name -Value $value
    }
}

## From Windows PowerShell Cookbook (O'Reilly)
## by Lee Holmes (http://www.leeholmes.com/guide)
Set-StrictMode -Version Latest

SetItemProperty -name ColorTable00 -type $DwordType -value 0x00562401
SetItemProperty -name ColorTable07 -type $DwordType -value 0x00f0edee
SetItemProperty -name FaceName -type STRING -value "Lucida Console"
SetItemProperty -name FontFamily -type $DwordType -value 0x00000036
SetItemProperty -name FontSize -type $DwordType -value 0x000c0000
SetItemProperty -name FontWeight -type $DwordType -value 0x00000190
SetItemProperty -name HistoryNoDup -type $DwordType -value 0x00000000
SetItemProperty -name QuickEdit -type $DwordType -value 0x00000001
SetItemProperty -name ScreenBufferSize -type $DwordType -value 0x0bb80078
SetItemProperty -name WindowSize -type $DwordType -value 0x00320078

###################
## Setup PoshGit ##
###################
. (Resolve-Path "$env:LOCALAPPDATA\GitHub\shell.ps1")
. $env:github_posh_git\profile.example.ps1

##################
## Load Profile ##
##################
. $profile

