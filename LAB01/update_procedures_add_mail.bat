@echo off
setlocal EnableDelayedExpansion

REM =================================================
REM Oracle Database Procedure Update Script
REM Author: robbin0919
REM Last Updated: 2025-02-14
REM =================================================

REM 設定電子郵件參數
set "SMTP_SERVER=your.smtp.server"
set "SMTP_PORT=587"
set "MAIL_FROM=sender@yourdomain.com"
set "MAIL_TO=recipient@yourdomain.com"
set "MAIL_CC=cc_recipient@yourdomain.com"
set "MAIL_USER=your_email_username"
set "MAIL_PASSWORD=your_email_password"

REM 設定時間戳記格式
set "TIMESTAMP=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"

REM 設定記錄檔目錄和檔案
set "LOG_DIR=%~dp0logs"
set "MAIN_LOG=%LOG_DIR%\main_update_%TIMESTAMP%.log"
set "DEBUG_LOG=%LOG_DIR%\debug_%TIMESTAMP%.log"
set "EMAIL_BODY=%TEMP_DIR%\email_body_%TIMESTAMP%.txt"

REM [前面的程式碼保持不變...]

REM 在最後加入發送郵件的部分
:SendEmailNotification
call :LogDebug "準備發送電子郵件通知"

REM 準備郵件內容
(
    echo 程序更新執行報告
    echo ===================================
    echo.
    echo 執行時間: %date% %time%
    echo 執行者: %USERNAME%
    echo.
    echo 更新摘要:
    echo -----------------------------------
) > "%EMAIL_BODY%"

REM 加入執行統計
sqlplus -S %DB_CONNECT% << EOF >> "%EMAIL_BODY%"
SET PAGESIZE 1000
SET LINESIZE 100
SET FEEDBACK OFF
SET VERIFY OFF

SELECT '總執行程序數: ' || COUNT(*) || CHR(10) ||
       '成功數: ' || SUM(CASE WHEN STATUS = 0 THEN 1 ELSE 0 END) || CHR(10) ||
       '失敗數: ' || SUM(CASE WHEN STATUS = 1 THEN 1 ELSE 0 END) || CHR(10) ||
       '總執行時間: ' || ROUND(SUM(EXECUTION_TIME)/60,2) || ' 分鐘'
FROM PROCEDURE_UPDATE_LOG
WHERE TRUNC(EXECUTION_DATE) = TRUNC(SYSDATE);

SELECT CHR(10) || '失敗的程序清單:' || CHR(10) ||
       LISTAGG(PROCEDURE_NAME || ' - ' || ERROR_MESSAGE, CHR(10)) WITHIN GROUP (ORDER BY EXECUTION_DATE)
FROM PROCEDURE_UPDATE_LOG
WHERE TRUNC(EXECUTION_DATE) = TRUNC(SYSDATE)
AND STATUS = 1;

EXIT;
EOF

REM 使用 PowerShell 發送郵件
powershell -Command ^
    "$ErrorActionPreference = 'Stop'; ^
     $SMTPServer = '%SMTP_SERVER%'; ^
     $SMTPPort = %SMTP_PORT%; ^
     $Username = '%MAIL_USER%'; ^
     $Password = '%MAIL_PASSWORD%'; ^
     $Subject = 'Oracle程序更新報告 - %date%'; ^
     $Body = Get-Content -Path '%EMAIL_BODY%' -Raw; ^
     $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force; ^
     $Credential = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword); ^
     $From = '%MAIL_FROM%'; ^
     $To = '%MAIL_TO%'.Split(','); ^
     $Cc = '%MAIL_CC%'.Split(','); ^
     $Attachments = @('%MAIN_LOG%', '%DEBUG_LOG%'); ^
     $MailParams = @{ ^
         SmtpServer = $SMTPServer; ^
         Port = $SMTPPort; ^
         UseSsl = $true; ^
         Credential = $Credential; ^
         From = $From; ^
         To = $To; ^
         Cc = $Cc; ^
         Subject = $Subject; ^
         Body = $Body; ^
         Attachments = $Attachments; ^
     }; ^
     Send-MailMessage @MailParams; ^
     Write-Host 'Email sent successfully'" >> "%DEBUG_LOG%" 2>&1

if errorlevel 1 (
    call :LogError "發送電子郵件時發生錯誤"
) else (
    call :LogDebug "電子郵件發送成功"
)

REM 清理暫存檔
del "%EMAIL_BODY%" 2>nul

goto :EOF

REM [其他函數保持不變...]