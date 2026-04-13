
set term on feed off echo off recsep off space 2 head on pages 9999 veri off newpage 0
set markup html on spool on entmap off
set echo off

COL db_name NEW_VALUE print_db_name
select SYS_CONTEXT('USERENV', 'DB_NAME')||'_'||to_char(sysdate,'ddmmyyyy') db_name from dual;
spool /u01/DB_Healthcheck_Report_&print_db_name..html

prompt **===========================**
prompt ** Database Information **
prompt **===========================**

set pagesize 50
set line 300
col HOST_NAME FORMAT a12
col "HOST_ADDRESS" FORMAT a15
col RESETLOGS_TIME FORMAT a12
col "DB RAC?" FORMAT A8
col days format 9999

select name INSTANCE,HOST_NAME,
LOGINS, archiver,to_char(STARTUP_TIME,'DD-MON-YYYY HH24:MI:SS') "DB_UP_TIME", RESETLOGS_TIME "RESET_TIME", FLOOR(sysdate-startup_time) days,
(select DECODE(vp1.value,'TRUE','Yes ('|| decode(vp1.value,'TRUE',' instances: '||vp2.value)||')','No')
from v$instance,(select value from v$parameter where name like 'cluster_database') vp1,
(select value from v$parameter where name like 'cluster_database_instances') vp2) "DB RAC?" from v$database,gv$instance;

col "Database Size" format a15;
col "Free space" format a15;
select round(sum(used.bytes) / 1024 / 1024/1024 ) || ' GB' "Database Size",
round(free.p / 1024 / 1024/1024) || ' GB' "Free space"
from (select bytes from v$datafile
union all select bytes from v$tempfile
union all select bytes from v$log) used,
(select sum(bytes) as p from dba_free_space) free
group by free.p;

prompt**=============================================**
prompt**   **Tablespace Information**
prompt**=============================================**

set pages 999
set lines 400
SELECT df.tablespace_name tablespace_name,
 max(df.autoextensible) auto_ext,
 round(df.maxbytes / (1024 * 1024 *1024), 2) max_ts_size_gb,
 round(df.bytes / (1024 * 1024 *1024), 2) curr_ts_size_gb,
 round((df.bytes - sum(fs.bytes)) / (1024 * 1024 *1024), 2) used_ts_size_gb,
 round((df.bytes-sum(fs.bytes)) * 100 / df.bytes, 2) ts_pct_used,
 round(sum(fs.bytes) / (1024 * 1024 *1024), 2) free_ts_size_gb,
 nvl(round(sum(fs.bytes) * 100 / df.bytes), 2) ts_pct_free
FROM dba_free_space fs,
 (select tablespace_name,
 sum(bytes) bytes,
 sum(decode(maxbytes, 0, bytes, maxbytes)) maxbytes,
 max(autoextensible) autoextensible
 from dba_data_files
 group by tablespace_name) df
WHERE fs.tablespace_name (+) = df.tablespace_name
GROUP BY df.tablespace_name, df.bytes, df.maxbytes
UNION ALL
SELECT df.tablespace_name tablespace_name,
 max(df.autoextensible) auto_ext,
 round(df.maxbytes / (1024 * 1024 *1024), 2) max_ts_size,
 round(df.bytes / (1024 * 1024 *1024), 2) curr_ts_size,
 round((df.bytes - sum(fs.bytes)) / (1024 * 1024 * 1024), 2) used_ts_size,
 round((df.bytes-sum(fs.bytes)) * 100 / df.bytes, 2) ts_pct_used,
 round(sum(fs.bytes) / (1024 * 1024 *1024), 2) free_ts_size,
 nvl(round(sum(fs.bytes) * 100 / df.bytes), 2) ts_pct_free
FROM (select tablespace_name, bytes_used bytes
 from V$temp_space_header
 group by tablespace_name, bytes_free, bytes_used) fs,
 (select tablespace_name,
 sum(bytes) bytes,
 sum(decode(maxbytes, 0, bytes, maxbytes)) maxbytes,
 max(autoextensible) autoextensible
 from dba_temp_files
 group by tablespace_name) df
WHERE fs.tablespace_name (+) = df.tablespace_name
GROUP BY df.tablespace_name, df.bytes, df.maxbytes
ORDER BY 4 DESC;

prompt**==============================================**
Prompt ****DB GROWTH****
prompt**==============================================**

SET LINESIZE 300
SET PAGESIZE 100
SET WRAP OFF
SET TRIMSPOOL ON
SET VERIFY OFF
SET FEEDBACK OFF
COLUMN "Create Time"           FORMAT A20
COLUMN "Database Name"         FORMAT A12
COLUMN "Database Size"         FORMAT A15
COLUMN "Used Space"            FORMAT A15
COLUMN "Free Space"            FORMAT A15
COLUMN "Used in %"             FORMAT A12
COLUMN "Free in %"             FORMAT A12
COLUMN "Growth DAY"            FORMAT A15
COLUMN "Growth DAY in %"       FORMAT A18
COLUMN "Growth WEEK"           FORMAT A15
COLUMN "Growth WEEK in %"      FORMAT A18
COLUMN "Growth MONTH"          FORMAT A15
COLUMN "Growth MONTH in %"     FORMAT A20
COLUMN "Growth 3 MONTHS"       FORMAT A15
COLUMN "Growth 6 MONTHS"       FORMAT A15
COLUMN "Growth YEAR"           FORMAT A15
SELECT
  (SELECT MIN(creation_time) FROM gv$datafile) AS "Create Time",
  (SELECT name FROM gv$database WHERE ROWNUM = 1) AS "Database Name",
  ROUND(SUM(used.bytes) / 1024 / 1024 / 1024, 2) || ' GB' AS "Database Size",
  ROUND(
        (SUM(used.bytes) / 1024 / 1024 / 1024) -
        (free.p / 1024 / 1024 / 1024), 2
      ) || ' GB' AS "Used Space",
  ROUND(
        (
          (SUM(used.bytes) / 1024 / 1024) -
          (free.p / 1024 / 1024)
        ) /
        (SUM(used.bytes) / 1024 / 1024) * 100, 2
      ) || '%' AS "Used in %",
  ROUND(free.p / 1024 / 1024 / 1024, 2) || ' GB' AS "Free Space",
  ROUND(
        (free.p / 1024 / 1024) /
        (SUM(used.bytes) / 1024 / 1024) * 100, 2
      ) || '%' AS "Free in %",
  /* ---------- DAILY GROWTH (GB) ---------- */
  ROUND(
        (
          (SUM(used.bytes) - free.p) / 1024 / 1024 / 1024
        ) /
        (SELECT SYSDATE - MIN(creation_time) FROM gv$datafile), 2
      ) || ' GB' AS "Growth DAY",
  ROUND(
        (
          (
            (SUM(used.bytes) - free.p) / 1024 / 1024 / 1024
          ) /
          (SELECT SYSDATE - MIN(creation_time) FROM gv$datafile)
        ) /
        (SUM(used.bytes) / 1024 / 1024 / 1024) * 100, 3
      ) || '%' AS "Growth DAY in %",
  /* ---------- WEEKLY GROWTH ---------- */
  ROUND(
        (
          (
            (SUM(used.bytes) - free.p) / 1024 / 1024 / 1024
          ) /
          (SELECT SYSDATE - MIN(creation_time) FROM gv$datafile)
        ) * 7, 2
      ) || ' GB' AS "Growth WEEK",
  ROUND(
        (
          (
            (
              (SUM(used.bytes) - free.p) / 1024 / 1024 / 1024
            ) /
            (SELECT SYSDATE - MIN(creation_time) FROM gv$datafile)
          ) /
          (SUM(used.bytes) / 1024 / 1024 / 1024) * 100
        ) * 7, 3
      ) || '%' AS "Growth WEEK in %",
  /* ---------- MONTHLY GROWTH ---------- */
  ROUND(
        (
          (
            (SUM(used.bytes) - free.p) / 1024 / 1024 / 1024
          ) /
          (SELECT SYSDATE - MIN(creation_time) FROM gv$datafile)
        ) * 30, 2
      ) || ' GB' AS "Growth MONTH",
  ROUND(
        (
          (
            (
              (SUM(used.bytes) - free.p) / 1024 / 1024 / 1024
            ) /
            (SELECT SYSDATE - MIN(creation_time) FROM gv$datafile)
          ) /
          (SUM(used.bytes) / 1024 / 1024 / 1024) * 100
        ) * 30, 3
      ) || '%' AS "Growth MONTH in %",
  /* ---------- 3 / 6 / YEAR ---------- */
  ROUND(
        (
          (
            (SUM(used.bytes) - free.p) / 1024 / 1024 / 1024
          ) /
          (SELECT SYSDATE - MIN(creation_time) FROM gv$datafile)
        ) * 90, 2
      ) || ' GB' AS "Growth 3 MONTHS",
  ROUND(
        (
          (
            (SUM(used.bytes) - free.p) / 1024 / 1024 / 1024
          ) /
          (SELECT SYSDATE - MIN(creation_time) FROM gv$datafile)
        ) * 180, 2
      ) || ' GB' AS "Growth 6 MONTHS",
  ROUND(
        (
          (
            (SUM(used.bytes) - free.p) / 1024 / 1024 / 1024
          ) /
          (SELECT SYSDATE - MIN(creation_time) FROM gv$datafile)
        ) * 365, 2
      ) || ' GB' AS "Growth YEAR"
FROM
  (
    SELECT bytes FROM gv$datafile
    UNION ALL
    SELECT bytes FROM gv$tempfile
    UNION ALL
    SELECT bytes FROM gv$log
  ) used,
  (
    SELECT SUM(bytes) AS p FROM dba_free_space
  ) free
GROUP BY free.p;

prompt**==============================================**
prompt**    **Database Users Activities**
prompt**==============================================**

col USERNAME for a30
col PROFILE for a30
set lines 200 pages 2000
select USERNAME,ACCOUNT_STATUS,EXPIRY_DATE,PROFILE from dba_users where ORACLE_MAINTAINED='N';

select owner,sum(bytes)/1024/1024 schema_size_MB from dba_segments where owner in (select username from dba_users where ORACLE_MAINTAINED='N') group by owner;

PROMPT **========================**
PROMPT ASM STATISTICS
PROMPT **========================**

set lines 141
col free_mb for 999999999999999999
col total_mb for 999999999999999999
select name,state,OFFLINE_DISKS,total_mb,free_mb,ROUND((1-(free_mb / total_mb))*100, 2) "%FULL" from v$asm_diskgroup;

prompt**===========================================**
prompt**    **RMAN Configuration and Backup**
prompt**===========================================**

col "RMAN CONFIGURE PARAMETERS" format a100;
select  'CONFIGURE '||name ||' '|| value "RMAN CONFIGURE PARAMETERS"
from  v$rman_configuration
order by conf#;

set line 200;
col "DEVIC" format a6;
col "L" format 9;
col "FIN:SS" format 9999;

SELECT  DECODE(backup_type, 'L', 'Archived Logs', 'D', 'Datafile Full', 'I', 'Incremental')
 backup_type, bp.tag "RMAN_BACKUP_TAG", device_type "DEVIC", DECODE( bs.controlfile_included, 'NO', null, bs.controlfile_included) controlfile,
 (sp.spfile_included) spfile, sum(bs.incremental_level) "L", TO_CHAR(bs.start_time, 'dd/mm/yyyy HH24:MI:SS') start_time
  , TO_CHAR(bs.completion_time, 'dd/mm/yyyy HH24:MI:SS')  completion_time, sum(bs.elapsed_seconds) "FIN:SS"
FROM v$backup_set  bs,  (select distinct  set_stamp, set_count, tag , device_type
     from v$backup_piece
     where status in ('A', 'X'))  bp,
     (select distinct  set_stamp , set_count , 'YES'  spfile_included
     from v$backup_spfile) sp
WHERE bs.start_time > sysdate - 1
AND bs.set_stamp = bp.set_stamp
AND bs.set_count = bp.set_count
AND bs.set_stamp = sp.set_stamp (+)
AND bs.set_count = sp.set_count (+)
group by backup_type, bp.tag, device_type, bs.controlfile_included, pieces, sp.spfile_included,start_time, bs.completion_time
ORDER BY bs.start_time desc;

set line 200;
col "DBF_BACKUP_MB" format 999999999.9999;
col "ARC_BACKUP_MB" format 999999999.9999;
select trunc(completion_time) "BAK_DATE", sum(blocks*block_size)/1024/1024 "DBF_BACKUP_MB", (SELECT sum(blocks*block_size)/1024/1024  from v$backup_redolog
WHERE first_time > sysdate-1) "ARC_BACKUP_MB"
from v$backup_datafile
WHERE completion_time > sysdate - 1
group by trunc(completion_time)
order by 1 DESC;

prompt**=======================================**
prompt ** Log Switchs per Hour **
prompt**========================================**

set pages 999 lines 400
col h0 format 999
col h1 format 999
col h2 format 999
col h3 format 999
col h4 format 999
col h5 format 999
col h6 format 999
col h7 format 999
col h8 format 999
col h9 format 999
col h10 format 999
col h11 format 999
col h12 format 999
col h13 format 999
col h14 format 999
col h15 format 999
col h16 format 999
col h17 format 999
col h18 format 999
col h19 format 999
col h20 format 999
col h21 format 999
col h22 format 999
col h23 format 999
SELECT TRUNC (first_time) "Date", inst_id, TO_CHAR (first_time, 'Dy') "Day",
COUNT (1) "Total",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '00', 1, 0)) "h0",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '01', 1, 0)) "h1",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '02', 1, 0)) "h2",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '03', 1, 0)) "h3",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '04', 1, 0)) "h4",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '05', 1, 0)) "h5",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '06', 1, 0)) "h6",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '07', 1, 0)) "h7",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '08', 1, 0)) "h8",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '09', 1, 0)) "h9",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '10', 1, 0)) "h10",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '11', 1, 0)) "h11",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '12', 1, 0)) "h12",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '13', 1, 0)) "h13",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '14', 1, 0)) "h14",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '15', 1, 0)) "h15",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '16', 1, 0)) "h16",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '17', 1, 0)) "h17",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '18', 1, 0)) "h18",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '19', 1, 0)) "h19",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '20', 1, 0)) "h20",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '21', 1, 0)) "h21",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '22', 1, 0)) "h22",
SUM (DECODE (TO_CHAR (first_time, 'hh24'), '23', 1, 0)) "h23",
ROUND (COUNT (1) / 24, 2) "Avg"
FROM gv$log_history
WHERE thread# = inst_id
AND first_time > sysdate-7
GROUP BY TRUNC (first_time), inst_id, TO_CHAR (first_time, 'Dy')
ORDER BY 2;

prompt**=======================================**
prompt ** ORA Errors from last 48hrs **
prompt**========================================**

col originating_timestamp for a50
col message_text for a100
SELECT originating_timestamp, message_text, message_type FROM V$DIAG_ALERT_EXT WHERE originating_timestamp > SYSTIMESTAMP - INTERVAL '2' DAY AND message_text LIKE '%ORA-%' ORDER BY originating_timestamp DESC;

prompt**=======================================**
prompt ** Database FRA Usage**
prompt**========================================**

SELECT * FROM V$RECOVERY_AREA_USAGE;

prompt**=======================================**
prompt ** Database  DR Sync Details **
prompt**========================================**

SET LINES 800
SET PAGESIZE 10000
BREAK ON REPORT
COMPUTE SUM LABEL TOTAL OF GAP ON REPORT
select primary.thread#,
       primary.maxsequence primaryseq,
       standby.maxsequence standbyseq,
       primary.maxsequence - standby.maxsequence gap
from ( select thread#, max(sequence#) maxsequence
       from v$archived_log
       where archived = 'YES'
         and resetlogs_change# = ( select d.resetlogs_change# from v$database d )
       group by thread# order by thread# ) primary,
     ( select thread#, max(sequence#) maxsequence
       from v$archived_log
       where applied = 'YES'
         and resetlogs_change# = ( select d.resetlogs_change# from v$database d )
       group by thread# order by thread# ) standby
where primary.thread# = standby.thread#;


spool off;
quit;
EOF
echo " FINISH "


