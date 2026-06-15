@echo off
REM Launcher so you can double-click or run generate.ps1 without changing
REM PowerShell's execution policy. Forwards any arguments through.
REM
REM   generate.bat                 -> renders every name in names.txt
REM   generate.bat "Anna" "Jörg"   -> one STL per name (use names.txt for umlauts)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate.ps1" %*
