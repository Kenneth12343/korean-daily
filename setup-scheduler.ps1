<#
.SYNOPSIS
    Install/Remove Windows scheduled task for daily Korean push
.DESCRIPTION
    Creates a daily scheduled task to run daily-korean.ps1.
    Supports both console and email delivery modes.
.EXAMPLE
    .\setup-scheduler.ps1                    # Install (console mode)
    .\setup-scheduler.ps1 -Email             # Install (email mode - sends to your inbox)
    .\setup-scheduler.ps1 -Time "09:00"      # Custom time
    .\setup-scheduler.ps1 -Remove            # Remove task
    .\setup-scheduler.ps1 -Status            # Check status
#>

param(
    [string]$Time = "08:00",
    [switch]$Remove,
    [switch]$Status,
    [switch]$Email
)

$TaskName = "KoreanDailyPush"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptPath = Join-Path $ScriptDir "daily-korean.ps1"

if ($Status) {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "TASK INSTALLED" -ForegroundColor Green
        Write-Host ("  Name      : " + $TaskName)
        Write-Host ("  Script    : " + $ScriptPath)
        $action = $task.Actions[0]
        Write-Host ("  Action    : " + $action.Execute + " " + $action.Arguments)
        $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($info) {
            Write-Host ("  Last Run  : " + $info.LastRunTime)
            Write-Host ("  Next Run  : " + $info.NextRunTime)
        }
    } else {
        Write-Host "TASK NOT INSTALLED" -ForegroundColor Yellow
        Write-Host "Run .\setup-scheduler.ps1 to install"
        Write-Host "Run .\setup-scheduler.ps1 -Email for email mode"
    }
    return
}

if ($Remove) {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "TASK REMOVED" -ForegroundColor Green
    } else {
        Write-Host "No task found: $TaskName" -ForegroundColor Yellow
    }
    return
}

# --- INSTALL ---

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TOPIK KOREAN DAILY PUSH - SETUP" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ScriptPath)) {
    Write-Host "ERROR: Script not found: $ScriptPath" -ForegroundColor Red
    return
}

# Check email config if email mode
if ($Email) {
    $emailConfigFile = Join-Path $ScriptDir "email-config.json"
    if (-not (Test-Path $emailConfigFile)) {
        Write-Host "WARNING: email-config.json not found!" -ForegroundColor Red
        Write-Host "Please create email-config.json first." -ForegroundColor Yellow
        return
    }
    $emailConfig = Get-Content $emailConfigFile -Encoding UTF8 | ConvertFrom-Json
    if ($emailConfig.Password -eq "YOUR_AUTH_CODE_HERE") {
        Write-Host "WARNING: Please set your QQ Mail authorization code in email-config.json!" -ForegroundColor Red
        return
    }
}

# Remove old task
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed old task" -ForegroundColor Gray
}

# Build action
if ($Email) {
    $ArgList = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`" -SendMail -NoToast"
    $modeText = "EMAIL MODE -> 524181692@qq.com"
} else {
    $ArgList = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $modeText = "CONSOLE MODE"
}

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $ArgList
$Trigger = New-ScheduledTaskTrigger -Daily -At $Time

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false

try {
    Register-ScheduledTask -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -Description "TOPIK Korean Daily Push - $modeText" `
        -User $env:USERNAME `
        -RunLevel Limited `
        -Force

    Write-Host ""
    Write-Host "INSTALLED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host ""
    Write-Host ("  Mode      : " + $modeText) -ForegroundColor White
    Write-Host ("  Time      : Every day at " + $Time) -ForegroundColor White
    Write-Host ("  Script    : " + $ScriptPath) -ForegroundColor Gray
    Write-Host ""
    Write-Host "COMMANDS:" -ForegroundColor Yellow
    Write-Host "  Manual run : .\daily-korean.ps1" -ForegroundColor Gray
    if (-not $Email) {
        Write-Host "  Send email : .\daily-korean.ps1 -SendMail" -ForegroundColor Gray
    }
    Write-Host "  Test       : .\daily-korean.ps1 -Test" -ForegroundColor Gray
    Write-Host "  Status     : .\setup-scheduler.ps1 -Status" -ForegroundColor Gray
    Write-Host "  Remove     : .\setup-scheduler.ps1 -Remove" -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host "INSTALL FAILED: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try running PowerShell as Administrator." -ForegroundColor Yellow
}

