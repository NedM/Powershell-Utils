# To reload profle without relaunching shell, type ". $PROFILE"

$devDir = "c:\dev"
$shared_R = "c:\shared_r"
$personalDir = $devDir + "\Personal"
$levelUpDir = $devDir + "\LevelUp"
$vagrantDir = $devDir + "\Vagrant"
$me = "C:\Users\Ned\AppData\Local\GitHub\GitHub.appref-ms --open-shell"

function GoTo([string]$location)
{
    if($location -eq "")
    {
        Get-ChildItem Env:
    }
    else
    {                
        if((Get-ChildItem Env: | Where-Object { $_.Name -eq $location }).Count -gt 0)
        {
            $path = Get-Item Env:$location
            Push-Location $path.Value
        }
        else
        {
            Push-Location $location
        }
    }
}

function GoUp([int]$numLevels = 1){
    if($numLevels -gt 0){
		Push-Location ..
		for($i=2; $i -le $numLevels; $i++){ cd.. }
    }
}

function GoBack([int]$numLevels = 1){
    if($numLevels -gt 0){
        for($i=1; $i -le $numLevels; $i++) { cd.. }
    }
}

function GoToRoot{ GoTo $devDir }
function GoToShared_RFolder{ GoTo $shared_R }
function GoToShared_RWFolder{ GoTo "c:\shared_rw" }
function GoToPOS{ GoTo "$levelUpDir\POS" }
function GoToLevelUp{ GoTo $levelUpDir }
function GoToPersonal{ GoTo $personalDir }
function GoToPowershell { GoTo "$personalDir\Powershell" }
function GoToVagrant{ GoTo $vagrantDir }
function GoToSDK{ GoTo "$levelUpDir\API-Csharp-SDK" }
function GoToJDK{ GoTo "$levelUpDir\API-Java-SDK" }
function GoToUwp { GoTo "$levelUpDir\UWP-LevelUp" }
function GoToBuild{ GoTo "$levelUpDir\Build+Deploy" }
function GoToUbuntuFS { 
    <# Push-Location $env:LOCALAPPDATA\lxss #> 
    Write-Host "NO! I will not take you to $env:LOCALAPPDATA\lxss. That is dangerous!" #See https://blogs.msdn.microsoft.com/commandline/2016/11/17/do-not-change-linux-files-using-windows-apps-and-tools/ 
}
function GoToMothership { GoTo "$levelUpDir\levelup" }
function GoToOrderAhead { GoTo "$levelUpDir\order-ahead" }

function EditProfile{
    Start-Process -FilePath "${env:windir}\System32\WindowsPowerShell\v1.0\powershell_ise.exe" -ArgumentList $profile #"${env:USERPROFILE}\documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
}

function FindString($string, $extensionFilter){
    Get-ChildItem -Recurse -Include $extensionFilter | Select-String $string | Sort-Object -Property Path,LineNumber -Descending | Format-Table -AutoSize -Property LineNumber,Path
}

function FindFiles($partialFileName){
    Get-ChildItem -Recurse -Filter $partialFileName | Sort-Object -Property FullName | Format-Table -Property FullName -Autosize
}

function FindPaths($partialName){
	Get-ChildItem -Path $partialName -Recurse | Sort-Object -Property FullName | Format-Table -Property FullName -Autosize
}

function FileTypeCount([switch]$recurse, $filePath){
    if(!$filePath) {
        $filePath = "."
    }
    
    if($recurse) {
        Get-Childitem $filePath -Recurse | where { -not $_.PSIsContainer } | group Extension -NoElement | sort count -desc
    } else {
        Get-Childitem $filePath | where { -not $_.PSIsContainer } | group Extension -NoElement | sort count -desc
    }
}

function GetFileVersionInfo($filePath) {
    if($filePath -eq "")
    {
        $filePath = "."
    }

    get-childitem $filePath | %{ $_.VersionInfo }
}

function FileTypeCountRecursive($filePath)
{
    FileTypeCount "-r" $filePath
}

function RunAsAdmin($pathToApplication, [string[]]$arguments)
{
	if("" -ne $arguments -and $arguments.length -gt 0)
	{
		Start-Process -FilePath $pathToApplication -WorkingDirectory .\ -Verb runAs -ArgumentList $arguments 
	}
    else
    {
        Start-Process -FilePath $pathToApplication -WorkingDirectory .\ -Verb runAs
    }
}

function RunVSCommunity2015AsAdmin([string[]]$arguments) {
    RunAsAdmin "${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe" $arguments
}

function RunVS2012AsAdmin([string[]]$arguments) {
    RunAsAdmin "${env:ProgramFiles(x86)}\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe" $arguments
}

function RunRubyMineAsAdmin([string[]]$arguments) {
    if(!$arguments) { $arguments = @('.') }
    RunAsAdmin "${env:ProgramFiles(x86)}\JetBrains\RubyMine 2016.3.2\bin\rubymine.exe" (Resolve-Path $arguments[0]).Path $arguments[1..($arguments.Count-1)]
}

function RunSourceTree() { 
    Start-Process -FilePath "${env:LOCALAPPDATA}\SourceTree\Update.exe" -WorkingDirectory "${env:LOCALAPPDATA}\SourceTree\app-2.0.20.1" -ArgumentList @("--processStart", "SourceTree.exe")
}

function RunEclipseAsAdmin([string[]]$arguments) {
    RunAsAdmin "${env:ProgramFiles(x86)}\eclipse\eclipse.exe" $arguments
}

function WhatCanISay($filter) {
    if(!$filter) {
        #$filter = "*"
        $filter = ""
    }
    
    #Alias | where {$_.Definition -like $filter}
    Alias | where {$_.Definition -match $filter}
}

function GetAvailableCommands([string]$moduleName) {
    if(!$moduleName) {
        WhatCanISay
    } else {
        Get-Command -Module $moduleName
    }
}

function PrintPSVersion{
    $PSVersionTable
}

function LaunchPrototypeProj{
    RunVSCommunity2015AsAdmin($personalDir + "\test\Prototype\Prototype\Prototype.sln")
}

function LaunchProcessExplorer{
    Start-Process -FilePath "$shared_R\tools\ProcessExplorer\procexp.exe"
}

function GitStatus { git status }
function GitAddAll { git add --all }
function GitCheckout($target) { git checkout $target }

function GitCleanUp {
    git clean -fdx
    git remote prune origin
}

function GitDifftoolStaged { git difftool --staged }
function GitCommitWithMessage($message) { git commit -m $message }
function GitLogDecorate { git log --decorate --graph }
function GitPullRebase { git pull --rebase }
function GitMergeFastForwardOnly($branch) { git merge --ff-only $branch }
function GitDontTrackRemainingChangedFiles { git checkout -- . }
function GitReset { git reset --hard HEAD }
function StartRailsServer { rails server }
function VagrantUp { vagrant up }

#General Aliases
Set-Alias mypro EditProfile
Set-Alias n "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
Set-Alias np "notepad.exe"
Set-Alias st "${env:PROGRAMW6432}\Sublime Text 3\sublime_text.exe"
Set-Alias mdp "${env:ProgramFiles(x86)}\MarkdownPad 2\MarkdownPad2.exe"
Set-Alias tre RunSourceTree
Set-Alias ecl RunEclipseAsAdmin
Set-Alias vs RunVSCommunity2015AsAdmin
Set-Alias vs12 RunVS2012AsAdmin
Set-Alias rbm RunRubyMineAsAdmin
Set-Alias fstr FindString
Set-Alias ffile FindFiles
Set-Alias ftc FileTypeCount
Set-Alias ftcr FileTypeCountRecursive
Set-Alias fver GetFileVersionInfo
Set-Alias find FindPaths
Set-Alias gh Get-Help
Set-Alias wut WhatCanISay
Set-Alias wat GetAvailableCommands
Set-Alias psver PrintPSVersion
Set-Alias proto LaunchPrototypeProj
Set-Alias elevate RunAsAdmin
Set-Alias pex LaunchProcessExplorer
Set-Alias gfv GetFileVersionInfo

# Location Shortcuts
Set-Alias up GoUp
Set-Alias .. GoBack
Set-Alias go GoTo
Set-Alias root GoToRoot
Set-Alias lu GoToLevelUp
Set-Alias dev GoToPersonal
Set-Alias pow GoToPowershell
Set-Alias uwp GoToUwp
Set-Alias shr GoToShared_RFolder
Set-Alias shrw GoToShared_RWFolder
Set-Alias pos GoToPOS
Set-Alias sdk GoToSDK
Set-Alias jdk GoToJDK
Set-Alias bld GoToBuild
Set-Alias vm GoToVagrant
Set-Alias ubu GoToUbuntuFS
Set-Alias msp GoToMothership
Set-Alias oa GoToOrderAhead

# Git aliases
Set-Alias g-- GitDontTrackRemainingChangedFiles
Set-Alias gad GitAddAll
Set-Alias gclean GitCleanUp
Set-Alias gco GitCheckout
Set-Alias gcom GitCommitWithMessage
Set-Alias glog GitLogDecorate
Set-Alias gds GitDifftoolStaged
Set-Alias gmerge GitMergeFastForwardOnly
Set-Alias gpr GitPullRebase
Set-Alias gs GitStatus
# Set-Alias greset GitReset

# Rails aliases
Set-Alias rs StartRailsServer
Set-Alias rc irb

# Vagrant aliases
Set-Alias vup VagrantUp

# Heroku alases
Set-Alias ku heroku
# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}


if(-not (Get-Module -Name posh-git)) {
  Import-Module Posh-Git
}

Start-SshAgent