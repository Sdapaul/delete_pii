@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo.
echo ================================================================
echo    File Auto Cleaner  --  배포용 EXE 빌드
echo ================================================================
echo.

:: ── PyInstaller 설치 확인 ────────────────────────────────────────
python --version > nul 2>&1
if %errorlevel% neq 0 (
    echo [오류] Python 이 설치되어 있지 않습니다. 빌드는 Python PC 에서 실행하세요.
    pause
    exit /b 1
)

pip show pyinstaller > nul 2>&1
if %errorlevel% neq 0 (
    echo [설치] PyInstaller 설치 중...
    pip install pyinstaller
    if %errorlevel% neq 0 (
        echo [오류] PyInstaller 설치 실패.
        pause
        exit /b 1
    )
)
echo [확인] PyInstaller 준비됨
echo.

:: ── EXE 빌드 ─────────────────────────────────────────────────────
echo [빌드] file_cleaner.exe 생성 중... (30초~1분 소요)
cd /d "%~dp0"
pyinstaller --onefile --name file_cleaner --distpath "%~dp0dist" --workpath "%~dp0build_tmp" --specpath "%~dp0build_tmp" file_cleaner.py

if not exist "%~dp0dist\file_cleaner.exe" (
    echo.
    echo [오류] 빌드 실패. 위 오류 메시지를 확인하세요.
    pause
    exit /b 1
)
echo [완료] dist\file_cleaner.exe 생성됨
echo.

:: ── 배포 패키지 조립 ─────────────────────────────────────────────
set "PKG=%~dp0배포패키지"
if exist "!PKG!" rmdir /s /q "!PKG!"
mkdir "!PKG!"

copy /y "%~dp0dist\file_cleaner.exe"  "!PKG!\file_cleaner.exe"  > nul
copy /y "%~dp0run_cleaner_exe.bat"    "!PKG!\run_cleaner.bat"   > nul
copy /y "%~dp0setup_exe.bat"          "!PKG!\setup.bat"         > nul
if exist "%~dp0사용법.md" copy /y "%~dp0사용법.md" "!PKG!\사용법.md" > nul

:: 임시 빌드 파일 정리
rmdir /s /q "%~dp0build_tmp" > nul 2>&1

echo.
echo ================================================================
echo   빌드 및 패키지 조립 완료
echo.
echo   배포패키지\ 폴더를 ZIP 으로 압축해서 전달하세요.
echo   수신자는 Python 없이 setup.bat 만 실행하면 됩니다.
echo.
echo   포함 파일:
echo     file_cleaner.exe  -- 메인 프로그램 (Python 불필요)
echo     run_cleaner.bat   -- 스케줄러 실행 래퍼
echo     setup.bat         -- 자동 설치 스크립트
echo     사용법.md          -- 참고 가이드
echo ================================================================
echo.
pause
endlocal
