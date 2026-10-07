<#
.SYNOPSIS
    Configures secure agent permission rules and guardrails for Google Antigravity, Cursor, and VS Code.

.DESCRIPTION
    Set-AntigravitySafeRules establishes a balanced, enterprise-grade AI execution policy within
    IDE configuration files (settings.json):
    - Auto-Approved (Allow): Read-only inspection commands, parameter discovery, and Git log/diff operations
      (e.g., Get-Command, Get-Help, Get-Member, Get-Mg*, git status/log/diff).
    - Manual Approval (Ask): State-altering, mutating, or potentially destructive operations
      (e.g., Set-*, Update-*, Remove-*, New-*, Reset-*, Clear-*, Stop-*, Restart-*, git push/reset/checkout).
    - Hardening: Strips hazardous wildcard permissions such as 'agent.autoApproveExecution' and enforces
      'agent.terminal.alwaysProceed' = false.
    - Cloud & M365 Protection: Safely enables Microsoft Graph / Entra ID parameter discovery while ensuring
      destructive directory mutations require explicit human confirmation.

.PARAMETER Apply
    Executes the configuration changes. When omitted, the script safely renders comprehensive help
    and usage guidelines without making any modifications.

.PARAMETER Target
    Specifies the target editor environment.
    Accepted values: 'Auto', 'Antigravity', 'Cursor', 'AntigravityServer', 'VSCode', 'All'.
    Default: 'Auto'.

.PARAMETER SettingsPath
    Direct explicit file path to a settings.json file, bypassing automatic profile discovery.

.PARAMETER AdditionalAllowRules
    Array of additional command patterns to add to 'agent.permissions.allowRules'.

.PARAMETER AdditionalAskRules
    Array of additional command patterns to add to 'agent.permissions.askRules'.

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
    .\Set-AntigravitySafeRules.ps1 -Apply
    Detects the active Antigravity or Cursor settings.json file and applies balanced safe rules.

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -Apply -Target Antigravity
    Applies the security policy specifically to Google Antigravity User configuration.

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -Apply -Target All
    Scans for all existing installations (Antigravity, Cursor, VSCode) and hardens each one.

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -Apply -WhatIf
    Simulates applying the safe rules using PowerShell WhatIf mechanism without modifying the file.

.EXAMPLE
    .\Set-AntigravitySafeRules.ps1 -Apply -AdditionalAllowRules "npm test*", "cargo check*"
    Applies the default safe rules along with custom project-specific allow patterns.

.NOTES
    Author  : Roman Pindela
    Email   : roman.pindela@gmail.com
    GitHub  : https://github.com/romanpindela
    Version : 1.2.0
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
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
    Write-Host "     ANTIGRAVITY & CURSOR SAFE PERMISSIONS CONFIGURATION ENGINE     " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "Version : 1.2.0" -ForegroundColor Yellow
    Write-Host "Author  : Roman Pindela (roman.pindela@gmail.com)" -ForegroundColor Yellow
    Write-Host "GitHub  : https://github.com/romanpindela" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------------" -ForegroundColor DarkGray

    if ($ExecutionReason -eq 'EmptyRun') {
        Write-Host "[!] NOTICE: Script executed without parameters. Guard rails active." -ForegroundColor Yellow
        Write-Host "    No modifications were made. Review the usage guide below.`n" -ForegroundColor Yellow
    }
    elseif ($ExecutionReason -eq 'MissingApply') {
        Write-Host "[!] NOTICE: Specify [-Apply] to execute configuration changes." -ForegroundColor Yellow
        Write-Host "    Use [-WhatIf -Apply] to preview changes safely without writing.`n" -ForegroundColor Yellow
    }

    Write-Host "DESCRIPTION:" -ForegroundColor White
    Write-Host "  Establishes a balanced, enterprise-grade AI execution policy inside IDE"
    Write-Host "  settings (settings.json). Auto-approves safe read-only operations while"
    Write-Host "  enforcing manual approval for state-altering, file, and cloud mutations."
    Write-Host ""
    Write-Host "MICROSOFT 365 & ENTRA ID PROTECTION:" -ForegroundColor White
    Write-Host "  Allows read-only discovery (Get-Command, Get-Help, Get-Mg*) for autonomous"
    Write-Host "  exploration, while intercepting destructive cmdlets (Update-Mg*, Remove-Mg*,"
    Write-Host "  New-Mg*, Reset-*, Set-*) to protect cloud tenants from unintended changes."
    Write-Host ""
    Write-Host "FIRST-TIME EXECUTION / UNBLOCK INSTRUCTION:" -ForegroundColor White
    Write-Host "  If downloaded from GitHub, unblock the script before execution:"
    Write-Host "  Unblock-File -Path .\Set-AntigravitySafeRules.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "AVAILABLE PARAMETERS:" -ForegroundColor White
    Write-Host "  -Apply                 : Executes the configuration changes."
    Write-Host "  -Target <string>       : Target IDE: 'Auto' (default), 'Antigravity', 'Cursor',"
    Write-Host "                           'AntigravityServer', 'VSCode', 'All'."
    Write-Host "  -SettingsPath <path>   : Explicit path to a custom settings.json file."
    Write-Host "  -AdditionalAllowRules  : Extra patterns to add to allowRules."
    Write-Host "  -AdditionalAskRules    : Extra patterns to add to askRules."
    Write-Host "  -Force                 : Overwrites rules instead of merging."
    Write-Host "  -NoBackup              : Disables automated timestamped .bak backups."
    Write-Host "  -Help, -h              : Displays this documentation screen."
    Write-Host "  -WhatIf                : Simulates the execution without altering files."
    Write-Host ""
    Write-Host "PRACTICAL USAGE EXAMPLES:" -ForegroundColor White
    Write-Host "  1. Show help documentation (default empty run):"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Help" -ForegroundColor Gray
    Write-Host "  2. Apply safe policy to detected IDE settings:"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Apply" -ForegroundColor Gray
    Write-Host "  3. Target Google Antigravity specifically:"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Apply -Target Antigravity" -ForegroundColor Gray
    Write-Host "  4. Target all installed IDE environments:"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Apply -Target All" -ForegroundColor Gray
    Write-Host "  5. Preview changes safely (dry run):"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Apply -WhatIf" -ForegroundColor Gray
    Write-Host "  6. Apply with custom allow rules:"
    Write-Host "     .\Set-AntigravitySafeRules.ps1 -Apply -AdditionalAllowRules 'npm test*', 'cargo check*'" -ForegroundColor Gray
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
        return @()
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
    return $clean.ToArray()
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

# Guard Rail 1: Empty run or explicit help request
if ($Help -or ($PSBoundParameters.Count -eq 0)) {
    Show-ScriptHelp -ExecutionReason $(if ($Help) { 'Help' } else { 'EmptyRun' })
    return
}

# Guard Rail 2: Prevent unconfirmed mutation without -Apply
if (-not $Apply) {
    Show-ScriptHelp -ExecutionReason 'MissingApply'
    return
}

Write-Host "`n[*] Initiating Antigravity & Cursor Security Hardening Engine..." -ForegroundColor Cyan

# Define baseline enterprise policies
$baselineAllowRules = @(
    "*Get-Command*",
    "*Get-Help*",
    "*Get-Member*",
    "*Parameters.Keys*",
    "*ParameterSets*",
    "powershell *-Command *Get-*",
    "pwsh *-Command *Get-*",
    "*Get-Mg*",
    "git status*",
    "git log*",
    "git diff*"
)

$baselineAskRules = @(
    "*Update-*",
    "*Set-*",
    "*Remove-*",
    "*New-*",
    "*Reset-*",
    "*Clear-*",
    "*Restart-*",
    "*Stop-*",
    "git push*",
    "git reset*",
    "git checkout*"
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

    # Assemble and deduplicate Allow rules
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

        $finalAllow = @($existingAllow + $baselineAllowRules + $extraAllow) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() } |
            Select-Object -Unique

        $finalAsk = @($existingAsk + $baselineAskRules + $extraAsk) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() } |
            Select-Object -Unique
    }

    # Inject policy settings
    $config["agent.permissions.allowRules"] = [string[]]$finalAllow
    $config["agent.permissions.askRules"] = [string[]]$finalAsk

    # Security Hardening: Neutralize dangerous wildcard permissions
    if ($config.Contains("agent.autoApproveExecution")) {
        $config.Remove("agent.autoApproveExecution")
        Write-Host "  [-] Removed hazardous key: 'agent.autoApproveExecution'" -ForegroundColor Yellow
    }

    if ($config.Contains("agent.terminal.alwaysProceed")) {
        $config["agent.terminal.alwaysProceed"] = $false
        Write-Host "  [*] Hardened 'agent.terminal.alwaysProceed' = false" -ForegroundColor Yellow
    }

    # Serialize JSON with clean indentation
    $updatedJson = $config | ConvertTo-Json -Depth 20

    if ($PSCmdlet.ShouldProcess($filePath, "Save updated agent permission policies")) {
        $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($filePath, $updatedJson, $utf8WithoutBom)
        Write-Host "[OK] Successfully applied security policy to: $filePath" -ForegroundColor Green
        $processedCount++
    }
}

if ($processedCount -gt 0) {
    Write-Host "`n=====================================================================" -ForegroundColor Green
    Write-Host "[OK] Balanced AI security rules applied successfully!" -ForegroundColor Green
    Write-Host " -> Agent will inspect parameters (Get-Command, Get-Help, Get-Mg*) autonomously." -ForegroundColor Gray
    Write-Host " -> Agent will prompt for confirmation on state mutations (Set-*, Update-*, Remove-*)." -ForegroundColor Gray
    Write-Host " -> Global auto-approve wildcards neutralized." -ForegroundColor Gray
    Write-Host "`n[i] Action Required: Press Ctrl+Shift+P in Antigravity / Cursor and run:" -ForegroundColor Yellow
    Write-Host "    'Developer: Reload Window'" -ForegroundColor Yellow
    Write-Host "=====================================================================" -ForegroundColor Green
}