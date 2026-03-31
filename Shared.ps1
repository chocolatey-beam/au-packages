#Requires -Version 7.0

<#
.SYNOPSIS
Shared utility functions for AU package scripts

.DESCRIPTION
Common functions used across package update scripts to avoid duplication.
#>

function Get-RepositoryRoot
{
    <#
    .SYNOPSIS
    Finds the repository root by searching for .git directory

    .DESCRIPTION
    Walks up the directory tree from the calling script's location
    until it finds a .git directory, indicating the repository root.

    .EXAMPLE
    $repoRoot = Get-RepositoryRoot
    #>
    $current = $PSScriptRoot
    while ($current -and -not (Test-Path -PathType Container -LiteralPath (Join-Path $current '.git')))
    {
        $current = Split-Path -Path $current -Parent
    }
    if (-not $current)
    {
        throw "Could not find repository root (no .git directory found)"
    }
    return $current
}

function Import-AUModule
{
    <#
    .SYNOPSIS
    Imports the Chocolatey-AU module from submodule or global install

    .DESCRIPTION
    Checks if Chocolatey-AU is available globally. If not, imports from
    the _modules/au submodule. This allows scripts to work with either
    a global AU installation or the submodule version.

    .EXAMPLE
    Import-AUModule
    #>
    if (-not (Get-Module -Name Chocolatey-AU -ListAvailable))
    {
        $repoRoot = Get-RepositoryRoot

        $auModulePath = Join-Path -Path $repoRoot -ChildPath '_modules'
        $auModulePath = Join-Path -Path $auModulePath -ChildPath 'au'
        $auModulePath = Join-Path -Path $auModulePath -ChildPath 'src'
        $auModulePath = Join-Path -Path $auModulePath -ChildPath 'Chocolatey-AU.psd1'
        if (-not (Test-Path $auModulePath))
        {
            throw "AU module not found at $auModulePath. Run 'git submodule update --init' first."
        }
        Import-Module -Force $auModulePath
    }
}

function Copy-TemplateFile
{
    <#
    .SYNOPSIS
    Copies all .in template files to their working file equivalents

    .DESCRIPTION
    Recursively finds all files with .in suffix in the current directory
    and copies them to files without the .in suffix. This allows keeping
    clean templates in source control while generating working files.

    .EXAMPLE
    Copy-TemplateFile
    Copies all *.in files in current directory and subdirectories

    .NOTES
    - erlang.nuspec.in -> erlang.nuspec
    - tools/chocolateyInstall.ps1.in -> tools/chocolateyInstall.ps1
    - Working files should be gitignored
    #>
    $templateFiles = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter '*.in'

    foreach ($template in $templateFiles)
    {
        $targetPath = $template.FullName -replace '\.in$', ''
        Copy-Item -Force $template.FullName $targetPath
    }
}

function Get-OtpVersions
{
    <#
    .SYNOPSIS
    Gets parsed OTP versions data with caching

    .DESCRIPTION
    Downloads otp_versions.table from Erlang/OTP repository with local
    caching. Validates cached file with checksum and age (24 hours).
    Returns a structured object with version information.

    .EXAMPLE
    $otp = Get-OtpVersions
    $otp.LatestVersion   # "28.4.1"
    $otp.LatestMajor     # 28
    $otp.Versions['28.4.1']  # "16.3" (ERTS version)

    .OUTPUTS
    PSCustomObject with properties:
    - LatestVersion: Full version string of latest release
    - LatestMajor: Major version number (int)
    - Versions: Hashtable mapping OTP version to ERTS version
    #>

    $repoRoot = Get-RepositoryRoot

    $cacheFile = Join-Path $repoRoot 'otp_versions.table'
    $checksumFile = Join-Path $repoRoot 'otp_versions.table.sha256'
    $maxAgeHours = 24

    $needsDownload = $false

    if (Test-Path $cacheFile)
    {
        $fileAge = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
        if ($fileAge.TotalHours -gt $maxAgeHours)
        {
            $needsDownload = $true
        }
        elseif (Test-Path $checksumFile)
        {
            $cachedChecksum = Get-Content $checksumFile
            $currentChecksum = (Get-FileHash -Path $cacheFile -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($cachedChecksum -ne $currentChecksum)
            {
                $needsDownload = $true
            }
        }
        else
        {
            $needsDownload = $true
        }
    }
    else
    {
        $needsDownload = $true
    }

    if ($needsDownload)
    {
        $url = 'https://raw.githubusercontent.com/erlang/otp/refs/heads/master/otp_versions.table'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $cacheFile
        $ProgressPreference = 'Continue'

        $checksum = (Get-FileHash -Path $cacheFile -Algorithm SHA256).Hash.ToLowerInvariant()
        Set-Content -Path $checksumFile -Value $checksum
    }

    # Parse the table
    $content = Get-Content -Path $cacheFile
    $versions = @{}
    $latestVersion = $null
    $latestMajor = $null

    foreach ($line in $content)
    {
        if ($line -match '^OTP-([0-9.]+)\s*:.*erts-([0-9.]+)')
        {
            $otpVersion = $Matches[1]
            $ertsVersion = $Matches[2]
            $versions[$otpVersion] = $ertsVersion

            if ($null -eq $latestVersion)
            {
                $latestVersion = $otpVersion
                if ($otpVersion -match '^(\d+)')
                {
                    $latestMajor = [int]$Matches[1]
                }
            }
        }
    }

    return [PSCustomObject]@{
        LatestVersion = $latestVersion
        LatestMajor   = $latestMajor
        Versions      = $versions
    }
}

function Test-LatestOtpVersion
{
    <#
    .SYNOPSIS
    Verifies the tracked OTP version matches the latest from otp_versions.table

    .DESCRIPTION
    Compares the OTP version in .latest_otp_version file against the
    latest version in otp_versions.table. Throws error if they don't match,
    indicating Elixir packages need regeneration.

    .EXAMPLE
    Test-LatestOtpVersion
    #>
    $repoRoot = Get-RepositoryRoot
    $trackedFile = Join-Path $repoRoot '.latest_otp_version'

    if (-not (Test-Path $trackedFile))
    {
        throw "Tracking file not found: $trackedFile"
    }

    $trackedOtp = [int](Get-Content $trackedFile)
    $otp = Get-OtpVersions

    if ($otp.LatestMajor -ne $trackedOtp)
    {
        throw "OTP version changed from $trackedOtp to $($otp.LatestMajor)! Regenerate Elixir packages with generate-packages.ps1 and update .latest_otp_version"
    }
}

function ConvertTo-ChocolateyVersion
{
    <#
    .SYNOPSIS
    Normalizes a version string to Chocolatey's format

    .DESCRIPTION
    Chocolatey normalizes versions to Major.Minor.Build.Revision format.
    This function converts version strings to match Chocolatey's normalization:
    - 2 parts (28.3) -> 28.3.0
    - 3 parts (27.3.4) -> 27.3.4 (unchanged)
    - 4 parts (25.1.2.1) -> 25.1.2.1 (unchanged)

    .PARAMETER Version
    The version string to normalize

    .EXAMPLE
    ConvertTo-ChocolateyVersion '28.3'
    Returns: 28.3.0

    .EXAMPLE
    ConvertTo-ChocolateyVersion '27.3.4'
    Returns: 27.3.4
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $v = [version]$Version

    # Build normalized version string based on which parts are present
    if ($v.Revision -ne -1)
    {
        # 4 parts: Major.Minor.Build.Revision
        return "$($v.Major).$($v.Minor).$($v.Build).$($v.Revision)"
    }
    elseif ($v.Build -ne -1)
    {
        # 3 parts: Major.Minor.Build
        return "$($v.Major).$($v.Minor).$($v.Build)"
    }
    else
    {
        # 2 parts: Major.Minor - Chocolatey adds .0
        return "$($v.Major).$($v.Minor).0"
    }
}
