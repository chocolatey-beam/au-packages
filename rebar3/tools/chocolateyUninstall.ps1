<#
.SYNOPSIS
Uninstalls Rebar3 Erlang build tool

.NOTES
Author: Luke Bakken - luke@bakken.io
#>

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$packageName = 'rebar3'

$toolsDir = Split-Path -LiteralPath $MyInvocation.MyCommand.Definition -Parent
$rebar3Cmd = Join-Path -Path $toolsDir -ChildPath 'rebar3.cmd'

Write-Information "Uninstalling rebar3..."

# Remove shim
Uninstall-BinFile -Name 'rebar3' -Path $rebar3Cmd

Write-Information "Rebar3 uninstalled successfully"
