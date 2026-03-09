# Switch-AwsProfile.ps1 (aka "sap")

Interactive PowerShell tool for switching between AWS SSO profiles.

[![Build](https://github.com/michaelsanford/Switch-AwsProfile/actions/workflows/lint.yml/badge.svg)](https://github.com/michaelsanford/Switch-AwsProfile/actions/workflows/lint.yml)

## Features

- Reads profiles from `${env:USERPROFILE}\.aws\config`
- Arrow key navigation
- Sets `AWS_PROFILE` in current shell
- Automatically triggers `aws sso login`

## Usage

```powershell
sap
```

Navigate with arrow keys, press Enter to select, or Esc to cancel.

## Installation

### Quick Setup (PowerShell)

Run these commands to install:

```powershell
# Create Scripts directory
$scriptsDir = "$env:LOCALAPPDATA\Scripts"
New-Item -ItemType Directory -Path $scriptsDir -Force

# Copy script to Scripts directory
Copy-Item .\Switch-AwsProfile.ps1 $scriptsDir\

# Add Scripts directory to user PATH (if not already there)
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$scriptsDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$scriptsDir", "User")
    $env:Path += ";$scriptsDir"
}

# Add function to PowerShell profile
$profileFunction = @"

# AWS Profile Switcher
if (-not (Get-Command sap -ErrorAction SilentlyContinue)) {
    function sap { . `"`$env:LOCALAPPDATA\Scripts\Switch-AwsProfile.ps1`" }
}
"@

Add-Content -Path $PROFILE -Value $profileFunction

# Reload profile
. $PROFILE
```

### Manual Installation

1. Create `%LOCALAPPDATA%\Scripts\` directory
2. Copy `Switch-AwsProfile.ps1` to that directory
3. Add `%LOCALAPPDATA%\Scripts` to your user PATH environment variable
4. Add this to your PowerShell profile (`$PROFILE`):

   ```powershell
   if (-not (Get-Command sap -ErrorAction SilentlyContinue)) {
       function sap { . "$env:LOCALAPPDATA\Scripts\Switch-AwsProfile.ps1" }
   }
   ```

5. Reload your profile: `. $PROFILE`

## Requirements

- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed
- Configured AWS SSO profiles in `${env:USERPROFILE}\.aws\config`

## Recommended

[Oh My Posh](https://ohmypo.sh/docs/installation/windows) enhances your PowerShell prompt with themes and AWS profile display.

[Here's my configuration](https://gist.github.com/michaelsanford/0ff562591a78f6815bb72fc879aead01).


---

## Bash/Zsh Version

A bash/zsh version is available as `switch-aws-profile.sh`.

**Installation:**

```bash
# Copy to a directory in your PATH
mkdir -p ~/.local/bin
cp switch-aws-profile.sh ~/.local/bin/sap
chmod +x ~/.local/bin/sap

# Add function to your ~/.bashrc or ~/.zshrc
echo 'sap() { source ~/.local/bin/sap; }' >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc  # or source ~/.zshrc
```

**Usage:**

```bash
sap
```

Note: The function sources the script so AWS_PROFILE persists in your current shell.
