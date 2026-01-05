#Requires -Version 7.0

<#
.SYNOPSIS
Verifies the tracked OTP version matches the latest from otp_versions.table

.DESCRIPTION
Compares the OTP version in .latest_otp_version file against the
latest version in otp_versions.table. Throws error if they don't match,
indicating Elixir packages need regeneration.
#>

. (Join-Path -Path $PSScriptRoot -ChildPath 'Shared.ps1')

$ErrorActionPreference = 'Stop'

Test-LatestOtpVersion

Write-Host "OTP version check passed"
