. "$PSScriptRoot\logger.ps1"

<#
Update an environment variable or create it if necessary
Environment variable are setted in the current process and in the user

.EXAMPLE
devenvUtils_UpdateEnvironmentVariable PUTTY_HOME C:/scoop/app/putty/current
 #>
function devenvUtils_UpdateEnvironmentVariable([String]$Name, [String]$Value) {
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

<#
Remove an environment variable if it exist with the matched value
if the value is null, remove the env var

.EXAMPLE
devenvUtils_RemoveEnvironmentVariable PUTTY_HOME C:/scoop/app/putty/current
or
devenvUtils_RemoveEnvironmentVariable PUTTY_HOME
 #>
function devenvUtils_RemoveEnvironmentVariable([String]$Name, [String]$Value) {
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

<#
Install a devenv plugin
The plugin can then be called by running devenv <pluginName>

.EXAMPLE
devenvUtils_installPlugin setJavaHome C:/...../setJavaHome.ps1

Then, by calling devenv setJavaHome, the script setJavaHome.ps1 will be called
 #>
function devenvUtils_installPlugin([String]$Name, [String]$ScriptFile) {
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

<#
Remove the mentionned plugin

.EXAMPLE
devenvUtils_removePlugin setJavaHome
 #>
function devenvUtils_removePlugin([String]$Name) {
    if ($Name) {
        if (Test-Path -path "$( scoop prefix devenv )/plugins/devenv-$Name.ps1") {
            Remove-Item "$( scoop prefix devenv )/plugins/devenv-$Name.ps1" -Force
            LogMessage "$Name plugin removed"
        } else {
            LogWarn "Impossible to remove plugin $Name. No plugin with the name '$Name' found."
        }
    }
    else {
        LogWarn "No plugin name specified."
    }
}

<#
Store the version used to apply extras
return true if the value has been updated
Can be used to now if an extra should be applied or not
 #>
function devenvUtils_updateExtraVersion([String]$persist_dir, [String]$version) {
    if (Test-Path -LiteralPath "$persist_dir/.version") {
        $currentVersion = Get-Content -Path "$persist_dir/.version"
        if ($currentVersion -eq $version) {
            LogMessage "The latest version of extra already installed"
            return $false
        } else {
            LogUpdate "Updating extra version from $currentVersion to $version"
            Set-Content "$persist_dir/.version" -Value $version
            return $true
        }
    } else {
        LogUpdate "Creating extra version $version"
        New-Item -ItemType File -Path "$persist_dir/.version" -Force
        Set-Content "$persist_dir/.version" -Value $version
        return $true
    }
}

<#
Remove the stored version
 #>
function devenvUtils_removeExtraVersion([String]$persist_dir) {
    Remove-Item "$persist_dir/.version" -Force
}
