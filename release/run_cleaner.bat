@echo off
chcp 65001 > nul
cd /d "%~dp0"
echo [%date% %time%] File Cleaner 실행 중...
"%~dp0file_cleaner.exe" --config
if %errorlevel% neq 0 (
    echo [오류] 프로그램 실행 실패. 로그를 확인하세요.
    pause
)
