# devenv

## Installation

In PowerShell console execute
```
iwr -useb 'https://tinyurl.com/devenv-install-beta' | iex
```
then

```
devenv config --apply --name di-conf
```

## Usage

### Install a configuration

```
devenv config --install --url plop.url --name confName
```

### Apply a configuration

```
devenv config --apply --name confName
```

### Update and apply a configuration
```
devenv config --update --name confName [--force]
```
The force will erase your own modification
If you want to keep your modification don't use --force and rebase your configuration by yourself

### Update your own configuration
Every configurations are located in ```<devenvDir>/persist/devevn/config```
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
