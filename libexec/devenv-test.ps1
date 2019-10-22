# Usage: devenv config [options]
# Summary: Devenv configuration Management
# Help:
# devenv config --install --url <git-url> --name <config-name>
# devenv config --remove --name <config-name>
# devenv config --apply --name <config-name>
# devenv config --update --name <config-name>
# devenv config --update --name <config-name> [--force]
# devenv config --list

Param(
    [String]
    $action,
    [String]
    $name,
    [String]
    $url,
    [String]
    $branch,
    [Switch]
    $force,
    [Switch]
    $control
)

# Import usefull scripts
. "$PSScriptRoot\..\lib\logger.ps1"

# Set global variables
$scoopTarget = $env:SCOOP

Function TakeDecision([String]$question) {
    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
    if ($decision -ne 0) {
        return $false
    }
    return $true
}

Switch ($action) {
    "add" {
        if (!$name -or !$url) {
            LogWarn "name and url are mandatory."
            LogMessage ""
            LogMessage "Usage: devenv config add  [-name <String>] [-url <String>] [-branch <String>] [-force]"
            LogMessage ""
            return
        }
        LogMessage "Adding configuration '$name' from repo '$url'."
        # Ask for override if the configuration already exist
        if (Test-Path -LiteralPath "$scoopTarget\persist\devenv\config\$name") {
            if (!$force) {
                LogMessage ""
                $decision = takeDecision "A configuration named '$name' already exist, would you like to override it ?"
                if (!$decision) {
                    LogWarn 'Cancelled'
                    return
                }
            }
            Remove-Item "$scoopTarget\persist\devenv\config\$name" -Force -Recurse
            LogInfo "Old configuration '$name' was erased."
        }
        # Clone configuration and checkout to the specified branch
        git clone $url "$scoopTarget\persist\devenv\config\$name"
        Push-Location "$scoopTarget\persist\devenv\config\$name"
        if ($branch) {
            $exist = git rev-parse --verify --quiet $branch
            if (!$exist) { git checkout -b $branch }
            else { git checkout $branch }
        }
        # Usefull if lfs is not configured to automatically checkout pointed files
        git lfs pull
        Pop-Location
        LogInfo "New configuration '$name' was added."
        ; Break
    }
    "remove" {
        Write-Host "Usage: devenv config remove <name> [-force]"
        ; Break
    }
    "update" {
        Write-Host "Usage: devenv config update <name> [-force]"
        ; Break
    }
    "apply" {
        Write-Host "Usage: devenv config apply <name> [-control]"
        ; Break
    }
    "unapply" {
        Write-Host "Usage: devenv config unapply <name>"
        ; Break
    }
    "list" {
        LogMessage "List all devenv configuration by names: "
        $Folders = Get-ChildItem "$scoopTarget\persist\devenv\config\" -Directory -Name
        foreach ($Folder in $Folders) {
            $Folder = Split-Path -Path $Folder -Leaf
            LogMessage " * $Folder"
        }
        ; Break
    }
    "check" {
        Write-Host "Usage: devenv config check <name>"
        ; Break
    }
    default {
        Invoke-Expression "$PSScriptRoot\devenv-help.ps1 $cmd"
    }
}
