param($apps)

$scoopRootDir = scoop prefix scoop
. "$scoopRootDir\lib\core.ps1"
. "$scoopRootDir\lib\buckets.ps1"
. "$scoopRootDir\lib\manifest.ps1"
. "$scoopRootDir\lib\versions.ps1"
. "$scoopRootDir\lib\install.ps1"
. "$PSScriptRoot\..\lib\utils.ps1"

enum ApplyType {
    PostInstall
    PreUpdate
    PostUpdate
    CleanUp
    Idem
}

Function ApplyConfigurationFile([String]$configPath) {

    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json

    # install buckets
    foreach ($bucketSpec in $scoopConf.buckets) {
        if ($bucketSpec -ne "" -and !($bucketSpec -like "#*")) {
            InstallScoopBucket $bucketSpec
        }
    }

    # update scoop / update all buckets
    scoop update

    # install apps
    $extrasPath = "$configPath\extras"
    foreach ($appSpec in $scoopConf.apps) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            InstallScoopApp $appSpec $extrasPath
        }
    }

    # apply extras
    foreach ($appSpec in $scoopConf.extras) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
                # TODO handle install update remove?
                m_applyExtra $extrasPath $appName [ApplyType]::Idem $appVersion
            }
        }
    }
}

Function UnapplyConfigurationFile([String]$configPath) {
    $extrasPath = "$configPath\extras"

    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json

    # apply extras
    foreach ($appSpec in $scoopConf.apps) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
                $version = current_version $appName $false
                m_apply $extrasPath $appName $( [ApplyType]::CleanUp ) $version
            }
        }
    }
    foreach ($appSpec in $scoopConf.extras) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            # TODO handle this as an extra, no need for bucket name and version
            if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
                m_apply $extrasPath $appName $( [ApplyType]::CleanUp ) $appVersion
            }
        }
    }
}

Function InstallScoopApp($appSpec, [String]$extrasPath) {
    if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
        $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
        if (!$appBucket) {
            $appBucket = "main"
        }
        if (installed $appName) {
            LogMessage "Scoop app '$( $appName )' is already installed"

            $ver = current_version $appName $false
            $install_info = install_info $appName $ver $false
            if ($install_info.bucket -ne $appBucket) {
                LogWarn "Scoop app '$appName' is from bucket '$( $install_info.bucket )' but declared in bucket '$appBucket' in the configuration"
            } else {
                $old_version = current_version $appName $false
                $install = install_info $appName $old_version
                $appBucket = $install.bucket
                $version = latest_version $appName $appBucket
                if ($old_version -eq $version) {
                    LogMessage "The latest version of '$appName' ($version) is already installed."
                    m_applyExtra $extrasPath $appName $( [ApplyType]::Idem ) $version
                }
                else {
                    LogInfo "New version of '$appName' detected..."
                    m_applyExtra $extrasPath $appName $( [ApplyType]::PreUpdate ) $version $old_version
                    scoop update $appSpec
                    m_applyExtra $extrasPath $appName $( [ApplyType]::PostUpdate ) $version $old_version
                }
            }
        }
        else {
            LogUpdate "Install scoop app '$appSpec'"
            scoop install $appSpec
            $version = current_version $appName $false
            m_applyExtra $extrasPath $appName $( [ApplyType]::PostInstall ) $version
        }
    }
    else {
        LogWarn "Invalid application : $appSpec"
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
        LogMessage "Running $type extras..."
        $appdir = appdir $appName/current
        $persist_dir = persistdir $appName
        . $extra_dir/extra.ps1
        switch ($type) {
            'PostInstall' {
                onPostInstall $extra_dir $appdir $persist_dir
                ; Break
            }
            'PreUpdate' {
                onPreUpdate $extra_dir $appdir $persist_dir
                ; Break
            }
            'PostUpdate' {
                onPostUpdate $extra_dir $appdir $persist_dir
                ; Break
            }
            'CleanUp' {
                onCleanUp $extra_dir $appdir $persist_dir
                ; Break
            }
            'Idem' {
                onIdem $extra_dir $appdir $persist_dir
                ; Break
            }
        }
    }
}
