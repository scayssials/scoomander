$scoopTarget = $env:SCOOP

. "$PSScriptRoot\logger.ps1"

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
        LogMessage "Scoomander $current_version used"
        if ($version -lt $current_version) {
            LogWarn "Current Scoomander version ($current_version) is higher than configuration scoomander version ($version). Aborting..."
            exit
        } elseif ($version -gt $current_version) {
            LogMessage "Updating scoomander to $version accordingly to the configuration..."
            $output = "$env:TEMP\PowerShell_transcript-$((Get-Date).ToFileTime() ).txt"
            write-host $output
            Start-Transcript -path "$output"
            scoop install "scoomander/scoomander@$version"
            Stop-Transcript > $null
            if ((Get-Content -path $output) -match $([RegEx]::Escape("Could not install") )) {
                LogWarn "Error during scoomander update"
                exit
            }
            LogInfo "Scoomander has been updated acordingly to the configuration."
            LogMessage "Re Invoke with the new scoomander version $( $version ):"
            LogMessage ""
            $lastCommand = (Get-History -count 1)
            LogMessage "     $lastCommand"
            Invoke-Expression $lastCommand
            exit
        }
    } else {
        LogWarn "No scoomander version specified in the configuration. Aborting..."
        exit
    }
}
