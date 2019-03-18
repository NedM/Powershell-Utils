[cmdletbinding()]
param(
    [int]$status = 200
)

import-module ("{0}\..\Modules\REST.psm1" -f $PSScriptRoot) -Force

$script:urlBase = "https://httpbin.org/"

$url = Create-Uri -base $script:urlBase -path "status/$status"

Submit-GetRequest -uri $url

