@echo off
setlocal

REM Set the directory containing the PROCEDURE and TRIGGER scripts
set SCRIPT_DIR=C:\path\to\scripts

REM Set Oracle database connection details
set ORACLE_SID=your_sid
set ORACLE_USER=your_username
set ORACLE_PASSWORD=your_password

REM Loop through all .sql files in the script directory
for %%f in (%SCRIPT_DIR%\*.sql) do (
    echo Executing script: %%f
    sqlplus %ORACLE_USER%/%ORACLE_PASSWORD%@%ORACLE_SID% @%%f
)

endlocal
