# Usage: devenv config [options]
# Summary: Devenv configuration Management
# Help:
# devenv config add -name <String> -url <String> [-branch <String>] [-force]
# devenv config remove -name <String> [-force]
# devenv config update -name <String> [-force]
# devenv config apply -name <String> [-appNames <String>*]
# devenv config unapply -name <String> [-force] [-appNames <String>*]
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
    [String[]]
    $appNames
)

# Import useful scripts
. "$PSScriptRoot\..\lib\logger.ps1"
. "$PSScriptRoot\..\lib\core.ps1"

# Set global variables
$scoopTarget = $env:SCOOP
$configPath = "$PSScriptRoot\..\config\$name"

Function EnsureDevenvVersion() {
    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json
    if ($scoopConf.devenv -and $scoopConf.devenv.version) {
        LogUpdate "Check Devenv version..."
        $( (Get-Item "$PSScriptRoot\..").Target ) -match '(?<version>[^\\]+$)' > $null
        $version = [System.Version]::Parse($scoopConf.devenv.version)
        $version = [System.Version]::Parse("1.04")
        $current_version = [System.Version]::Parse($matches['version'])
        LogMessage "Devenv $current_version used"
        if ($version -lt $current_version) {
            LogWarn "Current devenv version ($current_version) is higher than configuration devenv version ($version). Aborting..."
            exit
        } elseif ($version -gt $current_version) {
            LogMessage "Updating devenv to $version accordingly to the configuration..."
            $output = "$env:TEMP\PowerShell_transcript-$((Get-Date).ToFileTime()).txt"
            write-host $output
            Start-Transcript -path "$output"
            scoop install "devenv/devenv@$version"
            Stop-Transcript > $null
            if ((Get-Content -path $output) -match $([RegEx]::Escape("Could not install"))) {
                LogWarn "Error during devenv update"
                exit
            }
            LogInfo "Devenv has been updated acordingly to the configuration."
            LogMessage "Re Invoke with the new devenv version $( $version ):"
            LogMessage ""
            Invoke-History
            exit
        }
    } else {
        LogWarn "No devenv version specified in the configuration. Aborting..."
        exit
    }
}

Switch ($action) {
    { @("add", "apply", "unapply", "remove", "update") -contains $_ } {
        if (!$name) {
            LogWarn "name is mandatory."
            LogMessage ""
            LogMessage "Usage: devenv config $_ <name>"
            LogMessage ""
            return
        }
    }
    { @("apply", "unapply", "update") -contains $_ } {
        EnsureConfigInstalled $name
        # update scoop / update all buckets
        DoUnverifiedSslGitAction {
            scoop update
        }
        EnsureDevenvVersion
    }
    "apply" {
        . "$PSScriptRoot\..\API\configAPI.ps1" $name $force
        . "$configPath\main.ps1" -mode "apply" -appNames $appNames
        ; Break
    }
    "unapply" {
        . "$PSScriptRoot\..\API\configAPI.ps1" $name $force
        . "$configPath\main.ps1" -mode "unapply" -appNames $appNames
        ; Break
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
            Remove-Item "$scoopTarget\persist\devenv\config\$name" -Force -Recurse
            LogInfo "Old configuration '$name' was erased."
        }
        # Clone configuration and checkout to the specified branch
        try {
            DoUnverifiedSslGitAction {
                Invoke-Utility git lfs install
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
    "list" {
        LogMessage "Installed devenv configurations: "
        $Folders = Get-ChildItem "$scoopTarget\persist\devenv\config\" -Directory -Name
        foreach ($Folder in $Folders) {
            $Folder = Split-Path -Path $Folder -Leaf
            LogMessage " * $Folder"
        }
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
    default {
        Invoke-Expression "$PSScriptRoot\devenv-help.ps1 $cmd"
    }
}
