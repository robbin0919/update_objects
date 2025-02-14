-- 記錄執行結果（包含更多詳細資訊）
DECLARE
    v_log_id NUMBER;
    v_error_info CLOB;
    v_debug_info CLOB;
    v_exec_time NUMBER;
BEGIN
    -- 獲取錯誤資訊（如果有的話）
    SELECT LISTAGG(LINE, CHR(10)) WITHIN GROUP (ORDER BY LINE)
    INTO v_error_info
    FROM USER_ERRORS
    WHERE NAME = UPPER(SUBSTR('&1', 1, INSTR('&1', '.') - 1))
    AND TYPE = 'PROCEDURE';

    -- 計算執行時間（從 V$SQL）
    SELECT NVL(ELAPSED_TIME/1000000, 0)
    INTO v_exec_time
    FROM V$SQL
    WHERE SQL_TEXT LIKE '%' || UPPER(SUBSTR('&1', 1, INSTR('&1', '.') - 1)) || '%'
    AND ROWNUM = 1;

    -- 插入主記錄
    INSERT INTO PROCEDURE_UPDATE_LOG (
        PROCEDURE_NAME,
        STATUS,
        UPDATED_BY,
        ERROR_MESSAGE,
        EXECUTION_TIME,
        DEBUG_INFO
    ) VALUES (
        '&1',
        &2,
        '&3',
        v_error_info,
        v_exec_time,
        v_debug_info
    ) RETURNING LOG_ID INTO v_log_id;

    -- 插入詳細記錄
    INSERT INTO PROCEDURE_UPDATE_DETAIL_LOG (
        LOG_ID,
        STEP_NAME,
        STEP_STATUS,
        START_TIME,
        END_TIME,
        ELAPSED_TIME,
        MESSAGE
    ) VALUES (
        v_log_id,
        '執行程序',
        CASE &2 WHEN 0 THEN 'SUCCESS' ELSE 'FAILED' END,
        SYSTIMESTAMP - NUMTODSINTERVAL(v_exec_time, 'SECOND'),
        SYSTIMESTAMP,
        v_exec_time,
        '執行者: &3'
    );

    COMMIT;
END;
/