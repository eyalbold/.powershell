$Notebook = 'C:\notebook' # a path of cloned https://github.com/bold-dev/notebooks
if (-not $(test-path $Notebook) )
{
    $Notebook= Join-Path  $env:USERPROFILE "notebooks"
}
$global:enable_wt_keys=$false

if ($PSVersionTable.PSVersion -like "7*")
{
    Remove-Alias cd
}
Import-Module $PSScriptRoot\common.psm1 -DisableNameChecking

if (Test-path $PSScriptRoot\config.ps1) 
{
    . $PSScriptRoot\config.ps1
}

if ($global:enable_wt_keys)
{
    . $PSScriptRoot\wtkeys.ps1
}

if (Test-path $PSScriptRoot\my.ps1) 
{
    . $PSScriptRoot\my.ps1
}
if (Test-path $PSScriptRoot\secret.ps1)
{
    . $PSScriptRoot\secret.ps1
}
if (Test-Path $Notebook\bold.psm1)
{
    Import-Module $Notebook\bold.psm1 -DisableNameChecking
}
