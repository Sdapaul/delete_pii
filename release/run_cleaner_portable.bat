@echo off
chcp 65001 > nul
cd /d "%~dp0"

:: Portable Python 경로 확인
if not exist "%~dp0python\python.exe" (
    echo [오류] python\ 폴더가 없거나 python.exe 를 찾을 수 없습니다.
    echo   배포자에게 Portable Python 포함 버전을 요청하세요.
    pause
    exit /b 1
)

echo [%date% %time%] File Cleaner 실행 중...
"%~dp0python\python.exe" "%~dp0file_cleaner.py" --config
if %errorlevel% neq 0 (
    echo [오류] 프로그램 실행 실패. 로그를 확인하세요.
    pause
)
