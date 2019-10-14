param()

Function IsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
}

Function ExecuteScript([switch] $RequireAdmin, [String]$Message, [ScriptBlock]$UpdateScript) {
    if ($RequireAdmin -And (IsAdmin) -Or !($RequireAdmin)) {
        LogUpdate $Message
        & $UpdateScript
    } else {
        LogWarn "Update requires administrator privileges: $Message"
    }
}
