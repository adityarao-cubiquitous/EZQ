from pathlib import Path

from pypdf import PdfReader, PdfWriter
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(
    "/Users/adityasridhararao/Downloads/EZQ Product Architecture & Build Handout.pdf"
)
ADDENDUM = ROOT / "tmp/pdfs/ezq_handout_addendum_2026_06_22.pdf"
OUTPUT = ROOT / "output/pdf/EZQ Product Architecture & Build Handout - Updated 2026-06-22.pdf"


def styles():
    base = getSampleStyleSheet()
    base.add(
        ParagraphStyle(
            name="CoverTitle",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=24,
            leading=30,
            textColor=colors.HexColor("#0D1F2D"),
            spaceAfter=10,
        )
    )
    base.add(
        ParagraphStyle(
            name="SectionTitle",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=15,
            leading=19,
            textColor=colors.HexColor("#0D1F2D"),
            spaceBefore=12,
            spaceAfter=7,
        )
    )
    base.add(
        ParagraphStyle(
            name="SubTitle",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=11,
            leading=14,
            textColor=colors.HexColor("#006687"),
            spaceBefore=8,
            spaceAfter=4,
        )
    )
    base.add(
        ParagraphStyle(
            name="BodyTextEzq",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9.3,
            leading=12.3,
            textColor=colors.HexColor("#0D1F2D"),
            spaceAfter=5,
        )
    )
    base.add(
        ParagraphStyle(
            name="SmallMuted",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.2,
            leading=10.5,
            textColor=colors.HexColor("#607D8B"),
        )
    )
    base.add(
        ParagraphStyle(
            name="BulletEzq",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9,
            leading=11.8,
            leftIndent=10,
            firstLineIndent=-7,
            spaceAfter=3,
        )
    )
    return base


def p(text):
    return Paragraph(text, S["BodyTextEzq"])


def bullet(text):
    return Paragraph(f"- {text}", S["BulletEzq"])


def heading(text):
    return Paragraph(text, S["SectionTitle"])


def subheading(text):
    return Paragraph(text, S["SubTitle"])


def simple_table(rows, widths):
    table = Table(rows, colWidths=widths, hAlign="LEFT", repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8F6FC")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#0D1F2D")),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTNAME", (0, 1), (-1, -1), "Helvetica"),
                ("FONTSIZE", (0, 0), (-1, -1), 8),
                ("LEADING", (0, 0), (-1, -1), 10),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#D8EAFE")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8FBFE")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    return table


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#D8EAFE"))
    canvas.setLineWidth(0.4)
    canvas.line(18 * mm, 14 * mm, A4[0] - 18 * mm, 14 * mm)
    canvas.setFillColor(colors.HexColor("#607D8B"))
    canvas.setFont("Helvetica", 7.5)
    canvas.drawString(18 * mm, 9 * mm, "EZQ by Cubiquitous - Implementation Addendum - 2026-06-22")
    canvas.drawRightString(A4[0] - 18 * mm, 9 * mm, f"Addendum page {doc.page}")
    canvas.restoreState()


def build_addendum():
    ADDENDUM.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(ADDENDUM),
        pagesize=A4,
        rightMargin=18 * mm,
        leftMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
    )
    story = []

    story.append(Paragraph("EZQ Product Architecture & Build Handout", S["CoverTitle"]))
    story.append(Paragraph("Implementation Update Addendum", S["CoverTitle"]))
    story.append(p("Date: June 22, 2026"))
    story.append(
        p(
            "This addendum updates the original handout with the latest product and build decisions implemented in the EZQ development environment. It supersedes older references to cleaning state and reflects the current customer, manager, Firebase, and table lifecycle behavior."
        )
    )
    story.append(Spacer(1, 6))
    story.append(subheading("Current deployed environment"))
    for item in [
        "Firebase project: ezq-dev-cubiquitous.",
        "Hosting URL: https://ezq-dev-cubiquitous.web.app.",
        "Demo restaurant and branch: The Spice House, Indiranagar.",
        "Customer route: /customer/the-spice-house/indiranagar.",
        "Admin route: /admin/the-spice-house/indiranagar/dashboard.",
        "Manager authentication uses Firebase Authentication with email/password.",
    ]:
        story.append(bullet(item))

    story.append(heading("1. Product Decisions Updated Since Original Handout"))
    updates = [
        ["Area", "Latest decision"],
        ["Cleaning state", "Removed from MVP. Table lifecycle is now available -> reserved -> occupied -> available, with blocked kept as an administrative state."],
        ["Customer authentication", "Customer web app remains guest/no-email. Customers join by QR/web with name, phone, party size, and optional notes."],
        ["Admin authentication", "Manager/admin login uses Firebase email/password authentication."],
        ["Party size input", "Customer party size uses exact values rather than broad ranges; larger party sizes are supported through a picklist."],
        ["Menu", "Customer menu is a scrollable PDF-style page. The PDF URL is expected from backend branch configuration."],
        ["Wait engagement", "Ad space and hidden-object puzzle placement are present. Puzzle image is backend-driven with a placeholder until uploaded."],
        ["Table assignment", "Reserve asks the manager to select a table from a sorted picklist; choices are ordered by best capacity fit."],
    ]
    story.append(simple_table([[Paragraph(c, S["SmallMuted"]) for c in row] for row in updates], [38 * mm, 132 * mm]))

    story.append(heading("2. Current Customer Web Experience"))
    for item in [
        "Join Queue screen follows a compact, mobile-first iOS-style layout.",
        "Join Queue is disabled after a customer has already joined from that session/phone context.",
        "Queue Status screen shows restaurant, token, party size, queue position, remaining wait, and progress.",
        "Remaining wait now counts down on-screen instead of staying as a static estimate.",
        "Customer actions include View Menu and Cancel Reservation.",
        "Header includes a Get App option for future install flow.",
        "Powered by Cubiquitous appears below Cancel Reservation.",
        "Sponsored ad placeholder appears below the powered-by block.",
        "Hidden-object puzzle card now displays a backend-uploaded image. Until uploaded, it shows a clean placeholder.",
    ]:
        story.append(bullet(item))

    story.append(subheading("Backend fields for customer media"))
    media_rows = [
        ["Field", "Location", "Purpose"],
        ["menuPdfUrl", "branches/{branchId}", "Scrollable menu PDF source."],
        ["menuPreviewImageUrl", "branches/{branchId}", "Optional menu preview image."],
        ["hiddenObjectPuzzleImageUrl", "branches/{branchId}", "Uploaded hidden-object image for customer wait engagement."],
        ["waitPuzzleImageUrl", "branches/{branchId}", "Backward-compatible fallback for puzzle image."],
    ]
    story.append(simple_table([[Paragraph(c, S["SmallMuted"]) for c in row] for row in media_rows], [45 * mm, 45 * mm, 80 * mm]))

    story.append(PageBreak())
    story.append(heading("3. Current Admin Dashboard Experience"))
    for item in [
        "Dashboard is live against Firestore streams for queue entries and tables.",
        "Table grid is grouped and sorted by capacity: 2-top, 4-top, 6-top, 8-top, 10-top.",
        "Each table tile shows table number, status, token if linked, capacity, and occupied count.",
        "Location/section text such as main, bar, patio, and window was removed from table tiles for cleaner scanning.",
        "Available tables show Occ 0. Reserved and occupied tables show the linked queue party size.",
        "Reserved table tiles are actionable with Mark seated.",
        "Occupied table tiles are actionable with Meal finished and let the manager confirm the number of guests who finished.",
        "Live Queue panel supports Reserve and Skip. Reserve opens a table picklist sorted by best capacity fit.",
        "Topbar metrics show Free, Occupied, and Waiting counts.",
    ]:
        story.append(bullet(item))

    story.append(subheading("Current table tile states"))
    state_rows = [
        ["Table state", "Tile action", "Primary data shown"],
        ["available", "No direct action on tile", "Table number, Cap, Occ 0, available badge."],
        ["reserved", "Mark seated", "Table number, Cap, Occ party size, reserved badge, token."],
        ["occupied", "Meal finished", "Table number, Cap, Occ party size, occupied badge, token."],
        ["blocked", "No operational MVP action yet", "Reserved for future admin controls."],
    ]
    story.append(simple_table([[Paragraph(c, S["SmallMuted"]) for c in row] for row in state_rows], [36 * mm, 48 * mm, 86 * mm]))

    story.append(heading("4. Updated Table Lifecycle"))
    lifecycle = [
        "Manager reserves an available table for a queue entry.",
        "Queue entry becomes reserved and table becomes reserved.",
        "Customer status page changes to the table-ready/reserved state.",
        "When the customer arrives, manager clicks Mark seated on the reserved table tile.",
        "Queue entry becomes seated and table becomes occupied.",
        "When the meal is finished, manager clicks Meal finished and records guests completed.",
        "Queue entry becomes completed and table becomes available.",
        "The next customer for that table uses the previous completed end time as the next cycle start where applicable.",
    ]
    for item in lifecycle:
        story.append(bullet(item))

    story.append(subheading("Superseded handout sections"))
    for item in [
        "Section 8.4 Cleaning Flow is no longer part of MVP.",
        "Section 10.3 Table no longer uses cleaning as an allowed status for the active app flow.",
        "Section 12.2 Table Status Transitions should remove occupied -> cleaning and cleaning transitions.",
        "Section 21 Milestone 6 should remove Mark table cleaning from MVP acceptance.",
        "Section 22 MVP Acceptance Criteria should remove Mark table cleaning and Mark table available as separate cleaning-cycle requirements.",
    ]:
        story.append(bullet(item))

    story.append(PageBreak())
    story.append(heading("5. Current Firestore Model Additions"))
    model_rows = [
        ["Model", "Field", "Purpose"],
        ["Table", "capacity", "First-class table capacity used for grouping, sorting, and best-fit reserve picker."],
        ["Table", "currentQueueEntryId", "Links reserved/occupied table to the queue entry."],
        ["Table", "currentTokenCode", "Displays customer token on table tile."],
        ["Table", "currentCycleStartAt", "Tracks start of table cycle for seating/turnover reporting."],
        ["Table", "lastCycleStartAt / lastCycleEndAt", "Stores last completed table cycle."],
        ["QueueEntry", "assignedTableId / assignedTableNumber", "Tells customer which table is ready."],
        ["QueueEntry", "tableCycleStartAt / tableCycleEndAt", "Persists cycle timing on the customer visit."],
        ["QueueEntry", "completedPartySize", "Stores number of guests marked finished by manager."],
        ["Branch", "hiddenObjectPuzzleImageUrl", "Backend-uploaded waiting-game image placeholder."],
    ]
    story.append(simple_table([[Paragraph(c, S["SmallMuted"]) for c in row] for row in model_rows], [34 * mm, 58 * mm, 78 * mm]))

    story.append(heading("6. Updated Status Transitions"))
    transition_rows = [
        ["Entity", "Allowed MVP transitions"],
        ["Queue Entry", "waiting -> reserved; waiting -> skipped; waiting -> cancelled; reserved -> on_the_way; reserved -> seated; reserved -> no_show; reserved -> cancelled; on_the_way -> seated; on_the_way -> no_show; on_the_way -> cancelled; seated -> completed."],
        ["Table", "available -> reserved; available -> occupied; available -> blocked; reserved -> occupied; reserved -> available; occupied -> available; blocked -> available."],
    ]
    story.append(simple_table([[Paragraph(c, S["SmallMuted"]) for c in row] for row in transition_rows], [35 * mm, 135 * mm]))

    story.append(heading("7. Seed Data and Demo Readiness"))
    for item in [
        "Seed script now creates 14 tables for The Spice House Indiranagar.",
        "Table capacities include 2, 4, 6, 8, and 10 seats.",
        "Demo queue entries extend through Q35 with waiting, reserved, on_the_way, seated, and completed-like flows.",
        "Current dashboard is useful for testing capacity grouping, exact-fit reservation, seated transition, and meal-finished flow.",
        "Seed script path: tool/seed_firestore.mjs.",
    ]:
        story.append(bullet(item))

    story.append(heading("8. Implementation Status Snapshot"))
    status_rows = [
        ["Capability", "Current status"],
        ["Firebase project and hosting", "Implemented on ezq-dev-cubiquitous."],
        ["Customer web join flow", "Implemented and deployed."],
        ["Customer status page", "Implemented with live Firestore stream and countdown."],
        ["Admin login", "Implemented with Firebase Auth email/password."],
        ["Admin dashboard", "Implemented with capacity-grouped tables and live queue panel."],
        ["Reserve table", "Implemented with best-fit table picker."],
        ["Mark seated", "Implemented on reserved table tiles."],
        ["Meal finished", "Implemented on occupied table tiles with completed party size."],
        ["Menu PDF", "Implemented as backend URL driven customer menu page."],
        ["Hidden-object image", "Placeholder implemented; backend image upload/display path ready."],
        ["iOS simulator", "App has been run on iOS simulator during development."],
        ["Cloud Functions hardening", "Architecture remains Cloud Functions-first; some current Flutter repository writes are direct Firestore transactions and should be migrated/hardened as production work."],
    ]
    story.append(simple_table([[Paragraph(c, S["SmallMuted"]) for c in row] for row in status_rows], [55 * mm, 115 * mm]))

    doc.build(story, onFirstPage=footer, onLaterPages=footer)


def merge_pdf():
    writer = PdfWriter()
    for page in PdfReader(str(SOURCE)).pages:
        writer.add_page(page)
    for page in PdfReader(str(ADDENDUM)).pages:
        writer.add_page(page)
    with OUTPUT.open("wb") as handle:
        writer.write(handle)


if __name__ == "__main__":
    S = styles()
    build_addendum()
    merge_pdf()
    print(OUTPUT)
