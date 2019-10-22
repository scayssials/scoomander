# Usage: devenv help <command>
# Summary: Show help for a command
param($cmd)

. "$( scoop prefix scoop )\lib\help.ps1"

function print_help($cmd) {
    $file = Get-Content (command_path $cmd) -raw

    $usage = usage $file
    $help = scoop_help $file

    if ($usage) {
        "$usage`n"
    }
    if ($help) {
        $help
    }
}

function print_summaries {
    $commands = @{ }

    command_files | ForEach-Object {
        $command = command_name $_
        $summary = summary (Get-Content (command_path $command) -raw)
        if (!($summary)) {
            $summary = ''
        }
        $commands.add("$command ", $summary) # add padding
    }

    $commands.getenumerator() | Sort-Object name | Format-Table -hidetablehead -autosize -wrap
}

$commands = commands

if (!($cmd)) {
    "Usage: devenv <command> [<args>]

Some useful commands are:"
    print_summaries
    "Type 'devenv help <command>' to get help for a specific command."
} elseif($commands -contains $cmd) {
    print_help $cmd
} else {
    "devenv help: no such command '$cmd'"; exit 1
}

exit 0

