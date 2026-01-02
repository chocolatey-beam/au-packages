# Erlang Chocolatey Package

Automatic package for Erlang/OTP using Chocolatey-AU.

## Package Information

- **Package ID**: erlang
- **Maintainer**: Luke Bakken (@lukebakken)
- **Source**: https://github.com/erlang/otp
- **Icon**: https://raw.githubusercontent.com/chocolatey-beam/erlang-package/main/erlang-icon.png

## Update Process

This package uses Chocolatey-AU to automatically detect and update to the latest Erlang/OTP release.

The update script:
1. Fetches the latest release from GitHub
2. Downloads Windows installers (32-bit and 64-bit)
3. Calculates checksums
4. Tests installation to detect ERTS version
5. Updates nuspec and install scripts
6. Packs the package

## Testing

To test the package locally:

```powershell
$au_Force = $true
.\update.ps1
```

## Notes

- Package downloads installers from official Erlang/OTP GitHub releases
- ERTS version is detected during update by test-installing Erlang
- Supports both 32-bit and 64-bit Windows
- Creates shims for common Erlang tools (erl, erlc, escript, etc.)
