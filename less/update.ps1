Import-Module au

$releases = 'http://guysalias.tk/misc/less/'

function global:au_SearchReplace
{
    @{
        ".\tools\VERIFICATION.txt" = @{
            "(?i)(\s+x32:).*" = "`${1} $($Latest.URL32)"
            "(?i)(checksum32:).*" = "`${1} $($Latest.Checksum32)"
        }
    }
}

function global:au_BeforeUpdate
{
    Set-Alias 7z $Env:chocolateyInstall\tools\7z.exe

    $lessdir = "$PSScriptRoot\less-*-win*"
    Remove-Item $lessdir -Recurse -Force -ea ignore

    Invoke-WebRequest $Latest.URL32 -OutFile "$PSScriptRoot\less.7z"
    7z x $PSScriptRoot\less.7z

    Remove-Item $PSScriptRoot\tools\* -Recurse -Force -Exclude VERIFICATION.txt
    Move-Item $lessdir\* $PSScriptRoot\tools -Force
    Remove-Item $lessdir -Recurse -Force -ea ignore
    Remove-Item $PSScriptRoot\less.7z -ea ignore
}

function global:au_GetLatest
{
    $download_page = Invoke-WebRequest -Uri $releases -UseBasicParsing

    $re = 'less-.+win.+\.7z$'
    $url = $download_page.links | Where-Object href -Match $re | Select-Object -First 1 -expand href
    $version = "$( ($url -split '-' | Select-Object -Index 1) / 100 )"
    @{
        URL32 = $releases + $url
        Version = $version
    }
}

try
{
    Update-Package -ChecksumFor none
}
catch
{
    $ignore = 'Unable to connect to the remote server'
    if ($_ -match $ignore) { Write-Host $ignore; 'ignore' }  else { throw $_ }
}
