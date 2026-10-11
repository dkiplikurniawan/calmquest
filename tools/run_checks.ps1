<#
.SYNOPSIS
  Runs every automated check for CALMQUEST on Windows.

.DESCRIPTION
  1. Static res:// reference check (Python)
  2. Godot headless import (builds the class cache)
  3. GDScript unit tests        (tests/run_tests.gd)
  4. Integration smoke test     (tests/smoke/smoke_test.tscn)
     V2 overworld test          (tests/smoke/overworld_test.tscn)
     UI smoke test              (tests/smoke/ui_smoke_test.tscn)
  5. Headless load of every game screen
  6. Python analysis unit tests (analysis/tests)

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1 -Godot "C:\Tools\Godot_v4.7.2-stable_win64_console.exe"

  The Godot path can also come from the GODOT environment variable or a
  'godot' command on PATH. Use the *_console.exe build so output is captured.
#>
param(
    [string]$Godot = $env:GODOT,
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path ([System.IO.Path]::GetTempPath()) "calmquest_checks"
New-Item -ItemType Directory -Force $logDir | Out-Null
$results = New-Object System.Collections.ArrayList

if ([string]::IsNullOrWhiteSpace($Godot)) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { $Godot = $cmd.Source }
}

function Invoke-Logged([string]$name, [string]$exe, [string[]]$arguments, [int]$timeoutSec = 300) {
    $out = Join-Path $logDir "$name.out.log"
    $err = Join-Path $logDir "$name.err.log"
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $root -NoNewWindow -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err
    # Windows PowerShell 5.1 only reports ExitCode if the handle was read before exit.
    $null = $p.Handle
    if (-not $p.WaitForExit($timeoutSec * 1000)) {
        try { $p.Kill() } catch {}
        return @{ Code = -1; Text = "TIMEOUT after $timeoutSec s" }
    }
    $p.WaitForExit()
    $text = (Get-Content $out -Raw -ErrorAction SilentlyContinue) + "`n" + (Get-Content $err -Raw -ErrorAction SilentlyContinue)
    return @{ Code = $p.ExitCode; Text = $text }
}

function Add-Result([string]$check, [bool]$passed, [string]$detail) {
    [void]$results.Add([pscustomobject]@{ Check = $check; Result = $(if ($passed) { "PASS" } else { "FAIL" }); Detail = $detail })
}

function Test-GodotOutput($run) {
    # Script errors don't always change the exit code, so scan the log too.
    return ($run.Code -eq 0) -and ($run.Text -notmatch "SCRIPT ERROR|Parse Error|Failed to load script")
}

# 1. Static references
$r = Invoke-Logged "references" $Python @("tools/check_references.py")
Add-Result "Static res:// references" ($r.Code -eq 0) (($r.Text -split "`n" | Where-Object { $_ -match "Checked" }) -join " ")

if ([string]::IsNullOrWhiteSpace($Godot) -or -not (Test-Path $Godot)) {
    Add-Result "Godot checks" $false "Godot executable not found. Pass -Godot <path> or set GODOT."
} else {
    # 2. Import
    $r = Invoke-Logged "import" $Godot @("--headless", "--path", ".", "--import")
    Add-Result "Godot headless import" ($r.Code -eq 0) "exit $($r.Code)"

    # 3. Unit tests
    $r = Invoke-Logged "unit" $Godot @("--headless", "--path", ".", "--script", "res://tests/run_tests.gd")
    $summary = ($r.Text -split "`n" | Where-Object { $_ -match "^Unit tests:" }) -join " "
    Add-Result "GDScript unit tests" (Test-GodotOutput $r) $summary

    # 4. Smoke test
    $r = Invoke-Logged "smoke" $Godot @("--headless", "--path", ".", "res://tests/smoke/smoke_test.tscn")
    $summary = ($r.Text -split "`n" | Where-Object { $_ -match "^Smoke test:" }) -join " "
    Add-Result "Integration smoke test" (Test-GodotOutput $r) $summary

    # 4a. V2 overworld integration test (streaming, camera, bounds, travel, map, Act 1)
    $r = Invoke-Logged "overworld" $Godot @("--headless", "--path", ".", "res://tests/smoke/overworld_test.tscn")
    $summary = ($r.Text -split "`n" | Where-Object { $_ -match "^Overworld test:" }) -join " "
    Add-Result "V2 overworld test" (Test-GodotOutput $r) $summary

    # 4b. UI smoke test (menus, overlays, settings effects, check-in and results logic)
    $r = Invoke-Logged "ui_smoke" $Godot @("--headless", "--path", ".", "res://tests/smoke/ui_smoke_test.tscn")
    $summary = ($r.Text -split "`n" | Where-Object { $_ -match "^UI smoke test:" }) -join " "
    Add-Result "UI smoke test" (Test-GodotOutput $r) $summary

    # 5. Every screen loads and runs without script errors
    $scenes = @(
        "res://game/scenes/main/splash.tscn", "res://game/scenes/ui/main_menu.tscn",
        "res://game/scenes/ui/check_in.tscn", "res://game/scenes/ui/slot_select.tscn", "res://game/scenes/world/overworld.tscn",
        "res://game/scenes/ui/reflection.tscn", "res://game/scenes/ui/results.tscn"
    )
    foreach ($scene in $scenes) {
        $name = "scene_" + [System.IO.Path]::GetFileNameWithoutExtension($scene)
        $r = Invoke-Logged $name $Godot @("--headless", "--path", ".", $scene, "--quit-after", "120")
        Add-Result "Scene runs: $([System.IO.Path]::GetFileName($scene))" (Test-GodotOutput $r) "exit $($r.Code)"
    }
}

# 5a. Indonesian catalog: every player-facing string translated, placeholders and line breaks kept
$r = Invoke-Logged "i18n" $Python @("tools/i18n/extract.py")
$summary = ($r.Text -split "`n" | Where-Object { $_ -match "^strings found" }) -join " "
Add-Result "Translation catalog (id)" ($r.Code -eq 0) $summary

# 6. Python analysis tests
$r = Invoke-Logged "python_tests" $Python @("-m", "unittest", "discover", "-s", "analysis/tests")
$summary = ($r.Text -split "`n" | Where-Object { $_ -match "^Ran |^OK|^FAILED" }) -join " "
Add-Result "Python analysis tests" ($r.Code -eq 0) $summary

$results | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Output
Write-Output "Logs: $logDir"
$failed = @($results | Where-Object { $_.Result -eq "FAIL" }).Count
if ($failed -gt 0) { exit 1 } else { exit 0 }
