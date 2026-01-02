#Requires -Version 7.0

<#
.SYNOPSIS
Force push Elixir packages with updated LICENSE and checksums
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Use au_ForcePush workaround - adds --force flag to avoid empty string bug
$env:au_ForcePush = 'true'

# Configure AU
$env:au_Push = 'true'
$env:api_key = $ApiKey
$global:au_WhatIf = $false

Write-Information "Forcing update and push of Elixir packages..."
Write-Information "Using au_ForcePush='true' to add --force flag and avoid empty string bug"

# Force update specific packages
& "$PSScriptRoot\Update-Packages.ps1" -ForcedPackages 'elixir elixir-otp-26 elixir-otp-27 elixir-otp-28'
