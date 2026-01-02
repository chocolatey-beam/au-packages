. (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'Shared.ps1')
Import-AUModule

$InformationPreference = 'Continue'

function global:au_SearchReplace
{
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(?i)(^\s*[$]version\s*=\s*)('.*')" = "`$1'$($Latest.Version)'"
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

# Copy template files to working files before AU processes them
Copy-TemplateFiles

function global:au_BeforeUpdate
{
    Get-RemoteFiles -Purge -NoSuffix

    # Rename from rebar3.escript to rebar3 (no extension) for wrapper scripts
    $source = Join-Path -Path 'tools' -ChildPath 'rebar3.escript'
    $dest = Join-Path -Path 'tools' -ChildPath 'rebar3'
    Move-Item -LiteralPath $source -Destination $dest -Force
}

function global:au_GetLatest
{
    # Get latest release info from GitHub
    $tag = & gh.exe release view --repo erlang/rebar3 --json tagName --jq .tagName
    if ($LASTEXITCODE -ne 0)
    {
        throw "Failed to get latest release from GitHub"
    }

    $version = $tag
    $url = "https://github.com/erlang/rebar3/releases/download/$tag/rebar3"

    return @{
        Version = $version
        URL64 = $url
        FileType = 'escript'
        ReleaseNotes = "https://github.com/erlang/rebar3/releases/tag/$tag"
    }
}

Update-Package -ChecksumFor none
