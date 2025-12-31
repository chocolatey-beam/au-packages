$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$packageName = 'copyq'

$fileType = 'exe'
$toolsDir = Split-Path $MyInvocation.MyCommand.Definition
$embedded_path = Get-Item "$toolsDir\*.$fileType"

$pp = Get-PackageParameters
$tasks = @()
if (!$pp.NoStartup) { Write-Information 'Automatically start with Windows'; $tasks += 'startup' }
if (!$pp.NoDesktopIcon) { Write-Information 'Create desktop icon'; $tasks += 'desktopicon' }

$packageArgs = @{
    packageName = $packageName
    fileType = $fileType
    file = $embedded_path
    silentArgs = '/VERYSILENT /TASKS=' + ($tasks -join ',')
    validExitCodes = @(0)
    softwareName = $packageName
}
Install-ChocolateyInstallPackage @packageArgs
Remove-Item $embedded_path -ea 0

$packageName = $packageArgs.packageName
$installLocation = Get-AppInstallLocation $packageName
if (!$installLocation) { Write-Warning "Can't find $packageName install location"; return }
Write-Information "$packageName installed to '$installLocation'"

Register-Application "$installLocation\$packageName.exe"
Write-Information "$packageName registered as $packageName"

Start-Process "$installLocation\$packageName.exe"
