# AGENTS.md - AI Assistant Context

This file provides comprehensive context for AI assistants working on this repository.

## Repository Purpose

This repository manages Chocolatey packages for BEAM ecosystem tools (Erlang, Elixir, rebar3) using the Chocolatey-AU (Automatic Updater) framework. AU automates detection of new software versions and updates packages accordingly.

**Maintainer:** Luke Bakken (@lukebakken)
**Repository:** https://github.com/chocolatey-beam/au-packages

## Architecture Overview

### Package Management Strategy

**Three package types:**

1. **Erlang** - Single package, downloads installers at install time
2. **rebar3** - Single package, embeds binary in nupkg
3. **Elixir** - Four packages generated from templates (elixir, elixir-otp-26, elixir-otp-27, elixir-otp-28)

**Key principle:** Nuspec files are committed with current versions, not templates with 0.0.0. AU updates them in place when new versions are released.

### Directory Structure

```
au-packages/
├── .github/workflows/
│   ├── update.yml              # Daily package updates (5:30 AM UTC)
│   └── validate.yml            # PSScriptAnalyzer on push/PR
├── _modules/au/                # AU module submodule (our fork with fixes)
├── _elixir-gen/                # Elixir package generator
│   ├── generate-packages.ps1   # Creates 4 Elixir packages
│   ├── templates/              # Nuspec and update.ps1 templates
│   └── tools/                  # Static install/uninstall scripts
├── elixir/                     # Generated package (committed)
├── elixir-otp-26/              # Generated package (committed)
├── elixir-otp-27/              # Generated package (committed)
├── elixir-otp-28/              # Generated package (committed)
├── erlang/                     # Erlang package
│   ├── erlang.nuspec           # Version 28.3.0 (committed)
│   ├── update.ps1              # AU update script
│   └── tools/                  # Install/uninstall scripts
├── rebar3/                     # rebar3 package
│   ├── rebar3.nuspec           # Version 3.25.1 (committed)
│   ├── rebar3.nuspec.in        # Template (still used)
│   ├── update.ps1              # AU update script
│   └── tools/                  # Install/uninstall scripts + templates
├── icons/                      # Centralized package icons
│   ├── elixir.png
│   ├── erlang.png
│   └── rebar3.png
├── Shared.ps1                  # Common utility functions
├── Update-Packages.ps1         # AU batch updater
├── Test-Packages.ps1           # Force test all packages
├── Invoke-Validation.ps1       # PSScriptAnalyzer validation
├── Test-LatestOtpVersion.ps1   # OTP version check
├── Sync-ErlangVersions.ps1     # Batch Erlang version publisher
├── Push-ElixirPackages.ps1     # Force push Elixir packages
├── .latest_otp_version         # Tracks OTP major version (28)
├── PSScriptAnalyzerSettings.psd1
└── README.md
```

### Gitignored Files

- `*.nupkg` - Generated packages
- `sync-state.json` - Sync script state
- `otp_versions.table*` - Cached OTP versions
- `Update-AUPackages.md` - Generated reports
- `Update-History.md` - Generated history
- `update_vars.ps1` - Local configuration (secrets)

**Important:** Nuspec files and install scripts are NOT gitignored - they're committed with current versions.

## Current Packages

### Erlang

**What:** Erlang/OTP programming language and runtime
**Source:** https://github.com/erlang/otp
**Current Version:** 28.3.0
**Package Type:** Downloads installers at install time (not embedded)

**Key features:**
- Supports both 32-bit and 64-bit Windows
- Gets checksums from GitHub release `digest` field (newer releases)
- Downloads and calculates checksums for older releases without digest
- Parses `otp_versions.table` to get ERTS version
- Normalizes version to Chocolatey format (28.3 -> 28.3.0)
- Creates shims for Erlang tools (erl, erlc, escript, dialyzer, typer, etc.)

**Special handling:**
- Version parameter: Can specify version via `-Version` parameter or `$global:au_Version`
- ERTS version detection: Parsed from otp_versions.table, not by installing
- Checksum strategy: Uses GitHub digest API when available, downloads for older versions
- Version normalization: Critical for AU's Chocolatey existence check

### rebar3

**What:** Erlang build tool
**Source:** https://github.com/erlang/rebar3
**Current Version:** 3.25.1
**Package Type:** Embeds escript binary in nupkg (~842KB)

**Key features:**
- Binary has no file extension (rebar3, not rebar3.escript)
- Includes wrapper scripts (rebar3.cmd, rebar3.ps1)
- Uses `Get-RemoteFiles` to download and embed
- Still uses `.in` templates for some files

**Special handling:**
- Extensionless file requires `<file src="tools/**" target="tools" />` wildcard
- Renames downloaded file from rebar3.escript to rebar3
- VERIFICATION.txt documents embedded file

### Elixir (4 packages)

**What:** Elixir programming language
**Source:** https://github.com/elixir-lang/elixir
**Current Version:** 1.19.4
**Package Type:** Embeds zip files in nupkg (~8MB each)

**Packages:**
- `elixir` - Latest OTP (currently 28)
- `elixir-otp-28` - Specific OTP 28
- `elixir-otp-27` - Specific OTP 27
- `elixir-otp-26` - Specific OTP 26

**Key features:**
- Generated from templates in `_elixir-gen/`
- Each package depends on specific Erlang OTP major version
- Supports latest 3 OTP major versions
- All 4 packages committed to git (not gitignored)

**Special handling:**
- Generator parses `otp_versions.table` to determine latest OTP
- Creates 4 packages: one for each of last 3 OTP versions, plus generic "elixir"
- Manual regeneration required when OTP major version changes
- `.latest_otp_version` tracks current OTP major version

## Shared.ps1 Functions

### Get-RepositoryRoot

Finds the repository root by walking up the directory tree looking for `.git` directory.

**Used by:** All functions that need to find repo-relative paths

### Import-AUModule

Imports Chocolatey-AU module from submodule or global install. Checks for global module first, falls back to `_modules/au` submodule.

**Used by:** All package update scripts

### Copy-TemplateFile

Copies all `.in` template files to working files (removes `.in` suffix). Used by rebar3 package which still uses templates.

**Note:** Erlang no longer uses templates - nuspec is committed directly.

### Get-OtpVersions

Downloads and caches `otp_versions.table` from Erlang/OTP repository, returning a structured object.

**Returns:** `PSCustomObject` with:
- `LatestVersion` - Full version string (e.g., "28.4.1")
- `LatestMajor` - Major version number as int (e.g., 28)
- `Versions` - Hashtable mapping OTP version to ERTS version

**Example:**
```powershell
$otp = Get-OtpVersions
$otp.LatestVersion        # "28.4.1"
$otp.LatestMajor          # 28
$otp.Versions['28.4.1']   # "16.3" (ERTS version)
```

**Caching:**
- Location: Repository root
- Files: `otp_versions.table`, `otp_versions.table.sha256`
- Max age: 24 hours
- Validation: SHA256 checksum

**Used by:**
- `erlang/update.ps1` - Get latest version and ERTS version
- `_elixir-gen/generate-packages.ps1` - Determine latest OTP major
- `Sync-ErlangVersions.ps1` - Get all OTP versions
- `Test-LatestOtpVersion` - Check if OTP major changed

### Test-LatestOtpVersion

Compares tracked OTP version (`.latest_otp_version`) against latest from `otp_versions.table`. Throws error if mismatch, indicating Elixir packages need regeneration.

**Used by:** `Test-LatestOtpVersion.ps1` script, called by workflow

### ConvertTo-ChocolateyVersion

Normalizes version strings to Chocolatey's format:
- 2 parts (28.3) -> 28.3.0
- 3 parts (27.3.4) -> 27.3.4
- 4 parts (25.1.2.1) -> 25.1.2.1

**Critical for:** Erlang package - ensures AU's Chocolatey existence check works correctly

**Used by:**
- `erlang/update.ps1` - Normalize version before returning to AU
- `Sync-ErlangVersions.ps1` - Compare versions with Chocolatey

## Key Scripts

### Update-Packages.ps1

AU batch updater that processes all packages. Calls `Update-AUPackages` with configured options.

**Key configuration:**
- `Push = $Env:au_Push -eq 'true'` - Enable pushing
- `Threads = 10` - Parallel package processing
- Git plugin enabled with `Branch = 'main'`
- Gist plugin for update reports
- Report and History plugins for markdown output

**Environment variables required:**
- `au_Push` - 'true' or 'false' (string!)
- `api_key` - Chocolatey API key
- `github_api_key` - GitHub token (gist + repo scopes)
- `github_user_repo` - Format: 'owner/repo'
- `gist_id` - Gist ID for update reports

### Test-Packages.ps1

Force tests all packages with push disabled. Used for testing package update scripts work correctly.

**Usage:**
```powershell
.\Test-Packages.ps1                    # Test all packages
.\Test-Packages.ps1 'erlang','rebar3'  # Test specific packages
.\Test-Packages.ps1 'random 3'         # Random group testing
```

### Invoke-Validation.ps1

Runs PSScriptAnalyzer on all PowerShell files with configured rules.

**Checks:**
- Code quality (aliases, Write-Host, etc.)
- Formatting (indentation, braces, whitespace)
- PowerShell 5.1/7 compatibility
- Excludes `_modules/` directory

**Usage:**
```powershell
.\Invoke-Validation.ps1
```

### Test-LatestOtpVersion.ps1

Standalone script that checks if OTP major version has changed. Called by workflow to detect when Elixir packages need regeneration.

**Workflow integration:**
```yaml
- name: check-otp-version
  shell: pwsh
  run: ${{ github.workspace }}\Test-LatestOtpVersion.ps1
```

**When it fails:** OTP 29 released, Elixir packages need regeneration for OTP 26/27/28/29.

### Sync-ErlangVersions.ps1

Batch publisher for missing Erlang versions. Queries Chocolatey for published versions, compares with `otp_versions.table`, and pushes missing versions in batches.

**Key features:**
- Respects 10-version moderation limit
- State tracking in `sync-state.json`
- Version normalization for accurate comparison
- Supports dry-run mode
- Cleans up stale AU functions/variables

**Usage:**
```powershell
# Dry run
.\Sync-ErlangVersions.ps1 -MinMajorVersion 25 -DryRun

# Push up to 10 versions
.\Sync-ErlangVersions.ps1 -MinMajorVersion 25 -ApiKey 'YOUR_KEY'

# Push specific version
.\Sync-ErlangVersions.ps1 -SpecificVersion '27.3.4' -ApiKey 'YOUR_KEY'
```

### Push-ElixirPackages.ps1

Force pushes all 4 Elixir packages. Sets `au_ForcePush='false'` workaround for PowerShell 7 empty string bug.

**Usage:**
```powershell
.\Push-ElixirPackages.ps1 -ApiKey 'YOUR_KEY'
```

## AU Framework Deep Dive

### How AU Works

Each package has an `update.ps1` script that defines functions AU calls:

1. **`au_GetLatest`** - Returns hashtable with version and URLs
2. **`au_SearchReplace`** - Defines regex replacements for files
3. **`au_BeforeUpdate`** (optional) - Runs before file updates
4. **`au_AfterUpdate`** (optional) - Runs after file updates

**AU's process:**
1. Reads nuspec to get current version
2. Calls `au_GetLatest` to get remote version
3. Compares versions
4. If remote > current AND version doesn't exist on Chocolatey:
   - Calls `au_BeforeUpdate` if defined
   - Updates files via `au_SearchReplace`
   - Calls `au_AfterUpdate` if defined
   - Packs the package
   - Pushes if `$Options.Push = $true`

**Important:** AU checks if version exists on Chocolatey before updating. This prevents unnecessary rebuilds.

### Version Comparison

AU uses `[AUVersion]` type for comparison:
```powershell
if ([AUVersion] $Latest.Version -gt [AUVersion] $Latest.NuspecVersion)
```

**Critical:** Version must be normalized to Chocolatey format BEFORE AU checks Chocolatey. Otherwise, AU looks for wrong version (28.3 instead of 28.3.0) and thinks it doesn't exist.

### Chocolatey Existence Check

When AU detects remote version > nuspec version:
1. Constructs URL: `https://chocolatey.org/packages/{package}/{version}`
2. Tries to request the URL
3. If succeeds (200): Version exists, skip update
4. If fails (404): Version doesn't exist, proceed with update

**This is why version normalization is critical for Erlang.**

### AU Plugins

Configured in `Update-Packages.ps1`:

**Report** - Generates markdown update report
**History** - Tracks update history
**Gist** - Publishes reports to GitHub gist
**Git** - Commits updated files back to repository
**GitReleases** - Creates GitHub releases (not used)
**RunInfo** - Saves run information (fixed for PowerShell 7)

### Global Functions Persistence

AU functions are defined as `global:` which means they persist in PowerShell session:
- `global:au_GetLatest`
- `global:au_SearchReplace`
- `global:au_BeforeUpdate`
- `global:au_AfterUpdate`

**Problem:** Running multiple package updates in same session causes function conflicts.

**Solution:** `Sync-ErlangVersions.ps1` cleans up these functions at start.

## Critical Issues and Fixes

### PowerShell 7 Empty String Bug (FIXED)

**Problem:** PowerShell 7.3.0+ changed how empty strings are passed to external commands. In PS 5.1, empty strings were filtered. In PS 7+, they're passed as `""`.

AU's `Push-Package` function:
```powershell
$force_push = if ($Env:au_ForcePush) { '--force' } else { '' }
choco push $package $force_push
```

In PS 7, the empty string becomes `""` which choco interprets as filename, causing "file not found" errors.

**Fix:** Changed `''` to `$null` in `_modules/au/src/Public/Push-Package.ps1`

**Status:** Fixed in our AU submodule fork, PR submitted to upstream (#85)

### Version Normalization (FIXED)

**Problem:** Erlang package repeatedly tried to push version 28.3.0 even though it already exists. GitHub releases use `28.3`, Chocolatey normalizes to `28.3.0`. AU's existence check looked for `28.3` and failed.

**Fix:** Added `ConvertTo-ChocolateyVersion` function to normalize versions. Erlang's `au_GetLatest` now returns `28.3.0` instead of `28.3`.

**Critical detail:** Must normalize AFTER using original version for:
- GitHub release tag lookup (`OTP-28.3`)
- otp_versions.table lookup (`OTP-28.3`)
- Asset filename construction (`otp_win64_28.3.exe`)

Only normalize for the return value to AU.

### Git Plugin SSH Support (FIXED)

**Problem:** Git plugin only handled HTTPS URLs, failed with "Cannot index into a null array" for SSH URLs.

**Fix:** Added SSH URL parsing in `_modules/au/src/Plugins/Git.ps1`:
```powershell
if ($origin -match '(?<=:/+)[^/]+') {
    # HTTPS: https://github.com/user/repo
    $machine = $Matches[0]
} elseif ($origin -match '(?<=@)[^:]+') {
    # SSH: git@github.com:user/repo
    $machine = $Matches[0]
}
```

### RunInfo Plugin PowerShell 7 (FIXED)

**Problem:** RunInfo plugin used `BinaryFormatter` which was removed in .NET 5+/PowerShell 7.

**Fix:** Replaced with `PSSerializer` in `_modules/au/src/Plugins/RunInfo.ps1`:
```powershell
$serialized = [System.Management.Automation.PSSerializer]::Serialize($DeepCopyObject)
[System.Management.Automation.PSSerializer]::Deserialize($serialized)
```

### GitHub Release Digest Field

**Discovery:** GitHub now provides SHA256 checksums in release asset `digest` field (format: "sha256:hash").

**Implementation:** Erlang package uses digest when available (newer releases), downloads and calculates for older releases without digest.

**Benefit:** No download needed for newer releases (~250MB saved per update).

## GitHub Actions Workflows

### update.yml

**Trigger:** Daily at 5:30 AM UTC, or manual
**Permissions:** `contents: read` (Git plugin uses github_api_key for push)

**Steps:**
1. Checkout with submodules
2. Check OTP version (fails if changed)
3. Run `Update-Packages.ps1`

**What happens on update:**
- AU detects new version
- Updates nuspec and install scripts
- Packs package
- Pushes to Chocolatey
- Git plugin commits updated files
- Gist plugin updates report

**Environment variables:**
- `au_Push: 'true'` - Enable pushing
- `GH_TOKEN` - For gh.exe (automatic)
- `github_api_key` - GitHub token (from API_KEY secret)
- `github_user_repo` - Repository identifier
- `api_key` - Chocolatey API key (from CHOCOLATEY_API_KEY secret)
- `gist_id` - Gist ID for reports

### validate.yml

**Trigger:** Push or PR to main branch
**Permissions:** `contents: read`

**Steps:**
1. Checkout
2. Install PSScriptAnalyzer
3. Run `Invoke-Validation.ps1`

**Checks:**
- Code quality
- Formatting
- PowerShell 5.1/7 compatibility
- No aliases, proper cmdlet usage

## Common Patterns

### Using gh.exe for GitHub API

All packages use `gh.exe` instead of `Invoke-WebRequest`:

```powershell
# Get latest release
$releaseJson = & gh.exe release view --repo owner/repo --json 'tagName,url,assets'
if ($LASTEXITCODE -ne 0) {
    throw "Failed to get release"
}
$release = $releaseJson | ConvertFrom-Json
```

**Benefits:**
- Automatic authentication via `GH_TOKEN`
- Structured JSON output
- More reliable than web scraping
- Handles rate limiting

### Version Parameter Pattern

Packages support version override for batch processing:

```powershell
param([string]$Version)

# In au_GetLatest:
$targetVersion = if ($Version) {
    $Version
} elseif (Get-Variable -Name au_Version -Scope Global -ErrorAction Ignore) {
    $global:au_Version
} else {
    'latest'
}
```

**Allows:**
- Direct: `.\update.ps1 -Version '27.3.4'`
- Via global: `$global:au_Version = '27.3.4'; .\update.ps1`
- Default: `.\update.ps1` (gets latest)

### Checksum Strategies

**Embedded files (rebar3, Elixir):**
- Use `Get-RemoteFiles` to download
- AU calculates checksums automatically
- Files embedded in nupkg
- Use `-ChecksumFor none` (checksums in VERIFICATION.txt)

**Downloaded files (Erlang):**
- Get checksums from GitHub digest API (newer releases)
- Download and calculate for older releases
- Files downloaded at install time, not embedded
- Use `-ChecksumFor none` (checksums provided in `$Latest`)

### Template vs Committed Files

**Elixir (templates):**
- Templates in `_elixir-gen/`
- Generated packages committed to git
- Regenerate manually when OTP version changes

**rebar3 (hybrid):**
- Some `.in` templates (nuspec, install, VERIFICATION.txt)
- Working files committed with current version
- `Copy-TemplateFile` copies templates before AU runs

**Erlang (no templates):**
- All files committed directly
- AU updates in place
- No template copying needed

## Testing

### Local Package Testing

```powershell
cd packagename

# Test update detection
.\update.ps1

# Force update (even if no new version)
$au_Force = $true
.\update.ps1

# Test specific version (Erlang only)
.\update.ps1 -Version '27.3.4'

# Verify package contents
7z l *.nupkg

# Test installation
choco install packagename --source "." --yes

# Verify functionality
packagename --version

# Test uninstallation
choco uninstall packagename --yes
```

### Validation

```powershell
# Run PSScriptAnalyzer on all files
.\Invoke-Validation.ps1

# Check OTP version tracking
.\Test-LatestOtpVersion.ps1

# Test all packages (force update, no push)
.\Test-Packages.ps1
```

### Testing Checklist

Before committing package changes:

1. ✅ `.\Invoke-Validation.ps1` passes
2. ✅ Package updates successfully
3. ✅ Package installs locally
4. ✅ Software works correctly
5. ✅ Package uninstalls cleanly
6. ✅ Test in fresh PowerShell session

## Troubleshooting

### "Cannot index into a null array"

**Cause:** Stale AU functions from previous package in same PowerShell session.

**Solution:** Start fresh PowerShell session or run cleanup:
```powershell
Remove-Item Function:\au_* -ErrorAction Ignore
Remove-Variable -Name au_* -Scope Global -ErrorAction Ignore
```

### "Version already exists" (409 error)

**Cause:** Trying to push version that's already on Chocolatey.

**For Erlang:** Version normalization issue - check `ConvertTo-ChocolateyVersion` is being used.

**For others:** Nuspec version not updated after previous push - Git plugin should have committed it.

### "File not found" during choco push

**Cause:** PowerShell 7 empty string bug (if using old AU module).

**Solution:** Use our AU submodule fork which has the fix, or set `$PSNativeCommandArgumentPassing = 'Legacy'`.

### OTP Version Check Fails

**Cause:** OTP major version changed (e.g., OTP 29 released).

**Solution:**
1. Update `.latest_otp_version` to new version
2. Run `_elixir-gen\generate-packages.ps1`
3. Commit all generated Elixir packages
4. Push changes

### Workflow Fails to Commit

**Cause:** Git plugin not configured or token lacks permissions.

**Check:**
- `github_api_key` secret has `repo` scope
- `github_user_repo` environment variable is set
- `Branch = 'main'` in Git plugin config

### Package Icons Broken in Gist

**Cause:** Icon URLs pointing to wrong location or using wrong format.

**Solution:** Icons in `icons/` directory, URLs use `raw.githubusercontent.com` with `refs/heads/main` path.

## Development Workflows

### Adding a New Package

1. Create package directory with standard structure
2. Create `update.ps1` with AU functions
3. Create nuspec with current version (not 0.0.0)
4. Create install/uninstall scripts
5. Test locally with `$au_Force = $true`
6. Run `.\Invoke-Validation.ps1`
7. Commit and push
8. Workflow handles updates automatically

### Updating Elixir Packages When OTP Changes

When OTP 29 is released:

1. Workflow fails with OTP version mismatch
2. Update `.latest_otp_version` to `29`
3. Run `_elixir-gen\generate-packages.ps1`
4. Review generated packages
5. Commit all changes (4 packages + tracking file)
6. Push to trigger workflow

### Batch Publishing Erlang Versions

To publish multiple Erlang versions:

```powershell
# First batch (10 versions)
.\Sync-ErlangVersions.ps1 -MinMajorVersion 25 -ApiKey 'YOUR_KEY'

# Wait for moderation approval (hours/days)

# Second batch
.\Sync-ErlangVersions.ps1 -MinMajorVersion 25 -ApiKey 'YOUR_KEY'

# Repeat until all versions published
```

State is tracked in `sync-state.json` (gitignored).

### Debugging AU Issues

**Enable verbose output:**
```powershell
$VerbosePreference = 'Continue'
$au_Force = $true
.\update.ps1
```

**Check what AU detected:**
```powershell
$au_Force = $true
$result = .\update.ps1
$result | Format-List *
```

**Inspect $Latest data:**
The update output shows all `$Latest` properties - verify they match expectations.

**Test without force:**
```powershell
.\update.ps1  # Should report "no updates" if version current
```

## Important Notes

### Line Endings

- All files use LF (Unix-style)
- `.gitattributes` enforces this
- Don't use formatters that convert to CRLF
- AU submodule may have CRLF - use `dos2unix` before editing

### PowerShell Session State

AU functions persist across script runs in same session. Always test in fresh session or clean up:

```powershell
Remove-Item Function:\au_* -ErrorAction Ignore
Remove-Variable -Name au_* -Scope Global -ErrorAction Ignore
Remove-Item Env:\au_* -ErrorAction Ignore
```

### Chocolatey Moderation

- Limit: 10 versions in moderation at once
- Pushing more returns 403 error
- Daily workflow allows time for approval
- Use `Sync-ErlangVersions.ps1` for batch publishing

### Version Strings

**Always strings, never booleans:**
- `au_Push: 'true'` not `au_Push: true`
- AU checks with string comparison: `$Env:au_Push -eq 'true'`

### Git Plugin Behavior

**Only commits when packages are pushed:**
- Checks `$Info.result.pushed` (not `updated`)
- Commits only modified files in package directories
- Uses `--update` flag (staged files only)
- Includes `[skip ci]` in commit message

**Requires:**
- `github_api_key` with `repo` scope
- `github_user_repo` environment variable
- `Branch` parameter matching your branch name

## Package-Specific Details

### Erlang Package

**Update script:** `erlang/update.ps1`

**Key functions:**
- `au_GetLatest` - Fetches release from GitHub, gets checksums, parses ERTS version, normalizes version
- `au_SearchReplace` - Updates URLs, checksums, ERTS version in install/uninstall scripts

**Version handling:**
1. Get release tag (e.g., `OTP-28.3`)
2. Extract original version (`28.3`)
3. Use original for GitHub operations and otp_versions.table lookup
4. Normalize to Chocolatey format (`28.3.0`) for return to AU
5. AU checks Chocolatey for `28.3.0` and finds it exists

**Checksum handling:**
- Newer releases: Extract from `digest` field (instant)
- Older releases: Download both installers in parallel, calculate, delete

**ERTS version:**
- Parsed from `otp_versions.table` (no installation needed)
- Required for install/uninstall scripts to find Erlang installation

### rebar3 Package

**Update script:** `rebar3/update.ps1`

**Key functions:**
- `au_GetLatest` - Gets latest release tag, constructs download URL
- `au_BeforeUpdate` - Downloads binary, renames from .escript to no extension
- `au_SearchReplace` - Updates version in install script and VERIFICATION.txt

**Template handling:**
- Still uses `.in` templates for nuspec, install, VERIFICATION.txt
- `Copy-TemplateFile` copies before AU runs
- Working files committed with current version

**Binary handling:**
- Downloads as `rebar3.escript`
- Renames to `rebar3` (no extension)
- Embeds in nupkg with wildcard: `<file src="tools/**" target="tools" />`

### Elixir Packages

**Generator:** `_elixir-gen/generate-packages.ps1`

**Process:**
1. Parse `otp_versions.table` to get latest OTP major version
2. Calculate supported versions (latest + previous 2)
3. Generate 4 packages from templates
4. Copy static files (install, uninstall, LICENSE, VERIFICATION)
5. All packages committed to git

**Update scripts:** Each package has own `update.ps1` that:
- Gets latest Elixir release from GitHub
- Downloads OTP-specific zip file
- Embeds in nupkg
- Updates via `au_SearchReplace`

**OTP version tracking:**
- `.latest_otp_version` contains current major version
- Workflow checks this matches otp_versions.table
- Fails if mismatch, prompting regeneration

## AU Module Submodule

### Our Fork

**Location:** `_modules/au`
**Source:** https://github.com/chocolatey-beam/cc-chocolatey-au
**Branch:** `fix/powershell-7-compatibility`

**Our fixes:**
1. PowerShell 7 empty string bug in `Push-Package.ps1`
2. SSH URL support in `Git.ps1` plugin
3. PowerShell 7 compatibility in `RunInfo.ps1` plugin

**Status:** PR #85 submitted to upstream, using our fork until merged.

### Why Submodule

- Need fixes immediately, can't wait for upstream merge
- Upstream moves slowly (PRs sit for months)
- Can switch back to `Install-Module Chocolatey-AU` after PR merges

### Updating Submodule

```powershell
cd _modules/au
git pull origin fix/powershell-7-compatibility
cd ../..
git add _modules/au
git commit -m "Update AU submodule"
```

## Command Reference

### Package Updates

```powershell
# Single package
cd packagename
$au_Force = $true
.\update.ps1

# All packages (no push)
$env:au_Push = 'false'
$au_WhatIf = $false
.\Update-Packages.ps1

# Force specific packages
.\Update-Packages.ps1 -ForcedPackages 'erlang rebar3'

# Push Elixir packages
.\Push-ElixirPackages.ps1 -ApiKey 'YOUR_KEY'
```

### Erlang Batch Publishing

```powershell
# Dry run
.\Sync-ErlangVersions.ps1 -MinMajorVersion 25 -DryRun

# Push 10 versions
.\Sync-ErlangVersions.ps1 -MinMajorVersion 25 -MaxPushes 10 -ApiKey 'YOUR_KEY'

# Specific version
.\Sync-ErlangVersions.ps1 -SpecificVersion '27.3.4' -ApiKey 'YOUR_KEY'
```

### Elixir Regeneration

```powershell
# When OTP 29 is released
cd _elixir-gen
.\generate-packages.ps1

# Update tracking file
"29" | Set-Content ..\.latest_otp_version

# Commit all changes
git add ../elixir* ../.latest_otp_version
git commit -m "Regenerate Elixir packages for OTP 29"
```

### Validation

```powershell
# All files
.\Invoke-Validation.ps1

# OTP version
.\Test-LatestOtpVersion.ps1

# Force test packages
.\Test-Packages.ps1
```

## Best Practices

### Simplicity Over Complexity

**Always prefer the simplest solution that solves the problem.**

Example: OTP version tracking
- ❌ Complex: Parse nuspec XML, regex version dependencies, inline workflow logic
- ✅ Simple: Single tracking file (`.latest_otp_version`), function in Shared.ps1, standalone script

**Key principles:**
- Single source of truth
- Testable locally
- Reusable functions
- Clear separation of concerns

### Version Normalization

**Critical for Erlang:** Always normalize versions to Chocolatey format before returning to AU.

**Why:** AU's Chocolatey existence check constructs URL with the version. If version doesn't match Chocolatey's normalization, check fails.

**Pattern:**
```powershell
$originalVersion = $release.tagName -replace '^OTP-', ''
# Use originalVersion for GitHub operations
$normalizedVersion = ConvertTo-ChocolateyVersion $originalVersion
# Return normalizedVersion to AU
```

### Checksum Validation

**For embedded files:** Use `Get-RemoteFiles` and let AU calculate checksums.

**For downloaded files:** Provide checksums in `$Latest` hashtable:
- Get from GitHub digest API when available
- Download and calculate for older releases
- Use `-ChecksumFor none` (checksums already provided)

### Testing in Fresh Sessions

AU functions are global and persist. Always test in fresh PowerShell session or clean up between tests.

**Cleanup pattern:**
```powershell
Remove-Item Function:\au_* -ErrorAction Ignore
Remove-Variable -Name au_* -Scope Global -ErrorAction Ignore
Remove-Item Env:\au_* -ErrorAction Ignore
```

### Icon Management

**Centralize icons:** All icons in `icons/` directory with consistent naming.

**URL format:** Use `raw.githubusercontent.com` with `refs/heads/main`:
```
https://raw.githubusercontent.com/chocolatey-beam/au-packages/refs/heads/main/icons/package.png
```

**Not:**
```
https://github.com/chocolatey-beam/au-packages/raw/main/icons/package.png
```

## Links and References

### This Repository

- **Repository:** https://github.com/chocolatey-beam/au-packages
- **Gist (updates):** https://gist.github.com/lukebakken/7c671e5b6c0431b43e29fe2446e212c4
- **AU Fork:** https://github.com/chocolatey-beam/cc-chocolatey-au

### Upstream

- **Chocolatey-AU:** https://github.com/chocolatey-community/chocolatey-au
- **AU Wiki:** https://github.com/chocolatey-community/chocolatey-au/wiki
- **Template:** https://github.com/chocolatey-beam/au-packages-template

### Our Contributions

- **AU PR #85:** PowerShell 7 empty string fix
- **Discussion #86:** Template modernization proposal
- **PowerShell 7 Analysis:** https://gist.github.com/lukebakken/e7f9ba1fe1c71a46222ddac4b26f9d06
- **Migration Guide:** https://gist.github.com/lukebakken/935997613707af0853fab391fbd2d41d

### Chocolatey

- **Package Guidelines:** https://docs.chocolatey.org/en-us/create/create-packages
- **Moderation:** https://docs.chocolatey.org/en-us/community-repository/moderation/
- **Our Packages:**
  - https://community.chocolatey.org/packages/erlang
  - https://community.chocolatey.org/packages/elixir
  - https://community.chocolatey.org/packages/rebar3

### External

- **Erlang/OTP:** https://github.com/erlang/otp
- **Elixir:** https://github.com/elixir-lang/elixir
- **rebar3:** https://github.com/erlang/rebar3
- **gh CLI:** https://cli.github.com/manual/

## Recent Changes (January 2026)

### Version Normalization Fix

Fixed Erlang package repeatedly attempting to push 28.3.0. Added `ConvertTo-ChocolateyVersion` function to normalize versions (28.3 -> 28.3.0) so AU's Chocolatey check works correctly.

### AU Module Fixes

1. **Git plugin:** Added SSH URL support
2. **RunInfo plugin:** Replaced BinaryFormatter with PSSerializer for PowerShell 7

### Template Removal

Removed template pattern for Erlang and rebar3. Nuspec files now committed with current versions. AU updates them in place. Git plugin commits changes back to repository.

### OTP Version Tracking

Added `.latest_otp_version` file and `Test-LatestOtpVersion` function/script. Workflow checks OTP version and fails if changed, prompting Elixir package regeneration.

### Icon Centralization

Moved all package icons to `icons/` directory with consistent naming. Updated URLs to use `raw.githubusercontent.com` format.

---

**Last Updated:** January 5, 2026
**Maintainer:** Luke Bakken (lukerbakken@gmail.com)
