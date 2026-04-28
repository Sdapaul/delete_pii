"""
file_cleaner.py
개인 PC 파일 자동 격리/삭제 관리 프로그램

실행:
  python file_cleaner.py           # 대화형 설정 또는 config.json 사용
  python file_cleaner.py --config  # config.json 강제 사용 (무인 실행용)
"""

import os
import sys
import json
import shutil
import stat
import time
import logging
from datetime import datetime, timedelta

# ── 시스템 보호 경로 (대소문자 무관 비교) ──────────────────────────────
PROTECTED_PATHS = [
    "C:\\Windows",
    "C:\\Program Files",
    "C:\\Program Files (x86)",
    "C:\\ProgramData",
    "C:\\System Volume Information",
    "C:\\$Recycle.Bin",
    "C:\\Recovery",
    "C:\\boot",
]

# 환경변수 기반 보호 경로 동적 추가 (AppData, 사용자 프로필 등)
for _env in ("APPDATA", "LOCALAPPDATA", "PROGRAMDATA", "PROGRAMFILES",
             "PROGRAMFILES(X86)", "WINDIR", "SYSTEMROOT"):
    _p = os.environ.get(_env)
    if _p:
        _norm = os.path.normpath(_p)
        if _norm.upper() not in [os.path.normpath(x).upper() for x in PROTECTED_PATHS]:
            PROTECTED_PATHS.append(_norm)

# exe로 실행 시 sys.executable 기준, 스크립트 실행 시 __file__ 기준
if getattr(sys, "frozen", False):
    BASE_DIR = os.path.dirname(sys.executable)
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

CONFIG_FILE = os.path.join(BASE_DIR, "config.json")
LOG_FILE    = os.path.join(BASE_DIR, "activity_log.log")

# ── 로거 설정 ────────────────────────────────────────────────────────────

def setup_logger() -> logging.Logger:
    logger = logging.getLogger("FileCleaner")
    logger.setLevel(logging.INFO)
    if logger.handlers:
        return logger

    fmt = logging.Formatter("%(asctime)s  %(levelname)-8s  %(message)s",
                            datefmt="%Y-%m-%d %H:%M:%S")

    fh = logging.FileHandler(LOG_FILE, encoding="utf-8")
    fh.setFormatter(fmt)

    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(fmt)

    logger.addHandler(fh)
    logger.addHandler(ch)
    return logger

# ── 설정 로드/저장 ───────────────────────────────────────────────────────

def _ask(prompt: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    value = input(f"{prompt}{suffix}: ").strip()
    return value if value else default

def _ask_int(prompt: str, default: int) -> int:
    while True:
        raw = _ask(prompt, str(default))
        try:
            return int(raw)
        except ValueError:
            print("  숫자를 입력하세요.")

def interactive_setup() -> dict:
    print("\n" + "=" * 56)
    print("   파일 자동 격리/삭제 프로그램 — 초기 설정")
    print("=" * 56)
    print("(값을 입력하지 않으면 [] 안의 기본값이 사용됩니다)\n")

    target = _ask("1. 검사할 폴더 경로 (예: C:\\Users\\yourname\\Downloads)")
    if not target:
        sys.exit("대상 경로는 필수 항목입니다.")

    default_quarantine = os.path.join(target, "Quarantine")

    ext_raw = _ask("2. 대상 확장자 (쉼표 구분, 없으면 Enter → 전체)", "")
    keywords_raw = _ask("3. 파일명 포함 단어 (쉼표 구분, 없으면 Enter → 전체)", "")

    quarantine_days = _ask_int("4. 격리 기준일  — 생성 후 N일 초과 시 격리", 30)
    delete_days     = _ask_int("5. 삭제 기준일  — 격리 후 M일 초과 시 영구 삭제", 7)
    quarantine_dir  = _ask("6. 격리 폴더 경로", default_quarantine)

    print("\n  실행 방식 선택:")
    print("    0  = 한 번 실행 후 종료")
    print("    1~24 = 하루에 N번 반복 (예: 2 → 12시간마다)")
    runs_per_day = _ask_int("7. 하루 실행 횟수", 0)

    config = {
        "target_path":     target,
        "extensions":      [e.strip() for e in ext_raw.split(",") if e.strip()],
        "keywords":        [k.strip() for k in keywords_raw.split(",") if k.strip()],
        "quarantine_days": quarantine_days,
        "delete_days":     delete_days,
        "quarantine_dir":  quarantine_dir,
        "runs_per_day":    runs_per_day,
    }

    if _ask("\n설정을 config.json에 저장하시겠습니까?", "y").lower() == "y":
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(config, f, ensure_ascii=False, indent=4)
        print(f"  → {CONFIG_FILE} 저장 완료\n")

    return config


def load_config() -> dict:
    force_config = "--config" in sys.argv

    if force_config:
        if not os.path.exists(CONFIG_FILE):
            sys.exit(
                f"[오류] config.json 파일이 없습니다: {CONFIG_FILE}\n"
                "  setup.bat 을 먼저 실행해 초기 설정을 완료하세요."
            )
        with open(CONFIG_FILE, encoding="utf-8") as f:
            cfg = json.load(f)
        print(f"  → {CONFIG_FILE} 로드 완료")
        _validate_config(cfg)
        return cfg

    if os.path.exists(CONFIG_FILE):
        if _ask(f"\n{CONFIG_FILE} 파일이 있습니다. 사용하시겠습니까?", "y").lower() == "y":
            with open(CONFIG_FILE, encoding="utf-8") as f:
                cfg = json.load(f)
            print(f"  → {CONFIG_FILE} 로드 완료")
            _validate_config(cfg)
            return cfg

    return interactive_setup()


def _validate_config(cfg: dict):
    required = ["target_path", "quarantine_days", "delete_days", "quarantine_dir"]
    for key in required:
        if key not in cfg:
            sys.exit(f"[오류] config.json에 '{key}' 항목이 없습니다.")
    cfg.setdefault("extensions", [])
    cfg.setdefault("keywords", [])
    cfg.setdefault("runs_per_day", 0)
    cfg.setdefault("exclude_paths", [])
    # config의 exclude_paths를 전역 보호 목록에 반영
    for p in cfg["exclude_paths"]:
        norm = os.path.normpath(p)
        if norm.upper() not in [os.path.normpath(x).upper() for x in PROTECTED_PATHS]:
            PROTECTED_PATHS.append(norm)

# ── 보호 판단 헬퍼 ───────────────────────────────────────────────────────

def _norm(path: str) -> str:
    return os.path.normpath(path).upper()

def is_protected_path(path: str) -> bool:
    n = _norm(path)
    return any(n.startswith(_norm(p)) for p in PROTECTED_PATHS)

def is_restricted_file(path: str) -> bool:
    """읽기 전용 또는 시스템 속성 파일이면 True."""
    try:
        attrs = os.stat(path).st_file_attributes  # Windows 전용
        READONLY = 0x1
        SYSTEM   = 0x4
        HIDDEN   = 0x2
        return bool(attrs & READONLY or attrs & SYSTEM)
    except AttributeError:
        # 비 Windows 환경 fallback
        return not os.access(path, os.W_OK)
    except OSError:
        return True  # 접근 불가 → 건드리지 않음

# ── 파일 매칭 ────────────────────────────────────────────────────────────

def matches_filter(filename: str, extensions: list, keywords: list) -> bool:
    name_lower = filename.lower()
    _, ext = os.path.splitext(filename)

    if extensions and ext.lower() not in [e.lower() for e in extensions]:
        return False
    if keywords and not any(kw.lower() in name_lower for kw in keywords):
        return False
    return True

# ── 날짜 헬퍼 ────────────────────────────────────────────────────────────

def file_age_days(path: str) -> int:
    """파일 생성일 기준 경과 일수. 실패 시 -1."""
    try:
        return (datetime.now() - datetime.fromtimestamp(os.path.getctime(path))).days
    except OSError:
        return -1

def mtime_age_days(path: str) -> int:
    """수정 시각 기준 경과 일수 (격리 후 경과 일수로 사용). 실패 시 -1."""
    try:
        return (datetime.now() - datetime.fromtimestamp(os.path.getmtime(path))).days
    except OSError:
        return -1

def safe_dest(dest_dir: str, filename: str) -> str:
    """충돌 없는 목적지 경로 반환."""
    dest = os.path.join(dest_dir, filename)
    if not os.path.exists(dest):
        return dest
    base, ext = os.path.splitext(filename)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return os.path.join(dest_dir, f"{base}_{stamp}{ext}")

# ── 1단계: 격리 ──────────────────────────────────────────────────────────

def quarantine_files(cfg: dict, log: logging.Logger) -> int:
    target        = cfg["target_path"]
    extensions    = cfg["extensions"]
    keywords      = cfg["keywords"]
    threshold     = cfg["quarantine_days"]
    quarantine_dir = cfg["quarantine_dir"]

    if not os.path.isdir(target):
        log.error(f"대상 경로 없음: {target}")
        return 0

    if is_protected_path(target):
        log.error(f"시스템 보호 경로 대상 지정 불가: {target}")
        return 0

    os.makedirs(quarantine_dir, exist_ok=True)
    q_norm = _norm(quarantine_dir)
    count = 0

    for root, dirs, files in os.walk(target, topdown=True):
        # 격리 폴더 자체 및 시스템 경로 하위 탐색 스킵
        dirs[:] = [
            d for d in dirs
            if not _norm(os.path.join(root, d)).startswith(q_norm)
            and not is_protected_path(os.path.join(root, d))
        ]

        for fname in files:
            fpath = os.path.join(root, fname)

            if is_restricted_file(fpath):
                continue
            if not matches_filter(fname, extensions, keywords):
                continue

            age = file_age_days(fpath)
            if age < 0 or age <= threshold:
                continue

            dest = safe_dest(quarantine_dir, fname)
            try:
                shutil.move(fpath, dest)
                now = time.time()
                os.utime(dest, (now, now))  # 격리 시각을 mtime에 기록 (삭제 기준 기산점)
                log.info(f"[격리]  {fpath}  →  {dest}  (생성 후 {age}일)")
                count += 1
            except (OSError, shutil.Error) as e:
                log.warning(f"[격리 실패]  {fpath}  :  {e}")

    log.info(f"[격리 소계]  {count}개 파일 이동")
    return count

# ── 2단계: 최종 삭제 ─────────────────────────────────────────────────────

def delete_quarantined(cfg: dict, log: logging.Logger) -> int:
    quarantine_dir = cfg["quarantine_dir"]
    threshold      = cfg["delete_days"]

    if not os.path.isdir(quarantine_dir):
        log.info("[삭제]  격리 폴더 없음 — 건너뜁니다.")
        return 0

    count = 0
    for fname in os.listdir(quarantine_dir):
        fpath = os.path.join(quarantine_dir, fname)
        if not os.path.isfile(fpath):
            continue

        age = mtime_age_days(fpath)
        if age < 0 or age <= threshold:
            continue

        try:
            # 읽기 전용 속성 해제 후 삭제
            os.chmod(fpath, stat.S_IWRITE)
            os.remove(fpath)
            log.info(f"[삭제]  {fpath}  (격리 후 {age}일 — 영구 삭제)")
            count += 1
        except OSError as e:
            log.warning(f"[삭제 실패]  {fpath}  :  {e}")

    log.info(f"[삭제 소계]  {count}개 파일 영구 삭제")
    return count

# ── 단일 사이클 ──────────────────────────────────────────────────────────

def run_cycle(cfg: dict, log: logging.Logger):
    log.info("=" * 56)
    log.info("실행 시작")
    log.info(f"  대상: {cfg['target_path']}")
    log.info(f"  확장자: {cfg['extensions'] or '(전체)'}")
    log.info(f"  키워드: {cfg['keywords'] or '(전체)'}")
    log.info(f"  격리 기준: {cfg['quarantine_days']}일  /  삭제 기준: {cfg['delete_days']}일")
    if cfg.get("exclude_paths"):
        log.info(f"  추가 제외 경로: {cfg['exclude_paths']}")
    log.info("=" * 56)

    q = quarantine_files(cfg, log)
    d = delete_quarantined(cfg, log)

    log.info(f"실행 완료  —  격리 {q}개 / 삭제 {d}개")

# ── 메인 ─────────────────────────────────────────────────────────────────

def main():
    cfg = load_config()
    log = setup_logger()

    # --setup: 설치 스크립트에서 호출 시 설정 저장만 하고 종료
    if "--setup" in sys.argv:
        print(f"\n[설정 완료] 설정이 저장되었습니다.")
        print(f"  파일: {os.path.abspath(CONFIG_FILE)}")
        return

    runs_per_day = cfg.get("runs_per_day", 0)

    if runs_per_day <= 0:
        print("\n[모드] 일회성 실행\n")
        run_cycle(cfg, log)
        print(f"\n완료. 로그 파일: {os.path.abspath(LOG_FILE)}")
        return

    interval = int((24 * 3600) / runs_per_day)
    hours    = interval / 3600
    print(f"\n[모드] 반복 실행  —  하루 {runs_per_day}회 ({hours:.1f}시간 간격)")
    print("종료: Ctrl+C\n")

    while True:
        run_cycle(cfg, log)
        next_time = datetime.now() + timedelta(seconds=interval)
        log.info(f"대기 중  —  다음 실행: {next_time.strftime('%Y-%m-%d %H:%M:%S')}")
        try:
            time.sleep(interval)
        except KeyboardInterrupt:
            print("\n사용자 중단 — 종료합니다.")
            break


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n종료합니다.")
