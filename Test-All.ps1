#Requires -Version 7.0
#Requires -Modules PSScriptAnalyzer

<#
.SYNOPSIS
Validates PowerShell scripts in the AU packages repository.

.DESCRIPTION
Runs PSScriptAnalyzer on all PowerShell scripts to ensure they follow
best practices and maintain consistent formatting.
#>

$repoRoot = Split-Path -Parent $PSCommandPath
$settingsPath = Join-Path -Path $repoRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'

# Find all PowerShell scripts
$filesToCheck = Get-ChildItem -Path $repoRoot -Recurse -Include *.ps1, *.psm1 | Where-Object {
    $_.FullName -notmatch '\\(node_modules|\.git)\\'
}

$allPassed = $true

foreach ($file in $filesToCheck)
{
    Write-Information "Analyzing $($file.FullName)..." -InformationAction Continue
    $results = Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settingsPath -ExcludeRule @(
        'PSReviewUnusedParameter'                       # False positive for parameters used in scriptblocks
        'PSAvoidGlobalVars'                             # Required by AU framework
        'PSAvoidUsingWriteHost'                         # AU framework uses Write-Host
        'PSAvoidUsingCmdletAliases'                     # AU framework uses aliases
        'PSUseShouldProcessForStateChangingFunctions'   # Helper functions don't need ShouldProcess
        'PSAvoidUsingInvokeExpression'                  # Used in cinst-gh.ps1
        'PSUseApprovedVerbs'                            # cinst-gh uses unapproved verb
        'PSUseDeclaredVarsMoreThanAssignments'          # Some variables used for side effects
    )
    if ($results)
    {
        $allPassed = $false
        $results | Format-Table -AutoSize
    }
}

if ($allPassed)
{
    Write-Information "All checks passed!" -InformationAction Continue
    exit 0
}
else
{
    Write-Error "Some checks failed. See output above."
    exit 1
}
