@echo off
REM 
REM This script parses a heap dump.
REM
REM Usage: ParseHeapDump.bat <path/to/dump.hprof> [report]*
REM 
REM The leak report has the id org.eclipse.mat.api:suspects
REM 

set _DIRNAME=.\
if "%OS%" == "Windows_NT" set _DIRNAME=%~dp0%

"%_DIRNAME%\eclipsec.exe" --launcher.ini "%_DIRNAME%\MemoryAnalyzer.ini" -consoleLog -nosplash -application org.eclipse.mat.api.parse %*
