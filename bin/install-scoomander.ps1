new-module -name Install-Scoomander -scriptblock {
    Function Install {
        param(
            [String]
            $defaultScoopTarget = "$env:USERPROFILE\scoop",
            [Switch]
            $noPrompt,
            [Switch]
            $RunAsAdmin
        )

        $changeExecutionPolicy = (Get-ExecutionPolicy) -gt 'RemoteSigned' -or (Get-ExecutionPolicy) -eq 'ByPass'

        $scoopTarget = if ($noPrompt) { "" } else { Read-Host -Prompt "Where do you want to install Scoop (Scoomander will be installed inside)? [$defaultScoopTarget]" }
        if ( [string]::IsNullOrWhiteSpace($scoopTarget)) {
            $scoopTarget = $defaultScoopTarget
        }

        Write-Host "Scoop will be installed to $scoopTarget"
        if ($changeExecutionPolicy) {
            Write-Host "Current user execution policy will be set to RemoteSigned"
        } else {
            Write-Host "Current user execution policy don't need to be changed (current value is $( Get-ExecutionPolicy ))"
        }

        if (!$noPrompt) {
            $title = "Do you want to proceed with the Scoomander installation ?"
            $Prompt = "Enter your choice"
            $Choices = [System.Management.Automation.Host.ChoiceDescription[]]@("&Yes", "&No")
            $Default = 1
            $decision = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
            if ($decision -ne 0) {
                Write-Host 'Cancelled'
                return
            }
        }

        $env:SCOOP = $scoopTarget
        [environment]::setEnvironmentVariable('SCOOP', $scoopTarget, 'User')
        if ($changeExecutionPolicy) {
            Set-ExecutionPolicy RemoteSigned -scope CurrentUser -Force
        }
        if ($RunAsAdmin) {
            iwr get.scoop.sh -outfile 'scoop-install.ps1'
            .\scoop-install.ps1 -RunAsAdmin
            Remove-Item .\scoop-install.ps1
        } else {
            iwr -useb get.scoop.sh | iex
        }

        scoop install git

        scoop bucket add scoomander https://github.com/scayssials/scoomander-bucket.git
        scoop install scoomander/scoomander

        Write-Host ""
        Write-Host -ForegroundColor Green "Scoop bootstrapped and Scoomander installed."
        Write-Host "Try "
        Write-Host ""
        Write-Host -ForegroundColor Cyan "     scoomander help"
        Write-Host ""
        Write-Host "to get more infos."
    }
}
