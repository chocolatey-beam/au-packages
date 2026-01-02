#Requires -Version 7.0

<#
.SYNOPSIS
Shared utility functions for AU package scripts

.DESCRIPTION
Common functions used across package update scripts to avoid duplication.
#>

function Import-AUModule
{
    <#
    .SYNOPSIS
    Imports the Chocolatey-AU module from submodule or global install

    .DESCRIPTION
    Checks if Chocolatey-AU is available globally. If not, imports from
    the _modules/au submodule. This allows scripts to work with either
    a global AU installation or the submodule version.

    .EXAMPLE
    Import-AUModule
    #>
    if (-not (Get-Module -Name Chocolatey-AU -ListAvailable))
    {
        # Find repository root by looking for .git directory
        $current = $PSScriptRoot
        while ($current -and -not (Test-Path -PathType Container -LiteralPath (Join-Path $current '.git')))
        {
            $current = Split-Path -LiteralPath $current -Parent
        }
        if (-not $current)
        {
            throw "Could not find repository root (no .git directory found)"
        }

        $auModulePath = Join-Path -Path $current -ChildPath '_modules'
        $auModulePath = Join-Path -Path $auModulePath -ChildPath 'au'
        $auModulePath = Join-Path -Path $auModulePath -ChildPath 'src'
        $auModulePath = Join-Path -Path $auModulePath -ChildPath 'Chocolatey-AU.psd1'
        if (-not (Test-Path $auModulePath))
        {
            throw "AU module not found at $auModulePath. Run 'git submodule update --init' first."
        }
        Import-Module -Force $auModulePath
    }
}
