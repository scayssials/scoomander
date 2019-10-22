# Usage: devenv config [options]
# Summary: Devenv configuration Management
# Help:
# devenv config add [-name <String>]* [-url <String>]* [-branch <String>] [-force]
# devenv config remove [-name <String>]* [-force]
# devenv config update [-name <String>]* [-force]
# devenv config apply [-name <String>]*
# devenv config unapply [-name <String>]*
# devenv config list

Param(
    [String]
    $action,
    [String]
    $name,
    [String]
    $url,
    [String]
    $branch="current",
    [Switch]
    $force
)

# Import usefull scripts
. "$PSScriptRoot\..\lib\logger.ps1"

# Set global variables
$scoopTarget = $env:SCOOP

Function TakeDecision([String]$question, [String]$cancelMessage) {
    LogMessage ""
    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
    return $Host.UI.PromptForChoice($message, $question, $choices, 1)
}

Function GetConfigPath([String]$configName) {
    return "$scoopTarget\persist\devenv\config\$configName"
}

Function IsConfigInstalled([String]$configName) {
    return Test-Path -LiteralPath $( GetConfigPath $configName )
}

Function EnsureConfigInstalled([String]$configName) {
    if (-Not (IsConfigInstalled $configName)) {
        LogWarn "The configuration '$configName' do not exist."
        devenv test list
        exit 1
    }
}

Function m_apply([String]$configName) {
    if (!$configName) {
        LogWarn "name is mandatory."
        LogMessage ""
        LogMessage "Usage: devenv config apply <name>"
        LogMessage ""
        return
    }
    EnsureConfigInstalled $configName
    #load API
    . "$PSScriptRoot\..\API\configAPI.ps1"
    . "$PSScriptRoot\..\config\$configName\main.ps1" "apply"
}

Function m_unapply([String]$configName) {
    if (!$configName) {
        LogWarn "name is mandatory."
        LogMessage ""
        LogMessage "Usage: devenv config unapply <name>"
        LogMessage ""
        return
    }
    EnsureConfigInstalled $configName
    #load API
    . "$PSScriptRoot\..\API\configAPI.ps1"
    . "$PSScriptRoot\..\config\$configName\main.ps1" "unapply"
}

Switch ($action) {
    "add" {
        if (!$name -or !$url) {
            LogWarn "name and url are mandatory."
            LogMessage ""
            LogMessage "Usage: devenv config add [-name <String>] [-url <String>] [-branch <String>] [-force]"
            LogMessage ""
            return
        }
        LogMessage "Adding configuration '$name' from repo '$url'."
        # Ask for override if the configuration already exist
        if (IsConfigInstalled $name) {
            if (!$force) {
                LogMessage ""
                $decision = takeDecision "A configuration named '$name' already exist, would you like to override it ?"
                if ($decision -ne 0) {
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
        Pop-Location
        LogInfo "New configuration '$name' was added. "
        LogMessage ""
        LogMessage "You can now use: "
        LogMessage ""
        LogMessage "     devenv config apply $name"
        LogMessage ""
        LogMessage "to install it."
        ; Break
    }
    "remove" {
        if (!$name) {
            LogWarn "name is mandatory."
            LogMessage ""
            LogMessage "Usage: devenv config remove [-name <String>] [-force]"
            LogMessage ""
            return
        }
        EnsureConfigInstalled $name
        if (!$force) {
            LogMessage ""
            $decision = takeDecision "Do you really want to remove the configuration '$name'? Be sure to unapply it before delete it."
            if ($decision -ne 0) {
                LogWarn 'Cancelled'
                return
            }
        }
        Remove-Item "$scoopTarget\persist\devenv\config\$name" -Force -Recurse
        LogInfo "Configuration '$name' was removed."

        ; Break
    }
    "update" {
        if (!$name) {
            LogWarn "name is mandatory."
            LogMessage ""
            LogMessage "Usage: devenv config update <name> [-force]"
            LogMessage ""
            return
        }
        EnsureConfigInstalled $name
        # UnApplyConfiguration
        m_unapply $name
        # Rebase
        LogInfo "Rebasing configuration..."
        Push-Location $( GetConfigPath $name )
        git add .
        git commit -a -m "Snapshot of the configuration"
        git fetch origin
        if ($force) {
            git rebase -Xours origin/master
        }
        else {
            git rebase origin/master
            $decision = takeDecision "Is your configuration rebased ?"
            if ($decision -ne 0) {
                LogWarn 'Trying to reset configuration to previous snapshot.'
                git rebase --abort
                git reset --hard
            }
        }
        m_apply $name
        Pop-Location
        ; Break
    }
    "apply" {
        m_apply $name
        ; Break
    }
    "unapply" {
        m_unapply $name
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
    default {
        Invoke-Expression "$PSScriptRoot\devenv-help.ps1 $cmd"
    }
}
