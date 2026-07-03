<#
.SYNOPSIS
An install script for installing Erlang silently on the machine via Chocolatey

.NOTES
Author: Luke Bakken - lukerbakken@gmail.com
#>
$ErrorActionPreference = 'Stop'

$package = 'erlang'
$url64 = 'https://github.com/erlang/otp/releases/download/OTP-29.0.3/otp_win64_29.0.3.exe'
$checksum64 = 'f4c331112c4a4b58e7a7edda55a145bfdbe6ffa318e774f67b415f9666006baa'
$ertsVersion = '17.0.3'

$params = @{
    PackageName = $package
    FileType = 'exe'
    SilentArgs = '/S'
    CheckSumType = 'sha256'
    Url64 = $url64
    CheckSum64 = $checksum64
    CheckSumType64 = 'sha256'
    validExitCodes = @(0)
}

Install-ChocolateyPackage @params

$erlangProgramFilesPath = ((Get-ItemProperty -Path HKLM:\SOFTWARE\WOW6432Node\Ericsson\Erlang\$ertsVersion).'(default)')
$erlangErtsBinPath = (Join-Path -Path $erlangProgramFilesPath -ChildPath "erts-$ertsVersion" | Join-Path -ChildPath 'bin')

Install-BinFile -Name 'ct_run'   -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'ct_run.exe')
Install-BinFile -Name 'erl'      -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'erl.exe')
Install-BinFile -Name 'werl'     -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'werl.exe')
Install-BinFile -Name 'erlc'     -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'erlc.exe')
Install-BinFile -Name 'escript'  -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'escript.exe')
Install-BinFile -Name 'dialyzer' -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'dialyzer.exe')
Install-BinFile -Name 'typer'    -Path (Join-Path -Path $erlangErtsBinPath -ChildPath 'typer.exe')
