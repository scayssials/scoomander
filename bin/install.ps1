$scoopTarget = 'C:\devenv\scoop'
$changeExecutionPolicy = (Get-ExecutionPolicy) -gt 'RemoteSigned' -or (Get-ExecutionPolicy) -eq 'ByPass'

Write-Host "Scoop will be installed to $scoopTarget"
if ($changeExecutionPolicy) {
    Write-Host "Current user execution policy will be set to RemoteSigned"
} else {
    Write-Host "Current user execution policy don't need to be changed (current value is $( Get-ExecutionPolicy ))"
}
Write-Host ""

Write-Host "Do you want to proceed with the Devenv installation ?"

$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
if ($decision -ne 0) {
    Write-Host 'Cancelled'
    return
}

$env:SCOOP = $scoopTarget
[environment]::setEnvironmentVariable('SCOOP', $scoopTarget, 'User')
if ($changeExecutionPolicy) {
    Set-ExecutionPolicy RemoteSigned -scope CurrentUser -Force
}
# TODO use custom version to support manifest install/update
Invoke-WebRequest -useb 'https://tinyurl.com/scoop-devenv' | Invoke-Expression

scoop install git
scoop bucket add devenv https://github.com/stephanec1/devenv-bucket.git
scoop install devenv/devenv
Add-Content "$( scoop prefix git )/mingw64/ssl/certs/ca-bundle.crt" -Value (Get-Content -Path "$( scoop prefix devenv )/certs/axway.int.crt")

# Install di-conf by default
devenv config --install --url https://git.ecd.axway.int/decisioninsight/hacking-week/hw-201910-devenv-configuration.git --name di-conf

Write-Host ""
Write-Host "Scoop bootstrapped."
