param($apps)

$scoopRootDir = scoop prefix scoop
. "$PSScriptRoot\..\lib\core.ps1" $apps $opt.v $opt.n
. "$scoopRootDir\lib\core.ps1"
. "$scoopRootDir\lib\buckets.ps1"
. "$scoopRootDir\lib\manifest.ps1"
. "$scoopRootDir\lib\versions.ps1"
. "$scoopRootDir\lib\install.ps1"

Function ApplyConfigurationFile([String]$configPath, [String]$cmd, [Bool]$force)
{
    $extrasPath = "$configPath\extras"

    if ($cmd -eq "update")
    {
        # Rebase
        LogInfo "Rebasing configuration..."
        Push-Location $configPath
        git commit -a -m "Snapshot of the configuration"
        git fetch origin
        if ($force)
        {
            git rebase -Xours origin/master
        }
        else
        {
            git rebase origin/master
        }
        git lfs pull
        Pop-Location

        scoop update
    }

    $scoopConf = (Get-Content "$configPath\conf.json") | ConvertFrom-Json

    foreach ($bucketSpec in $scoopConf.buckets)
    {
        if ($bucketSpec -ne "" -and !($bucketSpec -like "#*"))
        {
            InstallScoopBuckets $bucketSpec
        }
    }
    foreach ($appSpec in $scoopConf.extras)
    {
        if ($appSpec -ne "" -and !($appSpec -like "#*"))
        {
            if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?')
            {
                $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
                m_applyExtras $extrasPath $appName
            }
        }
    }
    foreach ($appSpec in $scoopConf.apps)
    {
        if ($appSpec -ne "" -and !($appSpec -like "#*"))
        {
            if ($cmd -eq "update")
            {
                UpdateScoopApps $appSpec $extrasPath
            }
            else
            {
                InstallScoopApps $appSpec $extrasPath
            }
        }
    }
}

Function InstallScoopBuckets($bucketSpec)
{
    if ($bucketSpec -match "^([^@]+)(@(.+))?$")
    {
        $bucketName = $Matches[1]
        $bucketRepo = $Matches[3]

        $dir = Find-BucketDirectory $bucketName -Root
        if (Test-Path -LiteralPath $dir)
        {
            LogMessage "Scoop bucket '$bucketName' already installed"
        }
        else
        {
            ExecuteScript "Add scoop bucket '$bucketSpec'" {
                scoop bucket add $bucketName $bucketRepo
            }
        }
        return $bucketName
    }
    else
    {
        LogWarn "Invalid bucket : $bucketSpec"
    }
}

Function InstallScoopApps($appSpec, [String]$extrasPath)
{
    if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?')
    {
        $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
        if (!$appBucket)
        {
            $appBucket = "main"
        }
        if (installed $appName)
        {
            LogMessage "Scoop app '$( $appName )' is already installed"

            $ver = current_version $appName $false
            $install_info = install_info $appName $ver $false
            if ($install_info.bucket -ne $appBucket)
            {
                LogWarn "Scoop app '$appName' is from bucket '$( $install_info.bucket )' but declared in bucket '$appBucket' in the configuration"
            }

            if ($appVersion -and ($appVersion -ne $ver))
            {
                LogWarn "Scoop app '$appName' version is '$ver' but declared with version '$appVersion' in the configuration"
            }
        }
        else
        {
            ExecuteScript "Install scoop app '$appSpec'" {
                scoop install $appSpec
            }
        }
        m_applyExtras $extrasPath $appName
    }
    else
    {
        LogWarn "Invalid application : $appSpec"
    }
}

Function UpdateScoopApps($appSpec, [String]$extrasPath)
{
    if ($appSpec -match '(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?')
    {
        $appName, $appVersion, $appBucket = $matches['app'], $matches['version'], $matches['bucket']
        if (installed $appName)
        {
            # check configuration file
            $old_version = current_version $appName $false
            $install = install_info $appName $old_version
            $appBucket = $install.bucket
            $version = latest_version $appName $appBucket
            if ($old_version -eq $version)
            {
                LogMessage "The latest version of '$appName' ($version) is already installed."
            }
            else
            {
                LogInfo "New version of '$appName' detected..."
                scoop update $appSpec
                if (Test-Path -path $extrasPath/$appName/extra.psm1)
                {
                    m_applyExtras $extrasPath $appName
                }
            }
        }
        else
        {
            LogMessage "New scoop app detected '$( $appName )'..."
            InstallScoopApps $appSpec $extrasPath
        }
    }
    else
    {
        LogWarn "Invalid application : $appSpec"
    }
}

function m_applyExtras($extrasPath, $appName)
{
    $extra_dir = "$extrasPath\$appName"
    if (Test-Path -LiteralPath "$extra_dir\extra.psm1")
    {
        LogMessage "Applying '$appName' extras from '$extrasPath'"
        Import-Module $extra_dir/extra.psm1
        $appdir = appdir $appName/current
        $persist_dir = persistdir $appName
        apply $extra_dir $appdir $persist_dir
        Remove-Module extra
        LogInfo "-> '$appName' extras was applied"
    }
}
