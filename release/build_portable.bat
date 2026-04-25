@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo.
echo ================================================================
echo    File Auto Cleaner  --  Portable 배포 패키지 조립
echo    (EXE 차단 환경용 — Portable Python 포함 버전)
echo ================================================================
echo.

:: ── Portable Python 확인 ──────────────────────────────────────────
if not exist "%~dp0python\python.exe" (
    echo [준비 필요] python\ 폴더가 없습니다.
    echo.
    echo   아래 URL 에서 "Windows embeddable package" ^(zip^) 를 내려받으세요.
    echo   https://www.python.org/downloads/windows/
    echo.
    echo   예시: python-3.13.x-embed-amd64.zip
    echo.
    echo   내려받은 zip 을 이 스크립트와 같은 폴더의 python\ 에 압축 해제하세요.
    echo.
    echo   압축 해제 후 python\python.exe 가 존재하면 이 스크립트를 다시 실행하세요.
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('"%~dp0python\python.exe" --version 2^>^&1') do set PYVER=%%i
echo [확인] !PYVER! ^(Portable^) 준비됨
echo.

:: ── 소스 파일 확인 ────────────────────────────────────────────────
set "SRC=%~dp0.."
if not exist "!SRC!\file_cleaner.py" (
    echo [오류] file_cleaner.py 를 찾을 수 없습니다.
    echo   release\ 폴더와 file_cleaner.py 가 같은 프로젝트 내에 있어야 합니다.
    pause
    exit /b 1
)
echo [확인] file_cleaner.py 확인됨
echo.

:: ── 배포 패키지 조립 ──────────────────────────────────────────────
set "PKG=%~dp0..\배포패키지_portable"
if exist "!PKG!" rmdir /s /q "!PKG!"
mkdir "!PKG!"
mkdir "!PKG!\python"

echo [조립] 배포패키지_portable\ 폴더 생성 중...

:: Python portable 복사
xcopy /s /e /y /q "%~dp0python" "!PKG!\python\" > nul
echo [복사] python\ ^(Portable Python^)

:: 프로그램 파일 복사
copy /y "!SRC!\file_cleaner.py"                "!PKG!\file_cleaner.py"         > nul
copy /y "%~dp0run_cleaner_portable.bat"        "!PKG!\run_cleaner_portable.bat" > nul
copy /y "%~dp0setup_portable.bat"              "!PKG!\setup.bat"               > nul
if exist "!SRC!\사용법.md"  copy /y "!SRC!\사용법.md"  "!PKG!\사용법.md"  > nul
if exist "!SRC!\사용법.pdf" copy /y "!SRC!\사용법.pdf" "!PKG!\사용법.pdf" > nul

echo [복사] file_cleaner.py, setup.bat, run_cleaner_portable.bat, 사용법 문서
echo.

echo ================================================================
echo   조립 완료
echo.
echo   배포패키지_portable\ 폴더를 ZIP 으로 압축해서 전달하세요.
echo   수신자는 setup.bat 만 실행하면 됩니다 ^(Python 설치 불필요^).
echo.
echo   포함 파일:
echo     python\                -- Portable Python ^(런타임^)
echo     file_cleaner.py        -- 메인 프로그램
echo     setup.bat              -- 자동 설치 스크립트
echo     run_cleaner_portable.bat -- 스케줄러 실행 래퍼
echo     사용법.md / 사용법.pdf  -- 참고 가이드
echo.
echo   주의: config.json 은 포함하지 마세요.
echo         개인 경로 정보가 담겨 있고, setup.bat 이 새로 생성합니다.
echo ================================================================
echo.
pause
endlocal
