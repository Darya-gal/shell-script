@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

set "MAIN_SCRIPT=skript1_win.bat"
set "ROOT=test_folder"
set "LOG=%ROOT%\log"
set "BACKUP=%ROOT%\backup"
set /a PASSED=0
set /a FAILED=0

echo ===== AUTO TESTS FOR %MAIN_SCRIPT% =====
echo.
goto :main

:: ===== helper: create file of given size in MB (≥0.5MB requirement) =====
:makefile
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
for %%P in ("%~1") do if not exist "%%~dpP" mkdir "%%~dpP" >nul 2>&1
powershell -NoProfile -Command ^
  "$sizeMB = %~2; $bytes = New-Object byte[] ($sizeMB * 1MB); [IO.File]::WriteAllBytes('%~1',$bytes)" >nul 2>&1
exit /b 0
:: =======================================================================

:main

REM === TEST 1: below limit ===
echo [TEST 1] Below LIMIT - should NOT archive
rmdir /s /q "%ROOT%" >nul 2>&1
mkdir "%LOG%" >nul 2>&1
mkdir "%BACKUP%" >nul 2>&1
call :makefile "%LOG%\t1_1.log" 10
call :makefile "%LOG%\t1_2.log" 10
call "%MAIN_SCRIPT%" "%LOG%" 70 100 "%BACKUP%"
for /f %%A in ('dir /b "%BACKUP%\*.zip" 2^>nul ^| find /c /v ""') do set /a CNT=%%A
if !CNT! EQU 0 (echo ✓ TEST 1 PASSED & set /a PASSED+=1) else (echo ✗ TEST 1 FAILED & set /a FAILED+=1)
echo.

REM === TEST 2: above limit ===
echo [TEST 2] Above LIMIT - should archive
rmdir /s /q "%ROOT%" >nul 2>&1
mkdir "%LOG%" >nul 2>&1
mkdir "%BACKUP%" >nul 2>&1
call :makefile "%LOG%\t2_1.log" 60
call :makefile "%LOG%\t2_2.log" 60
call :makefile "%LOG%\t2_3.log" 60
call "%MAIN_SCRIPT%" "%LOG%" 70 100 "%BACKUP%"
for /f %%A in ('dir /b "%BACKUP%\*.zip" 2^>nul ^| find /c /v ""') do set /a CNT=%%A
if !CNT! GEQ 1 (echo ✓ TEST 2 PASSED & set /a PASSED+=1) else (echo ✗ TEST 2 FAILED & set /a FAILED+=1)
echo.

REM === TEST 3: around 70% threshold ===
echo [TEST 3] Around 70%% threshold
rmdir /s /q "%ROOT%" >nul 2>&1
mkdir "%LOG%" >nul 2>&1
mkdir "%BACKUP%" >nul 2>&1
call :makefile "%LOG%\t3_1.log" 40
call :makefile "%LOG%\t3_2.log" 35
call "%MAIN_SCRIPT%" "%LOG%" 70 100 "%BACKUP%"
for /f %%A in ('dir /b "%BACKUP%\*.zip" 2^>nul ^| find /c /v ""') do set /a CNT=%%A
if !CNT! GEQ 1 (echo ✓ TEST 3 PASSED & set /a PASSED+=1) else (echo ✗ TEST 3 FAILED & set /a FAILED+=1)
echo.

REM === TEST 4: auto-create backup folder ===
echo [TEST 4] BACKUP folder auto-create
rmdir /s /q "%ROOT%" >nul 2>&1
mkdir "%LOG%" >nul 2>&1
call :makefile "%LOG%\t4_1.log" 10
call "%MAIN_SCRIPT%" "%LOG%" 70 100 "%BACKUP%"
if exist "%BACKUP%" (echo ✓ TEST 4 PASSED & set /a PASSED+=1) else (echo ✗ TEST 4 FAILED & set /a FAILED+=1)
echo.

REM === TEST 5: LAB1_MAX_COMPRESSION variable ===
echo [TEST 5] LAB1_MAX_COMPRESSION=1 variable test
rmdir /s /q "%ROOT%" >nul 2>&1
mkdir "%LOG%" >nul 2>&1
mkdir "%BACKUP%" >nul 2>&1
call :makefile "%LOG%\t5_1.log" 80
call :makefile "%LOG%\t5_2.log" 80
set "LAB1_MAX_COMPRESSION=1"
call "%MAIN_SCRIPT%" "%LOG%" 70 100 "%BACKUP%"
set "LAB1_MAX_COMPRESSION="
for /f %%A in ('dir /b "%BACKUP%\*.zip" 2^>nul ^| find /c /v ""') do set /a CNT=%%A
if !CNT! GEQ 1 (echo ✓ TEST 5 PASSED & set /a PASSED+=1) else (echo ✗ TEST 5 FAILED & set /a FAILED+=1)
echo.

echo ===== FINAL SUMMARY =====
echo PASSED: !PASSED!
echo FAILED: !FAILED!
echo.
pause
exit /b 0