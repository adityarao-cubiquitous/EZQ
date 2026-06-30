from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Image,
    KeepTogether,
    ListFlowable,
    ListItem,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "EZQ_UI_DESIGN_HANDOUT.md"
OUTPUT = ROOT / "docs" / "EZQ_UI_DESIGN_HANDOUT.pdf"


def build_styles():
    base = getSampleStyleSheet()
    base.add(
        ParagraphStyle(
            name="HandoutTitle",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=24,
            leading=30,
            textColor=colors.HexColor("#102331"),
            spaceAfter=8,
        )
    )
    base.add(
        ParagraphStyle(
            name="Section",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=15,
            leading=19,
            textColor=colors.HexColor("#102331"),
            spaceBefore=10,
            spaceAfter=6,
        )
    )
    base.add(
        ParagraphStyle(
            name="Subsection",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=11.5,
            leading=15,
            textColor=colors.HexColor("#006B7A"),
            spaceBefore=8,
            spaceAfter=4,
        )
    )
    base.add(
        ParagraphStyle(
            name="BodyEzq",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.8,
            leading=11.4,
            textColor=colors.HexColor("#102331"),
            spaceAfter=4,
        )
    )
    base.add(
        ParagraphStyle(
            name="SmallEzq",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=7.5,
            leading=9.5,
            textColor=colors.HexColor("#102331"),
        )
    )
    return base


def clean_inline(text: str) -> str:
    escaped = (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("`", "")
        .replace("**", "")
    )
    return escaped.replace("/:", "/&#58;")


def paragraph(text: str, style_name: str = "BodyEzq") -> Paragraph:
    return Paragraph(clean_inline(text), STYLES[style_name])


def markdown_table(lines: list[str]) -> Table:
    rows: list[list[Paragraph]] = []
    for line in lines:
        if set(line.replace("|", "").strip()) <= {"-", " "}:
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        rows.append([paragraph(cell, "SmallEzq") for cell in cells])

    usable_width = A4[0] - (36 * mm)
    col_width = usable_width / max(len(rows[0]), 1)
    table = Table(rows, colWidths=[col_width] * len(rows[0]), repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8F6FC")),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#D8EAFE")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8FBFE")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return table


def markdown_image(line: str):
    alt_start = line.find("[")
    alt_end = line.find("]")
    path_start = line.find("(", alt_end)
    path_end = line.find(")", path_start)
    alt = line[alt_start + 1 : alt_end]
    rel_path = line[path_start + 1 : path_end]
    image_path = SOURCE.parent / rel_path
    if not image_path.exists():
        return paragraph(f"Missing image: {rel_path}")

    max_width = A4[0] - (36 * mm)
    max_height = 115 * mm
    img = Image(str(image_path))
    scale = min(max_width / img.imageWidth, max_height / img.imageHeight)
    img.drawWidth = img.imageWidth * scale
    img.drawHeight = img.imageHeight * scale
    return KeepTogether([img, paragraph(alt, "SmallEzq"), Spacer(1, 4)])


def flush_blocks(story, bullets, table_lines):
    if bullets:
        story.append(
            ListFlowable(
                [ListItem(paragraph(item), leftIndent=8) for item in bullets],
                bulletType="bullet",
                start="circle",
                leftIndent=14,
                bulletFontName="Helvetica",
                bulletFontSize=6,
            )
        )
        bullets.clear()
    if table_lines:
        story.append(markdown_table(table_lines))
        story.append(Spacer(1, 6))
        table_lines.clear()


def build_pdf():
    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        rightMargin=18 * mm,
        leftMargin=18 * mm,
        topMargin=16 * mm,
        bottomMargin=16 * mm,
        title="EZQ UI Design Handout",
    )
    story = []
    bullets: list[str] = []
    table_lines: list[str] = []

    for raw_line in SOURCE.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            flush_blocks(story, bullets, table_lines)
            story.append(Spacer(1, 2))
            continue

        if line.startswith("|"):
            flush_blocks(story, bullets, [])
            table_lines.append(line)
            continue

        flush_blocks(story, bullets, table_lines)

        if line.startswith("# "):
            story.append(paragraph(line[2:], "HandoutTitle"))
        elif line.startswith("## "):
            story.append(paragraph(line[3:], "Section"))
        elif line.startswith("### "):
            story.append(paragraph(line[4:], "Subsection"))
        elif line.startswith("- "):
            bullets.append(line[2:])
        elif line.startswith("!["):
            story.append(markdown_image(line))
        else:
            story.append(paragraph(line))

    flush_blocks(story, bullets, table_lines)
    doc.build(story, onFirstPage=footer, onLaterPages=footer)


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#D8EAFE"))
    canvas.setLineWidth(0.4)
    canvas.line(18 * mm, 11 * mm, A4[0] - 18 * mm, 11 * mm)
    canvas.setFillColor(colors.HexColor("#607D8B"))
    canvas.setFont("Helvetica", 7)
    canvas.drawString(18 * mm, 7 * mm, "EZQ UI Design Handout - June 30, 2026")
    canvas.drawRightString(A4[0] - 18 * mm, 7 * mm, f"Page {doc.page}")
    canvas.restoreState()


if __name__ == "__main__":
    STYLES = build_styles()
    build_pdf()
    print(OUTPUT)
