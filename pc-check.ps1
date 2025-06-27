function Write-CenteredLine {
    param(
        [string]$Text,
        [ConsoleColor]$Color = "White"
    )
    $width = $Host.UI.RawUI.WindowSize.Width
    $padding = [Math]::Max(0, [Math]::Floor(($width - $Text.Length) / 2))
    Write-Host (" " * $padding) $Text -ForegroundColor $Color
}

function Write-Header {
    param(
        [string]$Text,
        [int]$TotalWidth = 45,
        [ConsoleColor]$Color = "Yellow"
    )
    if ($Text.Length -gt ($TotalWidth - 2)) {
        $Text = $Text.Substring(0, $TotalWidth - 2)
    }
    $paddingLeftText = [Math]::Floor(($TotalWidth - 2 - $Text.Length) / 2)
    $paddingRightText = $TotalWidth - 2 - $paddingLeftText - $Text.Length
    $line = '=' * $TotalWidth
    $middle = '=' + (' ' * $paddingLeftText) + $Text + (' ' * $paddingRightText) + '='
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    $paddingLeftBox = [Math]::Max(0, [Math]::Floor(($consoleWidth - $TotalWidth) / 2))
    $padSpaces = ' ' * $paddingLeftBox
    Write-Host ($padSpaces + $line) -ForegroundColor $Color
    Write-Host ($padSpaces + $middle) -ForegroundColor $Color
    Write-Host ($padSpaces + $line) -ForegroundColor $Color
    Write-Host ""
}

$host.UI.RawUI.WindowTitle = "Vireth Quick Tools - PC Check"
$bannerLines = @(
    "██╗   ██╗ ██████╗ ████████╗              ██████╗  ██████╗     ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗",
    "██║   ██║██╔═══██╗╚══██╔══╝              ██╔══██╗██╔════╝    ██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝",
    "██║   ██║██║   ██║   ██║       █████╗    ██████╔╝██║         ██║     ███████║█████╗  ██║     █████╔╝ ",
    "╚██╗ ██╔╝██║▄▄ ██║   ██║       ╚════╝    ██╔═══╝ ██║         ██║     ██╔══██║██╔══╝  ██║     ██╔═██╗ ",
    " ╚████╔╝ ╚██████╔╝   ██║                 ██║     ╚██████╗    ╚██████╗██║  ██║███████╗╚██████╗██║  ██╗",
    "  ╚═══╝   ╚══▀▀═╝    ╚═╝                 ╚═╝      ╚═════╝     ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝"
)
foreach ($line in $bannerLines) {
    Write-CenteredLine -Text $line -Color Cyan
}
Write-Host

Write-Header "DMA CHECK START" 45 Yellow

Write-Header "Connected PnP Devices" 45 Green
$pnp = Get-PnpDevice -PresentOnly
if ($pnp) {
    $pnp | Select-Object Class, FriendlyName, InstanceId, Status | Format-Table -AutoSize
} else {
    Write-CenteredLine "No results found" -Color Red
}
Write-Host

Write-Header "System Drivers" 45 Magenta
$drivers = Get-WmiObject Win32_SystemDriver
if ($drivers) {
    $drivers | Select-Object Name, State, StartMode, PathName | Format-Table -AutoSize
} else {
    Write-CenteredLine "No results found" -Color Red
}
Write-Host

Write-Header "Loaded Device Drivers" 45 Cyan
$loadedDrivers = Get-WmiObject Win32_PnPSignedDriver
if ($loadedDrivers) {
    $loadedDrivers | Select-Object DeviceName, DriverVersion, Manufacturer, DriverDate, IsSigned | Sort-Object DeviceName | Format-Table -AutoSize
} else {
    Write-CenteredLine "No results found" -Color Red
}
Write-Host

Write-Header "Thunderbolt Controllers" 45 Cyan
$thunderbolt = Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -like '*Thunderbolt*' }
if ($thunderbolt) {
    $thunderbolt | Select-Object Class, FriendlyName, InstanceId, Status | Format-Table -AutoSize
} else {
    Write-CenteredLine "No results found" -Color Red
}
Write-Host

Write-Header "IOMMU / VT-d Status" 45 Yellow
try {
    $vt_d = Get-WmiObject -Namespace root\cimv2 -Class Win32_Processor | Select-Object -ExpandProperty SecondLevelAddressTranslationExtensions
    if ($vt_d -contains $true) {
        Write-CenteredLine "VT-d (Second Level Address Translation) support is enabled on CPU" -Color Green
    } else {
        Write-CenteredLine "VT-d is not detected or is disabled" -Color Red
    }
} catch {
    Write-CenteredLine "Unable to determine VT-d status" -Color Red
}
Write-Host

Write-Header "DMA CHECK COMPLETE" 45 Yellow
Write-Header "Recent Suspicious Files Scan" 45 Yellow

$pathsToScan = @(
    "$env:LOCALAPPDATA\FiveM\FiveM.app",
    "$env:APPDATA",
    "C:\Program Files",
    "C:\Program Files (x86)",
    "$env:LOCALAPPDATA\Temp"
)

$allRecentFiles = @()
foreach ($path in $pathsToScan) {
    if (Test-Path $path) {
        Write-CenteredLine "Scanning $path for .dll, .exe, .sys files modified in last 7 days..." -Color DarkYellow
        $recent = Get-ChildItem -Path $path -Include *.dll,*.exe,*.sys -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) }
        if ($recent) {
            $recent | Select-Object FullName, LastWriteTime | Format-Table -AutoSize
            $allRecentFiles += $recent
        } else {
            Write-CenteredLine "No results found" -Color Red
        }
    } else {
        Write-CenteredLine "Path not found: $path" -Color DarkRed
    }
    Write-Host
}

Write-Header "Recent Suspicious Files Scan Complete" 45 Yellow

Write-Header "Startup Programs Check" 45 Green
$startup = Get-CimInstance -ClassName Win32_StartupCommand
if ($startup) {
    $startup | Select-Object Location, Name, Command | Format-Table -AutoSize
} else {
    Write-CenteredLine "No results found" -Color Red
}
Write-Host

Write-Header "Startup Programs Check Complete" 45 Green

Write-Header "Scheduled Tasks Check" 45 Magenta
$tasks = Get-ScheduledTask | Where-Object { $_.State -eq 'Ready' -or $_.State -eq 'Running' }
if ($tasks) {
    $tasks | Select-Object TaskName, State, Author | Format-Table -AutoSize
} else {
    Write-CenteredLine "No results found" -Color Red
}
Write-Host

Write-Header "Scheduled Tasks Check Complete" 45 Magenta



# PC Check - Auto Analysis

Write-Header "PC Check - Auto Analysis" 70 Yellow
$suspicionScore = 0
$suspicionReasons = @()

$loadedDrivers = @($loadedDrivers)
$startup = @($startup)
$tasks = @($tasks)
$allRecentFiles = @($allRecentFiles)

if ($loadedDrivers.Count -gt 0) {
    $unsignedDrivers = $loadedDrivers | Where-Object { $_.IsSigned -eq $false }
    $countUnsigned = $unsignedDrivers.Count
    if ($countUnsigned -gt 0) {
        $score = [Math]::Min($countUnsigned, 5)
        $suspicionScore += $score
        $suspicionReasons += "Unsigned drivers detected: $countUnsigned"
        Write-CenteredLine "Unsigned drivers found: $countUnsigned" -Color Red
    } else {
        Write-CenteredLine "No unsigned drivers detected" -Color Green
    }
} else {
    Write-CenteredLine "Unable to evaluate unsigned drivers" -Color Red
}

if ($startup.Count -gt 0) {
    $suspiciousStartup = $startup | Where-Object { $_.Command -match '(inject|modmenu|cheat|bypass|fivem)' }
    $countStartup = $suspiciousStartup.Count
    if ($countStartup -gt 0) {
        $score = $countStartup * 2
        $suspicionScore += $score
        $suspicionReasons += "Suspicious startup entries found: $countStartup"
        Write-CenteredLine "Suspicious startup entries: $countStartup" -Color Red
    } else {
        Write-CenteredLine "No suspicious startup entries detected" -Color Green
    }
} else {
    Write-CenteredLine "Unable to evaluate startup programs" -Color Red
}

if ($tasks.Count -gt 0) {
    $suspiciousTasks = $tasks | Where-Object { $_.TaskName -match '(inject|modmenu|cheat|bypass|fivem)' }
    $countTasks = $suspiciousTasks.Count
    if ($countTasks -gt 0) {
        $score = $countTasks * 2
        $suspicionScore += $score
        $suspicionReasons += "Suspicious scheduled tasks found: $countTasks"
        Write-CenteredLine "Suspicious scheduled tasks: $countTasks" -Color Red
    } else {
        Write-CenteredLine "No suspicious scheduled tasks detected" -Color Green
    }
} else {
    Write-CenteredLine "Unable to evaluate scheduled tasks" -Color Red
}

if ($allRecentFiles.Count -gt 0) {
    $recentCount = $allRecentFiles.Count
    if ($recentCount -ge 100) {
        $suspicionReasons += "Very high number of recently modified system files: $recentCount"
        Write-CenteredLine "Very high number of recent system files modified: $recentCount" -Color Yellow
    } elseif ($recentCount -ge 30) {
        $suspicionReasons += "Moderate number of recently modified system files: $recentCount"
        Write-CenteredLine "Moderate number of recent system files modified: $recentCount" -Color Yellow
    } elseif ($recentCount -gt 0) {
        Write-CenteredLine "Some recent system files modified: $recentCount" -Color Yellow
    } else {
        Write-CenteredLine "No recent suspicious files found" -Color Green
    }
} else {
    Write-CenteredLine "Unable to evaluate recent suspicious files" -Color Red
}

Write-Host

if ($suspicionScore -ge 7) {
    Write-CenteredLine "⚠️ High likelihood of FiveM cheats detected, review suspicious entries carefully" -Color Red
} elseif ($suspicionScore -ge 3) {
    Write-CenteredLine "⚠️ Moderate likelihood of FiveM cheats, review suspicious entries carefully" -Color Yellow
} elseif ($suspicionScore -eq 0 -and $allRecentFiles.Count -ge 100) {
    Write-CenteredLine "✅ Low likelihood of FiveM cheats detected (high file changes might be benign)" -Color Green
} else {
    Write-CenteredLine "✅ Low likelihood of FiveM cheats detected" -Color Green
}

Write-Host

if ($suspicionReasons.Count -gt 0) {
    Write-CenteredLine "Summary:" -Color Cyan
    foreach ($reason in $suspicionReasons) {
        Write-CenteredLine "- $reason" -Color Cyan
    }
} else {
    Write-CenteredLine "No suspicious indicators detected." -Color Green
}
