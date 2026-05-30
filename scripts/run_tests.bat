@echo off
REM ============================================================
REM JSONPlaceholder API - JMeter Performance Test Runner (Windows)
REM ============================================================
REM Usage:
REM   run_tests.bat           -> Run all tests
REM   run_tests.bat smoke     -> Smoke test only
REM   run_tests.bat load      -> Load test only
REM   run_tests.bat stress    -> Stress test only
REM   run_tests.bat spike     -> Spike test only
REM ============================================================

SETLOCAL ENABLEDELAYEDEXPANSION

SET JMETER_HOME=C:\apache-jmeter
SET JMETER_BIN=%JMETER_HOME%\bin\jmeter.bat

SET SCRIPT_DIR=%~dp0
SET PROJECT_DIR=%SCRIPT_DIR%..
SET PLANS_DIR=%PROJECT_DIR%\test-plans
SET RESULTS_DIR=%PROJECT_DIR%\results
SET REPORTS_DIR=%PROJECT_DIR%\reports

FOR /F "tokens=2 delims==" %%I IN ('wmic os get localdatetime /value') DO SET DATETIME=%%I
SET TIMESTAMP=%DATETIME:~0,8%_%DATETIME:~8,6%

IF NOT EXIST "%RESULTS_DIR%" MKDIR "%RESULTS_DIR%"
IF NOT EXIST "%REPORTS_DIR%" MKDIR "%REPORTS_DIR%"

echo ============================================================
echo   JSONPlaceholder API - JMeter Performance Test Runner
echo   Timestamp: %TIMESTAMP%
echo ============================================================

IF NOT EXIST "%JMETER_BIN%" (
    echo [ERROR] JMeter not found at: %JMETER_BIN%
    echo [INFO]  Please update JMETER_HOME in this script
    echo [INFO]  Download: https://jmeter.apache.org/download_jmeter.cgi
    EXIT /B 1
)

SET MODE=%1
IF "%MODE%"=="" SET MODE=all

IF "%MODE%"=="smoke" GOTO :smoke
IF "%MODE%"=="load" GOTO :load
IF "%MODE%"=="stress" GOTO :stress
IF "%MODE%"=="spike" GOTO :spike
IF "%MODE%"=="all" GOTO :all

echo [ERROR] Unknown mode: %MODE%
echo Usage: run_tests.bat [smoke^|load^|stress^|spike^|all]
EXIT /B 1

:smoke
echo.
echo [START] Running: Light Smoke Test
IF EXIST "%RESULTS_DIR%\smoke_test_results.jtl" DEL "%RESULTS_DIR%\smoke_test_results.jtl"
CALL "%JMETER_BIN%" -n -t "%PLANS_DIR%\04_Light_Smoke_Test.jmx" -l "%RESULTS_DIR%\smoke_test_results.jtl" -e -o "%REPORTS_DIR%\smoke_report_%TIMESTAMP%"
IF %ERRORLEVEL%==0 (echo [PASS] Smoke Test PASSED) ELSE (echo [FAIL] Smoke Test FAILED)
GOTO :end

:load
echo.
echo [START] Running: Load Test (100 users)
IF EXIST "%RESULTS_DIR%\load_test_results.jtl" DEL "%RESULTS_DIR%\load_test_results.jtl"
CALL "%JMETER_BIN%" -n -t "%PLANS_DIR%\01_Load_Test.jmx" -l "%RESULTS_DIR%\load_test_results.jtl" -e -o "%REPORTS_DIR%\load_report_%TIMESTAMP%" -JTHREADS=100 -JRAMP_UP=60 -JDURATION=300
IF %ERRORLEVEL%==0 (echo [PASS] Load Test PASSED) ELSE (echo [FAIL] Load Test FAILED)
GOTO :end

:stress
echo.
echo [START] Running: Stress Test (100 - 1000 users)
IF EXIST "%RESULTS_DIR%\stress_test_results.jtl" DEL "%RESULTS_DIR%\stress_test_results.jtl"
CALL "%JMETER_BIN%" -n -t "%PLANS_DIR%\02_Stress_Test.jmx" -l "%RESULTS_DIR%\stress_test_results.jtl" -e -o "%REPORTS_DIR%\stress_report_%TIMESTAMP%"
IF %ERRORLEVEL%==0 (echo [PASS] Stress Test PASSED) ELSE (echo [FAIL] Stress Test FAILED)
GOTO :end

:spike
echo.
echo [START] Running: Spike Test (burst to 800 users)
IF EXIST "%RESULTS_DIR%\spike_test_results.jtl" DEL "%RESULTS_DIR%\spike_test_results.jtl"
CALL "%JMETER_BIN%" -n -t "%PLANS_DIR%\03_Spike_Test.jmx" -l "%RESULTS_DIR%\spike_test_results.jtl" -e -o "%REPORTS_DIR%\spike_report_%TIMESTAMP%"
IF %ERRORLEVEL%==0 (echo [PASS] Spike Test PASSED) ELSE (echo [FAIL] Spike Test FAILED)
GOTO :end

:all
echo [INFO] Running full suite: Smoke -> Load -> Stress -> Spike
CALL :smoke
CALL :load
CALL :stress
CALL :spike
GOTO :end

:end
echo.
echo ============================================================
echo   REPORTS available in: %REPORTS_DIR%
echo   Open index.html in any report folder to view dashboard
echo ============================================================
ENDLOCAL
