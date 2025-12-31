<#
.SYNOPSIS
Installs Rebar3 Erlang build tool

.NOTES
Author: Luke Bakken - luke@bakken.io
#>

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$packageName = 'rebar3'
$version = '3.25.1.20251231'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$rebar3File = Join-Path -Path $toolsDir -ChildPath 'rebar3'
$rebar3Cmd = Join-Path -Path $toolsDir -ChildPath 'rebar3.cmd'

# Verify the embedded file exists
if (-not (Test-Path -LiteralPath $rebar3File))
{
    throw "Rebar3 binary not found at $rebar3File"
}

Write-Information "Installing rebar3 $version..."

# Create shim for rebar3.cmd
Install-BinFile -Name 'rebar3' -Path $rebar3Cmd

Write-Information "Rebar3 installed successfully"
