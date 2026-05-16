param(
    [string]$Version
)

. (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'Shared.ps1')
Import-AUModule

$InformationPreference = 'Continue'

function global:au_SearchReplace
{
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(^\s*\`$url64\s*=\s*)('.*')" = "`$1'$($Latest.URL64)'"
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

function global:au_GetLatest
{
    # Start-ThreadJob requires PowerShell 7+, which is what we use
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCompatibleCommands', '', Justification = 'Start-ThreadJob is available in PowerShell 7+ which is our target')]
    param()

    # Check for version in order of precedence: parameter, global variable, latest
    $targetVersion = if ($Version)
    {
        $Version
    }
    elseif (Get-Variable -Name au_Version -Scope Global -ErrorAction Ignore)
    {
        $global:au_Version
    }
    else
    {
        'latest'
    }

    # Get OTP versions table (cached)
    $otp = Get-OtpVersions

    # Determine target version
    if ($targetVersion -eq 'latest')
    {
        $targetVersion = $otp.LatestVersion
    }

    # Get release from GitHub using gh CLI
    $releaseJson = & gh.exe release view --repo erlang/otp "OTP-$targetVersion" --json 'tagName,url,assets'

    if ($LASTEXITCODE -ne 0)
    {
        throw "Failed to get release from GitHub"
    }

    $release = $releaseJson | ConvertFrom-Json
    $originalVersion = $release.tagName -replace '^OTP-', ''

    # Find installer assets
    $win64Asset = $release.assets | Where-Object { $_.name -match '^otp_win64_[0-9.]+\.exe$' }

    if (-not $win64Asset)
    {
        throw "Could not find Windows 64-bit installers in release assets"
    }

    # Get ERTS version from parsed table
    $ertsVersion = $otp.Versions[$originalVersion]
    if (-not $ertsVersion)
    {
        throw "Could not extract ERTS version from otp_versions.table"
    }

    # Normalize version to Chocolatey format AFTER lookups (28.3 -> 28.3.0)
    $normalizedVersion = ConvertTo-ChocolateyVersion $originalVersion

    $checksum64 = $null

    if ($win64Asset.digest)
    {
        # Extract checksums from digest field (format: "sha256:hash")
        $checksum64 = ($win64Asset.digest -split ':')[1]
    }
    else
    {
        # Download installers to calculate checksums for older releases
        $win64Url = $win64Asset.url
        $win64File = Join-Path $PSScriptRoot "otp_win64_$originalVersion.exe"

        $jobs = @()
        $ProgressPreference = 'SilentlyContinue'

        # Download 64-bit installer
        $jobs += Start-ThreadJob -ScriptBlock {
            Invoke-WebRequest -Uri $using:win64Url -OutFile $using:win64File
        }

        Wait-Job -Job $jobs | Out-Null
        $ProgressPreference = 'Continue'

        # Calculate checksums
        $checksum64 = (Get-FileHash -Path $win64File -Algorithm SHA256).Hash.ToLowerInvariant()

        # Clean up downloaded file
        Remove-Item $win64File -Force
    }

    return @{
        Version = $normalizedVersion
        URL64 = $win64Asset.url
        Checksum64 = $checksum64
        ChecksumType64 = 'sha256'
        ReleaseNotes = $release.url
        ErtsVersion = $ertsVersion
    }
}

Update-Package -ChecksumFor none
