function Use-YourWords([Parameter(Mandatory=$true)][string] $text, [Parameter(Mandatory=$false)][switch] $async) {

[Reflection.Assembly]::LoadWithPartialName('System.Speech') | Out-Null
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

$synth.SelectVoice("Microsoft Hazel Desktop")

    if($async){
        $synth.SpeakAsync($text)
    } else {
        $synth.Speak($text)
    }
}