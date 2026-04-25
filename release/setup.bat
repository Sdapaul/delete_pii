@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo.
echo ================================================================
echo    File Auto Cleaner  --  자동 설치 프로그램
echo ================================================================
echo.

:: ── EXE 존재 확인 ────────────────────────────────────────────────
if not exist "%~dp0file_cleaner.exe" (
    echo [오류] file_cleaner.exe 파일이 없습니다.
    echo   이 스크립트와 같은 폴더에 file_cleaner.exe 가 있어야 합니다.
    pause
    exit /b 1
)
echo [확인] file_cleaner.exe 발견됨
echo.

:: ── 설치 경로 선택 ────────────────────────────────────────────────
set "DEFAULT_DIR=C:\FileCleaner"
set /p "INSTALL_DIR=설치 폴더를 입력하세요 [%DEFAULT_DIR%]: "
if "!INSTALL_DIR!"=="" set "INSTALL_DIR=%DEFAULT_DIR%"
echo.

:: ── 파일 복사 ────────────────────────────────────────────────────
if not exist "!INSTALL_DIR!" (
    mkdir "!INSTALL_DIR!"
)

copy /y "%~dp0file_cleaner.exe"  "!INSTALL_DIR!\file_cleaner.exe"  > nul
copy /y "%~dp0run_cleaner.bat"   "!INSTALL_DIR!\run_cleaner.bat"   > nul
if exist "%~dp0uninstall.bat"    copy /y "%~dp0uninstall.bat"   "!INSTALL_DIR!\uninstall.bat"   > nul
if exist "%~dp0사용법.md"  copy /y "%~dp0사용법.md"  "!INSTALL_DIR!\사용법.md"  > nul
if exist "%~dp0사용법.pdf" copy /y "%~dp0사용법.pdf" "!INSTALL_DIR!\사용법.pdf" > nul

echo [설치] 프로그램 파일 복사 완료: !INSTALL_DIR!
echo.

:: ── 초기 설정 (대화형) ───────────────────────────────────────────
echo ── 초기 설정을 시작합니다 ──────────────────────────────────────
echo    검사 폴더, 확장자, 격리 기간 등을 입력합니다.
echo    (설정 완료 후 첫 실행이 한 번 이루어집니다)
echo.

cd /d "!INSTALL_DIR!"
"!INSTALL_DIR!\file_cleaner.exe"
echo.

:: ── 작업 스케줄러 등록 ───────────────────────────────────────────
echo ── Windows 작업 스케줄러 자동 등록 ────────────────────────────
set /p "REG_SCHED=매일 자동 실행을 등록하시겠습니까? (y/n) [y]: "
if "!REG_SCHED!"=="" set "REG_SCHED=y"
if /i "!REG_SCHED!" neq "y" goto :done

set /p "SCHED_TIME=매일 실행 시각을 입력하세요 (HH:MM 형식) [09:00]: "
if "!SCHED_TIME!"=="" set "SCHED_TIME=09:00"

:: 같은 이름의 기존 작업 제거
schtasks /query /tn "File_Auto_Cleaner" > nul 2>&1
if %errorlevel% equ 0 (
    schtasks /delete /tn "File_Auto_Cleaner" /f > nul
    echo [갱신] 기존 File_Auto_Cleaner 작업을 덮어씁니다.
)

set "PS_INSTALL_DIR=!INSTALL_DIR!"
set "PS_SCHED_TIME=!SCHED_TIME!"
set "PS_TMP=%TEMP%\fc_sched.ps1"

echo $d  = $env:PS_INSTALL_DIR > "%PS_TMP%"
echo $t  = $env:PS_SCHED_TIME >> "%PS_TMP%"
echo $a  = New-ScheduledTaskAction -Execute 'cmd' -Argument ('/c "' + $d + '\run_cleaner.bat"') >> "%PS_TMP%"
echo $tr = New-ScheduledTaskTrigger -Daily -At $t >> "%PS_TMP%"
echo $s  = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ^(New-TimeSpan -Hours 72^) >> "%PS_TMP%"
echo $p  = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited >> "%PS_TMP%"
echo Register-ScheduledTask -TaskName 'File_Auto_Cleaner' -Action $a -Trigger $tr -Settings $s -Principal $p -Force ^| Out-Null >> "%PS_TMP%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_TMP%"
set PS_RESULT=%errorlevel%
del "%PS_TMP%" > nul 2>&1

if %PS_RESULT% equ 0 (
    echo.
    echo [완료] 작업 스케줄러 등록 성공
    echo        작업 이름 : File_Auto_Cleaner
    echo        실행 시각 : 매일 !SCHED_TIME!
    echo        실행 계정 : %USERNAME%  ^(로그인 상태일 때 자동 실행^)
    echo        지연 실행 : 9시 이후 PC 가 켜지면 즉시 보완 실행
) else (
    echo.
    echo [오류] 자동 등록에 실패했습니다.
    echo        사용법.md 의 STEP 5 를 참고해 수동으로 등록하세요.
)

:done
echo.
echo ================================================================
echo   설치 완료
echo   설정 파일 : !INSTALL_DIR!\config.json
echo   로그 파일 : !INSTALL_DIR!\activity_log.txt
echo   설정 변경 : config.json 을 메모장으로 열어 수정하면 됩니다.
echo ================================================================
echo.
pause
endlocal
