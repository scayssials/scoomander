param($cmd)

. "$PSScriptRoot\..\lib\commands.ps1"
. "$PSScriptRoot\..\lib\logger.ps1"

$commands = commands
if ('--version' -contains $cmd -or (!$cmd -and '-v' -contains $args)) {
    scoop info scoomander
}
elseif (@($null, '--help', '/?') -contains $cmd -or $args[0] -contains '-h') { exec 'help' $args }
elseif ($commands -contains $cmd) {
    exec $cmd $args
} else {
    "scoomander: '$cmd' isn't a scoomander command. See 'scoomander help'."; exit 1
}

