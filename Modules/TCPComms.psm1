Function Read-TcpResponse([System.Net.Sockets.NetworkStream]$stream) {
    $readBuffer = New-Object System.Byte[] 1024

    $strReader = New-Object System.Text.StringBuilder;

    try {
        $numBytesRead = $stream.Read($readBuffer, 0, $readBuffer.Length)

        while ($numBytesRead -ne 0){
                $EncodedText = New-Object System.Text.ASCIIEncoding
                $strReader.Append($EncodedText.GetString($readBuffer,0, $numBytesRead))

                if(!$stream.CanRead) {
                    break
                }

                $numBytesRead = $stream.Read($readBuffer, 0, $readBuffer.Length)
            }
    }catch [exception]{}

    Write-Output $strReader.ToString()
}

Function Send-TCPMessage { 
    param ( [ValidateNotNullOrEmpty()] 
        [string] $EndPoint, 
        [int] $Port, 
        $Message
    ) 
     
    $UTF8 = [System.Text.Encoding]::UTF8
    $IP = [System.Net.Dns]::GetHostAddresses($EndPoint) 
    $Address = [System.Net.IPAddress]::Parse($IP) 
    $Socket = New-Object System.Net.Sockets.TCPClient($Address,$Port) 
    $data = $UTF8.GetBytes($Message)
    $Stream = $Socket.GetStream() 
    $Writer = New-Object System.IO.StreamWriter($Stream)
    $Message | %{
        $Writer.WriteLine($_)
        $Writer.Flush()
    }

    Read-TcpResponse -stream $Stream

    $Stream.Close()
    $Socket.Close()
}

Function Receive-TCPMessage { 
    param ([ValidateNotNullOrEmpty()] 
        [int] $Port
    ) 
    try { 
     
        $endpoint = new-object System.Net.IPEndPoint([ipaddress]::any,$port) 
        $listener = new-object System.Net.Sockets.TcpListener $EndPoint
        $listener.start() 
 
        $data = $listener.AcceptTcpClient() # will block here until connection 
        $bytes = New-Object System.Byte[] 1024
        $stream = $data.GetStream()
        $stream.ReadTimeout = 250
 
        Read-TcpResponse -stream $stream
         
        $stream.close()
        $listener.stop()
    }catch [exception]{}
}