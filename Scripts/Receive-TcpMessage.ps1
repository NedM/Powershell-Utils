param ([ValidateNotNullOrEmpty()] 
       [int] $Port       
       )

Import-Module C:\dev\personal\Powershell\Modules\TCPComms.psm1 -Force

Receive-TCPMessage -port $Port