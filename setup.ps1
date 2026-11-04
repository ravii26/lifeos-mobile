# One-time setup for the Ally / LifeOS Flutter app on Windows. Safe to run again.
# Run with: powershell -ExecutionPolicy Bypass -File setup.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Step($message) { Write-Host "`n==> $message" -ForegroundColor Cyan }
function Run($command, [string[]]$arguments) {
    & $command @arguments
    if ($LASTEXITCODE -ne 0) { throw "Failed: $command $($arguments -join ' ')" }
}

Step 'Checking for Flutter'
if (Get-Command 'flutter' -ErrorAction SilentlyContinue) {
    Write-Host 'Flutter is already installed.'
} else {
    if (-not (Get-Command 'git' -ErrorAction SilentlyContinue)) {
        throw 'git is missing. Install it with: winget install --id Git.Git -e   then open a new terminal and run this again.'
    }
    $flutterHome = Join-Path $env:USERPROFILE 'Development\flutter'
    if (-not (Test-Path $flutterHome)) {
        Write-Host "Downloading Flutter (stable) to $flutterHome. This takes a few minutes."
        Run 'git' @('clone', '--depth', '1', '-b', 'stable', 'https://github.com/flutter/flutter.git', $flutterHome)
    }
    $flutterBin = Join-Path $flutterHome 'bin'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $flutterBin) {
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$flutterBin", 'User')
        Write-Host 'Added Flutter to your user PATH. Open a new terminal to use it there.'
    }
    $env:Path = "$env:Path;$flutterBin"
}

Step 'Checking Windows Developer Mode'
# Flutter plugins need symlinks, which Windows only allows with Developer Mode on.
$devKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
$devMode = (Get-ItemProperty -Path $devKey -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
if ($devMode -ne 1) {
    throw 'Developer Mode is off. Run: start ms-settings:developers   turn on "Developer Mode", then run this script again.'
}

Step 'Checking the Android NDK'
# The Gradle build cannot install this by itself: the newer Android tools misread
# the "ndk;version" name it uses, so install it here with the "ndk/version" name.
$ndkVersion = '28.2.13676358'
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$androidCli = Join-Path $sdk 'cmdline-tools\latest\bin\android.exe'
if (Test-Path (Join-Path $sdk "ndk\$ndkVersion\source.properties")) {
    Write-Host "NDK $ndkVersion is already installed."
} elseif (Test-Path $androidCli) {
    Write-Host "Installing NDK $ndkVersion. This is a large download."
    Run $androidCli @('--no-metrics', 'sdk', 'install', "ndk/$ndkVersion")
} else {
    Write-Host "Android command-line tools not found. Install Android Studio, then add NDK $ndkVersion from its SDK Manager." -ForegroundColor Yellow
}

Step 'Installing Dart and Flutter packages'
Run 'flutter' @('pub', 'get')

Step 'Checking your machine (anything marked [!] or [X] below still needs attention)'
& flutter doctor

Step 'Done'
Write-Host 'Run against the live server:   flutter run'
Write-Host 'Run against your local API:    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1   (Android emulator)'
Write-Host 'On a real phone, use your laptop''s Wi-Fi IP in place of 10.0.2.2.'
