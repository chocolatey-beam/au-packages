. (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'Shared.ps1')
Import-AUModule

$InformationPreference = 'Continue'

function global:au_SearchReplace
{
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(^\s*\`$url32\s*=\s*)('.*')" = "`$1'$($Latest.URL32)'"
            "(^\s*\`$url64\s*=\s*)('.*')" = "`$1'$($Latest.URL64)'"
            "(^\s*\`$checksum32\s*=\s*)('.*')" = "`$1'$($Latest.Checksum32)'"
            "(^\s*\`$checksum64\s*=\s*)('.*')" = "`$1'$($Latest.Checksum64)'"
            "(^\s*\`$ertsVersion\s*=\s*)('.*')" = "`$1'$($Latest.ErtsVersion)'"
        }

        ".\tools\chocolateyUninstall.ps1" = @{
            "(^\s*\`$ertsVersion\s*=\s*)('.*')" = "`$1'$($Latest.ErtsVersion)'"
        }

        "erlang.nuspec" = @{
            "(\<releaseNotes\>).*?(\</releaseNotes\>)" = "`${1}$($Latest.ReleaseNotes)`$2"
        }
    }
}

# Copy template files to working files before AU processes them
Copy-TemplateFiles

function global:au_GetLatest
{
    # Check if a specific version is requested
    $targetVersion = if (Get-Variable -Name au_Version -Scope Global -ErrorAction Ignore) { $global:au_Version } else { 'latest' }

    # Get release from GitHub using gh CLI with assets
    if ($targetVersion -eq 'latest')
    {
        $releaseJson = & gh.exe release view --repo erlang/otp --json 'tagName,url,assets'
    }
    else
    {
        $releaseJson = & gh.exe release view --repo erlang/otp "OTP-$targetVersion" --json 'tagName,url,assets'
    }

    if ($LASTEXITCODE -ne 0)
    {
        throw "Failed to get release from GitHub"
    }

    $release = $releaseJson | ConvertFrom-Json
    $version = $release.tagName -replace '^OTP-', ''

    # Find installer assets
    $win32Asset = $release.assets | Where-Object { $_.name -match '^otp_win32_[0-9.]+\.exe$' }
    $win64Asset = $release.assets | Where-Object { $_.name -match '^otp_win64_[0-9.]+\.exe$' }

    if (-not $win32Asset -or -not $win64Asset)
    {
        throw "Could not find Windows installers in release assets"
    }

    # Extract checksums from digest field (format: "sha256:hash")
    $checksum32 = ($win32Asset.digest -split ':')[1]
    $checksum64 = ($win64Asset.digest -split ':')[1]

    # Get ERTS version from otp_versions.table
    $otpVersionsContent = & gh.exe api --header 'Accept: application/vnd.github.v3.raw' 'repos/erlang/otp/contents/otp_versions.table'
    if ($LASTEXITCODE -ne 0)
    {
        throw "Failed to fetch otp_versions.table"
    }

    # Find the line for this OTP version and extract ERTS version
    $otpLine = ($otpVersionsContent -split "`n") | Where-Object { $_ -match "^OTP-$version\s*:" } | Select-Object -First 1
    if (-not $otpLine)
    {
        throw "Could not find OTP-$version in otp_versions.table"
    }

    if ($otpLine -match 'erts-([0-9.]+)')
    {
        $ertsVersion = $Matches[1]
    }
    else
    {
        throw "Could not extract ERTS version from otp_versions.table"
    }

    return @{
        Version = $version
        URL32 = $win32Asset.url
        URL64 = $win64Asset.url
        Checksum32 = $checksum32
        Checksum64 = $checksum64
        ChecksumType32 = 'sha256'
        ChecksumType64 = 'sha256'
        ReleaseNotes = $release.url
        ErtsVersion = $ertsVersion
    }
}

Update-Package -ChecksumFor none
