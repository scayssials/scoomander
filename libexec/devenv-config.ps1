# Usage: devenv config [options]
# Summary: Devenv configuration management
# Help:
# devenv config --install --url <git-url> --name <config-name>
# devenv config --remove --name <config-name>
# devenv config --apply --name <config-name>
# devenv config --update --name <config-name>
# devenv config --list

## todo check if the config repo is good

. "$( scoop prefix scoop )\lib\getopt.ps1"

$opt, $args, $err = getopt $args "" @('apply', 'update', 'remove', 'install', 'list', 'url=', 'name=', 'branch=')

$scoopTarget = $env:SCOOP

if ($err)
{
    LogMessage "devenv config: $err"; exit 1
}
elseif ($opt.apply)
{
    if (!$opt.ContainsKey('name'))
    {
        Write-Host "devenv config --apply: --name is mandatory"; exit 1
    }
    #load API
    . "$PSScriptRoot\..\API\configAPI.ps1"
    . "$PSScriptRoot\..\config\$( $opt.name )\apply.ps1" "install"
}
elseif ($opt.update)
{
    if (!$opt.ContainsKey('name'))
    {
        Write-Host "devenv config --update: --name is mandatory"; exit 1
    }
    #load API
    . "$PSScriptRoot\..\API\configAPI.ps1"
    . "$PSScriptRoot\..\config\$( $opt.name )\apply.ps1" "update"
}
elseif ($opt.list)
{
    Write-Host "List all devenv configuration by names: "
    $Folders = Get-ChildItem "$scoopTarget\persist\devenv\config\" -Directory -Name
    foreach ($Folder in $Folders)
    {
        $Folder = Split-Path -Path $Folder -Leaf
        Write-Host $Folder
    }
}
elseif ($opt['remove'])
{
    if (!$opt.ContainsKey('name'))
    {
        Write-Host "devenv config --remove: --name is mandatory"; exit 1
    }
    if (Test-Path -LiteralPath "$scoopTarget\persist\devenv\config\$( $opt.name )")
    {
        Write-Host "Removing configuration '$( $opt.name )'"
        Write-Host ""
        Write-Host "Are you sure to delete configuration $( $opt.name ) ?"
        $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

        $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
        if ($decision -ne 0)
        {
            Write-Host 'Cancelled'
            return
        }
        Remove-Item "$scoopTarget\persist\devenv\config\$( $opt.name )" -Force -Recurse
    }
    else
    {
        Write-Host "No configuration with name '$( $opt.name )' exit. Use devenv config --list."
    }
}
elseif ($opt.install)
{
    if (!$opt.ContainsKey('url'))
    {
        Write-Host "devenv config --install: --url is mandatory"; exit 1
    }
    elseif (!$opt.ContainsKey('name'))
    {
        Write-Host "devenv config --install: --name is mandatory"; exit 1
    }
    Write-Host "Installing a configuration from repo '$opt.url' as '$opt.name' configuration."
    Write-Host ""

    if (Test-Path -LiteralPath "$scoopTarget\persist\devenv\config\$( $opt.name )")
    {
        Write-Host "Configuration $( $opt.name ) already exist, would you like to override it ?"
        $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

        $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
        if ($decision -ne 0)
        {
            Write-Host 'Cancelled'
            return
        }
        Remove-Item "$scoopTarget\persist\devenv\config\$( $opt.name )" -Force -Recurse
    }

    Write-Host ""
    git clone $opt.url "$scoopTarget\persist\devenv\config\$( $opt.name )"
    Push-Location "$scoopTarget\persist\devenv\config\$( $opt.name )"
    if ( $opt.ContainsKey('branch'))
    {
        $exist = git rev-parse --verify --quiet $opt.branch
        if (!$exist)
        {
            git checkout -b $opt.branch
        }
        else
        {
            git checkout $opt.branch
        }
    }
    git lfs pull
    Pop-Location
}
else
{
    . "$PSScriptRoot\..\libexec\devenv-help.ps1" $cmd
}

