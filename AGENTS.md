# AGENTS.md - AI Assistant Context

This file provides context for AI assistants working on this repository.

## Repository Purpose

This repository manages Chocolatey packages using the AU (Automatic Updater) framework. AU automates the detection of new software versions and updates Chocolatey packages accordingly.

## Current Packages

### rebar3
- **What**: Erlang build tool (escript binary, ~842KB)
- **Source**: https://github.com/erlang/rebar3
- **Package**: Embeds the rebar3 binary directly in the nupkg
- **Special handling**: Binary has no file extension, requires `tools/**` wildcard in nuspec

## AU Framework Basics

### How AU Works

Each package has an `update.ps1` script with three key functions:

1. **`au_GetLatest`** - Queries upstream source for latest version
   ```powershell
   function global:au_GetLatest {
       return @{
           Version = $version
           URL64 = $downloadUrl
       }
   }
   ```

2. **`au_SearchReplace`** - Defines regex replacements for package files
   ```powershell
   function global:au_SearchReplace {
       @{
           ".\tools\install.ps1" = @{
               "(version\s*=\s*)('.*')" = "`$1'$($Latest.Version)'"
           }
       }
   }
   ```

3. **`au_BeforeUpdate`** - Downloads files before updating (optional)
   ```powershell
   function global:au_BeforeUpdate {
       Get-RemoteFiles -Purge -NoSuffix
   }
   ```

### Running Updates

**Single package:**
```powershell
cd packagename
$au_Force = $true  # Force update even if version unchanged
.\update.ps1
```

**All packages:**
```powershell
$au_WhatIf = $false
$au_Push = $false  # Don't push to chocolatey.org
.\update_all.ps1
```

## Key Patterns

### Using gh.exe Instead of Web Scraping

This repository uses `gh.exe` for GitHub API access instead of `Invoke-WebRequest`:

```powershell
# Get latest release tag
$tag = & gh.exe release view --repo owner/repo --json tagName --jq .tagName

# Check exit code
if ($LASTEXITCODE -ne 0) {
    throw "Failed to get release"
}
```

**Why:** 
- Handles authentication automatically via `GH_TOKEN`
- Cleaner than parsing HTML
- More reliable than web scraping

### Embedded Files

For small binaries (< 1MB), embed in the package:

1. **Download in `au_BeforeUpdate`:**
   ```powershell
   Get-RemoteFiles -Purge -NoSuffix
   ```

2. **Include in nuspec:**
   ```xml
   <file src="tools/**" target="tools" />
   ```

3. **Add VERIFICATION.txt** with checksum for moderators

### Extensionless Files

**Problem:** Chocolatey has a bug packing extensionless files when listed individually.

**Solution:** Use wildcard pattern in nuspec:
```xml
<file src="tools/**" target="tools" />
```

Instead of:
```xml
<file src="tools/rebar3" target="tools" />
```

### Chocolatey Fix Notation

When forcing an update of an existing version, AU appends the date:
- Input: `3.25.1`
- Output: `3.25.1.20251231`

This is **expected behavior** for testing. Real new versions won't have the date suffix.

## GitHub Actions

### Environment Variables

The update workflow requires:
- `au_Push: 'true'` (string, not boolean!)
- `GH_TOKEN: ${{ github.token }}` (for gh.exe)
- `github_api_key: ${{ github.token }}` (for AU Git/Gist features)
- `api_key: ${{ secrets.CHOCOLATEY_API_KEY }}` (for pushing)

### Permissions

- Validation workflow: `contents: read`
- Update workflow: `contents: write` (needs to commit changes)

## Common Issues

### "You cannot call a method on a null-valued expression"

**Cause:** Global `au_AfterUpdate` function from another package persists in PowerShell session.

**Solution:** Restart PowerShell or run `Remove-Item Function:\au_AfterUpdate`

### File Named "tools" in nupkg

**Cause:** Chocolatey bug with extensionless files in explicit file lists.

**Solution:** Use `<file src="tools/**" target="tools" />` wildcard.

### Download Creates Wrong Directory

**Cause:** `gh.exe release download --dir` flag behavior.

**Solution:** Download to current directory, then move to tools/.

### $au_WhatIf Not Set Error

**Cause:** Running `update_all.ps1` without setting required variables.

**Solution:** Set `$au_WhatIf = $false` before running, or create `update_vars.ps1`.

## File Structure

```
au-packages/
├── .github/workflows/
│   ├── validate.yml       # PSScriptAnalyzer on every push/PR
│   └── update.yml         # Weekly AU updates
├── rebar3/
│   ├── update.ps1         # AU update script
│   ├── rebar3.nuspec      # Package metadata
│   ├── README.md          # Package description (used by AU)
│   └── tools/
│       ├── chocolateyInstall.ps1
│       ├── chocolateyUninstall.ps1
│       ├── rebar3         # Escript binary (no extension)
│       ├── rebar3.cmd     # Windows wrapper
│       ├── rebar3.ps1     # PowerShell wrapper
│       ├── VERIFICATION.txt
│       └── .skipAutoUninstall
├── PSScriptAnalyzerSettings.psd1
├── Test-All.ps1           # Validation script
├── test_all.ps1           # AU test runner
├── update_all.ps1         # AU batch updater
└── README.md
```

## Testing Checklist

Before committing changes to a package:

1. ✅ Run `.\Test-All.ps1` - All scripts pass validation
2. ✅ Test update: `$au_Force = $true; .\update.ps1`
3. ✅ Verify nupkg contents: `7z l package.nupkg`
4. ✅ Check file sizes and names are correct
5. ✅ Verify VERIFICATION.txt has correct checksum
6. ✅ Test installation locally:
   ```powershell
   choco install packagename --version X.Y.Z --source ".;https://chocolatey.org/api/v2/" --yes
   ```
   Note: Include chocolatey.org source to resolve dependencies
7. ✅ Verify package functionality (run the installed software)
8. ✅ Test uninstallation: `choco uninstall packagename --yes`
9. ✅ Test in fresh PowerShell session (avoid stale functions)

## Workflow

### Adding a New Package

1. Create package directory: `mkdir newpackage`
2. Create `newpackage.nuspec` with metadata
3. Create `tools/` with install/uninstall scripts
4. Create `update.ps1` with AU functions
5. Test locally with `$au_Force = $true`
6. Commit and push
7. Weekly workflow will handle updates automatically

### Debugging AU Issues

**Enable verbose output:**
```powershell
$VerbosePreference = 'Continue'
$au_Force = $true
.\update.ps1
```

**Check what AU sees:**
```powershell
$au_Force = $true
$result = .\update.ps1
$result | Format-List *
```

**Inspect $Latest data:**
The update output shows all `$Latest` properties - check these match expectations.

## Important Notes

### Line Endings

- All files use LF (Unix-style)
- `.gitattributes` enforces this
- `.editorconfig` specifies `end_of_line = lf`
- Don't run formatters that convert to CRLF

### PowerShell Session State

AU functions are defined as `global:` which means they persist across script runs in the same session. Always test in a fresh PowerShell session or explicitly remove functions between tests.

### Chocolatey Moderation

- Chocolatey limits **10 versions in moderation** at once
- Pushing more returns 403 error
- Wait for approval before pushing additional versions
- Weekly schedule allows time for validation

## Links

- [AU Framework](https://github.com/majkinetor/au)
- [AU Wiki](https://github.com/majkinetor/au/wiki)
- [Chocolatey Package Guidelines](https://docs.chocolatey.org/en-us/create/create-packages)
- [gh CLI Documentation](https://cli.github.com/manual/)
