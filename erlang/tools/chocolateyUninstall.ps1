<#
.SYNOPSIS
An uninstall script for Erlang

.NOTES
Author: Luke Bakken - lukerbakken@gmail.com
#>

$package = 'erlang'
$ertsVersion = '17.0.6'

$erlangProgramFilesPath = ((Get-ItemProperty -Path HKLM:\SOFTWARE\WOW6432Node\Ericsson\Erlang\$ertsVersion).'(default)')

Start-Process -Wait -FilePath (Join-Path -Path $erlangProgramFilesPath -ChildPath 'uninstall.exe') -ArgumentList '/S'

# ...and remove the shim files as well.

$erlangErtsBinPath = (Join-Path -Path $erlangProgramFilesPath -ChildPath "erts-$ertsVersion" | Join-Path -ChildPath 'bin')

Uninstall-BinFile -Name 'ct_run'   -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'ct_run.exe')
Uninstall-BinFile -Name 'erl'      -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'erl.exe')
Uninstall-BinFile -Name 'werl'     -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'werl.exe')
Uninstall-BinFile -Name 'erlc'     -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'erlc.exe')
Uninstall-BinFile -Name 'escript'  -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'escript.exe')
Uninstall-BinFile -Name 'dialyzer' -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'dialyzer.exe')
Uninstall-BinFile -Name 'typer'    -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'typer.exe')
