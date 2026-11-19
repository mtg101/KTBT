@echo off
rem Imports KTBT's new or changed art and fonts, as the Godot editor does when it opens (so the
rem game and the tests see art redrawn outside the editor), then closes. Double-click it.
rem Godot's own path: set GODOT, or put it in tools\godot_path.txt (not in git: it's this PC's own).
setlocal
if "%GODOT%"=="" if exist "%~dp0godot_path.txt" set /p GODOT=<"%~dp0godot_path.txt"
if "%GODOT%"=="" goto no_godot
echo Importing KTBT's art and fonts...
"%GODOT%" --headless --path "%~dp0.." --import
echo Done.
pause
exit /b 0

:no_godot
echo Where's Godot? Put the full path of its .exe in tools\godot_path.txt, on one line.
pause
exit /b 1
