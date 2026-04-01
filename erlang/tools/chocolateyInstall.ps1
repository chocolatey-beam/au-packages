<#
.SYNOPSIS
An install script for installing Erlang silently on the machine via Chocolatey

.NOTES
Author: Luke Bakken - lukerbakken@gmail.com
#>
$ErrorActionPreference = 'Stop'

$package = 'erlang'
$url32 = 'https://github.com/erlang/otp/releases/download/OTP-28.4.1/otp_win32_28.4.1.exe'
$url64 = 'https://github.com/erlang/otp/releases/download/OTP-28.4.1/otp_win64_28.4.1.exe'
$checksum32 = 'c7c4d7df770c0199496e9084e9498d9bab629dda347b904b9e7fdaddb25ca358'
$checksum64 = '8e478c277f2e25520fac72b50497966be46d12e09270c5f8e96cd8fdcae78031'
$ertsVersion = '16.3'

$params = @{
    PackageName = $package
    FileType = 'exe'
    SilentArgs = '/S'
    Url = $url32
    CheckSum = $checksum32
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
