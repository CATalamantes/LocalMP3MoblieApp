@echo off
rem Execution policy applies only to this child process; no system policy is changed.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\run_test_music.ps1" %*
