"""gen_ground.py — атласы ландшафта, стен и декалей (PNG + normal map)."""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image

import paint as P

TILE = 128
GROUND_COLS = 3          # вариантов на материал
DECAL_COLS = 4


def _grain(size, seed, res=96):
    return P.fbm(size, res, 3, seed=seed)


# ------------------------------------------------------------------ материалы
def mat_asphalt(size, seed):
    n = P.warped_fbm(size, 5, 5, seed)
    g = _grain(size, seed + 1)
    patch = P.fbm(size, 3, 3, seed=seed + 2)
    color = P.tint_mask(P.rgb(0.145, 0.150, 0.160, size), P.norm(patch), (0.20, 0.20, 0.21))
    color = color * (0.75 + 0.5 * n)[..., None]
    color = color * (0.88 + 0.24 * g)[..., None]
    cr = P.cracks(size, 5, seed + 3, width=0.055)
    cr2 = P.cracks(size, 11, seed + 4, width=0.035)
    h = 0.62 + (n - 0.5) * 0.12 + (g - 0.5) * 0.05
    f1, _ = P.worley(size, 4, seed + 5)
    hole = P.smoothstep(0.34, 0.16, f1)
    stone = P.speckle(size, 900, seed + 6, 0.7)
    color = P.tint_mask(color, stone, (0.30, 0.29, 0.27), 0.8)          # щебень
    color = P.tint_mask(color, hole, (0.075, 0.075, 0.08), 0.85)        # ямы
    color = P.tint_mask(color, cr, (0.045, 0.045, 0.05), 0.9)
    color = P.tint_mask(color, cr2, (0.055, 0.055, 0.06), 0.7)
    h = h - hole * 0.45 - cr * 0.5 - cr2 * 0.2 + stone * 0.18
    return color, np.clip(h, 0.0, 1.0)


def mat_dirt(size, seed):
    n = P.warped_fbm(size, 5, 5, seed)
    g = _grain(size, seed + 1)
    color = P.rgb(0.180, 0.132, 0.092, size)
    color = color * (0.6 + 0.85 * n)[..., None]
    color = color * (0.88 + 0.22 * g)[..., None]
    pebble = P.speckle(size, 260, seed + 2, 1.4)
    big = P.mask_noise(P.speckle(size, 60, seed + 3, 3.0), size, 6, seed + 4, 0.45, 0.9)
    cr = P.cracks(size, 7, seed + 5, width=0.05)
    color = P.tint_mask(color, pebble, (0.34, 0.30, 0.26), 0.75)
    color = P.tint_mask(color, big, (0.30, 0.27, 0.22), 0.7)
    color = P.tint_mask(color, cr, (0.095, 0.065, 0.045), 0.85)
    h = 0.5 + (n - 0.5) * 0.35 + pebble * 0.22 + big * 0.3 - cr * 0.35
    return color, np.clip(h, 0.0, 1.0)


def mat_grass_dry(size, seed):
    n = P.fbm(size, 4, 4, seed)
    patch = P.fbm(size, 3, 3, seed=seed + 7)
    color = P.rgb(0.168, 0.160, 0.088, size)
    color = color * (0.55 + 0.9 * n)[..., None]
    # «травинки» — анизотропный шум
    blade = np.zeros((size, size), np.float32)
    for o in range(4):
        b = P.value_noise(size, 24 * (o + 1), seed + 11 + o)
        roll = np.roll(b, 3 * (o + 1), axis=0)
        blade += np.abs(b - roll) * (0.6 ** o)
    blade = P.norm(P.gauss(blade, 0.6))
    blades = P.mask_noise(blade, size, 5, seed + 31, 0.25, 0.85)
    color = P.tint_mask(color, blades, (0.42, 0.38, 0.16), 0.85)
    dirt = P.smoothstep(0.55, 0.35, patch)
    color = P.tint_mask(color, dirt, (0.18, 0.13, 0.09), 0.8)
    h = 0.45 + (n - 0.5) * 0.3 + blades * 0.28 + dirt * 0.05
    return color, np.clip(h, 0.0, 1.0)


def mat_grass_toxic(size, seed):
    n = P.warped_fbm(size, 4, 5, seed)
    moss = P.fbm(size, 7, 4, seed=seed + 3)
    color = P.rgb(0.070, 0.115, 0.070, size)
    color = color * (0.55 + 0.95 * n)[..., None]
    color = P.tint_mask(color, P.norm(moss), (0.115, 0.180, 0.085), 0.75)
    spots = P.mask_noise(P.speckle(size, 22, seed + 4, 5.0), size, 6, seed + 5, 0.35, 0.8)
    color = P.tint_mask(color, spots, (0.20, 0.34, 0.13), 0.85)
    puddle = P.smoothstep(0.62, 0.42, P.fbm(size, 3, 3, seed=seed + 9))
    color = P.tint_mask(color, puddle, (0.085, 0.140, 0.095), 0.7)
    h = 0.5 + (n - 0.5) * 0.4 + moss * 0.1 - puddle * 0.15 + spots * 0.25
    return color, np.clip(h, 0.0, 1.0)



def mat_concrete(size, seed):
    f1, f2, ids = P.worley(size, 3, seed, jitter=1.0, ret_ids=True)
    joint = P.smoothstep(0.10, 0.02, f2 - f1)
    n = P.warped_fbm(size, 5, 5, seed + 4)
    g = _grain(size, seed + 5)
    tone = P.norm(P.fbm(size, 6, 2, seed=seed + 6))
    color = P.rgb(0.300, 0.300, 0.285, size) * (0.78 + 0.45 * tone)[..., None]
    color = color * (0.88 + 0.24 * n)[..., None]
    color = color * (0.92 + 0.16 * g)[..., None]
    stain = P.mask_noise(P.fbm(size, 3, 3, seed=seed + 8), size, 4, seed + 9, 0.5, 0.95)
    color = P.tint_mask(color, stain, (0.20, 0.19, 0.17), 0.55)
    cr = P.cracks(size, 9, seed + 10, width=0.04)
    chip = P.speckle(size, 30, seed + 11, 4.0)
    color = P.tint_mask(color, joint, (0.150, 0.148, 0.140), 0.85)
    color = P.tint_mask(color, cr, (0.16, 0.155, 0.15), 0.8)
    color = P.tint_mask(color, chip, (0.38, 0.37, 0.35), 0.6)
    h = 0.62 + (n - 0.5) * 0.14 + g * 0.05 - joint * 0.45 - cr * 0.3 + chip * 0.12
    return color, np.clip(h, 0.0, 1.0)


def mat_gravel(size, seed):
    f1, f2, ids = P.worley(size, 22, seed, jitter=1.05, ret_ids=True)
    small, _ = P.worley(size, 46, seed + 1)
    tone = P.norm((ids % 97).astype(np.float32) + small * 40.0)
    color = P.rgb(0.230, 0.220, 0.205, size) * (0.72 + 0.6 * tone)[..., None]
    dome = 1.0 - P.clamp01(f1 * 3.4)
    color = color * (0.75 + 0.5 * dome)[..., None]
    dusty = P.fbm(size, 6, 3, seed=seed + 5)
    color = P.tint_mask(color, P.norm(dusty), (0.235, 0.215, 0.185), 0.35)
    g = _grain(size, seed + 6)
    color = color * (0.9 + 0.2 * g)[..., None]
    h = 0.42 + dome * 0.5 + (tone - 0.5) * 0.2 + (1.0 - P.clamp01(small * 4.0)) * 0.25
    return color, np.clip(h, 0.0, 1.0)


def mat_mud(size, seed):
    n = P.warped_fbm(size, 4, 5, seed)
    wet = P.fbm(size, 3, 3, seed=seed + 2)
    puddle = P.smoothstep(0.60, 0.40, wet)
    color = P.rgb(0.135, 0.100, 0.070, size) * (0.6 + 0.9 * n)[..., None]
    g = _grain(size, seed + 3)
    color = color * (0.88 + 0.25 * g)[..., None]
    color = P.tint_mask(color, puddle, (0.105, 0.095, 0.085), 0.85)
    ripple = P.norm(P.fbm(size, 8, 3, seed=seed + 4))
    color = P.tint_mask(color, puddle * ripple, (0.165, 0.150, 0.130), 0.5)
    cr = P.cracks(size, 6, seed + 5, width=0.05)
    color = P.tint_mask(color, cr * (1.0 - puddle), (0.085, 0.062, 0.042), 0.8)
    h = 0.55 + (n - 0.5) * 0.4 - puddle * 0.4 + ripple * 0.06 - cr * 0.25
    return color, np.clip(h, 0.0, 1.0)


def mat_metal_floor(size, seed):
    n = P.warped_fbm(size, 6, 4, seed)
    rust = P.mask_noise(P.fbm(size, 4, 4, seed=seed + 2), size, 3, seed + 3, 0.42, 0.9)
    color = P.rgb(0.190, 0.196, 0.205, size) * (0.7 + 0.6 * n)[..., None]
    plate = np.zeros((size, size), np.float32)
    step = size // 4
    for i in range(0, size, step):
        plate[:, i:i + 2] = 1.0
        plate[i:i + 2, :] = 1.0
    rivets = np.zeros((size, size), np.float32)
    yy, xx = np.ogrid[:size, :size]
    for i in range(step // 2, size, step):
        for j in range(step // 2, size, step):
            d = np.sqrt((xx - j) ** 2 + (yy - i) ** 2)
            rivets = np.maximum(rivets, P.smoothstep(6.0, 2.0, d))
    color = P.tint_mask(color, plate, (0.12, 0.12, 0.13), 0.8)
    color = P.tint_mask(color, rivets, (0.30, 0.31, 0.33), 0.9)
    color = P.tint_mask(color, rust, (0.32, 0.15, 0.055), 0.9)
    scrub = P.norm(P.fbm(size, 20, 3, seed=seed + 6))
    color = P.tint_mask(color, scrub, (0.24, 0.22, 0.20), 0.3)
    h = 0.6 + rivets * 0.4 - plate * 0.25 + rust * 0.12 + (n - 0.5) * 0.1
    return color, np.clip(h, 0.0, 1.0)


def mat_bunker_tile(size, seed):
    cell = size // 6
    yy, xx = np.ogrid[:size, :size]
    grout = ((xx % cell < 2) | (yy % cell < 2)).astype(np.float32)
    ids = (xx // cell) * 6 + (yy // cell)
    tone = P.norm((ids % 13).astype(np.float32) + P.fbm(size, 12, 2, seed=seed) * 6.0)
    color = P.rgb(0.325, 0.330, 0.310, size) * (0.75 + 0.45 * tone)[..., None]
    grim = P.mask_noise(P.fbm(size, 4, 4, seed=seed + 2), size, 5, seed + 3, 0.35, 0.95)
    color = P.tint_mask(color, grim, (0.17, 0.16, 0.13), 0.75)
    cr = P.cracks(size, 10, seed + 4, width=0.04)
    missing = P.mask_noise(P.speckle(size, 5, seed + 5, 9.0), size, 6, seed + 6, 0.3, 0.9)
    color = P.tint_mask(color, grout, (0.11, 0.11, 0.10), 0.85)
    color = P.tint_mask(color, cr, (0.19, 0.19, 0.18), 0.7)
    color = P.tint_mask(color, missing, (0.135, 0.128, 0.115), 0.85)
    h = 0.66 + tone * 0.05 - grout * 0.4 - cr * 0.2 - missing * 0.35
    return color, np.clip(h, 0.0, 1.0)



def mat_water_toxic(size, seed):
    n = P.warped_fbm(size, 3, 5, seed)
    ripple = P.norm(P.fbm(size, 10, 3, seed=seed + 2))
    color = P.rgb(0.055, 0.105, 0.075, size) * (0.7 + 0.7 * n)[..., None]
    color = P.tint_mask(color, ripple, (0.115, 0.205, 0.140), 0.7)
    foam = P.mask_noise(P.norm(P.fbm(size, 14, 3, seed=seed + 5)), size, 6, seed + 6, 0.72, 1.0)
    color = P.tint_mask(color, foam, (0.34, 0.42, 0.30), 0.65)
    glow = P.mask_noise(P.speckle(size, 12, seed + 7, 6.0), size, 6, seed + 8, 0.3, 0.9)
    color = P.tint_mask(color, glow, (0.35, 0.62, 0.32), 1.0)
    sludge = P.smoothstep(0.55, 0.80, P.fbm(size, 5, 3, seed=seed + 9))
    color = P.tint_mask(color, sludge, (0.075, 0.085, 0.05), 0.8)
    h = 0.42 + (n - 0.5) * 0.2 + ripple * 0.12 + sludge * 0.35 + glow * 0.1
    return color, np.clip(h, 0.0, 1.0)


def mat_ash(size, seed):
    n = P.warped_fbm(size, 4, 5, seed)
    soot = P.fbm(size, 3, 3, seed=seed + 2)
    color = P.rgb(0.115, 0.113, 0.110, size) * (0.55 + 0.95 * n)[..., None]
    color = P.tint_mask(color, P.norm(soot), (0.16, 0.155, 0.150), 0.7)
    ember = P.mask_noise(P.speckle(size, 26, seed + 4, 2.0), size, 6, seed + 5, 0.25, 0.85)
    color = P.tint_mask(color, ember, (0.62, 0.24, 0.07), 0.85)
    debris = P.speckle(size, 120, seed + 6, 2.4)
    color = P.tint_mask(color, debris, (0.075, 0.070, 0.065), 0.8)
    h = 0.5 + (n - 0.5) * 0.3 + ember * 0.2 + debris * 0.25
    return color, np.clip(h, 0.0, 1.0)


def mat_railbed(size, seed):
    f1, _, ids = P.worley(size, 26, seed, jitter=1.05, ret_ids=True)
    tone = P.norm((ids % 61).astype(np.float32))
    color = P.rgb(0.150, 0.145, 0.135, size) * (0.7 + 0.6 * tone)[..., None]
    dome = 1.0 - P.clamp01(f1 * 3.0)
    color = color * (0.75 + 0.5 * dome)[..., None]
    sleeper = np.zeros((size, size), np.float32)
    for i in range(0, size, size // 2):
        sleeper[i + 6:i + 26, :] = 1.0
    wood = P.norm(P.fbm(size, 22, 3, seed=seed + 3))
    color = P.tint_mask(color, sleeper, (0.125, 0.092, 0.062), 0.85)
    color = color * (0.85 + 0.30 * wood)[..., None]
    rust = np.zeros((size, size), np.float32)
    rust[:, size // 2 - 14:size // 2 - 6] = 1.0
    rust[:, size // 2 + 6:size // 2 + 14] = 1.0
    color = P.tint_mask(color, rust, (0.28, 0.155, 0.075), 0.9)
    h = 0.45 + dome * 0.45 + sleeper * 0.3 + rust * 0.22
    return color, np.clip(h, 0.0, 1.0)


GROUND_MATS = [
    ("asphalt", mat_asphalt),
    ("dirt", mat_dirt),
    ("grass_dry", mat_grass_dry),
    ("grass_toxic", mat_grass_toxic),
    ("concrete", mat_concrete),
    ("gravel", mat_gravel),
    ("mud", mat_mud),
    ("metal_floor", mat_metal_floor),
    ("bunker_tile", mat_bunker_tile),
    ("water_toxic", mat_water_toxic),
    ("ash", mat_ash),
    ("railbed", mat_railbed),
]


# ------------------------------------------------------------------ стены
def _wall_block(color, height, alpha=None, edge=0.30):
    """Придать тайлу стен «объём»: блик сверху, тень снизу, AO по краям."""
    size = height.shape[0]
    yy = np.arange(size, dtype=np.float32)[:, None] / size
    xx = np.arange(size, dtype=np.float32)[None, :] / size
    top = P.smoothstep(0.16, 0.0, yy)
    bot = P.smoothstep(0.80, 1.0, yy)
    left = P.smoothstep(0.14, 0.0, xx)
    right = P.smoothstep(0.86, 1.0, xx)
    rim = np.maximum(np.maximum(top, bot), np.maximum(left, right))
    lit = 1.0 + top * edge * 0.9 + left * edge * 0.5
    dark = 1.0 - bot * edge * 1.5 - right * edge * 0.9
    occ = 1.0 - rim * 0.35
    c = P.bake_shade(color, height)
    c = P.clamp01(c * (lit * dark * occ)[..., None])
    h = P.clamp01(height + top * 0.25 - bot * 0.2)
    if alpha is None:
        return c, h
    return c, h, alpha


def wall_concrete(size, seed):
    n = P.warped_fbm(size, 5, 5, seed)
    g = _grain(size, seed + 1)
    bh, bw = size // 5, size // 3
    brick = np.zeros((size, size), np.float32)
    for r in range(5):
        brick[r * bh:r * bh + bh, :] = 1.0
    brick = 1.0 - brick
    brick = P.gauss(brick, 0.8)
    tone = P.norm(P.fbm(size, 8, 3, seed=seed + 2))
    color = P.rgb(0.315, 0.310, 0.292, size) * (0.72 + 0.5 * tone)[..., None]
    color = color * (0.86 + 0.28 * n)[..., None]
    color = color * (0.92 + 0.16 * g)[..., None]
    joint = P.smoothstep(0.15, 0.55, brick)
    stain = P.mask_noise(P.fbm(size, 3, 3, seed=seed + 5), size, 4, seed + 6, 0.45, 0.95)
    color = P.tint_mask(color, stain, (0.19, 0.18, 0.16), 0.65)
    color = P.tint_mask(color, joint, (0.155, 0.150, 0.140), 0.9)
    cr = P.cracks(size, 8, seed + 7, width=0.04)
    color = P.tint_mask(color, cr, (0.15, 0.145, 0.14), 0.75)
    h = 0.60 + (n - 0.5) * 0.16 - joint * 0.5 - cr * 0.25 + g * 0.05
    return _wall_block(color, np.clip(h, 0, 1))


def wall_brick(size, seed):
    bh, bw = size // 6, size // 3
    brick = np.zeros((size, size), np.float32)
    for r in range(6):
        off = (bw // 2) if r % 2 else 0
        brick[r * bh + 3:r * bh + bh - 3, (off + 3):(size - 3)] = 1.0
        if off:
            brick[r * bh + 3:r * bh + bh - 3, 0:bw // 2 - 3] = 1.0
    tone = P.norm(P.fbm(size, 10, 3, seed=seed + 2))
    color = P.rgb(0.280, 0.150, 0.110, size) * (0.7 + 0.6 * tone)[..., None]
    mortar = 1.0 - brick
    color = P.tint_mask(color, mortar, (0.255, 0.245, 0.230), 0.92)
    n = P.warped_fbm(size, 6, 4, seed + 3)
    color = color * (0.8 + 0.4 * n)[..., None]
    soot = P.mask_noise(P.fbm(size, 3, 3, seed=seed + 4), size, 4, seed + 5, 0.4, 0.95)
    color = P.tint_mask(color, soot, (0.115, 0.100, 0.090), 0.7)
    cr = P.cracks(size, 9, seed + 6, width=0.045)
    color = P.tint_mask(color, cr, (0.13, 0.10, 0.08), 0.8)
    h = 0.62 + brick * 0.2 + (n - 0.5) * 0.12 - cr * 0.3
    return _wall_block(color, np.clip(h, 0, 1))



def wall_plaster(size, seed):
    n = P.warped_fbm(size, 5, 5, seed)
    flake = P.mask_noise(P.fbm(size, 7, 4, seed=seed + 2), size, 5, seed + 3, 0.45, 0.85)
    color = P.rgb(0.320, 0.300, 0.245, size) * (0.7 + 0.6 * n)[..., None]
    g = _grain(size, seed + 4)
    color = color * (0.88 + 0.22 * g)[..., None]
    color = P.tint_mask(color, flake, (0.185, 0.150, 0.115), 0.92)   # сбитая штукатурка
    stain = P.mask_noise(P.fbm(size, 3, 3, seed=seed + 5), size, 4, seed + 6, 0.4, 0.95)
    color = P.tint_mask(color, stain, (0.20, 0.185, 0.15), 0.6)
    green = P.mask_noise(P.fbm(size, 5, 3, seed=seed + 7), size, 6, seed + 8, 0.5, 0.9)
    color = P.tint_mask(color, green, (0.10, 0.14, 0.08), 0.3)
    cr = P.cracks(size, 7, seed + 9, width=0.05)
    color = P.tint_mask(color, cr, (0.145, 0.128, 0.11), 0.8)
    h = 0.60 + (n - 0.5) * 0.2 - flake * 0.3 - cr * 0.3 + g * 0.04
    return _wall_block(color, np.clip(h, 0, 1))


def wall_metal(size, seed):
    n = P.warped_fbm(size, 7, 4, seed)
    rust = P.mask_noise(P.fbm(size, 4, 5, seed=seed + 2), size, 3, seed + 3, 0.35, 0.9)
    color = P.rgb(0.205, 0.208, 0.215, size) * (0.7 + 0.6 * n)[..., None]
    seams = np.zeros((size, size), np.float32)
    seams[:, size // 2 - 2:size // 2 + 2] = 1.0
    color = P.tint_mask(color, rust, (0.335, 0.150, 0.050), 0.92)
    color = P.tint_mask(color, seams, (0.11, 0.11, 0.12), 0.8)
    sc = P.mask_noise(P.norm(P.fbm(size, 30, 3, seed=seed + 6)), size, 8, seed + 7, 0.7, 1.0)
    color = P.tint_mask(color, sc, (0.33, 0.34, 0.36), 0.5)
    h = 0.62 + rust * 0.16 - seams * 0.3 + (n - 0.5) * 0.12
    return _wall_block(color, np.clip(h, 0, 1))


def wall_container(size, seed):
    n = P.fbm(size, 8, 3, seed)
    rib = np.zeros((size, size), np.float32)
    period = size // 8
    for i in range(0, size, period):
        rib[:, i:i + period // 2] = 1.0
    rib = P.gauss(rib, 1.5)
    rust = P.mask_noise(P.fbm(size, 4, 4, seed=seed + 2), size, 3, seed + 3, 0.3, 0.85)
    color = P.rgb(0.24, 0.115, 0.09, size) * (0.7 + 0.65 * n)[..., None]
    color = color * (0.72 + 0.55 * rib)[..., None]
    color = P.tint_mask(color, rust, (0.32, 0.155, 0.06), 0.9)
    stain = P.mask_noise(P.fbm(size, 5, 3, seed=seed + 5), size, 4, seed + 6, 0.5, 0.95)
    color = P.tint_mask(color, stain, (0.13, 0.09, 0.06), 0.6)
    h = 0.55 + rib * 0.45 + (n - 0.5) * 0.1 + rust * 0.12
    return _wall_block(color, np.clip(h, 0, 1), edge=0.34)


def wall_wood(size, seed):
    planks = np.zeros((size, size), np.float32)
    pw = size // 4
    for i in range(0, size, pw):
        planks[:, i:i + 2] = 1.0
    grainv = np.zeros((size, size), np.float32)
    for o in range(5):
        b = P.value_noise(size, 8 * (o + 1), seed + 20 + o)
        grainv += np.abs(b - np.roll(b, 5 * (o + 1), axis=0)) * (0.65 ** o)
    grainv = P.norm(P.gauss(grainv, 0.5))
    tone = P.norm(P.fbm(size, 6, 2, seed=seed + 3))
    color = P.rgb(0.230, 0.160, 0.095, size) * (0.7 + 0.6 * tone)[..., None]
    color = P.tint_mask(color, grainv, (0.155, 0.105, 0.062), 0.7)
    color = P.tint_mask(color, 1.0 - planks, (0.42, 0.32, 0.20), 0.3)
    color = P.tint_mask(color, planks, (0.09, 0.06, 0.035), 0.85)
    rot = P.mask_noise(P.fbm(size, 4, 4, seed=seed + 6), size, 3, seed + 7, 0.4, 0.9)
    color = P.tint_mask(color, rot, (0.075, 0.075, 0.055), 0.8)
    h = 0.60 - planks * 0.35 + grainv * 0.08 + (tone - 0.5) * 0.1 - rot * 0.2
    return _wall_block(color, np.clip(h, 0, 1))


def wall_bunker(size, seed):
    n = P.warped_fbm(size, 6, 4, seed)
    panel = np.zeros((size, size), np.float32)
    panel[size // 2 - 2:size // 2 + 2, :] = 1.0
    panel[:, size // 2 - 2:size // 2 + 2] = 1.0
    bolts = np.zeros((size, size), np.float32)
    yy, xx = np.ogrid[:size, :size]
    for j in (size // 4, 3 * size // 4):
        for i in (size // 4, 3 * size // 4):
            d = np.sqrt((xx - j) ** 2 + (yy - i) ** 2)
            bolts = np.maximum(bolts, P.smoothstep(7.0, 2.5, d))
    color = P.rgb(0.265, 0.268, 0.258, size) * (0.75 + 0.5 * n)[..., None]
    g = _grain(size, seed + 4)
    color = color * (0.9 + 0.2 * g)[..., None]
    color = P.tint_mask(color, panel, (0.145, 0.145, 0.14), 0.85)
    color = P.tint_mask(color, bolts, (0.31, 0.31, 0.30), 0.9)
    grime = P.mask_noise(P.fbm(size, 3, 3, seed=seed + 5), size, 4, seed + 6, 0.4, 0.95)
    color = P.tint_mask(color, grime, (0.15, 0.155, 0.13), 0.6)
    h = 0.66 + bolts * 0.3 - panel * 0.28 + (n - 0.5) * 0.12
    return _wall_block(color, np.clip(h, 0, 1), edge=0.26)



def wall_tiles(size, seed):
    cell = size // 8
    yy, xx = np.ogrid[:size, :size]
    grout = ((xx % cell < 2) | (yy % cell < 2)).astype(np.float32)
    tone = P.norm((((xx // cell) * 8 + (yy // cell)) % 17).astype(np.float32))
    color = P.rgb(0.330, 0.335, 0.315, size) * (0.78 + 0.4 * tone)[..., None]
    grim = P.mask_noise(P.fbm(size, 4, 4, seed=seed + 2), size, 5, seed + 3, 0.35, 0.95)
    color = P.tint_mask(color, grim, (0.16, 0.15, 0.12), 0.8)
    missing = P.mask_noise(P.speckle(size, 8, seed + 4, 10.0), size, 5, seed + 5, 0.3, 0.9)
    color = P.tint_mask(color, missing, (0.20, 0.19, 0.17), 0.9)
    color = P.tint_mask(color, grout, (0.115, 0.115, 0.105), 0.9)
    cr = P.cracks(size, 11, seed + 6, width=0.035)
    color = P.tint_mask(color, cr, (0.18, 0.18, 0.17), 0.7)
    h = 0.68 - grout * 0.42 - cr * 0.2 - missing * 0.3 + tone * 0.04
    return _wall_block(color, np.clip(h, 0, 1), edge=0.24)


def wall_fence(size, seed):
    yy, xx = np.ogrid[:size, :size]
    cell = size // 8
    diag = np.maximum(((xx + yy) % cell < 2).astype(np.float32),
                      ((xx - yy) % cell < 2).astype(np.float32))
    diag = P.gauss(diag.astype(np.float32), 0.7)
    rust = P.mask_noise(P.fbm(size, 6, 4, seed=seed), size, 4, seed + 1, 0.3, 0.9)
    color = P.rgb(0.28, 0.27, 0.25, size) * (0.7 + 0.6 * rust)[..., None]
    color = P.tint_mask(color, rust, (0.30, 0.15, 0.07), 0.85)
    post = np.zeros((size, size), np.float32)
    post[:, size // 2 - 7:size // 2 + 7] = 1.0
    post[size // 2 - 7:size // 2 + 7, :] = 1.0
    color = P.tint_mask(color, post, (0.14, 0.13, 0.12), 0.9)
    alpha = np.clip(diag * 1.6 + post, 0.0, 1.0)
    h = 0.5 + diag * 0.4 + post * 0.5
    return _wall_block(color, np.clip(h, 0, 1), alpha)


def wall_rubble(size, seed):
    f1, f2, ids = P.worley(size, 6, seed, jitter=1.0, ret_ids=True)
    tone = P.norm((ids % 43).astype(np.float32) + P.fbm(size, 10, 3, seed=seed + 1))
    mixed = P.fbm(size, 4, 3, seed=seed + 2)
    col_a = P.rgb(0.300, 0.295, 0.280, size) * (0.7 + 0.55 * tone)[..., None]   # бетон
    col_b = P.rgb(0.280, 0.150, 0.110, size) * (0.7 + 0.55 * tone)[..., None]   # кирпич
    mix = P.smoothstep(0.42, 0.62, mixed)[..., None]
    color = col_a * (1.0 - mix) + col_b * mix
    dome = 1.0 - P.clamp01(f1 * 2.6)
    color = color * (0.65 + 0.7 * dome)[..., None]
    rubble = P.smoothstep(0.62, 0.42, mixed)
    color = P.tint_mask(color, rubble, (0.135, 0.128, 0.118), 0.7)
    h = 0.35 + dome * 0.65
    return _wall_block(color, np.clip(h, 0, 1), edge=0.2)


WALL_STYLES = [
    ("concrete", wall_concrete),
    ("brick", wall_brick),
    ("plaster", wall_plaster),
    ("metal", wall_metal),
    ("container", wall_container),
    ("wood", wall_wood),
    ("bunker", wall_bunker),
    ("tiles", wall_tiles),
    ("fence", wall_fence),
    ("rubble", wall_rubble),
]
WALL_COLS = 2


# ------------------------------------------------------------------ декали
def _win(size, inner=0.7):
    a = np.abs(np.arange(size, dtype=np.float32) / (size - 1) - 0.5) * 2.0
    wx = P.smoothstep(1.0, inner, a)
    return np.minimum(wx[:, None], wx[None, :])


def _dots(size, seed, count, rmin, rmax, blur=1.0, alpha=1.0, path=None):
    from PIL import Image as _I, ImageDraw as _D, ImageFilter as _F
    r = np.random.default_rng(seed)
    im = _I.new("L", (size, size), 0)
    d = _D.Draw(im)
    for _ in range(count):
        x, y = float(r.uniform(-4, size + 4)), float(r.uniform(-4, size + 4))
        rad = float(r.uniform(rmin, rmax))
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=255)
    if path is not None:
        d.line(path, fill=255, width=int(max(1, rmin)))
    if blur > 0:
        im = im.filter(_F.GaussianBlur(blur))
    return np.asarray(im, np.float32) / 255.0 * alpha


def _blob(size, seed, res=3, thr=0.5, soft=0.12):
    return P.smoothstep(thr, thr + soft, P.warped_fbm(size, res, 4, seed))


def _rgba(color, height, mask):
    if np.isscalar(height):
        height = np.full(mask.shape, float(height), np.float32)
    c = P.bake_shade(color, height, ao=0.5, ao_radius=3)
    return np.concatenate([c, P.clamp01(mask)[..., None]], -1)


def dec_crack(size, seed):
    m = P.cracks(size, 3, seed, width=0.075) * _win(size, 0.6)
    m = P.clamp01(m * 1.6)
    col = P.rgb(0.075, 0.072, 0.070, size)
    return _rgba(col, 0.6 - m * 0.55, m)


def dec_crack_big(size, seed):
    m = P.cracks(size, 7, seed, width=0.05) * _win(size, 0.6)
    m = P.clamp01(m * 1.7)
    col = P.rgb(0.085, 0.082, 0.078, size) * (0.8 + 0.4 * P.norm(P.fbm(size, 12, 3, seed=seed + 1)))[..., None]
    return _rgba(col, 0.6 - m * 0.5, m)


def dec_rubble(size, seed):
    f1, _, ids = P.worley(size, 9, seed, jitter=1.0, ret_ids=True)
    tone = P.norm((ids % 31).astype(np.float32))
    dome = 1.0 - P.clamp01(f1 * 2.2)
    mask = P.clamp01(P.smoothstep(0.55, 0.2, f1) * _win(size, 0.85))
    mix = P.smoothstep(0.4, 0.7, P.fbm(size, 4, 3, seed=seed + 3))[..., None]
    ca = P.rgb(0.31, 0.30, 0.285, size) * (0.7 + 0.5 * tone)[..., None]
    cb = P.rgb(0.29, 0.15, 0.11, size) * (0.7 + 0.5 * tone)[..., None]
    col = ca * (1 - mix) + cb * mix
    col = P.tint_mask(col, P.speckle(size, 200, seed + 5, 1.2), (0.175, 0.17, 0.16), 0.7)
    return _rgba(col, 0.25 + dome * 0.7, mask)


def dec_moss(size, seed):
    n = P.warped_fbm(size, 6, 4, seed)
    mask = P.clamp01(_blob(size, seed, 4, 0.48, 0.16) * _win(size, 0.75))
    mask = mask * (0.5 + 0.7 * n)
    col = P.rgb(0.085, 0.135, 0.075, size) * (0.6 + 0.8 * n)[..., None]
    col = P.tint_mask(col, P.speckle(size, 90, seed + 2, 2.0), (0.13, 0.19, 0.10), 0.6)
    return _rgba(col, 0.45 + n * 0.35, P.clamp01(mask * 1.4))


def dec_puddle(size, seed):
    mask = P.clamp01(_blob(size, seed, 3, 0.46, 0.10) * _win(size, 0.8))
    ripple = P.norm(P.fbm(size, 9, 3, seed=seed + 2))
    col = P.rgb(0.075, 0.070, 0.062, size) * (0.7 + 0.5 * ripple)[..., None]
    col = P.tint_mask(col, P.smoothstep(0.75, 1.0, ripple) * mask, (0.16, 0.15, 0.14), 0.5)
    return _rgba(col, 0.75 - ripple * 0.06, mask * 0.92)


def dec_puddle_toxic(size, seed):
    mask = P.clamp01(_blob(size, seed, 3, 0.45, 0.10) * _win(size, 0.8))
    ripple = P.norm(P.fbm(size, 9, 3, seed=seed + 2))
    col = P.rgb(0.075, 0.135, 0.090, size) * (0.7 + 0.6 * ripple)[..., None]
    glow = P.mask_noise(P.speckle(size, 10, seed + 4, 6.0), size, 6, seed + 5, 0.3, 0.9) * mask
    col = P.tint_mask(col, glow, (0.32, 0.58, 0.30), 1.0)
    col = P.tint_mask(col, P.smoothstep(0.8, 1.0, ripple) * mask, (0.36, 0.45, 0.32), 0.5)
    return _rgba(col, 0.75 - ripple * 0.06, mask * 0.95)


def dec_blood(size, seed):
    main = _blob(size, seed, 3, 0.5, 0.1)
    drops = _dots(size, seed + 1, 46, 1.0, 5.0, blur=0.8)
    mask = P.clamp01((main * 0.9 + drops * 0.9) * _win(size, 0.72))
    wet = P.norm(_blob(size, seed + 4, 5, 0.45, 0.1))
    col = P.rgb(0.30, 0.032, 0.028, size) * (0.65 + 0.5 * wet)[..., None]
    col = P.tint_mask(col, P.smoothstep(0.7, 1.0, wet) * mask, (0.48, 0.06, 0.05), 0.7)
    return _rgba(col, 0.55 + main * 0.2, mask)


def dec_blood_smear(size, seed):
    streak = _dots(size, seed, 1, 3.0, 3.0, blur=0.0,
                   path=[(18, 14), (46, 40), (74, 76), (108, 116)])
    streak = P.gauss(streak, 2.2)
    drops = _dots(size, seed + 2, 30, 1.0, 4.0, blur=0.8)
    mask = P.clamp01((streak * 1.2 + drops) * _win(size, 0.8))
    wet = P.norm(_blob(size, seed + 3, 5, 0.45, 0.1))
    col = P.rgb(0.255, 0.030, 0.026, size) * (0.7 + 0.4 * wet)[..., None]
    return _rgba(col, 0.55 + streak * 0.15, mask)


def dec_blood_pool(size, seed):
    pool = P.clamp01(_blob(size, seed, 2, 0.42, 0.09) * _win(size, 0.9))
    dry = P.cracks(size, 5, seed + 3, width=0.05)
    col = P.rgb(0.150, 0.040, 0.030, size)
    col = P.tint_mask(col, dry * pool, (0.075, 0.030, 0.024), 0.8)
    col = P.tint_mask(col, P.smoothstep(0.65, 1.0, P.norm(_blob(size, seed + 5, 6, 0.4, 0.1))) * pool,
                      (0.24, 0.03, 0.025), 0.6)
    return _rgba(col, np.full_like(pool, 0.7), pool)


def dec_scorch(size, seed):
    m = P.clamp01(_blob(size, seed, 4, 0.42, 0.16) * _win(size, 0.85))
    soot = P.clamp01(P.fbm(size, 3, 3, seed=seed + 2) * 1.2 - 0.15)
    col = P.rgb(0.055, 0.052, 0.050, size) * (0.6 + 0.7 * soot)[..., None]
    col = P.tint_mask(col, soot, (0.035, 0.033, 0.032), 0.7)
    return _rgba(col, 0.7, m * 0.95)


def dec_tire(size, seed):
    yy, xx = np.ogrid[:size, :size]
    bands = np.zeros((size, size), np.float32)
    for cx in (size // 3, 2 * size // 3):
        bands = np.maximum(bands, P.smoothstep(16.0, 9.0, np.abs(xx - cx).astype(np.float32)))
    tread = ((yy // 7) % 2).astype(np.float32)
    m = P.clamp01(bands * 0.85 * _win(size, 0.9))
    col = P.rgb(0.105, 0.100, 0.095, size)
    col = P.tint_mask(col, tread * bands, (0.055, 0.052, 0.05), 0.6)
    return _rgba(col, 0.7, m)



def dec_bones(size, seed):
    from PIL import Image as _I, ImageDraw as _D, ImageFilter as _F
    m = _I.new("L", (size, size), 0)
    d = _D.Draw(m)
    r = np.random.default_rng(seed)
    d.ellipse([52, 46, 76, 70], fill=235)                    # череп
    for i in range(4):
        y = 78 + i * 9
        w = int(r.uniform(20, 34))
        d.line([(58 - w // 2, y), (58 + w // 2, y + int(r.uniform(-3, 3)))], fill=200, width=4)
    d.line([(84, 96), (112, 118)], fill=190, width=5)         # кость
    d.ellipse([104, 110, 118, 124], fill=210)
    m = m.filter(_F.GaussianBlur(0.7))
    mask = P.clamp01(np.asarray(m, np.float32) / 255.0 * _win(size, 0.95))
    tex = P.norm(P.fbm(size, 20, 3, seed=seed + 2))
    col = P.rgb(0.60, 0.58, 0.50, size) * (0.7 + 0.5 * tex)[..., None]
    col = P.tint_mask(col, P.smoothstep(0.7, 0.4, tex), (0.30, 0.27, 0.20), 0.6)
    return _rgba(col, 0.35 + mask * 0.5, mask)


def dec_bullets(size, seed):
    m = _dots(size, seed, 16, 2.0, 5.5, blur=0.5)
    ring = P.clamp01(m - _dots(size, seed + 1, 16, 1.0, 3.0, blur=0.5))
    mask = P.clamp01(m * _win(size, 0.9))
    col = P.rgb(0.09, 0.085, 0.08, size)
    col = P.tint_mask(col, ring, (0.32, 0.30, 0.28), 0.6)
    return _rgba(col, 0.7 - m * 0.5, mask)


def dec_oil(size, seed):
    mask = P.clamp01(_blob(size, seed, 3, 0.45, 0.12) * _win(size, 0.8))
    sheen = P.norm(P.fbm(size, 7, 3, seed=seed + 3))
    col = P.rgb(0.050, 0.048, 0.055, size) * (0.7 + 0.5 * sheen)[..., None]
    col = P.tint_mask(col, P.smoothstep(0.72, 1.0, sheen) * mask, (0.14, 0.10, 0.16), 0.55)
    return _rgba(col, 0.72, mask * 0.92)


def dec_leaves(size, seed):
    from PIL import Image as _I, ImageDraw as _D, ImageFilter as _F
    m = _I.new("L", (size, size), 0)
    d = _D.Draw(m)
    r = np.random.default_rng(seed)
    for _ in range(26):
        x, y = float(r.uniform(6, size - 6)), float(r.uniform(6, size - 6))
        a = float(r.uniform(0, 3.14))
        ln, wd = float(r.uniform(7, 15)), float(r.uniform(3, 6))
        pts = []
        for t in np.linspace(0, 1, 7):
            off = math.sin(t * math.pi) * wd
            pts.append((x + math.cos(a) * (t - 0.5) * ln * 2 - math.sin(a) * off * 0.5,
                        y + math.sin(a) * (t - 0.5) * ln * 2 + math.cos(a) * off * 0.5))
        pts += [(2 * x - px, 2 * y - py) for px, py in reversed(pts)]
        d.polygon(pts, fill=int(r.uniform(160, 245)))
    m = m.filter(_F.GaussianBlur(0.6))
    raw = np.asarray(m, np.float32) / 255.0
    mask = raw * _win(size, 0.92)
    tone = P.norm(raw * 3.0 + P.fbm(size, 20, 3, seed=seed + 6))
    ca = P.rgb(0.30, 0.24, 0.075, size) * tone[..., None]
    cb = P.rgb(0.22, 0.13, 0.055, size) * (1.0 - tone)[..., None]
    return _rgba(ca + cb, 0.4 + raw * 0.35, P.clamp01(mask * 1.5))


def dec_tuft(size, seed):
    from PIL import Image as _I, ImageDraw as _D, ImageFilter as _F
    alpha = _I.new("L", (size, size), 0)
    d = _D.Draw(alpha)
    r = np.random.default_rng(seed)
    for _ in range(7):
        cx, cy = float(r.uniform(20, size - 20)), float(r.uniform(size * 0.45, size - 14))
        for _ in range(26):
            a = float(r.uniform(-1.25, 1.25))
            ln = float(r.uniform(14, 34))
            d.line([(cx, cy), (cx + math.sin(a) * ln, cy - math.cos(a) * ln)],
                   fill=int(r.uniform(120, 255)), width=1)
    alpha = alpha.filter(_F.GaussianBlur(0.5))
    mask = np.asarray(alpha, np.float32) / 255.0
    tone = P.norm(P.fbm(size, 22, 3, seed=seed + 4))
    ca = P.rgb(0.30, 0.28, 0.10, size) * (1.0 - tone)[..., None]
    cb = P.rgb(0.42, 0.38, 0.16, size) * tone[..., None]
    col = ca + cb
    col = P.tint_mask(col, P.smoothstep(0.3, 0.0, mask), (0.12, 0.11, 0.05), 0.6)
    return _rgba(col, 0.35 + mask * 0.4, P.clamp01(mask * 1.4))


DECALS = [
    ("crack", dec_crack),
    ("crack_big", dec_crack_big),
    ("rubble", dec_rubble),
    ("moss", dec_moss),
    ("puddle", dec_puddle),
    ("puddle_toxic", dec_puddle_toxic),
    ("blood_a", dec_blood),
    ("blood_b", dec_blood_smear),
    ("blood_c", dec_blood_pool),
    ("scorch", dec_scorch),
    ("tire", dec_tire),
    ("bones", dec_bones),
    ("bullets", dec_bullets),
    ("oil", dec_oil),
    ("leaves", dec_leaves),
    ("tuft", dec_tuft),
]



# ------------------------------------------------------------------ сборка
LIFT_GAMMA = 0.85       # подъём теней (альбедо не должно быть почти чёрным —
LIFT_GAIN = 1.10        # на телефонах тёмные текстуры превращаются в кашу)
TARGET_MEAN = 0.34      # мягкая цель по средней яркости материала
LIFT_EXP = 0.70         # насколько сильно подтягивать (1.0 = уравнять все материалы)
MIN_MEAN = 0.20         # ниже этого не опускается ни один материал


def _lift(color: np.ndarray, target: float | None = None) -> np.ndarray:
    """Гамма-подъём альбедо + мягкая подтяжка тёмных материалов к целевой яркости.

    Материалы не уравниваются (это убило бы разницу между асфальтом и травой),
    а лишь подтягиваются: c *= (target/mean)**LIFT_EXP. target=None — только
    гамма/усиление (для декалей: они и должны быть тёмными).
    """
    c = np.power(np.clip(color, 0.0, 1.0), LIFT_GAMMA) * LIFT_GAIN
    c = np.clip(c, 0.0, 1.0)
    if target is None:
        return c
    mean = float(c.mean())
    if mean > 1e-4:
        if mean < target:
            c = c * (target / mean) ** LIFT_EXP
        mean2 = float(c.mean())
        if 1e-4 < mean2 < MIN_MEAN:
            c = c * (MIN_MEAN / mean2)
    return np.clip(c, 0.0, 1.0)


def _save_tile(out: str, tag: str, i: int, name: str, arr, on_bg=True):
    img = P.to_image(arr)
    if on_bg and img.mode == "RGBA":
        bg = Image.new("RGBA", img.size, (30, 30, 34, 255))
        img = Image.alpha_composite(bg, img)
    p = os.path.join(out, f"{tag}_{i:02d}_{name}.png")
    img.save(p)
    return p


def build(verbose: bool = True):
    P.ensure_dirs()
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_out")
    os.makedirs(out, exist_ok=True)
    res = {}

    # --- земля: TILE * GROUND_COLS x TILE * len(GROUND_MATS)
    gc, gn, gpaths = [], [], []
    for mi, (name, fn) in enumerate(GROUND_MATS):
        for v in range(GROUND_COLS):
            c, h = fn(TILE, 1000 + mi * 37 + v * 11)
            c = P.bake_shade(c, h, strength=0.35, ao=0.0)
            c = _lift(c, TARGET_MEAN)
            gc.append(c)
            gn.append(P.normal_from_height(h, 2.4))
            gpaths.append(_save_tile(out, "ground", mi * GROUND_COLS + v, f"{name}_{v}", c))
    ground = P.atlas_stack(gc, GROUND_COLS)
    ground_n = P.atlas_stack(gn, GROUND_COLS)
    P.save_img(P.to_image(ground), "ground_atlas.png", P.TEX)
    P.save_img(P.to_image(ground_n), "ground_atlas_n.png", P.TEX)
    P.contact_sheet(gpaths, os.path.join(out, "sheet_ground.png"), 192, 6)
    res["ground"] = ground.shape

    # --- стены
    wc, wn, wpaths = [], [], []
    for si, (name, fn) in enumerate(WALL_STYLES):
        for v in range(WALL_COLS):
            res_w = fn(TILE, 5000 + si * 53 + v * 13)
            if len(res_w) == 2:
                c, h = res_w
                a = np.ones_like(h)
            else:
                c, h, a = res_w
            c = P.bake_shade(c, h, strength=1.1, ao=0.5, ao_radius=4.0)
            c = _lift(c, TARGET_MEAN + 0.04)
            rgba = np.concatenate([c, a[..., None]], -1)
            wc.append(rgba)
            wn.append(P.normal_from_height(h, 2.6))
            wpaths.append(_save_tile(out, "wall", si * WALL_COLS + v, f"{name}_{v}", rgba))
    wall = P.atlas_stack(wc, WALL_COLS)
    wall_n = P.atlas_stack(wn, WALL_COLS)
    P.save_img(P.to_image(wall), "wall_atlas.png", P.TEX)
    P.save_img(P.to_image(wall_n), "wall_atlas_n.png", P.TEX)
    P.contact_sheet(wpaths, os.path.join(out, "sheet_wall.png"), 192, 5)
    res["wall"] = wall.shape

    # --- декали
    dc, dn, dpaths = [], [], []
    for di, (name, fn) in enumerate(DECALS):
        rgba = fn(TILE, 9000 + di * 67)
        rgba[..., :3] = _lift(rgba[..., :3])
        dc.append(rgba)
        dn.append(P.normal_from_height(rgba[..., 3].copy(), 1.6))
        dpaths.append(_save_tile(out, "decal", di, name, rgba))
    decal = P.atlas_stack(dc, DECAL_COLS)
    decal_n = P.atlas_stack(dn, DECAL_COLS)
    P.save_img(P.to_image(decal), "decal_atlas.png", P.TEX)
    P.save_img(P.to_image(decal_n), "decal_atlas_n.png", P.TEX)
    P.contact_sheet(dpaths, os.path.join(out, "sheet_decal.png"), 192, 6)
    res["decal"] = decal.shape
    return res


if __name__ == "__main__":
    print("ground/wall/decal:", build())
