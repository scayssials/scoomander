# Usage: devenv setJavaHome [options]
# Summary: Set the java version to use
# Help:
# devenv setJavaHome <java app name>

. "$( scoop prefix scoop )\lib\getopt.ps1"
. "$( scoop prefix scoop )\lib\core.ps1"
. "$( scoop prefix scoop )\lib\manifest.ps1"
. "$( scoop prefix scoop )\lib\install.ps1"

$opt, $app, $err = getopt $args

if ($err)
{
    LogMessage "devenv setJavaHome: $err"; exit 1
}
elseif (!$app)
{
    Write-Host '<app> missing'
    . "$PSScriptRoot\..\libexec\devenv-help.ps1" $cmd
}
else
{
    $app = $app[0]
    $dir = appdir $app
    if (Test-Path -path "$dir/current/bin/java.exe")
    {
        $manifest = installed_manifest $app "current"
        env_add_path $manifest "$dir/current"
        env_set $manifest "$dir/current" $global
        java --version
    }
    else
    {
        Write-Host "App '$app' do not contain a java exe."
        Write-Host "'$dir/current/bin/java.exe' do not exist"
    }
}

