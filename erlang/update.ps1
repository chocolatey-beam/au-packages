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
    $originalVersion = $release.tagName -replace '^OTP-', ''

    # Find installer assets
    $win32Asset = $release.assets | Where-Object { $_.name -match '^otp_win32_[0-9.]+\.exe$' }
    $win64Asset = $release.assets | Where-Object { $_.name -match '^otp_win64_[0-9.]+\.exe$' }

    if (-not $win32Asset -or -not $win64Asset)
    {
        throw "Could not find Windows installers in release assets"
    }

    # Get ERTS version from otp_versions.table (cached) using original version
    $otpVersionsContent = Get-OtpVersionsTable

    # Find the line for this OTP version and extract ERTS version
    $otpLine = ($otpVersionsContent -split "`n") | Where-Object { $_ -match "^OTP-$originalVersion\s*:" } | Select-Object -First 1
    if (-not $otpLine)
    {
        throw "Could not find OTP-$originalVersion in otp_versions.table"
    }

    if ($otpLine -match 'erts-([0-9.]+)')
    {
        $ertsVersion = $Matches[1]
    }
    else
    {
        throw "Could not extract ERTS version from otp_versions.table"
    }

    # Normalize version to Chocolatey format AFTER lookups (28.3 -> 28.3.0)
    $normalizedVersion = ConvertTo-ChocolateyVersion $originalVersion

    $checksum32 = $null
    $checksum64 = $null

    if ($win32Asset.digest -and $win64Asset.digest)
    {
        # Extract checksums from digest field (format: "sha256:hash")
        $checksum32 = ($win32Asset.digest -split ':')[1]
        $checksum64 = ($win64Asset.digest -split ':')[1]
    }
    else
    {
        # Download installers to calculate checksums for older releases
        $win32Url = $win32Asset.url
        $win64Url = $win64Asset.url
        $win32File = Join-Path $PSScriptRoot "otp_win32_$originalVersion.exe"
        $win64File = Join-Path $PSScriptRoot "otp_win64_$originalVersion.exe"

        $jobs = @()
        $ProgressPreference = 'SilentlyContinue'

        # Download 32-bit installer
        $jobs += Start-ThreadJob -ScriptBlock {
            Invoke-WebRequest -Uri $using:win32Url -OutFile $using:win32File
        }

        # Download 64-bit installer
        $jobs += Start-ThreadJob -ScriptBlock {
            Invoke-WebRequest -Uri $using:win64Url -OutFile $using:win64File
        }

        Wait-Job -Job $jobs | Out-Null
        $ProgressPreference = 'Continue'

        # Calculate checksums
        $checksum32 = (Get-FileHash -Path $win32File -Algorithm SHA256).Hash.ToLowerInvariant()
        $checksum64 = (Get-FileHash -Path $win64File -Algorithm SHA256).Hash.ToLowerInvariant()

        # Clean up downloaded files
        Remove-Item $win32File, $win64File -Force
    }

    return @{
        Version = $normalizedVersion
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
