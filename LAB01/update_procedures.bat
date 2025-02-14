@echo off
setlocal EnableDelayedExpansion

REM =================================================
REM Oracle Database Procedure Update Script
REM Author: robbin0919
REM Created: 2025-02-14
REM =================================================

REM 設定時間戳記格式
set "TIMESTAMP=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"

REM 設定記錄檔目錄和檔案
set "LOG_DIR=%~dp0logs"
set "MAIN_LOG=%LOG_DIR%\main_update_%TIMESTAMP%.log"
set "DEBUG_LOG=%LOG_DIR%\debug_%TIMESTAMP%.log"

REM 建立記錄檔目錄
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM 開始記錄
call :LogDebug "==================================================="
call :LogDebug "開始執行程序更新"
call :LogDebug "執行時間: %date% %time%"
call :LogDebug "執行使用者: %USERNAME%"
call :LogDebug "==================================================="

REM 設定Oracle環境變數
set "ORACLE_HOME=C:\oracle\product\19c\client"
set "TNS_ADMIN=%ORACLE_HOME%\network\admin"
set "NLS_LANG=AMERICAN_AMERICA.AL32UTF8"
set "PATH=%ORACLE_HOME%\bin;%PATH%"

REM 設定資料庫連線資訊
set "DB_USER=YOUR_USERNAME"
set "DB_PASS=YOUR_PASSWORD"
set "TNS_ALIAS=YOUR_TNS_ALIAS"
set "DB_CONNECT=%DB_USER%/%DB_PASS%@%TNS_ALIAS%"

call :LogDebug "資料庫連線資訊設定完成"
call :LogDebug "TNS_ADMIN=%TNS_ADMIN%"
call :LogDebug "NLS_LANG=%NLS_LANG%"

REM 設定程序檔案目錄
set "PROC_DIR=%~dp0procedures"
set "TEMP_DIR=%~dp0temp"

REM 建立暫存目錄
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM 檢查程序目錄
if not exist "%PROC_DIR%" (
    call :LogError "找不到程序目錄: %PROC_DIR%"
    goto :ERROR
)

call :LogDebug "檢查程序目錄成功: %PROC_DIR%"

REM 建立執行記錄表
call :LogDebug "開始建立或更新記錄表"
sqlplus -S /nolog > "%TEMP_DIR%\create_table.log" 2>&1 << EOF
CONNECT %DB_CONNECT%
@%~dp0create_log_table.sql
EXIT;
EOF

REM 檢查SQL*Plus是否可用
sqlplus -V > nul 2>&1
if errorlevel 1 (
    call :LogError "找不到 SQL*Plus，請確認 Oracle Client 安裝正確"
    goto :ERROR
)

REM 處理所有SQL檔案
for %%f in ("%PROC_DIR%\*.sql") do (
    call :ProcessSqlFile "%%f"
)

call :LogDebug "所有程序處理完成"
goto :EOF

:ProcessSqlFile
set "SQL_FILE=%~1"
set "FILE_NAME=%~nx1"
set "PROC_LOG=%TEMP_DIR%\%~n1_%TIMESTAMP%.log"

call :LogDebug "開始處理檔案: %FILE_NAME%"
call :LogDebug "完整路徑: %SQL_FILE%"

REM 建立執行腳本
(
    echo SET ECHO ON
    echo SET FEEDBACK ON
    echo SET SERVEROUTPUT ON SIZE 1000000
    echo SET LINESIZE 1000
    echo SET TIMING ON
    echo SPOOL %PROC_LOG%
    echo SHOW USER;
    echo SELECT sys_context('USERENV','DB_NAME'^) FROM dual;
    echo.
    type "%SQL_FILE%"
    echo.
    echo SHOW ERRORS;
    echo SPOOL OFF
    echo EXIT SUCCESS;
) > "%TEMP_DIR%\exec_%~n1.sql"

REM 執行程序
call :LogDebug "執行 SQL 檔案..."
sqlplus -S %DB_CONNECT% @"%TEMP_DIR%\exec_%~n1.sql" >> "%DEBUG_LOG%" 2>&1

if errorlevel 1 (
    call :LogError "執行失敗: %FILE_NAME%"
    call :LogError "詳細記錄請查看: %PROC_LOG%"
    
    REM 記錄失敗到資料庫
    sqlplus -S %DB_CONNECT% @log_execution.sql "%FILE_NAME%" "1" "%USERNAME%" >> "%DEBUG_LOG%" 2>&1
) else (
    call :LogDebug "執行成功: %FILE_NAME%"
    
    REM 記錄成功到資料庫
    sqlplus -S %DB_CONNECT% @log_execution.sql "%FILE_NAME%" "0" "%USERNAME%" >> "%DEBUG_LOG%" 2>&1
)

REM 分析執行記錄中的錯誤
findstr /I "ORA- SP2- PLS-" "%PROC_LOG%" >> "%DEBUG_LOG%"

goto :EOF

:LogDebug
echo [%date% %time%] DEBUG: %~1 >> "%DEBUG_LOG%"
goto :EOF

:LogError
echo [%date% %time%] ERROR: %~1 >> "%DEBUG_LOG%"
echo [%date% %time%] ERROR: %~1 >> "%MAIN_LOG%"
goto :EOF

:ERROR
call :LogError "批次處理過程中發生錯誤"
exit /b 1