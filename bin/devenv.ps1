param($cmd)

. "$PSScriptRoot\..\lib\commands.ps1"
. "$PSScriptRoot\..\lib\logger.ps1"

$commands = commands
if ('--version' -contains $cmd -or (!$cmd -and '-v' -contains $args)) {
    scoop info devenv
}
elseif (@($null, '--help', '/?') -contains $cmd -or $args[0] -contains '-h') { exec 'help' $args }
elseif ($commands -contains $cmd) {
    exec $cmd $args
} else {
    "devenv: '$cmd' isn't a devenv command. See 'devenv help'."; exit 1
}

