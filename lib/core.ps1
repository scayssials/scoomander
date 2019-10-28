. "$PSScriptRoot\logger.ps1"

function core_UpdateEnvironmentVariable([String]$Name, [String]$Value) {
    $currentValue = [environment]::GetEnvironmentVariable($Name)
    if ($Value) {
        if ($currentValue) {
            if ($currentValue -ne $Value) {
                LogMessage "Environment variable '$Name' value was '$currentValue', set to '$Value'"
                [environment]::SetEnvironmentVariable($Name, $Value, 'User')
                [environment]::SetEnvironmentVariable($Name, $Value, 'Process')
            } else {
                LogMessage "Environment variable '$Name' value is already set to '$Value'"
            }
        } else {
            LogMessage "Environment variable '$Name' value was undefined, set to '$Value'"
            [environment]::SetEnvironmentVariable($Name, $Value, 'User')
            [environment]::SetEnvironmentVariable($Name, $Value, 'Process')
        }
    } else {
        if ($currentValue) {
            LogMessage "Environment variable '$Name' removed, previous value was '$currentValue'"
            [environment]::SetEnvironmentVariable($Name, $null, 'User')
            [environment]::SetEnvironmentVariable($Name, $null, 'Process')
        } else {
            LogMessage "Environment variable '$Name' value is already undefined"
        }
    }
}

function core_RemoveEnvironmentVariable([String]$Name, [String]$Value) {
    $currentValue = [environment]::GetEnvironmentVariable($Name)
    if ($Value) {
        if ($currentValue) {
            if ($currentValue -ne $Value) {
                LogMessage "Environment variable '$Name' value was '$currentValue' and not '$Value'"
            } else {
                LogMessage "Environment variable '$Name' value removed"
                [environment]::SetEnvironmentVariable($Name, $null, 'User')
                [environment]::SetEnvironmentVariable($Name, $null, 'Process')
            }
        } else {
            LogMessage "Environment variable '$Name' value was undefined, nothing to remove"
        }
    } else {
        if ($currentValue) {
            LogMessage "Environment variable '$Name' removed, previous value was '$currentValue'"
            [environment]::SetEnvironmentVariable($Name, $null, 'User')
            [environment]::SetEnvironmentVariable($Name, $null, 'Process')
        } else {
            LogMessage "Environment variable '$Name' value is already undefined"
        }
    }
}

function core_installPlugin([String]$Name, [String]$ScriptFile) {
    if ($Name) {
        if ($ScriptFile) {
            if (Test-Path -path $ScriptFile) {
                Copy-Item "$ScriptFile" -Destination "$( scoop prefix devenv )/plugins/devenv-$Name.ps1"
                LogMessage "$Name plugin added to the devenv."
                LogMessage "Use it with the command 'devenv $Name'."
            } else {
                LogWarn "No plugin script found for '$Name' in '$ScriptFile'."
            }
        } else {
            LogWarn "No plugin script specified for '$Name'."
        }
    } else {
        LogWarn "No plugin name specified."
    }
}

function core_uninstallPlugin([String]$Name) {
    if ($Name) {
        if (Test-Path -path "$( scoop prefix devenv )/plugins/devenv-$Name.ps1") {
            Remove-Item "$( scoop prefix devenv )/plugins/devenv-$Name.ps1" -Force
            LogMessage "$Name plugin uninstalled from"
        } else {
            LogWarn "Impossible to uninstall plugin $Name. No plugin with the name '$Name' found."
        }
    }
    else {
        LogWarn "No plugin name specified."
    }
}
