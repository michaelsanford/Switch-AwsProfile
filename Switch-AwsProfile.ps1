<#
.SYNOPSIS
    Interactive AWS SSO profile switcher with arrow key navigation.

.DESCRIPTION
    Reads AWS SSO profiles from ~/.aws/config and presents an interactive menu.
    Sets AWS_PROFILE environment variable in the current shell and triggers aws sso login.

.EXAMPLE
    Switch-AwsProfile
    Displays interactive menu to select and switch AWS profiles.

.EXAMPLE
    sap
    Short alias for Switch-AwsProfile (if configured in $PROFILE).

.NOTES
    Requires PowerShell 7+ and AWS CLI with configured SSO profiles.
#>

$configPath = "$env:USERPROFILE\.aws\config"
$profiles = @()

Get-Content $configPath | ForEach-Object {
    if ($_ -match '^\[profile (.+)\]$') {
        $profiles += $matches[1]
    }
}

if ($profiles.Count -eq 0) {
    Write-Host "No profiles found in $configPath"
    exit 1
}

$selected = 0
$startPos = $Host.UI.RawUI.CursorPosition

Write-Host "`nAWS SSO Profiles (arrow keys, Enter to select, Esc to cancel):`n" -ForegroundColor Cyan

while ($true) {
    $Host.UI.RawUI.CursorPosition = $startPos
    $Host.UI.RawUI.CursorPosition = @{X=0; Y=$startPos.Y + 2}
    
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        if ($i -eq $selected) {
            Write-Host "  > $($profiles[$i])" -ForegroundColor Green
        } else {
            Write-Host "    $($profiles[$i])"
        }
    }
    
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    if ($key.VirtualKeyCode -eq 38) { $selected = [Math]::Max(0, $selected - 1) }
    elseif ($key.VirtualKeyCode -eq 40) { $selected = [Math]::Min($profiles.Count - 1, $selected + 1) }
    elseif ($key.VirtualKeyCode -eq 13) { break }
    elseif ($key.VirtualKeyCode -eq 27) { Write-Host ""; exit 0 }
}

$selectedProfile = $profiles[$selected]
$env:AWS_PROFILE = $selectedProfile

Write-Host "`nSet AWS_PROFILE to: $selectedProfile" -ForegroundColor Green

aws sso login --profile $selectedProfile
