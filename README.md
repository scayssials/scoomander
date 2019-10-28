# devenv

## Installation

In PowerShell console execute
```
iwr -useb 'https://raw.githubusercontent.com/stephanec1/devenv/master/bin/install.ps1' | iex
```
then

```
devenv config apply [-Name <String>]
```

## Usage

### Add a configuration

```
devenv config add [-Name <String>] [-url <String>] 
```

### Apply a configuration

```
devenv config apply [-Name <String>]
```

### UnApply a configuration

```
devenv config unapply [-Name <String>]
```

### Update and apply a configuration
```
devenv config update [-Name <String>] [--force]*
```
The force will erase your own modification
If you want to keep your modification don't use --force and rebase your configuration by yourself

### Update your own configuration
Every configurations are located in ```<devenvDir>/persist/devenv/config```
All your configuration are coming from git so you can easily update it locally and remotely

configuration example:
```
{
    "buckets": [
        "devenv@https://github.com/stephanec1/devenv-bucket.git"
    ],
    "apps": [
        "devenv/devenv",
        "7zip",
        "git",
        "devenv/putty",
        "devenv/yarn"
    ],
    "extras": [
        "axway"
    ]
}

```
this will install a scoop bucket from github
install the list of apps and apply configurations extras

### Uninstall
Just run 
```
devenv uninstall
```
