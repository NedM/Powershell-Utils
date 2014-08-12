param ([ValidateNotNullOrEmpty()] 
       [string] $EndPoint, 
       [int] $Port, 
       $Message
       )

Import-Module C:\dev\personal\Powershell\Modules\TCPComms.psm1 -Force

if(!$Message) {
    $Message = @'
<Request xmlns:i="http://www.w3.org/2001/XMLSchema-instance" i:type="DataRequest" xmlns="http://www.TheLevelUp.com">
    <Cashier i:nil="true" />
    <Identifier i:nil="true" />
    <TerminalId>1</TerminalId>
    <Data>abc123</Data>
    <RequestType>STORE_QR_CODE</RequestType>
</Request>
'@
}

Send-TCPMessage -EndPoint $EndPoint -Port $Port -Message $Message