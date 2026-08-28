<#
.SYNOPSIS
Installs Elixir programming language

.NOTES
Author: Luke Bakken - lukerbakken@gmail.com
#>

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$packageName = 'elixir'
$version = '1.20.4'
$otpMajorVersion = '28'

$toolsDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$zipFile = Join-Path -Path $toolsDir -ChildPath 'elixir.zip'

# Verify the embedded file exists
if (-not (Test-Path -LiteralPath $zipFile))
{
    throw "Elixir zip file not found at $zipFile"
}

Write-Information "Installing Elixir $version for OTP $otpMajorVersion..."

# Extract the embedded zip file
Get-ChocolateyUnzip -FileFullPath $zipFile -Destination $toolsDir

# Remove the zip file after extraction
Remove-Item -LiteralPath $zipFile -Force -ErrorAction SilentlyContinue

$elixirBin = Join-Path -Path $toolsDir -ChildPath 'bin'

Write-Information @"
------------------------------------------------------------------------
Elixir $version has been installed to:

$elixirBin

The following commands are now available:
- elixir
- elixirc
- mix
- iex

Note: Elixir executables are automatically added to PATH by Chocolatey.
------------------------------------------------------------------------
"@

Write-Information "Elixir installed successfully"
