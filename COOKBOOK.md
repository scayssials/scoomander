# :poultry_leg: Devenv Cookbook :poultry_leg:


## Install the devenv

`iwr -useb 'https://raw.githubusercontent.com/stephanec1/devenv/master/bin/install.ps1' | iex`

## Create your first configuration

A configuration is a git repository that contains

```
/extras
    /appName
        /extra.ps1
conf.json
main.ps1
```

#### conf.json

The conf.json file represents what the devenv should install
it will first install required scoop `buckets`, then scoop `app` and then `extras`

```json
{
    "buckets": [
        "bucket_name[?@url]",
    ],
    "apps": [
        "[?bucket/]app_name[?@version]"
    ],
    "extras": [
        "extra_name[?@version]"
    ]
}
```

example

```json
{
    "buckets": [
        "devenv@https://github.com/stephanec1/devenv-bucket.git",
    ],
    "apps": [
        "devenv/winscp",
        "devenv/maven",
        "devenv/putty",
        "devenv/openjdk13"
    ],
    "extras": [
        "git"
    ]
}
```

#### main.ps1

The main script is called by the devenv when a configuration is applied on unapplied
The least you can do is asking the devenv to Apply or Unapply the configuration by calling the function `ApplyConfigurationFile $PSScriptRoot` or `UnApplyConfigurationFile $PSScriptRoot`
But you can also add anything that could be usefull for your configuration before or after

```powershell
param($mode)

switch ($mode) {
    "apply" {
        ApplyConfigurationFile $PSScriptRoot
    }
    "unapply" {
        UnApplyConfigurationFile $PSScriptRoot
    }
}
```


#### Buckets

##### What are buckets:

In Scoop, buckets are collections of apps. Or, to be more specific, a bucket is a Git repository containing JSON app manifests which describe how to install an app.

##### Public buckets

use `scoop bucket known` to list them:
* main
* extras
* versions
* jetbrains
* ...

##### Create your own bucket

The devenv has its own bucket that you can find here: [Devenv-bucket](https://github.com/stephanec1/devenv-bucket)
You can also create as many bucket as you wants. See scoop documentation to know more about it: [Buckets · scoop Wiki](https://github.com/lukesampson/scoop/wiki/Buckets#creating-your-own-bucket)


#### Add extras

to add extras, just add a folder with the app name or extras name you want under /extras in your configuration
example:

```
/extras
  /git
    /extra.ps1
  /putty
    /extra.ps1
```

If an app or extras contained in your conf.json match the folder name, the script `extra.ps1` will be called when the devenv apply/unapply your configuration
Your `extra.ps1` script **must** implements this interface:

```powershell
# Called after app installation
Function onPostInstall($extra_dir, $dir, $persist_dir, $version) {}

# Called before app update
Function onPreUpdate($extra_dir, $dir, $persist_dir, $version, $old_Version) {}
                          
# Called after app installation
Function onPostUpdate($extra_dir, $dir, $persist_dir, $version, $old_Version) {}
                                                                                 
# Called before app deletion 
# Called for extra unapply
Function onCleanUp($extra_dir, $dir, $persist_dir, $version) {}
                            
# Called on apply without app modification (ex: no update)
# Called for extra only at every apply (extra without apps, in the extras conf.json section)
Function onIdem($extra_dir, $dir, $persist_dir, $version) {}

<#
$extra_dir is the directory of your extras
example: for putty -> $extra_dir == <conf_dir>/extras/putty

$dir is the current app directory
example: for putty -> $dir == <scoop_dir>/apps/putty/current

$persist_dir is the persistant directory of the app
example: for putty -> $persist_dir == <scoop_dir>/persist/putty

$version is the installed version of the app (except for preUpdate -> version after update)
example: for putty v0.71 -> $version == 0.71

$old_version is the previously installed version
example: for an update of putty from 0.71 to 0.72 -> $version == 0.72 && $old_version == 0.71
#>
```

Some usefull utils can be used in your extra script

```powershell
<#
Update an environment variable or create it if necessary
Environment variable are setted in the current process and in the user

.EXAMPLE
devenvUtils_UpdateEnvironmentVariable PUTTY_HOME C:/scoop/app/putty/current
 #>
devenvUtils_UpdateEnvironmentVariable([String]$Name, [String]$Value)

<#
Remove an environment variable if it exist with the matched value
if the value is null, remove the env var

.EXAMPLE
devenvUtils_RemoveEnvironmentVariable PUTTY_HOME C:/scoop/app/putty/current
or
devenvUtils_RemoveEnvironmentVariable PUTTY_HOME
 #>
devenvUtils_RemoveEnvironmentVariable([String]$Name, [String]$Value)

<#
Install a devenv plugin
The plugin can then be called by running devenv <pluginName>

.EXAMPLE
devenvUtils_installPlugin setJavaHome C:/...../setJavaHome.ps1

Then, by calling devenv setJavaHome, the script setJavaHome.ps1 will be called
 #>
devenvUtils_installPlugin([String]$Name, [String]$ScriptFile)

<#
Remove the mentionned plugin

.EXAMPLE
devenvUtils_removePlugin setJavaHome
 #>
devenvUtils_removePlugin([String]$Name)  

<#
Store the version used to apply extras
return true if the value has been updated 
Can be used to now if an extra should be applied or not
 #> 
devenvUtils_updateExtraVersion([String]$persist_dir, [String]$version) 
 
<#
Remove the stored version
 #> 
devenvUtils_removeExtraVersion([String]$persist_dir)
```

But you can also do whatever you want

example of putty `extra.ps1`

```powershell
Function onPostInstall($extra_dir, $dir, $persist_dir, $version) {
    Copy-Item "$extra_dir/putty.conf" -Destination "$dir/putty.conf"

    devenvUtils_UpdateEnvironmentVariable "PUTTY_SETTINGS" "$extra_dir\settings" 'User'
}

Function onPreUpdate($extra_dir, $dir, $persist_dir, $version, $old_Version) {}

Function onPostUpdate($extra_dir, $dir, $persist_dir, $version, $old_Version) {}

Function onCleanUp($extra_dir, $dir, $persist_dir, $version) {
    Remove-Item "$dir/putty.conf" -Force

    devenvUtils_RemoveEnvironmentVariable "PUTTY_SETTINGS" "$extra_dir\settings"
}

Function onIdem($extra_dir, $dir, $persist_dir, $version) {}
```

Once your first configuration is done, publish it on a remote git repository


## Install your first configuration


#### Add configuration A

`devenv config add -Name <conf_name> -Url <git_url> [-force]`

this will clone the configuration from the `git_url` in `<devenv_dir>/persist/devenv/config/<conf_name>` and checkout a new local branch `current`

(If you want to test a configuration that is not yet on a remote repository, you can create your configuration under `<devenv_dir>/persist/devenv/config/<conf_name>`)

#### Apply configuration A

`devenv config apply <conf_name>`

This will install your conf `buckets`, `apps` and apply your `extras` as you have defined them in your configuration


## Update localy your configuration

You can directly work on your configuration by editing it in `<devenv_dir>/persist/devenv/config/<conf_name>`

You can test your changes by running `devenv config apply <conf_name>`

You can also work localy on your installed buckets to update some app `manifest.json` and run `devenv config update <conf_name>` to apply it


## Share your new configuration

When you are confident with your changes you can merge then on the master branch of the configuration

Then anyone can install the new configuration by running

`devenv config update <conf_name> [-force]` 

OR directly rebase there current configuration branch on master

and then

`devenv config apply <conf_name>`


## Install a second configuration

`devenv config add <conf_name> [-force]`

`devenv config apply <conf_name>`


## Uninstall your first configuration

#### First uninstall every conf apps and unapply extras
`devenv config unapply <conf_name> [-force]`

If -force is not used, the devenv will ask you for every apps if you wants to uninstall them

If a given app is referenced in multiple configurations, the devenv will only uninstall app that has been installed with the given configuration

#### Remove the configuration
`devenv config remove <conf_name>`

This will delete your configuration from `<devenv_dir>/persist/devenv/config/<conf_name>`

