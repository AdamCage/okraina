"""gen_ui.py — процедурный интерфейс «ЗОНА: Пикник на обочине».

Генерирует весь UI + иконки предметов в assets/ui: панели (9-slice-friendly,
рамка ~16 px по краю), кнопки, тач-HUD, декор HUD, текстовые плашки, 37 иконок
64x64 (читаемых в 32 px) и брендинг (logo/splash/icon_app).

Ассеты пишутся как PNG с альфой через P.save_ui(). Плюс MANIFEST.txt и
контрольные листы в tools/gen/_out.

Запуск: cd tools/gen; python gen_ui.py
"""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import paint as P

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_out")
FONT_PATH = os.path.join(P.UI, "Oswald.ttf")
FONT_PATH2 = os.path.join(P.UI, "PT_Sans-Narrow-Web-Regular.ttf")

SS_PANEL = 2      # суперсэмплинг панелей
SS_ICON = 4       # суперсэмплинг иконок и тач-глифов

# --------------------------------------------------------------------- палитра
HEX = {
    "black": "#0a0c0d",
    "ink": "#131618",
    "ink2": "#1b1f21",
    "steel0": "#1d2224",
    "steel1": "#282e30",
    "steel2": "#394143",
    "steel3": "#525b5b",
    "steel4": "#7b847e",
    "steel5": "#a7afa2",
    "olive0": "#1c2116",
    "olive1": "#2d341e",
    "olive2": "#464f2b",
    "olive3": "#687343",
    "olive4": "#8d9a5c",
    "rust0": "#2b1507",
    "rust1": "#54270c",
    "rust2": "#8b4318",
    "rust3": "#c06a22",
    "amber": "#e2a13c",
    "amber2": "#f2c46a",
    "toxic": "#7fcf36",
    "toxic2": "#b6f05a",
    "blood0": "#4d0b09",
    "blood": "#7e1410",
    "blood2": "#c02a1c",
    "blood3": "#e2563c",
    "cyan": "#38a7bd",
    "cyan2": "#7fdfe8",
    "cream": "#e3d9bd",
    "bone": "#bfb391",
    "brass": "#b98a2e",
    "brass2": "#e0b855",
    "copper": "#9a5a28",
    "glass": "#2b4a52",
}


def col(name, a=1.0):
    """Имя из HEX -> (r, g, b, a) во float 0..1."""
    if isinstance(name, str):
        r, g, b = P.hexa(HEX[name])
        return (r, g, b, float(a))
    return (name[0], name[1], name[2], float(a) if len(name) < 4 else name[3])


def rgb8(c, a=None):
    """Цвет в 8-битный RGBA-кортеж для PIL."""
    if isinstance(c, str):
        c = col(c)
    al = int(round((c[3] if len(c) > 3 else 1.0) * 255))
    if a is not None:
        al = int(round(a * 255))
    return (int(round(c[0] * 255)), int(round(c[1] * 255)), int(round(c[2] * 255)), al)


def mix(a, b, t):
    """Линейно смешать два RGBA-цвета."""
    a, b = col(a) if isinstance(a, str) else a, col(b) if isinstance(b, str) else b
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))


def flat(w, h, name, a=1.0):
    """Однотонная RGBA-картинка HxWx4."""
    c = col(name, a)
    arr = np.zeros((h, w, 4), np.float32)
    for i in range(4):
        arr[..., i] = c[i]
    return arr


def src_over(dst, src):
    """Правильный source-over двух RGBA-массивов."""
    sa = src[..., 3:4]
    da = dst[..., 3:4]
    oa = sa + da * (1.0 - sa)
    rgb = np.where(oa > 1e-6, (src[..., :3] * sa + dst[..., :3] * da * (1.0 - sa)) /
                   np.maximum(oa, 1e-6), 0.0)
    return np.concatenate([rgb, oa], -1).astype(np.float32)


# ---------------------------------------------------------------------- шум
def noise2(w, h, res=6, oct=4, seed=0, gain=0.5):
    """Квадратный fBm, обрезанный до HxW."""
    n = P.fbm(max(w, h), res, oct, gain=gain, seed=seed)
    return np.ascontiguousarray(n[:h, :w]).astype(np.float32)


def gate(w, h, seed, res=4, lo=0.45, hi=0.9, oct=4):
    """Мягкий гейт по шуму — пятна грязи/ржавчины."""
    n = noise2(w, h, res, oct, seed)
    return P.clamp01((n - lo) / max(hi - lo, 1e-4)).astype(np.float32)


def speck(w, h, count, seed, radius=1.1):
    """Мелкие «крошки» как маска."""
    r = np.random.default_rng(seed)
    acc = np.zeros((h, w), np.float32)
    ys = r.integers(0, h, max(count, 1))
    xs = r.integers(0, w, max(count, 1))
    acc[ys, xs] = 1.0
    img = Image.fromarray((acc * 255).astype(np.uint8), "L")
    return (np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), np.float32) / 255.0)


def scratch_mask(w, h, seed, count=40, lo=8.0, hi=46.0, value=0.55):
    """Царапины: тонкие линии под случайными углами."""
    r = np.random.default_rng(seed)
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = r.uniform(0, w), r.uniform(0, h)
        ang = r.uniform(0, math.tau)
        ln = r.uniform(lo, hi)
        v = int(255 * value * r.uniform(0.45, 1.0))
        d.line([x, y, x + math.cos(ang) * ln, y + math.sin(ang) * ln], fill=v, width=1)
    return (np.asarray(img, np.float32) / 255.0)


def grainize(arr, seed, strength=0.12, res=64, oct=3):
    """Зерно/грязь: множитель яркости только там, где есть альфа."""
    if strength <= 0.0:
        return arr
    h, w = arr.shape[:2]
    n = noise2(w, h, res, oct, seed, gain=0.55)
    f = 1.0 + (n[..., None] - 0.5) * 2.0 * strength
    m = P.clamp01(arr[..., 3:4])
    out = arr.copy()
    out[..., :3] = np.clip(arr[..., :3] * (1.0 - m + m * f), 0.0, 1.0)
    return out


def tint(arr, m, name, amount=1.0):
    """Подмешать цвет по маске (аналог P.tint_mask, но для RGBA)."""
    mm = P.clamp01(m * amount)[..., None]
    c = np.asarray(col(name)[:3], np.float32)[None, None, :]
    out = arr.copy()
    out[..., :3] = arr[..., :3] * (1.0 - mm) + c * mm
    return out


def inner_shadow(arr, border=16, depth=0.5, soft=9.0):
    """Затемнение у внутренней кромки рамки — панель выглядит утопленной."""
    h, w = arr.shape[:2]
    ys = np.arange(h, dtype=np.float32)[:, None]
    xs = np.arange(w, dtype=np.float32)[None, :]
    dd = np.minimum(np.minimum(ys - border, xs - border),
                    np.minimum(h - border - ys, w - border - xs))
    f = 1.0 - depth * (1.0 - np.clip(dd / soft, 0.0, 1.0))
    out = arr.copy()
    out[..., :3] = np.clip(out[..., :3] * f[..., None], 0.0, 1.0)
    return out


def toast(arr, seed, grime=0.30, rust=0.35, scratch=34, dust=90):
    """Общий «грязный» пост-процесс: ржавчина, копоть, царапины, крошки."""
    h, w = arr.shape[:2]
    out = tint(arr, gate(w, h, seed + 11, 4, 0.52, 0.95), "rust1", rust * 0.8)
    out = tint(out, gate(w, h, seed + 23, 7, 0.58, 0.98), "rust2", rust * 0.45)
    out = tint(out, gate(w, h, seed + 31, 3, 0.55, 0.99), "black", grime * 0.55)
    out = tint(out, scratch_mask(w, h, seed + 41, scratch), "steel5", 0.16)
    out = tint(out, speck(w, h, dust, seed + 57, 0.9), "steel0", 0.30)
    return grainize(out, seed + 71, 0.13)


# ------------------------------------------------------------------- рисование
class Pen:
    """Рисование фигур в дизайн-координатах 0..size с суперсэмплингом."""

    def __init__(self, size, ss=SS_ICON, bg=None):
        self.size = size
        self.ss = ss
        self.img = Image.new("RGBA", (size * ss, size * ss),
                             rgb8(bg) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img, "RGBA")

    def _p(self, pts):
        s = self.ss
        return [(float(x) * s, float(y) * s) for x, y in pts]

    def _w(self, w):
        return max(1, int(round(w * self.ss)))

    def poly(self, pts, fill=None, line=None, w=1.6):
        p = self._p(pts)
        if fill is not None:
            self.d.polygon(p, fill=rgb8(fill))
        if line is not None:
            self.d.line(p + [p[0]], fill=rgb8(line), width=self._w(w), joint="curve")
        return self

    def rect(self, x0, y0, x1, y1, fill=None, line=None, w=1.6, r=0.0):
        box = [x0 * self.ss, y0 * self.ss, x1 * self.ss, y1 * self.ss]
        rad = int(r * self.ss)
        if fill is not None:
            self.d.rounded_rectangle(box, radius=rad, fill=rgb8(fill))
        if line is not None:
            self.d.rounded_rectangle(box, radius=rad, outline=rgb8(line), width=self._w(w))
        return self

    def circ(self, cx, cy, rad, fill=None, line=None, w=1.6):
        box = [(cx - rad) * self.ss, (cy - rad) * self.ss,
               (cx + rad) * self.ss, (cy + rad) * self.ss]
        if fill is not None:
            self.d.ellipse(box, fill=rgb8(fill))
        if line is not None:
            self.d.ellipse(box, outline=rgb8(line), width=self._w(w))
        return self

    def ell(self, x0, y0, x1, y1, fill=None, line=None, w=1.6):
        box = [x0 * self.ss, y0 * self.ss, x1 * self.ss, y1 * self.ss]
        if fill is not None:
            self.d.ellipse(box, fill=rgb8(fill))
        if line is not None:
            self.d.ellipse(box, outline=rgb8(line), width=self._w(w))
        return self

    def line(self, pts, c, w=1.6):
        p = self._p(pts)
        self.d.line(p, fill=rgb8(c), width=self._w(w), joint="curve")
        rr = self._w(w) / 2.0
        for x, y in (p[0], p[-1]):          # скруглённые концы
            self.d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=rgb8(c))
        return self

    def arc(self, cx, cy, rad, a0, a1, c, w=1.6):
        box = [(cx - rad) * self.ss, (cy - rad) * self.ss,
               (cx + rad) * self.ss, (cy + rad) * self.ss]
        self.d.arc(box, a0, a1, fill=rgb8(c), width=self._w(w))
        return self

    def text(self, xy, s, fnt, c="cream", anchor="mm", stroke=0, stroke_c="ink"):
        self.d.text((xy[0] * self.ss, xy[1] * self.ss), s, font=fnt, fill=rgb8(c),
                    anchor=anchor, stroke_width=self._w(stroke) if stroke else 0,
                    stroke_fill=rgb8(stroke_c))
        return self

    def rgba(self, seed=0, grain=0.07, res=48):
        img = self.img.resize((self.size, self.size), Image.LANCZOS)
        arr = np.asarray(img, np.float32) / 255.0
        return grainize(arr, seed, grain, res)

    def save(self, name, seed=0, grain=0.07, res=48):
        arr = self.rgba(seed, grain, res)
        P.save_ui(name, P.to_image(arr))
        return arr


def font(px, title=True):
    """Шрифт с кириллицей; если не загрузился — None (рисуем фигурами)."""
    cands = [FONT_PATH, FONT_PATH2, r"C:\Windows\Fonts\arialbd.ttf",
             r"C:\Windows\Fonts\tahomabd.ttf", r"C:\Windows\Fonts\segoeuib.ttf"]
    if not title:
        cands = cands[1:] + cands[:1]
    for path in cands:
        try:
            f = ImageFont.truetype(path, int(px))
        except Exception:
            continue
        if f.getbbox("ЗОНА"):
            return f
    return None


def crisp(w, h, fn, ss=SS_PANEL):
    """Отрисовать фигуры на прозрачном холсте с суперсэмплингом -> RGBA float."""
    img = Image.new("RGBA", (int(w * ss), int(h * ss)), (0, 0, 0, 0))
    fn(ImageDraw.Draw(img, "RGBA"), ss)
    im = img.resize((int(w), int(h)), Image.LANCZOS)
    return np.asarray(im, np.float32) / 255.0


def bolts(d, s, w, h, border, rad=3.0, c_out="ink", c_in="steel2", c_hi="steel5"):
    """Четыре болта по углам — в зоне рамки (не мешают 9-slice)."""
    off = border * 0.5
    for cx, cy in ((off, off), (w - off, off), (off, h - off), (w - off, h - off)):
        d.ellipse([(cx - rad) * s, (cy - rad) * s, (cx + rad) * s, (cy + rad) * s],
                  fill=rgb8(c_in), outline=rgb8(c_out), width=max(1, int(s)))
        d.arc([(cx - rad * 0.7) * s, (cy - rad * 0.7) * s,
               (cx + rad * 0.7) * s, (cy + rad * 0.7) * s], 170, 320,
              fill=rgb8(c_hi), width=max(1, int(s)))
        d.ellipse([(cx - rad * 0.35) * s, (cy - rad * 0.35) * s,
                   (cx + rad * 0.35) * s, (cy + rad * 0.35) * s], fill=rgb8("ink"))


# --------------------------------------------------------------------- панели
def plate(w, h, seed, *, border=16, radius=6, body="steel1", band="steel0",
          alpha=1.0, alpha_band=1.0, bevel="steel3", shadow=0.5,
          rust=0.30, grime=0.26, weld=True):
    """Основа панели: рамка border px + матовое тело. Возвращает RGBA float."""
    border = max(1, min(int(border), min(w, h) // 2 - 1))
    def shapes(d, s):
        def R(v):
            return float(v * s)
        d.rounded_rectangle([0, 0, R(w) - 1, R(h) - 1], radius=R(radius),
                            fill=rgb8(col(band, alpha_band)))
        d.rounded_rectangle([R(border), R(border), R(w - border) - 1, R(h - border) - 1],
                            radius=R(max(radius - 1, 1)), fill=rgb8(col(body, alpha)))
        if weld:
            # стык посередине рамки сверху/снизу — «сварной шов»
            for y in (border * 0.5, h - border * 0.5):
                d.line([R(border * 1.6), R(y), R(w - border * 1.6), R(y)],
                       fill=rgb8(col("steel3", 0.30 * alpha_band)), width=max(1, int(s)))
        # фаска: свет сверху/слева, тень снизу/справа (в 2 px от кромки тела)
        t = max(1, int(2 * s))
        d.line([R(border + 1), R(border + 1), R(w - border - 2), R(border + 1)],
               fill=rgb8(col(bevel, 0.55 * alpha)), width=t)
        d.line([R(border + 1), R(border + 1), R(border + 1), R(h - border - 2)],
               fill=rgb8(col(bevel, 0.40 * alpha)), width=t)
        d.line([R(border + 1), R(h - border - 2), R(w - border - 2), R(h - border - 2)],
               fill=rgb8(col("ink", 0.75 * alpha)), width=t)
        d.line([R(w - border - 2), R(border + 1), R(w - border - 2), R(h - border - 2)],
               fill=rgb8(col("ink", 0.60 * alpha)), width=t)
    base = crisp(w, h, shapes)
    arr = toast(base, seed, rust=rust, grime=grime,
                scratch=max(12, (w + h) // 18), dust=max(30, (w * h) // 220))
    return inner_shadow(arr, border, shadow, 9.0)


def accent_frame(w, h, *, border=16, radius=6, accent="rust2", thick=1.6,
                 glow=False, bolts_on=True, bolt_rad=3.0, inner_line=True,
                 alpha=1.0, corners=True):
    """Резкий слой поверх панели: контур акцента, болты, уголки. RGBA float."""
    def shapes(d, s):
        def R(v):
            return float(v * s)
        tw = max(1, int(round(thick * s)))
        d.rounded_rectangle([R(thick), R(thick), R(w) - 1 - R(thick), R(h) - 1 - R(thick)],
                            radius=R(radius), outline=rgb8(col(accent, alpha)), width=tw)
        if inner_line:
            d.rounded_rectangle([R(border - 1.2), R(border - 1.2),
                                 R(w - border + 1.2) - 1, R(h - border + 1.2) - 1],
                                radius=R(max(radius - 1, 1)),
                                outline=rgb8(col("ink", 0.95 * alpha)), width=max(1, int(s)))
        if corners:
            for cx, cy in ((border * 0.5, border * 0.5), (w - border * 0.5, border * 0.5),
                           (border * 0.5, h - border * 0.5), (w - border * 0.5, h - border * 0.5)):
                d.rectangle([R(cx) - R(1.4), R(cy) - R(1.4), R(cx) + R(1.4), R(cy) + R(1.4)],
                            fill=rgb8(col(accent, 0.55 * alpha)))
        if bolts_on:
            bolts(d, s, w, h, border, bolt_rad)
    return crisp(w, h, shapes)


def glow_frame(w, h, *, color="rust3", band=4.0, thick=1.6, alpha=0.75):
    """Мягкое свечение по кромке (для выделенного слота/кнопки)."""
    def shapes(d, s):
        d.rounded_rectangle([0, 0, w * s - 1, h * s - 1], radius=int(6 * s),
                            outline=rgb8(col(color, alpha)), width=max(1, int(round(band * s))))
    layer = crisp(w, h, shapes)
    img = Image.fromarray((P.clamp01(layer[..., 3]) * 255).astype(np.uint8), "L")
    blur = np.asarray(img.filter(ImageFilter.GaussianBlur(2.2)), np.float32) / 255.0
    out = layer.copy()
    out[..., 3] = np.clip(layer[..., 3] * 0.35 + blur, 0.0, 1.0)
    return out


# ------------------------------------------------------------------- вывод/учёт
PRODUCED: dict[str, dict] = {}


def save_u(name, arr, border=0, note=""):
    """Сохранить PNG с альфой и запомнить параметры для MANIFEST."""
    P.save_ui(name, P.to_image(arr))
    PRODUCED[name] = {"w": int(arr.shape[1]), "h": int(arr.shape[0]),
                      "border": int(border), "note": note}
    return arr


# --------------------------------------------------------------------- панели
def panel_window():
    w, h = 320, 240
    a = plate(w, h, 1001, border=16, radius=6, body="steel1", band="steel0",
              shadow=0.5, rust=0.32)
    a = src_over(a, accent_frame(w, h, border=16, radius=6, accent="rust2",
                                 thick=1.6, bolt_rad=3.4))
    save_u("panel_window", a, 16, "главное окно: тёмная сталь, оранжевый кант, болты")
    return a


def panel_window_light():
    w, h = 320, 240
    a = plate(w, h, 1002, border=16, radius=6, body="steel1", band="steel0",
              alpha=0.62, alpha_band=0.74, shadow=0.35, rust=0.22, grime=0.2)
    a = src_over(a, accent_frame(w, h, border=16, radius=6, accent="rust2",
                                 thick=1.4, bolt_rad=3.0, alpha=0.85, inner_line=False))
    save_u("panel_window_light", a, 16, "полупрозрачное окно поверх боя")
    return a


def panel_tooltip():
    w, h = 256, 128
    a = plate(w, h, 1003, border=12, radius=5, body="olive1", band="olive0",
              alpha=0.95, alpha_band=0.97, bevel="olive3", shadow=0.42, rust=0.24, grime=0.22)
    a = src_over(a, accent_frame(w, h, border=12, radius=5, accent="amber",
                                 thick=1.5, bolt_rad=2.6, corners=False, inner_line=False))
    save_u("panel_tooltip", a, 12, "подсказка предмета: олива + янтарный кант")
    return a


def panel_slot(name, accent, seed, glow=False, note=""):
    w = h = 72
    a = plate(w, h, seed, border=12, radius=5, body="steel0", band="steel2",
              bevel="steel4", shadow=0.6, rust=0.3, grime=0.28, weld=False)
    a = src_over(a, accent_frame(w, h, border=12, radius=5, accent=accent, thick=1.5,
                                 bolt_rad=2.4, inner_line=True, corners=True))
    if glow:
        a = src_over(glow_frame(w, h, color=accent, band=3.0, alpha=0.55), a)
    save_u(name, a, 12, note)
    return a


def panel_divider():
    w, h = 192, 16
    def shapes(d, s):
        d.rectangle([0, 0, w * s, h * s], fill=rgb8(col("rust1", 0.95)))
        d.rectangle([0, 3 * s, w * s, 7 * s], fill=rgb8(col("rust2", 0.95)))
        d.rectangle([0, 5 * s, w * s, 6 * s], fill=rgb8(col("rust0", 0.85)))
        d.line([0, 1 * s, w * s, 1 * s], fill=rgb8(col("amber", 0.55)), width=max(1, int(s)))
        d.line([0, 14 * s, w * s, 14 * s], fill=rgb8(col("ink", 0.85)), width=max(1, int(s)))
        d.line([0, 15 * s, w * s, 15 * s], fill=rgb8(col("black", 0.7)), width=max(1, int(s)))
    a = crisp(w, h, shapes)
    a = toast(a, 1004, rust=0.5, grime=0.3, scratch=26, dust=120)
    # затухание к краям — плашка выглядит «обрубленной» с двух сторон
    fade = np.clip(np.minimum(np.arange(w), w - 1 - np.arange(w)) / 10.0, 0.15, 1.0)
    a[..., 3] *= fade[None, :]
    a = src_over(a, crisp(w, h, lambda d, s: (
        d.rectangle([8 * s, 4 * s, 12 * s, 11 * s], fill=rgb8(col("steel1"))),
        d.rectangle([10 * s, 4 * s, 12 * s, 11 * s], fill=rgb8(col("ink", 0.6))),
        d.rectangle([(w - 12) * s, 4 * s, (w - 8) * s, 11 * s], fill=rgb8(col("steel1"))),
        d.rectangle([(w - 12) * s, 4 * s, (w - 10) * s, 11 * s], fill=rgb8(col("ink", 0.6))))))
    save_u("panel_divider", a, 0, "горизонтальный разделитель-ржавая рейка (тайлится)")
    return a


def bar_frame(name, seed, w=256, h=32, border=8, accent="steel4", face="steel1",
              note=""):
    a = plate(w, h, seed, border=border, radius=3, body=face, band="steel2",
              bevel="steel5", shadow=0.75, rust=0.34, grime=0.3, weld=False)
    a = src_over(a, accent_frame(w, h, border=border, radius=3, accent=accent,
                                 thick=1.2, bolts_on=False, corners=True, inner_line=True))
    save_u(name, a, border, note)
    return a


def bar_fill(name, c_top, c_mid, c_low, seed, w=256, h=16, streaks=0.42, note=""):
    """Градиентная полоса заполнения (тянется по X, поэтому профиль постоянный)."""
    ts = np.array([0.0, 0.10, 0.42, 1.0], np.float32)
    ck = np.array([col(c_top)[:3], col(c_mid)[:3], col(c_mid)[:3], col(c_low)[:3]], np.float32)
    yy = np.linspace(0.0, 1.0, h, dtype=np.float32)
    profile = np.stack([np.interp(yy, ts, ck[:, i]) for i in range(3)], -1)   # h x 3
    rgb = np.repeat(profile[:, None, :], w, axis=1)
    # продольные потёртости
    n = noise2(w, h, 26, 3, seed, gain=0.55)
    rgb *= (1.0 - streaks * 0.5 + streaks * n)[..., None]
    # тонкая вертикальная «накатка» по X
    rib = 1.0 + 0.05 * np.sin(np.arange(w, dtype=np.float32) * 1.15)
    rgb *= rib[None, :, None]
    arr = np.concatenate([np.clip(rgb, 0.0, 1.0), np.ones((h, w, 1), np.float32)], -1)
    arr = toast(arr, seed + 5, rust=0.18, grime=0.14, scratch=8, dust=40)
    # ржавые проплешины по кромкам
    arr = tint(arr, np.clip(1.0 - np.abs(np.linspace(-1, 1, h))[:, None], 0, 1) ** 2, "rust1", 0.35)
    save_u(name, arr, 0, note)
    return arr


def rivet(d, s, cx, cy, rad=3.0, c_in="steel2", c_out="ink", c_hi="steel5"):
    """Одиночная заклёпка (для круглых кнопок и корпусов)."""
    d.ellipse([(cx - rad) * s, (cy - rad) * s, (cx + rad) * s, (cy + rad) * s],
              fill=rgb8(c_in), outline=rgb8(c_out), width=max(1, int(s)))
    d.arc([(cx - rad * 0.72) * s, (cy - rad * 0.72) * s,
           (cx + rad * 0.72) * s, (cy + rad * 0.72) * s], 170, 320,
          fill=rgb8(c_hi), width=max(1, int(s)))
    d.ellipse([(cx - rad * 0.3) * s, (cy - rad * 0.3) * s,
               (cx + rad * 0.3) * s, (cy + rad * 0.3) * s], fill=rgb8("ink"))


# -------------------------------------------------------------------- кнопки
def button(name, seed, *, body="steel1", band="steel2", bevel="steel5",
           accent="rust2", alpha=1.0, shadow=0.55, pressed=False, note=""):
    w, h = 256, 64
    def shapes(d, s):
        R = lambda v: float(v * s)
        d.rounded_rectangle([0, 0, R(w) - 1, R(h) - 1], radius=R(8), fill=rgb8(col(band, alpha)))
        d.rounded_rectangle([R(12), R(12), R(w - 12) - 1, R(h - 12) - 1], radius=R(6),
                            fill=rgb8(col(body, alpha)))
        t = max(1, int(2 * s))
        light, dark = (col("ink", 0.8 * alpha), col(bevel, 0.55 * alpha)) if pressed \
            else (col(bevel, 0.55 * alpha), col("ink", 0.8 * alpha))
        d.line([R(13), R(13), R(w - 14), R(13)], fill=rgb8(light), width=t)
        d.line([R(13), R(13), R(13), R(h - 14)], fill=rgb8(light), width=t)
        d.line([R(13), R(h - 14), R(w - 14), R(h - 14)], fill=rgb8(dark), width=t)
        d.line([R(w - 14), R(13), R(w - 14), R(h - 14)], fill=rgb8(dark), width=t)
        # «накатка» на рамке: насечки по верху и низу
        for i in range(1, 10):
            x = R(12) + (R(w - 24) / 10.0) * i
            d.line([x, R(5.5), x, R(10.5)], fill=rgb8(col("steel4", 0.30 * alpha)),
                   width=max(1, int(s)))
            d.line([x, R(h - 10.5), x, R(h - 5.5)], fill=rgb8(col("ink", 0.5 * alpha)),
                   width=max(1, int(s)))
    a = plate(w, h, 0, border=12, radius=8, body=body, band=band, bevel=bevel, alpha=alpha,
              shadow=shadow, rust=0.26, grime=0.24, weld=False)
    a = src_over(a, crisp(w, h, shapes))
    a = src_over(a, accent_frame(w, h, border=12, radius=8, accent=accent, thick=1.5,
                                 bolt_rad=3.0, inner_line=True, corners=True, alpha=alpha))
    if pressed:
        a = inner_shadow(a, 12, 0.6, 7.0)
    save_u(name, a, 12, note)
    return a


def button_round(name, seed, *, body="olive1", band="steel1", accent="rust2",
                 alpha=1.0, pressed=False, note=""):
    w = h = 128
    def shapes(d, s):
        R = lambda v: float(v * s)
        c_body = col(body, alpha) if not pressed else col(mix(body, "black", 0.35), alpha)
        d.ellipse([R(2), R(2), R(w - 2), R(h - 2)], fill=rgb8(col(band, alpha)),
                  outline=rgb8(col("ink", 0.9)))
        d.ellipse([R(11), R(11), R(w - 11), R(h - 11)], fill=rgb8(c_body))
        d.ellipse([R(26), R(26), R(w - 26), R(h - 26)],
                  fill=rgb8(col(mix(body, "black", 0.42), alpha)),
                  outline=rgb8(col("ink", 0.85)), width=max(1, int(1.6 * s)))
        a0, a1 = (10, 170) if pressed else (190, 350)
        d.arc([R(12), R(12), R(w - 12), R(h - 12)], a0, a1,
              fill=rgb8(col("ink", 0.75)), width=max(1, int(2 * s)))
        d.arc([R(12), R(12), R(w - 12), R(h - 12)], a1, a0 + 360,
              fill=rgb8(col("steel5", 0.5)), width=max(1, int(2 * s)))
        for ang in (45, 135, 225, 315):
            rivet(d, s, w / 2 + math.cos(math.radians(ang)) * 46,
                  h / 2 + math.sin(math.radians(ang)) * 46, 3.4)
    a = crisp(w, h, shapes)
    a = toast(a, 2000 + seed, rust=0.28, grime=0.22, scratch=22, dust=90)
    a = src_over(a, crisp(w, h, lambda d, s: d.ellipse(
        [2 * s, 2 * s, (w - 2) * s, (h - 2) * s], outline=rgb8(col(accent, 0.9 * alpha)),
        width=max(1, int(round(2.0 * s))))))
    if pressed:
        a = inner_shadow(a, 12, 0.4, 8.0)
    save_u(name, a, 0, note)
    return a


# ------------------------------------------------------------------ джойстик
def joy_base():
    """Полупрозрачное кольцо зоны джойстика (центр пустой)."""
    w = h = 256
    def shapes(d, s):
        R = lambda v: float(v * s)
        d.ellipse([R(4), R(4), R(w - 4), R(h - 4)], fill=rgb8(col("black", 0.16)))
        d.ellipse([R(4), R(4), R(w - 4), R(h - 4)], outline=rgb8(col("steel2", 0.55)),
                  width=max(1, int(9 * s)))
        d.ellipse([R(4), R(4), R(w - 4), R(h - 4)], outline=rgb8(col("ink", 0.55)),
                  width=max(1, int(2 * s)))
        d.ellipse([R(24), R(24), R(w - 24), R(h - 24)], outline=rgb8(col("amber", 0.28)),
                  width=max(1, int(1.6 * s)))
        d.ellipse([R(60), R(60), R(w - 60), R(h - 60)], outline=rgb8(col("steel4", 0.22)),
                  width=max(1, int(1.2 * s)))
        for ang in range(0, 360, 45):
            a = math.radians(ang)
            x0 = w / 2 + math.cos(a) * 96
            y0 = h / 2 + math.sin(a) * 96
            x1 = w / 2 + math.cos(a) * 112
            y1 = h / 2 + math.sin(a) * 112
            d.line([R(x0), R(y0), R(x1), R(y1)], fill=rgb8(col("steel4", 0.45)),
                   width=max(1, int(3 * s)))
    a = crisp(w, h, shapes, ss=SS_ICON)
    a = toast(a, 3001, rust=0.20, grime=0.18, scratch=16, dust=60)
    save_u("joy_base", a, 0, "кольцо зоны джойстика (полупрозрачное)")
    return a


def joy_knob():
    """Металлический грибок джойстика."""
    w = h = 128
    def shapes(d, s):
        R = lambda v: float(v * s)
        d.ellipse([R(3), R(3), R(w - 3), R(h - 3)], fill=rgb8(col("ink")),
                  outline=rgb8(col("black")))
        d.ellipse([R(7), R(7), R(w - 7), R(h - 7)], fill=rgb8(col("steel2")))
        d.ellipse([R(13), R(13), R(w - 13), R(h - 13)], fill=rgb8(col("steel3")))
        d.ellipse([R(20), R(20), R(w - 20), R(h - 20)], fill=rgb8(col("steel1")))
        d.arc([R(8), R(8), R(w - 8), R(h - 8)], 185, 355, fill=rgb8(col("steel5", 0.7)),
              width=max(1, int(2.4 * s)))
        d.arc([R(8), R(8), R(w - 8), R(h - 8)], 8, 172, fill=rgb8(col("black", 0.75)),
              width=max(1, int(2.4 * s)))
        # крестовая накатка в центре
        d.line([R(40), R(64), R(88), R(64)], fill=rgb8(col("ink", 0.85)), width=max(1, int(4 * s)))
        d.line([R(64), R(40), R(64), R(88)], fill=rgb8(col("ink", 0.85)), width=max(1, int(4 * s)))
        d.line([R(40), R(63), R(88), R(63)], fill=rgb8(col("steel4", 0.5)), width=max(1, int(2 * s)))
        d.line([R(63), R(40), R(63), R(88)], fill=rgb8(col("steel4", 0.5)), width=max(1, int(2 * s)))
        for ang in (0, 90, 180, 270):
            a = math.radians(ang)
            rivet(d, s, w / 2 + math.cos(a) * 26, h / 2 + math.sin(a) * 26, 3.0)
    a = crisp(w, h, shapes, ss=SS_ICON)
    a = toast(a, 3002, rust=0.30, grime=0.24, scratch=20, dust=70)
    save_u("joy_knob", a, 0, "рукоятка джойстика (металл с накаткой)")
    return a


# ------------------------------------------------- мелкая векторная геометрия
def bar_pts(p0, p1, hw):
    """Четырёхугольник-«брусок» от p0 к p1 с полутолщиной hw."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    L = max(math.hypot(dx, dy), 1e-6)
    nx, ny = -dy / L * hw, dx / L * hw
    return [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]


def _sc(pts, s):
    return [(x * s, y * s) for x, y in pts]


def bpoly(d, s, pts, fill, line="ink", w=1.8):
    """Полигон с контуром (координаты в дизайн-пространстве)."""
    p = _sc(pts, s)
    if fill is not None:
        d.polygon(p, fill=rgb8(fill))
    if line is not None:
        d.line(p + [p[0]], fill=rgb8(line), width=max(1, int(round(w * s))), joint="curve")


def brect(d, s, x0, y0, x1, y1, fill, line="ink", w=1.8, r=0.0):
    box = [x0 * s, y0 * s, x1 * s, y1 * s]
    if fill is not None:
        d.rounded_rectangle(box, radius=int(r * s), fill=rgb8(fill))
    if line is not None:
        d.rounded_rectangle(box, radius=int(r * s), outline=rgb8(line),
                            width=max(1, int(round(w * s))))


def bcirc(d, s, cx, cy, rad, fill=None, line="ink", w=1.8):
    box = [(cx - rad) * s, (cy - rad) * s, (cx + rad) * s, (cy + rad) * s]
    if fill is not None:
        d.ellipse(box, fill=rgb8(fill))
    if line is not None:
        d.ellipse(box, outline=rgb8(line), width=max(1, int(round(w * s))))


def bline(d, s, pts, c, w=3.0):
    p = _sc(pts, s)
    ww = max(1, int(round(w * s)))
    d.line(p, fill=rgb8(c), width=ww, joint="curve")
    rr = ww / 2.0
    for x, y in (p[0], p[-1]):
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=rgb8(c))


def barc(d, s, cx, cy, rad, a0, a1, c, w=3.0):
    box = [(cx - rad) * s, (cy - rad) * s, (cx + rad) * s, (cy + rad) * s]
    d.arc(box, a0, a1, fill=rgb8(c), width=max(1, int(round(w * s))))


def arrow_head(d, s, tip, ang, size, c, line="ink"):
    """Треугольный наконечник стрелки (ang в градусах)."""
    a = math.radians(ang)
    back = (tip[0] - math.cos(a) * size, tip[1] - math.sin(a) * size)
    side = size * 0.62
    n = (-math.sin(a) * side, math.cos(a) * side)
    bpoly(d, s, [tip, (back[0] + n[0], back[1] + n[1]), (back[0] - n[0], back[1] - n[1])],
          c, line, 1.2)


def sline(d, s, pts, c, w, o="ink"):
    """Штрих с тёмной обводкой — главный приём читаемости мелких глифов."""
    if o is not None:
        bline(d, s, pts, o, w + 4.0)
    bline(d, s, pts, c, w)


def sarc(d, s, cx, cy, rad, a0, a1, c, w, o="ink"):
    if o is not None:
        barc(d, s, cx, cy, rad, a0, a1, o, w + 4.0)
    barc(d, s, cx, cy, rad, a0, a1, c, w)


# -------------------------------------------------------------------- тач-HUD
TOUCH = 128


def touch_btn(name, glyph, seed, note="", ring="steel3"):
    """Круглая полупрозрачная кнопка с крупным символом."""
    w = h = TOUCH

    def shapes(d, s):
        R = lambda v: float(v * s)
        d.ellipse([R(6), R(6), R(w - 6), R(h - 6)], fill=rgb8(col("ink", 0.40)))
        d.ellipse([R(6), R(6), R(w - 6), R(h - 6)], outline=rgb8(col(ring, 0.85)),
                  width=max(1, int(4 * s)))
        d.ellipse([R(11), R(11), R(w - 11), R(h - 11)], outline=rgb8(col("ink", 0.5)),
                  width=max(1, int(1.5 * s)))
        d.arc([R(13), R(13), R(w - 13), R(h - 13)], 190, 350,
              fill=rgb8(col("steel5", 0.30)), width=max(1, int(2 * s)))
        glyph(d, s)
    a = crisp(w, h, shapes, ss=SS_ICON)
    a = toast(a, seed, rust=0.16, grime=0.14, scratch=12, dust=40)
    save_u(name, a, 0, note)
    return a


# --- глифы (сетка 128x128, центр 64) -----------------------------------------
def g_attack(d, s):
    """Скрещённые нож и патрон."""
    bpoly(d, s, bar_pts((36, 42), (98, 104), 8.5), "brass")
    bpoly(d, s, [(26, 28), (46, 44), (36, 56)], "brass2")             # пуля
    bpoly(d, s, bar_pts((92, 98), (100, 106), 10.0), "copper")        # донце гильзы
    bpoly(d, s, [(96, 22), (88, 30), (54, 66), (48, 58)], "steel5")   # клинок
    bline(d, s, [(92, 26), (52, 62)], "steel2", 2.0)
    bpoly(d, s, bar_pts((30, 46), (52, 70), 9.0), "olive0")           # рукоять
    bpoly(d, s, bar_pts((52, 68), (58, 74), 12.0), "steel2")          # гарда
    bcirc(d, s, 34, 42, 5.0, "steel3")


def g_use(d, s):
    """Открытая ладонь."""
    hand = "bone"
    for x0, x1, y0 in ((44, 56, 46), (57, 69, 40), (70, 82, 44), (83, 95, 54)):
        brect(d, s, x0, y0, x1, 74, hand, "ink", 2.2, r=5.0)
    brect(d, s, 40, 62, 96, 108, hand, "ink", 2.4, r=12.0)
    bpoly(d, s, bar_pts((40, 66), (26, 84), 7.0), hand)               # большой палец
    bline(d, s, [(46, 96), (58, 96)], "steel2", 2.0)
    bline(d, s, [(70, 98), (88, 98)], "steel2", 2.0)


def g_dodge(d, s):
    """Двойная шеврон-стрелка."""
    sline(d, s, [(38, 32), (64, 64), (38, 96)], "amber", 11.0)
    sline(d, s, [(72, 32), (98, 64), (72, 96)], "amber2", 11.0)


def g_bag(d, s):
    """Рюкзак."""
    sarc(d, s, 64, 52, 20, 195, 345, "steel3", 4.0)                   # ручка
    brect(d, s, 34, 48, 94, 110, "olive2", "ink", 2.4, r=10.0)        # корпус
    brect(d, s, 34, 48, 94, 70, "olive1", "ink", 2.2, r=10.0)         # клапан
    brect(d, s, 58, 62, 70, 76, "amber", "ink", 2.0, r=3.0)           # пряжка
    brect(d, s, 72, 78, 92, 102, "olive0", "ink", 1.8, r=4.0)         # карман
    bline(d, s, [(40, 78), (52, 78)], "olive4", 3.0)


def g_journal(d, s):
    """Блокнот."""
    brect(d, s, 34, 32, 96, 102, "olive3", "ink", 2.4, r=6.0)
    brect(d, s, 34, 32, 48, 102, "rust1", "ink", 2.2, r=6.0)          # корешок
    for y in (48, 62, 76, 90):
        bline(d, s, [(56, y), (88, y)], "cream", 3.0)
    brect(d, s, 74, 26, 88, 52, "blood2", "ink", 2.0, r=2.0)          # закладка


def g_pause(d, s):
    """Две полосы паузы."""
    brect(d, s, 44, 34, 58, 96, "cream", "ink", 2.6, r=3.0)
    brect(d, s, 72, 34, 86, 96, "cream", "ink", 2.6, r=3.0)


def g_heal(d, s):
    """Красный крест медицины."""
    brect(d, s, 32, 32, 96, 96, "bone", "ink", 2.6, r=8.0)
    brect(d, s, 56, 44, 72, 84, "blood2", "ink", 2.0, r=1.0)
    brect(d, s, 44, 56, 84, 72, "blood2", "ink", 2.0, r=1.0)
    brect(d, s, 60, 52, 66, 76, "blood3", None, 0)                    # блик на кресте
    brect(d, s, 48, 60, 80, 66, "blood3", None, 0)


def g_map(d, s):
    """Сложенная карта с маршрутом."""
    bpoly(d, s, [(28, 44), (52, 34), (76, 44), (100, 34), (100, 92), (76, 102),
                 (52, 92), (28, 102)], "bone")
    bline(d, s, [(52, 36), (52, 92)], "ink", 2.2)
    bline(d, s, [(76, 44), (76, 100)], "ink", 2.2)
    bline(d, s, [(36, 88), (46, 74), (60, 78), (68, 62)], "blood2", 3.5)
    for x, y in ((36, 88), (46, 74), (60, 78)):
        bcirc(d, s, x, y, 3.0, "blood", None)
    sline(d, s, [(84, 52), (94, 62)], "blood3", 4.0)
    sline(d, s, [(94, 52), (84, 62)], "blood3", 4.0)


def g_swap(d, s):
    """Две стрелки между «стволами»."""
    for cy in (28, 100):
        brect(d, s, 34, cy - 7, 90, cy + 7, "steel3", "ink", 2.2, r=3.0)
        brect(d, s, 40, cy + 6, 56, cy + 18, "steel2", "ink", 2.0, r=2.0)
        brect(d, s, 90, cy - 4, 98, cy + 4, "steel2", "ink", 1.8, r=2.0)
    sarc(d, s, 64, 64, 20, 195, 330, "amber", 7.0)
    arrow_head(d, s, (43, 55), -128, 13.0, "amber")
    sarc(d, s, 64, 64, 20, 15, 150, "amber2", 7.0)
    arrow_head(d, s, (85, 73), 52, 13.0, "amber2")


# ------------------------------------------------------------------ декор HUD
def radial(w, h):
    """Нормированное расстояние от центра (0 в центре, ~1.41 в углах)."""
    ys = (np.arange(h, dtype=np.float32) - (h - 1) / 2.0) / ((h - 1) / 2.0)
    xs = (np.arange(w, dtype=np.float32) - (w - 1) / 2.0) / ((w - 1) / 2.0)
    return np.sqrt(xs[None, :] ** 2 + ys[:, None] ** 2).astype(np.float32)


def minimap_frame():
    w = h = 208
    a = plate(w, h, 4001, border=16, radius=8, body="steel0", band="steel1",
              bevel="steel3", shadow=0.55, rust=0.32, grime=0.26, weld=False)
    def notch(d, s):
        R = lambda v: float(v * s)
        bpoly(d, s, [(96, 4), (112, 4), (104, 15)], "amber")
        bpoly(d, s, [(96, 4), (112, 4), (104, 15)], None, "ink", 1.4)
    a = src_over(a, crisp(w, h, notch, ss=SS_ICON))
    for i in range(4):          # насечки-деления на нижней кромке
        a = src_over(a, crisp(w, h, lambda d, s, i=i: d.line(
            [(60 + i * 30) * s, (h - 12) * s, (60 + i * 30) * s, (h - 5) * s],
            fill=rgb8(col("steel4", 0.6)), width=max(1, int(2 * s))), ss=SS_ICON))
    a = src_over(a, accent_frame(w, h, border=16, radius=8, accent="rust2", thick=1.8,
                                 bolt_rad=3.2, inner_line=True, corners=True))
    save_u("minimap_frame", a, 16, "рамка миникарты + метка «север» и деления")
    return a


def crosshair():
    w = h = 48
    def shapes(d, s):
        for pts in ([(24, 3), (24, 18)], [(24, 30), (24, 45)], [(3, 24), (18, 24)],
                    [(30, 24), (45, 24)]):
            sline(d, s, pts, "cream", 3.0)
        bcirc(d, s, 24, 24, 1.8, "amber", None)
    a = crisp(w, h, shapes, ss=SS_ICON)
    save_u("crosshair", a, 0, "прицел: тонкий крест + точка")
    return a


def cursor_arrow():
    w = h = 32
    pts = [(3, 2), (3, 23), (8.5, 18), (12.5, 28), (16.5, 26), (12.5, 16), (20, 15.5)]
    def shapes(d, s):
        bpoly(d, s, pts, "cream", "ink", 1.8)
        bline(d, s, [(6, 6), (6, 16)], "steel5", 1.4)
    a = crisp(w, h, shapes, ss=SS_ICON)
    save_u("cursor", a, 0, "системный курсор-стрелка")
    return a


def quest_marker():
    w, h = 24, 32
    def shapes(d, s):
        bpoly(d, s, [(12, 31), (4, 18), (20, 18)], "amber", "ink", 1.6)
        bcirc(d, s, 12, 12, 10.5, "amber", "ink", 1.8)
        bcirc(d, s, 12, 12, 6.5, "rust1", "ink", 1.4)
        bpoly(d, s, [(12, 6), (17, 15), (12, 12), (7, 15)], "amber2", None)
    a = crisp(w, h, shapes, ss=SS_ICON)
    a = toast(a, 4102, rust=0.25, grime=0.15, scratch=6, dust=18)
    save_u("quest_marker", a, 0, "маркер квеста (янтарный указатель)")
    return a


def skull_marker():
    w = h = 24
    def shapes(d, s):
        bcirc(d, s, 12, 11, 9.0, "bone", "ink", 1.8)
        brect(d, s, 6, 15, 18, 21.5, "bone", "ink", 1.6, r=2.0)
        bcirc(d, s, 8.6, 10.5, 3.2, "black", None)
        bcirc(d, s, 15.4, 10.5, 3.2, "black", None)
        bcirc(d, s, 8.6, 10.0, 1.2, "blood2", None)
        bcirc(d, s, 15.4, 10.0, 1.2, "blood2", None)
        bpoly(d, s, [(12, 14), (14, 17.5), (10, 17.5)], "ink", None)
        for x in (8, 12, 16):
            bline(d, s, [(x, 18), (x, 21)], "ink", 1.2)
    a = crisp(w, h, shapes, ss=SS_ICON)
    save_u("skull_marker", a, 0, "маркер трупа/опасности")
    return a


def party_marker():
    w = h = 24
    def shapes(d, s):
        bcirc(d, s, 12, 7.5, 4.2, "cyan2", "ink", 1.8)
        sarc(d, s, 12, 21, 9.0, 190, 350, "cyan2", 4.0)
        bcirc(d, s, 12, 7.5, 1.5, "cyan", None)
    a = crisp(w, h, shapes, ss=SS_ICON)
    save_u("party_marker", a, 0, "маркер союзника")
    return a


def danger_arrow():
    w = h = 32
    def shapes(d, s):
        bpoly(d, s, [(16, 2), (30, 26), (16, 19), (2, 26)], "blood2", "ink", 1.8)
        bpoly(d, s, [(16, 8), (24, 22), (16, 17), (8, 22)], "blood3", None)
    a = crisp(w, h, shapes, ss=SS_ICON)
    save_u("danger_arrow", a, 0, "указатель урона/опасности (вращать по углу)")
    return a


# -------------------------------------------------------------- экранные слои
def vignette():
    w = h = 512
    rr = radial(w, h)
    edge = P.clamp01((rr - 0.40) / 0.58) ** 1.45
    n = noise2(w, h, 4, 3, 5001)
    alpha = np.clip(edge * (0.78 + 0.35 * n), 0.0, 1.0) * 0.94
    arr = flat(w, h, "black")
    arr[..., :3] *= (0.85 + 0.3 * n)[..., None]
    arr[..., 3] = alpha
    arr = tint(arr, speck(w, h, 700, 5002, 1.2) * edge, "steel2", 0.35)
    save_u("vignette", arr, 0, "затемнение по краям экрана (центр прозрачный)")
    return arr


def blood_overlay():
    w = h = 512
    rr = radial(w, h)
    edge = P.clamp01((rr - 0.28) / 0.72) ** 1.25
    splat = gate(w, h, 5101, 5, 0.30, 0.78)
    fine = gate(w, h, 5102, 13, 0.45, 0.92)
    drips = np.zeros_like(splat)
    for k in range(1, 30):
        drips = np.maximum(drips, np.roll(splat, k, axis=0) * (1.0 - k / 30.0))
    mask = P.clamp01(edge * (0.22 + 1.05 * splat) + 0.45 * edge * fine + 0.9 * edge * drips)
    mask = P.clamp01(mask + speck(w, h, 1100, 5103, 1.2) * edge * 1.2)
    arr = flat(w, h, "blood0")
    arr = tint(arr, splat, "blood2", 0.75)
    arr = tint(arr, gate(w, h, 5104, 9, 0.55, 0.95), "blood", 0.6)
    arr[..., 3] = mask * 0.88
    save_u("blood_overlay", arr, 0, "кровь по краям экрана (при уроне)")
    return arr


def damage_flash():
    w = h = 256
    rr = radial(w, h)
    edge = P.clamp01((rr - 0.12) / 0.85) ** 1.35
    arr = flat(w, h, "blood2")
    arr = tint(arr, edge, "blood3", 0.5)
    arr[..., 3] = np.clip(0.12 + edge * 0.86, 0.0, 1.0)
    save_u("damage_flash", arr, 0, "красная радиальная вспышка урона")
    return arr


def noise_overlay():
    w = h = 256
    r = np.random.default_rng(6001)
    fine = r.random((h, w)).astype(np.float32)
    clump = noise2(w, h, 40, 3, 6002)
    g = P.clamp01(fine * 0.6 + clump * 0.7 - 0.12)
    arr = np.zeros((h, w, 4), np.float32)
    arr[..., :3] = np.stack([g * 0.9, g * 0.92, g], -1)
    arr[..., 3] = 0.04 + 0.10 * np.abs(g - 0.5) * 2.0
    sc = scratch_mask(w, h, 6003, 14, 20.0, 90.0, 0.9)
    arr = tint(arr, sc, "cream", 0.25)
    arr[..., 3] = np.clip(arr[..., 3] + sc * 0.14, 0.0, 0.35)
    save_u("noise_overlay", arr, 0, "плёнка/зерно поверх экрана (низкая альфа)")
    return arr


def scanlines():
    w = h = 8                    # тайл 8x8: тёмная строка каждые 4 px
    arr = flat(w, h, "black")
    a = np.zeros((h, w), np.float32)
    a[0, :] = 0.26
    a[1, :] = 0.15
    a[3, :] = 0.06
    arr[..., 3] = a
    save_u("scanlines", arr, 0, "тайл строчной развёртки 8x8")
    return arr


def radar_grid():
    w = h = 128
    def shapes(d, s):
        for i in range(0, w, 16):
            al = 0.32 if i % 64 == 0 else 0.20
            d.line([i * s, 0, i * s, h * s], fill=rgb8(col("toxic", al)), width=max(1, int(s)))
            d.line([0, i * s, w * s, i * s], fill=rgb8(col("toxic", al)), width=max(1, int(s)))
        for x in (16, 48, 80, 112):
            for y in (16, 48, 80, 112):
                d.ellipse([(x - 1.4) * s, (y - 1.4) * s, (x + 1.4) * s, (y + 1.4) * s],
                          fill=rgb8(col("toxic", 0.45)))
    a = crisp(w, h, shapes, ss=SS_ICON)
    save_u("radar_grid", a, 0, "сетка радара/детектора (тайл 128x128)")
    return a


def compass():
    """Компас: кольцо, риски, кириллица С/В/Ю/З и стрелка."""
    w = h = 192
    def shapes(d, s):
        R = lambda v: float(v * s)
        d.ellipse([R(5), R(5), R(w - 5), R(h - 5)], fill=rgb8(col("black", 0.34)))
        d.ellipse([R(5), R(5), R(w - 5), R(h - 5)], outline=rgb8(col("steel3", 0.95)),
                  width=max(1, int(4 * s)))
        d.ellipse([R(10), R(10), R(w - 10), R(h - 10)], outline=rgb8(col("ink", 0.75)),
                  width=max(1, int(2 * s)))
        d.ellipse([R(30), R(30), R(w - 30), R(h - 30)], outline=rgb8(col("steel2", 0.45)),
                  width=max(1, int(1.4 * s)))
        for ang in range(0, 360, 15):
            a = math.radians(ang)
            long = ang % 90 == 0
            r0, r1 = 76, (60 if long else 68)
            d.line([R(w / 2 + math.cos(a) * r0), R(h / 2 + math.sin(a) * r0),
                    R(w / 2 + math.cos(a) * r1), R(h / 2 + math.sin(a) * r1)],
                   fill=rgb8(col("steel4", 0.8 if long else 0.45)),
                   width=max(1, int((2.4 if long else 1.4) * s)))
        f2 = font(30 * s)
        letters = (("С", 96, 34, "amber2"), ("В", 157, 96, "steel5"),
                   ("Ю", 96, 158, "steel5"), ("З", 35, 96, "steel5"))
        if f2 is not None:
            for ch, x, y, c in letters:
                d.text((R(x), R(y)), ch, font=f2, fill=rgb8(col(c)), anchor="mm",
                       stroke_width=max(1, int(1.4 * s)), stroke_fill=rgb8(col("ink")))
        else:  # запасной вариант — толстые геометрические наконечники
            for x, y in ((96, 34), (157, 96), (96, 158), (35, 96)):
                bcirc(d, s, x, y, 5.0, "amber2", "ink", 1.4)
        # игла: север красный, юг светлый
        bpoly(d, s, [(96, 26), (106, 96), (96, 90), (86, 96)], "blood2", "ink", 1.6)
        bpoly(d, s, [(96, 166), (86, 96), (96, 102), (106, 96)], "cream", "ink", 1.6)
        bcirc(d, s, 96, 96, 6.5, "steel3", "ink", 1.6)
    a = crisp(w, h, shapes, ss=SS_ICON)
    a = toast(a, 4103, rust=0.22, grime=0.16, scratch=14, dust=50)
    save_u("compass", a, 0, "компас: С/В/Ю/З + красная игла севера")
    return a


# -------------------------------------------------------------- плашки текста
def hazard(d, s, w, y0, y1, c1="amber", c2="ink", period=12.0):
    """Полоса-«зебра» (опасность) внутри плашки."""
    x = 0.0
    while x < w:
        d.rectangle([x * s, y0 * s, (x + period * 0.5) * s, y1 * s], fill=rgb8(col(c1, 0.85)))
        d.rectangle([(x + period * 0.5) * s, y0 * s, (x + period) * s, y1 * s],
                    fill=rgb8(col(c2, 0.7)))
        x += period


def banner(name, seed, body, band, accent, hazard_cols=None, note=""):
    w, h = 512, 64
    a = plate(w, h, seed, border=12, radius=6, body=body, band=band, bevel="steel4",
              shadow=0.5, rust=0.34, grime=0.26, weld=False)
    if hazard_cols is not None:
        a = src_over(a, crisp(w, h, lambda d, s: (
            hazard(d, s, w, 3.5, 10.5, hazard_cols[0], hazard_cols[1]),
            hazard(d, s, w, h - 10.5, h - 3.5, hazard_cols[0], hazard_cols[1]))))
    a = src_over(a, accent_frame(w, h, border=12, radius=6, accent=accent, thick=1.8,
                                 bolt_rad=3.0, inner_line=True, corners=True))
    save_u(name, a, 12, note)
    return a


def log_plate():
    w, h = 384, 32
    a = plate(w, h, 7003, border=8, radius=4, body="steel1", band="steel0", alpha=0.88,
              alpha_band=0.92, bevel="steel3", shadow=0.35, rust=0.24, grime=0.22, weld=False)
    a = src_over(a, accent_frame(w, h, border=8, radius=4, accent="steel4", thick=1.4,
                                 bolt_rad=2.2, inner_line=True, corners=False))
    save_u("log_plate", a, 8, "плашка строки журнала/лога")
    return a


def dlg_portrait_frame():
    w = h = 192
    a = plate(w, h, 7004, border=16, radius=8, body="steel0", band="olive1",
              bevel="olive3", shadow=0.6, rust=0.3, grime=0.26, weld=False)
    a = src_over(a, accent_frame(w, h, border=16, radius=8, accent="amber", thick=1.8,
                                 bolt_rad=3.2, inner_line=True, corners=True))
    save_u("dlg_portrait_frame", a, 16, "рамка портрета в диалоге с NPC")
    return a


# ------------------------------------------------------------------- брендинг
def logo():
    """logo.png 1024x256: «ЗОНА» стенсилом + подзаголовок «ПИКНИК НА ОБОЧИНЕ»."""
    w, h = 1024, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    f_title = font(152)
    f_sub = font(40, title=False)
    title, sub = "ЗОНА", "ПИКНИК НА ОБОЧИНЕ"
    if f_title is not None:
        widths = [d.textlength(ch, font=f_title) for ch in title]
        gap = 18
        x = (w - (sum(widths) + gap * (len(title) - 1))) / 2.0
        for ch, cw in zip(title, widths):
            d.text((x, 112), ch, font=f_title, fill=rgb8(col("ink")), anchor="lm",
                   stroke_width=8, stroke_fill=rgb8(col("ink")))
            d.text((x, 108), ch, font=f_title, fill=rgb8(col("amber2")), anchor="lm")
            d.text((x - 4, 105), ch, font=f_title, fill=rgb8(col("cream")), anchor="lm")
            x += cw + gap
    else:   # аварийный геометрический вариант
        for i in range(4):
            d.rectangle([220 + i * 150, 40, 330 + i * 150, 150], fill=rgb8(col("amber2")),
                        outline=rgb8(col("ink")), width=6)
    if f_sub is not None:
        d.text((w / 2, 198), sub, font=f_sub, fill=rgb8(col("steel5")), anchor="mm",
               stroke_width=4, stroke_fill=rgb8(col("ink")))
    hazard(d, 1, w, 170, 178, "rust2", "ink", period=16.0)
    for i in range(3):
        d.line([(46 + i * 16, 104), (88 + i * 16, 130), (46 + i * 16, 156)],
               fill=rgb8(col("rust3", 0.85)), width=7)
        d.line([(w - 46 - i * 16, 104), (w - 88 - i * 16, 130), (w - 46 - i * 16, 156)],
               fill=rgb8(col("rust3", 0.85)), width=7)
    arr = np.asarray(img, np.float32) / 255.0
    arr = tint(arr, gate(w, h, 7101, 5, 0.55, 0.95), "rust1", 0.32)
    arr = tint(arr, gate(w, h, 7102, 11, 0.62, 0.98), "rust2", 0.24)
    arr = tint(arr, scratch_mask(w, h, 7104, 90, 20.0, 90.0), "steel0", 0.22)
    arr = grainize(arr, 7103, 0.18, 40)
    save_u("logo", arr, 0, "логотип: «ЗОНА» + «ПИКНИК НА ОБОЧИНЕ»")
    return arr


def splash_bg():
    """splash_bg.png 1024x576: туман, руины, одинокий силуэт сталкера."""
    w, h = 1024, 576
    hor = int(h * 0.68)
    yy = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None, None]
    top = np.array(col("ink")[:3], np.float32)[None, None, :]
    bot = np.array(col("rust0")[:3], np.float32)[None, None, :] * 1.5
    sky = np.repeat(top * (1.0 - yy) + bot * yy, w, axis=1)          # h x w x 3
    fog = noise2(w, h, 3, 4, 7201)
    band = np.exp(-((np.arange(h, dtype=np.float32) - hor) / (0.17 * h)) ** 2)[:, None]
    warm = np.array([1.0, 0.86, 0.66], np.float32)[None, None, :]
    img = sky * (1.0 - (0.5 * band * fog)[..., None]) + (0.26 * band * fog)[..., None] * warm
    edge = hor + (noise2(w, h, 6, 3, 7202)[0] - 0.5) * 16.0
    ground = (np.arange(h, dtype=np.float32)[:, None] > edge[None, :]).astype(np.float32)
    img = img * (1.0 - ground[..., None]) + ground[..., None] * 0.05
    arr = np.concatenate([np.clip(img, 0, 1), np.ones((h, w, 1), np.float32)], -1)
    arr = tint(arr, gate(w, h, 7203, 4, 0.5, 0.95) * ground, "rust1", 0.40)

    def sil(d, s):
        R = lambda v: float(v * s)
        for x0, x1, top_y in ((110, 205, 320), (240, 315, 372), (700, 792, 292),
                              (838, 906, 344), (520, 572, 392)):
            d.rectangle([R(x0), R(top_y), R(x1), R(hor + 6)], fill=rgb8(col("black", 0.95)))
            d.polygon([(R(x0), R(top_y)), (R((x0 + x1) / 2), R(top_y - 26)),
                       (R(x1), R(top_y))], fill=rgb8(col("black", 0.95)))
        for x in (56, 430, 968):          # столбы ЛЭП
            d.rectangle([R(x - 4), R(140), R(x + 4), R(hor + 6)], fill=rgb8(col("black", 0.9)))
            d.line([R(x - 30), R(164), R(x + 30), R(164)], fill=rgb8(col("black", 0.9)),
                   width=max(1, int(3 * s)))
        cx, base = 664, hor + 104         # сталкер в плаще с ружьём
        d.polygon([(R(cx - 28), R(base)), (R(cx + 32), R(base)), (R(cx + 22), R(base - 76)),
                   (R(cx - 22), R(base - 76))], fill=rgb8(col("black")))
        d.ellipse([R(cx - 20), R(base - 112), R(cx + 20), R(base - 70)],
                  fill=rgb8(col("black")))
        d.polygon([(R(cx - 32), R(base - 74)), (R(cx + 36), R(base - 74)),
                   (R(cx + 16), R(base - 104)), (R(cx - 26), R(base - 104))],
                  fill=rgb8(col("black")))
        d.line([R(cx - 46), R(base - 126), R(cx + 42), R(base - 88)],
               fill=rgb8(col("black")), width=max(1, int(7 * s)))
    arr = src_over(arr, crisp(w, h, sil, ss=SS_PANEL))
    dg = np.sqrt(((np.arange(w, dtype=np.float32)[None, :] / w) - 0.30) ** 2 +
                 ((np.arange(h, dtype=np.float32)[:, None] / h) - 0.62) ** 2)
    glow = np.exp(-(dg ** 2) / (2 * 0.10 ** 2))
    arr[..., :3] = np.clip(arr[..., :3] + (glow * 0.30)[..., None] *
                           np.array([0.40, 0.95, 0.28], np.float32), 0, 1)
    arr[..., :3] = np.clip(arr[..., :3] + (np.exp(-(dg ** 2) / (2 * 0.045 ** 2)) * 0.28)[..., None] *
                           np.array([0.90, 0.45, 0.14], np.float32), 0, 1)
    arr = tint(arr, gate(w, h, 7204, 4, 0.52, 0.95), "rust1", 0.26)
    arr = tint(arr, scratch_mask(w, h, 7205, 40, 30.0, 140.0), "steel5", 0.10)
    arr[..., :3] *= (0.58 + 0.62 * (1.0 - P.clamp01((radial(w, h) - 0.35) / 0.75) ** 1.5))[..., None]
    arr = grainize(arr, 7206, 0.14, 64)
    save_u("splash_bg", arr, 0, "фон сплэша 1024x576: туман, руины, силуэт сталкера")
    return arr


def icon_app():
    """icon_app.png 512x512: радиоактивный трилистник на ржавом круге."""
    w = h = 512
    def shapes(d, s):
        R = lambda v: float(v * s)
        d.rounded_rectangle([0, 0, R(w) - 1, R(h) - 1], radius=R(72), fill=rgb8(col("steel0")))
        d.rounded_rectangle([R(14), R(14), R(w - 14), R(h - 14)], radius=R(62),
                            fill=rgb8(col("ink")))
        for i in range(0, w, 24):        # фоновая зебра по краю
            d.line([R(i), R(6), R(i + 12), R(6)], fill=rgb8(col("rust2", 0.7)),
                   width=max(1, int(3 * s)))
            d.line([R(i), R(h - 6), R(i + 12), R(h - 6)], fill=rgb8(col("rust2", 0.7)),
                   width=max(1, int(3 * s)))
        d.ellipse([R(74), R(74), R(w - 74), R(h - 74)], fill=rgb8(col("rust1")),
                  outline=rgb8(col("rust3")), width=max(1, int(7 * s)))
        d.ellipse([R(88), R(88), R(w - 88), R(h - 88)], outline=rgb8(col("rust0")),
                  width=max(1, int(4 * s)))
        # три лопасти трилистника
        for k in range(3):
            a0 = math.radians(-90 + k * 120 - 24)
            a1 = math.radians(-90 + k * 120 + 24)
            pts = [(256 + math.cos(a0 + (a1 - a0) * t / 8.0) * (58 + 12 * t / 8.0) * 1.9,
                    256 + math.sin(a0 + (a1 - a0) * t / 8.0) * (58 + 12 * t / 8.0) * 1.9)
                   for t in range(9)]
            back = [(256 + math.cos(a1 + (a0 - a1) * t / 8.0) * 62,
                     256 + math.sin(a1 + (a0 - a1) * t / 8.0) * 62) for t in range(9)]
            bpoly(d, s, pts + back, "toxic", "ink", 5.0)
        bcirc(d, s, 256, 256, 34, "toxic", "ink", 5.0)
        bcirc(d, s, 256, 256, 16, "ink", "toxic2", 3.0)
    arr = crisp(w, h, shapes, ss=SS_PANEL)
    arr = tint(arr, gate(w, h, 7301, 5, 0.52, 0.95), "rust1", 0.30)
    arr = tint(arr, scratch_mask(w, h, 7302, 60, 30.0, 150.0), "steel5", 0.16)
    arr = grainize(arr, 7303, 0.15, 48)
    save_u("icon_app", arr, 0, "иконка приложения: трилистник на ржавом круге")
    return arr


# ----------------------------------------------------------- иконки предметов
IC = 64          # сторона иконки предмета


def artifact_glow(arr, color, amount=0.6, radius=3.0):
    """Мягкое свечение вокруг артефакта (под объектом, сам объект не размыт)."""
    img = Image.fromarray((P.clamp01(arr[..., 3]) * 255).astype(np.uint8), "L")
    blur = np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), np.float32) / 255.0
    ring = np.clip(blur - arr[..., 3], 0.0, 1.0)
    glow = np.zeros_like(arr)
    glow[..., :3] = np.asarray(col(color)[:3], np.float32)
    glow[..., 3] = np.clip(ring * amount, 0.0, 1.0)
    return src_over(glow, arr)


def icon(name, fn, seed, note="", glow=None):
    """Отрисовать иконку 64x64 (читаемую в 32 px) и сохранить."""
    arr = crisp(IC, IC, fn, ss=SS_ICON)
    if glow:
        arr = artifact_glow(arr, glow)
    arr = grainize(arr, seed, 0.08, 40)
    save_u(name, arr, 0, note)
    return arr


# --- оружие -----------------------------------------------------------------
def i_pm(d, s):
    brect(d, s, 9, 18, 14, 26, "steel2", "ink", 1.8, r=2)            # курок
    brect(d, s, 12, 20, 50, 30, "steel3", "ink", 2.0, r=2)           # затвор
    brect(d, s, 18, 22, 30, 28, "steel1", None)                      # окно выброса
    brect(d, s, 50, 22, 55, 28, "ink", "steel0", 1.4)                # ствол
    for x in (42, 45, 48):                                           # насечки
        bline(d, s, [(x, 22), (x, 28)], "steel1", 1.4)
    brect(d, s, 14, 30, 40, 36, "steel2", "ink", 1.8, r=2)           # рамка
    bpoly(d, s, [(30, 36), (38, 36), (42, 42), (34, 42)], "steel2")  # спусковая скоба
    bpoly(d, s, [(14, 34), (30, 34), (26, 54), (10, 54)], "olive0")  # рукоять
    bline(d, s, [(13, 50), (24, 50)], "olive4", 1.6)
    bline(d, s, [(16, 34), (26, 34)], "ink", 1.6)


def i_ak(d, s):
    bpoly(d, s, [(3, 24), (10, 22), (14, 26), (12, 32), (3, 33)], "olive2")   # приклад
    brect(d, s, 12, 22, 44, 32, "olive1", "ink", 2.0, r=2)                    # ств. коробка
    brect(d, s, 44, 25, 61, 29, "steel2", "ink", 1.8)                         # ствол
    brect(d, s, 44, 22, 50, 26, "steel2", "ink", 1.6, r=1)                    # газовая трубка
    brect(d, s, 57, 20, 61, 25, "steel3", "ink", 1.6)                         # мушка
    bpoly(d, s, [(22, 32), (28, 32), (24, 46), (16, 46)], "olive0")           # рукоять
    bpoly(d, s, [(30, 32), (44, 32), (42, 46), (32, 48), (28, 44)], "olive2")  # магазин
    bline(d, s, [(31, 36), (41, 36)], "olive4", 1.6)
    bpoly(d, s, [(18, 32), (30, 32), (28, 38), (20, 38)], "steel2")           # УСМ


def i_shotgun(d, s):
    brect(d, s, 6, 24, 20, 38, "olive0", "ink", 2.0, r=2)            # колодка
    brect(d, s, 18, 22, 52, 29, "steel2", "ink", 2.0, r=2)           # верхний ствол
    brect(d, s, 18, 30, 52, 37, "steel1", "ink", 2.0, r=2)           # нижний ствол
    bcirc(d, s, 51, 25.5, 2.6, "ink", None)
    bcirc(d, s, 51, 33.5, 2.6, "ink", None)
    bpoly(d, s, [(8, 26), (14, 24), (16, 30), (8, 30)], "steel2")    # курки
    bpoly(d, s, [(8, 36), (18, 36), (14, 52), (4, 52)], "olive2")    # пистолетная рукоять
    bpoly(d, s, [(16, 38), (24, 38), (28, 44), (20, 44)], "steel1")  # скоба
    bline(d, s, [(8, 48), (15, 48)], "olive4", 1.6)


def i_knife(d, s):
    bpoly(d, s, [(56, 8), (46, 12), (24, 38), (32, 46)], "steel4")   # клинок
    bline(d, s, [(52, 14), (30, 40)], "steel2", 2.2)                 # дол
    bpoly(d, s, [(24, 36), (34, 46), (28, 52), (18, 42)], "steel2")  # гарда
    bpoly(d, s, [(18, 42), (28, 52), (10, 58), (4, 52)], "olive0")   # рукоять
    bline(d, s, [(10, 50), (18, 56)], "olive4", 2.0)
    bcirc(d, s, 12, 51, 2.2, "steel4", "ink", 1.2)
    bcirc(d, s, 18, 46, 2.2, "steel4", "ink", 1.2)


def i_crossbow(d, s):
    bpoly(d, s, [(4, 32), (18, 30), (30, 30), (30, 40), (16, 40), (4, 38)], "olive1")  # ложе
    bpoly(d, s, [(6, 38), (20, 40), (16, 54), (4, 54)], "olive2")                      # рукоять
    sline(d, s, [(16, 8), (30, 22), (30, 46), (16, 58)], "steel3", 3.4)               # плечи
    bline(d, s, [(16, 8), (16, 58)], "cream", 1.6)                                    # тетива
    brect(d, s, 22, 28, 58, 34, "brass", "ink", 1.8, r=2)                             # болт
    bpoly(d, s, [(58, 27), (62, 31), (58, 35)], "steel5", "ink", 1.4)
    brect(d, s, 24, 26, 34, 29, "steel2", None)                                       # оперение
    bline(d, s, [(24, 33), (30, 33)], "ink", 1.4)


# --- броня ------------------------------------------------------------------
def i_armor_leather(d, s):
    bpoly(d, s, [(20, 8), (44, 8), (50, 18), (48, 56), (16, 56), (14, 18)], "olive0")
    bpoly(d, s, [(20, 8), (10, 14), (6, 34), (14, 36), (16, 16)], "olive1")   # рукава
    bpoly(d, s, [(44, 8), (54, 14), (58, 34), (50, 36), (48, 16)], "olive1")
    bpoly(d, s, [(20, 8), (26, 16), (32, 10)], "olive2")                      # воротник
    bpoly(d, s, [(32, 10), (38, 16), (44, 8)], "olive2")
    bline(d, s, [(32, 14), (32, 54)], "steel4", 2.0)                          # молния
    brect(d, s, 20, 22, 28, 30, "olive1", "ink", 1.4)                         # карманы
    brect(d, s, 36, 22, 44, 30, "olive1", "ink", 1.4)
    bpoly(d, s, [(16, 56), (48, 56), (48, 60), (16, 60)], "rust1")            # потёртый низ
    bline(d, s, [(22, 38), (42, 38)], "ink", 1.2)


def i_armor_plate(d, s):
    bpoly(d, s, [(18, 8), (46, 8), (54, 26), (50, 56), (14, 56), (10, 26)], "steel2")
    bpoly(d, s, [(18, 8), (10, 14), (8, 30), (16, 32), (18, 16)], "steel1")
    bpoly(d, s, [(46, 8), (54, 14), (56, 30), (48, 32), (46, 16)], "steel1")
    bpoly(d, s, [(24, 16), (40, 16), (44, 40), (20, 40)], "steel3")           # плита
    bpoly(d, s, [(24, 16), (32, 14), (40, 16), (32, 22)], "steel4")
    for cx, cy in ((24, 21), (40, 21), (22, 35), (42, 35)):
        rivet(d, s, cx, cy, 2.2)
    brect(d, s, 16, 44, 28, 56, "olive1", "ink", 1.6, r=2)                    # подсумки
    brect(d, s, 30, 44, 42, 56, "olive1", "ink", 1.6, r=2)
    bline(d, s, [(21, 48), (25, 48)], "olive4", 1.4)
    bline(d, s, [(35, 48), (39, 48)], "olive4", 1.4)


def i_armor_exo(d, s):
    bpoly(d, s, [(20, 10), (44, 10), (50, 24), (46, 50), (18, 50), (14, 24)], "steel1")
    brect(d, s, 24, 16, 40, 38, "steel3", "ink", 1.6, r=3)                    # грудная плита
    for cx, cy in ((27, 20), (37, 20), (27, 34), (37, 34)):
        rivet(d, s, cx, cy, 2.0)
    for x in (12, 48):                                                        # стойки
        brect(d, s, x - 3, 12, x + 3, 54, "steel4", "ink", 1.8, r=2)
        brect(d, s, x - 5, 20, x + 5, 27, "steel2", "ink", 1.6, r=2)           # гидроцилиндр
    bline(d, s, [(12, 32), (20, 32)], "steel5", 2.0)
    bline(d, s, [(44, 32), (52, 32)], "steel5", 2.0)
    brect(d, s, 22, 40, 42, 54, "olive1", "ink", 1.6, r=2)                    # подсумок
    bcirc(d, s, 32, 8, 6.0, "steel2", "ink", 1.8)                             # плечевой блок
    bcirc(d, s, 32, 8, 2.4, "amber", None)


def i_helmet(d, s):
    bpoly(d, s, [(12, 34), (14, 16), (24, 8), (40, 8), (50, 16), (52, 34),
                 (46, 40), (18, 40)], "olive2")
    brect(d, s, 14, 29, 50, 38, "glass", "ink", 2.0, r=3)                     # смотровое окно
    brect(d, s, 17, 31.5, 47, 35, "toxic", None)
    bline(d, s, [(20, 33), (40, 33)], "toxic2", 1.4)
    brect(d, s, 16, 38, 48, 52, "olive1", "ink", 2.0, r=4)                    # подбородок
    bline(d, s, [(24, 44), (40, 44)], "ink", 1.4)
    bline(d, s, [(24, 48), (40, 48)], "ink", 1.4)
    brect(d, s, 48, 40, 58, 50, "steel2", "ink", 1.8, r=3)                    # фильтр
    bline(d, s, [(51, 44), (55, 44)], "steel4", 1.6)
    rivet(d, s, 20, 13, 2.0)
    rivet(d, s, 44, 13, 2.0)


# --- расходники -------------------------------------------------------------
def i_medkit(d, s):
    sarc(d, s, 32, 20, 8, 185, 355, "steel3", 3.0)                            # ручка
    brect(d, s, 8, 20, 56, 50, "bone", "ink", 2.4, r=4)                       # корпус
    brect(d, s, 8, 20, 56, 28, "cream", "ink", 2.0, r=4)                      # крышка
    brect(d, s, 27, 26, 37, 33, "steel3", "ink", 1.6, r=2)                    # замок
    brect(d, s, 28, 32, 37, 45, "blood2", "ink", 1.6)                         # крест
    brect(d, s, 21, 36, 44, 43, "blood2", "ink", 1.6)
    brect(d, s, 30, 34, 35, 43, "blood3", None)
    brect(d, s, 23, 38, 42, 41, "blood3", None)


def i_bandage(d, s):
    brect(d, s, 34, 24, 58, 40, "bone", "ink", 2.0, r=2)                      # размотка
    bcirc(d, s, 26, 32, 14.0, "cream", "ink", 2.4)                            # рулон
    bcirc(d, s, 26, 32, 6.5, "ink", "bone", 2.0)
    barc(d, s, 26, 32, 10.5, 30, 300, "bone", 2.4)
    bline(d, s, [(42, 29), (54, 29)], "cream", 1.6)
    bline(d, s, [(42, 35), (52, 35)], "cream", 1.6)
    bcirc(d, s, 32, 32, 2.2, "blood2", None)


def i_vodka(d, s):
    brect(d, s, 27, 6, 37, 12, "rust2", "ink", 1.6, r=2)                      # пробка
    brect(d, s, 28, 11, 36, 22, "glass", "ink", 1.8)                          # горлышко
    brect(d, s, 18, 21, 46, 56, "glass", "ink", 2.2, r=4)                     # бутылка
    brect(d, s, 20, 30, 44, 46, "cream", "ink", 1.6, r=2)                     # этикетка
    bline(d, s, [(24, 34), (40, 34)], "blood2", 2.0)
    bline(d, s, [(24, 40), (36, 40)], "ink", 1.6)
    bline(d, s, [(22, 24), (22, 52)], "steel5", 1.6)                          # блик


def i_canned(d, s):
    brect(d, s, 18, 18, 46, 50, "steel4", "ink", 2.2, r=3)                    # банка
    bcirc(d, s, 32, 20, 13.0, "steel5", "ink", 1.8)                           # крышка
    bcirc(d, s, 32, 20, 4.0, "steel2", "ink", 1.6)                            # кольцо
    barc(d, s, 32, 20, 7.5, 200, 340, "steel3", 2.0)
    brect(d, s, 18, 30, 46, 44, "rust2", "ink", 1.6)                          # этикетка
    bline(d, s, [(22, 34), (42, 34)], "cream", 2.2)
    bline(d, s, [(22, 40), (36, 40)], "cream", 1.8)
    bcirc(d, s, 40, 37, 2.6, "blood2", "ink", 1.2)


def i_bread(d, s):
    bpoly(d, s, [(8, 46), (10, 30), (16, 18), (32, 12), (48, 16), (56, 30), (56, 46)], "brass")
    bpoly(d, s, [(8, 46), (56, 46), (56, 52), (8, 52)], "copper")             # корка
    for x in (20, 30, 40):                                                    # надрезы
        bline(d, s, [(x, 20), (x + 5, 30)], "cream", 2.4)
    bline(d, s, [(14, 42), (50, 42)], "rust1", 2.0)
    bcirc(d, s, 24, 30, 2.0, "cream", None)
    bcirc(d, s, 40, 26, 1.8, "cream", None)


def i_ammo_box(d, s, box="olive2", lid="olive1", bullets=3, bullet_h=12,
               shell=False):
    """Патронный ящик; пули/гильзы торчат из крышки (общая заготовка)."""
    for i in range(bullets):
        x = 32 - (bullets - 1) * 4 + i * 8
        if shell:
            brect(d, s, x - 3.5, 12, x + 3.5, 12 + bullet_h, "blood2", "ink", 1.6, r=2)
            brect(d, s, x - 3.5, 12 + bullet_h, x + 3.5, 18 + bullet_h, "brass", "ink", 1.4, r=2)
        else:
            brect(d, s, x - 2.5, 10, x + 2.5, 10 + bullet_h, "brass", "ink", 1.6, r=2)
            bpoly(d, s, [(x - 2.5, 10), (x, 4), (x + 2.5, 10)], "brass2", "ink", 1.2)
    brect(d, s, 8, 26, 56, 56, box, "ink", 2.4, r=3)                          # ящик
    brect(d, s, 8, 26, 56, 34, lid, "ink", 2.0, r=3)                          # крышка
    brect(d, s, 26, 30, 38, 37, "steel3", "ink", 1.6, r=2)                    # замок
    brect(d, s, 14, 40, 50, 52, "cream", "ink", 1.6, r=2)                     # этикетка
    bline(d, s, [(18, 44), (34, 44)], "ink", 2.2)
    bline(d, s, [(18, 48), (28, 48)], "ink", 1.8)
    bcirc(d, s, 43, 46, 3.2, "blood2", "ink", 1.2)


def i_flashlight(d, s):
    brect(d, s, 12, 24, 44, 38, "steel2", "ink", 2.2, r=4)                    # корпус
    for x in (18, 24, 30):                                                    # насечки
        bline(d, s, [(x, 26), (x, 36)], "steel4", 2.0)
    bpoly(d, s, [(44, 20), (54, 20), (58, 42), (44, 42)], "steel3")           # раструб
    brect(d, s, 52, 22, 58, 40, "brass2", "ink", 1.8, r=2)                    # линза
    bpoly(d, s, [(58, 24), (64, 14), (64, 48), (58, 38)], "cream", None, 0)   # луч
    brect(d, s, 26, 20, 36, 25, "rust2", "ink", 1.6, r=2)                     # кнопка
    bline(d, s, [(14, 32), (42, 32)], "steel5", 1.6)


def i_detector(d, s):
    bpoly(d, s, [(14, 22), (50, 22), (54, 32), (52, 54), (12, 54), (10, 32)], "steel2")
    brect(d, s, 18, 34, 40, 44, "glass", "ink", 1.8, r=3)                     # экран
    brect(d, s, 20, 36, 30, 39, "toxic", None)
    bline(d, s, [(20, 41), (36, 41)], "toxic2", 1.6)
    bcirc(d, s, 46, 46, 5.0, "steel3", "ink", 1.8)                            # ручка настройки
    bline(d, s, [(46, 42), (46, 50)], "ink", 1.4)
    sline(d, s, [(32, 22), (32, 10)], "steel4", 3.0)                          # антенна
    bcirc(d, s, 32, 8, 3.4, "amber", "ink", 1.6)
    barc(d, s, 32, 8, 8.0, 200, 340, "amber", 1.6)                            # «волны»
    barc(d, s, 32, 8, 13.0, 205, 335, "amber", 1.4)


def i_bolt(d, s):
    bpoly(d, s, bar_pts((18, 56), (44, 22), 5.5), "steel3")                   # стержень
    for t in range(5):                                                        # резьба
        x = 20 + t * 6
        bline(d, s, [(x - 3, 52 - t * 6), (x + 3, 47 - t * 6)], "steel1", 1.6)
    hexa = [(44 + 18 * math.cos(math.radians(a)), 20 + 18 * math.sin(math.radians(a)))
            for a in range(0, 360, 60)]
    bpoly(d, s, hexa, "steel4", "ink", 2.0)                                   # гайка
    bcirc(d, s, 44, 20, 8.0, "ink", None)
    bcirc(d, s, 44, 20, 8.0, None, "steel2", 2.0)


def i_geiger(d, s):
    brect(d, s, 18, 14, 48, 54, "olive2", "ink", 2.4, r=5)                    # корпус
    bcirc(d, s, 33, 27, 11.0, "cream", "ink", 2.2)                            # шкала
    for a in range(200, 341, 20):
        r = math.radians(a)
        bline(d, s, [(33 + math.cos(r) * 7, 27 + math.sin(r) * 7),
                     (33 + math.cos(r) * 10, 27 + math.sin(r) * 10)], "ink", 1.4)
    bline(d, s, [(33, 27), (27, 20)], "blood2", 2.4)                          # стрелка
    bcirc(d, s, 33, 27, 1.8, "ink", None)
    brect(d, s, 22, 40, 44, 50, "glass", "ink", 1.8, r=2)
    brect(d, s, 24, 42, 34, 45, "toxic2", None)
    sline(d, s, [(44, 14), (52, 4)], "steel3", 2.6)                           # антенна
    bcirc(d, s, 22, 20, 2.4, "blood2", None)


def i_energy(d, s):
    brect(d, s, 22, 12, 42, 54, "steel3", "ink", 2.2, r=3)                    # банка
    bcirc(d, s, 32, 13, 9.5, "steel5", "ink", 1.8)                            # крышка
    barc(d, s, 32, 13, 5.0, 200, 340, "steel2", 2.0)                          # кольцо-язычок
    brect(d, s, 22, 22, 42, 44, "toxic", "ink", 1.8)                          # «молния»
    bpoly(d, s, [(34, 24), (27, 36), (32, 36), (29, 45), (38, 32), (33, 32)], "ink", None)
    bline(d, s, [(24, 48), (40, 48)], "toxic2", 2.0)
    bline(d, s, [(24, 18), (24, 50)], "steel5", 1.6)


def i_antidote(d, s):
    brect(d, s, 26, 8, 38, 20, "steel3", "ink", 1.8, r=2)                     # колпачок
    bcirc(d, s, 32, 9, 5.0, "steel2", "ink", 1.6)
    brect(d, s, 20, 19, 44, 56, "glass", "ink", 2.2, r=6)                     # ампула
    brect(d, s, 23, 30, 41, 53, "toxic", "ink", 1.6, r=4)                     # жидкость
    bline(d, s, [(27, 34), (37, 34)], "toxic2", 1.8)
    brect(d, s, 20, 24, 44, 29, "blood2", "ink", 1.4)                         # красный поясок
    bline(d, s, [(24, 22), (24, 52)], "steel5", 1.6)


def i_binocular(d, s):
    bcirc(d, s, 20, 34, 12.0, "steel2", "ink", 2.2)                           # тубусы
    bcirc(d, s, 44, 34, 12.0, "steel2", "ink", 2.2)
    brect(d, s, 26, 26, 38, 42, "steel1", "ink", 1.8, r=2)                    # перемычка
    bcirc(d, s, 20, 46, 8.5, "glass", "ink", 2.0)                             # объективы
    bcirc(d, s, 44, 46, 8.5, "glass", "ink", 2.0)
    bcirc(d, s, 20, 46, 4.0, "cream", None)
    bcirc(d, s, 44, 46, 4.0, "cream", None)
    brect(d, s, 14, 14, 26, 24, "steel3", "ink", 1.8, r=2)                    # окуляры
    brect(d, s, 38, 14, 50, 24, "steel3", "ink", 1.8, r=2)
    bline(d, s, [(16, 18), (20, 18)], "steel5", 1.6)
    bline(d, s, [(40, 18), (44, 18)], "steel5", 1.6)


def i_radio(d, s):
    brect(d, s, 18, 16, 46, 54, "olive2", "ink", 2.4, r=4)                    # корпус
    brect(d, s, 22, 20, 42, 32, "olive0", "ink", 1.8, r=2)                    # решётка
    for y in (23, 26, 29):
        bline(d, s, [(25, y), (39, y)], "steel2", 1.6)
    brect(d, s, 22, 34, 34, 42, "glass", "ink", 1.6, r=2)                     # экран
    brect(d, s, 24, 36, 30, 39, "toxic2", None)
    bcirc(d, s, 40, 42, 4.0, "steel2", "ink", 1.6)                            # верньер
    bline(d, s, [(40, 38), (40, 46)], "ink", 1.4)
    sline(d, s, [(42, 16), (50, 4)], "steel3", 2.8)                           # антенна
    bcirc(d, s, 51, 3, 2.8, "steel4", "ink", 1.4)
    brect(d, s, 46, 24, 50, 34, "rust2", "ink", 1.4, r=2)                     # PTT
    bline(d, s, [(22, 48), (40, 48)], "olive4", 1.8)


def i_scrap(d, s):
    bpoly(d, s, [(6, 48), (30, 34), (36, 44), (12, 58)], "rust2")             # пластина
    bpoly(d, s, [(24, 22), (52, 18), (54, 30), (26, 34)], "steel2")           # вторая
    bpoly(d, s, [(34, 36), (58, 42), (56, 54), (32, 48)], "rust1")
    bcirc(d, s, 22, 30, 6.0, "steel3", "ink", 1.8)                            # гайка
    bcirc(d, s, 22, 30, 2.4, "ink", None)
    bpoly(d, s, bar_pts((44, 14), (58, 30), 3.6), "steel4")                   # погнутый прут
    bpoly(d, s, bar_pts((58, 30), (52, 40), 3.6), "steel4")
    bline(d, s, [(14, 44), (30, 36)], "rust3", 1.8)


def i_tools(d, s):
    bpoly(d, s, bar_pts((10, 54), (44, 22), 4.5), "steel3")                   # ключ
    bpoly(d, s, bar_pts((44, 22), (54, 12), 5.0), "steel4")
    bpoly(d, s, [(46, 6), (60, 13), (56, 22), (42, 15)], "steel4")            # зев ключа
    bpoly(d, s, bar_pts((52, 54), (26, 26), 3.2), "steel5")                   # отвёртка
    bpoly(d, s, [(26, 26), (20, 18), (26, 12), (32, 20)], "steel5")
    bpoly(d, s, bar_pts((56, 58), (44, 46), 6.0), "olive0")                   # рукоять
    bline(d, s, [(48, 50), (56, 58)], "olive4", 2.0)
    bcirc(d, s, 20, 34, 3.0, "rust2", "ink", 1.4)


def i_docs(d, s):
    bpoly(d, s, [(10, 14), (44, 10), (48, 46), (14, 50)], "steel4")           # нижний лист
    bpoly(d, s, [(14, 12), (48, 16), (44, 52), (10, 48)], "bone")             # верхний лист
    bpoly(d, s, [(36, 14), (48, 16), (46, 26)], "steel3")                     # отогнутый угол
    for y in (22, 28, 34, 40):
        bline(d, s, [(18, y), (38, y + 1)], "ink", 1.6)
    bcirc(d, s, 34, 44, 6.0, None, "blood2", 2.0)                             # печать
    bline(d, s, [(30, 44), (38, 44)], "blood2", 1.6)
    bcirc(d, s, 16, 16, 3.4, None, "steel2", 1.8)                             # скрепка


def i_key(d, s):
    bcirc(d, s, 22, 22, 13.0, None, "brass", 4.5)                             # кольцо-бородка
    bcirc(d, s, 22, 22, 6.0, None, "brass", 3.0)
    bpoly(d, s, bar_pts((30, 30), (56, 56), 4.5), "brass2")                   # стержень
    bpoly(d, s, [(48, 48), (56, 40), (60, 44), (52, 52)], "brass2")           # зубцы
    bpoly(d, s, [(40, 40), (46, 34), (50, 38), (44, 44)], "brass2")
    bline(d, s, [(26, 26), (30, 30)], "brass", 3.0)
    bcirc(d, s, 22, 22, 4.0, "ink", None)
    bline(d, s, [(18, 16), (26, 16)], "brass2", 2.0)


def i_quest_note(d, s):
    bpoly(d, s, [(12, 8), (52, 8), (52, 52), (12, 52)], "bone")               # лист
    for y in (18, 27, 36):
        bline(d, s, [(17, y), (47, y)], "ink", 1.8)
        bline(d, s, [(17, y + 5), (38, y + 5)], "ink", 1.6)
    bcirc(d, s, 40, 46, 6.5, "blood2", "ink", 1.8)                            # сургуч
    bcirc(d, s, 40, 46, 2.4, "ink", None)
    bpoly(d, s, [(12, 8), (23, 8), (12, 19)], "steel2")                       # загнутый уголок
    bline(d, s, [(12, 24), (12, 52)], "rust1", 1.6)


def i_radiation(d, s):
    for k in range(3):
        a0 = math.radians(-90 + k * 120 - 26)
        a1 = math.radians(-90 + k * 120 + 26)
        out = [(32 + math.cos(a0 + (a1 - a0) * t / 6.0) * 26,
                32 + math.sin(a0 + (a1 - a0) * t / 6.0) * 26) for t in range(7)]
        inn = [(32 + math.cos(a1 + (a0 - a1) * t / 6.0) * 8,
                32 + math.sin(a1 + (a0 - a1) * t / 6.0) * 8) for t in range(7)]
        bpoly(d, s, out + inn, "toxic", "ink", 1.8)
    bcirc(d, s, 32, 32, 7.0, "toxic", "ink", 1.8)


def i_weapon_empty(d, s):
    for x0, y0, x1, y1 in ((6, 6, 22, 8), (42, 6, 58, 8), (6, 56, 22, 58), (42, 56, 58, 58),
                           (6, 6, 8, 22), (56, 6, 58, 22), (6, 42, 8, 58), (56, 42, 58, 58)):
        brect(d, s, x0, y0, x1, y1, "steel3", None)
    brect(d, s, 14, 26, 50, 34, "steel1", "steel3", 1.8, r=2)                 # силуэт «пусто»
    bpoly(d, s, [(20, 34), (34, 34), (30, 48), (16, 48)], "steel1")
    bpoly(d, s, [(36, 34), (50, 34), (46, 46), (34, 48)], "steel1")
    bline(d, s, [(14, 30), (50, 30)], "steel2", 1.6)


# --- артефакты ---------------------------------------------------------------
def petal(d, s, cx, cy, ang, r0, r1, half0, half1, fill, line="ink", w=1.8):
    """Лепесток/луч: выпуклый пятиугольник вдоль направления ang."""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    mid = (r0 + r1) * 0.55
    bpoly(d, s, [(cx + ux * r0 + nx * half1, cy + uy * r0 + ny * half1),
                 (cx + ux * mid + nx * half0, cy + uy * mid + ny * half0),
                 (cx + ux * r1, cy + uy * r1),
                 (cx + ux * mid - nx * half0, cy + uy * mid - ny * half0),
                 (cx + ux * r0 - nx * half1, cy + uy * r0 - ny * half1)],
          fill, line, w)


def i_medusa(d, s):
    bline(d, s, [(24, 38), (21, 50), (26, 58)], "cyan", 3.0)                  # щупальца
    bline(d, s, [(32, 40), (32, 52), (35, 58)], "cyan2", 3.0)
    bline(d, s, [(40, 38), (43, 50), (38, 58)], "cyan", 3.0)
    bpoly(d, s, [(12, 40), (14, 24), (24, 14), (40, 14), (50, 24), (52, 40)], "cyan")
    bpoly(d, s, [(20, 36), (22, 26), (30, 22), (34, 30), (32, 38)], "cyan2", None)
    bpoly(d, s, [(38, 30), (44, 26), (47, 34), (42, 38)], "cyan2", None)
    bline(d, s, [(14, 40), (52, 40)], "ink", 1.8)
    bcirc(d, s, 24, 26, 3.0, "glass", None)


def i_flower(d, s):
    for k in range(6):
        petal(d, s, 32, 34, -90 + k * 60, 6, 24, 8.0, 4.5, "blood2", "ink", 1.8)
        petal(d, s, 32, 34, -90 + k * 60, 12, 21, 4.5, 2.0, "blood3", None)
    bcirc(d, s, 32, 34, 8.0, "amber", "ink", 2.0)
    bcirc(d, s, 32, 34, 3.5, "amber2", None)
    bline(d, s, [(32, 44), (32, 56)], "olive2", 3.0)                          # стебель
    petal(d, s, 32, 54, 30, 2, 12, 5.0, 2.0, "olive3", "ink", 1.4)


def i_soul(d, s):
    for ang in (150, 195, 250, 300, 345):
        a = math.radians(ang)
        bline(d, s, [(32 + math.cos(a) * 12, 34 + math.sin(a) * 12),
                     (32 + math.cos(a) * 26, 40 + math.sin(a) * 26)], "bone", 2.6)
    bpoly(d, s, [(32, 8), (44, 18), (48, 34), (40, 48), (24, 48), (16, 34), (20, 18)], "bone")
    bpoly(d, s, [(32, 14), (40, 22), (42, 33), (34, 42), (26, 38), (22, 28)], "cream", None)
    bline(d, s, [(30, 40), (30, 50), (34, 56)], "bone", 2.4)
    bcirc(d, s, 28, 26, 3.0, "cream", None)
    bcirc(d, s, 38, 26, 3.0, "cream", None)


def i_moonlight(d, s):
    for k in range(4):
        petal(d, s, 32, 32, k * 90, 0, 28, 7.0, 2.0, "amber", "ink", 1.8)
    for k in range(4):
        petal(d, s, 32, 32, 45 + k * 90, 0, 17, 5.0, 1.6, "amber2", "ink", 1.4)
    bcirc(d, s, 32, 32, 9.0, "cream", "ink", 1.8)
    bcirc(d, s, 32, 32, 4.0, "amber2", None)
    for x, y in ((18, 16), (46, 18), (14, 46), (48, 44)):
        bcirc(d, s, x, y, 2.0, "amber2", None)


def i_fruit(d, s):
    bpoly(d, s, [(32, 20), (44, 26), (46, 44), (32, 54), (18, 44), (20, 26)], "rust3")
    bpoly(d, s, [(32, 26), (40, 30), (41, 42), (32, 48), (23, 42), (24, 30)], "amber")
    for x, y in ((28, 34), (36, 34), (32, 42)):
        bcirc(d, s, x, y, 3.0, "rust1", "ink", 1.4)
    bline(d, s, [(32, 20), (32, 10)], "olive1", 3.0)                          # черешок
    petal(d, s, 32, 12, 200, 2, 12, 5.0, 2.0, "olive3", "ink", 1.4)
    petal(d, s, 32, 12, 340, 2, 12, 5.0, 2.0, "olive3", "ink", 1.4)


def i_grav(d, s):
    bcirc(d, s, 32, 34, 17.0, "steel0", "ink", 2.0)
    bcirc(d, s, 32, 34, 11.0, "ink", None)
    sarc(d, s, 32, 34, 21.5, 200, 340, "cyan", 2.4)                           # кольцо искажения
    sarc(d, s, 32, 34, 25.0, 20, 160, "cyan2", 2.0)
    barc(d, s, 32, 34, 13.0, 150, 300, "steel4", 2.4)                         # завихрение
    barc(d, s, 32, 34, 8.0, 330, 120, "steel3", 2.0)
    bcirc(d, s, 26, 28, 4.0, "steel3", None)
    bcirc(d, s, 32, 34, 3.0, "cyan2", None)


# --------------------------------------------------------------------- сборка
def hud_panel(name, seed, w, h, accent, note):
    """Панель для hud.gd (NinePatchRect, отступ 12 px) — как panel_vitals."""
    a = plate(w, h, seed, border=12, radius=6, body="steel1", band="steel0",
              alpha=0.86, alpha_band=0.9, shadow=0.4, rust=0.26, grime=0.22, weld=False)
    a = src_over(a, accent_frame(w, h, border=12, radius=6, accent=accent, thick=1.4,
                                 bolt_rad=2.6, corners=False, inner_line=True))
    save_u(name, a, 12, note)
    return a


def build_panels():
    panel_window()
    panel_window_light()
    panel_tooltip()
    panel_slot("panel_slot", "steel4", 1101, note="слот инвентаря (утопленное гнездо)")
    panel_slot("panel_slot_sel", "amber", 1102, glow=True,
               note="слот: выбран (янтарная рамка + свечение)")
    panel_slot("panel_slot_rare", "cyan2", 1103, glow=True, note="слот: редкий предмет")
    panel_slot("panel_slot_quest", "toxic2", 1104, glow=True, note="слот: квестовый предмет")
    panel_divider()
    bar_frame("bar_frame", 1201, 256, 32, 8, "steel4", "steel1", "универсальная рамка полосы")
    bar_frame("bar_frame_hp", 1202, 256, 32, 8, "blood2", "steel1", "рамка полосы здоровья")
    bar_frame("bar_frame_stamina", 1203, 256, 32, 8, "olive4", "steel1", "рамка полосы стамины")
    bar_frame("bar_frame_xp", 1204, 256, 32, 8, "toxic", "steel1", "рамка полосы опыта")
    bar_frame("bar_thin_frame", 1205, 128, 12, 4, "steel4", "steel0", "тонкая рамка (таймеры)")
    bar_fill("bar_fill_hp", "blood3", "blood2", "blood0", 1301,
             note="заполнение HP: красный градиент + шум")
    bar_fill("bar_fill_stamina", "amber2", "olive3", "olive0", 1302,
             note="заполнение стамины: жёлто-оливковый")
    bar_fill("bar_fill_xp", "toxic2", "toxic", "olive0", 1303,
             note="заполнение опыта: токсично-зелёный")
    bar_fill("bar_fill_boss", "blood2", "blood", "rust0", 1304,
             note="полоса босса: тёмно-красная")
    hud_panel("panel_vitals", 1401, 200, 112, "rust2", "панель здоровья (запрос hud.gd)")
    hud_panel("panel_detector", 1402, 168, 96, "toxic", "панель детектора аномалий")
    hud_panel("panel_actionbar", 1403, 160, 96, "amber", "панель быстрых действий")


def build_buttons():
    button("btn_idle", 1, note="кнопка: обычная (ржавая сталь)")
    button("btn_hover", 2, body="steel2", accent="rust3", shadow=0.45,
           note="кнопка: наведение (светлее + яркий кант)")
    button("btn_press", 3, body="steel0", accent="rust1", pressed=True,
           note="кнопка: нажатие (утоплена, тень сверху)")
    button("btn_disabled", 4, body="steel0", band="steel1", accent="steel2", alpha=0.55,
           note="кнопка: недоступна (полупрозрачная, серая)")
    button_round("btn_round_idle", 11, note="круглая кнопка: обычная")
    button_round("btn_round_press", 12, pressed=True, accent="amber",
                 note="круглая кнопка: нажатие")
    joy_base()
    joy_knob()


def build_touch():
    touch_btn("touch_attack", g_attack, 2001, "тач: атака (нож + патрон)", "amber")
    touch_btn("touch_use", g_use, 2002, "тач: действие/обыск (открытая ладонь)", "steel4")
    touch_btn("touch_dodge", g_dodge, 2003, "тач: рывок (двойной шеврон)", "amber")
    touch_btn("touch_bag", g_bag, 2004, "тач: инвентарь (рюкзак)", "olive4")
    touch_btn("touch_journal", g_journal, 2005, "тач: журнал (блокнот)", "olive4")
    touch_btn("touch_pause", g_pause, 2006, "тач: пауза (две полосы)", "steel4")
    touch_btn("touch_heal", g_heal, 2007, "тач: аптечка (красный крест)", "blood2")
    touch_btn("touch_map", g_map, 2008, "тач: карта", "steel5")
    touch_btn("touch_swap", g_swap, 2009, "тач: смена оружия (стрелки между стволами)", "amber")


def build_hud():
    minimap_frame()
    crosshair()
    cursor_arrow()
    quest_marker()
    skull_marker()
    party_marker()
    vignette()
    blood_overlay()
    damage_flash()
    noise_overlay()
    scanlines()
    radar_grid()
    compass()
    danger_arrow()


def build_plates():
    banner("banner_quest", 7001, "rust1", "rust0", "amber", ("amber", "ink"),
           "баннер квеста: ржавая пластина с зеброй")
    banner("banner_levelup", 7002, "olive1", "olive0", "toxic2", ("toxic", "ink"),
           "баннер повышения уровня")
    log_plate()
    dlg_portrait_frame()


def build_icons():
    icon("icon_pm", i_pm, 8001, "ПМ (пистолет Макарова)")
    icon("icon_ak", i_ak, 8002, "АК-74")
    icon("icon_shotgun", i_shotgun, 8003, "обрез")
    icon("icon_knife", i_knife, 8004, "нож охотничий")
    icon("icon_crossbow", i_crossbow, 8005, "арбалет")
    icon("icon_ammo_9x18", lambda d, s: i_ammo_box(d, s, "olive2", "olive1", 3, 12),
         8006, "патроны 9x18")
    icon("icon_ammo_545", lambda d, s: i_ammo_box(d, s, "olive0", "olive1", 4, 16),
         8007, "патроны 5.45")
    icon("icon_ammo_12ga", lambda d, s: i_ammo_box(d, s, "rust0", "rust1", 2, 10, True),
         8008, "патроны 12x70 (дробь)")
    icon("icon_bolt", i_bolt, 8009, "болт с гайкой")
    icon("icon_armor_leather", i_armor_leather, 8010, "куртка сталкера")
    icon("icon_armor_plate", i_armor_plate, 8011, "комбинезон «Заря» / бронеплита")
    icon("icon_armor_exo", i_armor_exo, 8012, "экзоскелет «Буревестник»")
    icon("icon_helmet", i_helmet, 8013, "шлем «Сфера»")
    icon("icon_medkit", i_medkit, 8014, "аптечка")
    icon("icon_bandage", i_bandage, 8015, "бинт")
    icon("icon_antidote", i_antidote, 8016, "антирад")
    icon("icon_vodka", i_vodka, 8017, "водка")
    icon("icon_canned", i_canned, 8018, "тушёнка")
    icon("icon_bread", i_bread, 8019, "хлеб")
    icon("icon_energy_drink", i_energy, 8020, "энергетик")
    icon("icon_flashlight", i_flashlight, 8021, "фонарь")
    icon("icon_detector", i_detector, 8022, "детектор «Отклик»")
    icon("icon_binocular", i_binocular, 8023, "бинокль")
    icon("icon_radio", i_radio, 8024, "рация")
    icon("icon_geiger", i_geiger, 8025, "дозиметр")
    icon("icon_scrap", i_scrap, 8026, "хлам")
    icon("icon_tools", i_tools, 8027, "инструменты")
    icon("icon_docs", i_docs, 8028, "документы")
    icon("icon_key", i_key, 8029, "ключ от бункера")
    icon("icon_quest_note", i_quest_note, 8030, "записка с заданием")
    icon("icon_radiation", i_radiation, 8031, "знак радиации (HUD-иконка)")
    icon("icon_weapon_empty", i_weapon_empty, 8032, "пустой слот оружия")
    icon("icon_artifact_medusa", i_medusa, 8101, "артефакт «Медуза» (синий)", "cyan")
    icon("icon_artifact_flower", i_flower, 8102, "артефакт «Цветок» (красный)", "blood2")
    icon("icon_artifact_soul", i_soul, 8103, "артефакт «Душа» (бледный)", "bone")
    icon("icon_artifact_moonlight", i_moonlight, 8104, "«Ночная звезда» (жёлтый)", "amber")
    icon("icon_artifact_fruit", i_fruit, 8105, "артефакт «Плод» (оранжевый)", "rust3")
    icon("icon_artifact_grav", i_grav, 8106, "«Гравиконцентрат»", "cyan")


def build_branding():
    logo()
    splash_bg()
    icon_app()


# -------------------------------------------------------------- контрольные листы
def ui_path(name):
    return os.path.join(P.UI, name + ".png")


def sheet(names, out_name, cell, cols):
    paths = [ui_path(n) for n in names if os.path.exists(ui_path(n))]
    return P.contact_sheet(paths, os.path.join(OUT, out_name), cell, cols)


def sheet_icons32(names, out_name, cols=10):
    """Лист иконок, уменьшенных до 32 px — проверка читаемости на телефоне."""
    cell = 48
    tiles = []
    for n in names:
        p = ui_path(n)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        small = im.resize((32, 32), Image.LANCZOS)
        canvas = Image.new("RGBA", (cell, cell), (26, 26, 30, 255))
        canvas.paste(small, ((cell - 32) // 2, (cell - 32) // 2), small)
        tiles.append((n, canvas))
    rows = max((len(tiles) + cols - 1) // cols, 1)
    sheet_img = Image.new("RGBA", (cols * cell, rows * cell), (26, 26, 30, 255))
    d = ImageDraw.Draw(sheet_img)
    for i, (name, t) in enumerate(tiles):
        x, y = (i % cols) * cell, (i // cols) * cell
        sheet_img.paste(t, (x, y), t)
        d.rectangle([x, y, x + cell - 1, y + cell - 1], outline=(70, 70, 80, 255))
        d.text((x + 4, y + 2), name.replace("icon_", "")[:12], fill=(225, 200, 140, 255))
    sheet_img.convert("RGB").save(os.path.join(OUT, out_name))
    return os.path.join(OUT, out_name)


ICON_ORDER = ["icon_pm", "icon_ak", "icon_shotgun", "icon_knife", "icon_crossbow",
              "icon_ammo_9x18", "icon_ammo_545", "icon_ammo_12ga", "icon_bolt",
              "icon_armor_leather", "icon_armor_plate", "icon_armor_exo", "icon_helmet",
              "icon_medkit", "icon_bandage", "icon_antidote", "icon_vodka", "icon_canned",
              "icon_bread", "icon_energy_drink", "icon_flashlight", "icon_detector",
              "icon_binocular", "icon_radio", "icon_geiger", "icon_scrap", "icon_tools",
              "icon_docs", "icon_key", "icon_quest_note", "icon_radiation",
              "icon_weapon_empty", "icon_artifact_medusa", "icon_artifact_flower",
              "icon_artifact_soul", "icon_artifact_moonlight", "icon_artifact_fruit",
              "icon_artifact_grav"]

PANEL_ORDER = ["panel_window", "panel_window_light", "panel_tooltip", "panel_slot",
               "panel_slot_sel", "panel_slot_rare", "panel_slot_quest", "panel_vitals",
               "panel_detector", "panel_actionbar", "panel_divider", "bar_frame",
               "bar_frame_hp", "bar_frame_stamina", "bar_frame_xp", "bar_thin_frame",
               "bar_fill_hp", "bar_fill_stamina", "bar_fill_xp", "bar_fill_boss",
               "btn_idle", "btn_hover", "btn_press", "btn_disabled", "btn_round_idle",
               "btn_round_press", "joy_base", "joy_knob", "banner_quest", "banner_levelup",
               "log_plate", "dlg_portrait_frame"]

TOUCH_ORDER = ["touch_attack", "touch_use", "touch_dodge", "touch_bag", "touch_journal",
               "touch_pause", "touch_heal", "touch_map", "touch_swap", "minimap_frame",
               "compass", "crosshair", "cursor", "quest_marker", "skull_marker",
               "party_marker", "danger_arrow", "radar_grid"]

MANIFEST_GROUPS = [
    ("ОКНА, ПАНЕЛИ, СЛОТЫ", ["panel_window", "panel_window_light", "panel_tooltip",
                             "panel_slot", "panel_slot_sel", "panel_slot_rare",
                             "panel_slot_quest", "panel_vitals", "panel_detector",
                             "panel_actionbar", "dlg_portrait_frame"]),
    ("ПОЛОСЫ И РАЗДЕЛИТЕЛИ", ["bar_frame", "bar_frame_hp", "bar_frame_stamina",
                              "bar_frame_xp", "bar_thin_frame", "bar_fill_hp",
                              "bar_fill_stamina", "bar_fill_xp", "bar_fill_boss",
                              "panel_divider"]),
    ("КНОПКИ И ДЖОЙСТИК", ["btn_idle", "btn_hover", "btn_press", "btn_disabled",
                           "btn_round_idle", "btn_round_press", "joy_base", "joy_knob"]),
    ("ТАЧ-HUD (глифовые кнопки 128x128)", ["touch_attack", "touch_use", "touch_dodge",
                                           "touch_bag", "touch_journal", "touch_pause",
                                           "touch_heal", "touch_map", "touch_swap"]),
    ("ДЕКОР HUD И ЭКРАННЫЕ СЛОИ", ["minimap_frame", "compass", "crosshair", "cursor",
                                   "quest_marker", "skull_marker", "party_marker",
                                   "danger_arrow", "radar_grid", "vignette",
                                   "blood_overlay", "damage_flash", "noise_overlay",
                                   "scanlines"]),
    ("ПЛАШКИ ТЕКСТА", ["banner_quest", "banner_levelup", "log_plate"]),
    ("ИКОНКИ ПРЕДМЕТОВ 64x64 (читаемы в 32 px)", ICON_ORDER),
    ("БРЕНДИНГ", ["logo", "splash_bg", "icon_app"]),
]


def write_manifest():
    """assets/ui/MANIFEST.txt — что за файл, размер и отступ 9-slice."""
    lines = [
        "ЗОНА: Пикник на обочине — MANIFEST интерфейса (assets/ui)",
        "=" * 96,
        "Сгенерировано процедурно: tools/gen/gen_ui.py (numpy + PIL, сиды фиксированы).",
        "Все файлы — PNG с альфой. Колонка «9-slice» — отступ для NinePatchRect в Godot 4",
        "(patch_margin_left/right/top/bottom); 0 = тянуть/тайлить целиком без 9-slice.",
        "Русские шрифты (Oswald.ttf, PT_Sans-Narrow-Web-Regular.ttf) не изменялись.",
        "",
    ]
    total = 0
    for title, names in MANIFEST_GROUPS:
        lines.append(f"[{title}]")
        for n in names:
            info = PRODUCED.get(n)
            if info is None:
                continue
            size = f"{info['w']}x{info['h']}"
            b = info["border"]
            bs = f"9-slice {b} px" if b else "без 9-slice"
            lines.append(f"  {n + '.png':<30} {size:>9}  {bs:<14} {info['note']}")
            total += 1
        lines.append("")
    lines += [
        "ПРОЧЕЕ",
        "  Контрольные листы (вне assets): tools/gen/_out/sheet_ui_panels.png,",
        "  sheet_ui_icons.png, sheet_ui_icons_32.png, sheet_ui_touch.png, sheet_ui_brand.png.",
        f"  Всего файлов: {total}.",
        "",
        "ПОДСКАЗКИ ПО ИСПОЛЬЗОВАНИЮ",
        "  * Панели/кнопки/слоты: NinePatchRect с patch_margin = значению «9-slice».",
        "  * Полосы: bar_frame_* + bar_fill_* внутрь, растягивать по X (STRETCH_SCALE).",
        "  * scanlines.png, radar_grid.png, noise_overlay.png — тайлы (TEXTURE_REPEAT).",
        "  * Иконки предметов — 64x64, читаемы при уменьшении до 32 px (имена совпадают",
        "    с полем \"icon\" в scripts/item_db.gd).",
    ]
    path = os.path.join(P.UI, "MANIFEST.txt")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    P.ensure_dirs()
    build_panels()
    build_buttons()
    build_touch()
    build_hud()
    build_plates()
    build_icons()
    build_branding()
    sheets = [
        sheet(PANEL_ORDER, "sheet_ui_panels.png", 176, 6),
        sheet(ICON_ORDER, "sheet_ui_icons.png", 96, 8),
        sheet_icons32(ICON_ORDER, "sheet_ui_icons_32.png", 10),
        sheet(TOUCH_ORDER, "sheet_ui_touch.png", 160, 6),
        sheet(["logo", "splash_bg", "icon_app"], "sheet_ui_brand.png", 384, 3),
    ]
    mpath = write_manifest()
    total = sum(os.path.getsize(ui_path(n)) for n in PRODUCED)
    print(f"gen_ui: файлов {len(PRODUCED)}, суммарно {total // 1024} KiB")
    for s in sheets:
        print("  лист:", s)
    print("  манифест:", mpath)
    return len(PRODUCED)


if __name__ == "__main__":
    main()
