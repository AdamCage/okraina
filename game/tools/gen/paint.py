"""paint.py — ядро процедурной генерации ассетов для «ЗОНА: Пикник на обочине».

Только numpy + PIL. Всё, что генерируется, тайлится (seamless), потому что
текстуры идут в TileMapLayer. Итог: albedo PNG + normal-map PNG (пара).

Запуск: это библиотека — сами генераторы лежат рядом и импортируют её:
        cd tools\\gen; python gen_ground.py | gen_sprites.py | gen_ui.py | gen_audio.py
"""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "assets", "textures")
SPR = os.path.join(ROOT, "assets", "sprites")
UI = os.path.join(ROOT, "assets", "ui")
AUD = os.path.join(ROOT, "assets", "audio")


def ensure_dirs() -> None:
    for d in (TEX, SPR, UI, AUD):
        os.makedirs(d, exist_ok=True)


# --------------------------------------------------------------------------- noise
def _smooth(t: np.ndarray) -> np.ndarray:
    return t * t * (3.0 - 2.0 * t)


def value_noise(size: int, res: int, seed: int) -> np.ndarray:
    """Периодический (тайлящийся) value-noise на решётке res x res."""
    res = max(2, int(res))
    g = np.random.default_rng(seed).random((res, res)).astype(np.float32)
    xs = np.linspace(0.0, res, size, endpoint=False)
    i0 = np.floor(xs).astype(np.int64) % res
    i1 = (i0 + 1) % res
    t = _smooth(xs - np.floor(xs))
    g0 = g[i0]
    g1 = g[i1]
    a = g0[:, i0]
    b = g0[:, i1]
    c = g1[:, i0]
    d = g1[:, i1]
    tx = t[None, :]
    ty = t[:, None]
    top = a * (1.0 - tx) + b * tx
    bot = c * (1.0 - tx) + d * tx
    return (top * (1.0 - ty) + bot * ty).astype(np.float32)


def fbm(size: int, res: int = 4, octaves: int = 5, gain: float = 0.5,
        lacunarity: float = 2.0, seed: int = 0) -> np.ndarray:
    out = np.zeros((size, size), np.float32)
    amp, tot, r = 1.0, 0.0, float(res)
    for o in range(octaves):
        out += amp * value_noise(size, int(round(r)), seed + o * 7919)
        tot += amp
        amp *= gain
        r *= lacunarity
    return (out / max(tot, 1e-6)).astype(np.float32)


def warped_fbm(size: int, res: int = 4, octaves: int = 5, seed: int = 0,
               warp: float = 6.0, warp_res: int = 3) -> np.ndarray:
    """fBm с доменным искажением — «живые», неровные структуры."""
    dx = fbm(size, warp_res, 3, seed=seed + 101) - 0.5
    dy = fbm(size, warp_res, 3, seed=seed + 202) - 0.5
    base = fbm(size, res, octaves, seed=seed)
    xi = np.round((np.arange(size, dtype=np.float32)[None, :] + dx * warp)) % size
    yi = np.round((np.arange(size, dtype=np.float32)[:, None] + dy * warp)) % size
    return base[yi.astype(np.int64), xi.astype(np.int64)]


def worley(size: int, cells: int, seed: int, jitter: float = 0.9,
           ret_ids: bool = False):
    """Периодическая мозаика Вороного. Возвращает (f1, f2[, ids])."""
    r = np.random.default_rng(seed)
    pts = r.random((cells, cells, 2)).astype(np.float32)
    px = (np.arange(size, dtype=np.float32) + 0.5) / size * cells
    ys = px
    xs = px
    f1 = np.full((size, size), 9.0, np.float32)
    f2 = np.full((size, size), 9.0, np.float32)
    ids = np.zeros((size, size), np.int32)
    for cy in range(cells):
        for cx in range(cells):
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    gy, gx = (cy + dy) % cells, (cx + dx) % cells
                    ox = (cx + dx) + pts[gy, gx, 0] * jitter
                    oy = (cy + dy) + pts[gy, gx, 1] * jitter
                    dd = (xs[None, :] - ox) ** 2 + (ys[:, None] - oy) ** 2
                    upd = dd < f1
                    f2 = np.where(upd, f1, np.minimum(f2, dd))
                    f1 = np.where(upd, dd, f1)
                    ids = np.where(upd, gy * cells + gx, ids)
    out = (np.sqrt(f1), np.sqrt(f2))
    return (*out, ids) if ret_ids else out


def cracks(size: int, cells: int, seed: int, width: float = 0.06) -> np.ndarray:
    """Маска тонких трещин по рёбрам Вороного (1 = трещина)."""
    f1, f2 = worley(size, cells, seed)
    edge = np.clip(1.0 - (f2 - f1) / max(width, 1e-4), 0.0, 1.0)
    return (edge ** 1.6).astype(np.float32)


def mask_noise(gate: np.ndarray, size: int, res: int, seed: int,
               lo: float, hi: float) -> np.ndarray:
    """Гейт: оставляем структуру только там, где шум в диапазоне [lo, hi]."""
    n = fbm(size, res, 4, seed=seed)
    m = np.clip((n - lo) / max(hi - lo, 1e-4), 0.0, 1.0)
    return (gate * m).astype(np.float32)


def speckle(size: int, count: int, seed: int, radius: float = 1.2,
            radius_x: float = 0.6) -> np.ndarray:
    """Отдельные «крошки»/камешки как маска."""
    r = np.random.default_rng(seed)
    acc = np.zeros((size, size), np.float32)
    ys = r.integers(0, size, count)
    xs = r.integers(0, size, count)
    for x, y in zip(xs, ys):
        acc[int(y), int(x)] = 1.0
    img = Image.fromarray((acc * 255).astype(np.uint8), "L")
    img = img.filter(ImageFilter.GaussianBlur(max(radius, radius_x)))
    return (np.asarray(img, np.float32) / 255.0).astype(np.float32)



# --------------------------------------------------------------------------- math
def clamp01(a: np.ndarray) -> np.ndarray:
    return np.clip(a, 0.0, 1.0)


def norm(a: np.ndarray) -> np.ndarray:
    a = a.astype(np.float32)
    lo, hi = float(a.min()), float(a.max())
    if hi - lo < 1e-6:
        return np.zeros_like(a)
    return ((a - lo) / (hi - lo)).astype(np.float32)


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(edge0, edge1, x):
    t = clamp01((x - edge0) / max(edge1 - edge0, 1e-6))
    return t * t * (3.0 - 2.0 * t)


def curve(x: np.ndarray, gamma: float = 1.0) -> np.ndarray:
    return clamp01(np.sign(x) * np.abs(x) ** gamma)


def gradient(height: np.ndarray):
    dx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    dy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    return dx.astype(np.float32), dy.astype(np.float32)


def gauss(a: np.ndarray, radius: float) -> np.ndarray:
    if radius <= 0:
        return a.astype(np.float32)
    img = Image.fromarray((clamp01(a) * 255).astype(np.uint8), "L")
    out = img.filter(ImageFilter.GaussianBlur(radius))
    return (np.asarray(out, np.float32) / 255.0).astype(np.float32)


# --------------------------------------------------------------------------- compose
def rgb(r: float, g: float, b: float, size: int) -> np.ndarray:
    return np.stack([
        np.full((size, size), r, np.float32),
        np.full((size, size), g, np.float32),
        np.full((size, size), b, np.float32),
    ], -1)


def hexa(s: str) -> tuple:
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def tint_mask(color: np.ndarray, mask: np.ndarray, rgb_col, amount: float = 1.0):
    """Подмешать цвет по маске. mask: [size,size], rgb_col: (r,g,b)."""
    m = clamp01(mask * amount)[..., None]
    c = np.asarray(rgb_col, np.float32)[None, None, :]
    return color * (1.0 - m) + c * m


def over(base: np.ndarray, top: np.ndarray, alpha: np.ndarray):
    """Alpha-over: top накладывается на base с маской alpha."""
    a = clamp01(alpha)[..., None]
    return base * (1.0 - a) + top * a


def bake_shade(color: np.ndarray, height: np.ndarray, light=(-0.5, -0.72),
               strength: float = 1.4, ao: float = 0.55, ao_radius: float = 5.0):
    """Запечь направленный свет + AO в albedo (читаемость даже без лампы)."""
    dx, dy = gradient(height)
    lx, ly = light
    lam = np.clip(1.0 - (dx * lx + dy * ly) * strength, 0.35, 1.65)
    occ = np.clip(1.0 - ao * (1.0 - gauss(height, ao_radius)) * 1.4, 0.45, 1.2)
    if color.ndim == 3:
        return clamp01(color * (lam * occ)[..., None])
    return clamp01(color * lam * occ)


def normal_from_height(height: np.ndarray, strength: float = 3.0) -> np.ndarray:
    dx, dy = gradient(height)
    nz = np.ones_like(height)
    ln = np.sqrt((dx * strength) ** 2 + (dy * strength) ** 2 + nz * nz)
    n = np.stack([(-dx * strength) / ln, (-dy * strength) / ln, nz / ln], -1)
    return clamp01(n * 0.5 + 0.5)


# --------------------------------------------------------------------------- io
def to_image(arr: np.ndarray, mode: str = "RGB") -> Image.Image:
    if arr.ndim == 3:
        if arr.shape[2] == 4:
            return Image.fromarray((clamp01(arr) * 255.0 + 0.5).astype(np.uint8), "RGBA")
        return Image.fromarray((clamp01(arr) * 255.0 + 0.5).astype(np.uint8), "RGB")
    return Image.fromarray((clamp01(arr) * 255.0 + 0.5).astype(np.uint8), mode)


def save_img(img: Image.Image, name: str, folder: str) -> str:
    path = os.path.join(folder, name)
    img.save(path)
    return path


def save_pair(name: str, color: np.ndarray, height: np.ndarray,
              strength: float = 3.0) -> None:
    save_img(to_image(color), name + ".png", TEX)
    save_img(to_image(normal_from_height(height, strength)), name + "_n.png", TEX)


def save_sprite(name: str, rgba: np.ndarray, normal: np.ndarray | None = None) -> None:
    save_img(to_image(rgba), name + ".png", SPR)
    if normal is not None:
        save_img(to_image(normal), name + "_n.png", SPR)


def save_ui(name: str, img: Image.Image) -> None:
    save_img(img, name + ".png", UI)


def atlas_stack(arrs, cols: int) -> np.ndarray:
    """Собрать атлас из одинаковых по размеру numpy-картинок (H,W,C)."""
    h, w = arrs[0].shape[0], arrs[0].shape[1]
    rows = (len(arrs) + cols - 1) // cols
    ch = arrs[0].shape[2] if arrs[0].ndim == 3 else 1
    out = np.zeros((rows * h, cols * w, ch), np.float32)
    for i, a in enumerate(arrs):
        aa = a if a.ndim == 3 else a[..., None]
        r, c = divmod(i, cols)
        out[r * h:r * h + h, c * w:c * w + w] = aa
    return out


def contact_sheet(paths, out_path: str, cell: int = 256, cols: int = 6,
                  bg=(24, 24, 28, 255)) -> str:
    """Контрольный лист для визуальной приёмки."""
    tiles = []
    for p in paths:
        try:
            im = Image.open(p).convert("RGBA")
        except Exception:
            continue
        im.thumbnail((cell, cell), Image.LANCZOS)
        canvas = Image.new("RGBA", (cell, cell), bg)
        canvas.paste(im, ((cell - im.width) // 2, (cell - im.height) // 2), im)
        tiles.append((os.path.basename(p), canvas))
    rows = max((len(tiles) + cols - 1) // cols, 1)
    sheet = Image.new("RGBA", (cols * cell, rows * cell), bg)
    d = ImageDraw.Draw(sheet)
    for i, (name, t) in enumerate(tiles):
        x, y = (i % cols) * cell, (i // cols) * cell
        sheet.paste(t, (x, y), t)
        d.rectangle([x, y, x + cell - 1, y + cell - 1], outline=(70, 70, 80, 255))
        d.text((x + 6, y + 6), name[:30], fill=(220, 200, 150, 255))
    sheet.convert("RGB").save(out_path)
    return out_path
