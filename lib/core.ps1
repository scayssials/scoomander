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
    return "$scoopTarget\persist\devenv\config\$configName"
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
        LogWarn "The configuration '$configName' do not exist."
        devenv config list
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
function UnverifySslGitAction([ScriptBlock]$script){
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
        Start-Process powershell -Verb RunAs -ArgumentList "-noexit -command invoke-command -scriptblock {$command} -argumentlist $params"
    } else {
        Invoke-Command -scriptblock $command -argumentlist $params
    }
}
