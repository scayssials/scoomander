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

Function ApplyConfigurationFile([String]$configPath, [String]$appName) {

    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json

    # install buckets
    foreach ($bucketSpec in $scoopConf.buckets) {
        if ($bucketSpec -ne "" -and !($bucketSpec -like "#*")) {
            InstallScoopBucket $bucketSpec
        }
    }

    # update scoop / update all buckets
    scoop update

    # install apps and apply app extras
    $extrasPath = "$configPath\extras"
    foreach ($appSpec in $scoopConf.apps) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $specAppName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
                if (!$appName -or $appName -eq $specAppName) {
                    InstallScoopApp $specAppName $appBucket $extrasPath
                }
            }
        }
    }
    # apply lonely extras
    foreach ($appSpec in $scoopConf.extras) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            if ($appSpec -match '(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $specAppName, $appVersion = $matches['app'], $matches['version']
                if (!$appName -or $appName -eq $specAppName) {
                    LogUpdate "* Applying extra of $specAppName version $appVersion"
                    m_applyExtra $extrasPath $specAppName $( [ApplyType]::Idem ) $appVersion
                }
            }
        }
    }
}

Function UnapplyConfigurationFile([String]$configPath, [String]$appName) {
    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json
    $extrasPath = "$configPath\extras"
    # uninstall apps and unapply app extras
    foreach ($appSpec in $scoopConf.apps) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $specAppName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
                if (!$appName -or $appName -eq $specAppName) {
                    RemoveScoopApp $specAppName $appBucket $extrasPath
                }
            }
        }
    }
    # unapply lonely extras
    foreach ($appSpec in $scoopConf.extras) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            if ($appSpec -match '(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $specAppName, $appVersion = $matches['app'], $matches['version']
                if (!$appName -or $appName -eq $specAppName) {
                    LogUpdate "* UnApplying extra of $specAppName version $appVersion"
                    m_applyExtra $extrasPath $specAppName $( [ApplyType]::CleanUp ) $appVersion
                }
            }
        }
    }
}

Function RemoveScoopApp([String]$appName, [String]$appBucket, [String]$extrasPath) {
    LogUpdate "* Unapplying configuration for app '$appSpec'..."
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
        scoop uninstall $appSpec
    } else {
        LogMessage "'$appName' isn't installed."
    }
}

Function InstallScoopApp([String]$appName, [String]$appBucket, [String]$extrasPath) {
    LogUpdate "* Applying configuration for app '$appSpec'"
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
            return
        }
        if ($currentAppBucket -ne $appBucket) {
            LogWarn "Scoop app '$appName' is from bucket '$( $install_info.bucket )' but declared in bucket '$appBucket' in the configuration"
            return
        }
        if ($from_version -eq $to_version) {
            LogMessage "The latest version of '$appName' ($to_version) is already installed."
            m_applyExtra $extrasPath $appName $( [ApplyType]::Idem ) $to_version
        }
        else {
            LogInfo "New version of '$appName' detected..."
            m_applyExtra $extrasPath $appName $( [ApplyType]::PreUpdate ) $to_version $from_version
            scoop update $appSpec
            m_applyExtra $extrasPath $appName $( [ApplyType]::PostUpdate ) $to_version $from_version
            m_AddConfigName $appName
        }
    }
    else {
        LogUpdate "Install scoop app '$appSpec'"
        scoop install $appSpec
        $to_version = current_version $appName $false
        m_applyExtra $extrasPath $appName $( [ApplyType]::PostInstall ) $to_version
        m_AddConfigName $appName
    }
}

Function InstallScoopBucket($bucketSpec) {
    if ($bucketSpec -match "^([^@]+)(@(.+))?$") {
        $bucketName = $Matches[1]
        $bucketRepo = $Matches[3]

        $dir = Find-BucketDirectory $bucketName -Root
        if (Test-Path -LiteralPath $dir) {
            LogMessage "Scoop bucket '$bucketName' is already installed"
        } else {
            LogUpdate "Add scoop bucket '$bucketSpec'"
            scoop bucket add $bucketName $bucketRepo
        }
        return $bucketName
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
    $install_json | Add-Member -Type NoteProperty -Name 'config' -Value $configName
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
