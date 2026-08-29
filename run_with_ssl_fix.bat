@echo off
REM Helper script to run Flutter with SSL certificate fix for Gradle
REM This script disables SSL certificate verification for Gradle wrapper downloads

REM Set environment variables to disable SSL verification (development only)
set GRADLE_OPTS=-Dcom.sun.net.ssl.checkRevocation=false
set JAVA_OPTS=-Dcom.sun.net.ssl.checkRevocation=false

REM Run Flutter
flutter run
