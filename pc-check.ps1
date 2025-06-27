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
Get-PnpDevice -PresentOnly |
    Select-Object Class, FriendlyName, InstanceId, Status |
    Format-Table -AutoSize
Write-Host

Write-Header "System Drivers" 45 Magenta
Get-WmiObject Win32_SystemDriver |
    Select-Object Name, State, StartMode, PathName |
    Format-Table -AutoSize
Write-Host

Write-Header "Loaded Device Drivers" 45 Cyan
Get-WmiObject Win32_PnPSignedDriver |
    Select-Object DeviceName, DriverVersion, Manufacturer, DriverDate, IsSigned |
    Sort-Object DeviceName |
    Format-Table -AutoSize
Write-Host

Write-Header "Thunderbolt Controllers" 45 Cyan
Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -like '*Thunderbolt*' } |
    Select-Object Class, FriendlyName, InstanceId, Status |
    Format-Table -AutoSize
Write-Host

Write-Header "IOMMU / VT-d Status" 45 Yellow
try {
    $vt_d = Get-WmiObject -Namespace root\cimv2 -Class Win32_Processor | Select-Object -ExpandProperty SecondLevelAddressTranslationExtensions
    if ($vt_d -eq $true) {
        Write-Host "VT-d (Second Level Address Translation) support is ENABLED on CPU." -ForegroundColor Green
    } else {
        Write-Host "VT-d NOT detected or DISABLED. Check BIOS settings!" -ForegroundColor Red
    }
} catch {
    Write-Host "Unable to determine VT-d status." -ForegroundColor Red
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

foreach ($path in $pathsToScan) {
    if (Test-Path $path) {
        Write-Host "Scanning $path for .dll, .exe, .sys files modified in last 7 days..." -ForegroundColor DarkYellow
        Get-ChildItem -Path $path -Include *.dll,*.exe,*.sys -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
            Select-Object FullName, LastWriteTime |
            Format-Table -AutoSize
    } else {
        Write-Host "Path not found: $path" -ForegroundColor DarkRed
    }
    Write-Host ""
}

Write-Header "Recent Suspicious Files Scan Complete" 45 Yellow
Write-Header "Startup Programs Check" 45 Green
Get-CimInstance -ClassName Win32_StartupCommand |
    Select-Object Location, Name, Command |
    Format-Table -AutoSize
Write-Host

Write-Header "Startup Programs Check Complete" 45 Green
Write-Header "Scheduled Tasks Check" 45 Magenta
Get-ScheduledTask | Where-Object { $_.State -eq 'Ready' -or $_.State -eq 'Running' } |
    Select-Object TaskName, State, Author |
    Format-Table -AutoSize
Write-Host

Write-Header "Scheduled Tasks Check Complete" 45 Magenta
Write-CenteredLine "All checks complete, review output carefully." -Color Yellow
