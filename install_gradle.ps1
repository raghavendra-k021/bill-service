# Script to install manually downloaded Gradle 8.0
# This will extract the zip file to the correct location

$gradleHash = "a2o1xoguejy6msdh0lk99lxza"
$targetPath = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.0-all\$gradleHash\gradle-8.0"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Gradle 8.0 Installation Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Gradle is already installed
if (Test-Path "$targetPath\bin\gradle.bat") {
    Write-Host "Gradle appears to be already installed at:" -ForegroundColor Green
    Write-Host $targetPath -ForegroundColor Cyan
    Write-Host ""
    $response = Read-Host "Do you want to reinstall? (y/n)"
    if ($response -ne "y") {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Find the downloaded zip file
$possibleLocations = @(
    "$env:USERPROFILE\Downloads\gradle-8.0-all.zip",
    "$env:TEMP\gradle-8.0-all.zip",
    "$env:USERPROFILE\Desktop\gradle-8.0-all.zip",
    ".\gradle-8.0-all.zip"
)

$zipFile = $null
foreach ($location in $possibleLocations) {
    if (Test-Path $location) {
        $zipFile = $location
        Write-Host "Found Gradle zip file at: $location" -ForegroundColor Green
        break
    }
}

if (-not $zipFile) {
    Write-Host "Gradle zip file not found in common locations." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please provide the path to your downloaded gradle-8.0-all.zip file:" -ForegroundColor Yellow
    $zipFile = Read-Host "Path"
    
    if (-not (Test-Path $zipFile)) {
        Write-Host "File not found: $zipFile" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Step 1: Extracting Gradle..." -ForegroundColor Yellow

# Create temporary extraction directory
$extractTemp = "$env:TEMP\gradle-extract-$(Get-Random)"
if (Test-Path $extractTemp) {
    Remove-Item -Path $extractTemp -Recurse -Force
}
New-Item -ItemType Directory -Path $extractTemp -Force | Out-Null

try {
    # Extract zip file
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $extractTemp)
    Write-Host "Extraction complete!" -ForegroundColor Green
} catch {
    Write-Host "Extraction failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Finding gradle-8.0 directory..." -ForegroundColor Yellow

# Find the gradle-8.0 directory in extracted files
$gradleDir = Get-ChildItem -Path $extractTemp -Directory | Where-Object { $_.Name -eq "gradle-8.0" } | Select-Object -First 1

if (-not $gradleDir) {
    Write-Host "ERROR: Could not find gradle-8.0 directory in extracted files!" -ForegroundColor Red
    Write-Host "Contents of extracted directory:" -ForegroundColor Yellow
    Get-ChildItem -Path $extractTemp | Select-Object Name
    Remove-Item -Path $extractTemp -Recurse -Force
    exit 1
}

Write-Host "Found: $($gradleDir.FullName)" -ForegroundColor Green

Write-Host ""
Write-Host "Step 3: Installing to target location..." -ForegroundColor Yellow

# Create target directory if it doesn't exist
if (-not (Test-Path $targetPath)) {
    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
}

# Copy all files
Write-Host "Copying files to: $targetPath" -ForegroundColor Cyan
Copy-Item -Path "$($gradleDir.FullName)\*" -Destination $targetPath -Recurse -Force

Write-Host ""
Write-Host "Step 4: Verifying installation..." -ForegroundColor Yellow

# Verify installation
if (Test-Path "$targetPath\bin\gradle.bat") {
    Write-Host "✓ Gradle installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Location: $targetPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "You can now run: flutter run" -ForegroundColor Green
} else {
    Write-Host "ERROR: Installation verification failed!" -ForegroundColor Red
    Write-Host "Expected file not found: $targetPath\bin\gradle.bat" -ForegroundColor Red
    exit 1
}

# Cleanup
Write-Host ""
Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
Remove-Item -Path $extractTemp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
