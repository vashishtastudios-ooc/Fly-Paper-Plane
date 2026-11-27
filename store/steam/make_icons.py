"""Steam achievement icons for Paper Plane Playground.

Draws every achievement in ICONS as a 256x256 PNG sticker (achieved) plus a grey "_locked"
version, into store/steam/achievements/, and a contact sheet of them all.
Run from the repo root:  python store/steam/make_icons.py
Ids must match Profile.ACHIEVEMENTS in autoload/profile.gd (and the API names in Steamworks).
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "store", "steam", "achievements")
FONT = os.path.join(ROOT, "fonts", "CaveatBrush-Regular.ttf")
TITLE_FONT = os.path.join(ROOT, "fonts", "BarlowCondensed-SemiBold.ttf")

S = 4                     # supersampling
N = 256                   # final size
INK = (36, 50, 79)
PAPER = (251, 249, 242)
WHITE = (255, 255, 255)
GOLD = (242, 193, 78)
GOLD_DEEP = (217, 154, 43)
ORANGE = (255, 154, 51)
RED = (226, 90, 90)
PINK = (255, 126, 182)
SKY = (110, 198, 255)
GREEN = (111, 208, 140)
SEA = (47, 143, 191)
BRICK = (214, 110, 92)
LEAF = (88, 170, 92)
PURPLE = (150, 110, 210)
TEAL = (64, 186, 170)
SAND = (232, 196, 140)

CATEGORY = {
    "land": (111, 196, 130), "skill": (245, 178, 60), "far": (92, 170, 232), "air": (130, 190, 240),
    "collect": (255, 140, 90), "linden": (226, 122, 114), "harbour": (54, 140, 196),
    "oops": (166, 122, 220), "fun": (255, 120, 170),
}


def p(x, y):
    return (x * S, y * S)


def lw(w):
    return max(1, int(w * S))


class Pen:
    def __init__(self, img):
        self.img = img
        self.d = ImageDraw.Draw(img)
        self.tag = None

    def poly(self, pts, fill=None, outline=INK, width=6):
        q = [p(*a) for a in pts]
        if fill:
            self.d.polygon(q, fill=fill)
        if outline and width:
            self.d.line(q + [q[0]], fill=outline, width=lw(width), joint="curve")
            for a in q:
                r = lw(width) / 2
                self.d.ellipse((a[0] - r, a[1] - r, a[0] + r, a[1] + r), fill=outline)

    def line(self, pts, color=INK, width=6, round_ends=True):
        q = [p(*a) for a in pts]
        self.d.line(q, fill=color, width=lw(width), joint="curve")
        if round_ends:
            r = lw(width) / 2
            for a in (q[0], q[-1]):
                self.d.ellipse((a[0] - r, a[1] - r, a[0] + r, a[1] + r), fill=color)

    def circle(self, cx, cy, r, fill=None, outline=INK, width=6):
        box = (p(cx - r, cy - r), p(cx + r, cy + r))
        self.d.ellipse(box, fill=fill, outline=outline if width else None, width=lw(width) if width else 0)

    def rect(self, x0, y0, x1, y1, fill=None, outline=INK, width=6, radius=4):
        self.d.rounded_rectangle((p(x0, y0), p(x1, y1)), radius=radius * S, fill=fill,
                                 outline=outline if width else None, width=lw(width) if width else 0)

    def arc(self, cx, cy, r, a0, a1, color=INK, width=6):
        pts = []
        steps = max(8, int(abs(a1 - a0) / 6))
        for i in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * i / steps)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        self.line(pts, color, width)
        return pts

    def text(self, cx, cy, s, size, color=INK, font=FONT):
        f = ImageFont.truetype(font, int(size * S))
        self.d.text(p(cx, cy), s, font=f, fill=color, anchor="mm")


# --- Pictograms (256-unit coordinates, centred near (128, 120)) -------------------------------

def plane(pen, cx, cy, size=1.0, angle=-20, fill=WHITE, width=6):
    """A paper dart pointing right, rotated by angle (degrees, screen space)."""
    pts = [(62, 0), (-46, -34), (-26, 0), (-46, 30)]
    fold = [(62, 0), (-26, 0)]
    a = math.radians(angle)
    ca, sa = math.cos(a), math.sin(a)

    def tr(q):
        return (cx + (q[0] * ca - q[1] * sa) * size, cy + (q[0] * sa + q[1] * ca) * size)
    pen.poly([tr(q) for q in pts], fill=fill, width=width)
    # Shaded lower wing and the centre fold.
    pen.poly([tr(q) for q in [(62, 0), (-26, 0), (-46, 30)]], fill=(222, 232, 245), width=width)
    pen.line([tr(q) for q in fold], INK, width * 0.8)


def target(pen, cx, cy, r):
    for k, c in enumerate([WHITE, RED, WHITE, RED, GOLD]):
        rr = r * (1 - k * 0.19)
        pen.circle(cx, cy, rr, fill=c, width=5 if k == 0 else 0)
    pen.circle(cx, cy, r, width=6)


def ring(pen, cx, cy, r, color=ORANGE):
    pen.circle(cx, cy, r + 11, fill=INK, width=0)
    pen.circle(cx, cy, r + 6, fill=color, width=0)
    pen.circle(cx, cy, r - 6, fill=INK, width=0)
    pen.circle(cx, cy, r - 11, fill=(0, 0, 0, 0), width=0)   # punch the hole (the sticker shows through)
    pen.arc(cx, cy, r, 200, 250, (255, 230, 190), 4)


def star(pen, cx, cy, r, fill=GOLD, angle=-90):
    pts = []
    for i in range(10):
        a = math.radians(angle + i * 36)
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    pen.poly(pts, fill=fill, width=6)


def ribbon(pen, cx, cy, color=GOLD):
    pen.poly([(cx - 16, cy + 6), (cx - 34, cy + 66), (cx - 18, cy + 58), (cx - 8, cy + 74), (cx + 4, cy + 10)], fill=RED, width=6)
    pen.poly([(cx + 16, cy + 6), (cx + 34, cy + 66), (cx + 18, cy + 58), (cx + 8, cy + 74), (cx - 4, cy + 10)], fill=RED, width=6)
    pts = []
    for i in range(24):
        a = math.radians(i * 15)
        rr = 40 if i % 2 == 0 else 34
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    pen.poly(pts, fill=color, width=6)
    pen.circle(cx, cy, 22, fill=(255, 224, 140), width=5)


def clock(pen, cx, cy, r):
    pen.circle(cx, cy, r, fill=WHITE, width=7)
    for i in range(12):
        a = math.radians(i * 30)
        pen.line([(cx + math.cos(a) * r * 0.78, cy + math.sin(a) * r * 0.78), (cx + math.cos(a) * r * 0.88, cy + math.sin(a) * r * 0.88)], INK, 4)
    pen.line([(cx, cy), (cx, cy - r * 0.6)], INK, 7)
    pen.line([(cx, cy), (cx + r * 0.45, cy + r * 0.2)], INK, 7)


def cloud(pen, cx, cy, s=1.0, fill=WHITE):
    blobs = [(-30, 6, 22), (-6, -10, 28), (24, -2, 24), (40, 12, 16), (4, 14, 22), (-38, 18, 14)]
    for bx, by, br in blobs:
        pen.circle(cx + bx * s, cy + by * s, br * s + 3, fill=INK, width=0)
    for bx, by, br in blobs:
        pen.circle(cx + bx * s, cy + by * s, br * s - 3, fill=fill, width=0)


def house(pen, cx, cy, wall=(250, 214, 165), roof=BRICK):
    pen.rect(cx - 40, cy - 8, cx + 40, cy + 50, fill=wall, radius=3)
    pen.poly([(cx - 52, cy - 4), (cx, cy - 50), (cx + 52, cy - 4)], fill=roof)
    pen.rect(cx + 18, cy - 46, cx + 32, cy - 22, fill=roof, radius=2)
    pen.rect(cx - 30, cy + 4, cx - 8, cy + 26, fill=(170, 215, 245), width=5, radius=2)
    pen.line([(cx - 19, cy + 4), (cx - 19, cy + 26)], INK, 3)
    pen.rect(cx + 8, cy + 16, cx + 28, cy + 50, fill=(120, 170, 120), width=5, radius=2)


def lighthouse(pen, cx, cy):
    pen.poly([(cx - 22, cy + 56), (cx - 14, cy - 24), (cx + 14, cy - 24), (cx + 22, cy + 56)], fill=WHITE)
    for y0 in (cy - 6, cy + 30):
        pen.poly([(cx - 17.5, y0), (cx + 17.5, y0), (cx + 19.4, y0 + 14), (cx - 19.4, y0 + 14)], fill=RED, width=0)
    pen.poly([(cx - 22, cy + 56), (cx - 14, cy - 24), (cx + 14, cy - 24), (cx + 22, cy + 56)], fill=None)
    pen.rect(cx - 14, cy - 44, cx + 14, cy - 24, fill=GOLD, radius=2)
    pen.poly([(cx - 18, cy - 44), (cx, cy - 62), (cx + 18, cy - 44)], fill=RED)
    pen.line([(cx + 20, cy - 36), (cx + 56, cy - 50)], (255, 240, 170), 7)
    pen.line([(cx - 20, cy - 36), (cx - 56, cy - 50)], (255, 240, 170), 7)


def tree(pen, cx, cy):
    pen.rect(cx - 8, cy + 10, cx + 8, cy + 56, fill=(150, 100, 60), radius=2)
    for bx, by, br in [(0, -22, 34), (-26, 0, 26), (26, 2, 26), (0, 8, 28)]:
        pen.circle(cx + bx, cy + by, br + 3, fill=INK, width=0)
    for bx, by, br in [(0, -22, 34), (-26, 0, 26), (26, 2, 26), (0, 8, 28)]:
        pen.circle(cx + bx, cy + by, br - 3, fill=LEAF, width=0)
    pen.circle(cx - 12, cy - 30, 8, fill=(140, 210, 130), width=0)


def waves(pen, cx, cy, w=70, color=WHITE, width=6):
    pts = []
    for i in range(41):
        x = cx - w + 2 * w * i / 40
        pts.append((x, cy + math.sin(i / 40 * math.pi * 4) * 5))
    pen.line(pts, color, width)


def numberplate(pen, s, color):
    """Asks for the tier label tag; badge() draws it on top, outside the sticker clip."""
    pen.tag = s


def draw_tag(pen, s):
    """The tier label on a paper tag across the bottom."""
    w = 26 + 15 * len(s)
    pen.rect(128 - w / 2, 190, 128 + w / 2, 230, fill=PAPER, width=5, radius=8)
    pen.text(128, 208, s, 38, INK)


# --- Icon drawings -------------------------------------------------------------------------

def d_first_landing(pen):
    # The landing pad seen from a low angle: a squashed target, with the plane touching down.
    for k, c in enumerate([WHITE, RED, WHITE, GOLD]):
        rx, ry = 74 * (1 - k * 0.24), 24 * (1 - k * 0.24)
        pen.d.ellipse((p(128 - rx, 162 - ry), p(128 + rx, 162 + ry)), fill=c, outline=INK if k == 0 else None, width=lw(6) if k == 0 else 0)
    plane(pen, 122, 122, 0.8, 10)
    for x in (56, 70):
        pen.line([(x, 104), (x + 22, 108)], WHITE, 5)


def d_flight_school(pen):
    pen.poly([(128, 52), (210, 86), (128, 120), (46, 86)], fill=INK, outline=INK)
    pen.poly([(84, 104), (84, 140), (128, 156), (172, 140), (172, 104), (128, 120)], fill=(70, 90, 130))
    pen.line([(196, 92), (196, 140)], GOLD, 6)
    pen.circle(196, 146, 8, fill=GOLD, width=4)
    plane(pen, 112, 186, 0.6, -10)


def d_landings(pen, label):
    for k, (x, y, a) in enumerate([(92, 136, -8), (128, 116, -14), (164, 96, -20)]):
        plane(pen, x, y, 0.55, a)
    pen.line([(48, 168), (208, 168)], INK, 6)
    numberplate(pen, label, CATEGORY["land"])


def d_bullseye(pen):
    target(pen, 128, 132, 66)
    plane(pen, 150, 102, 0.6, 35)


def d_perfect_10(pen):
    ribbon(pen, 92, 96)
    ribbon(pen, 164, 96)
    numberplate(pen, "x10", CATEGORY["skill"])


def d_under_par(pen):
    clock(pen, 112, 116, 50)
    for k in range(3):
        pen.line([(170, 92 + k * 22), (210, 92 + k * 22)], WHITE, 7)
    plane(pen, 176, 156, 0.5, -10)
    numberplate(pen, "5", CATEGORY["skill"])


def d_distance(pen, label):
    pen.line([(40, 160), (216, 160)], INK, 6)
    for k in range(5):
        x = 52 + k * 38
        pen.line([(x, 160), (x, 146 if k % 2 == 0 else 152)], INK, 5)
    dash = [(46, 126), (80, 116), (112, 112)]
    for a, b in zip(dash[:-1], dash[1:]):
        pen.line([a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)], WHITE, 6)
    plane(pen, 160, 104, 0.75, -10)
    numberplate(pen, label, CATEGORY["far"])


def d_air(pen, label):
    cloud(pen, 96, 124, 1.0)
    cloud(pen, 176, 92, 0.6)
    plane(pen, 150, 140, 0.62, -18)
    numberplate(pen, label, CATEGORY["air"])


def d_rings(pen):
    ring(pen, 88, 112, 40)
    ring(pen, 168, 112, 40)
    plane(pen, 128, 120, 0.55, -6)
    numberplate(pen, "100", CATEGORY["collect"])


def d_stars(pen):
    star(pen, 128, 112, 54)
    star(pen, 66, 70, 18)
    star(pen, 194, 150, 16)
    numberplate(pen, "100", CATEGORY["collect"])


def d_rolls(pen):
    pen.arc(128, 116, 64, 200, 520, WHITE, 12)
    pen.poly([(186, 70), (206, 102), (170, 104)], fill=WHITE, outline=WHITE, width=2)
    plane(pen, 128, 116, 0.62, -35)
    numberplate(pen, "25", CATEGORY["collect"])


def d_thermals(pen):
    for x in (78, 128, 178):
        pts = [(x + math.sin(i / 10 * math.pi * 2) * 10, 172 - i * 10) for i in range(11)]
        pen.line(pts, (255, 236, 200), 8)
        pen.poly([(x - 14, 70), (x, 50), (x + 14, 70)], fill=(255, 236, 200), outline=(255, 236, 200), width=2)
    plane(pen, 128, 86, 0.5, -12)
    numberplate(pen, "50", CATEGORY["collect"])


def d_gusts(pen):
    pen.circle(88, 116, 44, fill=WHITE, width=6)
    pen.circle(74, 104, 6, fill=INK, width=0)
    pen.circle(100, 104, 6, fill=INK, width=0)
    pen.circle(104, 126, 10, fill=(255, 170, 170), width=4)
    for k, y in enumerate((96, 118, 140)):
        pen.line([(146, y), (204 - k * 12, y)], WHITE, 7)
    pen.arc(204, 110, 14, -90, 90, WHITE, 6)
    numberplate(pen, "100", CATEGORY["collect"])


def d_skips(pen):
    pen.rect(36, 146, 220, 236, fill=(80, 170, 220), width=0, radius=0)
    waves(pen, 128, 146, 92, INK, 6)
    for x0, x1, h in [(44, 100, 34), (100, 146, 26), (146, 184, 18)]:
        pen.arc((x0 + x1) / 2, 146, (x1 - x0) / 2, 180, 360, WHITE, 5)
        pen.circle(x1, 148, 6, fill=WHITE, outline=WHITE, width=2)
    plane(pen, 196, 120, 0.42, 8)
    numberplate(pen, "10", CATEGORY["collect"])


def d_secrets(pen):
    ring(pen, 104, 104, 36, PINK)
    pen.circle(156, 140, 34, fill=(220, 240, 255), width=7)
    pen.line([(180, 164), (210, 196)], INK, 14)
    pen.text(156, 140, "?", 50, INK)


def d_linden_all(pen):
    house(pen, 136, 122)
    plane(pen, 82, 76, 0.4, 14)


def d_linden_gold(pen):
    house(pen, 110, 120)
    ribbon(pen, 182, 92)


def d_harbour_all(pen):
    pen.rect(36, 160, 220, 236, fill=(80, 170, 220), width=0, radius=0)
    waves(pen, 128, 160, 92, INK, 6)
    lighthouse(pen, 112, 110)
    plane(pen, 178, 138, 0.38, -10)


def d_harbour_gold(pen):
    pen.rect(36, 160, 220, 236, fill=(80, 170, 220), width=0, radius=0)
    waves(pen, 128, 160, 92, INK, 6)
    lighthouse(pen, 96, 110)
    ribbon(pen, 182, 92)


def d_trees(pen):
    tree(pen, 112, 112)
    plane(pen, 150, 96, 0.5, 40, fill=(255, 238, 238))
    for a in (200, 250, 300):
        r = math.radians(a)
        pen.line([(168 + math.cos(r) * 22, 80 + math.sin(r) * 22), (168 + math.cos(r) * 34, 80 + math.sin(r) * 34)], WHITE, 5)
    numberplate(pen, "10", CATEGORY["oops"])


def d_splash(pen):
    # A folded paper boat on the water.
    pen.rect(36, 146, 220, 236, fill=(80, 170, 220), width=0, radius=0)
    waves(pen, 128, 146, 92, INK, 6)
    pen.poly([(66, 118), (190, 118), (168, 148), (88, 148)], fill=WHITE)
    pen.poly([(98, 118), (128, 66), (158, 118)], fill=(230, 238, 250))
    pen.line([(128, 66), (128, 118)], INK, 4)
    for x, y in [(56, 104), (206, 98), (48, 128)]:
        pen.poly([(x, y - 12), (x + 7, y + 2), (x, y + 8), (x - 7, y + 2)], fill=(200, 235, 255), width=4)
    numberplate(pen, "10", CATEGORY["oops"])


def d_crashes(pen):
    # A crumpled plane with a plaster, still smiling.
    pts = []
    for i in range(14):
        a = math.radians(i * 360 / 14)
        r = 48 if i % 2 == 0 else 38
        pts.append((128 + math.cos(a) * r, 112 + math.sin(a) * r))
    pen.poly(pts, fill=WHITE)
    for a, b in [((100, 96), (128, 112)), ((128, 112), (150, 90)), ((128, 112), (140, 142))]:
        pen.line([a, b], (170, 180, 200), 4)
    pen.circle(114, 108, 5, fill=INK, width=0)
    pen.circle(140, 108, 5, fill=INK, width=0)
    pen.arc(127, 118, 14, 20, 160, INK, 5)
    pen.d.polygon([p(84, 70), p(124, 90), p(118, 102), p(78, 82)], fill=(240, 200, 160))
    pen.poly([(84, 70), (124, 90), (118, 102), (78, 82)], fill=None, width=4)
    numberplate(pen, "100", CATEGORY["oops"])


# id -> (category, drawing, title, description, hidden)
ICONS = [
    ("first_landing", "land", d_first_landing),
    ("flight_school", "land", d_flight_school),
    ("landings_25", "land", lambda pen: d_landings(pen, "25")),
    ("landings_100", "land", lambda pen: d_landings(pen, "100")),
    ("bullseye", "skill", d_bullseye),
    ("perfect_10", "skill", d_perfect_10),
    ("under_par_5", "skill", d_under_par),
    ("dist_1k", "far", lambda pen: d_distance(pen, "1 km")),
    ("dist_10k", "far", lambda pen: d_distance(pen, "10 km")),
    ("air_10m", "air", lambda pen: d_air(pen, "10 min")),
    ("air_60m", "air", lambda pen: d_air(pen, "1 hour")),
    ("rings_100", "collect", d_rings),
    ("stars_100", "collect", d_stars),
    ("rolls_25", "collect", d_rolls),
    ("thermals_50", "collect", d_thermals),
    ("gusts_100", "collect", d_gusts),
    ("skips_10", "collect", d_skips),
    ("secrets", "skill", d_secrets),
    ("linden_all", "linden", d_linden_all),
    ("linden_gold", "linden", d_linden_gold),
    ("harbour_all", "harbour", d_harbour_all),
    ("harbour_gold", "harbour", d_harbour_gold),
    ("trees_10", "oops", d_trees),
    ("splash_10", "oops", d_splash),
    ("crashes_100", "oops", d_crashes),
]


def badge(category, draw):
    big = N * S
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    pen = Pen(img)
    col = CATEGORY[category]
    # Notebook paper card with faint rules and a red margin line.
    pen.rect(4, 4, 252, 252, fill=PAPER, outline=None, width=0, radius=34)
    for y in range(36, 252, 22):
        pen.line([(10, y), (246, y)], (200, 222, 240), 2, round_ends=False)
    pen.line([(34, 8), (34, 248)], (240, 170, 165), 2, round_ends=False)
    # The coloured sticker, with a soft shadow and a white cut edge.
    shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((p(26, 30), p(234, 238)), fill=(36, 50, 79, 90))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(6 * S)))
    pen.circle(128, 128, 106, fill=WHITE, width=0)
    pen.circle(128, 128, 96, fill=col, width=0)
    pen.arc(128, 128, 84, 200, 290, tuple(min(255, c + 45) for c in col), 8)
    # Clip the drawing to the sticker so ground strips stay inside the circle.
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    lp = Pen(layer)
    draw(lp)
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse((p(32, 32), p(224, 224)), fill=255)
    clipped = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    clipped.paste(layer, (0, 0), Image.composite(layer.getchannel("A"), Image.new("L", (big, big), 0), mask))
    img.alpha_composite(clipped)
    pen.circle(128, 128, 106, outline=INK, width=5)
    if lp.tag:
        draw_tag(pen, lp.tag)
    return img.resize((N, N), Image.LANCZOS)


def locked(img):
    rgb = ImageOps.grayscale(img.convert("RGB")).convert("RGB")
    rgb = Image.blend(rgb, Image.new("RGB", rgb.size, (190, 190, 196)), 0.45)
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for aid, cat, draw in ICONS:
        img = badge(cat, draw)
        flat = Image.new("RGB", img.size, PAPER)   # Steam wants opaque images
        flat.paste(img, (0, 0), img)
        flat.save(os.path.join(OUT, aid + ".png"))
        lk = locked(img)
        flat_l = Image.new("RGB", lk.size, (235, 235, 238))
        flat_l.paste(lk, (0, 0), lk)
        flat_l.save(os.path.join(OUT, aid + "_locked.png"))
        tiles.append((aid, flat, flat_l))
    # Contact sheet: 5 per row, achieved above, locked thumbnail beside the name.
    cols = 5
    cw, ch = 280, 330
    rows = math.ceil(len(tiles) / cols)
    sheet = Image.new("RGB", (cols * cw + 20, rows * ch + 20), (243, 240, 230))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.truetype(TITLE_FONT, 22)
    for i, (aid, a, l) in enumerate(tiles):
        x = 20 + (i % cols) * cw
        y = 20 + (i // cols) * ch
        sheet.paste(a, (x, y))
        sheet.paste(l.resize((48, 48), Image.LANCZOS), (x, y + 262))
        d.text((x + 58, y + 286), aid, font=f, fill=INK, anchor="lm")
    sheet.save(os.path.join(os.path.dirname(OUT), "achievement_sheet.png"))
    print("wrote", len(tiles), "icons to", OUT)


if __name__ == "__main__":
    main()
