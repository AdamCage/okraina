# -*- coding: utf-8 -*-
"""gen_sprites.py — процедурная генерация всех спрайтов игры «ЗОНА: Пикник на обочине».

Что делает:
  * персонажи и монстры — горизонтальные полосы кадров 64x64 (ноги на y≈58,
    совпадает с Assets.SHEET_ANCHOR = Vector2(32,58));
  * пропы — одиночные RGBA-спрайты собственного размера + normal-map;
  * аномалии и FX — листы для аддитивного бленда (normal-map не нужен);
  * assets/sprites/MANIFEST.txt — машиночитаемый список всего сгенерированного.

Всё детерминировано: только seeded numpy.random.default_rng.
Запуск:  cd tools/gen; python gen_sprites.py
"""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image, ImageDraw

import paint as P

OUT = os.path.join(P.ROOT, "tools", "gen", "_out")
SPR = P.SPR
SS = 4                      # суперсемплинг масок (сглаженные силуэты)
F = 64                      # размер кадра анимационного листа
FOOT = 58.0                 # линия «ног» внутри кадра

# ------------------------------------------------------------------ палитра
def hx(s: str):
    return P.hexa(s)


OLIVE     = hx("63604A")    # олива-серый (плащ сталкера)
OLIVE_D   = hx("403C2C")
OLIVE_L   = hx("8B8568")
PANTS     = hx("565042")
CANVAS    = hx("8A7E55")    # брезент
CANVAS_D  = hx("5C5236")
RUST      = hx("7C4726")
RUST_D    = hx("4B2A18")
METAL     = hx("6F7377")
METAL_D   = hx("3C4044")
METAL_L   = hx("9AA0A4")
BONE      = hx("C6BA99")
WOOD      = hx("6B4E31")
WOOD_D    = hx("3D2B1B")
CONCRETE  = hx("8B8981")
CONCRETE_D= hx("5A5852")
DIRT      = hx("5B4832")
DIRT_L    = hx("796044")
TOXIC     = hx("84B32C")
TOXIC_D   = hx("3E4F15")
TOXIC_L   = hx("C7E86A")
BLOOD     = hx("6E1A14")
BLOOD_D   = hx("40100C")
SKIN      = hx("B78F68")
SKIN_D    = hx("7E5F42")
SKIN_PALE = hx("C9B7A0")
FLESH_MUT = hx("63261F")    # кровосос
FLESH_MUT_L = hx("8A3B2C")
ZOMB_SKIN = hx("6C7350")
MASK_GRN  = hx("5A624A")    # резина противогаза
GLASS     = hx("26332C")
GUNMETAL  = hx("5C6064")    # сталь ствола (светлее, чтобы читалась на куртке)
WOOD_GUN  = hx("8A5A2E")    # дерево цевья/приклада
FIRE      = hx("FF8A28")
FIRE_HOT  = hx("FFEAA8")
FIRE_D    = hx("B23D0C")
ELEC      = hx("BFE8FF")
ELEC_D    = hx("4E86D8")
GRAV      = hx("9C8FB4")
FRUIT     = hx("B7D24A")


# ------------------------------------------------------------------ шум WxH
def vnoise(w: int, h: int, res: int, seed: int) -> np.ndarray:
    """Value-noise произвольного размера (спрайты не тайлятся, периодичность не нужна)."""
    res = max(2, int(res))
    g = np.random.default_rng(seed).random((res + 2, res + 2)).astype(np.float32)
    xs = np.linspace(0.0, res, w, endpoint=False)
    ys = np.linspace(0.0, res, h, endpoint=False)
    i0 = np.clip(np.floor(xs).astype(np.int64), 0, res - 1)
    j0 = np.clip(np.floor(ys).astype(np.int64), 0, res - 1)
    tx = xs - i0
    ty = ys - j0
    tx = (tx * tx * (3.0 - 2.0 * tx))[None, :]
    ty = (ty * ty * (3.0 - 2.0 * ty))[:, None]
    a = g[np.ix_(j0, i0)]
    b = g[np.ix_(j0, i0 + 1)]
    c = g[np.ix_(j0 + 1, i0)]
    d = g[np.ix_(j0 + 1, i0 + 1)]
    top = a * (1.0 - tx) + b * tx
    bot = c * (1.0 - tx) + d * tx
    return (top * (1.0 - ty) + bot * ty).astype(np.float32)


def fbm2(w: int, h: int, res: int = 4, octaves: int = 4, seed: int = 0,
         gain: float = 0.5, lac: float = 2.0) -> np.ndarray:
    out = np.zeros((h, w), np.float32)
    amp, tot, r = 1.0, 0.0, float(res)
    for o in range(octaves):
        out += amp * vnoise(w, h, int(round(r)), seed + o * 7919)
        tot += amp
        amp *= gain
        r *= lac
    return (out / max(tot, 1e-6)).astype(np.float32)


def warp2(w: int, h: int, res: int = 4, octaves: int = 4, seed: int = 0,
          warp: float = 5.0) -> np.ndarray:
    """fBm с доменным искажением — рваные, «живые» структуры."""
    dx = fbm2(w, h, 3, 3, seed + 101) - 0.5
    dy = fbm2(w, h, 3, 3, seed + 202) - 0.5
    base = fbm2(w, h, res, octaves, seed)
    xi = np.clip(np.round(np.arange(w, dtype=np.float32)[None, :] + dx * warp), 0, w - 1)
    yi = np.clip(np.round(np.arange(h, dtype=np.float32)[:, None] + dy * warp), 0, h - 1)
    return base[yi.astype(np.int64), xi.astype(np.int64)]


def base_col(c, w: int, h: int, seed: int, amp: float = 0.13, res: int = 6):
    """Базовый цвет с неровностью — «живая» поверхность вместо плоской заливки."""
    n = fbm2(w, h, res, 3, seed)
    v = 1.0 + (n - 0.5) * 2.0 * amp
    return np.asarray(c, np.float32)[None, None, :] * v[..., None]


def speck(w: int, h: int, count: int, seed: int, radius: float = 1.0) -> np.ndarray:
    """Отдельные «крошки»/камешки как маска."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), np.float32)
    ys = rng.integers(0, h, count)
    xs = rng.integers(0, w, count)
    acc[ys, xs] = 1.0
    return P.clamp01(P.gauss(acc, radius) * 3.2)


def radial(w: int, h: int, cx: float, cy: float, r: float, soft: float = 0.6,
           power: float = 1.0) -> np.ndarray:
    ys = np.arange(h, dtype=np.float32)[:, None]
    xs = np.arange(w, dtype=np.float32)[None, :]
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / max(r, 1e-3)
    m = P.clamp01(1.0 - P.smoothstep(1.0 - soft, 1.0, d))
    return (m ** power).astype(np.float32)


def lgrad(w: int, h: int, dx: float, dy: float, cx: float = 0.0,
          cy: float = 0.0) -> np.ndarray:
    """Линейный градиент 0..1 вдоль направления (dx,dy)."""
    ys = np.arange(h, dtype=np.float32)[:, None] - cy
    xs = np.arange(w, dtype=np.float32)[None, :] - cx
    v = xs * dx + ys * dy
    v = (v - v.min()) / max(float(v.max() - v.min()), 1e-6)
    return v.astype(np.float32)


def ragg(m: np.ndarray, amount: float = 0.2, seed: int = 0,
         res: int = 7) -> np.ndarray:
    """Неровный край силуэта: модулируем альфу шумом только в полосе края."""
    h, w = m.shape
    n = (fbm2(w, h, res, 3, seed) - 0.5) * 2.0
    edge = 4.0 * m * (1.0 - m)
    return P.clamp01(m + n * amount * edge)


# ------------------------------------------------------------------ примитивы
def el(d, s, cx, cy, rx, ry, v=255):
    d.ellipse([(cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s], fill=v)


def rc(d, s, x0, y0, x1, y1, r=0.0, v=255):
    if r > 0.05:
        d.rounded_rectangle([x0 * s, y0 * s, x1 * s, y1 * s], radius=max(1, r * s), fill=v)
    else:
        d.rectangle([x0 * s, y0 * s, x1 * s, y1 * s], fill=v)


def pg(d, s, pts, v=255):
    d.polygon([(a * s, b * s) for a, b in pts], fill=v)


def ln(d, s, x0, y0, x1, y1, w, v=255):
    ww = max(1, int(round(w * s)))
    d.line([x0 * s, y0 * s, x1 * s, y1 * s], fill=v, width=ww)
    rr = ww * 0.5 / s
    el(d, s, x0, y0, rr, rr, v)
    el(d, s, x1, y1, rr, rr, v)


def tp(d, s, x0, y0, x1, y1, w0, w1, v=255):
    """Сужающаяся капсула (конечность)."""
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    if L < 1e-4:
        el(d, s, x0, y0, max(w0, w1), max(w0, w1), v)
        return
    px, py = -dy / L, dx / L
    pg(d, s, [(x0 + px * w0, y0 + py * w0), (x1 + px * w1, y1 + py * w1),
              (x1 - px * w1, y1 - py * w1), (x0 - px * w0, y0 - py * w0)], v)
    el(d, s, x0, y0, w0, w0, v)
    el(d, s, x1, y1, w1, w1, v)


def mask(w: int, h: int, fn) -> np.ndarray:
    """Маска из фигур: fn(draw, s) рисует в SS-масштабе, результат AA-усреднён."""
    im = Image.new("L", (w * SS, h * SS), 0)
    fn(ImageDraw.Draw(im), SS)
    im = im.resize((w, h), Image.LANCZOS)
    return P.clamp01(np.asarray(im, np.float32) / 255.0)


# ------------------------------------------------------------------ буфер
class Buf:
    """RGBA-накопитель: цвет, альфа и карта высот для normal-map."""

    __slots__ = ("w", "h", "col", "a", "hgt")

    def __init__(self, w: int, h: int):
        self.w, self.h = int(w), int(h)
        self.col = np.zeros((self.h, self.w, 3), np.float32)
        self.a = np.zeros((self.h, self.w), np.float32)
        self.hgt = np.zeros((self.h, self.w), np.float32)

    def paint(self, m, color, height: float = 0.55, rough: float = 0.0,
              seed: int = 0, amt: float = 0.25) -> None:
        """Наложить маску с цветом (константа или callable(w,h)->(h,w,3))."""
        if rough > 0.0:
            m = ragg(m, rough, seed)
        m = P.clamp01(m)
        if callable(color):
            c = np.asarray(color(self.w, self.h), np.float32)
        else:
            c = np.asarray(color, np.float32)
        if c.ndim == 1:
            c = np.broadcast_to(c, (self.h, self.w, 3))
        inv = 1.0 - m
        a_new = m + self.a * inv
        prem = c * m[..., None] + self.col * (self.a * inv)[..., None]
        self.col = (prem / np.maximum(a_new, 1e-6)[..., None]).astype(np.float32)
        self.hgt = (self.hgt * inv + height * m).astype(np.float32)
        self.a = a_new.astype(np.float32)

    def tint(self, m, rgb_col, amount: float = 1.0) -> None:
        self.col = P.tint_mask(self.col, P.clamp01(m) * amount, rgb_col)

    def scale(self, m, factor) -> None:
        """Умножить яркость в области маски (factor: число или карта)."""
        f = np.asarray(factor, np.float32)
        if f.ndim == 2:
            k = ((1.0 - m) + m * f)[..., None]
        else:
            k = (1.0 + m * (float(f) - 1.0))[..., None]
        self.col = P.clamp01(self.col * k)

    def relief(self, m, dh: float) -> None:
        self.hgt = P.clamp01(self.hgt + P.clamp01(m) * dh)

    def erase(self, m) -> None:
        """Стереть альфу по маске (для колец, дыр и т.п.)."""
        self.a = (self.a * (1.0 - P.clamp01(m))).astype(np.float32)


# ------------------------------------------------------------------ шадинг/вывод
def bake(col: np.ndarray, hgt: np.ndarray, light=(-0.42, -0.78), strength: float = 1.5,
         ao: float = 0.42, ao_r: float = 4.0, pad: int = 3) -> np.ndarray:
    """Запечённый свет + AO. Паддинг убирает wrap-артефакт np.roll на краях."""
    hp = np.pad(hgt, pad)
    cp = np.pad(col, ((pad, pad), (pad, pad), (0, 0)), mode="edge")
    out = P.bake_shade(cp, hp, light=light, strength=strength, ao=ao, ao_radius=ao_r)
    return out[pad:-pad, pad:-pad]


def normal_map(hgt: np.ndarray, strength: float = 3.0, pad: int = 3) -> np.ndarray:
    hp = np.pad(hgt, pad)
    n = P.normal_from_height(hp, strength)
    return n[pad:-pad, pad:-pad]


def render(b: Buf, shade: bool = True, normal: bool = True, quant: int = 40,
           light=(-0.42, -0.78), strength: float = 1.15, ao: float = 0.46,
           nstrength: float = 3.0, edge_ao: float = 0.34, rim: float = 0.20):
    col = bake(b.col, b.hgt, light, strength, ao) if shade else b.col.copy()
    # светлая кромка по верхнему контуру (чтобы силуэт не сливался с землёй)
    if rim > 0.0:
        inner = P.clamp01((P.gauss(b.a, 1.1) - b.a) * 2.6)
        ap = np.pad(b.a, 2)
        dy = (np.roll(ap, -1, 0) - np.roll(ap, 1, 0))[2:-2, 2:-2] * 0.5
        col = col + (inner * P.clamp01(dy * 2.5) * rim)[..., None]
    # внутренний «контактный» контур: отделяет силуэт от фона без чёрной обводки
    if edge_ao > 0.0:
        inner = P.clamp01((P.gauss(b.a, 1.05) - b.a) * 2.2)
        col = col * (1.0 - edge_ao * inner)[..., None]
    if quant > 0:
        col = np.round(P.clamp01(col) * quant) / quant
    rgba = np.concatenate([P.clamp01(col), P.clamp01(b.a)[..., None]], -1)
    rgba = np.where(b.a[..., None] < 0.02, 0.0, rgba).astype(np.float32)
    nrm = normal_map(b.hgt, nstrength) if normal else None
    return rgba, nrm


# ================================================================== ЧЕЛОВЕКОПОДОБНЫЕ
def dk(c, k: float):
    """Затемнить/высветлить цвет (глубина: дальние конечности темнее)."""
    return tuple(float(v) * k for v in np.asarray(c, np.float32))


def draw_ak(b: Buf, x: float, y: float, deg: float, rust: bool = False,
            seed: int = 0, wear: float = 1.0) -> None:
    """АК в 3/4: ствол, деревянные цевьё и приклад, изогнутый магазин.
    Начало координат — район спусковой скобы, ствол смотрит вправо (u+)."""
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)

    def T(u, v):
        return (x + u * ca - v * sa, y + u * sa + v * ca)

    def bar(u0, v0, u1, v1, w):
        p0, p1 = T(u0, v0), T(u1, v1)
        return p0[0], p0[1], p1[0], p1[1], w

    met = RUST_D if rust else GUNMETAL
    wd = hx("6A4324") if rust else WOOD_GUN

    def m_metal(d, s):
        ln(d, s, *bar(6.5, -0.4, 20.5, -0.4, 1.35))
        ln(d, s, *bar(7.0, -2.4, 15.5, -2.4, 0.85))
        ln(d, s, *bar(19.9, -3.0, 19.9, 0.7, 0.8))
        pg(d, s, [T(0.5, -2.4), T(8.0, -2.4), T(8.0, 2.0), T(0.5, 2.0)])
        pg(d, s, [T(-1.8, 1.6), T(1.6, 1.6), T(-0.4, 7.2), T(-3.4, 7.2)])
        pg(d, s, [T(2.8, 1.8), T(8.6, 1.8), T(7.2, 8.4), T(3.2, 7.8)])
    b.paint(mask(F, F, m_metal), base_col(met, F, F, seed, 0.16), 0.72, 0.2, seed + 1)

    def m_wood(d, s):
        pg(d, s, [T(9.0, -1.9), T(15.6, -1.8), T(15.6, 1.8), T(9.0, 2.2)])
        pg(d, s, [T(-9.8, -2.3), T(-0.6, -2.0), T(-0.6, 2.0), T(-9.8, 1.3)])
    b.paint(mask(F, F, m_wood), base_col(wd, F, F, seed + 7, 0.2), 0.62, 0.22, seed + 8)

    worn = mask(F, F, lambda d, s: pg(d, s, [T(1, -2.6), T(20, -2.6), T(20, 2.0), T(1, 2.0)]))
    b.tint(worn * fbm2(F, F, 9, 3, seed + 11) * wear, METAL_L, 0.5)


def human(b: Buf, cfg: dict, *, hx: float = 32.0, bob: float = 0.0, lean: float = 0.0,
          crouch: float = 0.0, feet=((27.0, 57.4), (37.0, 57.4)),
          lift=(0.0, 0.0), hands=((26.4, 34.8), (37.6, 34.4)), head=(32.0, 12.6),
          head_dx: float = 0.0, gun=None, seed: int = 0, shoulder_w: float = 9.4,
          head_r: float = 7.4) -> None:
    """Фигура 3/4 сверху, ростом ~53 px (голова ~y=5, ноги на y=57.5)."""
    jac = np.asarray(cfg["jacket"], np.float32)
    sdy = 22.6 - bob + crouch * 2.0        # линия плеч
    hpy = 36.8 + crouch * 2.6              # линия бёдер
    kny = 44.8                             # колени
    fty = 57.4                             # посадка стопы
    sx = hx + lean
    back = 0.76                            # затемнение дальних конечностей

    def leg(fx, fy, lf, k, wsc, sd, rough):
        """Нога: бедро + колено + голень + ботинок."""
        kx = hx + (fx - hx) * 0.5
        ky = kny - bob * 0.4
        def m(d, s):
            tp(d, s, hx, hpy - 1.0, kx, ky - lf * 0.45, 3.5 * wsc, 3.0 * wsc)
            tp(d, s, kx, ky - lf * 0.45, fx, fy - lf, 3.0 * wsc, 2.3 * wsc)
        b.paint(mask(F, F, m), base_col(dk(cfg["pants"], k), F, F, sd, 0.15), 0.5, rough, sd + 3)
        b.paint(mask(F, F, lambda d, s: el(d, s, fx, fy - lf + 0.4, 4.0 * wsc, 2.4 * wsc)),
                base_col(dk(cfg["boot"], k), F, F, sd + 5, 0.17), 0.62, 0.3, sd + 6)
        b.tint(mask(F, F, lambda d, s: el(d, s, fx, fy - lf - 1.7, 2.9 * wsc, 1.1 * wsc)),
               dk(cfg["boot"], 1.5 * k), 0.45)

    def arm(shx, shy, hand, k, sd, out=1.8):
        """Рука: плечо–локоть–кисть (рукав темнее куртки, чтобы читался силуэт)."""
        ex = (shx + hand[0]) * 0.5 + out
        ey = (shy + hand[1]) * 0.5 + 1.2
        def m(d, s):
            tp(d, s, shx, shy, ex, ey, 3.1, 2.5)
            tp(d, s, ex, ey, hand[0], hand[1], 2.5, 2.0)
        mm = mask(F, F, m)
        b.paint(mm, base_col(dk(cfg["jacket"], k * 0.78), F, F, sd, 0.1),
                0.62, 0.22, sd + 2)
        b.scale(mm * (1.0 - radial(F, F, (shx + hand[0]) * 0.5, (shy + hand[1]) * 0.5,
                                   7.0, 1.0)), 0.82)
        b.paint(mask(F, F, lambda d, s: el(d, s, hand[0], hand[1], 2.2, 1.9)),
                dk(cfg["glove"], k), 0.68)

    leg(feet[0][0], feet[0][1], lift[0], back, 0.96, seed + 11, 0.26)
    if cfg.get("pack"):
        def mp(d, s):
            rc(d, s, sx - 6.6, sdy - 2.4, sx + 6.6, sdy + 7.4, 2.4)
        b.paint(mask(F, F, mp), base_col(dk(cfg["pack_col"], back + 0.06), F, F, seed + 21, 0.16),
                0.8, 0.3, seed + 22)
    arm(sx - 6.8, sdy + 2.6, hands[0], back, seed + 31)

    def m_torso(d, s):
        el(d, s, sx, sdy + 1.6, shoulder_w, 4.0)
        pg(d, s, [(sx - shoulder_w * 0.80, sdy + 1.2), (sx + shoulder_w * 0.80, sdy + 1.2),
                  (hx + 6.2, hpy - 2.0), (hx - 6.2, hpy - 2.0)])
        el(d, s, hx, hpy - 1.6, 6.4, 3.2)
        pg(d, s, [(hx - 6.0, 26.0), (hx + 6.0, 26.0), (hx + 6.4, 38.0), (hx - 6.4, 38.0)])
    b.paint(mask(F, F, m_torso), base_col(jac, F, F, seed, 0.11), 0.62, 0.16, seed + 1)
    tor = b.a.copy()
    # бронежилет/разгрузка поверх куртки
    b.paint(mask(F, F, lambda d, s: rc(d, s, hx - 6.4, sdy + 2.6, hx + 6.4, 33.6, 1.6)) * tor,
            base_col(dk(jac, 0.72), F, F, seed + 43, 0.1), 0.72)
    b.paint(mask(F, F, lambda d, s: (rc(d, s, sx - 4.0, sdy + 1.8, sx - 2.1, 33.6, 0.5),
                                     rc(d, s, sx + 2.1, sdy + 1.8, sx + 4.0, 33.6, 0.5))) * tor,
            dk(jac, 0.34), 0.9)                             # стропы
    if cfg.get("accent") is not None:
        b.paint(ragg(mask(F, F, lambda d, s: rc(d, s, hx - 7.4, 35.4, hx - 4.4, 39.0, 0.7)),
                     0.25, seed + 74) * tor,
                base_col(cfg["accent"], F, F, seed + 44, 0.12), 0.86)
    hem = mask(F, F, lambda d, s: pg(d, s, [(hx - 6.2, 31.0), (hx + 6.2, 31.0),
                                           (hx + 6.8, 41.6), (hx - 6.8, 41.6)]))
    b.paint(ragg(hem, 0.45, seed + 41), base_col(dk(jac, 0.9), F, F, seed + 42, 0.16), 0.58)
    tor = b.a.copy()
    b.paint(mask(F, F, lambda d, s: rc(d, s, hx - 6.4, 33.4, hx + 6.4, 36.2, 0.6)) * tor,
            METAL_D, 0.75)                                  # ремень
    b.scale(tor * radial(F, F, sx, sdy + 1.6, 12.0, 0.9), 1.07)
    b.scale(tor * radial(F, F, hx, 41.5, 10.0, 0.9), 0.84)
    b.tint(tor * P.clamp01((fbm2(F, F, 5, 4, seed + 51) - 0.55) * 2.4), DIRT, 0.4)
    if cfg.get("tatters"):
        t = mask(F, F, lambda d, s: pg(d, s, [(hx - 6.6, 30), (hx + 6.6, 30),
                                              (hx + 7.2, 40), (hx - 7.2, 40)]))
        cuts = P.clamp01((fbm2(F, F, 4, 4, seed + 61) - 0.5) * 3.2)
        b.a = np.where(cuts * t > 0.5, 0.0, b.a)            # дыры в тряпье

    leg(feet[1][0], feet[1][1], lift[1], 1.0, 1.0, seed + 71, 0.24)

    if gun is not None:
        draw_ak(b, gun["x"], gun["y"], gun.get("deg", 0.0), gun.get("rust", False),
                seed + 81, gun.get("wear", 1.0))
    arm(sx + 5.8, sdy + 2.2, hands[1], 1.0, seed + 91)
    human_head(b, cfg, head[0] + head_dx, head[1], seed + 101, head_r)


def human_head(b: Buf, cfg: dict, cx: float, cy: float, seed: int, r: float = 7.0) -> None:
    """Голова: воротник, капюшон/кепка, противогаз или гниющее лицо."""
    b.paint(mask(F, F, lambda d, s: tp(d, s, cx, cy + 4.0, cx, cy + r + 1.6, 2.4, 3.2)),
            dk(cfg["jacket"], 0.6), 0.5)
    cover = cfg.get("cover", "hood")
    if cover == "hood":
        def mh(d, s):
            el(d, s, cx, cy - 1.4, r * 0.86, r * 0.92)
            pg(d, s, [(cx - r - 0.6, cy + 3.6), (cx + r + 0.6, cy + 3.6),
                      (cx + r * 0.74, cy - 1.0), (cx - r * 0.74, cy - 1.0)])
            pg(d, s, [(cx - r - 1.0, cy + 3.0), (cx + r + 1.0, cy + 3.0),
                      (cx + r - 1.0, cy + 7.8), (cx - r + 1.0, cy + 7.8)])
        hm = mask(F, F, mh)
        b.paint(ragg(hm, 0.14, seed + 2), base_col(cfg["hood"], F, F, seed, 0.13), 0.95, 0.0)
        b.tint(hm * radial(F, F, cx - 2.0, cy - 3.5, 9.5, 0.9), dk(cfg["hood"], 1.28), 0.55)
        b.tint(hm * radial(F, F, cx + 1.0, cy + 6.0, 8.0, 0.9), dk(cfg["hood"], 0.68), 0.5)
        b.scale(b.a * (hm > 0.4), 1.12 - 0.24 * lgrad(F, F, 0.0, 1.0))
        b.paint(mask(F, F, lambda d, s: el(d, s, cx, cy + 2.4, r * 0.74, r * 0.70)),
                (0.05, 0.05, 0.055), 0.35)                 # тень внутри капюшона
    elif cover == "cap":
        b.paint(mask(F, F, lambda d, s: (el(d, s, cx, cy - 0.8, r * 0.92, r * 0.86),
                                         pg(d, s, [(cx - r * 0.7, cy - 1.2), (cx + r * 0.7, cy - 1.2),
                                                   (cx + r * 1.15, cy + 2.6), (cx - r * 1.15, cy + 2.6)]))),
                base_col(cfg["hood"], F, F, seed, 0.14), 0.9, 0.25, seed + 3)
    if cfg.get("mask") == "gas":
        mm = mask(F, F, lambda d, s: el(d, s, cx, cy + 2.8, 5.2, 4.7))
        b.paint(mm, base_col(MASK_GRN, F, F, seed + 4, 0.13), 0.86, 0.1, seed + 5)
        b.paint(mask(F, F, lambda d, s: (el(d, s, cx - 3.0, cy + 1.0, 1.8, 1.75),
                                         el(d, s, cx + 3.0, cy + 1.0, 1.8, 1.75))),
                dk(MASK_GRN, 0.68), 0.94)                  # тёмная оправа стёкол
        gl = mask(F, F, lambda d, s: (el(d, s, cx - 3.0, cy + 1.0, 1.45, 1.4),
                                      el(d, s, cx + 3.0, cy + 1.0, 1.45, 1.4)))
        b.paint(gl, base_col(GLASS, F, F, seed + 7, 0.2), 0.62)
        b.tint(gl, TOXIC, 0.10)
        b.paint(mask(F, F, lambda d, s: (el(d, s, cx - 3.4, cy + 0.5, 0.5, 0.45),
                                         el(d, s, cx + 2.6, cy + 0.5, 0.5, 0.45))),
                (0.90, 0.94, 0.86), 0.8)                   # отблеск на стёклах
        b.paint(mask(F, F, lambda d, s: el(d, s, cx - 5.7, cy + 4.2, 1.8, 1.55)),
                base_col(METAL_D, F, F, seed + 9, 0.15), 0.98)      # корпус фильтра
        b.paint(mask(F, F, lambda d, s: el(d, s, cx + 1.6, cy + 4.9, 1.15, 0.95)),
                base_col(METAL, F, F, seed + 10, 0.12), 0.92)       # клапан выдоха
    else:
        fm = mask(F, F, lambda d, s: el(d, s, cx, cy + 1.6, r * 0.58, r * 0.56))
        b.paint(fm, base_col(cfg["skin"], F, F, seed + 12, 0.15), 0.68, 0.24, seed + 13)
        b.paint(mask(F, F, lambda d, s: (el(d, s, cx - 1.9, cy + 0.2, 1.05, 0.95),
                                         el(d, s, cx + 1.9, cy + 0.2, 1.05, 0.95))),
                (0.05, 0.05, 0.05), 0.3)                   # глазницы
        b.paint(mask(F, F, lambda d, s: (el(d, s, cx - 1.9, cy + 0.0, 0.55, 0.5),
                                         el(d, s, cx + 1.9, cy + 0.0, 0.55, 0.5))),
                (0.62, 0.16, 0.09), 0.45)                  # тлеющие зрачки
        b.paint(mask(F, F, lambda d, s: rc(d, s, cx - 1.7, cy + 3.9, cx + 1.7, cy + 4.9, 0.3)),
                (0.15, 0.10, 0.09), 0.3)                   # разинутый рот
        b.tint(fm * radial(F, F, cx, cy + 3.6, 5.2, 1.0), dk(cfg["skin"], 0.68), 0.5)


# ================================================================== ИГРОК: СТАЛКЕР
CFG_STALKER = dict(jacket=OLIVE, hood=OLIVE_D, pants=PANTS, boot=hx("22201A"),
                   glove=hx("332F22"), skin=SKIN, cover="hood", mask="gas",
                   pack=True, pack_col=CANVAS_D, rig=True, accent=hx("C8752A"))


def build_strip(name: str, n: int, fn, desc: str, normal: bool = True,
                shade: bool = True, quant: int = 40, light=(-0.42, -0.78),
                ao: float = 0.46, strength: float = 1.15) -> None:
    """Собрать горизонтальную полосу кадров 64x64 и сохранить вместе с нормалью."""
    frames, nrms = [], []
    for i in range(n):
        b = Buf(F, F)
        fn(b, i)
        rgba, nrm = render(b, shade=shade, normal=normal, quant=quant, light=light,
                           strength=strength, ao=ao)
        frames.append(rgba)
        nrms.append(nrm)
    save_strip(name, frames, nrms, desc)


def stalker_idle(b: Buf, i: int) -> None:
    """Стойка: дыхание, лёгкое покачивание, руки вдоль тела."""
    ph = 2.0 * math.pi * i / 4.0
    bob = 0.45 - 0.45 * math.cos(ph)
    human(b, CFG_STALKER, hx=32.0, bob=bob * 0.8, lean=0.2 * math.sin(ph),
          feet=((27.0, 57.4), (37.0, 57.4)),
          hands=((26.6, 35.4 - bob * 0.5), (37.4, 35.0 - bob * 0.5)),
          head=(32.0, 12.2 - bob * 0.6), head_dx=0.25 * math.sin(ph), seed=100)


def stalker_walk(b: Buf, i: int) -> None:
    """Шаг: АК на груди, ноги попеременно, корпус покачивается."""
    ph = 2.0 * math.pi * i / 6.0
    sw = math.sin(ph)
    bob = abs(math.sin(ph)) * 1.1
    human(b, CFG_STALKER, hx=32.0 + sw * 0.4, bob=bob * 0.7, lean=0.5,
          feet=((26.6 + sw * 3.8, 57.4 - max(0.0, sw) * 3.4),
                (37.4 - sw * 3.8, 57.4 - max(0.0, -sw) * 3.4)),
          lift=(max(0.0, sw) * 1.8, max(0.0, -sw) * 1.8),
          hands=((30.4, 34.6 - bob * 0.6), (40.6, 28.4 - bob * 0.6)),
          head=(32.0, 12.0 - bob * 0.7), head_dx=0.3 * sw,
          gun=dict(x=30.2, y=33.8 - bob * 0.6, deg=-28.0), seed=200)


def stalker_attack(b: Buf, i: int) -> None:
    """Выстрел: АК вскинут вправо, отдача на 1-2 кадрах."""
    rec = (0.0, 2.6, 1.4, 0.3)[i]
    human(b, CFG_STALKER, hx=32.0, bob=rec * 0.35, lean=1.2 - rec * 0.25,
          feet=((26.2, 57.4), (37.8, 57.4)),
          hands=((32.0 - rec, 32.6), (43.6 - rec, 31.4)),
          head=(32.2, 11.8), head_dx=0.8,
          gun=dict(x=32.2 - rec, y=32.2, deg=-4.0 - rec * 0.8), seed=300)


def stalker_hurt(b: Buf, i: int) -> None:
    """Попадание: отброс назад, руки вскинуты."""
    k = (0.0, 1.0)[i]
    human(b, CFG_STALKER, hx=32.0 - k * 0.8, bob=k * 0.8, lean=-1.8 * k - 0.4,
          crouch=0.35 * k,
          feet=((26.0, 57.4), (38.0, 56.2 - k * 1.6)),
          hands=((26.6 - k * 1.5, 30.4 - k * 3.0), (38.0, 29.6 - k * 3.0)),
          head=(31.4 - k * 0.6, 12.2 - k * 1.4), head_dx=-0.8,
          gun=dict(x=30.0, y=35.0, deg=34.0 + k * 12.0), seed=400)


def stalker_dead(b: Buf, i: int) -> None:
    """Труп: лежит на земле по диагонали, лужа крови, выроненный АК."""
    # лужа крови (заметная, тёмно-красная)
    b.paint(ragg(radial(F, F, 30.0, 48.0, 21.0, 0.9), 0.3, 9) * 0.92, (0.24, 0.04, 0.04), 0.02)
    b.paint(ragg(radial(F, F, 29.0, 47.0, 13.0, 0.8), 0.42, 11) * 0.95, (0.36, 0.06, 0.05), 0.035)
    # ноги (влево) с чёрными ботинками
    for (p, q) in (((25.0, 46.0), (12.5, 49.0)), ((26.0, 49.4), (14.5, 53.6))):
        b.paint(mask(F, F, lambda d, s, a=p, c=q: tp(d, s, a[0], a[1], c[0], c[1], 3.6, 2.5)),
                base_col(hx("6E6E62"), F, F, 11, 0.14), 0.5, 0.3, 12)
        b.paint(mask(F, F, lambda d, s, c=q: el(d, s, c[0], c[1] - 0.4, 3.7, 2.3)),
                base_col(hx("26251F"), F, F, 13, 0.12), 0.62, 0.32, 14)
    # торс в куртке
    b.paint(mask(F, F, lambda d, s: tp(d, s, 26.0, 48.0, 41.0, 45.0, 6.2, 6.8)),
            base_col(dk(OLIVE, 1.15), F, F, 15, 0.12), 0.5, 0.26, 16)
    b.paint(mask(F, F, lambda d, s: tp(d, s, 27.0, 49.8, 41.0, 46.8, 5.6, 6.2)),
            base_col(dk(OLIVE, 0.9), F, F, 17, 0.12), 0.54, 0.3, 18)
    b.paint(mask(F, F, lambda d, s: rc(d, s, 29.0, 46.2, 38.0, 49.0, 0.8)),
            base_col(hx("4A4E46"), F, F, 19, 0.1), 0.68)          # бронежилет
    # раскинутая рука
    b.paint(mask(F, F, lambda d, s: tp(d, s, 33.0, 44.6, 36.0, 36.6, 3.0, 2.2)),
            base_col(dk(OLIVE, 0.95), F, F, 20, 0.12), 0.62, 0.3, 21)
    b.paint(mask(F, F, lambda d, s: el(d, s, 36.6, 35.6, 2.2, 1.9)),
            base_col(hx("332F22"), F, F, 22, 0.1), 0.68)          # перчатка
    # голова в капюшоне с противогазом
    def mh_dead(d, s):
        el(d, s, 45.5, 42.4, 8.0, 6.9)
        pg(d, s, [(37.0, 42.2), (46.5, 38.0), (48.2, 45.8), (38.0, 46.6)])
    b.paint(ragg(mask(F, F, mh_dead), 0.16, 23), base_col(dk(OLIVE_D, 1.05), F, F, 24, 0.13), 0.9)
    b.paint(mask(F, F, lambda d, s: el(d, s, 47.2, 44.0, 4.6, 4.1)),
            base_col(MASK_GRN, F, F, 25, 0.14), 0.84)
    b.paint(mask(F, F, lambda d, s: (el(d, s, 45.0, 43.0, 1.7, 1.6),
                                     el(d, s, 49.4, 44.2, 1.7, 1.6))),
            base_col(GLASS, F, F, 26, 0.2), 0.6)
    b.paint(mask(F, F, lambda d, s: (el(d, s, 44.4, 42.6, 0.55, 0.5),
                                     el(d, s, 48.8, 43.8, 0.55, 0.5))),
            (0.86, 0.90, 0.82), 0.7)                              # отблеск на стёклах
    b.paint(mask(F, F, lambda d, s: el(d, s, 42.8, 46.6, 1.9, 1.6)),
            base_col(METAL_D, F, F, 27, 0.15), 0.9)               # фильтр
    # выроненный АК поверх ног
    draw_ak(b, 30.0, 53.6, -18.0, False, 28, 0.6)
    b.tint(radial(F, F, 31.0, 46.0, 18.0, 0.9) * (b.a > 0.4), BLOOD, 0.12)


def gen_stalker() -> None:
    build_strip("stalker_idle", 4, stalker_idle,
                "Игрок-сталкер: стойка с дыханием, капюшон и противогаз")
    build_strip("stalker_walk", 6, stalker_walk,
                "Игрок-сталкер: шаг, АК на груди стволом вверх")
    build_strip("stalker_attack", 4, stalker_attack,
                "Игрок-сталкер: выстрел из АК с отдачей")
    build_strip("stalker_hurt", 2, stalker_hurt,
                "Игрок-сталкер: отброс от попадания")
    build_strip("stalker_dead", 1, stalker_dead,
                "Игрок-сталкер: труп на земле, лужа крови и выроненный АК")


# ================================================================== ЗОМБИ-СТАЛКЕР
CFG_ZOMBIE = dict(jacket=hx("57593A"), hood=hx("43462C"), pants=hx("3E4030"),
                  boot=hx("2C2820"), glove=hx("393625"), skin=ZOMB_SKIN,
                  cover="cap", mask=None, pack=False, rig=False)


def camo(b: Buf, seed: int, top: float = 24.0) -> None:
    """Пятна камуфляжа поверх уже нарисованной фигуры (только в силуэте)."""
    reg = ((b.a > 0.55) & (np.arange(F, dtype=np.float32)[:, None] > top)).astype(np.float32)
    for k, c in enumerate((hx("3B4726"), hx("2A2A1E"), hx("605E42"))):
        n = fbm2(F, F, 5 - k, 3, seed + k * 17)
        m = reg * P.clamp01((n - 0.52 - k * 0.09) * 4.5)
        b.tint(m, c, 0.55)


def zombie_idle(b: Buf, i: int) -> None:
    """Зомби: покачивается, голова свешена, руки вяло вниз."""
    ph = 2.0 * math.pi * i / 4.0
    bob = 0.5 - 0.5 * math.cos(ph)
    human(b, CFG_ZOMBIE, hx=32.0, bob=bob * 1.1, lean=0.9 * math.sin(ph),
          feet=((26.8, 57.4), (37.2, 57.4)),
          hands=((26.4, 37.6 + bob * 0.6), (37.6, 37.2 + bob * 0.6)),
          head=(31.6, 13.2 + bob * 0.5), head_dx=0.4 * math.sin(ph), seed=600)
    camo(b, 610, 20.0)


def zombie_walk(b: Buf, i: int) -> None:
    """Зомби: шаркающий шаг с вытянутой рукой и ржавым АК."""
    ph = 2.0 * math.pi * i / 6.0
    sw = math.sin(ph)
    bob = abs(sw) * 1.4
    human(b, CFG_ZOMBIE, hx=32.0 + sw * 0.9, bob=bob * 0.7, lean=1.6,
          feet=((26.2 + sw * 4.0, 57.4 - max(0.0, sw) * 2.6),
                (37.8 - sw * 4.0, 57.4 - max(0.0, -sw) * 2.6)),
          lift=(max(0.0, sw) * 1.4, max(0.0, -sw) * 1.4),
          hands=((27.6 - sw * 1.2, 37.8), (42.0, 32.0 - bob * 0.5)),
          head=(31.4, 13.0 - bob * 0.4), head_dx=0.5,
          gun=dict(x=28.0, y=35.0 - bob * 0.4, deg=-46.0, rust=True, wear=0.9), seed=620)
    camo(b, 630, 20.0)


def zombie_attack(b: Buf, i: int) -> None:
    """Зомби: вскидывает ствол и проваливается вперёд."""
    k = (0.0, 1.0, 0.7, 0.25)[i]
    human(b, CFG_ZOMBIE, hx=32.0, bob=0.4 + k * 0.5, lean=1.9 - k * 0.6,
          feet=((25.6, 57.4), (38.6, 56.8)),
          hands=((33.6, 32.6), (44.6, 30.6 - k * 0.8)),
          head=(31.8, 13.0 + k * 0.3), head_dx=1.2,
          gun=dict(x=33.2, y=32.0, deg=-8.0 + k * 4.0, rust=True, wear=0.9), seed=640)
    camo(b, 650, 20.0)


def gen_zombie() -> None:
    build_strip("zombie_idle", 4, zombie_idle,
                "Зомби-сталкер: качается, рваный камуфляж, опухшее лицо")
    build_strip("zombie_walk", 6, zombie_walk,
                "Зомби-сталкер: шаркающий шаг, ржавый АК в руке")
    build_strip("zombie_attack", 4, zombie_attack,
                "Зомби-сталкер: неуклюжий выпад и выстрел")


# ================================================================== ЧЕТВЕРОНОГИЕ
def quad_body(b: Buf, cfg: dict, *, hy: float = 41.0, chest: float = 34.0,
              haunch: float = 21.0, rx: float = 8.0, ry: float = 7.0,
              seed: int = 0) -> np.ndarray:
    """Туловище зверя: грудь + круп + спина. Возвращает маску тела."""
    def m(d, s):
        el(d, s, chest, hy, rx * 0.78, ry * 1.02)
        el(d, s, haunch, hy - 0.6, rx * 0.86, ry * 0.94)
        pg(d, s, [(chest - 2.0, hy - ry * 0.92), (chest + 3.0, hy - ry * 0.92),
                  (haunch + 1.0, hy - ry * 0.86), (haunch - 3.0, hy - ry * 0.86)])
        el(d, s, (chest + haunch) * 0.5, hy + 0.4, rx, ry * 0.9)
    bm = mask(F, F, m)
    b.paint(bm, base_col(cfg["body"], F, F, seed, 0.14), 0.6, 0.28, seed + 1)
    b.scale(bm * radial(F, F, (chest + haunch) * 0.5, hy - ry, 14.0, 0.9), 1.14)
    b.scale(bm * radial(F, F, (chest + haunch) * 0.5, hy + ry, 12.0, 0.9), 0.84)
    return bm


def quad_leg(b: Buf, cfg: dict, hip: float, hy: float, foot: float, fy: float,
             lift: float, w: float, k: float, seed: int) -> None:
    """Нога зверя: бедро + голень + лапа."""
    ky = (hy + fy) * 0.5 + 1.0
    kx = (hip + foot) * 0.5
    def m(d, s):
        tp(d, s, hip, hy + 1.0, kx, ky - lift * 0.4, w * 1.25, w)
        tp(d, s, kx, ky - lift * 0.4, foot, fy - lift, w, w * 0.8)
    b.paint(mask(F, F, m), base_col(dk(cfg["body"], k), F, F, seed, 0.15), 0.5, 0.26, seed + 1)
    b.paint(mask(F, F, lambda d, s: el(d, s, foot, fy - lift + 0.3, w * 1.5, w * 0.85)),
            base_col(dk(cfg["skin"], k), F, F, seed + 2, 0.16), 0.58, 0.3, seed + 3)


def beast_head(b: Buf, cfg: dict, cx: float, cy: float, rx: float, ry: float,
               snout: float, seed: int, *, jaw: float = 0.0, ear: float = 1.0,
               eye=None) -> None:
    """Голова зверя: череп, вытянутая морда, пасть с клыками, уши, глаз."""
    def mh(d, s):
        el(d, s, cx, cy, rx, ry)
        pg(d, s, [(cx + rx * 0.3, cy - ry * 0.75), (cx + rx * 0.3 + snout, cy + 0.4),
                  (cx + rx * 0.3 + snout, cy + ry * 0.9), (cx + rx * 0.3, cy + ry * 0.95)])
    b.paint(mask(F, F, mh), base_col(cfg["skin"], F, F, seed, 0.13), 0.7, 0.24, seed + 1)
    b.paint(mask(F, F, lambda d, s: el(d, s, cx + rx * 0.55 + snout * 0.6, cy + ry * 0.8,
                                       snout * 0.35, ry * 0.32)),
            base_col(cfg["nose"], F, F, seed + 2, 0.12), 0.66)
    if jaw > 0.0:
        b.paint(mask(F, F, lambda d, s: el(d, s, cx + rx * 0.9, cy + ry * (0.7 + jaw),
                                           rx * 0.55, ry * 0.5)),
                base_col(cfg["maw"], F, F, seed + 3, 0.15), 0.45)
        for k in range(3):
            t = cx + rx * 0.45 + k * 1.9
            def teeth(d, s, tt=t):
                pg(d, s, [(tt, cy + ry * (0.35 + jaw)), (tt + 1.5, cy + ry * (0.35 + jaw)),
                          (tt + 0.7, cy + ry * (0.95 + jaw))])
            b.paint(mask(F, F, teeth), (0.86, 0.84, 0.74), 0.5)
    b.paint(mask(F, F, lambda d, s: pg(d, s, [(cx + rx * 0.2, cy - ry * 0.2),
                                              (cx + rx * 0.2 + snout * 0.9, cy - ry * 0.15),
                                              (cx + rx * 0.2 + snout * 0.9, cy + ry * 0.3),
                                              (cx + rx * 0.2, cy + ry * 0.35)])),
            dk(cfg["skin"], 0.80), 0.5, 0.2, seed + 4)
    if ear > 0.0:
        b.paint(mask(F, F, lambda d, s: pg(d, s, [(cx - rx * 0.3, cy - ry * 0.75),
                                                  (cx + rx * 0.15, cy - ry * 0.7),
                                                  (cx - rx * 0.55 - ear * 1.4,
                                                   cy - ry * 1.5 - ear * 1.2)])),
                base_col(dk(cfg["skin"], 0.86), F, F, seed + 5, 0.12), 0.72, 0.28, seed + 6)
    b.paint(mask(F, F, lambda d, s: el(d, s, cx + rx * 0.15, cy - ry * 0.24, 1.15, 1.0)),
            (0.06, 0.05, 0.05), 0.3)
    if eye is not None:
        b.paint(mask(F, F, lambda d, s: el(d, s, cx + rx * 0.15, cy - ry * 0.24, 0.55, 0.5)),
                eye, 0.35)


# ================================================================== СЛЕПОЙ ПЁС
DOG = dict(body=hx("A99C84"), skin=hx("B9AF99"), nose=hx("3E362E"), maw=hx("361614"))


def dog_detail(b: Buf, hy: float, seed: int) -> None:
    """Детали пса: редкие шипы на хребте, рёбра, проплешины."""
    for k in range(4):
        x = 21.0 + k * 3.2
        y = hy - 6.4 + math.sin(k * 0.9) * 0.4
        b.paint(mask(F, F, lambda d, s, xx=x, yy=y: pg(d, s, [(xx, yy), (xx + 1.9, yy + 0.3),
                                                              (xx + 0.95, yy - 1.9)])),
                base_col(dk(hx("9C9078"), 0.9), F, F, seed + k, 0.1), 0.8)
    for k in range(4):
        x = 26.0 + k * 2.5
        b.paint(mask(F, F, lambda d, s, xx=x: tp(d, s, xx, hy - 3.0, xx + 1.0, hy + 4.0, 0.35, 0.3)),
                dk(hx("9A8E76"), 0.9), 0.45)
    patch = P.clamp01((fbm2(F, F, 3, 3, seed + 33) - 0.42) * 2.2) * (b.a > 0.6)
    b.tint(patch, hx("6E6350"), 0.45)
    # тёмная полоса по хребту
    band = P.clamp01(1.0 - radial(F, F, 29.0, hy - 5.4, 12.0, 1.0)) * (b.a > 0.6)
    b.tint(band, hx("6B604C"), 0.5)
    sore = P.clamp01((fbm2(F, F, 4, 3, seed + 31) - 0.45) * 2.4) * (b.a > 0.6)
    b.tint(sore, hx("8A5A4A"), 0.45)
    # горб над лопатками
    b.paint(mask(F, F, lambda d, s: el(d, s, 34.0, hy - 5.6, 6.4, 2.6)),
            base_col(dk(hx("C6BCA6"), 0.94), F, F, seed + 41, 0.12), 0.86, 0.3, seed + 42)


def dog_frame(b: Buf, i: int, n: int, mode: str = "idle") -> None:
    """Кадр пса: mode = idle | walk | attack."""
    sw = math.sin(2.0 * math.pi * i / n)
    bob = abs(sw) * (0.9 if mode == "walk" else 0.4)
    hy = 41.0 - bob * 0.6
    fx = 1.0 if mode == "walk" else (2.4 if mode == "attack" else 0.0)
    quad_leg(b, DOG, 38.0, hy + 4.0, 38.0 + sw * 3.4 * fx, 56.4 - max(0.0, sw) * 2.4 * fx,
             0.0, 2.0, 1.0, 900)
    quad_leg(b, DOG, 34.0, hy + 4.5, 33.0 - sw * 3.0 * fx, 56.6 - max(0.0, -sw) * 2.4 * fx,
             0.0, 2.0, 0.84, 910)
    quad_body(b, DOG, hy=hy, chest=34.0, haunch=21.0, rx=7.4, ry=7.0, seed=920)
    quad_leg(b, DOG, 23.0, hy + 4.0, 22.0 - sw * 3.2 * fx, 56.2 - max(0.0, -sw) * 2.0 * fx,
             0.0, 2.1, 0.86, 930)
    quad_leg(b, DOG, 19.0, hy + 4.0, 18.0 + sw * 3.2 * fx, 56.6 - max(0.0, sw) * 2.0 * fx,
             0.0, 2.1, 1.0, 940)
    b.paint(mask(F, F, lambda d, s: tp(d, s, 17.0, hy - 1.5, 9.5 + sw * 1.6, hy - 6.5 + sw * 1.2,
                                       1.7, 0.65)), base_col(dk(DOG["skin"], 0.94), F, F, 950, 0.12),
            0.55, 0.3, 951)
    hx_, hy_ = 49.0 + sw * 0.3, hy - 1.4 - bob * 0.8
    if mode == "attack":
        hx_ += 1.6
        hy_ += 1.6
    b.paint(mask(F, F, lambda d, s: tp(d, s, 37.0, hy - 3.4, hx_ - 4.6, hy_ - 0.8, 3.9, 3.3)),
            base_col(DOG["skin"], F, F, 960, 0.12), 0.66, 0.22, 961)
    jaw = 0.10 if mode != "attack" else 0.55
    beast_head(b, DOG, hx_, hy_, 4.7, 4.1, 5.4, 970, jaw=jaw,
               ear=(1.0 if mode != "attack" else 1.7), eye=(0.80, 0.22, 0.12))
    dog_detail(b, hy, 980)


def gen_dog() -> None:
    build_strip("dog_idle", 4, lambda b, i: dog_frame(b, i, 4, "idle"),
                "Слепой пёс: стойка, бледная лысая кожа, шипы на хребте")
    build_strip("dog_walk", 6, lambda b, i: dog_frame(b, i, 6, "walk"),
                "Слепой пёс: рысь на четырёх ногах, хвост вразлёт")
    build_strip("dog_attack", 4, lambda b, i: dog_frame(b, i, 4, "attack"),
                "Слепой пёс: прыжок с раскрытой пастью и клыками")


# ================================================================== КРОВОСОС
MUT = dict(body=hx("5E2A22"), body_l=hx("7E3A2C"), maw=hx("2A0E0E"), skin=hx("6A3028"))


def mutant_frame(b: Buf, i: int, n: int, mode: str = "idle") -> None:
    """Кровосос: высокий сгорбленный гуманоид с щупальцами на лице."""
    sw = math.sin(2.0 * math.pi * i / n)
    if mode == "walk":
        bob = abs(sw) * 1.4
        lurch = sw * 1.2
        reach = 1.0
    elif mode == "attack":
        bob = 0.0
        lurch = -1.4 + 0.6 * i
        reach = 3.0
    else:
        bob = 0.5 - 0.5 * math.cos(2.0 * math.pi * i / n)
        lurch = 0.0
        reach = 0.2
    for (hip, foot, k, sd, lift) in ((26.0, 22.0 + sw * 2.4, 1.0, 1000, max(0.0, sw) * 2.6),
                                     (37.0, 41.0 - sw * 2.4, 0.84, 1010, max(0.0, -sw) * 2.6)):
        ky = 45.0 - bob * 0.4
        def ml(d, s, hp=hip, ft=foot, kk=k, lf=lift, kyy=ky):
            tp(d, s, hp, 33.0 - bob * 0.5, (hp + ft) * 0.5 - 1.6, kyy - lf * 0.4, 3.6 * kk, 3.0 * kk)
            tp(d, s, (hp + ft) * 0.5 - 1.6, kyy - lf * 0.4, ft, 56.6 - lf, 3.0 * kk, 2.4 * kk)
        b.paint(mask(F, F, ml), base_col(dk(MUT["body"], k), F, F, sd, 0.15), 0.5, 0.26, sd + 1)
        def mf(d, s, ft=foot, kk=k, lf=lift):
            el(d, s, ft, 56.9 - lf, 3.6 * kk, 2.0 * kk)
            for c in range(3):
                pg(d, s, [(ft - 1.6 + c * 1.6, 55.4 - lf), (ft - 1.0 + c * 1.6, 55.4 - lf),
                          (ft - 1.9 + c * 1.6, 57.4 - lf)])
        b.paint(mask(F, F, mf), base_col(dk(hx("3A2018"), k), F, F, sd + 2, 0.12), 0.6, 0.3, sd + 3)
    tx = 31.5 + lurch * 0.4
    bx = 32.0
    def mt(d, s):
        el(d, s, tx, 24.5 - bob * 0.5, 11.6, 5.2)
        pg(d, s, [(tx - 8.4, 24.0 - bob * 0.5), (tx + 8.4, 24.0 - bob * 0.5),
                  (bx - 6.0, 34.6), (bx + 6.0, 34.6)])
        el(d, s, bx, 34.0, 6.6, 3.6)
    b.paint(mask(F, F, mt), base_col(MUT["body"], F, F, 1020, 0.13), 0.62, 0.2, 1021)
    tor = b.a.copy()
    b.scale(tor * radial(F, F, tx, 20.0, 13.0, 0.9), 1.30)
    b.scale(tor * radial(F, F, bx, 35.0, 10.0, 0.9), 0.76)
    for k in range(5):
        xx = tx - 6.4 + k * 3.2
        b.paint(mask(F, F, lambda d, s, x=xx: tp(d, s, x, 21.0, x - 1.6, 34.0, 0.5, 0.4)) * tor,
                dk(MUT["body_l"], 0.9), 0.5)
    b.tint(tor * P.clamp01((fbm2(F, F, 4, 4, 1030) - 0.5) * 2.6), hx("8A4A30"), 0.35)
    b.tint(tor * radial(F, F, tx, 22.0, 8.0, 1.0), dk(MUT["body_l"], 1.18), 0.45)
    mutant_arms(b, tx, reach, i)
    mutant_head(b, tx, lurch, bob, i, mode)

def mutant_arms(b: Buf, tx: float, reach: float, i: int) -> None:
    """Длинные руки кровососа почти до колен, с когтями."""
    hnd = 40.5 - reach * 1.6
    for (shx, shy, hand, k, sd, out) in ((tx - 8.6, 25.0 + reach * 0.4, 28.5, 0.84, 1040, -2.4),
                                         (tx + 8.6, 25.0 + reach * 0.4, 37.5, 1.0, 1050, 2.4)):
        ex = (shx + hand) * 0.5 + out
        ey = (shy + hnd) * 0.5 + 1.0
        def ma(d, s, a=(shx, shy), e=(ex, ey), h=(hand, hnd), kk=k):
            tp(d, s, a[0], a[1], e[0], e[1], 3.9 * kk, 3.0 * kk)
            tp(d, s, e[0], e[1], h[0], h[1], 3.0 * kk, 2.3 * kk)
        b.paint(mask(F, F, ma), base_col(dk(MUT["body"], k), F, F, sd, 0.13), 0.6, 0.24, sd + 1)
        def mc(d, s, h=(hand, hnd), kk=k):
            el(d, s, h[0], h[1], 2.1 * kk, 1.9 * kk)
            for c in range(3):
                pg(d, s, [(h[0] - 1.5 + c * 1.5, h[1] + 0.8), (h[0] - 1.0 + c * 1.5, h[1] + 1.1),
                          (h[0] - 1.8 + c * 1.5, h[1] + 2.8)])
        b.paint(mask(F, F, mc), base_col(dk(hx("B9AC90"), k), F, F, sd + 2, 0.1), 0.72, 0.3, sd + 3)


def mutant_head(b: Buf, tx: float, lurch: float, bob: float, i: int, mode: str) -> None:
    """Голова кровососа: вросшая в плечи, тёмная маска лица и щупальца."""
    hcx, hcy = tx + lurch * 0.6, 17.4 - bob * 0.5
    def mh(d, s):
        el(d, s, hcx, hcy, 7.8, 5.8)
        pg(d, s, [(hcx - 5.6, hcy + 2.6), (hcx + 5.6, hcy + 2.6),
                  (hcx + 4.6, hcy + 8.4), (hcx - 4.6, hcy + 8.4)])
    b.paint(mask(F, F, mh), base_col(dk(MUT["body"], 1.08), F, F, 1060, 0.13), 0.9, 0.22, 1061)
    b.scale(radial(F, F, hcx - 2.0, hcy - 3.0, 8.0, 0.9), 1.18)
    b.paint(mask(F, F, lambda d, s: el(d, s, hcx, hcy + 2.4, 5.4, 4.4)),
            base_col(hx("3A1414"), F, F, 1062, 0.14), 0.55)
    for c in range(6):
        t0 = hcx - 5.0 + c * 2.0
        wav = math.sin(i * 1.6 + c * 1.1) * 2.1
        def mten(d, s, x=t0, w=wav, cc=c):
            tp(d, s, x, hcy + 2.4, x + w * 0.5, hcy + 7.6, 2.1, 1.5)
            tp(d, s, x + w * 0.5, hcy + 7.6, x + w, hcy + 13.0 + (cc % 2) * 1.8, 1.5, 0.7)
        b.paint(mask(F, F, mten), base_col(hx("A85A44"), F, F, 1063 + c, 0.12), 0.66,
                0.3, 1064 + c)
    b.paint(mask(F, F, lambda d, s: (el(d, s, hcx - 2.6, hcy + 0.6, 1.5, 1.3),
                                     el(d, s, hcx + 2.6, hcy + 0.6, 1.5, 1.3))),
            (0.06, 0.05, 0.05), 0.3)
    b.paint(mask(F, F, lambda d, s: (el(d, s, hcx - 2.6, hcy + 0.5, 0.7, 0.6),
                                     el(d, s, hcx + 2.6, hcy + 0.5, 0.7, 0.6))),
            (0.94, 0.32, 0.14), 0.45)
    jaw = 0.5 if mode == "attack" else 0.18
    b.paint(mask(F, F, lambda d, s: el(d, s, hcx, hcy + 4.4 + jaw * 2.0, 3.0, 1.6 + jaw * 1.5)),
            base_col(MUT["maw"], F, F, 1080, 0.1), 0.35)
    for c in range(4):
        xx = hcx - 2.2 + c * 1.5
        b.paint(mask(F, F, lambda d, s, x=xx: pg(d, s, [(x, hcy + 3.8 + jaw),
                                                        (x + 0.9, hcy + 3.8 + jaw),
                                                        (x + 0.45, hcy + 4.7 + jaw)])),
                (0.70, 0.66, 0.56), 0.45)


def gen_mutant() -> None:
    build_strip("mutant_idle", 4, lambda b, i: mutant_frame(b, i, 4, "idle"),
                "Кровосос: сгорбленная стойка, щупальца на лице шевелятся")
    build_strip("mutant_walk", 6, lambda b, i: mutant_frame(b, i, 6, "walk"),
                "Кровосос: тяжёлый шаг, длинные руки почти до земли")
    build_strip("mutant_attack", 4, lambda b, i: mutant_frame(b, i, 4, "attack"),
                "Кровосос: замах с раскрытой пастью и когтями")


# ================================================================== КАБАН
BOAR = dict(body=hx("5B4732"), skin=hx("6B5540"), nose=hx("2E2620"), maw=hx("2A1412"))


def boar_frame(b: Buf, i: int, n: int, mode: str = "idle") -> None:
    """Кабан: приземистая туша с горбом, пятак, клыки."""
    sw = math.sin(2.0 * math.pi * i / n)
    bob = abs(sw) * (0.9 if mode == "walk" else 0.4)
    head_drop = 0.0 if mode != "attack" else 2.2
    hy = 40.5 - bob * 0.5 + head_drop * 0.4
    fx = 1.0 if mode == "walk" else (1.8 if mode == "attack" else 0.0)
    quad_leg(b, BOAR, 34.0, hy + 5.0, 35.0 + sw * 3.0 * fx, 57.4 - max(0.0, sw) * 2.2 * fx,
             0.0, 2.6, 1.0, 1100)
    quad_leg(b, BOAR, 30.0, hy + 5.0, 29.0 - sw * 2.6 * fx, 57.4 - max(0.0, -sw) * 2.2 * fx,
             0.0, 2.6, 0.84, 1110)
    quad_body(b, BOAR, hy=hy, chest=33.0, haunch=20.0, rx=8.6, ry=8.0, seed=1120)
    # горб над лопатками и щетина
    b.paint(mask(F, F, lambda d, s: el(d, s, 33.0, hy - 5.4, 7.6, 4.2)),
            base_col(dk(BOAR["body"], 1.16), F, F, 1130, 0.13), 0.82, 0.26, 1131)
    for k in range(7):
        xx = 24.0 + k * 2.4
        yy = hy - 7.0 + math.sin(k * 0.8) * 0.8
        b.paint(mask(F, F, lambda d, s, x=xx, y=yy: pg(d, s, [(x, y), (x + 1.8, y + 0.4),
                                                              (x + 0.9, y - 2.6)])),
                base_col(dk(hx("2A2119"), 0.95), F, F, 1140 + k, 0.1), 0.85)
    quad_leg(b, BOAR, 22.0, hy + 5.0, 21.0 - sw * 2.8 * fx, 57.0 - max(0.0, -sw) * 1.8 * fx,
             0.0, 2.7, 0.86, 1150)
    quad_leg(b, BOAR, 18.0, hy + 5.0, 17.0 + sw * 2.8 * fx, 57.4 - max(0.0, sw) * 1.8 * fx,
             0.0, 2.7, 1.0, 1160)
    # хвост-крючок
    b.paint(mask(F, F, lambda d, s: tp(d, s, 13.0, hy - 3.0, 9.0, hy - 6.5 + sw * 0.8, 1.1, 0.6)),
            base_col(dk(BOAR["body"], 0.9), F, F, 1170, 0.12), 0.55, 0.3, 1171)
    # шея и голова
    hcx, hcy = 45.5, hy - 1.5 + head_drop
    b.paint(mask(F, F, lambda d, s: tp(d, s, 35.0, hy - 2.0, hcx - 3.0, hcy + 1.0, 5.4, 4.8)),
            base_col(dk(BOAR["skin"], 0.92), F, F, 1180, 0.12), 0.64, 0.24, 1181)
    beast_head(b, BOAR, hcx, hcy, 5.8, 5.0, 6.2, 1190, jaw=(0.35 if mode != "attack" else 0.55),
               ear=0.7, eye=(0.80, 0.26, 0.10))
    # светлый пятак и клыки
    b.paint(mask(F, F, lambda d, s: el(d, s, hcx + 5.4, hcy + 4.4, 2.0, 1.6)),
            base_col(hx("9A7A68"), F, F, 1195, 0.12), 0.7)
    for sgn in (0.0, 1.0):
        def mt(d, s, g=sgn):
            pg(d, s, [(hcx + 3.0 + g * 2.4, hcy + 3.6), (hcx + 4.4 + g * 2.4, hcy + 3.4),
                      (hcx + 6.6 + g * 1.8, hcy - 0.2), (hcx + 5.2 + g * 1.8, hcy + 0.2)])
        b.paint(mask(F, F, mt), base_col(hx("D6CDB4"), F, F, 1200, 0.08), 0.76, 0.2, 1201)
    mud = P.clamp01((fbm2(F, F, 4, 3, 1210) - 0.4) * 2.2) * (b.a > 0.55)
    b.tint(mud, hx("3A3222"), 0.4)
    b.scale(b.a * radial(F, F, 30.0, hy - 6.5, 12.0, 0.9), 1.12)
    if mode == "attack":
        b.scale(b.a * radial(F, F, hcx, hcy, 9.0, 0.9), 1.10)


def gen_boar() -> None:
    build_strip("boar_idle", 4, lambda b, i: boar_frame(b, i, 4, "idle"),
                "Мутировавший кабан: приземистая туша, горб, щетина, клыки")
    build_strip("boar_walk", 6, lambda b, i: boar_frame(b, i, 6, "walk"),
                "Кабан: тяжёлая рысь, четыре ноги, клыки вперёд")
    build_strip("boar_attack", 4, lambda b, i: boar_frame(b, i, 4, "attack"),
                "Кабан: разгон головой вниз, клыки нацелены")


# ================================================================== ПРОПЫ
def make_prop(name: str, w: int, h: int, fn, desc: str, normal: bool = True,
              quant: int = 40, ao: float = 0.5, strength: float = 1.1) -> None:
    """Одиночный спрайт пропа (со своей normal-map)."""
    b = Buf(w, h)
    fn(b)
    rgba, nrm = render(b, normal=normal, quant=quant, ao=ao, strength=strength)
    save_single(name, rgba, nrm, desc)


def cyl_height(w: int, h: int, x0: float, x1: float, amp: float = 0.34) -> np.ndarray:
    """Карта высот цилиндра (скругление по X)."""
    xs = np.arange(w, dtype=np.float32)[None, :]
    cx = (x0 + x1) * 0.5
    r = max((x1 - x0) * 0.5, 1e-3)
    t = P.clamp01(1.0 - ((xs - cx) / r) ** 2)
    return (0.42 + amp * np.sqrt(t)).astype(np.float32) + np.zeros((h, w), np.float32)


def barrel(b: Buf, toxic: bool) -> None:
    """Бочка: цилиндр с обручами, ржавчина или токсичная маркировка."""
    w, h = b.w, b.h
    body = mask(w, h, lambda d, s: (rc(d, s, 6.0, 6.0, 42.0, 62.0, 4.0),
                                    el(d, s, 24.0, 7.5, 18.0, 3.4),
                                    el(d, s, 24.0, 61.0, 18.0, 3.0)))
    ch = cyl_height(w, h, 6.0, 42.0)
    base = hx("6C8A3E") if toxic else hx("7A5030")
    b.paint(body, base_col(base, w, h, 1300, 0.16), ch, 0.24, 1301)
    for yy in (17.0, 38.0, 56.0):                        # обручи
        b.paint(mask(w, h, lambda d, s, y=yy: rc(d, s, 6.0, y - 2.0, 42.0, y + 2.0, 0.7)) * body,
                base_col(dk(base, 0.66), w, h, 1310 + int(yy), 0.12), 0.62)
    b.paint(mask(w, h, lambda d, s: el(d, s, 24.0, 7.6, 17.4, 3.0)),
            base_col(dk(base, 0.86), w, h, 1320, 0.14), 0.72)
    b.paint(mask(w, h, lambda d, s: el(d, s, 24.0, 7.6, 12.0, 2.0)),
            base_col(dk(base, 0.7), w, h, 1321, 0.1), 0.74)
    streak = P.clamp01((fbm2(w, h, 3, 3, 1330) - 0.42) * 2.6) * body
    b.tint(streak, hx("3E2A1A") if not toxic else hx("2E3A12"), 0.5)
    if toxic:
        b.paint(mask(w, h, lambda d, s: el(d, s, 24.0, 33.0, 9.0, 7.0)),
                base_col(hx("C7D24A"), w, h, 1340, 0.1), 0.56)
        for k in range(3):                               # знак радиации (упрощённый)
            ang = -90 + k * 120
            a0 = math.radians(ang - 26)
            a1 = math.radians(ang + 26)
            def sec(d, s, a0=a0, a1=a1):
                pts = [(24.0, 33.0)]
                for t in range(7):
                    aa = a0 + (a1 - a0) * t / 6.0
                    pts.append((24.0 + math.cos(aa) * 7.0, 33.0 + math.sin(aa) * 7.0))
                pg(d, s, pts)
            b.paint(mask(w, h, sec), (0.08, 0.08, 0.06), 0.5)
        b.paint(mask(w, h, lambda d, s: el(d, s, 24.0, 33.0, 1.8, 1.8)), (0.08, 0.08, 0.06), 0.55)
    else:
        b.paint(mask(w, h, lambda d, s: rc(d, s, 20.0, 24.0, 30.0, 30.0, 1.0)),
                (0.55, 0.52, 0.44), 0.6)                 # выцветший трафарет
    b.scale(body * radial(w, h, 12.0, 28.0, 34.0, 0.9), 1.16)
    b.scale(body * radial(w, h, 40.0, 40.0, 18.0, 0.9), 0.84)


def prop_barrel_rust(b: Buf) -> None:
    barrel(b, False)


def prop_barrel_toxic(b: Buf) -> None:
    barrel(b, True)


def box_top_side(b: Buf, x0: float, x1: float, y0: float, y1: float, ox: float,
                 oy: float, col_front, col_top, col_side, seed: int):
    """Три видимые грани ящика (3/4 сверху). Возвращает маски (front, side, top)."""
    front = mask(b.w, b.h, lambda d, s: rc(d, s, x0, y0, x1, y1, 1.2))
    side = mask(b.w, b.h, lambda d, s: pg(d, s, [(x1, y0), (x1 + ox, y0 - oy),
                                                 (x1 + ox, y1 - oy), (x1, y1)]))
    top = mask(b.w, b.h, lambda d, s: pg(d, s, [(x0, y0), (x1, y0),
                                                (x1 + ox, y0 - oy), (x0 + ox, y0 - oy)]))
    b.paint(front, base_col(col_front, b.w, b.h, seed, 0.13), 0.5, 0.3, seed + 1)
    b.paint(side, base_col(col_side, b.w, b.h, seed + 2, 0.13), 0.52, 0.3, seed + 3)
    b.paint(top, base_col(col_top, b.w, b.h, seed + 4, 0.13), 0.86, 0.3, seed + 5)
    return front, side, top


def prop_crate_wood(b: Buf) -> None:
    front, side, top = box_top_side(b, 6.0, 44.0, 16.0, 54.0, 8.0, 8.0,
                                    hx("7A5C36"), hx("8E6C42"), hx("5C452A"), 1400)
    allx = P.clamp01(front + side + top)
    for k in range(5):                                   # доски
        yy = 20.0 + k * 7.0
        seam = mask(b.w, b.h, lambda d, s, y=yy: rc(d, s, 6.0, y, 44.0, y + 1.1, 0.0))
        b.paint(seam * front, dk(hx("5C452A"), 0.9), 0.44)
    for k in range(4):                                   # рёбра жёсткости
        xx = 10.0 + k * 10.0
        b.paint(mask(b.w, b.h, lambda d, s, x=xx: rc(d, s, x, 16.0, x + 1.2, 54.0, 0.0)) * front,
                dk(hx("5C452A"), 0.95), 0.46)
    b.paint(mask(b.w, b.h, lambda d, s: (rc(d, s, 6.0, 16.0, 8.4, 54.0, 0.0),
                                         rc(d, s, 41.6, 16.0, 44.0, 54.0, 0.0),
                                         rc(d, s, 6.0, 16.0, 44.0, 18.4, 0.0),
                                         rc(d, s, 6.0, 51.6, 44.0, 54.0, 0.0))) * allx,
            base_col(dk(hx("3E4038"), 1.0), b.w, b.h, 1410, 0.12), 0.7)     # уголки
    b.paint(mask(b.w, b.h, lambda d, s: rc(d, s, 16.0, 26.0, 34.0, 40.0, 1.0)) * allx,
            (0.62, 0.58, 0.46), 0.56)                                       # трафарет
    b.tint(allx * P.clamp01((fbm2(b.w, b.h, 4, 3, 1420) - 0.45) * 2.4), hx("3A3020"), 0.4)
    b.scale(allx * radial(b.w, b.h, 10.0, 22.0, 24.0, 0.9), 1.1)


def prop_crate_metal(b: Buf) -> None:
    front, side, top = box_top_side(b, 6.0, 44.0, 16.0, 54.0, 8.0, 8.0,
                                    hx("4E5A50"), hx("5E6C60"), hx("3A443C"), 1500)
    allx = P.clamp01(front + side + top)
    for k in range(3):
        xx = 6.0 + k * 14.0
        b.paint(mask(b.w, b.h, lambda d, s, x=xx: rc(d, s, x + 2.0, 18.0, x + 4.0, 52.0, 0.6)) * front,
                dk(hx("2E3830"), 1.1), 0.72)
    for k in range(10):                                  # заклёпки
        xx = 9.0 + (k % 5) * 7.5
        yy = 19.0 if k < 5 else 51.0
        b.paint(mask(b.w, b.h, lambda d, s, x=xx, y=yy: el(d, s, x, y, 0.9, 0.9)) * allx,
                (0.68, 0.72, 0.70), 0.76)
    b.paint(mask(b.w, b.h, lambda d, s: rc(d, s, 30.0, 30.0, 44.0, 38.0, 1.2)) * front,
            dk(hx("2E3830"), 1.2), 0.8)                                     # ручка
    rust = P.clamp01((fbm2(b.w, b.h, 5, 4, 1510) - 0.42) * 2.4) * allx
    b.tint(rust, hx("6E4222"), 0.6)
    b.tint(rust * P.clamp01((fbm2(b.w, b.h, 9, 3, 1511) - 0.5) * 2.0), hx("3A2113"), 0.4)
    b.scale(allx * radial(b.w, b.h, 12.0, 24.0, 26.0, 0.9), 1.1)


def prop_car_wreck(b: Buf) -> None:
    """Разбитая машина (вид сверху-3/4): кузов, капот, стёкла, колёса, ржавчина."""
    w, h = b.w, b.h
    # колёса по углам (выступают из-под кузова)
    for (cx, cy) in ((26.0, 15.0), (98.0, 15.0), (26.0, 65.0), (98.0, 65.0)):
        b.paint(ragg(mask(w, h, lambda d, s, x=cx, y=cy: rc(d, s, x - 9.0, y - 4.5, x + 9.0,
                                                            y + 4.5, 2.5)), 0.3, int(cx + cy)),
                base_col(hx("232326"), w, h, int(cx + cy), 0.1), 0.5, 0.32, int(cy))
    body = mask(w, h, lambda d, s: rc(d, s, 8.0, 18.0, 120.0, 62.0, 10.0))
    b.paint(body, base_col(hx("5E5A50"), w, h, 1600, 0.14), 0.6, 0.26, 1601)
    # крыша-салон светлее, капот темнее
    b.paint(mask(w, h, lambda d, s: rc(d, s, 52.0, 20.0, 98.0, 60.0, 7.0)) * body,
            base_col(hx("6E6A5E"), w, h, 1602, 0.12), 0.82)
    b.paint(mask(w, h, lambda d, s: rc(d, s, 14.0, 22.0, 50.0, 58.0, 6.0)) * body,
            base_col(dk(hx("5E5A50"), 0.88), w, h, 1603, 0.12), 0.66)
    # лобовое и заднее стекло
    glass = base_col(hx("3E4C50"), w, h, 1604, 0.2)
    b.paint(mask(w, h, lambda d, s: rc(d, s, 50.0, 21.0, 56.0, 59.0, 2.0)) * body, glass, 0.5)
    b.paint(mask(w, h, lambda d, s: rc(d, s, 94.0, 21.0, 100.0, 59.0, 2.0)) * body,
            base_col(dk(hx("3E4C50"), 0.85), w, h, 1605, 0.2), 0.5)
    for k in range(5):                                   # трещины на лобовом
        yy = 25.0 + k * 7.0
        b.paint(mask(w, h, lambda d, s, y=yy: ln(d, s, 50.6, y, 55.6, y + 2.0, 0.5)),
                (0.78, 0.82, 0.80), 0.6)
    # рёбра жёсткости крыши
    for k in range(3):
        xx = 60.0 + k * 12.0
        b.paint(mask(w, h, lambda d, s, x=xx: rc(d, s, x, 23.0, x + 1.3, 57.0, 0.0)) * body,
                dk(hx("6E6A5E"), 0.8), 0.8)
    # выбитая дверь — тёмный проём с рваным краем
    b.paint(ragg(mask(w, h, lambda d, s: rc(d, s, 58.0, 23.0, 90.0, 33.0, 1.2)), 0.35, 1606),
            base_col(hx("221C18"), w, h, 1607, 0.12), 0.42)
    b.paint(ragg(mask(w, h, lambda d, s: rc(d, s, 58.0, 47.0, 90.0, 57.0, 1.2)), 0.35, 1608),
            base_col(hx("221C18"), w, h, 1609, 0.12), 0.42)
    # капот: швы и решётка радиатора
    b.paint(mask(w, h, lambda d, s: rc(d, s, 24.0, 30.0, 46.0, 50.0, 3.0)) * body,
            base_col(dk(hx("5E5A50"), 1.06), w, h, 1610, 0.1), 0.7)
    for k in range(4):
        yy = 28.0 + k * 6.0
        b.paint(mask(w, h, lambda d, s, y=yy: rc(d, s, 9.5, y, 15.0, y + 3.0, 0.5)) * body,
                dk(hx("2A2724"), 1.0), 0.66)
    # фара и ржавые потёки
    b.paint(mask(w, h, lambda d, s: el(d, s, 13.0, 24.0, 3.2, 2.4)) * body,
            base_col(hx("9A9A86"), w, h, 1611, 0.1), 0.72)
    rust = P.clamp01((fbm2(w, h, 6, 4, 1620) - 0.4) * 2.6) * body
    b.tint(rust, hx("7A4422"), 0.62)
    b.tint(rust * P.clamp01((fbm2(w, h, 14, 3, 1621) - 0.5) * 2.0), hx("3E2413"), 0.42)
    b.scale(body * radial(w, h, 64.0, 22.0, 46.0, 0.9), 1.12)
    b.scale(body * radial(w, h, 64.0, 62.0, 44.0, 0.9), 0.82)


def prop_bus_wreck(b: Buf) -> None:
    """Сгоревший автобус: длинный кузов, ряд окон, ржавчина и гарь."""
    w, h = b.w, b.h
    for (cx, cy) in ((26.0, 78.0), (78.0, 82.0), (124.0, 82.0), (146.0, 78.0)):
        b.paint(ragg(mask(w, h, lambda d, s, x=cx, y=cy: el(d, s, x, y, 9.0, 6.0)), 0.3,
                     int(cx + cy)), base_col(hx("22222A"), w, h, int(cx), 0.1), 0.5, 0.32, int(cy))
    body = mask(w, h, lambda d, s: (rc(d, s, 10.0, 14.0, 150.0, 82.0, 10.0),
                                    rc(d, s, 13.0, 18.0, 147.0, 78.0, 8.0)))
    b.paint(body, base_col(hx("4E5A4A"), w, h, 1700, 0.14), 0.6, 0.26, 1701)
    # крыша
    b.paint(ragg(mask(w, h, lambda d, s: (rc(d, s, 22.0, 22.0, 142.0, 74.0, 6.0),
                                          rc(d, s, 26.0, 26.0, 138.0, 70.0, 5.0))), 0.2, 1702),
            base_col(hx("59654F"), w, h, 1703, 0.12), 0.72)
    for k in range(2):                                   # люки на крыше
        xx = 60.0 + k * 46.0
        b.paint(mask(w, h, lambda d, s, x=xx: rc(d, s, x, 40.0, x + 12.0, 56.0, 1.5)),
                dk(hx("59654F"), 0.8), 0.84)
    # лобовое стекло
    b.paint(mask(w, h, lambda d, s: pg(d, s, [(16.0, 22.0), (24.0, 20.0), (24.0, 76.0), (16.0, 74.0)])),
            base_col(hx("3E4A48"), w, h, 1704, 0.2), 0.5)
    # ряд боковых окон с рёбрами
    b.paint(mask(w, h, lambda d, s: rc(d, s, 30.0, 80.0, 142.0, 84.0, 1.0)),
            base_col(hx("2A2E2E"), w, h, 1705, 0.1), 0.5)
    for k in range(7):
        xx = 32.0 + k * 16.0
        b.paint(mask(w, h, lambda d, s, x=xx: rc(d, s, x, 20.0, x + 12.0, 34.0, 1.0)),
                base_col(hx("3E4A48"), w, h, 1706 + k, 0.16), 0.6)
    # дверь и полоса
    b.paint(mask(w, h, lambda d, s: rc(d, s, 128.0, 60.0, 146.0, 78.0, 1.5)),
            dk(hx("4E5A4A"), 0.8), 0.66)
    b.paint(mask(w, h, lambda d, s: rc(d, s, 14.0, 46.0, 148.0, 52.0, 1.0)),
            base_col(hx("9AA05A"), w, h, 1716, 0.12), 0.62)
    # выгоревший зад
    burn = P.clamp01((fbm2(w, h, 4, 4, 1720) - 0.34) * 2.2) * body
    b.tint(burn, hx("241F1A"), 0.72)
    rust = P.clamp01((fbm2(w, h, 8, 4, 1721) - 0.42) * 2.6) * body
    b.tint(rust, hx("7A4422"), 0.62)
    b.scale(body * radial(w, h, 30.0, 18.0, 50.0, 0.9), 1.1)


def prop_tree_dead(b: Buf) -> None:
    """Сухое дерево: ствол, ветви-вилки, торчащие сучья."""
    w, h = b.w, b.h
    rng = np.random.default_rng(1800)

    def branch(x, y, ang, ln, wid, depth, sd):
        ex = x + math.cos(ang) * ln
        ey = y + math.sin(ang) * ln
        b.paint(mask(w, h, lambda d, s, a=(x, y), e=(ex, ey), ww=wid: tp(d, s, a[0], a[1],
                                                                       e[0], e[1], ww, ww * 0.68)),
                base_col(dk(WOOD_D, 0.85 + 0.1 * depth), w, h, sd, 0.16), 0.55, 0.3, sd + 1)
        if depth <= 0 or ln < 7:
            return
        nk = 2 if depth > 1 else 3
        for k in range(nk):
            sp = (k - (nk - 1) * 0.5) * (0.55 + float(rng.random()) * 0.45)
            branch(ex, ey, ang + sp * 0.9 + (float(rng.random()) - 0.5) * 0.2,
                   ln * (0.62 + float(rng.random()) * 0.16), wid * 0.66, depth - 1,
                   sd + 11 + k * 7)
    # ствол
    b.paint(mask(w, h, lambda d, s: tp(d, s, 50.0, 126.0, 47.0, 74.0, 7.0, 3.6)),
            base_col(WOOD_D, w, h, 1810, 0.18), 0.6, 0.34, 1811)
    for k in range(4):                                        # борозды коры
        xx = 45.0 + k * 2.4
        b.paint(mask(w, h, lambda d, s, x=xx: tp(d, s, x, 124.0, x - 1.2, 78.0, 0.5, 0.4)),
                dk(WOOD_D, 0.7), 0.62)
    # корни-лапы
    for (x0, y0, x1, y1) in ((46.0, 122.0, 34.0, 127.0), (50.0, 122.0, 62.0, 127.0),
                             (44.0, 118.0, 30.0, 122.0)):
        b.paint(mask(w, h, lambda d, s, a=(x0, y0), e=(x1, y1): tp(d, s, a[0], a[1], e[0], e[1],
                                                                  2.4, 1.2)),
                base_col(dk(WOOD_D, 0.9), w, h, 1820, 0.16), 0.55, 0.32, 1821)
    branch(47.0, 78.0, -1.9, 22.0, 3.0, 2, 1830)
    branch(48.0, 88.0, -1.15, 20.0, 2.8, 2, 1840)
    branch(49.0, 96.0, -0.5, 16.0, 2.4, 1, 1850)
    moss = P.clamp01(1.0 - radial(w, h, 48.0, 118.0, 26.0, 0.9)) * (b.a > 0.5)
    b.tint(moss * P.clamp01((fbm2(w, h, 6, 3, 1860) - 0.4) * 2.4), hx("4A5030"), 0.5)
    b.tint(b.a * radial(w, h, 40.0, 74.0, 34.0, 0.9), hx("6A6250"), 0.3)


def prop_tree_pine(b: Buf) -> None:
    """Мёртвая ель: тёмные ярусы хвои с рваными краями."""
    w, h = b.w, b.h
    b.paint(mask(w, h, lambda d, s: tp(d, s, 49.0, 142.0, 47.0, 108.0, 5.0, 3.4)),
            base_col(hx("4A3A28"), w, h, 1900, 0.16), 0.6, 0.3, 1901)
    grn = hx("33412A")
    layers = 7
    for k in range(layers):
        t = k / (layers - 1.0)
        cy = 120.0 - t * 108.0
        half = 24.0 - t * 21.0
        def lay(d, s, y=cy, hw=half, kk=k):
            pg(d, s, [(49.0, y - 15.0 - kk * 0.6), (49.0 + hw, y + 5.0), (49.0, y + 1.0),
                      (49.0 - hw, y + 5.0)])
            n = max(2, int(hw / 3.0))
            for j in range(n):                       # рваный низ яруса
                x0 = 49.0 - hw + j * (hw * 2.0 / n)
                pg(d, s, [(x0, y + 3.4), (x0 + hw * 2.0 / n, y + 3.4), (x0 + 1.4, y + 8.0 - j % 2 * 2.4)])
        b.paint(mask(w, h, lay), base_col(dk(grn, 0.86 + 0.2 * t), w, h, 1910 + k, 0.16),
                0.62, 0.34, 1920 + k)
    # подсветка слева и тень справа
    tree = b.a.copy()
    b.scale(tree * radial(w, h, 34.0, 70.0, 42.0, 0.9), 1.16)
    b.scale(tree * radial(w, h, 70.0, 80.0, 34.0, 0.9), 0.8)
    rust = P.clamp01((fbm2(w, h, 5, 4, 1930) - 0.52) * 2.6) * tree
    b.tint(rust, hx("8A6A2A"), 0.5)                       # рыжие мёртвые ветки
    b.tint(tree * radial(w, h, 49.0, 14.0, 22.0, 1.0), hx("B9B49A"), 0.22)


def prop_bush_dry(b: Buf) -> None:
    """Сухой куст-перекати-поле: клубок веточек."""
    w, h = b.w, b.h
    rng = np.random.default_rng(2000)
    ball = mask(w, h, lambda d, s: el(d, s, 32.0, 30.0, 24.0, 19.0))
    for k in range(74):
        a = float(rng.random()) * math.tau
        r = 6.0 + float(rng.random()) * 18.0
        cx, cy = 32.0 + math.cos(a) * r, 30.0 + math.sin(a) * r * 0.8
        a2 = a + 2.0 + (float(rng.random()) - 0.5) * 1.6
        ex, ey = 32.0 + math.cos(a2) * r * 0.42, 30.0 + math.sin(a2) * r * 0.42
        b.paint(mask(w, h, lambda d, s, p=(cx, cy), q=(ex, ey): ln(d, s, p[0], p[1], q[0], q[1],
                                                                   1.0)) * ball,
                base_col(hx("7E6C42"), w, h, 2000 + k, 0.22), 0.58)
    b.tint(ball * P.clamp01((fbm2(w, h, 5, 4, 2010) - 0.4) * 2.0), hx("6A5A34"), 0.4)
    b.scale(ball * radial(w, h, 24.0, 22.0, 26.0, 0.9), 1.16)
    b.tint(radial(w, h, 32.0, 46.0, 16.0, 1.0) * (b.a > 0.4), hx("3A2E1A"), 0.3)


def rock(b: Buf, seed: int, cx: float, cy: float, rx: float, ry: float) -> None:
    """Валун: неровный силуэт, грани, трещины, мох."""
    w, h = b.w, b.h
    rng = np.random.default_rng(seed)
    pts = []
    n = 11
    for k in range(n):
        a = k / n * math.tau
        rr = 0.78 + float(rng.random()) * 0.32
        pts.append((cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr))
    body = mask(w, h, lambda d, s: pg(d, s, pts))
    b.paint(body, base_col(hx("6E6C66"), w, h, seed + 1, 0.15), 0.6, 0.26, seed + 2)
    for k in range(3):                                    # грани
        def facet(d, s, kk=k):
            a0 = kk * 2.1 + 0.3
            p = []
            for t in range(4):
                aa = a0 + t * 1.35
                rr = 0.42 + 0.3 * t / 3.0
                p.append((cx + math.cos(aa) * rx * rr, cy + math.sin(aa) * ry * rr))
            pg(d, s, p)
        b.paint(mask(w, h, facet) * body,
                base_col(dk(hx("6E6C66"), 1.0 + 0.16 * k), w, h, seed + 5 + k, 0.12),
                0.66 + 0.06 * k)
    for k in range(5):                                    # трещины
        a0 = float(rng.random()) * math.tau
        x0 = cx + math.cos(a0) * rx * 0.2
        y0 = cy + math.sin(a0) * ry * 0.2
        x1 = cx + math.cos(a0) * rx * 0.95
        y1 = cy + math.sin(a0 + 0.25) * ry * 0.95
        b.paint(mask(w, h, lambda d, s, p=(x0, y0), q=(x1, y1): ln(d, s, p[0], p[1], q[0],
                                                                   q[1], 0.55)) * body,
                dk(hx("4A4844"), 0.8), 0.45)
    b.tint(speck(w, h, 90, seed + 31, 0.9) * body, hx("4E4C48"), 0.4)
    moss = P.clamp01(1.0 - radial(w, h, cx, cy + ry * 0.6, rx * 0.9, 0.9)) * body
    b.tint(moss * P.clamp01((fbm2(w, h, 5, 3, seed + 41) - 0.4) * 2.2), hx("4E5A32"), 0.5)
    b.scale(body * radial(w, h, cx - rx * 0.4, cy - ry * 0.6, rx * 1.2, 0.9), 1.14)


def prop_rock_a(b: Buf) -> None:
    rock(b, 2100, 36.0, 34.0, 28.0, 20.0)


def prop_rock_b(b: Buf) -> None:
    rock(b, 2200, 48.0, 38.0, 40.0, 24.0)
    rock(b, 2210, 22.0, 46.0, 16.0, 12.0)


def prop_tent(b: Buf) -> None:
    """Палатка: брезентовый скат, вход, колышки и растяжки."""
    w, h = b.w, b.h
    tent = mask(w, h, lambda d, s: pg(d, s, [(8.0, 72.0), (30.0, 34.0), (58.0, 26.0),
                                             (88.0, 50.0), (84.0, 74.0), (12.0, 74.0)]))
    b.paint(tent, base_col(CANVAS, w, h, 2300, 0.14), 0.62, 0.26, 2301)
    b.paint(mask(w, h, lambda d, s: pg(d, s, [(8.0, 72.0), (30.0, 34.0), (58.0, 26.0),
                                              (56.0, 74.0)])) * tent,
            base_col(dk(CANVAS, 1.1), w, h, 2302, 0.12), 0.7)
    b.paint(mask(w, h, lambda d, s: pg(d, s, [(58.0, 26.0), (88.0, 50.0), (84.0, 74.0),
                                              (56.0, 74.0)])) * tent,
            base_col(dk(CANVAS, 0.78), w, h, 2303, 0.12), 0.64)
    for k in range(3):                                    # швы
        b.paint(mask(w, h, lambda d, s, kk=k: ln(d, s, 30.0 + kk * 8.0, 34.0 + kk * 2.0,
                                                 20.0 + kk * 12.0, 74.0, 0.7)) * tent,
                dk(CANVAS_D, 1.0), 0.5)
    def doorway(d, s):
        pg(d, s, [(56.0, 28.0), (78.0, 48.0), (76.0, 72.0), (58.0, 72.0)])
    b.paint(ragg(mask(w, h, doorway), 0.3, 2304) * tent,
            base_col(hx("2A2820"), w, h, 2305, 0.12), 0.35)
    def flap(d, s):
        pg(d, s, [(60.0, 30.0), (76.0, 48.0), (72.0, 70.0), (62.0, 70.0)])
    b.paint(ragg(mask(w, h, flap), 0.35, 2306) * tent,
            base_col(dk(CANVAS, 0.92), w, h, 2307, 0.14), 0.6)
    for (x0, y0, x1, y1) in ((30.0, 36.0, 6.0, 74.0), (88.0, 50.0, 94.0, 74.0),
                             (56.0, 27.0, 56.0, 74.0)):
        b.paint(mask(w, h, lambda d, s, a=(x0, y0), e=(x1, y1): ln(d, s, a[0], a[1], e[0], e[1],
                                                                  0.6)), hx("8A8266"), 0.5)
    b.tint((1.0 - radial(w, h, 46.0, 34.0, 40.0, 0.9)) * tent, hx("5A4E36"), 0.4)
    b.scale(tent * radial(w, h, 30.0, 50.0, 40.0, 0.9), 1.08)


def prop_campfire(b: Buf) -> None:
    """Костровище: камни по кругу, головешки, угли и огонь."""
    w, h = b.w, b.h
    b.paint(radial(w, h, 24.0, 30.0, 20.0, 0.85) * 0.9, base_col(hx("3E3A36"), w, h, 2400, 0.2),
            0.36, 0.4, 2401)
    for k in range(9):                                    # камни
        a = k / 9.0 * math.tau
        cx = 24.0 + math.cos(a) * 16.0
        cy = 30.0 + math.sin(a) * 12.0
        b.paint(ragg(mask(w, h, lambda d, s, x=cx, y=cy: el(d, s, x, y, 4.4, 3.4)), 0.4, 2400 + k),
                base_col(hx("605C54"), w, h, 2410 + k, 0.16), 0.5, 0.4, 2415)
    for (x0, y0, x1, y1) in ((8.0, 38.0, 34.0, 24.0), (10.0, 32.0, 38.0, 40.0),
                             (16.0, 40.0, 30.0, 22.0)):
        b.paint(mask(w, h, lambda d, s, p=(x0, y0), q=(x1, y1): tp(d, s, p[0], p[1], q[0], q[1],
                                                                  3.0, 2.4)),
                base_col(hx("3A2A1C"), w, h, int(x0 * 7), 0.18), 0.5, 0.4, int(x0))
    b.paint(mask(w, h, lambda d, s: el(d, s, 24.0, 33.0, 9.0, 5.0)),
            base_col(hx("8A3A10"), w, h, 2430, 0.3), 0.34)             # угли
    for k in range(26):                                                # угольки
        rng = np.random.default_rng(2440 + k)
        x = 24.0 + (float(rng.random()) - 0.5) * 16.0
        y = 33.0 + (float(rng.random()) - 0.5) * 7.0
        b.paint(mask(w, h, lambda d, s, xx=x, yy=y: el(d, s, xx, yy, 0.9, 0.7)),
                FIRE_HOT if k % 3 == 0 else FIRE, 0.4)
    for k in range(5):                                                 # языки пламени
        rng = np.random.default_rng(2460 + k)
        x = 24.0 + (float(rng.random()) - 0.5) * 11.0
        hgt = 12.0 + float(rng.random()) * 14.0
        wd = 3.4 + float(rng.random()) * 3.6
        def flame(d, s, xx=x, hh=hgt, ww=wd):
            pg(d, s, [(xx - ww, 33.0), (xx - ww * 0.5, 33.0 - hh * 0.5), (xx, 33.0 - hh),
                      (xx + ww * 0.6, 33.0 - hh * 0.45), (xx + ww, 33.0)])
        b.paint(ragg(mask(w, h, flame), 0.35, 2470 + k),
                FIRE_HOT if k % 2 == 0 else FIRE, 0.4)
    b.paint(mask(w, h, lambda d, s: el(d, s, 24.0, 30.0, 3.6, 5.0)), (1.0, 0.96, 0.80), 0.45)


def prop_power_pole(b: Buf) -> None:
    """Столб ЛЭП: крен, поперечина, изоляторы, обрывки проводов."""
    w, h = b.w, b.h
    b.paint(mask(w, h, lambda d, s: pg(d, s, [(6.0, 127.0), (10.0, 20.0), (20.0, 18.0),
                                              (22.0, 127.0)])),
            base_col(hx("5A4630"), w, h, 2500, 0.16), 0.6, 0.3, 2501)
    for k in range(3):                                   # волокна
        xx = 9.0 + k * 4.0
        b.paint(mask(w, h, lambda d, s, x=xx: tp(d, s, x, 126.0, x + 1.0, 24.0, 0.6, 0.5)),
                dk(hx("5A4630"), 0.75), 0.5)
    b.paint(mask(w, h, lambda d, s: rc(d, s, 0.0, 22.0, 32.0, 27.0, 1.5)),
            base_col(hx("4A3A26"), w, h, 2510, 0.14), 0.72)          # поперечина
    for k in range(3):                                   # изоляторы
        xx = 5.0 + k * 11.0
        b.paint(mask(w, h, lambda d, s, x=xx: (rc(d, s, x - 1.6, 27.0, x + 1.6, 33.0, 0.6),
                                               el(d, s, x, 32.0, 2.4, 1.6))),
                base_col(hx("6E6A58"), w, h, 2520 + k, 0.12), 0.8)
    for (x0, y0, x1, y1) in ((5.0, 34.0, 2.0, 74.0), (16.0, 34.0, 14.0, 60.0),
                             (27.0, 34.0, 30.0, 52.0)):
        b.paint(mask(w, h, lambda d, s, a=(x0, y0), e=(x1, y1): ln(d, s, a[0], a[1], e[0], e[1],
                                                                  0.55)), hx("3A3630"), 0.6)
    b.tint((1.0 - radial(w, h, 10.0, 30.0, 40.0, 0.9)) * b.a, hx("3A2A1A"), 0.35)
    b.scale(b.a * radial(w, h, 6.0, 60.0, 40.0, 0.9), 1.12)
    b.scale(b.a * radial(w, h, 26.0, 100.0, 30.0, 0.9), 0.82)


def prop_grave(b: Buf) -> None:
    """Могила: покосившийся крест, холмик, трава у основания."""
    w, h = b.w, b.h
    b.paint(ragg(mask(w, h, lambda d, s: el(d, s, 24.0, 56.0, 19.0, 7.0)), 0.4, 2600),
            base_col(hx("4E4436"), w, h, 2601, 0.18), 0.5, 0.4, 2602)
    cross = mask(w, h, lambda d, s: (tp(d, s, 16.0, 58.0, 22.0, 12.0, 3.4, 3.0),
                                     tp(d, s, 12.0, 26.0, 30.0, 22.0, 3.0, 2.8)))
    b.paint(cross, base_col(hx("6E6046"), w, h, 2603, 0.16), 0.7, 0.3, 2604)
    b.paint(mask(w, h, lambda d, s: (tp(d, s, 16.0, 58.0, 22.0, 12.0, 1.2, 1.0),
                                     tp(d, s, 12.0, 26.0, 30.0, 22.0, 1.0, 0.9))) * cross,
            base_col(dk(hx("6E6046"), 1.2), w, h, 2605, 0.12), 0.82)
    b.paint(mask(w, h, lambda d, s: rc(d, s, 17.4, 30.0, 25.0, 42.0, 0.8)),
            base_col(hx("3A3830"), w, h, 2606, 0.4), 0.68)              # табличка
    grass = speck(w, h, 70, 2610, 1.1) * P.clamp01(1.0 - radial(w, h, 24.0, 60.0, 26.0, 1.0))
    b.tint(grass, hx("55602E"), 0.5)
    b.tint(radial(w, h, 24.0, 60.0, 22.0, 0.9) * (b.a > 0.4), hx("2A2418"), 0.25)


def prop_well(b: Buf) -> None:
    """Колодец: каменное кольцо, тёмная вода, ворот с ведром."""
    w, h = b.w, b.h
    ring = mask(w, h, lambda d, s: el(d, s, 32.0, 40.0, 26.0, 16.0))
    b.paint(ring, base_col(hx("7A7870"), w, h, 2700, 0.15), 0.62, 0.3, 2701)
    for k in range(12):                                  # камни кольца
        a = k / 12.0 * math.tau
        cx = 32.0 + math.cos(a) * 23.0
        cy = 40.0 + math.sin(a) * 13.5
        b.paint(mask(w, h, lambda d, s, x=cx, y=cy: el(d, s, x, y, 4.4, 3.0)) * ring,
                base_col(dk(hx("7A7870"), 0.86 + 0.24 * (k % 3)), w, h, 2710 + k, 0.14),
                0.68, 0.35, 2720 + k)
    b.paint(mask(w, h, lambda d, s: el(d, s, 32.0, 40.0, 18.0, 10.0)),
            base_col(hx("16221E"), w, h, 2730, 0.2), 0.3)               # вода
    b.paint(mask(w, h, lambda d, s: el(d, s, 28.0, 38.0, 8.0, 4.0)),
            base_col(hx("2E4A3C"), w, h, 2731, 0.2), 0.34)
    b.paint(mask(w, h, lambda d, s: (rc(d, s, 12.0, 10.0, 16.0, 40.0, 1.0),
                                     rc(d, s, 48.0, 10.0, 52.0, 40.0, 1.0),
                                     rc(d, s, 10.0, 6.0, 54.0, 12.0, 2.0))),
            base_col(hx("4A3A26"), w, h, 2740, 0.14), 0.66)             # стойки и крыша
    b.paint(mask(w, h, lambda d, s: rc(d, s, 14.0, 22.0, 50.0, 25.0, 0.8)),
            base_col(hx("3A3226"), w, h, 2741, 0.12), 0.6)              # ворот
    b.paint(mask(w, h, lambda d, s: (ln(d, s, 32.0, 24.0, 32.0, 34.0, 0.6),
                                     rc(d, s, 27.0, 34.0, 37.0, 42.0, 1.2))),
            base_col(hx("4E4A44"), w, h, 2742, 0.12), 0.5)              # цепь и ведро
    moss = P.clamp01(1.0 - radial(w, h, 32.0, 46.0, 28.0, 0.9)) * b.a
    b.tint(moss * P.clamp01((fbm2(w, h, 5, 3, 2750) - 0.4) * 2.2), hx("4E5A32"), 0.45)


def prop_sign_radiation(b: Buf) -> None:
    """Знак радиации: ржавый столб и жёлтая табличка с трилистником."""
    w, h = b.w, b.h
    b.paint(mask(w, h, lambda d, s: rc(d, s, 21.0, 22.0, 27.0, 64.0, 1.0)),
            base_col(hx("5A4A32"), w, h, 2800, 0.16), 0.6, 0.3, 2801)
    plate = mask(w, h, lambda d, s: rc(d, s, 4.0, 6.0, 44.0, 30.0, 2.0))
    b.paint(plate, base_col(hx("B7A226"), w, h, 2802, 0.14), 0.66, 0.24, 2803)
    for k in range(3):                                   # трилистник
        ang = -90 + k * 120
        a0 = math.radians(ang - 28)
        a1 = math.radians(ang + 28)
        def sec(d, s, a0=a0, a1=a1):
            pts = [(24.0, 18.0)]
            for t in range(7):
                aa = a0 + (a1 - a0) * t / 6.0
                pts.append((24.0 + math.cos(aa) * 7.0, 18.0 + math.sin(aa) * 7.0))
            pg(d, s, pts)
        b.paint(mask(w, h, sec) * plate, (0.08, 0.07, 0.05), 0.62)
    b.paint(mask(w, h, lambda d, s: el(d, s, 24.0, 18.0, 1.9, 1.9)) * plate,
            (0.08, 0.07, 0.05), 0.66)
    rust = P.clamp01((fbm2(w, h, 5, 4, 2810) - 0.46) * 2.6) * b.a
    b.tint(rust, hx("7A4422"), 0.6)
    b.tint(radial(w, h, 24.0, 58.0, 26.0, 0.9) * (b.a > 0.4), hx("3A3020"), 0.3)


def prop_bunker_door(b: Buf) -> None:
    """Гермодверь бункера: бетонная рама, стальная створка, штурвал."""
    w, h = b.w, b.h
    b.paint(mask(w, h, lambda d, s: rc(d, s, 0.0, 0.0, 64.0, 48.0, 3.0)),
            base_col(CONCRETE, w, h, 2900, 0.16), 0.6, 0.34, 2901)
    b.paint(mask(w, h, lambda d, s: rc(d, s, 18.0, 4.0, 62.0, 48.0, 2.0)),
            base_col(dk(CONCRETE, 0.82), w, h, 2902, 0.14), 0.54)
    door = mask(w, h, lambda d, s: rc(d, s, 5.0, 5.0, 44.0, 45.0, 3.0))
    b.paint(door, base_col(hx("55605A"), w, h, 2903, 0.14), 0.68, 0.3, 2904)
    b.paint(mask(w, h, lambda d, s: rc(d, s, 8.0, 8.0, 41.0, 42.0, 2.0)) * door,
            base_col(dk(hx("55605A"), 1.1), w, h, 2905, 0.12), 0.74)
    for k in range(8):                                   # заклёпки
        xx = 9.0 + (k % 4) * 10.0
        yy = 10.0 if k < 4 else 40.0
        b.paint(mask(w, h, lambda d, s, x=xx, y=yy: el(d, s, x, y, 1.0, 1.0)) * door,
                (0.72, 0.76, 0.72), 0.78)
    b.paint(mask(w, h, lambda d, s: el(d, s, 25.0, 25.0, 7.0, 7.0)) * door,
            base_col(dk(hx("3E4844"), 1.0), w, h, 2906, 0.12), 0.8)
    for k in range(3):                                   # спицы штурвала
        a = k / 3.0 * math.pi
        p = (25.0 + math.cos(a) * 7.5, 25.0 + math.sin(a) * 7.5)
        q = (25.0 - math.cos(a) * 7.5, 25.0 - math.sin(a) * 7.5)
        b.paint(mask(w, h, lambda d, s, a0=p, b0=q: ln(d, s, a0[0], a0[1], b0[0], b0[1], 1.4)) * door,
                base_col(hx("6E7A72"), w, h, 2907 + k, 0.1), 0.84)
    for k in range(4):                                   # петли
        yy = 9.0 + k * 10.0
        b.paint(mask(w, h, lambda d, s, y=yy: rc(d, s, 1.5, y, 6.0, y + 4.0, 0.6)) * door,
                base_col(hx("3A423E"), w, h, 2910 + k, 0.1), 0.8)
    rust = P.clamp01((fbm2(w, h, 5, 4, 2920) - 0.44) * 2.4) * b.a
    b.tint(rust, hx("6E4222"), 0.5)
    b.tint(P.clamp01((fbm2(w, h, 3, 3, 2921) - 0.5) * 2.0) * b.a, hx("2E2A22"), 0.3)


def prop_fence_panel(b: Buf) -> None:
    """Секция забора: столбы и ржавая сетка с дырами."""
    w, h = b.w, b.h
    for xx in (2.0, 90.0):
        b.paint(mask(w, h, lambda d, s, x=xx: rc(d, s, x, 0.0, x + 5.0, 48.0, 1.0)),
                base_col(hx("4E4232"), w, h, int(xx * 13), 0.16), 0.62, 0.3, int(xx))
    b.paint(mask(w, h, lambda d, s: (rc(d, s, 6.0, 6.0, 90.0, 8.5, 0.5),
                                    rc(d, s, 6.0, 40.0, 90.0, 42.5, 0.5))),
            base_col(hx("5A5A52"), w, h, 3000, 0.14), 0.66, 0.24, 3001)
    for k in range(11):                                  # сетка-ромбы
        x0 = 7.0 + k * 7.6
        b.paint(mask(w, h, lambda d, s, x=x0: (ln(d, s, x, 7.0, x + 7.6, 42.0, 0.5),
                                               ln(d, s, x, 42.0, x + 7.6, 7.0, 0.5))),
                base_col(hx("6E6A5E"), w, h, 3010 + k, 0.12), 0.6)
    holes = P.clamp01((fbm2(w, h, 5, 4, 3020) - 0.52) * 3.0)
    band = ((np.arange(h, dtype=np.float32)[:, None] > 6) &
            (np.arange(h, dtype=np.float32)[:, None] < 43)).astype(np.float32)
    b.a = np.where(holes * band > 0.35, b.a * 0.15, b.a)
    rust = P.clamp01((fbm2(w, h, 4, 4, 3021) - 0.4) * 2.4) * b.a
    b.tint(rust, hx("7A4422"), 0.62)
    b.tint(P.clamp01((fbm2(w, h, 8, 3, 3022) - 0.5) * 2.0) * b.a, hx("3A2113"), 0.35)


def prop_pipe_ruin(b: Buf) -> None:
    """Разрушенная труба: два бетонных отрезка с раструбами и арматурой."""
    w, h = b.w, b.h
    for (x0, y0, x1, y1, open_end) in ((8.0, 14.0, 60.0, 32.0, 1), (22.0, 34.0, 76.0, 50.0, 0)):
        body = mask(w, h, lambda d, s, a=(x0, y0), e=(x1, y1): rc(d, s, a[0], a[1], e[0], e[1], 3.0))
        col = base_col(CONCRETE, w, h, int(x0 * 5 + y0), 0.15)
        b.paint(body, col, 0.6, 0.28, int(x0))
        # раструб-утолщение у открытого торца
        ex = x1 - 3.0 if open_end else x0 + 3.0
        b.paint(mask(w, h, lambda d, s, e=(ex, y0, y1): rc(d, s, e[0] - 4.0, e[1] - 1.0,
                                                           e[0] + 4.0, e[2] + 1.0, 2.0)) * body,
                base_col(dk(CONCRETE, 1.08), w, h, int(ex), 0.12), 0.7)
        # тёмное отверстие с бетонным кольцом
        cx = x1 - 2.0 if open_end else x0 + 2.0
        cy = (y0 + y1) * 0.5
        b.paint(mask(w, h, lambda d, s, a=(cx, cy), yy=(y1 - y0) * 0.5:
                     el(d, s, a[0], a[1], 3.6, yy - 1.0)), base_col(hx("241F1A"), w, h, int(cx), 0.1),
                0.4)
        b.paint(mask(w, h, lambda d, s, a=(cx, cy), yy=(y1 - y0) * 0.5:
                     el(d, s, a[0], a[1], 2.4, yy - 2.2)), base_col(hx("120F0C"), w, h, int(cx), 0.1),
                0.34)
        # трещины и потёки
        for k in range(3):
            xx = x0 + 8.0 + k * 14.0
            b.paint(mask(w, h, lambda d, s, x=xx, a=(y0, y1): ln(d, s, x, a[0] + 2.0, x + 3.0,
                                                                a[1] - 1.0, 0.6)) * body,
                    dk(CONCRETE, 0.72), 0.5)
    for k in range(5):                                   # арматура из обломов
        rng = np.random.default_rng(3100 + k)
        side = 1 if k < 3 else -1
        x0 = (60.0 if side > 0 else 22.0) + float(rng.random()) * 6.0
        y0 = (18.0 if side > 0 else 38.0) + float(rng.random()) * 8.0
        b.paint(mask(w, h, lambda d, s, p=(x0, y0), kk=k: ln(d, s, p[0], p[1], p[0] + 9.0 + kk,
                                                            p[1] - 5.0 + kk * 1.8, 0.8)),
                hx("6E5638"), 0.7)
    b.paint(ragg(mask(w, h, lambda d, s: el(d, s, 14.0, 46.0, 8.0, 4.0)), 0.4, 3120) * 0.9,
            base_col(dk(CONCRETE, 0.86), w, h, 3121, 0.16), 0.55, 0.4, 3122)
    b.tint(P.clamp01((fbm2(w, h, 4, 3, 3130) - 0.42) * 2.2) * b.a, hx("4E4A42"), 0.4)
    b.tint(P.clamp01((fbm2(w, h, 7, 3, 3131) - 0.5) * 2.0) * b.a, hx("5A5030"), 0.3)


# ================================================================== АНОМАЛИИ
def build_fx(name: str, n: int, w: int, h: int, fn, desc: str) -> None:
    """Лист FX/аномалии: без шадинга и без normal-map (идёт в аддитивный бленд)."""
    frames = []
    for i in range(n):
        b = Buf(w, h)
        fn(b, i)
        rgba, _ = render(b, shade=False, normal=False, quant=0, rim=0.0, edge_ao=0.0)
        frames.append(rgba)
    save_strip(name, frames, None, desc, fw=w, fh=h)


def anomaly_grav_frame(b: Buf, i: int) -> None:
    """Гравиконцентрат: искажённые кольца-линзы и затягиваемый мусор."""
    w, h = b.w, b.h
    ph = i / 4.0 * math.tau

    def ring_pts(rr, wob, phase):
        pts = []
        for t in range(29):
            a = t / 28.0 * math.tau
            r = rr * (1.0 + math.sin(a * 3 + phase) * wob)
            pts.append((32.0 + math.cos(a) * r, 32.0 + math.sin(a) * r * 0.94))
        return pts

    for k in range(6):
        rr = 6.5 + k * 4.3 + math.sin(ph + k * 1.3) * 1.4
        wob = 0.09 + 0.05 * k
        outer = ring_pts(rr + 2.4, wob, ph * 2.0 + k)
        inner = ring_pts(max(1.5, rr - 2.4), wob, ph * 2.0 + k)
        col = (0.86, 0.80, 1.0) if k % 2 == 0 else (0.62, 0.52, 0.92)
        b.paint(mask(w, h, lambda d, s, p=outer: pg(d, s, p)) * (0.85 - 0.08 * k), col, 0.0)
        b.erase(mask(w, h, lambda d, s, p=inner: pg(d, s, p)))
    b.paint(radial(w, h, 32.0, 32.0, 9.0, 1.0) * 0.55, (0.10, 0.08, 0.14), 0.0)
    for t in range(40):                                  # пыль/мусор по спирали
        rng = np.random.default_rng(3200 + t)
        a = float(rng.random()) * math.tau + ph * 1.4
        r = 4.0 + float(rng.random()) * 25.0
        x = 32.0 + math.cos(a) * r
        y = 32.0 + math.sin(a) * r * 0.94
        sz = 0.5 + float(rng.random()) * 1.0
        col = (0.90, 0.92, 0.98) if t % 4 else (0.66, 0.58, 0.78)
        b.paint(mask(w, h, lambda d, s, xx=x, yy=y, z=sz: el(d, s, xx, yy, z, z)), col, 0.0)
    b.paint(radial(w, h, 32.0, 32.0, 26.0, 1.0) * 0.22, (0.42, 0.36, 0.52), 0.0)


def anomaly_elektra_frame(b: Buf, i: int) -> None:
    """Электра: синие дуги-молнии и голубое свечение."""
    w, h = b.w, b.h
    b.paint(radial(w, h, 32.0, 32.0, 30.0, 1.0) * 0.5, (0.16, 0.34, 0.60), 0.0)
    b.paint(radial(w, h, 32.0, 32.0, 15.0, 1.0) * 0.7, (0.35, 0.60, 0.92), 0.0)
    rng = np.random.default_rng(3300 + i * 17)
    for a_idx in range(7):
        a = float(rng.random()) * math.tau + i * 0.7
        x, y = 32.0, 32.0
        pts = [(x, y)]
        for seg in range(7):
            a += (float(rng.random()) - 0.5) * 0.9
            step = 3.0 + float(rng.random()) * 3.4
            x += math.cos(a) * step
            y += math.sin(a) * step
            pts.append((x, y))
        for wdt, col in ((2.6, (0.30, 0.52, 0.86)), (1.3, ELEC), (0.55, (1.0, 1.0, 1.0))):
            def bolt(d, s, p=pts, ww=wdt):
                for k in range(len(p) - 1):
                    ln(d, s, p[k][0], p[k][1], p[k + 1][0], p[k + 1][1], ww)
            b.paint(mask(w, h, bolt), col, 0.0)
    for k in range(10):                                  # искры-разряды
        rng2 = np.random.default_rng(3350 + i * 31 + k)
        a = float(rng2.random()) * math.tau
        r = 14.0 + float(rng2.random()) * 14.0
        x, y = 32.0 + math.cos(a) * r, 32.0 + math.sin(a) * r
        b.paint(mask(w, h, lambda d, s, xx=x, yy=y: el(d, s, xx, yy, 1.1, 1.1)),
                (0.92, 0.97, 1.0), 0.0)


def anomaly_zharka_frame(b: Buf, i: int) -> None:
    """Жарка: оранжевое пламя, угли и жар у земли."""
    w, h = b.w, b.h
    b.paint(radial(w, h, 32.0, 44.0, 30.0, 1.0) * 0.75, (0.62, 0.16, 0.05), 0.0)
    b.paint(radial(w, h, 32.0, 42.0, 17.0, 1.0) * 0.9, (0.95, 0.42, 0.08), 0.0)
    rng = np.random.default_rng(3400 + i * 13)
    for k in range(9):                                   # языки пламени
        x = 32.0 + (float(rng.random()) - 0.5) * 22.0
        hgt = 10.0 + float(rng.random()) * 24.0
        wd = 3.0 + float(rng.random()) * 5.0
        sway = (float(rng.random()) - 0.5) * 8.0
        def flame(d, s, xx=x, hh=hgt, ww=wd, sw=sway):
            pg(d, s, [(xx - ww, 46.0), (xx - ww * 0.6, 46.0 - hh * 0.55), (xx + sw, 46.0 - hh),
                      (xx + ww * 0.7, 46.0 - hh * 0.5), (xx + ww, 46.0)])
        b.paint(ragg(mask(w, h, flame), 0.4, 3410 + k), FIRE, 0.0)
    for k in range(5):                                   # горячее ядро
        x = 32.0 + (float(rng.random()) - 0.5) * 12.0
        hgt = 8.0 + float(rng.random()) * 14.0
        def core(d, s, xx=x, hh=hgt):
            pg(d, s, [(xx - 2.6, 46.0), (xx, 46.0 - hh), (xx + 2.6, 46.0)])
        b.paint(ragg(mask(w, h, core), 0.35, 3430 + k), FIRE_HOT, 0.0)
    for k in range(18):                                  # угли и искры
        rng2 = np.random.default_rng(3450 + i * 7 + k)
        x = 32.0 + (float(rng2.random()) - 0.5) * 26.0
        y = 46.0 - float(rng2.random()) * 12.0
        b.paint(mask(w, h, lambda d, s, xx=x, yy=y: el(d, s, xx, yy, 0.9, 0.9)),
                FIRE_HOT if k % 3 == 0 else (0.95, 0.45, 0.10), 0.0)
    b.paint(radial(w, h, 32.0, 48.0, 20.0, 0.9) * 0.6, (1.0, 0.75, 0.35), 0.0)


def anomaly_fruit_frame(b: Buf, i: int) -> None:
    """Плод: пульсирующий зелёный плод с венами и спорами."""
    w, h = b.w, b.h
    ph = i / 4.0 * math.tau
    r = 13.0 + math.sin(ph) * 1.6
    body = mask(w, h, lambda d, s, rr=r: (el(d, s, 32.0, 33.0, rr, rr * 0.94),
                                          el(d, s, 25.0, 27.0, rr * 0.5, rr * 0.5),
                                          el(d, s, 39.0, 39.0, rr * 0.55, rr * 0.5)))
    b.paint(body * 0.55, (0.30, 0.48, 0.12), 0.0)
    b.paint(radial(w, h, 32.0, 33.0, 16.0, 1.0) * body, (0.62, 0.78, 0.22), 0.0)
    for k in range(6):                                   # вены
        a0 = k / 6.0 * math.tau + ph * 0.3
        x0 = 32.0 + math.cos(a0) * r * 0.35
        y0 = 33.0 + math.sin(a0) * r * 0.35
        x1 = 32.0 + math.cos(a0 + 0.4) * r * 0.92
        y1 = 33.0 + math.sin(a0 + 0.4) * r * 0.9
        b.paint(mask(w, h, lambda d, s, p=(x0, y0), q=(x1, y1): ln(d, s, p[0], p[1], q[0], q[1],
                                                                  1.0)) * body,
                (0.35, 0.52, 0.14), 0.0)
    b.paint(radial(w, h, 30.0, 30.0, 7.0, 1.0), (0.85, 0.95, 0.45), 0.0)
    for k in range(16):                                  # споры вокруг
        rng = np.random.default_rng(3500 + i * 19 + k)
        a = float(rng.random()) * math.tau
        rr = r * (1.15 + float(rng.random()) * 1.0)
        x = 32.0 + math.cos(a) * rr
        y = 33.0 + math.sin(a) * rr * 0.94
        b.paint(mask(w, h, lambda d, s, xx=x, yy=y: el(d, s, xx, yy, 1.2, 1.2)),
                (0.80, 0.92, 0.36), 0.0)
    b.paint(radial(w, h, 32.0, 33.0, 24.0, 1.0) * 0.45, (0.35, 0.55, 0.12), 0.0)


# ================================================================== FX БОЯ
def muzzle_flash_frame(b: Buf, i: int) -> None:
    """Дульная вспышка: звезда и конус вправо, кадры затухают."""
    w, h = b.w, b.h
    k = (1.0, 0.75, 0.4)[i]
    cx, cy = 14.0, 16.0
    def cone(d, s, kk=k):
        pg(d, s, [(cx, cy - 7.0 * kk), (cx + 30.0 * kk, cy - 3.0 * kk),
                  (cx + 34.0 * kk, cy), (cx + 30.0 * kk, cy + 3.0 * kk),
                  (cx, cy + 7.0 * kk)])
    b.paint(ragg(mask(w, h, cone), 0.3, 3600 + i), (1.0, 0.72, 0.20), 0.0)
    def star(d, s, kk=k):
        for a_ in range(6):
            a = a_ / 6.0 * math.tau
            pg(d, s, [(cx, cy), (cx + math.cos(a - 0.12) * 16.0 * kk,
                                 cy + math.sin(a - 0.12) * 16.0 * kk),
                      (cx + math.cos(a + 0.12) * 16.0 * kk,
                       cy + math.sin(a + 0.12) * 16.0 * kk)])
    b.paint(ragg(mask(w, h, star), 0.25, 3610 + i), (1.0, 0.90, 0.52), 0.0)
    b.paint(radial(w, h, cx, cy, 9.0 * k, 0.95), (1.0, 0.97, 0.86), 0.0)
    b.paint(radial(w, h, cx, cy, 4.0 * k, 1.0), (1.0, 1.0, 1.0), 0.0)


def blood_splat_frame(b: Buf, i: int) -> None:
    """Кровавый всплеск: растёт и затухает, с брызгами."""
    w, h = b.w, b.h
    k = (0.55, 1.0, 0.8)[i]
    rr = 12.0 + 9.0 * k
    rng = np.random.default_rng(3700)
    pts = []
    for t in range(15):
        a = t / 15.0 * math.tau
        pts.append((24.0 + math.cos(a) * rr * (0.75 + float(rng.random()) * 0.5),
                    24.0 + math.sin(a) * rr * (0.75 + float(rng.random()) * 0.5)))
    m = mask(w, h, lambda d, s: pg(d, s, pts))
    b.paint(P.clamp01(m * (1.15 - 0.25 * i)), (0.48, 0.06, 0.05) if i else (0.52, 0.08, 0.06), 0.0)
    b.paint(radial(w, h, 24.0, 24.0, rr * 0.6, 1.0) * (1.0 - 0.3 * i), (0.60, 0.10, 0.07), 0.0)
    for kk in range(14):                                # брызги
        rng2 = np.random.default_rng(3710 + i * 23 + kk)
        a = float(rng2.random()) * math.tau
        r = rr * (1.05 + float(rng2.random()) * 1.1)
        x = 24.0 + math.cos(a) * r
        y = 24.0 + math.sin(a) * r
        s = 0.7 + float(rng2.random()) * 1.4
        b.paint(mask(w, h, lambda d, ss, xx=x, yy=y, z=s: el(d, ss, xx, yy, z, z * 0.85)),
                (0.38, 0.04, 0.03), 0.0)


def spark_frame(b: Buf, i: int) -> None:
    """Искра: четырёхлучевая звёздочка, гаснет."""
    w, h = b.w, b.h
    k = (1.0, 0.8, 0.55, 0.3)[i]
    cx, cy = 8.0, 8.0
    def star(d, s, kk=k):
        for a_ in range(4):
            a = a_ / 4.0 * math.tau + 0.3
            pg(d, s, [(cx, cy), (cx + math.cos(a - 0.18) * 7.0 * kk,
                                 cy + math.sin(a - 0.18) * 7.0 * kk),
                      (cx + math.cos(a + 0.18) * 7.0 * kk,
                       cy + math.sin(a + 0.18) * 7.0 * kk)])
    b.paint(mask(w, h, star), (1.0, 0.86, 0.45), 0.0)
    b.paint(radial(w, h, cx, cy, 4.6 * k, 0.9), (1.0, 0.94, 0.72), 0.0)
    b.paint(radial(w, h, cx, cy, 2.0 * k, 1.0), (1.0, 1.0, 1.0), 0.0)


def smoke_puff_frame(b: Buf, i: int) -> None:
    """Клуб дыма: расширяется, бледнеет, распадается."""
    w, h = b.w, b.h
    k = (0.6, 1.05, 1.55)[i]
    fade = (0.95, 0.7, 0.4)[i]
    blobs = ((18.0, 27.0, 9.0), (30.0, 22.0, 10.5), (24.0, 34.0, 9.5), (35.0, 32.0, 8.0))
    for (bx, by, br) in blobs:
        m = radial(w, h, 24.0 + (bx - 24.0) * k, 28.0 + (by - 28.0) * k, br * k, 0.9)
        n = fbm2(w, h, 5, 4, int(bx * 7 + by + i))
        b.paint(P.clamp01(m * (0.55 + 0.9 * n) * fade), (0.66, 0.65, 0.62), 0.0)
    b.paint(radial(w, h, 24.0, 28.0, 8.0 * k, 1.0) * fade * 0.8, (0.84, 0.83, 0.80), 0.0)
    b.paint(radial(w, h, 24.0, 28.0, 22.0 * k, 1.0) * fade * 0.25, (0.52, 0.52, 0.50), 0.0)


def shockwave_frame(b: Buf, i: int) -> None:
    """Ударная волна: расширяющееся кольцо."""
    w, h = b.w, b.h
    rr = (14.0, 27.0, 42.0)[i]
    thick = (5.0, 4.0, 3.0)[i]
    fade = (1.0, 0.8, 0.5)[i]
    dist = np.sqrt((np.arange(w, dtype=np.float32)[None, :] - 48.0) ** 2 +
                   (np.arange(h, dtype=np.float32)[:, None] - 48.0) ** 2)
    ring = P.clamp01(1.0 - np.abs(dist - rr) / thick)
    b.paint(ragg(ring, 0.25, 3800 + i) * fade, (0.72, 0.86, 1.0), 0.0)
    b.paint(radial(w, h, 48.0, 48.0, rr * 0.75, 1.0) * fade * 0.28, (0.45, 0.66, 0.95), 0.0)


def light_cone_frame(b: Buf, i: int) -> None:
    """Конус фонаря: вершина снизу, светит ВВЕРХ, белый с затуханием по альфе."""
    w, h = b.w, b.h
    ys = np.arange(h, dtype=np.float32)[:, None]
    xs = np.arange(w, dtype=np.float32)[None, :]
    apx, apy = w * 0.5, h - 8.0
    dx = xs - apx
    dy = apy - ys
    dist = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(np.abs(dx), np.maximum(dy, 1.0))
    a_ang = 1.0 - P.smoothstep(0.34, 0.72, ang)
    a_dist = (1.0 - P.smoothstep(60.0, h * 1.05, dist)) * 0.82 + 0.18
    a_top = 1.0 - P.smoothstep(0.0, 26.0, -dy)
    alpha = P.clamp01(a_ang * a_dist * a_top) * 0.85
    # мягкое ядро у вершины
    alpha = P.clamp01(alpha + radial(w, h, apx, apy - 10.0, 22.0, 1.0) * 0.5)
    b.paint(alpha, (1.0, 1.0, 1.0), 0.0)


def soft_shadow_frame(b: Buf, i: int) -> None:
    """Мягкая тень: чёрный радиальный градиент (эллипс)."""
    w, h = b.w, b.h
    ys = (np.arange(h, dtype=np.float32)[:, None] - h * 0.5) / (h * 0.5)
    xs = (np.arange(w, dtype=np.float32)[None, :] - w * 0.5) / (w * 0.5)
    d = np.sqrt(xs * xs + ys * ys)
    alpha = P.clamp01(1.0 - P.smoothstep(0.15, 1.0, d)) ** 1.4 * 0.62
    b.paint(alpha, (0.0, 0.0, 0.0), 0.0)


# ================================================================== РЕЕСТР ВЫВОДОВ
MANIFEST: list = []
STRIPS: list = []
SINGLES: list = []


# ================================================================== СБОРКА АССЕТОВ
def gen_props() -> None:
    make_prop("barrel_rust", 48, 64, prop_barrel_rust,
              "Ржавая бочка: цилиндр, обручи, потёки ржавчины")
    make_prop("barrel_toxic", 48, 64, prop_barrel_toxic,
              "Токсичная бочка: жёлто-зелёная маркировка, знак радиации")
    make_prop("crate_wood", 56, 56, prop_crate_wood,
              "Деревянный ящик: доски, железные уголки, трафарет")
    make_prop("crate_metal", 56, 56, prop_crate_metal,
              "Металлический контейнер: рёбра, заклёпки, ржавчина")
    make_prop("car_wreck", 128, 80, prop_car_wreck,
              "Разбитая машина: кузов, битые стёкла, ржавчина")
    make_prop("bus_wreck", 160, 96, prop_bus_wreck,
              "Сгоревший автобус: ряд окон, выгоревший зад")
    make_prop("tree_dead", 96, 128, prop_tree_dead,
              "Сухое дерево: ствол, ветви-вилки, мох у корней")
    make_prop("tree_pine", 96, 144, prop_tree_pine,
              "Мёртвая ель: ярусы хвои, рыжие ветки")
    make_prop("bush_dry", 64, 48, prop_bush_dry,
              "Сухой куст-перекати-поле")
    make_prop("rock_a", 72, 56, prop_rock_a, "Валун: грани, трещины, мох")
    make_prop("rock_b", 96, 64, prop_rock_b, "Два валуна: большой и малый")
    make_prop("tent", 96, 80, prop_tent, "Палатка: брезент, вход, растяжки")
    make_prop("campfire", 48, 48, prop_campfire,
              "Костровище: камни, головешки, угли и огонь")
    make_prop("power_pole", 32, 128, prop_power_pole,
              "Столб ЛЭП: поперечина, изоляторы, обрывки проводов")
    make_prop("grave", 48, 64, prop_grave, "Могила: покосившийся крест и холмик")
    make_prop("well", 64, 64, prop_well, "Колодец: каменное кольцо, ворот, ведро")
    make_prop("sign_radiation", 48, 64, prop_sign_radiation,
              "Знак радиации: ржавый столб и табличка с трилистником")
    make_prop("bunker_door", 64, 48, prop_bunker_door,
              "Гермодверь бункера: бетонная рама, штурвал, петли")
    make_prop("fence_panel", 96, 48, prop_fence_panel,
              "Секция ржавого забора-сетки с дырами")
    make_prop("pipe_ruin", 80, 48, prop_pipe_ruin,
              "Разрушенная бетонная труба с арматурой")


def gen_anomalies() -> None:
    build_fx("anomaly_grav", 4, 64, 64, anomaly_grav_frame,
             "Гравиконцентрат: искажённые кольца и затянутый мусор")
    build_fx("anomaly_elektra", 4, 64, 64, anomaly_elektra_frame,
             "Электра: синие дуги-молнии и голубое свечение")
    build_fx("anomaly_zharka", 4, 64, 64, anomaly_zharka_frame,
             "Жарка: пламя, угли и жар у земли")
    build_fx("anomaly_fruit", 4, 64, 64, anomaly_fruit_frame,
             "Плод: пульсирующий зелёный плод с венами и спорами")


def gen_fx() -> None:
    build_fx("muzzle_flash", 3, 48, 32, muzzle_flash_frame,
             "Дульная вспышка: звезда и конус, аддитивно")
    build_fx("blood_splat", 3, 48, 48, blood_splat_frame,
             "Кровавый всплеск: растёт и затухает")
    build_fx("spark", 4, 16, 16, spark_frame, "Искра: четырёхлучевая звёздочка")
    build_fx("smoke_puff", 3, 48, 48, smoke_puff_frame,
             "Клуб дыма: расширяется и распадается")
    build_fx("shockwave", 3, 96, 96, shockwave_frame,
             "Ударная волна: расширяющееся кольцо")
    build_fx("light_cone", 1, 256, 256, light_cone_frame,
             "Конус фонаря, светит ВВЕРХ, белый с затуханием альфы")
    build_fx("soft_shadow", 1, 64, 32, soft_shadow_frame,
             "Мягкая тень-эллипс (чёрный радиальный градиент)")


def write_manifest() -> str:
    """MANIFEST.txt — список всего сгенерированного (читает игровой код)."""
    path = os.path.join(SPR, "MANIFEST.txt")
    lines = ["# ЗОНА: Пикник на обочине — спрайты",
             "# Сгенерировано tools/gen/gen_sprites.py (процедурно, детерминированно)",
             "# FORMAT: name | WxH кадра | кадров | normal | описание",
             "# Листы анимации — горизонтальные полосы кадров 64x64;",
             "# якорь «ног» Assets.SHEET_ANCHOR = (32, 58). FX-листы без normal-map.",
             ""]
    for (name, fw, fh, n, has_n, desc) in MANIFEST:
        norm = "n" if has_n else "-"
        lines.append(f"{name} | {fw}x{fh} | {n} | {norm} | {desc}")
    lines.append("")
    lines.append(f"# всего файлов albedo: {len(MANIFEST)}")
    lines.append(f"# нормалей: {sum(1 for m in MANIFEST if m[4])}")
    txt = "\r\n".join(lines) + "\r\n"
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(txt)
    return path

STRIPS: list = []
SINGLES: list = []


def save_strip(name: str, frames, normals, desc: str, fw: int = F, fh: int = F) -> None:
    n = len(frames)
    img = P.atlas_stack(frames, n)
    nrm = P.atlas_stack(normals, n) if normals and all(x is not None for x in normals) else None
    P.save_sprite(name, img, nrm)
    MANIFEST.append((name, fw, fh, n, nrm is not None, desc))
    STRIPS.append((name, frames))


def save_single(name: str, rgba, normal, desc: str, add_sheet: bool = True) -> None:
    P.save_sprite(name, rgba, normal)
    h, w = rgba.shape[0], rgba.shape[1]
    MANIFEST.append((name, w, h, 1, normal is not None, desc))
    if add_sheet:
        SINGLES.append((name, rgba))


def dbg_sheet(items, out_path: str, k: int = 3, cols: int = 8,
              bg=(26, 26, 30, 255), half: bool = False) -> str:
    """Мой контрольный лист: NEAREST-увеличение каждого кадра + подписи.
    half=True — сначала сжать до 50% (масштаб в игре), потом увеличить: тест читаемости."""
    tiles = []
    for label, rgba in items:
        if rgba.shape[2] == 3:
            rgba = np.concatenate([rgba, np.ones(rgba.shape[:2] + (1,), np.float32)], -1)
        im = P.to_image(rgba)
        if half:
            im = im.resize((max(1, im.width // 2), max(1, im.height // 2)), Image.LANCZOS)
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
        tiles.append((label, im))
    cw = max(t.width for _, t in tiles) + 8
    ch = max(t.height for _, t in tiles) + 18
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), bg)
    d = ImageDraw.Draw(sheet)
    for i, (label, t) in enumerate(tiles):
        x, y = (i % cols) * cw, (i // cols) * ch
        sheet.paste(t, (x + 4, y + 16), t)
        d.rectangle([x, y, x + cw - 1, y + ch - 1], outline=(62, 62, 72, 255))
        d.text((x + 5, y + 3), label[:26], fill=(228, 208, 152, 255))
    sheet.convert("RGB").save(out_path)
    return out_path


def frames_of(name: str, from_strip: str) -> list:
    for n, fr in STRIPS:
        if n == from_strip:
            return fr
    return []


# ================================================================== СБОРКА
CHAR_PREFIX = ("stalker", "dog", "mutant", "zombie", "boar")
PROP_NAMES = ("barrel_rust", "barrel_toxic", "crate_wood", "crate_metal", "car_wreck",
              "bus_wreck", "tree_dead", "tree_pine", "bush_dry", "rock_a", "rock_b",
              "tent", "campfire", "power_pole", "grave", "well", "sign_radiation",
              "bunker_door", "fence_panel", "pipe_ruin")
FX_NAMES = ("anomaly_grav", "anomaly_elektra", "anomaly_zharka", "anomaly_fruit",
            "muzzle_flash", "blood_splat", "spark", "smoke_puff", "shockwave",
            "light_cone", "soft_shadow")


def sheet(name: str) -> str:
    return os.path.join(SPR, name + ".png")


def main() -> None:
    P.ensure_dirs()
    os.makedirs(OUT, exist_ok=True)
    gen_stalker()
    gen_zombie()
    gen_dog()
    gen_mutant()
    gen_boar()
    gen_anomalies()
    gen_fx()
    gen_props()
    write_manifest()

    # 1) обязательные контрольные листы
    P.contact_sheet([sheet(n) for n in PROP_NAMES],
                    os.path.join(OUT, "sheet_sprites_props.png"), cell=200, cols=5)
    P.contact_sheet([sheet(n) for n in FX_NAMES],
                    os.path.join(OUT, "sheet_sprites_fx.png"), cell=200, cols=4)

    # 2) мои листы: кадры крупно и «на 50%» (масштаб на экране в игре)
    char_items = [(f"{n}:{i}", f) for n, fr in STRIPS for i, f in enumerate(fr)
                  if n.split("_")[0] in CHAR_PREFIX]
    dbg_sheet(char_items, os.path.join(OUT, "_dbg_char.png"), k=4, cols=8)
    dbg_sheet(char_items, os.path.join(OUT, "_dbg_char_half.png"), k=6, cols=10, half=True)
    prop_items = [(n, s) for (n, s) in SINGLES if n in PROP_NAMES]
    dbg_sheet(prop_items, os.path.join(OUT, "_dbg_props.png"), k=2, cols=5)
    fx_items = [(f"{n}:{i}", f) for n, fr in STRIPS
                if n.startswith("anomaly_") or n in
                ("muzzle_flash", "blood_splat", "spark", "smoke_puff", "shockwave")
                for i, f in enumerate(fr)]
    fx_items += [(n, s) for (n, s) in SINGLES if n in ("light_cone", "soft_shadow")]
    fx_items += [(n, fr[0]) for n, fr in STRIPS if n in ("light_cone", "soft_shadow")]
    dbg_sheet(fx_items, os.path.join(OUT, "_dbg_fx.png"), k=3, cols=6)

    # 3) обязательный лист по персонажам (P.contact_sheet)
    P.contact_sheet([sheet(n) for n in
                     [m[0] for m in MANIFEST if m[0].split("_")[0] in CHAR_PREFIX]],
                    os.path.join(OUT, "sheet_sprites_char.png"), cell=200, cols=4)

    print(f"спрайтов: {len(MANIFEST)} albedo, "
          f"{sum(1 for m in MANIFEST if m[4])} normal; кадров: "
          f"{sum(len(fr) for _, fr in STRIPS)}")


if __name__ == "__main__":
    main()

