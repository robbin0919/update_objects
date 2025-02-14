@echo off
for /f "tokens=1,2 delims==" %%a in (config.ini) do (
    set "%%a=%%b"
)