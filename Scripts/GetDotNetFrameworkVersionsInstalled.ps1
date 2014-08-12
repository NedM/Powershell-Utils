$registryPath = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'
$keys = Get-ChildItem -Path $registryPath
$relevantKeys = $keys | Where-Object { (Split-Path -Leaf $_.Name).ToLower().StartsWith("v") }

$header = @"
++++++++++++++++++++++++++++++
+ Installed versions of .NET +
++++++++++++++++++++++++++++++

"@

Write-Host $header -ForegroundColor Gray

foreach($k in $relevantKeys) {
    $name = Split-Path -Leaf $k.Name
    $version = $k.GetValue("Version", "")
    $sp = $k.GetValue("SP", "")
    $install = $k.GetValue("Install", "")

    Write-Host $name -ForegroundColor Cyan
    
    if($version -ne "") {
        if($install -eq "") {
            $output = "  {0}" -f $version
            Write-Host $output -ForegroundColor Green
        }
        else {
            $output = "  {0}, SP{1}" -f $version, $sp
            Write-Host $output -ForegroundColor Green
        }

        continue;
    }

    $subKeys = Get-ChildItem -Path $k.PSPath
    foreach($subKey in $subKeys) {
        $subname = Split-Path -Leaf $subKey.Name
        $version = $subKey.GetValue("Version", "");
        if($version -ne "") {
            $sp = $subKey.GetValue("SP", "")
        }

        $install = $subKey.GetValue("Install", "")
        if($install -eq "") {
            $output = "{0} {1}" -f $name, $version
        }
        else {
            if($install -eq "1") {
                if($sp -ne "") {
                    $output = "  {0} :: {1} SP{2}" -f $subname, $version, $sp
                }
                else {
                    $output = "  {0} {1}" -f $subname, $version
                }
            }
        }

        Write-Host $output -ForegroundColor Green
        
        #Add new line at the end
        Write-Host ""
    }    
}