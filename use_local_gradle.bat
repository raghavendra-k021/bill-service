@echo off
REM Script to configure Gradle to use local installation and bypass download

echo Configuring Gradle to use local installation...
echo.

REM Set environment variable to use local Gradle
set GRADLE_USER_HOME=%USERPROFILE%\.gradle
set GRADLE_OPTS=-Dgradle.user.home=%USERPROFILE%\.gradle

REM Set JAVA_OPTS to disable SSL checks
set JAVA_OPTS=-Dcom.sun.net.ssl.checkRevocation=false

echo Environment variables set:
echo   GRADLE_USER_HOME=%GRADLE_USER_HOME%
echo   GRADLE_OPTS=%GRADLE_OPTS%
echo   JAVA_OPTS=%JAVA_OPTS%
echo.

echo Now running Flutter...
echo.

REM Run Flutter with the environment
flutter run
