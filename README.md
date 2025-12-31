# Chocolatey AU Packages

[![update-au-packages](https://github.com/chocolatey-beam/au-packages/actions/workflows/update.yml/badge.svg)](https://github.com/chocolatey-beam/au-packages/actions/workflows/update.yml)
[![validate-powershell-scripts](https://github.com/chocolatey-beam/au-packages/actions/workflows/validate.yml/badge.svg)](https://github.com/chocolatey-beam/au-packages/actions/workflows/validate.yml)
[![Update status](https://img.shields.io/badge/Update-Status-blue)](https://gist.github.com/lukebakken/7c671e5b6c0431b43e29fe2446e212c4)

This repository contains Chocolatey packages managed with the [AU (Automatic Updater)](https://github.com/majkinetor/au) framework.

## Packages

- **[rebar3](https://community.chocolatey.org/packages/rebar3)** - Erlang build tool

## Automated Updates

A GitHub Actions workflow runs weekly to automatically check for new package versions and publish updates to chocolatey.org.

## Local Development

### Prerequisites

- PowerShell 7+
- [AU Module](https://github.com/majkinetor/au): `Install-Module AU -Scope CurrentUser`
- [gh CLI](https://cli.github.com/) for GitHub API access

### Testing a Package

To test a package update locally:

```powershell
cd rebar3
$au_Force = $true
.\update.ps1
```

This will:
- Detect the latest version from GitHub
- Download required files
- Update package files
- Pack the package
- NOT push (unless `$au_Push = $true`)

### Testing All Packages

To check all packages for updates:

```powershell
$au_WhatIf = $false
$au_Push = $false
.\update_all.ps1
```

### Creating a New Package

1. Create a directory for your package (e.g., `mypackage/`)
2. Create `mypackage.nuspec` with package metadata
3. Create `tools/` directory with install/uninstall scripts
4. Create `update.ps1` with AU functions:
   - `au_GetLatest` - Detect latest version
   - `au_SearchReplace` - Define file updates
   - `au_BeforeUpdate` - Download files (optional)

See the [rebar3 package](rebar3/) for a complete example.

## AU Framework

The AU framework automates:
- Version detection from upstream sources
- File downloads and checksum calculation
- Package file updates via regex
- Packing and pushing to chocolatey.org
- Retry logic for transient failures

### Key Functions

**`au_GetLatest`** - Returns hashtable with version info:
```powershell
function global:au_GetLatest {
    return @{
        Version = $version
        URL64 = $downloadUrl
    }
}
```

**`au_SearchReplace`** - Defines regex replacements:
```powershell
function global:au_SearchReplace {
    @{
        ".\tools\install.ps1" = @{
            "(version\s*=\s*)('.*')" = "`$1'$($Latest.Version)'"
        }
    }
}
```

**`au_BeforeUpdate`** - Pre-update actions:
```powershell
function global:au_BeforeUpdate {
    Get-RemoteFiles -Purge -NoSuffix
}
```

## GitHub Actions

### Validation Workflow

Runs on every push and pull request:
- Validates PowerShell scripts with PSScriptAnalyzer
- Ensures code quality and consistent formatting

### Update Workflow

Runs weekly (Sunday 5:30 AM UTC):
- Checks all packages for updates
- Downloads new versions
- Pushes to chocolatey.org automatically

## Environment Variables

For local testing, create `update_vars.ps1` (not tracked in git):

```powershell
$Env:au_Push = 'false'
$Env:api_key = 'your-chocolatey-api-key'
$Env:github_api_key = 'your-github-token'
```

For GitHub Actions, set secrets:
- `CHOCOLATEY_API_KEY` - Your Chocolatey API key
- `GITHUB_TOKEN` - Automatically provided

## Validation

Run PSScriptAnalyzer on all scripts:

```powershell
.\Test-All.ps1
```

All scripts must pass validation before committing.
