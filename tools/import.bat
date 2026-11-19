@echo off
rem Imports KTBT's new or changed art and fonts, as the Godot editor does when it opens (so the
rem game and the tests see art redrawn outside the editor), then closes. Double-click it; VS Code's
rem "Import art and fonts" task runs it with --no-pause before the tests and playing.
rem Godot's own path: set GODOT, or put it in tools\godot_path.txt (not in git: it's this PC's own).
rem Uses Godot's console build beside it, if there is one, so what it says shows here.
setlocal
if "%GODOT%"=="" if exist "%~dp0godot_path.txt" set /p GODOT=<"%~dp0godot_path.txt"
if "%GODOT%"=="" goto no_godot
for %%F in ("%GODOT%") do set CONSOLE=%%~dpnF_console%%~xF
if exist "%CONSOLE%" set GODOT=%CONSOLE%
rem Everything it says also goes in logs\import.log (newest at the end), with when it started and
rem finished: if it ever hangs, the log shows where.
if not exist "%~dp0..\logs" mkdir "%~dp0..\logs"
set LOG=%~dp0..\logs\import.log
echo Importing KTBT's art and fonts...
echo ==== Import started %DATE% %TIME% with %GODOT% >> "%LOG%"
powershell -NoProfile -Command "& $env:GODOT --headless --path '%~dp0..' --import 2>&1 | ForEach-Object { $line = [string]$_; $line; Add-Content -Path $env:LOG -Value $line }; exit $LASTEXITCODE"
set RESULT=%ERRORLEVEL%
echo ==== Import finished %DATE% %TIME% (Godot's exit code %RESULT%) >> "%LOG%"
echo Done (Godot finished with %RESULT%; the log's in logs\import.log).
if not "%~1"=="--no-pause" pause
exit /b 0

:no_godot
echo Where's Godot? Put the full path of its .exe in tools\godot_path.txt, on one line.
if not "%~1"=="--no-pause" pause
exit /b 1
