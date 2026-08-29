# Script to fix Gradle wrapper markers so it recognizes the installed Gradle

$gradlePath = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.0-all\a2o1xoguejy6msdh0lk99lxza"

Write-Host "Fixing Gradle wrapper markers..." -ForegroundColor Cyan
Write-Host ""

# Check if Gradle is installed
if (-not (Test-Path "$gradlePath\gradle-8.0\bin\gradle.bat")) {
    Write-Host "ERROR: Gradle not found at expected location!" -ForegroundColor Red
    Write-Host "Expected: $gradlePath\gradle-8.0\bin\gradle.bat" -ForegroundColor Yellow
    exit 1
}

Write-Host "Step 1: Removing incomplete download markers..." -ForegroundColor Yellow

# Remove lock file (may need admin or process termination)
$lockFile = "$gradlePath\gradle-8.0-all.zip.lck"
if (Test-Path $lockFile) {
    try {
        Remove-Item $lockFile -Force -ErrorAction Stop
        Write-Host "  Removed lock file" -ForegroundColor Green
    } catch {
        Write-Host "  Could not remove lock file (may be in use): $_" -ForegroundColor Yellow
        Write-Host "  Try closing any running Gradle/Flutter processes and run again" -ForegroundColor Yellow
    }
}

# Remove partial download file
$partFile = "$gradlePath\gradle-8.0-all.zip.part"
if (Test-Path $partFile) {
    try {
        Remove-Item $partFile -Force -ErrorAction Stop
        Write-Host "  Removed partial download file" -ForegroundColor Green
    } catch {
        Write-Host "  Could not remove partial file: $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Step 2: Creating completion marker..." -ForegroundColor Yellow

# Create a dummy zip file or marker to indicate completion
# Gradle wrapper checks for the zip file existence
$zipMarker = "$gradlePath\gradle-8.0-all.zip"
if (-not (Test-Path $zipMarker)) {
    # Create an empty file as a marker
    # Note: This is a workaround - ideally we'd have the actual zip
    # But since we have the extracted files, we can create a marker
    try {
        New-Item -ItemType File -Path $zipMarker -Force | Out-Null
        Write-Host "  Created zip marker file" -ForegroundColor Green
    } catch {
        Write-Host "  Could not create marker: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Zip marker already exists" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 3: Verifying installation..." -ForegroundColor Yellow

if (Test-Path "$gradlePath\gradle-8.0\bin\gradle.bat") {
    Write-Host "  Gradle installation verified" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Gradle markers fixed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "You can now run: flutter run" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: If you still see SSL errors, the lock file may be locked" -ForegroundColor Yellow
    Write-Host "      by a running process. Close all Flutter/Gradle processes" -ForegroundColor Yellow
    Write-Host "      and try again." -ForegroundColor Yellow
} else {
    Write-Host "  Gradle installation not found!" -ForegroundColor Red
    exit 1
}
