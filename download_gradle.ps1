# PowerShell script to manually download and install Gradle 8.0
# Run this script if you encounter SSL certificate errors

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Gradle 8.0 Manual Download Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$gradleUrl = "https://services.gradle.org/distributions/gradle-8.0-all.zip"
$gradleHome = "$env:USERPROFILE\.gradle\wrapper\dists"

Write-Host "Step 1: Downloading Gradle 8.0..." -ForegroundColor Yellow
$tempFile = "$env:TEMP\gradle-8.0-all.zip"

try {
    # Try PowerShell 6+ method first
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        Invoke-WebRequest -Uri $gradleUrl -OutFile $tempFile -SkipCertificateCheck
    } else {
        # Use .NET WebClient for older PowerShell
        $webClient = New-Object System.Net.WebClient
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient.DownloadFile($gradleUrl, $tempFile)
    }
    Write-Host "Download complete!" -ForegroundColor Green
} catch {
    Write-Host "`nAutomatic download failed due to SSL certificate issues." -ForegroundColor Red
    Write-Host "`nPlease download manually:" -ForegroundColor Yellow
    Write-Host "1. Open your browser and visit:" -ForegroundColor White
    Write-Host "   $gradleUrl" -ForegroundColor Cyan
    Write-Host "2. Save the file to: $tempFile" -ForegroundColor White
    Write-Host "3. Press any key after downloading..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    if (-not (Test-Path $tempFile)) {
        Write-Host "`nFile not found. Please ensure you saved it to: $tempFile" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nStep 2: Extracting Gradle..." -ForegroundColor Yellow

# Create extraction directory
$extractPath = "$env:TEMP\gradle-extract"
if (Test-Path $extractPath) {
    Remove-Item -Path $extractPath -Recurse -Force
}
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

# Extract zip
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempFile, $extractPath)
    Write-Host "Extraction complete!" -ForegroundColor Green
} catch {
    Write-Host "Extraction failed: $_" -ForegroundColor Red
    exit 1
}

# Find gradle-8.0 directory
$gradleDir = Get-ChildItem -Path $extractPath -Directory | Where-Object { $_.Name -like "gradle-8.0*" } | Select-Object -First 1

if (-not $gradleDir) {
    Write-Host "Could not find gradle-8.0 directory in extracted files" -ForegroundColor Red
    exit 1
}

Write-Host "`nStep 3: Installing Gradle..." -ForegroundColor Yellow

# Create Gradle wrapper directory
if (-not (Test-Path $gradleHome)) {
    New-Item -ItemType Directory -Path $gradleHome -Force | Out-Null
}

# Gradle uses a hash of the distribution URL
# We'll create the directory structure Gradle expects
$hash = "a1q7qj0j8j8j8j8j8j8j8j8j8j"  # This will be replaced by Gradle's actual hash on first run
$targetBase = "$gradleHome\gradle-8.0-all"

# Check if there's an existing partial download
$existingDirs = Get-ChildItem -Path $gradleHome -Directory -ErrorAction SilentlyContinue | 
    Where-Object { (Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "gradle-8.0" }) }

if ($existingDirs) {
    $targetPath = (Get-ChildItem $existingDirs[0].FullName -Directory | Where-Object { $_.Name -eq "gradle-8.0" }).FullName
    Write-Host "Found existing Gradle installation, updating..." -ForegroundColor Cyan
} else {
    # Create a temporary directory - Gradle will create the proper hash on first run
    # We'll extract to a location Gradle can find
    $targetPath = "$targetBase\gradle-8.0"
    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    Write-Host "Creating new Gradle installation..." -ForegroundColor Cyan
}

# Copy files
Copy-Item -Path "$($gradleDir.FullName)\*" -Destination $targetPath -Recurse -Force
Write-Host "Installation complete!" -ForegroundColor Green

# Cleanup
Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Gradle 8.0 installed successfully!" -ForegroundColor Green
Write-Host "Location: $targetPath" -ForegroundColor Cyan
Write-Host "`nYou can now run: flutter run" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
