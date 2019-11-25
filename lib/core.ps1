$scoopTarget = $env:SCOOP

. "$PSScriptRoot\logger.ps1"
. "$( scoop prefix scoop )\lib\versions.ps1"
. "$( scoop prefix scoop )\lib\core.ps1"
. "$( scoop prefix scoop )\lib\install.ps1"

<#
Ask a yes no question and return the prompted response
 #>
Function TakeDecision([String]$title) {
    $Prompt = "Enter your choice"
    $Choices = [System.Management.Automation.Host.ChoiceDescription[]]@("&Yes", "&No")
    $Default = 1
    return $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
}

<#
Return the absolute path of a configuration
 #>
Function GetConfigPath([String]$configName) {
    return "$scoopTarget\persist\scoomander\config\$configName"
}

<#
Check that a configuration is installed in the config directory.
 #>
Function IsConfigInstalled([String]$configName) {
    return Test-Path -LiteralPath $( GetConfigPath $configName )
}

<#
Ensure that a configuration is installed in the config directory. If not, it warn
this add a warning and list all installed configuration
 #>
Function EnsureConfigInstalled([String]$configName) {
    if (-Not(IsConfigInstalled $configName)) {
        LogWarn "Configuration '$configName' do not exist."
        scoomander config list
        exit 1
    }
}

<#
Invokes an external utility (program) and, if the utility indicates failure by
way of a nonzero exit code, throws a script-terminating error.
* Pass the command the way you would execute the command directly.
* Do NOT use & as the first argument if the executable name is not a literal.

.EXAMPLE
Invoke-Utility git push

Executes `git push` and throws a script-terminating error if the exit code
is nonzero.
 #>
function Invoke-Utility {
    $exe, $argsForExe = $Args
    $ErrorActionPreference = 'Stop' # in case $exe isn't found
    & $exe $argsForExe
    if ($LASTEXITCODE) { Throw "$exe indicated failure (exit code $LASTEXITCODE; full command: $Args)." }
}

<#
Invoke a script block without git http.sslVerify
#>
function DoUnverifiedSslGitAction([ScriptBlock]$script) {
    $sslVerify = git config --global --get http.sslVerify
    git config --global http.sslVerify false
    & $script
    git config --global --unset http.sslVerify
    git config --global http.sslVerify $sslVerify
}

function isAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
}

function runElevated([String[]]$params, [ScriptBlock]$command) {
    If (-NOT(isAdmin)) {
        $params = "'" + [system.String]::Join("', '", $params) + "'"
        Start-Process powershell -Verb RunAs -ArgumentList "-command invoke-command -scriptblock {$command} -argumentlist $params" -Wait
    } else {
        Invoke-Command -scriptblock $command -argumentlist $params
    }
}

Function EnsureScoomanderVersion($configPath) {
    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json
    if ($scoopConf.scoomander -and $scoopConf.scoomander.version) {
        LogUpdate "Check Scoomander version..."
        $( (Get-Item "$PSScriptRoot\..").Target ) -match '(?<version>[^\\]+$)' > $null
        $version = [System.Version]::Parse($scoopConf.scoomander.version)
        $current_version = [System.Version]::Parse($matches['version'])
        cleanupScoomander $current_version
        if ($version -eq $current_version) {
            LogMessage "Scoomander $current_version used"
        } else {
            LogMessage "Updating scoomander to $version accordingly to the configuration..."
            exec {
                scoop install "scoomander/scoomander@$version"
            } -catchOutput "Could not install" -exit
            LogInfo "Scoomander has been updated acordingly to the configuration."
            LogMessage "Re Invoke to use the right scoomander version:"
            LogMessage ""
            LogMessage "     $global_command"
            exit
        }
    } else {
        LogWarn "No scoomander version specified in the configuration. Aborting..."
        exit
    }
}

# taken from scoop versions.ps1
function cleanupScoomander($current_version) {
    $versions = versions "scoomander " $global | Where-Object { $_ -ne $current_version -and $_ -ne 'current' }
    if (!$versions) {
        return
    }
    write-host -f yellow "Removing scoomander`:" -nonewline
    $versions | ForEach-Object {
        $version = $_
        write-host " $version" -nonewline
        $dir = versiondir "scoomander" $version $global
        # unlink all potential old link before doing recursive Remove-Item
        unlink_persist_data $dir
        Remove-Item $dir -ErrorAction Stop -Recurse -Force
    }
    write-host ''
}

function link_file($source, $target) {
    write-host "Linking $source => $target"
    # create link
    if (is_directory $target) {
        # target is a directory, create junction
        & "$env:COMSPEC" /c "mklink /j `"$source`" `"$target`"" | out-null
        attrib $source +R /L
    } else {
        # target is a file, create hard link
        & "$env:COMSPEC" /c "mklink /h `"$source`" `"$target`"" | out-null
    }
}

function unlink_file($dir) {
    write-host "Un-Linking $dir"
    $file = Get-Item $dir
    if ($null -ne $file.LinkType) {
        $filepath = $file.FullName
        # directory (junction)
        if ($file -is [System.IO.DirectoryInfo]) {
            # remove read-only attribute on the link
            attrib -R /L $filepath
            # remove the junction
            & "$env:COMSPEC" /c "rmdir /s /q `"$filepath`""
        } else {
            # remove the hard link
            & "$env:COMSPEC" /c "del `"$filepath`""
        }
    }
}

function exec() {
    param(
        [ScriptBlock]
        $command,
        [String]
        $catchOutput = "error",
        [Switch]
        $retry,
        [Switch]
        $exit
    )
    try {
        $commandToString = $executioncontext.invokecommand.expandstring($command).Trim()
        write-host $commandToString
        throwOnTextOutput $catchOutput "'$catchOutput' message was catched during the execution of:
    $commandToString" $command
    } catch {
        if ($retry) {
            write-host $_
            $Choices = [System.Management.Automation.Host.ChoiceDescription[]]@("&Retry", "&Continue", "&Exit")
            $Default = 1
            $decision = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
            if ($decision -eq 0) {
                exec $command $catchOutput -retry
            } elseif ($decision -eq 2) {
                write-host 'exiting...'
                exit
            }
        } elseif ($exit) {
            write-host $_
            exit
        } else {
            throw $_
        }
    }
}

function throwOnTextOutput([String]$message, [String]$error, [ScriptBlock]$command) {
    $output = "$env:TEMP\PowerShell_transcript-$((Get-Date).ToFileTime() ).txt"
    Start-Transcript -path "$output" > $null
    try {
        & $command
        if ((Get-Content -path $output) -match $([RegEx]::Escape($message) )) {
            Throw "$error
more infos:
    $output"
        }
    } catch {
        throw $_
    } finally {
        Stop-Transcript > $null
    }
}

function askForRetryOnError([ScriptBlock]$script) {
    try {
        & $script
    } catch {
        write-host $_
        $Choices = [System.Management.Automation.Host.ChoiceDescription[]]@("&Retry", "&Continue", "&Exit")
        $Default = 1
        $decision = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
        if ($decision -eq 0) {
            askForRetryOnError $script
            return
        } elseif ($decision -eq 2) {
            write-host 'exiting...'
            exit
        }
    }
}
