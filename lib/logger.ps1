param()

Function LogUpdate([String]$Message) {
    #    Write-Output "[UPDATE] $Message"
    Write-Host -ForegroundColor Cyan $Message
}

Function LogInfo([String]$Message) {
    #    Write-Output "[INFO ] $Message"
    Write-Host -ForegroundColor Green $Message
}

Function LogWarn([String]$Message) {
    #    Write-Output "[WARN ] $Message"
    Write-Host -ForegroundColor Yellow $Message
}

Function LogMessage([String]$Message) {
    #    Write-Output "[MSG   ] $Message"
    Write-Host $Message
}
