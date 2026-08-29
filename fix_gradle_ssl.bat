@echo off
REM Script to help fix Gradle SSL certificate issues
REM This provides step-by-step instructions

echo ========================================
echo Gradle SSL Certificate Fix Helper
echo ========================================
echo.

echo This script will help you manually download and install Gradle 8.0
echo to bypass SSL certificate issues.
echo.

set GRADLE_URL=https://services.gradle.org/distributions/gradle-8.0-all.zip
set GRADLE_HOME=%USERPROFILE%\.gradle\wrapper\dists

echo Step 1: Let Gradle create the directory structure...
echo Running flutter run once to generate the hash directory...
echo.
flutter run 2>&1 | findstr /C:"gradle-8.0" >nul
if %ERRORLEVEL% EQU 0 (
    echo Directory structure created.
) else (
    echo Note: This may fail, but it will create the directory structure we need.
)
echo.

echo Step 2: Please download Gradle manually:
echo.
echo 1. Open your web browser
echo 2. Visit: %GRADLE_URL%
echo 3. Download the file (gradle-8.0-all.zip)
echo 4. Save it to: %TEMP%\gradle-8.0-all.zip
echo.
pause

if not exist "%TEMP%\gradle-8.0-all.zip" (
    echo.
    echo ERROR: File not found at %TEMP%\gradle-8.0-all.zip
    echo Please download the file and run this script again.
    pause
    exit /b 1
)

echo.
echo Step 3: Finding Gradle installation directory...
echo.

REM Try to find the hash directory
for /d %%d in ("%GRADLE_HOME%\gradle-8.0-all\*") do (
    if exist "%%d\gradle-8.0" (
        set TARGET_DIR=%%d\gradle-8.0
        goto :found
    )
)

REM If not found, create a new one
echo Hash directory not found. Creating new directory...
set TARGET_DIR=%GRADLE_HOME%\gradle-8.0-all\temp\gradle-8.0
mkdir "%TARGET_DIR%" 2>nul

:found
echo.
echo Step 4: Extracting Gradle to: %TARGET_DIR%
echo.

REM Extract using PowerShell
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%TEMP%\gradle-8.0-all.zip', '%TEMP%\gradle-extract')"

REM Find and copy gradle-8.0 directory
for /d %%d in ("%TEMP%\gradle-extract\*") do (
    if "%%~nxd"=="gradle-8.0" (
        echo Copying Gradle files...
        xcopy "%%d\*" "%TARGET_DIR%\" /E /I /Y >nul
        goto :copied
    )
)

:copied
echo.
echo Step 5: Cleaning up...
del "%TEMP%\gradle-8.0-all.zip" 2>nul
rmdir /s /q "%TEMP%\gradle-extract" 2>nul

echo.
echo ========================================
echo Gradle installation complete!
echo ========================================
echo.
echo You can now run: flutter run
echo.
pause
