@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo.
echo ================================================================
echo    File Auto Cleaner  --  제거 프로그램
echo ================================================================
echo.

:: ── 제거 대상 경로 입력 ──────────────────────────────────────────
:: 기본값: 이 bat 파일이 있는 폴더
set "DEFAULT_DIR=%~dp0"
if "!DEFAULT_DIR:~-1!"=="\" set "DEFAULT_DIR=!DEFAULT_DIR:~0,-1!"

echo 제거할 설치 폴더를 입력하세요.
echo (다른 경로에 설치된 경우 해당 경로를 직접 입력하세요)
echo.
set /p "INSTALL_DIR=설치 폴더 [!DEFAULT_DIR!]: "
if "!INSTALL_DIR!"=="" set "INSTALL_DIR=!DEFAULT_DIR!"

:: 끝 슬래시 제거
if "!INSTALL_DIR:~-1!"=="\" set "INSTALL_DIR=!INSTALL_DIR:~0,-1!"

echo.

:: ── 폴더 존재 확인 ───────────────────────────────────────────────
if not exist "!INSTALL_DIR!" (
    echo [오류] 폴더가 존재하지 않습니다: !INSTALL_DIR!
    pause
    exit /b 1
)

:: ── 프로그램 설치본 확인 ─────────────────────────────────────────
set "_is_installed=0"
if exist "!INSTALL_DIR!\file_cleaner.exe" set "_is_installed=1"
if exist "!INSTALL_DIR!\file_cleaner.py"  set "_is_installed=1"

if "!_is_installed!"=="0" (
    echo [경고] !INSTALL_DIR! 에 file_cleaner 프로그램이 없습니다.
    echo        경로가 맞는지 확인하세요.
    echo.
    set /p "FORCE=그래도 진행하시겠습니까? (y/n) [n]: "
    if "!FORCE!"=="" set "FORCE=n"
    if /i "!FORCE!" neq "y" (
        echo 제거를 취소했습니다.
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

:: ── 제거 예정 항목 표시 ───────────────────────────────────────────
echo 제거 대상 폴더: !INSTALL_DIR!
echo.
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

:: ── STEP 2: 격리 폴더 처리 ───────────────────────────────────────
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

:: ── STEP 3: 프로그램 파일 삭제 ───────────────────────────────────
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

:: ── STEP 4: 설치 폴더 정리 ───────────────────────────────────────
:: 이 bat이 대상 폴더 안에 있는 경우: 지연 삭제
:: 이 bat이 대상 폴더 밖에서 실행된 경우: 즉시 rmdir 시도
echo.
set "THIS_DIR=%~dp0"
if "!THIS_DIR:~-1!"=="\" set "THIS_DIR=!THIS_DIR:~0,-1!"

if /i "!THIS_DIR!"=="!INSTALL_DIR!" (
    echo [정리] 스크립트 종료 후 설치 폴더를 자동 정리합니다...
    start /min "" cmd /c "timeout /t 2 /nobreak > nul ^& del /f /q "!INSTALL_DIR!\uninstall.bat" > nul 2>&1 ^& rmdir "!INSTALL_DIR!" > nul 2>&1"
) else (
    rmdir "!INSTALL_DIR!" > nul 2>&1
    if exist "!INSTALL_DIR!" (
        echo [안내] 빈 폴더가 아니거나 다른 파일이 남아 있어 폴더를 유지합니다.
        echo        탐색기에서 직접 확인 후 삭제하세요: !INSTALL_DIR!
    ) else (
        echo [완료] 설치 폴더 삭제: !INSTALL_DIR!
    )
)

echo.
echo ================================================================
echo   제거 완료
echo ================================================================
echo.
pause
endlocal
