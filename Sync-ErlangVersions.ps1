#Requires -Version 7.0

<#
.SYNOPSIS
Synchronizes Erlang/OTP versions to Chocolatey by detecting and publishing missing versions.

.DESCRIPTION
Parses the official OTP versions table from GitHub, compares with published versions
on chocolatey.org, and builds/publishes any missing versions. Processes versions
sequentially to ensure thorough testing of each release.

.PARAMETER DryRun
Show what would be done without actually building or pushing packages.

.PARAMETER MinMajorVersion
Minimum OTP major version to process (default: 25). Only processes versions >= this value.

.PARAMETER SpecificVersion
Process only this specific version (e.g., "27.3.4"). Overrides MinMajorVersion.

.PARAMETER ApiKey
Chocolatey API key for publishing. Required unless using -DryRun.

.EXAMPLE
.\sync-versions.ps1 -DryRun
Shows which versions are missing without building anything

.EXAMPLE
.\sync-versions.ps1 -ApiKey "your-api-key"
Builds and publishes all missing versions >= 25.0

.EXAMPLE
.\sync-versions.ps1 -MinMajorVersion 26 -ApiKey "your-api-key"
Builds and publishes all missing versions >= 26.0

.EXAMPLE
.\sync-versions.ps1 -SpecificVersion "27.3.4" -ApiKey "your-api-key"
Builds and publishes only version 27.3.4 if missing
#>

param(
    [switch]$DryRun = $false,
    [ValidateRange(1, 99)]
    [int]$MinMajorVersion = 25,
    [string]$SpecificVersion,
    [ValidateRange(1, 99)]
    [int]$MaxMajorVersion = 99,
    [string]$ApiKey = $null,
    [ValidateRange(1, 100)]
    [int]$MaxPushes = 10
)

. (Join-Path -Path $PSScriptRoot -ChildPath 'Shared.ps1')

# Clean up any stale AU functions from previous package runs
Remove-Item Function:\au_SearchReplace -ErrorAction Ignore
Remove-Item Function:\au_BeforeUpdate -ErrorAction Ignore
Remove-Item Function:\au_AfterUpdate -ErrorAction Ignore
Remove-Item Function:\au_GetLatest -ErrorAction Ignore

# Clean up AU global variables
Remove-Variable -Name au_Version -Scope Global -ErrorAction Ignore
Remove-Variable -Name au_Force -Scope Global -ErrorAction Ignore
Remove-Variable -Name Latest -Scope Global -ErrorAction Ignore

# Clean up AU environment variables
Remove-Item Env:\au_Push -ErrorAction Ignore
Remove-Item Env:\api_key -ErrorAction Ignore

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

# Validate parameters
if ($MaxMajorVersion -lt $MinMajorVersion)
{
    Write-Error "MaxMajorVersion ($MaxMajorVersion) cannot be less than MinMajorVersion ($MinMajorVersion)"
    exit 1
}

if ($SpecificVersion)
{
    $specificMajor = [int]($SpecificVersion -split '\.')[0]
    if ($specificMajor -lt $MinMajorVersion -or $specificMajor -gt $MaxMajorVersion)
    {
        Write-Error "SpecificVersion ($SpecificVersion) has major version $specificMajor which is outside the range $MinMajorVersion-$MaxMajorVersion"
        exit 1
    }
}

if (-not $DryRun -and -not $ApiKey)
{
    Write-Error "ApiKey is required unless using -DryRun"
    exit 1
}

Write-Information "=== Erlang/OTP Version Sync ==="
$versionRangeMsg = if ($MaxMajorVersion -eq 99) { ">= $MinMajorVersion" } else { "$MinMajorVersion-$MaxMajorVersion" }
Write-Information "Version Range: $versionRangeMsg"
Write-Information "Max Pushes Per Run: $MaxPushes"
if ($SpecificVersion)
{
    Write-Information "Specific Version: $SpecificVersion"
}
Write-Information "Dry Run: $DryRun"
Write-Information ""

# State file to track pushed versions
$stateFile = Join-Path $PSScriptRoot 'sync-state.json'
$pushedVersions = @()
if (Test-Path $stateFile)
{
    $state = Get-Content $stateFile | ConvertFrom-Json
    $pushedVersions = @($state.pushedVersions)
    Write-Information "Loaded state: $($pushedVersions.Count) versions previously pushed"
}

# Load otp_versions.table (cached)
Write-Information "Loading otp_versions.table..."
$otp = Get-OtpVersions

# Filter OTP versions by major version range
Write-Information "Filtering OTP versions..."
$otpVersions = @()
foreach ($version in $otp.Versions.Keys)
{
    if ($version -match '^(\d+)')
    {
        $major = [int]$Matches[1]
        if ($major -ge $MinMajorVersion -and $major -le $MaxMajorVersion)
        {
            if (-not $SpecificVersion -or $version -eq $SpecificVersion)
            {
                $otpVersions += $version
            }
        }
    }
}

Write-Information "Found $($otpVersions.Count) OTP versions in range $versionRangeMsg"

# Query Chocolatey for published versions
Write-Information "Querying chocolatey.org for published versions..."
$chocoOutput = & choco.exe search erlang --exact --all-versions --limit-output
$publishedVersions = @()
foreach ($line in $chocoOutput)
{
    if ($line -match '^erlang\|(.+)$')
    {
        $publishedVersions += $matches[1]
    }
}

Write-Information "Found $($publishedVersions.Count) published versions on chocolatey.org"

# Find missing versions - normalize OTP versions to match Chocolatey format
$normalizedOtpVersions = $otpVersions | ForEach-Object {
    ConvertTo-ChocolateyVersion $_
}

$missingVersions = @()
for ($i = 0; $i -lt $otpVersions.Count; $i++)
{
    $otpVersion = $otpVersions[$i]
    $normalizedVersion = $normalizedOtpVersions[$i]

    # Skip if already pushed in a previous run
    if ($otpVersion -in $pushedVersions)
    {
        continue
    }

    if ($normalizedVersion -notin $publishedVersions)
    {
        $missingVersions += $otpVersion  # Keep original OTP version for processing
    }
}

Write-Information ""
Write-Information "=== Gap Analysis ==="
Write-Information "Missing versions: $($missingVersions.Count)"

if ($missingVersions.Count -eq 0)
{
    Write-Information "All versions are published! Nothing to do."
    exit 0
}

Write-Information ""
Write-Information "Missing versions:"
foreach ($version in $missingVersions)
{
    Write-Information "  - $version"
}

# Process missing versions
Write-Information ""
if ($DryRun)
{
    Write-Information "=== DRY RUN - Building Packages Without Pushing ==="
}
else
{
    Write-Information "=== Processing Missing Versions ==="
}
Write-Information "Will process up to $MaxPushes versions in this run"

$processedCount = 0
$newlyPushed = @()

foreach ($version in $missingVersions)
{
    if ($processedCount -ge $MaxPushes)
    {
        Write-Information ""
        Write-Information "Reached maximum of $MaxPushes pushes for this run"
        Write-Information "Remaining versions: $($missingVersions.Count - $processedCount)"
        break
    }

    Write-Information ""
    Write-Information "[$($processedCount + 1)/$MaxPushes] Processing version $version..."

    $actionMsg = if ($DryRun) { "Building" } else { "Building and pushing" }
    Write-Information "  $actionMsg version $version..."

    # Reset for clean update

    # Set AU variables for this version
    $env:au_Push = if ($DryRun) { 'false' } else { 'true' }
    $env:api_key = $ApiKey
    $global:au_Version = $version
    $global:au_Force = $true

    # Run AU update for erlang package
    Push-Location (Join-Path $PSScriptRoot 'erlang')
    try
    {
        & .\update.ps1
        if ($LASTEXITCODE -ne 0)
        {
            throw "Update failed for version $version"
        }

        # Push the package if not dry run
        if (-not $DryRun)
        {
            # Push-Package calls choco push which sets $LASTEXITCODE
            # The function doesn't throw on error, so we check exit code
            Push-Package
            if ($LASTEXITCODE -ne 0)
            {
                throw "Push failed for version $version"
            }
        }
    }
    finally
    {
        Pop-Location
        # Clean up global variables
        $global:au_Version = $null
        $global:au_Force = $null
    }

    $processedCount++
    $newlyPushed += $version
    Write-Information "  SUCCESS: Version $version completed successfully"
}

# Update state file with newly pushed versions (only if not dry run)
if (-not $DryRun -and $newlyPushed.Count -gt 0)
{
    $allPushed = @($pushedVersions) + @($newlyPushed)
    $state = @{
        pushedVersions = $allPushed
        lastRun = (Get-Date).ToString('o')
    }
    $state | ConvertTo-Json | Set-Content $stateFile
    Write-Information ""
    Write-Information "State saved: $($allPushed.Count) total versions pushed"
}

Write-Information ""
Write-Information "=== Summary ==="
Write-Information "Processed $processedCount versions in this run"
if ($processedCount -lt $missingVersions.Count)
{
    Write-Information "Remaining: $($missingVersions.Count - $processedCount) versions"
    Write-Information "Run again to continue processing"
}
else
{
    Write-Information "All missing versions processed!"
}
exit 0
