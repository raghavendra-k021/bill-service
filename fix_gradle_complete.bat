@echo off
REM Complete fix for Gradle wrapper - removes locks and creates proper markers

echo ========================================
echo Complete Gradle Fix
echo ========================================
echo.

set GRADLE_PATH=%USERPROFILE%\.gradle\wrapper\dists\gradle-8.0-all\a2o1xoguejy6msdh0lk99lxza

echo IMPORTANT: Close all Flutter/Android Studio/Java processes first!
echo Press any key when ready...
pause >nul

echo.
echo Step 1: Killing any remaining Java processes...
taskkill /F /IM java.exe /T >nul 2>&1
timeout /t 2 /nobreak >nul

echo.
echo Step 2: Removing lock and partial files...
if exist "%GRADLE_PATH%\gradle-8.0-all.zip.lck" (
    del /F /Q "%GRADLE_PATH%\gradle-8.0-all.zip.lck" 2>nul && echo   Removed .lck file || echo   Could not remove .lck (may need admin)
)
if exist "%GRADLE_PATH%\gradle-8.0-all.zip.part" (
    del /F /Q "%GRADLE_PATH%\gradle-8.0-all.zip.part" 2>nul && echo   Removed .part file || echo   Could not remove .part
)

echo.
echo Step 3: Creating completion markers...
REM Create the .ok marker file that Gradle wrapper checks for
echo. > "%GRADLE_PATH%\gradle-8.0-all.zip.ok" 2>nul && echo   Created .ok marker file || echo   Could not create .ok file

REM Also create a dummy zip file (Gradle checks for this too)
if not exist "%GRADLE_PATH%\gradle-8.0-all.zip" (
    echo. > "%GRADLE_PATH%\gradle-8.0-all.zip" 2>nul && echo   Created zip marker || echo   Could not create zip marker
)

echo.
echo Step 4: Verifying...
if exist "%GRADLE_PATH%\gradle-8.0\bin\gradle.bat" (
    echo   Gradle installation: OK
    if exist "%GRADLE_PATH%\gradle-8.0-all.zip.ok" (
        echo   Completion marker: OK
        echo.
        echo ========================================
        echo Fix complete! Try running: flutter run
        echo ========================================
    ) else (
        echo   WARNING: Completion marker not created
    )
) else (
    echo   ERROR: Gradle not found!
    pause
    exit /b 1
)

echo.
pause
