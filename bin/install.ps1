$defaultScoopTarget = 'C:\devenv\scoop'
$changeExecutionPolicy = (Get-ExecutionPolicy) -gt 'RemoteSigned' -or (Get-ExecutionPolicy) -eq 'ByPass'

$scoopTarget = Read-Host -Prompt "Where do you want to install your devenv? [$defaultScoopTarget]"
if ([string]::IsNullOrWhiteSpace($scoopTarget))
{
   $scoopTarget = $defaultScoopTarget
}

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
iwr -useb get.scoop.sh | iex

scoop install git
Write-Host ""
Write-Host "Bootstrap git"
Write-Host ""

scoop bucket add devenv https://github.com/stephanec1/devenv-bucket.git
scoop install devenv/devenv

Write-Host ""
Write-Host "Scoop bootstrapped."
