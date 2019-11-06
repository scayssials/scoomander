$defaultScoopTarget = 'C:\devenv\scoop'
$changeExecutionPolicy = (Get-ExecutionPolicy) -gt 'RemoteSigned' -or (Get-ExecutionPolicy) -eq 'ByPass'

$scoopTarget = Read-Host -Prompt "Where do you want to install your devenv? [$defaultScoopTarget]"
if ( [string]::IsNullOrWhiteSpace($scoopTarget)) {
    $scoopTarget = $defaultScoopTarget
}

Write-Host "Scoop will be installed to $scoopTarget"
if ($changeExecutionPolicy) {
    Write-Host "Current user execution policy will be set to RemoteSigned"
} else {
    Write-Host "Current user execution policy don't need to be changed (current value is $( Get-ExecutionPolicy ))"
}

$title = "Do you want to proceed with the Devenv installation ?"
$Prompt = "Enter your choice"
$Choices = [System.Management.Automation.Host.ChoiceDescription[]]@("&Yes", "&No")
$Default = 1
$decision = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
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

scoop bucket add devenv https://github.com/scayssials/devenv-bucket.git
scoop install devenv/devenv

Write-Host ""
Write-Host -ForegroundColor Green "Scoop bootstrapped and Devenv installed."
Write-Host "Try "
Write-Host ""
Write-Host -ForegroundColor Cyan "     devenv help"
Write-Host ""
Write-Host "to get more infos."
