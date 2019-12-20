<p align="center">
<!--<img src="scoop.png" alt="Long live Scoop!"/>-->
    <h1 align="center">Scoomander</h1>
</p>
<p align="center">
<b><a href="https://github.com/scayssials/scoomander#what-does-scoomander-do">Features</a></b>
|
<b><a href="https://github.com/scayssials/scoomander#installation">Installation</a></b>
|
<b><a href="https://github.com/scayssials/scoomander/wiki">Documentation</a></b>
</p>

- - -
<p align="center" >
    <a href="https://github.com/scayssials/scoomander">
        <img src="https://img.shields.io/github/languages/code-size/scayssials/scoomander.svg" alt="Code Size" />
    </a>
    <a href="https://github.com/scayssials/scoomander">
        <img src="https://img.shields.io/github/repo-size/scayssials/scoomander.svg" alt="Repository size" />
    </a>
    <a href="https://github.com/scayssials/scoomander/blob/master/LICENSE">
        <img src="https://img.shields.io/github/license/scayssials/scoomander.svg" alt="License" />
    </a>    
</p>

Scoomander is a scoop orchestrator for Windows.

## What does Scoomander do

Scoomander install a configurable list of programs on your machine thanks to Scoop.

Scoomander allows users to use complex configuration in order to create and maintain a development environment. 

## Requirements

- Windows 7 SP1+ / Windows Server 2008+
- [PowerShell 5](https://aka.ms/wmf5download) (or later, include [PowerShell Core](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-6)) and [.NET Framework 4.5](https://www.microsoft.com/net/download) (or later)
- PowerShell must be enabled for your user account e.g. `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

## Installation

Run the following command from your PowerShell to install:
- Scoop to its default location (`C:\Users\<user>\scoop`) or the one specified during installation 
- Git
- 7zip
- Scoomander

```powershell
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/scayssials/scoomander/master/bin/install.ps1')

# or shorter
iwr -useb 'https://raw.githubusercontent.com/scayssials/scoomander/master/bin/install.ps1' | iex
```

Once installed, run `scoomander help` for instructions.

The default Scoop setup is configured so all user installed programs Scoop and Scoomander itself live in `C:\Users\<user>\scoop`.
These settings can be changed through scoop directly (see [scoop wiki](https://github.com/lukesampson/scoop/wiki)).

Scoomander configurations are in `C:\Users\<user>\scoop\apps\scoomander\current\config`

Scoomander plugins are in `C:\Users\<user>\scoop\apps\scoomander\current\plugins`

## More

[Scoomander wiki](https://github.com/scayssials/scoomander/wiki)
