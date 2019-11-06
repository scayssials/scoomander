# Usage: devenv config [options]
# Summary: Devenv configuration Management
# Help:
# devenv config add [-name <String>]* [-url <String>]* [-branch <String>] [-force]
# devenv config remove [-name <String>]* [-force]
# devenv config update [-name <String>]* [-force]
# devenv config apply [-name <String>]* [-appName <String>]*
# devenv config unapply [-name <String>] [-force]* [-appName <String>]*
# devenv config list

Param(
    [String]
    $action,
    [String]
    $name,
    [String]
    $url,
    [String]
    $branch = "current",
    [Switch]
    $force,
    [String]
    $appName
)

# Import useful scripts
. "$PSScriptRoot\..\lib\logger.ps1"
. "$PSScriptRoot\..\lib\core.ps1"

# Set global variables
$scoopTarget = $env:SCOOP

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
    . "$PSScriptRoot\..\API\configAPI.ps1" $configName $force
    . "$PSScriptRoot\..\config\$configName\main.ps1" -mode "apply" -appName $appName
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
    . "$PSScriptRoot\..\API\configAPI.ps1" $configName $force
    . "$PSScriptRoot\..\config\$configName\main.ps1" -mode "unapply" -appName $appName
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
        # Ask for override if the configuration already exist
        if (IsConfigInstalled $name) {
            if (!$force) {
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
        try {
            UnverifySslGitAction {
                Invoke-Utility git clone $url "$scoopTarget\persist\devenv\config\$name"
            }
        }
        catch {
            LogWarn "Impossible to Clone '$url' to '$scoopTarget\persist\devenv\config\$name'. Check the error message and your git configuration."
            throw
        }
        Push-Location "$scoopTarget\persist\devenv\config\$name"
        $exist = git rev-parse --verify --quiet $branch
        if (!$exist) { git checkout -b $branch }
        else { git checkout $branch }
        Pop-Location
        LogInfo "Configuration '$name' was added."
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
            $decision = takeDecision "Do you really want to remove the configuration '$name'? Be sure to unapply it before delete it."
            if ($decision -ne 0) {
                LogWarn 'Remove configuration cancelled.'
                return
            }
        }
        Remove-Item "$scoopTarget\persist\devenv\config\$name" -Force -Recurse
        LogMessage ""
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
        # Rebase
        LogInfo "Rebasing configuration..."
        Push-Location $( GetConfigPath $name )
        git add .
        git commit -a -m "[Devenv Update] Configuration Snapshot"
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
