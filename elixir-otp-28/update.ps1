. (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'Shared.ps1')
Import-AUModule

$InformationPreference = 'Continue'

$otpMajorVersion = 28

function global:au_SearchReplace
{
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(?i)(^\s*[$]version\s*=\s*)('.*')" = "`$1'$($Latest.Version)'"
            "(?i)(^\s*[$]otpMajorVersion\s*=\s*)('.*')" = "`$1'$otpMajorVersion'"
        }

        ".\tools\VERIFICATION.txt" = @{
            "(?i)(Version\s*:).*" = "`${1} $($Latest.Version)"
            "(?i)(URL\s*:).*" = "`${1} $($Latest.URL64)"
            "(?i)(Checksum\s*:).*" = "`${1} $($Latest.Checksum64)"
        }

        "$($Latest.PackageName).nuspec" = @{
            "(\<releaseNotes\>).*?(\</releaseNotes\>)" = "`${1}$($Latest.ReleaseNotes)`$2"
        }
    }
}

function global:au_BeforeUpdate
{
    Get-RemoteFiles -Purge -NoSuffix

    # Rename from elixir-otp-N.zip to elixir.zip for simpler install script
    $source = Join-Path -Path 'tools' -ChildPath "elixir-otp-$otpMajorVersion.zip"
    $dest = Join-Path -Path 'tools' -ChildPath 'elixir.zip'
    Move-Item -LiteralPath $source -Destination $dest -Force
}

function global:au_GetLatest
{
    # Get latest release info from GitHub
    $tag = & gh.exe release view --repo elixir-lang/elixir --json tagName --jq .tagName
    if ($LASTEXITCODE -ne 0)
    {
        throw "Failed to get latest release from GitHub"
    }

    $version = $tag -replace '^v', ''
    $url = "https://github.com/elixir-lang/elixir/releases/download/$tag/elixir-otp-$otpMajorVersion.zip"

    return @{
        Version = $version
        URL64 = $url
        FileType = 'zip'
        ReleaseNotes = "https://github.com/elixir-lang/elixir/releases/tag/$tag"
    }
}

Update-Package -ChecksumFor none
