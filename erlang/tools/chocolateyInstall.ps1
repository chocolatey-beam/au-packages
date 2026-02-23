<#
.SYNOPSIS
An install script for installing Erlang silently on the machine via Chocolatey

.NOTES
Author: Luke Bakken - lukerbakken@gmail.com
#>
$ErrorActionPreference = 'Stop'

$package = 'erlang'
$url32 = 'https://github.com/erlang/otp/releases/download/OTP-28.3.2/otp_win32_28.3.2.exe'
$url64 = 'https://github.com/erlang/otp/releases/download/OTP-28.3.2/otp_win64_28.3.2.exe'
$checksum32 = '2545a3e9a21760167436b15d0748d01d4d92ba8dc913d29e0b1c78a993733e5c'
$checksum64 = '6f8fbdc224e30c9ae32da854f431ca54be7bbf6739eb446a42cf7edf0c1346cb'
$ertsVersion = '16.2.1'

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
