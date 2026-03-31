@{
    # Include all default rules plus formatting
    IncludeDefaultRules = $true

    # Exclude rules that don't apply
    ExcludeRules = @(
        'PSUseSingularNouns'  # Get-OtpVersions returns multiple versions
    )

    # Formatting rules
    Rules = @{
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind = 'space'
        }

        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckPipeForRedundantWhitespace = $true
            CheckSeparator = $true
            CheckParameter = $false
        }

        PSAlignAssignmentStatement = @{
            Enable = $false
            CheckHashtable = $false
        }

        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $false
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace = @{
            Enable = $true
            NoEmptyLineBefore = $false
            IgnoreOneLineBlock = $true
            NewLineAfter = $true
        }

        PSUseCorrectCasing = @{
            Enable = $true
        }

        PSAvoidUsingCmdletAliases = @{
            Allowlist = @()
        }

        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('5.1', '7.0', '7.4')
        }

        PSUseCompatibleCommands = @{
            Enable = $true
            TargetProfiles = @(
                'win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework',
                'win-8_x64_10.0.14393.0_7.0.0_x64_3.1.2_core'
            )
        }

        PSUseCompatibleTypes = @{
            Enable = $true
            TargetProfiles = @(
                'win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework',
                'win-8_x64_10.0.14393.0_7.0.0_x64_3.1.2_core'
            )
        }
    }
}
