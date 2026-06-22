from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "web" / "demo-menu.pdf"
PREVIEW_OUTPUT = ROOT / "web" / "demo-menu-page-1.png"


def section(title, items):
    rows = [[Paragraph(f"<b>{title}</b>", styles["section"]), ""]]
    for name, price in items:
        rows.append([Paragraph(name, styles["item"]), Paragraph(price, styles["price"])])

    table = Table(rows, colWidths=[132 * mm, 24 * mm])
    table.setStyle(
        TableStyle(
            [
                ("SPAN", (0, 0), (1, 0)),
                ("BACKGROUND", (0, 0), (1, 0), colors.HexColor("#E8F6FC")),
                ("TEXTCOLOR", (0, 0), (1, 0), colors.HexColor("#0D1F2D")),
                ("BOX", (0, 0), (1, -1), 0.5, colors.HexColor("#D8EAFE")),
                ("INNERGRID", (0, 1), (1, -1), 0.25, colors.HexColor("#D8EAFE")),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]
        )
    )
    return table


styles = {
    "title": ParagraphStyle(
        "Title",
        fontName="Helvetica-Bold",
        fontSize=28,
        leading=32,
        textColor=colors.HexColor("#0D1F2D"),
        spaceAfter=4,
    ),
    "subtitle": ParagraphStyle(
        "Subtitle",
        fontName="Helvetica",
        fontSize=11,
        leading=15,
        textColor=colors.HexColor("#607D8B"),
        spaceAfter=18,
    ),
    "section": ParagraphStyle(
        "Section",
        fontName="Helvetica-Bold",
        fontSize=13,
        leading=16,
        textColor=colors.HexColor("#0D1F2D"),
    ),
    "item": ParagraphStyle(
        "Item",
        fontName="Helvetica",
        fontSize=10.5,
        leading=14,
        textColor=colors.HexColor("#0D1F2D"),
    ),
    "price": ParagraphStyle(
        "Price",
        fontName="Helvetica-Bold",
        fontSize=10.5,
        leading=14,
        alignment=2,
        textColor=colors.HexColor("#006687"),
    ),
    "note": ParagraphStyle(
        "Note",
        fontName="Helvetica",
        fontSize=9,
        leading=12,
        textColor=colors.HexColor("#607D8B"),
    ),
}


def build_menu():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        rightMargin=22 * mm,
        leftMargin=22 * mm,
        topMargin=20 * mm,
        bottomMargin=18 * mm,
    )

    story = [
        Paragraph("The Spice House", styles["title"]),
        Paragraph(
            "Indiranagar - Demo PDF Menu - Uploaded from backend field menuPdfUrl",
            styles["subtitle"],
        ),
        section(
            "Breakfast & Small Plates",
            [
                ("Masala Dosa with coconut chutney", "Rs 180"),
                ("Ghee podi idli", "Rs 160"),
                ("Paneer pepper fry", "Rs 290"),
                ("Crispy baby corn", "Rs 240"),
            ],
        ),
        Spacer(1, 10),
        section(
            "Mains",
            [
                ("North Indian thali with seasonal curries", "Rs 420"),
                ("Butter chicken with laccha paratha", "Rs 480"),
                ("Malabar vegetable stew with appam", "Rs 360"),
                ("Hyderabadi dum biryani", "Rs 440"),
            ],
        ),
        Spacer(1, 10),
        section(
            "Drinks & Desserts",
            [
                ("Filter coffee", "Rs 90"),
                ("Fresh lime soda", "Rs 110"),
                ("Mango kulfi", "Rs 160"),
                ("Gulab jamun with rabri", "Rs 190"),
            ],
        ),
        Spacer(1, 18),
        Paragraph(
            "Prices are sample demo values. Taxes and service charges may apply.",
            styles["note"],
        ),
    ]
    doc.build(story)


def draw_text(draw, xy, text, font, fill, anchor=None):
    draw.text(xy, text, font=font, fill=fill, anchor=anchor)


def build_preview():
    width, height = 1240, 1754
    margin = 110
    image = Image.new("RGB", (width, height), "#FFFFFF")
    draw = ImageDraw.Draw(image)

    title_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 58)
    subtitle_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 24)
    section_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 30)
    item_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 24)
    price_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 24)
    note_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 20)

    draw_text(draw, (margin, 95), "The Spice House", title_font, "#0D1F2D")
    draw_text(
        draw,
        (margin, 165),
        "Indiranagar - Demo PDF Menu - Uploaded from backend field menuPdfUrl",
        subtitle_font,
        "#607D8B",
    )

    sections = [
        (
            "Breakfast & Small Plates",
            [
                ("Masala Dosa with coconut chutney", "Rs 180"),
                ("Ghee podi idli", "Rs 160"),
                ("Paneer pepper fry", "Rs 290"),
                ("Crispy baby corn", "Rs 240"),
            ],
        ),
        (
            "Mains",
            [
                ("North Indian thali with seasonal curries", "Rs 420"),
                ("Butter chicken with laccha paratha", "Rs 480"),
                ("Malabar vegetable stew with appam", "Rs 360"),
                ("Hyderabadi dum biryani", "Rs 440"),
            ],
        ),
        (
            "Drinks & Desserts",
            [
                ("Filter coffee", "Rs 90"),
                ("Fresh lime soda", "Rs 110"),
                ("Mango kulfi", "Rs 160"),
                ("Gulab jamun with rabri", "Rs 190"),
            ],
        ),
    ]

    y = 240
    table_width = width - margin * 2
    for section_title, items in sections:
        draw.rounded_rectangle(
            (margin, y, margin + table_width, y + 64),
            radius=8,
            fill="#E8F6FC",
            outline="#D8EAFE",
            width=2,
        )
        draw_text(draw, (margin + 24, y + 20), section_title, section_font, "#0D1F2D")
        y += 64
        for item, price in items:
            draw.rectangle(
                (margin, y, margin + table_width, y + 62),
                fill="#FFFFFF",
                outline="#D8EAFE",
                width=1,
            )
            draw_text(draw, (margin + 24, y + 18), item, item_font, "#0D1F2D")
            draw_text(
                draw,
                (margin + table_width - 24, y + 18),
                price,
                price_font,
                "#006687",
                anchor="ra",
            )
            y += 62
        y += 30

    draw_text(
        draw,
        (margin, y + 20),
        "Prices are sample demo values. Taxes and service charges may apply.",
        note_font,
        "#607D8B",
    )
    image.save(PREVIEW_OUTPUT)


if __name__ == "__main__":
    build_menu()
    build_preview()
    print(OUTPUT)
    print(PREVIEW_OUTPUT)
