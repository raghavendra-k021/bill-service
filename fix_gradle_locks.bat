@echo off
REM Script to remove Gradle lock files by closing processes and cleaning up

echo ========================================
echo Fixing Gradle Lock Files
echo ========================================
echo.

set GRADLE_PATH=%USERPROFILE%\.gradle\wrapper\dists\gradle-8.0-all\a2o1xoguejy6msdh0lk99lxza

echo Step 1: Closing any running Java/Gradle processes...
echo.

REM Kill Java processes that might be holding the lock
taskkill /F /IM java.exe /T >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Closed Java processes
) else (
    echo No Java processes found (or already closed)
)

timeout /t 2 /nobreak >nul

echo.
echo Step 2: Removing lock files...
echo.

REM Remove lock file
if exist "%GRADLE_PATH%\gradle-8.0-all.zip.lck" (
    del /F /Q "%GRADLE_PATH%\gradle-8.0-all.zip.lck" 2>nul
    if %ERRORLEVEL% EQU 0 (
        echo Removed lock file
    ) else (
        echo WARNING: Could not remove lock file - may need to close processes manually
    )
) else (
    echo Lock file not found
)

REM Remove partial download file
if exist "%GRADLE_PATH%\gradle-8.0-all.zip.part" (
    del /F /Q "%GRADLE_PATH%\gradle-8.0-all.zip.part" 2>nul
    if %ERRORLEVEL% EQU 0 (
        echo Removed partial download file
    ) else (
        echo WARNING: Could not remove partial file
    )
) else (
    echo Partial file not found
)

echo.
echo Step 3: Creating completion marker...
echo.

REM Create a dummy zip file marker
if not exist "%GRADLE_PATH%\gradle-8.0-all.zip" (
    echo. > "%GRADLE_PATH%\gradle-8.0-all.zip"
    if %ERRORLEVEL% EQU 0 (
        echo Created zip marker file
    ) else (
        echo WARNING: Could not create marker file
    )
) else (
    echo Zip marker already exists
)

echo.
echo Step 4: Verifying Gradle installation...
echo.

if exist "%GRADLE_PATH%\gradle-8.0\bin\gradle.bat" (
    echo Gradle installation verified!
    echo.
    echo ========================================
    echo Lock files fixed!
    echo ========================================
    echo.
    echo You can now run: flutter run
    echo.
) else (
    echo ERROR: Gradle not found at expected location!
    echo Expected: %GRADLE_PATH%\gradle-8.0\bin\gradle.bat
    pause
    exit /b 1
)

pause
