# Usage: scoomander apply <config> [options]
# Summary: Unapply configuration
# Help:
# e.g. The usual way to unapply a configuration:
#      scoomander unapply myConfig
#
# Options:
#   -appnames:  Comma separated app. Will only unapply configuration for those apps
#   -force:     Do not ask to confirm
#
# This will uninstall your configuration apps
# This will also cleanup all your configurations extras

Param(
    [String]
    $name,
    [String[]]
    $appNames,
    [Switch]
    $force
)

# Import useful scripts
. "$PSScriptRoot\..\lib\logger.ps1"
. "$PSScriptRoot\..\lib\core.ps1"

# Set global variables
$configPath = "$PSScriptRoot\..\config\$name"

if (!$name) {
    LogWarn "<config> is missing."
    LogMessage ""
    LogMessage "Usage: scoomander unapply <config>"
    LogMessage ""
    return
}

EnsureConfigInstalled $name
# update scoop / update all buckets
DoUnverifiedSslGitAction {
    scoop update
}
EnsureScoomanderVersion $configPath

. "$PSScriptRoot\..\API\configAPI.ps1" $name $force
. "$configPath\main.ps1" -mode "unapply" -appNames $appNames
