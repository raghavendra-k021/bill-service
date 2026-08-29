@echo off
REM Script to install manually downloaded Gradle 8.0 to the correct location

echo ========================================
echo Gradle 8.0 Installation
echo ========================================
echo.

set GRADLE_HASH=a2o1xoguejy6msdh0lk99lxza
set TARGET_DIR=%USERPROFILE%\.gradle\wrapper\dists\gradle-8.0-all\%GRADLE_HASH%\gradle-8.0

echo Target directory: %TARGET_DIR%
echo.

REM Check if already installed
if exist "%TARGET_DIR%\bin\gradle.bat" (
    echo Gradle appears to be already installed.
    echo.
    set /p REINSTALL="Do you want to reinstall? (y/n): "
    if /i not "%REINSTALL%"=="y" (
        echo Installation cancelled.
        exit /b 0
    )
)

echo Step 1: Finding your downloaded gradle-8.0-all.zip file...
echo.

REM Check common locations
set ZIP_FILE=
if exist "%USERPROFILE%\Downloads\gradle-8.0-all.zip" (
    set ZIP_FILE=%USERPROFILE%\Downloads\gradle-8.0-all.zip
    goto :found
)
if exist "%TEMP%\gradle-8.0-all.zip" (
    set ZIP_FILE=%TEMP%\gradle-8.0-all.zip
    goto :found
)
if exist "%USERPROFILE%\Desktop\gradle-8.0-all.zip" (
    set ZIP_FILE=%USERPROFILE%\Desktop\gradle-8.0-all.zip
    goto :found
)
if exist "gradle-8.0-all.zip" (
    set ZIP_FILE=gradle-8.0-all.zip
    goto :found
)

:notfound
echo Zip file not found in common locations.
echo.
set /p ZIP_FILE="Please enter the full path to gradle-8.0-all.zip: "
if not exist "%ZIP_FILE%" (
    echo ERROR: File not found: %ZIP_FILE%
    pause
    exit /b 1
)

:found
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

REM Find gradle-8.0 directory
for /d %%d in ("%EXTRACT_TEMP%\*") do (
    if "%%~nxd"=="gradle-8.0" (
        set GRADLE_SOURCE=%%d
        goto :copy
    )
)

echo ERROR: Could not find gradle-8.0 directory in extracted files!
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
    echo Gradle installed successfully!
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
