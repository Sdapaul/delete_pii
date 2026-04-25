@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo.
echo ================================================================
echo    File Auto Cleaner  --  설정 초기화 / 스케줄러 해제
echo    (프로그램 파일은 삭제하지 않습니다)
echo ================================================================
echo.

:: ── 대상 경로 입력 ───────────────────────────────────────────────
set "DEFAULT_DIR=%~dp0"
if "!DEFAULT_DIR:~-1!"=="\" set "DEFAULT_DIR=!DEFAULT_DIR:~0,-1!"

echo 초기화할 설치 폴더를 입력하세요.
echo (다른 경로에 설치된 경우 해당 경로를 직접 입력하세요)
echo.
set /p "INSTALL_DIR=설치 폴더 [!DEFAULT_DIR!]: "
if "!INSTALL_DIR!"=="" set "INSTALL_DIR=!DEFAULT_DIR!"
if "!INSTALL_DIR:~-1!"=="\" set "INSTALL_DIR=!INSTALL_DIR:~0,-1!"
echo.

:: ── 폴더 존재 확인 ───────────────────────────────────────────────
if not exist "!INSTALL_DIR!" (
    echo [오류] 폴더가 존재하지 않습니다: !INSTALL_DIR!
    pause
    exit /b 1
)

:: ── 프로그램 설치 여부 확인 ──────────────────────────────────────
set "_found=0"
if exist "!INSTALL_DIR!\file_cleaner.exe" set "_found=1"
if exist "!INSTALL_DIR!\file_cleaner.py"  set "_found=1"

if "!_found!"=="0" (
    echo [경고] !INSTALL_DIR! 에 file_cleaner 프로그램이 없습니다.
    echo        경로가 맞는지 확인하세요.
    echo.
    set /p "FORCE=그래도 진행하시겠습니까? (y/n) [n]: "
    if "!FORCE!"=="" set "FORCE=n"
    if /i "!FORCE!" neq "y" (
        echo 취소했습니다.
        pause
        exit /b 0
    )
)

:: ── config.json 에서 quarantine_dir 읽기 ─────────────────────────
set "CONFIG_FILE=!INSTALL_DIR!\config.json"
set "QUARANTINE_DIR="

if exist "!CONFIG_FILE!" (
    set "PS_TMP=%TEMP%\fc_read_cfg.ps1"
    (
        echo try {
        echo   $c = Get-Content '!CONFIG_FILE!' -Raw ^| ConvertFrom-Json
        echo   if ($c.quarantine_dir) { Write-Output $c.quarantine_dir }
        echo } catch {}
    ) > "!PS_TMP!"
    for /f "usebackq tokens=*" %%i in (
        `powershell -NoProfile -ExecutionPolicy Bypass -File "!PS_TMP!" 2^>nul`
    ) do set "QUARANTINE_DIR=%%i"
    del "!PS_TMP!" > nul 2>&1
)

:: ── 초기화 예정 항목 표시 ─────────────────────────────────────────
echo 대상 폴더: !INSTALL_DIR!
echo.
echo [초기화될 항목]
echo   작업 스케줄러  File_Auto_Cleaner 등록 해제
echo   config.json    설정 파일 삭제
echo   activity_log.txt  로그 파일 삭제
if defined QUARANTINE_DIR (
    echo   격리 폴더      !QUARANTINE_DIR!  ^(삭제 여부 별도 확인^)
)
echo.
echo [유지되는 항목]
echo   file_cleaner.exe / file_cleaner.py  ^(프로그램 본체^)
echo   run_cleaner*.bat                    ^(실행 래퍼^)
if exist "!INSTALL_DIR!\python\" (
    echo   python\                             ^(Portable Python^)
)
echo   사용법.md / 사용법.pdf              ^(참고 문서^)
echo.
echo   → 재설치: setup.bat 을 다시 실행하면 설정과 스케줄러가 재등록됩니다.
echo.

:: ── 최종 확인 ────────────────────────────────────────────────────
set /p "CONFIRM=위 항목을 초기화하시겠습니까? (y/n) [n]: "
if "!CONFIRM!"=="" set "CONFIRM=n"
if /i "!CONFIRM!" neq "y" (
    echo.
    echo 취소했습니다.
    pause
    exit /b 0
)
echo.

:: ── STEP 1: 작업 스케줄러 해제 ───────────────────────────────────
schtasks /query /tn "File_Auto_Cleaner" > nul 2>&1
if %errorlevel% equ 0 (
    schtasks /delete /tn "File_Auto_Cleaner" /f > nul 2>&1
    echo [완료] 작업 스케줄러 'File_Auto_Cleaner' 해제
) else (
    echo [건너뜀] 작업 스케줄러에 'File_Auto_Cleaner' 없음
)

:: ── STEP 2: 격리 폴더 처리 ───────────────────────────────────────
if defined QUARANTINE_DIR (
    if exist "!QUARANTINE_DIR!" (
        echo.
        echo 격리 폴더: !QUARANTINE_DIR!
        set /p "DEL_Q=격리 폴더와 내부 파일을 삭제하시겠습니까? (y/n) [n]: "
        if "!DEL_Q!"=="" set "DEL_Q=n"
        if /i "!DEL_Q!"=="y" (
            rmdir /s /q "!QUARANTINE_DIR!" > nul 2>&1
            echo [완료] 격리 폴더 삭제: !QUARANTINE_DIR!
        ) else (
            echo [보존] 격리 폴더를 남겨둡니다.
        )
    ) else (
        echo [건너뜀] 격리 폴더가 존재하지 않습니다.
    )
)

:: ── STEP 3: 설정·로그 파일만 삭제 ───────────────────────────────
echo.
for %%f in (config.json activity_log.txt) do (
    if exist "!INSTALL_DIR!\%%f" (
        del /f /q "!INSTALL_DIR!\%%f" > nul 2>&1
        echo [완료] %%f 삭제
    )
)

echo.
echo ================================================================
echo   초기화 완료
echo.
echo   프로그램 파일은 그대로 남아 있습니다.
echo   재사용하려면 setup.bat 을 다시 실행하세요.
echo   설치 폴더: !INSTALL_DIR!
echo ================================================================
echo.
pause
endlocal
