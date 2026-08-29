@echo off
REM Auto-detect Gradle version and install script

echo ========================================
echo Gradle Auto-Installation Script
echo ========================================
echo.

REM Read Gradle version from wrapper properties
for /f "tokens=2 delims==" %%a in ('findstr "distributionUrl" android\gradle\wrapper\gradle-wrapper.properties') do (
    set DIST_URL=%%a
)

REM Extract version from URL (e.g., gradle-8.9-all.zip)
for /f "tokens=2 delims=-" %%a in ("%DIST_URL%") do (
    set GRADLE_VERSION=%%a
)
for /f "tokens=3 delims=-" %%a in ("%DIST_URL%") do (
    set GRADLE_TYPE=%%a
)

echo Detected Gradle version: %GRADLE_VERSION%
echo Distribution type: %GRADLE_TYPE%
echo.

REM Check if hash directory exists
set GRADLE_BASE=%USERPROFILE%\.gradle\wrapper\dists\gradle-%GRADLE_VERSION%-%GRADLE_TYPE%

if exist "%GRADLE_BASE%" (
    echo Finding hash directory...
    for /d %%d in ("%GRADLE_BASE%\*") do (
        set GRADLE_HASH=%%~nxd
        set TARGET_DIR=%%d\gradle-%GRADLE_VERSION%
        goto :found
    )
)

:notfound
echo Hash directory not found. Gradle will create it on first run.
echo.
echo Please run this command once to create the directory:
echo   cd android
echo   .\gradlew --version
echo.
echo This will fail with SSL error, but will create the hash directory.
echo Then run this script again.
pause
exit /b 1

:found
echo Found hash directory: %GRADLE_HASH%
echo Target directory: %TARGET_DIR%
echo.

REM Check if already installed
if exist "%TARGET_DIR%\bin\gradle.bat" (
    echo Gradle %GRADLE_VERSION% appears to be already installed.
    echo.
    set /p REINSTALL="Do you want to reinstall? (y/n): "
    if /i not "%REINSTALL%"=="y" (
        echo Installation cancelled.
        exit /b 0
    )
)

echo Step 1: Finding your downloaded gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip file...
echo.

REM Check common locations
set ZIP_FILE=
if exist "%USERPROFILE%\Downloads\gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip" (
    set ZIP_FILE=%USERPROFILE%\Downloads\gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip
    goto :foundzip
)
if exist "%TEMP%\gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip" (
    set ZIP_FILE=%TEMP%\gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip
    goto :foundzip
)
if exist "%USERPROFILE%\Desktop\gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip" (
    set ZIP_FILE=%USERPROFILE%\Desktop\gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip
    goto :foundzip
)
if exist "gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip" (
    set ZIP_FILE=gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip
    goto :foundzip
)

:notfoundzip
echo Zip file not found in common locations.
echo.
set /p ZIP_FILE="Please enter the full path to gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip: "
if not exist "%ZIP_FILE%" (
    echo ERROR: File not found: %ZIP_FILE%
    echo.
    echo Please download from: https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-%GRADLE_TYPE%.zip
    pause
    exit /b 1
)

:foundzip
echo Found zip file: %ZIP_FILE%
echo.

echo Step 2: Extracting Gradle...
echo.

REM Create temp extraction directory
set EXTRACT_TEMP=%TEMP%\gradle-extract-%RANDOM%
if exist "%EXTRACT_TEMP%" rmdir /s /q "%EXTRACT_TEMP%"
mkdir "%EXTRACT_TEMP%"

REM Extract using PowerShell
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%ZIP_FILE%', '%EXTRACT_TEMP%')"

if errorlevel 1 (
    echo ERROR: Extraction failed!
    pause
    exit /b 1
)

echo Extraction complete!
echo.

echo Step 3: Installing to target location...
echo.

REM Find gradle-X.X directory
for /d %%d in ("%EXTRACT_TEMP%\*") do (
    if "%%~nxd"=="gradle-%GRADLE_VERSION%" (
        set GRADLE_SOURCE=%%d
        goto :copy
    )
)

echo ERROR: Could not find gradle-%GRADLE_VERSION% directory in extracted files!
echo Contents:
dir /b "%EXTRACT_TEMP%"
rmdir /s /q "%EXTRACT_TEMP%"
pause
exit /b 1

:copy
REM Create target directory
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

REM Copy files
echo Copying files to: %TARGET_DIR%
xcopy "%GRADLE_SOURCE%\*" "%TARGET_DIR%\" /E /I /Y /Q

if errorlevel 1 (
    echo ERROR: Copy failed!
    rmdir /s /q "%EXTRACT_TEMP%"
    pause
    exit /b 1
)

echo.
echo Step 4: Verifying installation...
echo.

if exist "%TARGET_DIR%\bin\gradle.bat" (
    echo.
    echo ========================================
    echo Gradle %GRADLE_VERSION% installed successfully!
    echo ========================================
    echo.
    echo Location: %TARGET_DIR%
    echo.
    echo You can now run: flutter run
    echo.
) else (
    echo ERROR: Installation verification failed!
    echo Expected file not found: %TARGET_DIR%\bin\gradle.bat
    pause
    exit /b 1
)

REM Cleanup
echo Cleaning up...
rmdir /s /q "%EXTRACT_TEMP%"

echo.
echo Installation complete!
pause
