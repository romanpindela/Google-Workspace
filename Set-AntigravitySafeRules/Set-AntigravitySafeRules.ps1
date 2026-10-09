<#
.SYNOPSIS
    Configures AI agent permission rules and execution modes for Google Antigravity, Cursor, and VS Code.

.DESCRIPTION
    Set-AntigravitySafeRules manages AI agent execution policies inside IDE configuration files (settings.json).
    It provides two distinct operational modes:

    1. Safe Mode (-Mode Safe / -Safe):
       - Human Approval (Ask): State-altering, mutating, or potentially destructive operations
         (e.g., Set-*, Update-*, Remove-*, New-*, Reset-*, Clear-*, Stop-*, Restart-*, Out-File,
          Set-Content, git commit/push/reset, cloud tenant mutations).
       - Auto-Approved (Allow): Harmless read-only inspection, parameter discovery, and Git logs/diffs
         (e.g., Get-Command, Get-Help, Get-Member, Get-Mg*, git status/log/diff).
       - Guardrails: Enforces 'agent.terminal.alwaysProceed' = false, 'agent.permissions.mode' = 'request-review',
         'agent.artifactReviewPolicy' = 'asks-for-review', 'agent.fileAccess.policy' = 'ask', and neutralizes
         hazardous wildcard auto-approvals.

    2. Full Machine Mode (-Mode FullMachine / -FullMachine):
       - Full Permissions: Unrestricted machine access with zero confirmation prompts to the user.
       - Auto-Approved: All commands, terminal executions, file writes, and code modifications proceed autonomously.
       - Settings: 'agent.permissions.mode' = 'always-proceed', 'agent.terminal.alwaysProceed' = true,
         'agent.autoApproveExecution' = true, 'agent.artifactReviewPolicy' = 'always-proceed',
         'agent.fileAccess.policy' = 'allow', 'agent.permissions.allowRules' = ['*'], askRules cleared.

.PARAMETER Mode
    Specifies the operational security mode to apply:
    - 'Safe': Enforces permission checks for writes, modifications, and state mutations.
    - 'FullMachine': Grants full unrestricted machine permissions without user prompts.
    Default: 'Safe'.

.PARAMETER FullMachine
    Convenience switch to apply Full Machine mode directly (unrestricted permissions, zero prompts).

.PARAMETER Safe
    Convenience switch to apply Safe mode directly (requires human approval for write, modification, and state changes).

.PARAMETER Apply
    Executes the configuration changes. When running without parameters, the script safely renders
    comprehensive help and usage guidelines without making any modifications.

.PARAMETER Target
    Specifies the target editor environment.
    Accepted values: 'Auto', 'Antigravity', 'Cursor', 'AntigravityServer', 'VSCode', 'All'.
    Default: 'Auto'.

.PARAMETER SettingsPath
    Direct explicit file path to a settings.json file, bypassing automatic profile discovery.

.PARAMETER AdditionalAllowRules
    Array of additional command patterns to append to 'agent.permissions.allowRules'.

.PARAMETER AdditionalAskRules
    Array of additional command patterns to append to 'agent.permissions.askRules'.

.PARAMETER Force
    Overwrites the permission rule lists instead of merging with existing configured rules.

.PARAMETER NoBackup
    Suppresses the automated generation of timestamped .bak backup files prior to updating settings.

.PARAMETER Help
    Displays detailed manual, usage examples, author profile, and version information.

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -Help
    Displays comprehensive help, parameter reference, and practical usage examples.

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -Safe
    Applies balanced Safe mode requiring user confirmation for writes, modifications, and mutations.

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -FullMachine
    Applies Full Machine mode granting complete autonomy without user prompts.

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -Apply -Mode FullMachine -Target Antigravity
    Applies Full Machine mode specifically to Google Antigravity User settings.

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -Apply -Target All -Safe
    Applies Safe mode to all discovered installations (Antigravity, Cursor, VSCode).

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -FullMachine -WhatIf
    Simulates applying Full Machine mode using PowerShell WhatIf without altering files.

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -Safe -AdditionalAllowRules "npm test*", "cargo check*"
    Applies Safe mode rules along with custom project-specific allow patterns.

.NOTES
    Author  : Roman Pindela
    Email   : roman.pindela@gmail.com
    GitHub  : https://github.com/romanpindela
    Version : 1.3.0
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Operational security mode: 'Safe' or 'FullMachine'. Default: 'Safe'.")]
    [ValidateSet('Safe', 'FullMachine')]
    [string]$Mode = 'Safe',

    [Parameter(Mandatory = $false, HelpMessage = "Convenience switch to apply Full Machine mode (unrestricted permissions, zero prompts).")]
    [switch]$FullMachine,

    [Parameter(Mandatory = $false, HelpMessage = "Convenience switch to apply Safe mode (approval required for writes, modifications, and changes).")]
    [switch]$Safe,

    [Parameter(Mandatory = $false, HelpMessage = "Executes the policy update on targeted settings.json files.")]
    [switch]$Apply,

    [Parameter(Mandatory = $false, HelpMessage = "Target environment: Auto, Antigravity, Cursor, AntigravityServer, VSCode, All.")]
    [ValidateSet('Auto', 'Antigravity', 'Cursor', 'AntigravityServer', 'VSCode', 'All')]
    [string]$Target = 'Auto',

    [Parameter(Mandatory = $false, HelpMessage = "Direct path to a custom settings.json file.")]
    [string]$SettingsPath,

    [Parameter(Mandatory = $false, HelpMessage = "Custom command patterns to append to allowRules.")]
    [string[]]$AdditionalAllowRules,

    [Parameter(Mandatory = $false, HelpMessage = "Custom command patterns to append to askRules.")]
    [string[]]$AdditionalAskRules,

    [Parameter(Mandatory = $false, HelpMessage = "Overwrites rules instead of merging with existing custom rules.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Skips creating a safety backup file prior to modifying settings.json.")]
    [switch]$NoBackup,

    [Parameter(Mandatory = $false, HelpMessage = "Displays script help, author metadata, and practical usage scenarios.")]
    [Alias('h')]
    [switch]$Help
)

# =====================================================================
# Helper: Display Script Help and Guard Rails
# =====================================================================
function Show-ScriptHelp {
    param (
        [string]$ExecutionReason = 'Help'
    )

    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "     ANTIGRAVITY & CURSOR PERMISSIONS CONFIGURATION ENGINE          " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "Version : 1.3.0" -ForegroundColor Yellow
    Write-Host "Author  : Roman Pindela (roman.pindela@gmail.com)" -ForegroundColor Yellow
    Write-Host "GitHub  : https://github.com/romanpindela" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------------" -ForegroundColor DarkGray

    if ($ExecutionReason -eq 'EmptyRun') {
        Write-Host "[!] NOTICE: Script executed without parameters. Guard rails active." -ForegroundColor Yellow
        Write-Host "    No modifications were made. Review the usage guide below.`n" -ForegroundColor Yellow
    }
    elseif ($ExecutionReason -eq 'MissingApply') {
        Write-Host "[!] NOTICE: Specify [-Safe], [-FullMachine], or [-Apply] to execute changes." -ForegroundColor Yellow
        Write-Host "    Use [-WhatIf] to preview configuration changes safely without writing.`n" -ForegroundColor Yellow
    }

    Write-Host "DESCRIPTION:" -ForegroundColor White
    Write-Host "  Manages AI coding assistant permission policies in IDE settings.json."
    Write-Host "  Supports two distinct operational profiles tailored for security vs autonomy."
    Write-Host ""
    Write-Host "OPERATIONAL MODES:" -ForegroundColor White
    Write-Host "  1. Safe Mode (-Mode Safe / -Safe):" -ForegroundColor Cyan
    Write-Host "     - Auto-approves harmless read-only inspection (Get-Command, Get-Help, Get-Mg*, git status/log)."
    Write-Host "     - Enforces human confirmation before write, modify, delete, and state mutations"
    Write-Host "       (Set-*, Update-*, Remove-*, Out-File, Set-Content, git commit/push, Microsoft Graph updates)."
    Write-Host "     - Sets 'agent.permissions.mode' = 'request-review' and 'agent.terminal.alwaysProceed' = false."
    Write-Host "     - Configures 'agent.artifactReviewPolicy' = 'asks-for-review' and 'agent.fileAccess.policy' = 'ask'."
    Write-Host ""
    Write-Host "  2. Full Machine Mode (-Mode FullMachine / -FullMachine):" -ForegroundColor Magenta
    Write-Host "     - Grants full, unrestricted machine permissions with zero prompts to the user."
    Write-Host "     - Allows the AI agent to execute commands, write files, and alter project state autonomously."
    Write-Host "     - Sets allowRules to ['*'], clears askRules, and sets alwaysProceed = true / autoApprove = true."
    Write-Host "     - Configures 'agent.artifactReviewPolicy' = 'always-proceed' and 'agent.fileAccess.policy' = 'allow'."
    Write-Host ""
    Write-Host "MICROSOFT 365 & ENTRA ID PROTECTION (In Safe Mode):" -ForegroundColor White
    Write-Host "  Allows read-only discovery (Get-Command, Get-Help, Get-Mg*) for autonomous"
    Write-Host "  exploration, while intercepting destructive cmdlets (Update-Mg*, Remove-Mg*,"
    Write-Host "  New-Mg*, Reset-*, Set-*) to protect cloud tenants from unintended changes."
    Write-Host ""
    Write-Host "FIRST-TIME EXECUTION / UNBLOCK INSTRUCTION:" -ForegroundColor White
    Write-Host "  If downloaded from GitHub, unblock the script before execution:"
    Write-Host "  Unblock-File -Path .\Set-AntigravitySafeRules.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "AVAILABLE PARAMETERS:" -ForegroundColor White
    Write-Host "  -Mode <Safe|FullMachine>: Selects configuration mode (Default: 'Safe')."
    Write-Host "  -FullMachine            : Convenience switch to apply Full Machine mode directly."
    Write-Host "  -Safe                   : Convenience switch to apply Safe mode directly."
    Write-Host "  -Apply                  : Executes the configuration changes."
    Write-Host "  -Target <string>        : Target IDE: 'Auto' (default), 'Antigravity', 'Cursor',"
    Write-Host "                            'AntigravityServer', 'VSCode', 'All'."
    Write-Host "  -SettingsPath <path>    : Explicit path to a custom settings.json file."
    Write-Host "  -AdditionalAllowRules   : Extra patterns to add to allowRules."
    Write-Host "  -AdditionalAskRules     : Extra patterns to add to askRules."
    Write-Host "  -Force                  : Overwrites rules instead of merging."
    Write-Host "  -NoBackup               : Disables automated timestamped .bak backups."
    Write-Host "  -Help, -h               : Displays this documentation screen."
    Write-Host "  -WhatIf                 : Simulates the execution without altering files."
    Write-Host ""
    Write-Host "PRACTICAL USAGE EXAMPLES:" -ForegroundColor White
    Write-Host "  1. Show help documentation (default empty run):"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Help" -ForegroundColor Gray
    Write-Host "  2. Apply Safe Mode (prompts for write/modify/state mutations):"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Safe" -ForegroundColor Gray
    Write-Host "     # or: .\Set-AntigravitySafeRules.ps1 -Apply -Mode Safe" -ForegroundColor Gray
    Write-Host "  3. Apply Full Machine Mode (full permissions, zero confirmation prompts):"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -FullMachine" -ForegroundColor Gray
    Write-Host "     # or: .\Set-AntigravitySafeRules.ps1 -Apply -Mode FullMachine" -ForegroundColor Gray
    Write-Host "  4. Target Google Antigravity specifically in Full Machine mode:"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Target Antigravity -FullMachine" -ForegroundColor Gray
    Write-Host "  5. Target all installed IDE environments in Safe mode:"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Target All -Safe" -ForegroundColor Gray
    Write-Host "  6. Preview changes safely (dry run):"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -FullMachine -WhatIf" -ForegroundColor Gray
    Write-Host "  7. Apply Safe mode with custom allowed commands:"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Safe -AdditionalAllowRules 'npm test*', 'cargo check*'" -ForegroundColor Gray
    Write-Host "=====================================================================" -ForegroundColor Cyan
}

# =====================================================================
# Helper: Language-Independent Administrator Verification
# =====================================================================
function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        $adminSid = [Security.Principal.SecurityIdentifier]::new([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
        return $principal.IsInRole($adminSid)
    }
    catch {
        return $false
    }
}

# =====================================================================
# Helper: Target Settings Paths Resolver
# =====================================================================
function Get-TargetSettingsPaths {
    param (
        [string]$TargetProfile,
        [string]$ExplicitPath
    )

    $appData = [System.Environment]::GetFolderPath('ApplicationData')

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if ($ExplicitPath.IndexOfAny([System.IO.Path]::GetInvalidPathChars()) -ge 0) {
            throw "Invalid path characters detected in -SettingsPath: '$ExplicitPath'"
        }

        $resolvedPath = [System.IO.Path]::GetFullPath($ExplicitPath)
        return @($resolvedPath)
    }

    $candidateDict = [ordered]@{
        'Antigravity'       = (Join-Path $appData "Antigravity\User\settings.json")
        'Cursor'            = (Join-Path $appData "Cursor\User\settings.json")
        'AntigravityServer' = (Join-Path $appData "antigravity-server\data\Machine\settings.json")
        'VSCode'            = (Join-Path $appData "Code\User\settings.json")
    }

    switch ($TargetProfile) {
        'Antigravity'       { return @($candidateDict['Antigravity']) }
        'Cursor'            { return @($candidateDict['Cursor']) }
        'AntigravityServer' { return @($candidateDict['AntigravityServer']) }
        'VSCode'            { return @($candidateDict['VSCode']) }
        'All' {
            $existing = @($candidateDict.Values | Where-Object { Test-Path -LiteralPath $_ })
            if ($existing.Count -gt 0) {
                return $existing
            }
            return @($candidateDict['Antigravity'])
        }
        'Auto' {
            foreach ($path in $candidateDict.Values) {
                if (Test-Path -LiteralPath $path) {
                    return @($path)
                }
            }
            return @($candidateDict['Antigravity'])
        }
    }
}

# =====================================================================
# Helper: Rule Sanitization
# =====================================================================
function Sanitize-Rules {
    param (
        [string[]]$Rules
    )

    if ($null -eq $Rules -or $Rules.Count -eq 0) {
        return ,@()
    }

    $clean = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $Rules) {
        if (-not [string]::IsNullOrWhiteSpace($r)) {
            $trimmed = $r.Trim()
            if ($trimmed -match '[\r\n\0]') {
                throw "Input security rule contains illegal newline or control characters: '$trimmed'"
            }
            $clean.Add($trimmed)
        }
    }
    return ,$clean.ToArray()
}

# =====================================================================
# Helper: Convert JSON to Ordered Dictionary (PowerShell 5.1 & 7+ Safe)
# =====================================================================
function Convert-JsonToOrderedDictionary {
    param (
        [string]$JsonText
    )

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        return [ordered]@{}
    }

    # Strip JSON with comments (JSONC) safely
    $cleanedJson = $JsonText -replace '(?m)^\s*//.*$', '' `
                             -replace '/\*[\s\S]*?\*/', '' `
                             -replace '(?m)\s+//.*$', ''

    if ([string]::IsNullOrWhiteSpace($cleanedJson)) {
        return [ordered]@{}
    }

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return ($cleanedJson | ConvertFrom-Json -AsHashtable)
    }

    $parsed = $cleanedJson | ConvertFrom-Json

    function Convert-Node($node) {
        if ($null -eq $node) { return $null }
        if ($node -is [System.Management.Automation.PSCustomObject]) {
            $dict = [ordered]@{}
            foreach ($prop in $node.PSObject.Properties) {
                $dict[$prop.Name] = Convert-Node $prop.Value
            }
            return $dict
        }
        if ($node -is [System.Collections.IEnumerable] -and $node -isnot [string]) {
            $list = [System.Collections.ArrayList]::new()
            foreach ($item in $node) {
                [void]$list.Add((Convert-Node $item))
            }
            return $list.ToArray()
        }
        return $node
    }

    return (Convert-Node $parsed)
}

# =====================================================================
# Main Execution Controller & Guard Rails
# =====================================================================

# Validate mode arguments
if ($FullMachine -and $Safe) {
    Write-Error "Conflict: Both -FullMachine and -Safe switches were specified. Please select either Safe mode or Full Machine mode."
    return
}

$effectiveMode = $Mode
if ($FullMachine) {
    $effectiveMode = 'FullMachine'
}
elseif ($Safe) {
    $effectiveMode = 'Safe'
}

# Determine if execution was explicitly requested
$executeRequested = $Apply -or $FullMachine -or $Safe -or $PSBoundParameters.ContainsKey('Mode')

# Guard Rail 1: Empty run or explicit help request
if ($Help -or ($PSBoundParameters.Count -eq 0)) {
    Show-ScriptHelp -ExecutionReason $(if ($Help) { 'Help' } else { 'EmptyRun' })
    return
}

# Guard Rail 2: Prevent unconfirmed mutation without -Apply, -Safe, -FullMachine, or -Mode
if (-not $executeRequested) {
    Show-ScriptHelp -ExecutionReason 'MissingApply'
    return
}

Write-Host "`n[*] Initiating Antigravity & Cursor Permissions Engine..." -ForegroundColor Cyan
Write-Host "[*] Selected Operational Mode: $effectiveMode" -ForegroundColor $(if ($effectiveMode -eq 'FullMachine') { 'Magenta' } else { 'Cyan' })

# Define baseline enterprise policies for Safe Mode
$baselineAllowRules = @(
    "*Get-Command*",
    "*Get-Help*",
    "*Get-Member*",
    "*Parameters.Keys*",
    "*ParameterSets*",
    "powershell *-Command *Get-*",
    "pwsh *-Command *Get-*",
    "*Get-Mg*",
    "*Get-Az*",
    "git status*",
    "git log*",
    "git diff*",
    "git show*",
    "git branch",
    "git branch -a",
    "git branch -r"
)

$baselineAskRules = @(
    # State mutation cmdlets
    "*Update-*",
    "*Set-*",
    "*Remove-*",
    "*New-*",
    "*Reset-*",
    "*Clear-*",
    "*Restart-*",
    "*Stop-*",

    # File write, modify, and delete operations
    "*Out-File*",
    "*Set-Content*",
    "*Add-Content*",
    "*New-Item*",
    "*Remove-Item*",
    "*Move-Item*",
    "*Rename-Item*",
    "*Copy-Item*",
    "*rm *",
    "*rmdir*",
    "*del *",
    "*erase *",

    # Process and external side-effects
    "*Start-Process*",
    "*Stop-Process*",
    "*Invoke-RestMethod*",
    "*Invoke-WebRequest*",

    # Git operations modifying repository state
    "git push*",
    "git reset*",
    "git checkout*",
    "git commit*",
    "git merge*",
    "git rebase*",
    "git clean*",
    "git branch -D*",
    "git branch -d*",

    # Cloud & M365 tenant mutations
    "*Update-Mg*",
    "*Remove-Mg*",
    "*New-Mg*",
    "*Reset-Mg*",
    "*Set-Mg*",
    "*Set-Az*",
    "*New-Az*",
    "*Remove-Az*",
    "*Update-Az*"
)

# Sanitize custom rules
$extraAllow = Sanitize-Rules -Rules $AdditionalAllowRules
$extraAsk = Sanitize-Rules -Rules $AdditionalAskRules

try {
    $targetFiles = Get-TargetSettingsPaths -TargetProfile $Target -ExplicitPath $SettingsPath
}
catch {
    Write-Error "Path Resolution Failure: $_"
    return
}

$processedCount = 0

foreach ($filePath in $targetFiles) {
    Write-Host "`n---------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[*] Processing target: $filePath" -ForegroundColor Cyan

    $targetDir = [System.IO.Path]::GetDirectoryName($filePath)
    if (-not (Test-Path -LiteralPath $targetDir)) {
        if ($PSCmdlet.ShouldProcess($targetDir, "Create missing configuration directory")) {
            [void](New-Item -ItemType Directory -Path $targetDir -Force)
            Write-Host "[+] Created directory: $targetDir" -ForegroundColor Green
        }
    }

    # Backup existing configuration
    if (Test-Path -LiteralPath $filePath) {
        if (-not $NoBackup) {
            $backupPath = "$filePath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            if ($PSCmdlet.ShouldProcess($filePath, "Create safety backup at '$backupPath'")) {
                Copy-Item -LiteralPath $filePath -Destination $backupPath -Force
                Write-Host "[+] Created safety backup: $backupPath" -ForegroundColor Green
            }
        }

        # Safe read and parse
        try {
            $rawContent = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
            $config = Convert-JsonToOrderedDictionary -JsonText $rawContent
        }
        catch {
            Write-Error "Failed to parse JSON file '$filePath'. Configuration aborted to prevent data corruption. Details: $_"
            continue
        }
    }
    else {
        $config = [ordered]@{}
        Write-Host "[i] Configuration file does not exist yet. Initializing new settings structure." -ForegroundColor Gray
    }

    # Assemble rules based on operational mode
    if ($effectiveMode -eq 'FullMachine') {
        # Full Machine Mode: All commands allowed without prompts, askRules cleared
        $finalAllow = @("*")
        if ($extraAllow -and $extraAllow.Count -gt 0) {
            $finalAllow = @($finalAllow + $extraAllow) | Select-Object -Unique
        }
        $finalAsk = if ($extraAsk -and $extraAsk.Count -gt 0) { @($extraAsk) } else { @() }

        # Apply settings
        $config["agent.permissions.mode"] = "always-proceed"
        $config["agent.terminal.alwaysProceed"] = $true
        $config["agent.autoApproveExecution"] = $true
        $config["agent.artifactReviewPolicy"] = "always-proceed"
        $config["agent.fileAccess.policy"] = "allow"
        $config["antigravity.terminal.autoApprove"] = $true
        $config["antigravity.agent.autoApprove"] = $true
        $config["agent.runCommandsWithoutPrompt"] = $true
        $config["agent.permissions.allowRules"] = [string[]]$finalAllow
        $config["agent.permissions.askRules"] = @($finalAsk)
        if ($config.Contains("agent.permissions.denyRules")) {
            $config["agent.permissions.denyRules"] = @()
        }

        Write-Host "  [+] Configured Full Machine Mode:" -ForegroundColor Magenta
        Write-Host "      -> agent.permissions.mode       = 'always-proceed'" -ForegroundColor Gray
        Write-Host "      -> agent.terminal.alwaysProceed = true" -ForegroundColor Gray
        Write-Host "      -> agent.autoApproveExecution   = true" -ForegroundColor Gray
        Write-Host "      -> agent.artifactReviewPolicy   = 'always-proceed'" -ForegroundColor Gray
        Write-Host "      -> agent.fileAccess.policy      = 'allow'" -ForegroundColor Gray
        Write-Host "      -> agent.permissions.allowRules = ['*']" -ForegroundColor Gray
        Write-Host "      -> agent.permissions.askRules   = []" -ForegroundColor Gray
    }
    else {
        # Safe Mode: Guarded permissions, require approval for writes and mutations
        if ($Force) {
            $finalAllow = @($baselineAllowRules + $extraAllow) | Select-Object -Unique
            $finalAsk = @($baselineAskRules + $extraAsk) | Select-Object -Unique
        }
        else {
            $existingAllow = @()
            if ($config.Contains("agent.permissions.allowRules") -and ($config["agent.permissions.allowRules"] -is [System.Collections.IEnumerable])) {
                $existingAllow = @($config["agent.permissions.allowRules"])
            }

            $existingAsk = @()
            if ($config.Contains("agent.permissions.askRules") -and ($config["agent.permissions.askRules"] -is [System.Collections.IEnumerable])) {
                $existingAsk = @($config["agent.permissions.askRules"])
            }

            # Strip wildcard '*' that would defeat safe mode guardrails
            $cleanedExistingAllow = @($existingAllow | Where-Object { $_ -ne "*" -and $_ -ne "*.*" })

            $finalAllow = @($cleanedExistingAllow + $baselineAllowRules + $extraAllow) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { $_.Trim() } |
                Select-Object -Unique

            $finalAsk = @($existingAsk + $baselineAskRules + $extraAsk) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { $_.Trim() } |
                Select-Object -Unique
        }

        # Apply settings
        $config["agent.permissions.mode"] = "request-review"
        $config["agent.terminal.alwaysProceed"] = $false
        if ($config.Contains("agent.autoApproveExecution")) {
            $config.Remove("agent.autoApproveExecution")
            Write-Host "  [-] Neutralized hazardous key: 'agent.autoApproveExecution'" -ForegroundColor Yellow
        }
        $config["agent.artifactReviewPolicy"] = "asks-for-review"
        $config["agent.fileAccess.policy"] = "ask"
        if ($config.Contains("antigravity.terminal.autoApprove")) {
            $config["antigravity.terminal.autoApprove"] = $false
        }
        if ($config.Contains("antigravity.agent.autoApprove")) {
            $config["antigravity.agent.autoApprove"] = $false
        }
        if ($config.Contains("agent.runCommandsWithoutPrompt")) {
            $config["agent.runCommandsWithoutPrompt"] = $false
        }
        $config["agent.permissions.allowRules"] = [string[]]$finalAllow
        $config["agent.permissions.askRules"] = [string[]]$finalAsk

        Write-Host "  [+] Configured Safe Mode:" -ForegroundColor Cyan
        Write-Host "      -> agent.permissions.mode       = 'request-review'" -ForegroundColor Gray
        Write-Host "      -> agent.terminal.alwaysProceed = false" -ForegroundColor Gray
        Write-Host "      -> agent.artifactReviewPolicy   = 'asks-for-review'" -ForegroundColor Gray
        Write-Host "      -> agent.fileAccess.policy      = 'ask'" -ForegroundColor Gray
        Write-Host "      -> agent.permissions.allowRules = (inspection & read-only patterns)" -ForegroundColor Gray
        Write-Host "      -> agent.permissions.askRules   = (write, modify & mutation patterns)" -ForegroundColor Gray
    }

    # Serialize JSON with clean indentation
    $updatedJson = $config | ConvertTo-Json -Depth 20

    if ($PSCmdlet.ShouldProcess($filePath, "Save updated agent permission policies ($effectiveMode)")) {
        $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($filePath, $updatedJson, $utf8WithoutBom)
        Write-Host "[OK] Successfully applied $effectiveMode policy to: $filePath" -ForegroundColor Green
        $processedCount++
    }
}

if ($processedCount -gt 0) {
    Write-Host "`n=====================================================================" -ForegroundColor Green
    if ($effectiveMode -eq 'FullMachine') {
        Write-Host "[OK] Full Machine Mode applied successfully!" -ForegroundColor Green
        Write-Host " -> Full unrestricted permissions granted to the AI agent." -ForegroundColor Magenta
        Write-Host " -> Agent will execute commands, write, and modify files without prompting the user." -ForegroundColor Gray
        Write-Host " -> Policy set: mode='always-proceed', terminal.alwaysProceed=true, allowRules=['*']." -ForegroundColor Gray
    }
    else {
        Write-Host "[OK] Safe Mode permissions applied successfully!" -ForegroundColor Green
        Write-Host " -> Agent will inspect parameters (Get-Command, Get-Help, Get-Mg*) autonomously." -ForegroundColor Cyan
        Write-Host " -> Agent will prompt for confirmation on file writes, edits, and state mutations." -ForegroundColor Gray
        Write-Host " -> Policy set: mode='request-review', terminal.alwaysProceed=false, guarded askRules." -ForegroundColor Gray
    }
    Write-Host "`n[i] Action Required: Press Ctrl+Shift+P in Antigravity / Cursor / VS Code and run:" -ForegroundColor Yellow
    Write-Host "    'Developer: Reload Window'" -ForegroundColor Yellow
    Write-Host "=====================================================================" -ForegroundColor Green
}