param($configName, $force)

$scoopRootDir = scoop prefix scoop
. "$scoopRootDir\lib\core.ps1"
. "$scoopRootDir\lib\buckets.ps1"
. "$scoopRootDir\lib\manifest.ps1"
. "$scoopRootDir\lib\versions.ps1"
. "$scoopRootDir\lib\install.ps1"
. "$PSScriptRoot\..\lib\utils.ps1"
. "$PSScriptRoot\..\lib\core.ps1"

enum ApplyType {
    PostInstall
    PreUpdate
    PostUpdate
    CleanUp
    Idem
}

Function ApplyConfigurationFile([String]$configPath, [string[]]$appNames) {
    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json
    $extrasPath = "$configPath\extras"
    # install buckets
    foreach ($bucketSpec in $scoopConf.buckets) {
        if ($bucketSpec -ne "" -and !($bucketSpec -like "#*")) {
            InstallScoopBucket $bucketSpec $configPath
        }
    }
    # install specs
    foreach ($installSpec in $scoopConf.install) {
        if ($installSpec -ne "" -and !($installSpec -like "#*")) {
            if ($installSpec -match '(?<type>[^:]+):(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<name>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $type, $name, $version, $appBucket = $matches['type'], $matches['name'], $matches['version'], $matches['bucket']
                if (!$appNames -or $appNames.Contains($name)) {
                    if ($type -eq "extra") {
                        InstallExtra $installSpec $name $version $extrasPath
                    } elseif ($type -eq "app") {
                        InstallApp $installSpec $name $version $appBucket $extrasPath
                    } else {
                        LogWarn "$type is not a supported type. ($installSpec)"
                    }
                }
            }
        }
    }
    # uninstall local buckets to clean up scoop
    foreach ($bucketSpec in $scoopConf.buckets) {
        if ($bucketSpec -ne "" -and !($bucketSpec -like "#*")) {
            if ($bucketSpec -match "^([^@]+)(@(.+))?$") {
                $bucketName = $Matches[1]
                $bucketRepo = $Matches[3]
                if ($bucketRepo -eq "local") {
                    unlink_file "$env:SCOOP\buckets\$bucketName"
                }
            }
        }
    }
}

Function UnapplyConfigurationFile([String]$configPath, [string[]]$appNames) {
    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json
    $extrasPath = "$configPath\extras"
    # uninstall specs
    [array]::Reverse($scoopConf.install)
    foreach ($installSpec in $scoopConf.install) {
        if ($installSpec -ne "" -and !($installSpec -like "#*")) {
            if ($installSpec -match '(?<type>[^:]+):(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<name>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $type, $name, $version, $bucket = $matches['type'], $matches['name'], $matches['version'], $matches['bucket']
                if (!$appNames -or $appNames.Contains($name)) {
                    if ($type -eq "extra") {
                        RemoveExtra $name $version $extrasPath
                    } elseif ($type -eq "app") {
                        RemoveApp $name $bucket $extrasPath
                    } else {
                        LogWarn "$type is not a supported type. ($installSpec)"
                    }
                }
            }
        }
    }
}

Function RemoveExtra([String]$name, [String]$version, [String]$extraPath) {
    if (!$force) {
        $decision = takeDecision "The extras '$name' will be cleanedUp. Do you want to continue?"
        if ($decision -ne 0) {
            LogWarn 'Cancelled'
            return
        }
    }
    $persist_dir = persistdir $name
    LogUpdate "* UnApplying extra of $name version $version"
    m_applyExtra $extrasPath $name $( [ApplyType]::CleanUp ) $version
    Remove-Item "$persist_dir/.version" -Force -ErrorAction Ignore
}

Function RemoveApp([String]$appName, [String]$appBucket, [String]$extrasPath) {
    LogUpdate "* Unapplying configuration for app '$appName'..."
    if (!$appBucket) {
        $appBucket = "main"
    }
    if (installed $appName) {
        $appConfigName = m_getConfigName $appName
        $from_version = current_version $appName $false
        $install = install_info $appName $from_version
        $currentAppBucket = $install.bucket
        $to_version = latest_version $appName $appBucket
        if ($appConfigName -ne $configName) {
            LogWarn "Scoop app '$( $appName )' wasn't installed by the configuration '$configName' but by the configuration '$appConfigName'. Nothing will be done on the app."
            LogMessage "Use the unappy of the right configuration to uninstall it, or directly by running 'scoop uninstall $appName' (this will not cleanup app extras if there is some)"
            return
        }
        if ($currentAppBucket -ne $appBucket) {
            LogWarn "Scoop app '$appName' is from bucket '$( $install_info.bucket )' but declared in bucket '$appBucket' in the configuration"
            return
        }
        if (!$force) {
            $decision = takeDecision "The scoop app '$appName' will be removed. Do you want to continue?"
            if ($decision -ne 0) {
                LogWarn 'Cancelled'
                return
            }
        }
        m_applyExtra $extrasPath $appName $( [ApplyType]::CleanUp ) $from_version
        scoop uninstall $appName
    } else {
        LogMessage "'$appName' isn't installed."
    }
}

Function InstallApp([String]$appSpec, [String]$appName, [String]$version, [String]$appBucket, [String]$extrasPath) {
    write-host -f Cyan "* $appName$( if ($version) { " $version" } )" -NoNewline
    write-host -f DarkCyan " ($appSpec)"
    if (!$appBucket) {
        $appBucket = "main"
    }
    if (installed $appName) {
        $appConfigName = m_getConfigName $appName
        $from_version = current_version $appName $false
        $install = install_info $appName $from_version
        $currentAppBucket = $install.bucket
        $to_version = latest_version $appName $appBucket
        if ($appConfigName -eq "main") {
            LogWarn "Scoop app '$( $appName )' wasn't installed by the configuration '$configName' but directly by scoop. Add it to the current configuration"
            m_AddConfigName $appName
        }
        elseif ($appConfigName -ne $configName) {
            LogWarn "Scoop app '$( $appName )' wasn't installed by the configuration '$configName' but by the configuration '$appConfigName'. Nothing will be done on the app."
            return
        }
        if ($currentAppBucket -and $currentAppBucket -ne $appBucket) {
            LogWarn "Scoop app '$appName' is from bucket '$( $install_info.bucket )' but declared in bucket '$appBucket' in the configuration"
            return
        }
        if ($version) {
            if ($from_version -eq $version) {
                LogMessage "Version already installed ($from_version)"
                m_applyExtra $extrasPath $appName $( [ApplyType]::Idem ) $to_version
            } else {
                LogInfo "New version specified. Updating $from_version -> $version ..."
                m_applyExtra $extrasPath $appName $( [ApplyType]::PreUpdate ) $version $from_version
                scoop install $appBucket/$appName@$version
                m_applyExtra $extrasPath $appName $( [ApplyType]::PostUpdate ) $version $from_version
                m_AddConfigName $appName
            }
        } else {
            if ($from_version -eq $to_version) {
                LogMessage "Latest version installed ($from_version)"
                m_applyExtra $extrasPath $appName $( [ApplyType]::Idem ) $to_version
            }
            else {
                LogInfo "New version detected. Updating $from_version -> $to_version ..."
                m_applyExtra $extrasPath $appName $( [ApplyType]::PreUpdate ) $to_version $from_version
                scoop update $appName
                m_applyExtra $extrasPath $appName $( [ApplyType]::PostUpdate ) $to_version $from_version
                m_AddConfigName $appName
            }
        }
    }
    else {
        LogUpdate "Install scoop app '$appName'"
        scoop install $appName
        $to_version = current_version $appName $false
        m_applyExtra $extrasPath $appName $( [ApplyType]::PostInstall ) $to_version
        m_AddConfigName $appName
    }
}

Function InstallExtra([String]$extraSpec, [String]$name, [String]$version, [String]$extrasPath) {
    write-host -f Cyan "* $name$( if ($version) { " $version" } )" -NoNewline
    write-host -f DarkCyan " ($extraSpec)"
    $persist_dir = persistdir $name
    # Set current extra version
    $current_version = '0.0'
    if (Test-Path -LiteralPath "$persist_dir/.version") {
        $current_version = Get-Content -Path "$persist_dir/.version"
    } else {
        New-Item -ItemType File -Path "$persist_dir/.version" -Force > $null
        Set-Content "$persist_dir/.version" -Value $current_version
    }
    #determine apply type
    if ($version) {
        if ($current_version -eq '0.0') {
            LogMessage "Installing $name ($version)"
            Set-Content "$persist_dir/.version" -Value $version
            m_applyExtra $extrasPath $name $( [ApplyType]::PostInstall ) $version
        }
        elseif ($current_version -eq $version) {
            LogMessage "Latest version installed ($current_version)"
            m_applyExtra $extrasPath $name $( [ApplyType]::Idem ) $version
        } else {
            LogUpdate "New version detected. Updating $current_version -> $version ..."
            m_applyExtra $extrasPath $name $( [ApplyType]::PreUpdate ) $version $current_version
            Set-Content "$persist_dir/.version" -Value $version
            m_applyExtra $extrasPath $name $( [ApplyType]::PostUpdate ) $version $current_version
        }
    } else {
        LogMessage "$name extras detected with no version. Installing it as new extra (v0.0)"
        Set-Content "$persist_dir/.version" -Value $current_version
        m_applyExtra $extrasPath $name $( [ApplyType]::PostInstall ) $version
    }
}

Function InstallScoopBucket($bucketSpec, $configPath) {
    if ($bucketSpec -match "^([^@]+)(@(.+))?$") {
        $bucketName = $Matches[1]
        $bucketRepo = $Matches[3]

        $dir = Find-BucketDirectory $bucketName -Root
        if (Test-Path -LiteralPath $dir) {
            LogMessage "Scoop bucket '$bucketName' is already installed"
        } elseif ($bucketRepo -eq "local") {
            if (Test-Path -LiteralPath "$configPath\buckets\$bucketName") {
                LogUpdate "Add scoop bucket '$bucketSpec'"
                link_file "$scoopDir\buckets\$bucketName" "$configPath\buckets\$bucketName"
            } else {
                LogWarn "No scoop bucket with name $bucketName is present in the configuration"
            }
        }
        else {
            LogUpdate "Add scoop bucket '$bucketSpec'"
            DoUnverifiedSslGitAction {
                scoop bucket add $bucketName $bucketRepo
            }
        }
    }
    else {
        LogWarn "Invalid bucket : $bucketSpec"
    }
}

function m_applyExtra($extrasPath, $appName, [ApplyType] $type, $version, $old_version) {
    $extra_dir = "$extrasPath\$appName"
    if (Test-Path -LiteralPath "$extra_dir\extra.ps1") {
        LogMessage "Running $type extras for $appName..."
        $appdir = appdir $appName\current
        $persist_dir = persistdir $appName
        . $extra_dir/extra.ps1
        switch ($type) {
            'PostInstall' {
                onPostInstall $extra_dir $appdir $persist_dir $version
                ; Break
            }
            'PreUpdate' {
                onPreUpdate $extra_dir $appdir $persist_dir $version $old_version
                ; Break
            }
            'PostUpdate' {
                onPostUpdate $extra_dir $appdir $persist_dir $version $old_version
                ; Break
            }
            'CleanUp' {
                onCleanUp $extra_dir $appdir $persist_dir $version
                ; Break
            }
            'Idem' {
                onIdem $extra_dir $appdir $persist_dir $version
                ; Break
            }
        }
    }
}

function m_AddConfigName($appName) {
    $appdir = appdir $appName/current
    $install_json = Get-Content $appdir/install.json -raw -Encoding UTF8 | convertfrom-json -ea stop
    $install_json | Add-Member -Type NoteProperty -Name 'config' -Value $configName -force
    $install_json | ConvertTo-Json | Set-Content $appdir/install.json
}

function m_getConfigName($appName) {
    $appdir = appdir $appName/current
    $install_json = Get-Content $appdir/install.json -raw -Encoding UTF8 | convertfrom-json -ea stop
    if ($install_json.config) {
        return $install_json.config
    } else {
        return 'main'
    }
}

function m_isAppInstalledThroughCurrentConfig($appName) {
    if ($( m_getConfigName $appName ) -eq $configName) {
        return $true
    }
    return $false
}

