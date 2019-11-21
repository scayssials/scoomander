# Usage: scoomander list [options]
# Summary: List configurations
# Help:
# scoomander list

Param()

# Import useful scripts
. "$PSScriptRoot\..\lib\logger.ps1"

# Set global variables
$scoopTarget = $env:SCOOP

LogMessage "Scoomander configurations: "
$Folders = Get-ChildItem "$scoopTarget\persist\scoomander\config\" -Directory -Name
foreach ($Folder in $Folders) {
    $Folder = Split-Path -Path $Folder -Leaf
    LogMessage " * $Folder"
}
; Break
