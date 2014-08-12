[cmdletbinding()]
Param(
    [parameter(Mandatory=$true)]
    [alias("p")]
    [string]$packageName,
    [parameter(Mandatory=$true)]
    [alias("o")]
    [string]$versionToReplace,
    [parameter(Mandatory=$true)]
    [alias("n")]
    [string]$replacement
    )

function ReplacePackageVersionInCsProj([string]$packageName, [string]$versionToReplace, [string]$newVersion) {
    #Replace in <Reference> line
    $versionStr = "Version="

    if($packageName) {
      $versionStr = "$packageName, $versionStr"
    }

    $firstMatchTarget = $versionStr + $versionToReplace + ".0"  #This is a RegEx
    $firstReplacement = $versionStr + $newVersion + ".0"

    #Replace in <HintPath> line
    $versionStr = ""
    
    if($packageName) {
      $versionStr = "$packageName."
    }

    $secondMatchTarget = $versionStr + $versionToReplace  #This is a RegEx
    $secondReplacement = $versionStr + $newVersion

    Get-ChildItem -Recurse -Include "*.csproj" | 
        ForEach-Object { 
          $updateFile = $false
          $content = ($_ | Get-Content)

          if($content -match $firstMatchTarget) {
            $content = ($content -replace $firstMatchTarget, $firstReplacement)
            $updateFile = $true
          }

          if($content -match $secondMatchTarget) { 
            $content = ($content -replace $secondMatchTarget, $secondReplacement)
            $updateFile = $true
          }

          if($updateFile) {
            Set-Content -Value $content -Path $_
            Write-Verbose "Updated $_"
          }
        }        
}

function ReplacePackageVersionInPackagesConfig([string]$packageName, [string]$versionToReplace, [string]$newVersion) {
    $versionStr = "version="
    
    if($packageName) {
      $versionStr = "id=`"$packageName`" $versionStr"
    }

    $matchTarget = $versionStr + "`"$versionToReplace`""  #RegEx
    $replacement = $versionStr + "`"$newVersion`""   

     Get-ChildItem -Recurse -Include "packages.config" |
        ForEach-Object { 
           $content = ($_ | Get-Content)

           if($content -match $matchTarget) {
            $content = ($content -replace $matchTarget, $replacement) | 
            Set-Content $_
            Write-Verbose "Updated $_"
           }
        }
}

function ReplacePackageVersion($packageName, $versionToReplace, $newVersion) {

    ReplacePackageVersionInCsProj $packageName $versionToReplace $newVersion
    
    ReplacePackageVersionInPackagesConfig $packageName $versionToReplace $newVersion
}

ReplacePackageVersion -packageName $packageName -versionToReplace $versionToReplace -newVersion $replacement