param($apps)

$scoopRootDir = scoop prefix scoop
. "$scoopRootDir\lib\core.ps1"
. "$scoopRootDir\lib\buckets.ps1"
. "$scoopRootDir\lib\manifest.ps1"
. "$scoopRootDir\lib\versions.ps1"
. "$scoopRootDir\lib\install.ps1"
. "$PSScriptRoot\..\lib\core.ps1"


Add-Type -TypeDefinition @"
    public enum InstallType {
        NewInstallation,
        OldInstallation,
        Update,
        OnlyExtra
    }
"@

Function UnapplyConfigurationFile([String]$configPath) {
    $extrasPath = "$configPath\extras"

    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json

    # apply extras
    foreach ($appSpec in $scoopConf.apps) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
                m_unapplyExtras $extrasPath $appName
            }
        }
    }
    foreach ($appSpec in $scoopConf.extras) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
                m_unapplyExtras $extrasPath $appName
            }
        }
    }
}

Function ApplyConfigurationFile([String]$configPath) {
    $extrasPath = "$configPath\extras"

    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json

    # install buckets
    foreach ($bucketSpec in $scoopConf.buckets) {
        if ($bucketSpec -ne "" -and !($bucketSpec -like "#*")) {
            InstallScoopBuckets $bucketSpec
        }
    }

    # update scoop / update all buckets
    scoop update

    # install apps
    foreach ($appSpec in $scoopConf.apps) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            InstallScoopApps $appSpec $extrasPath
        }
    }

    # apply extras
    foreach ($appSpec in $scoopConf.extras) {
        if ($appSpec -ne "" -and !($appSpec -like "#*")) {
            if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
                $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
                m_applyExtras $extrasPath $appName [InstallType]::OnlyExtra
            }
        }
    }
}

Function InstallScoopBuckets($bucketSpec) {
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

Function InstallScoopApps($appSpec, [String]$extrasPath) {
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
                    m_applyExtras $extrasPath $appName $( [InstallType]::OldInstallation )
                }
                else {
                    LogInfo "New version of '$appName' detected..."
                    scoop update $appSpec
                    m_applyExtras $extrasPath $appName $( [InstallType]::Update )
                }
            }
        }
        else {
            LogUpdate "Install scoop app '$appSpec'"
            scoop install $appSpec
            m_applyExtras $extrasPath $appName $( [InstallType]::NewInstallation )
        }
    }
    else {
        LogWarn "Invalid application : $appSpec"
    }
}

Function UpdateScoopApps($appSpec, [String]$extrasPath) {
    if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
        $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
        if (installed $appName) {
            # check configuration file
            $old_version = current_version $appName $false
            $install = install_info $appName $old_version
            $appBucket = $install.bucket
            $version = latest_version $appName $appBucket
            if ($old_version -eq $version) {
                LogMessage "The latest version of '$appName' ($version) is already installed."
                m_applyExtras $extrasPath $appName $( [InstallType]::OldInstallation )
            }
            else {
                LogInfo "New version of '$appName' detected..."
                scoop update $appSpec
                if (Test-Path -path $extrasPath/$appName/extra.ps1) {
                    m_applyExtras $extrasPath $appName $( [InstallType]::Update )
                }
            }
        }
        else {
            LogMessage "New scoop app detected '$( $appName )'..."
            InstallScoopApps $appSpec $extrasPath
            m_applyExtras $extrasPath $appName $( [InstallType]::NewInstallation )
        }
    }
    else {
        LogWarn "Invalid application : $appSpec"
    }
}

function m_applyExtras($extrasPath, $appName, [InstallType] $installType) {
    $extra_dir = "$extrasPath\$appName"
    if (Test-Path -LiteralPath "$extra_dir\extra.ps1") {
        LogMessage "Applying '$appName' extras from '$extra_dir'"
        $appdir = appdir $appName/current
        $persist_dir = persistdir $appName
        . $extra_dir/extra.ps1
        apply $extra_dir $appdir $persist_dir $installType
        LogInfo "-> '$appName' extras was applied"
    }
}

function m_unapplyExtras($extrasPath, $appName) {
    $extra_dir = "$extrasPath\$appName"
    if (Test-Path -LiteralPath "$extra_dir\extra.ps1") {
        LogMessage "Unapplying '$appName' extras from '$extra_dir'"
        $appdir = appdir $appName/current
        $persist_dir = persistdir $appName
        . $extra_dir/extra.ps1
        unapply $extra_dir $appdir $persist_dir
        LogInfo "-> '$appName' extras was unapplied"
    }
}
