@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM === Arguments ===
set "LOG=%~1"
set "LIMIT=%~2"
if not defined LIMIT set "LIMIT=70"
set "MAX=%~3"
if not defined MAX set "MAX=500"
set "BACKUP=%~4"
if not defined BACKUP set "BACKUP=backup"

REM === Convert relative paths to absolute ===
for %%I in ("%LOG%") do set "LOG=%%~fI"
for %%I in ("%BACKUP%") do set "BACKUP=%%~fI"

REM === Check arguments ===
if not defined LOG (
  echo Log folder not specified!
  echo Usage: skript1_win.bat ^<log_folder^> [limit%%] [max_size_MB] [backup_folder]
  exit /b 1
)

if not exist "%LOG%\" (
  echo Error: log folder "%LOG%" does not exist!
  exit /b 1
)

if not exist "%BACKUP%\" mkdir "%BACKUP%"

REM === Calculate log folder size in MB ===
for /f %%S in ('powershell -NoProfile -Command "(Get-ChildItem -LiteralPath \"%LOG%\" -Recurse -File | Measure-Object -Sum Length).Sum / 1MB -as [int]"') do set "SIZE=%%S"
if not defined SIZE set "SIZE=0"

set /a PERCENT=100*SIZE/MAX

echo Log folder: %LOG%
echo Current size: %SIZE% MB (%PERCENT%%% of %MAX% MB)
echo Limit: %LIMIT%%%

if %PERCENT% LSS %LIMIT% (
  echo Archiving is not required.
  exit /b 0
)

echo Folder usage: %PERCENT%%% (limit %LIMIT%%). Archiving required.

REM === Select oldest files ===
set "TMP=%TEMP%\to_archive_list.txt"
del /f /q "%TMP%" >nul 2>&1

powershell -NoProfile -Command ^
  "$Log = '%LOG%';" ^
  "$Max = %MAX%;" ^
  "$Limit = %LIMIT%;" ^
  "$sizeMB = %SIZE%;" ^
  "$items = Get-ChildItem -LiteralPath $Log -File | Sort-Object LastWriteTime;" ^
  "$freed = 0;" ^
  "$outFile = '%TMP%';" ^
  "Remove-Item -ErrorAction SilentlyContinue $outFile;" ^
  "foreach($i in $items){" ^
  "  $s = [math]::Floor($i.Length/1MB); if($s -le 0){$s = 1}" ^
  "  $freed += $s;" ^
  "  $newPercent = [math]::Floor(100*([int]$sizeMB - $freed)/$Max);" ^
  "  Add-Content -LiteralPath $outFile -Value $i.FullName;" ^
  "  if($newPercent -lt $Limit){ break }" ^
  "}"

if not exist "%TMP%" (
  echo No suitable files found for archiving.
  exit /b 0
)

for /f %%A in ('type "%TMP%" ^| find /c /v ""') do set COUNT=%%A
if "%COUNT%"=="0" (
  echo No suitable files found for archiving.
  del /q "%TMP%" >nul 2>&1
  exit /b 0
)

echo Files to be archived:
type "%TMP%"

REM === Archive file name with timestamp ===
for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%T"
set "ARCHIVE=%BACKUP%\archive_%TS%.zip"

REM === Create ZIP archive ===
powershell -NoProfile -Command ^
  "$paths = Get-Content -LiteralPath '%TMP%';" ^
  "if(-not $paths -or $paths.Count -eq 0){ exit 2 }" ^
  "Compress-Archive -LiteralPath $paths -DestinationPath '%ARCHIVE%' -Force"

if errorlevel 1 (
  echo Error: failed to create archive "%ARCHIVE%".
  del /q "%TMP%" >nul 2>&1
  exit /b 2
)

echo Archive created: %ARCHIVE%

REM === Delete archived files ===
echo Deleting archived files...
for /f "usebackq delims=" %%F in ("%TMP%") do (
  del /f /q "%%~F"
)
del /q "%TMP%" >nul 2>&1
echo Deletion completed.

REM === Final size ===
for /f %%S in ('powershell -NoProfile -Command "(Get-ChildItem -LiteralPath \"%LOG%\" -Recurse -File | Measure-Object -Sum Length).Sum / 1MB -as [int]"') do set "NEW_SIZE=%%S"
if not defined NEW_SIZE set "NEW_SIZE=0"
set /a NEW_PERCENT=100*NEW_SIZE/MAX

echo New size: %NEW_SIZE% MB (%NEW_PERCENT%%% of %MAX% MB)
echo Archiving completed.
exit /b 0