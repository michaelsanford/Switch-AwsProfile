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
    Short alias for Switch-AwsProfile.

.NOTES
    Requires PowerShell 7+ and AWS CLI with configured SSO profiles.
    Dot-source this file in $PROFILE to load the function and alias at shell startup.
#>

function Switch-AwsProfile {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Host "aws CLI not found. Install it from https://aws.amazon.com/cli/" -ForegroundColor Red
        return
    }

    $configPath = "$env:USERPROFILE\.aws\config"

    if (-not (Test-Path $configPath)) {
        Write-Host "AWS config not found at $configPath" -ForegroundColor Red
        return
    }

    $profiles = @()

    Get-Content $configPath | ForEach-Object {
        if ($_ -match '^\[profile (.+)\]$') {
            $profiles += $matches[1]
        }
    }

    if ($profiles.Count -eq 0) {
        Write-Host "No profiles found in $configPath"
        return
    }

    # --- Sort ---
    # Splits on non-alphanumeric boundaries; pads numeric segments so they sort correctly.
    function Get-NaturalSortKey([string]$str) {
        ($str -split '[^a-zA-Z0-9]+' | ForEach-Object {
            if ($_ -match '^\d+$') { $_.PadLeft(10, '0') } else { $_.ToLower() }
        }) -join '|'
    }

    $sortMode   = 0   # 0=original  1=A→Z  2=Z→A
    $sortLabels = @('', ' · A→Z', ' · Z→A')

    function Get-DisplayProfile {
        if ($sortMode -eq 1) { return @($profiles | Sort-Object { Get-NaturalSortKey $_ }) }
        if ($sortMode -eq 2) { return @($profiles | Sort-Object { Get-NaturalSortKey $_ } -Descending) }
        return $profiles
    }

    $displayProfiles = $profiles

    # --- Layout calculations ---
    $longestName = ($profiles | Measure-Object -Property Length -Maximum).Maximum
    $innerWidth = [Math]::Max($longestName + 4, 40)
    $innerWidth = [Math]::Min($innerWidth, [Console]::WindowWidth - 4)

    $viewportSize = [Math]::Min($profiles.Count, [Console]::WindowHeight - 6)
    if ($viewportSize -lt 1) {
        Write-Host "Terminal too small to display menu." -ForegroundColor Yellow
        $profiles | ForEach-Object { Write-Host "  $_" }
        return
    }

    # +4: top border, title, separator, bottom border; +1: hints bar
    $totalLines = $viewportSize + 5

    $hBar = '─' * $innerWidth
    $topBorder    = "┌$hBar┐"
    $separator    = "├$hBar┤"
    $bottomBorder = "└$hBar┘"

    function Show-Menu {
        param($selected, $scrollOffset)

        [Console]::SetCursorPosition(0, $drawTop)

        $sortInfo   = $sortLabels[$sortMode]
        $scrollInfo = if ($displayProfiles.Count -gt $viewportSize) { " ($($selected + 1)/$($displayProfiles.Count))" } else { "" }
        $title = " AWS SSO Profiles$sortInfo$scrollInfo"

        [Console]::WriteLine($topBorder)
        [Console]::WriteLine("│$($title.PadRight($innerWidth))│")
        [Console]::WriteLine($separator)

        for ($i = $scrollOffset; $i -lt $scrollOffset + $viewportSize; $i++) {
            $name = $displayProfiles[$i]
            if ($name.Length -gt $innerWidth - 4) {
                $name = $name.Substring(0, $innerWidth - 5) + '…'
            }
            $line = "  $($name.PadRight($innerWidth - 2))"
            [Console]::Write("│")
            if ($i -eq $selected) {
                $prevFg = [Console]::ForegroundColor
                $prevBg = [Console]::BackgroundColor
                [Console]::ForegroundColor = [ConsoleColor]::White
                [Console]::BackgroundColor = [ConsoleColor]::DarkCyan
                [Console]::Write($line)
                [Console]::ForegroundColor = $prevFg
                [Console]::BackgroundColor = $prevBg
            } else {
                [Console]::Write($line)
            }
            [Console]::WriteLine("│")
        }

        [Console]::WriteLine($bottomBorder)

        # Hints bar
        $hintsText = "  ↑↓ Navigate   [Enter] Select   [S] Sort   [Esc] Cancel"
        $padding   = " " * ([Math]::Max(0, $innerWidth + 2 - $hintsText.Length))
        $prevFg = [Console]::ForegroundColor
        [Console]::Write("  ")
        [Console]::ForegroundColor = [ConsoleColor]::Cyan
        [Console]::Write("↑↓")
        [Console]::ForegroundColor = $prevFg
        [Console]::Write(" Navigate   ")
        [Console]::ForegroundColor = [ConsoleColor]::Cyan
        [Console]::Write("[Enter]")
        [Console]::ForegroundColor = $prevFg
        [Console]::Write(" Select   ")
        [Console]::ForegroundColor = [ConsoleColor]::Cyan
        [Console]::Write("[S]")
        [Console]::ForegroundColor = $prevFg
        [Console]::Write(" Sort   ")
        [Console]::ForegroundColor = [ConsoleColor]::Cyan
        [Console]::Write("[Esc]")
        [Console]::ForegroundColor = $prevFg
        [Console]::WriteLine(" Cancel$padding")
    }

    # Pre-allocate space so any required terminal scroll happens before we capture $drawTop
    for ($i = 0; $i -lt $totalLines; $i++) { [Console]::WriteLine("") }
    $drawTop = [Console]::CursorTop - $totalLines

    $selected     = 0
    $scrollOffset = 0

    [Console]::CursorVisible = $false
    Show-Menu $selected $scrollOffset

    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 { $selected = [Math]::Max(0, $selected - 1) }                                          # Up
            40 { $selected = [Math]::Min($displayProfiles.Count - 1, $selected + 1) }                # Down
            33 { $selected = [Math]::Max(0, $selected - [Math]::Max(1, [int]($viewportSize / 2))) }  # Page Up
            34 { $selected = [Math]::Min($displayProfiles.Count - 1, $selected + [Math]::Max(1, [int]($viewportSize / 2))) } # Page Down
            83 {                                                                                        # S — cycle sort
                $currentProfile  = $displayProfiles[$selected]
                $sortMode        = ($sortMode + 1) % 3
                $displayProfiles = Get-DisplayProfile
                $newIndex        = [Array]::IndexOf([array]$displayProfiles, $currentProfile)
                $selected        = if ($newIndex -ge 0) { $newIndex } else { 0 }
            }
            13 { break }                                                                                # Enter
            27 {                                                                                        # Esc
                [Console]::CursorVisible = $true
                for ($row = $drawTop; $row -lt $drawTop + $totalLines; $row++) {
                    [Console]::SetCursorPosition(0, $row)
                    [Console]::Write(" " * [Console]::WindowWidth)
                }
                [Console]::SetCursorPosition(0, $drawTop)
                return
            }
        }

        if ($key.VirtualKeyCode -eq 13) { break }

        if ($selected -lt $scrollOffset) { $scrollOffset = $selected }
        if ($selected -ge ($scrollOffset + $viewportSize)) { $scrollOffset = $selected - $viewportSize + 1 }

        Show-Menu $selected $scrollOffset
    }

    [Console]::CursorVisible = $true
    for ($row = $drawTop; $row -lt $drawTop + $totalLines; $row++) {
        [Console]::SetCursorPosition(0, $row)
        [Console]::Write(" " * [Console]::WindowWidth)
    }
    [Console]::SetCursorPosition(0, $drawTop)

    $selectedProfile = $displayProfiles[$selected]
    $env:AWS_PROFILE = $selectedProfile

    Write-Host "Set AWS_PROFILE to: $selectedProfile" -ForegroundColor Green

    aws sso login --profile $selectedProfile
}

Set-Alias -Name sap -Value Switch-AwsProfile
