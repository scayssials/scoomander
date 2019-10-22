param($mode)

switch ($mode) {
    "apply" {
        ApplyConfigurationFile $PSScriptRoot
    }
    "unapply" {
        UnApplyConfigurationFile $PSScriptRoot
    }
}
