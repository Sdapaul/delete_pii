"""사용법.md → 사용법.pdf 변환 스크립트"""
import re
import os
from fpdf import FPDF

FONT_REGULAR = r"C:\Windows\Fonts\malgun.ttf"
FONT_BOLD    = r"C:\Windows\Fonts\malgunbd.ttf"
MD_FILE      = os.path.join(os.path.dirname(os.path.abspath(__file__)), "사용법.md")
PDF_FILE     = os.path.join(os.path.dirname(os.path.abspath(__file__)), "사용법.pdf")

PAGE_W = 210
MARGIN = 18
CONTENT_W = PAGE_W - MARGIN * 2

def strip_inline(text):
    """굵게(`**`), 인라인코드(`` ` ``), 링크 마크업 제거 → 순수 텍스트."""
    text = re.sub(r'\*\*(.*?)\*\*', r'\1', text)
    text = re.sub(r'`([^`]+)`', r'\1', text)
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
    return text

class PDF(FPDF):
    def header(self):
        pass

    def footer(self):
        self.set_y(-13)
        self.set_font("Regular", size=8)
        self.set_text_color(150, 150, 150)
        self.cell(0, 8, f"- {self.page_no()} -", align="C")
        self.set_text_color(0, 0, 0)

def make_pdf():
    pdf = PDF(orientation="P", unit="mm", format="A4")
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.add_font("Regular", style="",  fname=FONT_REGULAR)
    pdf.add_font("Bold",    style="",  fname=FONT_BOLD)
    pdf.add_page()

    with open(MD_FILE, encoding="utf-8") as f:
        lines = f.readlines()

    in_code   = False
    in_table  = False
    col_widths = []

    for raw in lines:
        line = raw.rstrip("\n")

        # ── 코드 블록 ──────────────────────────────────────────────
        if line.startswith("```"):
            in_code = not in_code
            if in_code:
                pdf.set_fill_color(240, 240, 240)
                pdf.ln(1)
            else:
                pdf.ln(2)
            continue

        if in_code:
            pdf.set_font("Regular", size=8)
            pdf.set_fill_color(240, 240, 240)
            display = line if line else " "
            pdf.multi_cell(CONTENT_W, 5, display, fill=True, new_x="LMARGIN", new_y="NEXT")
            continue

        # ── 표 감지 ────────────────────────────────────────────────
        if re.match(r'^\s*\|', line):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            # 구분선 행 건너뜀 (|---|---|)
            if all(re.match(r'^[-:]+$', c) for c in cells if c):
                continue
            in_table = True
            if not col_widths or len(col_widths) != len(cells):
                col_widths = [CONTENT_W / len(cells)] * len(cells)
            pdf.set_font("Regular", size=9)
            max_lines = 1
            for i, cell in enumerate(cells):
                w = col_widths[i]
                n = len(pdf.multi_cell(w, 5, strip_inline(cell), dry_run=True, output="LINES"))
                max_lines = max(max_lines, n)
            row_h = max_lines * 5
            x_start = pdf.get_x()
            y_start = pdf.get_y()
            for i, cell in enumerate(cells):
                w = col_widths[i]
                pdf.set_xy(x_start + sum(col_widths[:i]), y_start)
                pdf.multi_cell(w, row_h, strip_inline(cell), border=1,
                               new_x="RIGHT", new_y="TOP", max_line_height=5)
            pdf.set_xy(x_start, y_start + row_h)
            continue
        else:
            if in_table:
                in_table = False
                col_widths = []
                pdf.ln(2)

        stripped = line.strip()

        if not stripped:
            pdf.ln(3)
            continue

        # ── HR (---) ───────────────────────────────────────────────
        if re.match(r'^-{3,}$', stripped):
            pdf.set_draw_color(180, 180, 180)
            pdf.line(MARGIN, pdf.get_y(), PAGE_W - MARGIN, pdf.get_y())
            pdf.ln(4)
            continue

        # ── 제목 ───────────────────────────────────────────────────
        if stripped.startswith("# ") and not stripped.startswith("## "):
            pdf.set_font("Bold", size=18)
            pdf.set_text_color(20, 60, 120)
            pdf.multi_cell(CONTENT_W, 10, strip_inline(stripped[2:]), new_x="LMARGIN", new_y="NEXT")
            pdf.set_text_color(0, 0, 0)
            pdf.ln(2)
            continue

        if stripped.startswith("## "):
            pdf.set_font("Bold", size=13)
            pdf.set_text_color(30, 80, 150)
            pdf.multi_cell(CONTENT_W, 8, strip_inline(stripped[3:]), new_x="LMARGIN", new_y="NEXT")
            pdf.set_text_color(0, 0, 0)
            pdf.ln(1)
            continue

        if stripped.startswith("### "):
            pdf.set_font("Bold", size=11)
            pdf.set_text_color(50, 100, 170)
            pdf.multi_cell(CONTENT_W, 7, strip_inline(stripped[4:]), new_x="LMARGIN", new_y="NEXT")
            pdf.set_text_color(0, 0, 0)
            continue

        if stripped.startswith("#### "):
            pdf.set_font("Bold", size=10)
            pdf.multi_cell(CONTENT_W, 6, strip_inline(stripped[5:]), new_x="LMARGIN", new_y="NEXT")
            continue

        # ── 인용 (>) ───────────────────────────────────────────────
        if stripped.startswith("> "):
            pdf.set_font("Regular", size=9)
            pdf.set_text_color(80, 80, 80)
            pdf.set_fill_color(248, 248, 248)
            content = strip_inline(stripped[2:])
            pdf.multi_cell(CONTENT_W - 4, 5, content, fill=True, new_x="LMARGIN", new_y="NEXT")
            pdf.set_text_color(0, 0, 0)
            continue

        # ── 리스트 ─────────────────────────────────────────────────
        bullet_m = re.match(r'^(\s*)[-*]\s+(.*)', line)
        num_m    = re.match(r'^(\s*)\d+[.)]\s+(.*)', line)
        check_m  = re.match(r'^(\s*)-\s+\[[ x]\]\s+(.*)', line)

        if check_m:
            indent = len(check_m.group(1))
            content = strip_inline(check_m.group(2))
            pdf.set_font("Regular", size=10)
            x_off = MARGIN + indent * 2 + 4
            pdf.set_x(x_off)
            pdf.multi_cell(CONTENT_W - indent * 2 - 4, 6, f"□ {content}", new_x="LMARGIN", new_y="NEXT")
            continue

        if bullet_m:
            indent = len(bullet_m.group(1))
            content = strip_inline(bullet_m.group(2))
            pdf.set_font("Regular", size=10)
            x_off = MARGIN + indent * 2 + 4
            pdf.set_x(x_off)
            pdf.multi_cell(CONTENT_W - indent * 2 - 4, 6, f"• {content}", new_x="LMARGIN", new_y="NEXT")
            continue

        if num_m:
            indent = len(num_m.group(1))
            content = strip_inline(num_m.group(2))
            pdf.set_font("Regular", size=10)
            x_off = MARGIN + indent * 2 + 4
            pdf.set_x(x_off)
            pdf.multi_cell(CONTENT_W - indent * 2 - 4, 6, content, new_x="LMARGIN", new_y="NEXT")
            continue

        # ── 일반 문단 ──────────────────────────────────────────────
        pdf.set_font("Regular", size=10)
        pdf.multi_cell(CONTENT_W, 6, strip_inline(stripped), new_x="LMARGIN", new_y="NEXT")

    pdf.output(PDF_FILE)
    print(f"생성 완료: {PDF_FILE}")

if __name__ == "__main__":
    make_pdf()
