@echo off
rem Autoplay: a batch of KTBT nights that play themselves, with the real AI (see scripts\autoplay.gd).
rem Double-click for 10 nights; or "autoplay.bat 5" for 5; or "autoplay.bat 5 <bar id>" to carry on that bar.
rem Needs Ollama running. Godot's own path: set GODOT, or put it in tools\godot_path.txt
rem (not in git: it's this PC's own). The _console .exe shows the log as it goes.
setlocal
set NIGHTS=%~1
if "%NIGHTS%"=="" set NIGHTS=10
set BAR=
if not "%~2"=="" set BAR=--autoplay-bar=%~2
if "%GODOT%"=="" if exist "%~dp0godot_path.txt" set /p GODOT=<"%~dp0godot_path.txt"
if "%GODOT%"=="" goto no_godot
echo Autoplay: %NIGHTS% nights. Each night's stats and transcript go in logs, and the batch's summary in logs\autoplay.
"%GODOT%" --path "%~dp0.." --audio-driver Dummy -- --autoplay=%NIGHTS% %BAR%
echo Autoplay finished: the summary's in logs\autoplay.
pause
exit /b 0

:no_godot
echo Where's Godot? Put the full path of its .exe in tools\godot_path.txt, on one line.
pause
exit /b 1
