#Requires -Version 7.0

<#
.SYNOPSIS
Orchestrates Elixir package updates for multiple OTP versions.

.DESCRIPTION
Generates and updates Elixir packages for the latest 3 OTP major versions.
Parses otp_versions.table to determine the latest OTP version, then creates
packages for OTP N, N-1, and N-2.
#>

. (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'Shared.ps1')
Import-AUModule

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'

# Get latest OTP major version from otp_versions.table
Write-Information "Fetching otp_versions.table from GitHub..."
$otpVersionsContent = & gh.exe api --header 'Accept: application/vnd.github.v3.raw' 'repos/erlang/otp/contents/otp_versions.table'

# Parse first line to get latest OTP major version
$firstLine = ($otpVersionsContent -split "`n")[0]
if ($firstLine -match '^OTP-(\d+)')
{
    $latestOtpMajor = [int]$matches[1]
}
else
{
    throw "Could not parse latest OTP version from otp_versions.table"
}

Write-Information "Latest OTP major version: $latestOtpMajor"

# Calculate supported OTP versions (latest + previous 2)
$supportedOtpVersions = @($latestOtpMajor, ($latestOtpMajor - 1), ($latestOtpMajor - 2))
Write-Information "Supported OTP versions: $($supportedOtpVersions -join ', ')"

# Generate packages for each OTP version
$packagesToGenerate = @()

foreach ($otpMajor in $supportedOtpVersions)
{
    # Always create elixir-otp-N
    $packagesToGenerate += @{
        Name = "elixir-otp-$otpMajor"
        OtpMajor = $otpMajor
        Title = "Elixir (OTP $otpMajor)"
    }

    # For latest OTP, also create "elixir" package
    if ($otpMajor -eq $latestOtpMajor)
    {
        $packagesToGenerate += @{
            Name = "elixir"
            OtpMajor = $otpMajor
            Title = "Elixir"
        }
    }
}

Write-Information "Generating $($packagesToGenerate.Count) packages..."

foreach ($pkg in $packagesToGenerate)
{
    $packageName = $pkg.Name
    $otpMajor = $pkg.OtpMajor
    $title = $pkg.Title
    $packageDir = Join-Path -Path $PSScriptRoot -ChildPath "..\$packageName"

    Write-Information ""
    Write-Information "Generating package: $packageName (OTP $otpMajor)"

    # Create package directory structure
    if (-not (Test-Path $packageDir))
    {
        New-Item -ItemType Directory -Path $packageDir | Out-Null
        New-Item -ItemType Directory -Path "$packageDir\tools" | Out-Null
    }

    # Generate files from templates
    $erlangDep = "[$otpMajor.0,$($otpMajor + 1).0)"

    # Generate nuspec
    $nuspecContent = Get-Content "$PSScriptRoot\templates\nuspec.template" -Raw
    $nuspecContent = $nuspecContent -replace '@@PACKAGE_ID@@', $packageName
    $nuspecContent = $nuspecContent -replace '@@TITLE@@', $title
    $nuspecContent = $nuspecContent -replace '@@ERLANG_DEPENDENCY@@', $erlangDep
    Set-Content -Path "$packageDir\$packageName.nuspec" -Value $nuspecContent

    # Generate update.ps1
    $updateContent = Get-Content "$PSScriptRoot\templates\update.ps1.template" -Raw
    $updateContent = $updateContent -replace '@@OTP_MAJOR@@', $otpMajor
    Set-Content -Path "$packageDir\update.ps1" -Value $updateContent

    # Copy static files
    Copy-Item "$PSScriptRoot\tools\chocolateyInstall.ps1" "$packageDir\tools\" -Force
    Copy-Item "$PSScriptRoot\tools\chocolateyUninstall.ps1" "$packageDir\tools\" -Force
    Copy-Item "$PSScriptRoot\tools\VERIFICATION.txt" "$packageDir\tools\" -Force
    Copy-Item "$PSScriptRoot\tools\LICENSE.txt" "$packageDir\tools\" -Force
    Copy-Item "$PSScriptRoot\tools\.skipAutoUninstall" "$packageDir\tools\" -Force
    Copy-Item "$PSScriptRoot\README.md" "$packageDir\" -Force
    Copy-Item "$PSScriptRoot\elixir-icon.png" "$packageDir\" -Force

    Write-Information "Package $packageName generated successfully"
}

Write-Information ""
Write-Information "All $($packagesToGenerate.Count) packages generated successfully"
Write-Information ""
Write-Information "Generated packages:"
foreach ($pkg in $packagesToGenerate)
{
    Write-Information "  - $($pkg.Name) (OTP $($pkg.OtpMajor))"
}
