param($apps)

$scoopRootDir = scoop prefix scoop
. "$PSScriptRoot\..\lib\core.ps1" $apps $opt.v $opt.n
. "$scoopRootDir\lib\core.ps1"
. "$scoopRootDir\lib\buckets.ps1"
. "$scoopRootDir\lib\manifest.ps1"
. "$scoopRootDir\lib\versions.ps1"
. "$scoopRootDir\lib\install.ps1"

Function ApplyConfigurationFile([String]$ScoopConfig, [String]$extrasPath, [String]$cmd)
{
    $scoopConf = ConvertFrom-Json $ScoopConfig

    if ($cmd -eq "install") {
        foreach ($bucketSpec in $scoopConf.buckets)
        {
            if ($bucketSpec -ne "" -and !($bucketSpec -like "#*"))
            {
                InstallScoopBuckets $bucketSpec
            }
        }
        foreach ($appSpec in $scoopConf.apps)
        {
            if ($appSpec -ne "" -and !($appSpec -like "#*"))
            {
                InstallScoopApps $appSpec $extrasPath
            }
        }
    }

    if ($cmd -eq "update")
    {
        scoop update
        foreach ($appSpec in $scoopConf.apps)
        {
            if ($appSpec -ne "" -and !($appSpec -like "#*"))
            {
                UpdateScoopApps $appSpec $extrasPath
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
            LogInfo "Scoop bucket '$bucketName' already exists"
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
            LogInfo "Scoop app '$( $appName )' is already installed"

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
                # check configuration file
                if (Test-Path -path $extrasPath/$appName/extra.psm1)
                {
                    m_installApp $extrasPath $appName $appBucket
                }
                else
                {
                    scoop install $appSpec
                }
            }
        }
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
        if (!$appBucket)
        {
            $appBucket = "main"
        }
        if (installed $appName)
        {
            # check configuration file
            $old_version = current_version $appName $false
            $version = latest_version $appName $appBucket
            if ($old_version -eq $version)
            {
                LogInfo "The latest version of '$appName' ($version) is already installed."
            }
            else
            {
                if (Test-Path -path $extrasPath/$appName/extra.psm1)
                {
                    m_updateApp $extrasPath $appName $appBucket
                }
                else
                {
                    scoop update $appBucket/$appSpec
                }
            }

        }
    }
    else
    {
        LogWarn "Invalid application : $appSpec"
    }
}

function pre_install($manifest, $extra_dir)
{
    if (!$manifest.pre_install)
    {
        $manifest | Add-Member -Type NoteProperty -Name 'pre_install' -Value @()
    }
    $manifest.pre_install += 'extra_pre_install $extra_dir $dir $original_dir $persist_dir $version $app $architecture'
}

function post_install($manifest, $extra_dir)
{
    if (!$manifest.post_install)
    {
        $manifest | Add-Member -Type NoteProperty -Name 'post_install' -Value @()
    }
    $manifest.post_install += 'extra_post_install $extra_dir $dir $original_dir $persist_dir $version $app $architecture'
}

function m_installApp($extrasPath, $appName, $appBucket)
{
    # First install the app
    scoop install $appName

    # Then post configure it
    $extra_dir = "$extrasPath/$appName/"
    if (Test-Path -LiteralPath "$extra_dir/extra.psm1")
    {
        Import-Module $extra_dir/extra.psm1
        $appdir = appdir $appName/current
        apply $extra_dir $appdir
        Remove-Module extra
    }
}

function m_updateApp($extrasPath, $appName, $appBucket)
{
    $extra_dir = "$extrasPath/$appName/"
    Import-Module $extrasPath/$appName/extra.psm1
    # add pre and post operation directly in the manifest
    $manifest = manifest $appName $appBucket
    pre_install $manifest $extra_dir
    post_install $manifest $extra_dir

    $persistDir = persistdir "devenv"
    $manifest_path = "$persistDir\manifest\$appName.json"
    New-Item $manifest_path -ItemType "file" -Force
    $manifest | ConvertTo-Json | Set-Content $manifest_path -Force

    # use the created manifest to install the app
    scoop update $appName

    m_AddBucketName $appName $appBucket

    Remove-Module extra
}
