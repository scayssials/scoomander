# Usage: scoomander config add|list|rm [<args>]
# Summary: Add, list or remove configs.
# Help:
# Configurations are repositories of scoomander configurations.
# Scoomander comes without any configuration
# Configurations are installed in scoop\persist\scoomander\config
#
# To add a configuration:
#
#     scoomander config add -name <String> -url <String> [-branch <String>] [-force]
#     [-branch <String>]: to checkout the configuration in a specific branch. (master is checkouted by default, and a new branch current is created from it)
#     [-force] : force override of a configuration with the same name
#
# To remove a configuration:
#
#     scoomander config rm -name <String> [-force]
#     [-force] : do not ask permission
#
# To list all added configurations:
#
#     scoomander config list

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
    $force
)

# Import useful scripts
. "$PSScriptRoot\..\lib\logger.ps1"
. "$PSScriptRoot\..\lib\core.ps1"

# Set global variables
$scoopTarget = $env:SCOOP

Switch ($action) {
    { @("add", "rm") -contains $_ } {
        if (!$name) {
            LogWarn "<name> missing"
            LogMessage ""
            LogMessage "Usage: scoomander config $_ <name>"
            LogMessage ""
            return
        }
    }
    "add" {
        # Ask for override if the configuration already exist
        if (IsConfigInstalled $name) {
            if (!$force) {
                $decision = takeDecision "A configuration named '$name' already exist, would you like to override it ?"
                if ($decision -ne 0) {
                    LogWarn 'Cancelled'
                    return
                }
            }
            Remove-Item "$scoopTarget\persist\scoomander\config\$name" -Force -Recurse
            LogInfo "Old configuration '$name' was erased."
        }
        # Clone configuration and checkout to the specified branch
        try {
            DoUnverifiedSslGitAction {
                Invoke-Utility git lfs install
                Invoke-Utility git clone $url "$scoopTarget\persist\scoomander\config\$name"
            }
        }
        catch {
            LogWarn "Impossible to Clone '$url' to '$scoopTarget\persist\scoomander\config\$name'. Check the error message and your git configuration."
            throw
        }
        Push-Location "$scoopTarget\persist\scoomander\config\$name"
        if ($branch) {
            $exist = git rev-parse --verify --quiet $branch
            if (!$exist) {
                LogWarn "Specified branch '$branch' do not exist."
            }
            else {
                git checkout $branch
            }
        }
        $currentExist = git rev-parse --verify --quiet "current"
        if (!$currentExist) {
            git checkout -b "current"
        } else {
            LogWarn "'current' branch already exist."
        }
        Pop-Location
        LogInfo "Configuration '$name' was added."
        LogMessage "You can now use: "
        LogMessage ""
        LogMessage "     scoomander apply $name"
        LogMessage ""
        LogMessage "to install it."
        ; Break
    }
    "rm" {
        if (!$force) {
            $decision = takeDecision "Do you really want to remove the configuration '$name'? Be sure to unapply it before delete it."
            if ($decision -ne 0) {
                LogWarn 'Remove configuration cancelled.'
                return
            }
        }
        Remove-Item "$scoopTarget\persist\scoomander\config\$name" -Force -Recurse
        LogMessage ""
        LogInfo "Configuration '$name' was removed."
        ; Break
    }
    "list" {
        LogMessage "Installed Scoomander configurations: "
        $Folders = Get-ChildItem "$scoopTarget\persist\scoomander\config\" -Directory -Name
        foreach ($Folder in $Folders) {
            $Folder = Split-Path -Path $Folder -Leaf
            LogMessage " * $Folder"
        }
        ; Break
    }
    default {
        Invoke-Expression "$PSScriptRoot\scoomander-help.ps1 $cmd"
    }
}
