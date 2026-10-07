# Antigravity & Cursor Safe Permissions Configuration Engine

An enterprise-grade PowerShell automation script engineered to establish, harden, and maintain a balanced AI execution policy inside Google Antigravity, Cursor, and VS Code configuration files (`settings.json`).

The script applies the **Principle of Least Privilege**:
* **Autonomous Read-Only Discovery:** Auto-approves harmless parameter inspection, command help, and Git inspection commands (`Get-Command`, `Get-Help`, `Get-Member`, `Get-Mg*`, `git status/log/diff`), allowing AI agents to navigate the development environment without interruption.
* **Guarded State Mutation:** Enforces explicit human confirmation prior to executing state-altering, file-system mutating, or cloud-destructive operations (`Set-*`, `Update-*`, `Remove-*`, `New-*`, `Reset-*`, `Clear-*`, `Restart-*`, `Stop-*`, `git push/reset/checkout`).
* **Hazard Neutralization:** Eliminates dangerous global auto-approval wildcards (`agent.autoApproveExecution`) and hardens interactive terminal flags (`agent.terminal.alwaysProceed = false`).

---

## Metadata & Ownership

* **Author:** Roman Pindela
* **Contact Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
* **GitHub Profile:** [https://github.com/romanpindela](https://github.com/romanpindela)
* **Current Version:** `1.2.0`
* **Release Date:** October 2026
* **License:** MIT

---

## Visual Previews & Screenshots

| Default Guard Rails & Help Screen (`.\Set-AntigravitySafeRules.ps1`) |
| :---: |
| ![Default Run](assets/Standard_run.jpg) |

| Applying Security Rules to Targets (`.\Set-AntigravitySafeRules.ps1 -Apply -Target All`) |
| :---: |
| ![Applying Rules](assets/Setting_rules.jpg) |

---

## Architectural Highlights

* **Multi-Runtime JSON Engine:** Seamlessly handles both Windows PowerShell 5.1 and PowerShell Core 7+. Uses recursive object mapping and safely strips VS Code JSON with Comments (`JSONC`), preventing parse failures or configuration loss.
* **Deterministic Guard Rails:** Running the script without parameters (`.\Set-AntigravitySafeRules.ps1`) triggers an empty-run protection banner with usage guidance and exits without altering settings. Modifications require an explicit `-Apply` switch.
* **Bilingual Windows Compatibility:** Built with language-independent .NET APIs (e.g., WellKnownSidType `BuiltInAdministratorsSid`, `[System.Environment]::GetFolderPath('ApplicationData')`), ensuring identical operation on Polish ("Administratorzy") and English ("Administrators") editions of Windows Desktop and Windows Server.
* **Automatic Safety Backups:** Automatically generates timestamped backups (e.g., `settings.json.bak_20261007_162449`) before modifying any file.
* **Simulation Support (WhatIf):** Full support for PowerShell `-WhatIf` and `-Confirm` flags (`[CmdletBinding(SupportsShouldProcess = $true)]`) for zero-risk dry-run audits.
* **Preservation of Existing Settings:** Merges permission rules into existing user configurations without overwriting unrelated IDE preferences, theme selections, or extension configs.

---

## Microsoft 365 & Entra ID Protection

When developers interact with Microsoft 365 (Exchange Online, SharePoint Online, Teams) or Azure / Entra ID via Microsoft Graph PowerShell (`Microsoft.Graph`), AI coding assistants can accidentally execute destructive tenant commands if auto-approve rules are overly broad.

This configuration enforces granular boundaries:
* **Allowed (Autonomous):** Read-only introspection cmdlets such as `Get-Command`, `Get-Help`, `Get-MgUser`, `Get-MgGroup`, and `Get-MgServicePrincipal`. The AI agent can examine schemas, query IDs, and retrieve tenant state without user prompts.
* **Guarded (Interactive Approval):** Destructive or mutating cmdlets such as `Update-MgUser`, `Remove-MgUser`, `New-MgGroup`, `Reset-MgUserPassword`, and `Set-Mailbox` are intercepted. The IDE requires the user to click or confirm before the command is sent to the terminal.

---

## Prerequisites & Installation

### 1. PowerShell Execution Policy
Ensure your PowerShell execution policy allows running local scripts:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 2. Unblocking the Script (Important)
When downloading PowerShell scripts from GitHub or the Internet, Windows attaches an alternate data stream (`Zone.Identifier`) that marks the file as untrusted. Unblock the script before running:
```powershell
Unblock-File -Path .\Set-AntigravitySafeRules.ps1
```

### 3. Administrator Privileges Note
By design, user-level IDE configuration files reside inside `%APPDATA%` (`$HOME\AppData\Roaming\Antigravity\User\settings.json`). Modifying these files does **not** require elevation. Running this script as Administrator is unnecessary and discouraged because elevation shifts `%APPDATA%` to the Administrator profile rather than your user environment.

---

## Parameter Reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-Apply` | `[switch]` | `$false` | **Required to write changes.** Without this switch, the script displays help and safety guidance without modifying files. |
| `-Target` | `[string]` | `'Auto'` | Target IDE profile. Allowed: `Auto`, `Antigravity`, `Cursor`, `AntigravityServer`, `VSCode`, `All`. |
| `-SettingsPath` | `[string]` | *Auto-detected* | Explicit file path to a custom `settings.json` file. |
| `-AdditionalAllowRules` | `[string[]]` | `@()` | Additional command patterns to append to `agent.permissions.allowRules`. |
| `-AdditionalAskRules` | `[string[]]` | `@()` | Additional command patterns to append to `agent.permissions.askRules`. |
| `-Force` | `[switch]` | `$false` | Overwrites permission rules rather than merging with existing custom rules. |
| `-NoBackup` | `[switch]` | `$false` | Suppresses creation of `.bak_yyyyMMdd_HHmmss` backup files. |
| `-Help`, `-h` | `[switch]` | `$false` | Displays the interactive CLI help banner, author details, and syntax. |
| `-WhatIf` | `[switch]` | N/A | Simulates configuration changes without modifying files (dry run). |
| `-Confirm` | `[switch]` | N/A | Prompts for confirmation before modifying each target file. |

---

## Policy Rules Breakdown

### Default Allow Rules (`agent.permissions.allowRules`)
Harmless discovery and inspection commands that execute without prompts:
* `*Get-Command*`
* `*Get-Help*`
* `*Get-Member*`
* `*Parameters.Keys*`
* `*ParameterSets*`
* `powershell *-Command *Get-*`
* `pwsh *-Command *Get-*`
* `*Get-Mg*`
* `git status*`
* `git log*`
* `git diff*`

### Default Ask Rules (`agent.permissions.askRules`)
Operations requiring interactive developer consent:
* `*Update-*`
* `*Set-*`
* `*Remove-*`
* `*New-*`
* `*Reset-*`
* `*Clear-*`
* `*Restart-*`
* `*Stop-*`
* `git push*`
* `git reset*`
* `git checkout*`

---

## Usage Scenarios & Examples

### 1. Safe Inspection & Help Banner (Default Empty Run)
Running the script without parameters displays the built-in help guide and exits safely:
```powershell
.\Set-AntigravitySafeRules.ps1
# or explicitly:
.\Set-AntigravitySafeRules.ps1 -Help
```

![Default Run Console Banner](assets/Standard_run.jpg)

### 2. Standard Safe Deployment
Auto-detects active IDE configurations (Antigravity, Cursor, or VS Code) and applies the balanced policy:
```powershell
.\Set-AntigravitySafeRules.ps1 -Apply
```

### 3. Target Google Antigravity Explicitly
Directs configuration strictly to Google Antigravity User settings:
```powershell
.\Set-AntigravitySafeRules.ps1 -Apply -Target Antigravity
```

### 4. Target All Installed IDE Environments
Audits and updates every discovered editor installation across the workstation:
```powershell
.\Set-AntigravitySafeRules.ps1 -Apply -Target All
```

![Applying Security Policy to Targets](assets/Setting_rules.jpg)

### 5. Dry-Run / Simulation Mode (`-WhatIf`)
Audits what files would be modified and where backups would be generated without writing to disk:
```powershell
.\Set-AntigravitySafeRules.ps1 -Apply -WhatIf
```

### 6. Appending Custom Project Rules
Adds project-specific test and build commands to the auto-approve allow list:
```powershell
.\Set-AntigravitySafeRules.ps1 -Apply -AdditionalAllowRules "npm test*", "cargo check*", "pytest*"
```

### 7. Custom File Path
Applies the policy to a non-standard or portable editor path:
```powershell
.\Set-AntigravitySafeRules.ps1 -Apply -SettingsPath "D:\PortableApps\Antigravity\data\user-data\User\settings.json"
```

### 8. Force Resetting Permission Lists
Overwrites existing permission rules with the clean baseline, discarding legacy or stale entries:
```powershell
.\Set-AntigravitySafeRules.ps1 -Apply -Force
```

---

## Post-Execution Activation

After applying the configuration, reload the IDE window to apply the updated settings immediately:
1. In Antigravity, Cursor, or VS Code, press **`Ctrl + Shift + P`** (or **`Cmd + Shift + P`** on macOS).
2. Type and select: **`Developer: Reload Window`**.

---

## Version History & Changelog

### Version 1.2.0 (October 2026)
* **Bug Fix:** Removed invalid LaTeX syntax (`\vert{}`) and corrected string quote parsing errors in `Set-AntigravitySafeRules.ps1`.
* **CleanCode Architecture:** Modularized code with robust helper functions (`Show-ScriptHelp`, `Get-TargetSettingsPaths`, `Convert-JsonToOrderedDictionary`, `Sanitize-Rules`).
* **Guard Rails:** Implemented default empty-run protection requiring `-Apply` to modify files.
* **PowerShell 5.1 & 7 Compatibility:** Implemented custom recursive JSON deserializer supporting both Windows PowerShell 5.1 and modern PowerShell Core 7+.
* **JSONC Support:** Added automatic regex stripping for single-line (`//`) and multi-line (`/* */`) comments in `settings.json`.
* **Cloud & M365 Security:** Added `*Get-Mg*` discovery to default allow rules while strictly gating mutating cmdlets.
* **Documentation:** Created comprehensive enterprise `README.md` with complete parameter and usage reference.
