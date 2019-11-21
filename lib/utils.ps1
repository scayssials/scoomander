. "$PSScriptRoot\logger.ps1"
. "$( scoop prefix scoop )\lib\shortcuts.ps1"
. "$( scoop prefix scoop )\lib\decompress.ps1"

<#
Update an environment variable or create it if necessary
Environment variable are setted in the current process and in the user

.EXAMPLE
scoomanderUtils_UpdateEnvironmentVariable PUTTY_HOME C:/scoop/app/putty/current
 #>
function scoomanderUtils_UpdateEnvironmentVariable([String]$Name, [String]$Value) {
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
scoomanderUtils_RemoveEnvironmentVariable PUTTY_HOME C:/scoop/app/putty/current
or
scoomanderUtils_RemoveEnvironmentVariable PUTTY_HOME
 #>
function scoomanderUtils_RemoveEnvironmentVariable([String]$Name, [String]$Value) {
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
Install a scoomander plugin
The plugin can then be called by running scoomander <pluginName>

.EXAMPLE
scoomanderUtils_installPlugin setJavaHome C:/...../setJavaHome.ps1

Then, by calling scoomander setJavaHome, the script setJavaHome.ps1 will be called
 #>
function scoomanderUtils_installPlugin([String]$Name, [String]$ScriptFile) {
    if ($Name) {
        if ($ScriptFile) {
            if (Test-Path -path $ScriptFile) {
                Copy-Item "$ScriptFile" -Destination "$( scoop prefix scoomander )/plugins/scoomander-$Name.ps1"
                LogMessage "$Name plugin added to the scoomander."
                LogMessage "Use it with the command 'scoomander $Name'."
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
scoomanderUtils_removePlugin setJavaHome
 #>
function scoomanderUtils_removePlugin([String]$Name) {
    if ($Name) {
        if (Test-Path -path "$( scoop prefix scoomander )/plugins/scoomander-$Name.ps1") {
            Remove-Item "$( scoop prefix scoomander )/plugins/scoomander-$Name.ps1" -Force
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
function scoomanderUtils_updateExtraVersion([String]$persist_dir, [String]$version) {
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
function scoomanderUtils_removeExtraVersion([String]$persist_dir) {
    Remove-Item "$persist_dir/.version" -Force
}

function scoomanderUtils_addMenuShortcut([System.IO.FileInfo]$target, $shortcutName, [System.IO.FileInfo]$icon) {
    startmenu_shortcut $target $shortcutName "" $icon
}

function scoomanderUtils_rmMenuShortcut($shortcutName) {
    $shortcut = "$(shortcut_folder)\$shortcutName.lnk"
    write-host "Removing shortcut $shortcut"
    if (Test-Path -Path $( friendly_path $shortcut )) {
        Remove-Item $( friendly_path $shortcut )
    }
}

function scoomanderUtils_addCommand($commandPath, $name) {
    write-host "Creating shim $name for $commandPath"
    shim $commandPath $null $name
}

function scoomanderUtils_rmCommand($name) {
    rm_shim $name $(shimdir)
}

function scoomanderUtils_decompress([String]$fileName, [String]$extract_to, [String]$extract_dir) {
    # work out extraction method, if applicable
    if (((get_config 7ZIPEXTRACT_USE_EXTERNAL) -and (Test-CommandAvailable 7z)) -or (Test-HelperInstalled -Helper 7zip)) {
        $extract_fn = 'Expand-7zipArchive'
    } else {
        $extract_fn = 'Expand-ZipArchive'
    }

    if ($extract_fn) {
        Write-Host "Extracting " -NoNewline
        Write-Host $fileName -f Cyan -NoNewline
        Write-Host " ... " -NoNewline
        if ($extract_dir) {
            & $extract_fn -Path "$fileName" -DestinationPath $extract_to -ExtractDir $extract_dir
        } else {
            & $extract_fn -Path "$fileName" -DestinationPath $extract_to
        }
        Write-Host "done." -f Green
        $extracted++
    }
}
