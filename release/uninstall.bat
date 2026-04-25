@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo.
echo ================================================================
echo    File Auto Cleaner  --  제거 프로그램
echo ================================================================
echo.

:: ── 설치 경로 (이 bat 파일 위치 기준) ───────────────────────────��
set "INSTALL_DIR=%~dp0"
if "!INSTALL_DIR:~-1!"=="\" set "INSTALL_DIR=!INSTALL_DIR:~0,-1!"
echo 설치 폴더: !INSTALL_DIR!
echo.

:: ── config.json 에서 quarantine_dir 읽기 (PowerShell) ────────────
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

:: ── 제거 예정 항목 표시 ───────────────────────────────────────────
echo 제거될 항목:
echo   [스케줄러]  File_Auto_Cleaner 작업 등록
echo   [파일]      file_cleaner.exe  /  file_cleaner.py
echo   [파일]      config.json
echo   [파일]      run_cleaner*.bat
echo   [파일]      activity_log.txt
echo   [파일]      사용법.md  /  사용법.pdf  (있는 경우)
if exist "!INSTALL_DIR!\python\" (
    echo   [폴더]      python\  ^(Portable Python^)
)
if defined QUARANTINE_DIR (
    echo.
    echo   [격리 폴더] !QUARANTINE_DIR!
    echo               ^(삭제 여부를 별도로 묻습니다^)
)
echo.

:: ── 최종 확인 ────────────────────────────────────────────────────
set /p "CONFIRM=위 항목을 제거하시겠습니까? (y/n) [n]: "
if "!CONFIRM!"=="" set "CONFIRM=n"
if /i "!CONFIRM!" neq "y" (
    echo.
    echo 제거를 취소했습니다.
    pause
    exit /b 0
)
echo.

:: ── STEP 1: 작업 스케줄러 삭제 ───────────────────────────────────
schtasks /query /tn "File_Auto_Cleaner" > nul 2>&1
if %errorlevel% equ 0 (
    schtasks /delete /tn "File_Auto_Cleaner" /f > nul 2>&1
    echo [완료] 작업 스케줄러 'File_Auto_Cleaner' 삭제
) else (
    echo [건너뜀] 작업 스케줄러에 'File_Auto_Cleaner' 없음
)

:: ── STEP 2: 격리 폴더 처리 ──────────────────────────────────────
if defined QUARANTINE_DIR (
    if exist "!QUARANTINE_DIR!" (
        echo.
        echo 격리 폴더 경로: !QUARANTINE_DIR!
        set /p "DEL_Q=격리 폴더와 내부 파일을 삭제하시겠습니까? (y/n) [n]: "
        if "!DEL_Q!"=="" set "DEL_Q=n"
        if /i "!DEL_Q!"=="y" (
            rmdir /s /q "!QUARANTINE_DIR!" > nul 2>&1
            echo [완료] 격리 폴더 삭제: !QUARANTINE_DIR!
        ) else (
            echo [보존] 격리 폴더를 남겨둡니다.
            echo        필요한 파일을 확인한 뒤 탐색기에서 직접 삭제하세요.
        )
    ) else (
        echo [건너뜀] 격리 폴더가 존재하지 않습니다.
    )
)

:: ── STEP 3: 프로그램 파일 삭제 ──────────────────────────────────
echo.
set "_ok=0"

for %%f in (
    file_cleaner.exe
    file_cleaner.py
    config.json
    activity_log.txt
    run_cleaner.bat
    run_cleaner_portable.bat
    run_cleaner_exe.bat
    "사용법.md"
    "사용법.pdf"
) do (
    if exist "!INSTALL_DIR!\%%~f" (
        del /f /q "!INSTALL_DIR!\%%~f" > nul 2>&1
        echo [완료] %%~f 삭제
        set "_ok=1"
    )
)

:: Portable Python 폴더
if exist "!INSTALL_DIR!\python\" (
    rmdir /s /q "!INSTALL_DIR!\python" > nul 2>&1
    echo [완료] python\ 폴더 삭제
)

if "!_ok!"=="0" echo [건너뜀] 삭제할 프로그램 파일 없음

:: ── STEP 4: 설치 폴더 정리 ──────────────────────────────────────
:: 이 bat 파일 자체는 실행 중이므로 지연 삭제로 처리
echo.
echo [정리] 스크립트 종료 후 설치 폴더를 자동 정리합니다...
start /min "" cmd /c "timeout /t 2 /nobreak > nul ^& del /f /q "!INSTALL_DIR!\uninstall.bat" > nul 2>&1 ^& rmdir "!INSTALL_DIR!" > nul 2>&1"

echo.
echo ================================================================
echo   제거 완료
echo.
echo   남아있는 파일이 있으면 탐색기에서 아래 폴더를 직접 삭제하세요.
echo   !INSTALL_DIR!
echo ================================================================
echo.
pause
endlocal
