# -*- coding: utf-8 -*-
"""gen_audio.py — процедурный генератор SFX/эмбиента/музыки для ARPG «ЗОНА».

Всё синтезируется кодом (numpy, без сэмплов и scipy):
  * одношот = транзиент + тело + спектральный хвост (гребёнки/всёпропускающие);
  * шум строится сразу в спектре (irfft случайных бинов) — он строго периодичен
    N отсчётам, поэтому лупы бесшовны математически, а не «на слух»;
  * частоты осцилляторов в лупах квантуются в целое число периодов на луп;
  * события внутри лупа пишутся кольцевым сдвигом (хвост переносится в начало).

Запуск:  cd tools\\gen; python gen_audio.py
Файлы:   assets\\audio\\<name>.wav  (44100 Гц, 16 бит, моно, RIFF/WAVE)
Нормы:   одношоты — пик -1.5 dBFS (0.8414), лупы — пик -3 dBFS (0.7079);
         одношотам добавляются фейды 2 мс / 5 мс от щелчков.
Проверка: таблица статов (длительность/пик/RMS/DC/клипы/шов лупа) в stdout и
         PNG-сводка waveform+спектр в tools\\gen\\_out\\audio_waveforms.png.
"""
from __future__ import annotations

import math
import os
import sys
import time
import wave

import numpy as np
from PIL import Image, ImageDraw

import paint as P

SR = 44100
PEAK_ONE = 0.8414           # -1.5 dBFS — пик одношота
PEAK_LOOP = 0.7079          # -3.0 dBFS — пик лупа
FADE_IN_MS = 2.0
FADE_OUT_MS = 5.0
SEAM_WIN = 200              # окно проверки шва лупа, отсчёты
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_out")


# ------------------------------------------------------------------ утилиты
def ns(sec: float) -> int:
    """Секунды -> отсчёты."""
    return int(round(float(sec) * SR))


def rng(seed: int) -> np.random.Generator:
    """Детерминированный ГПСЧ (каждый звук — свой seed)."""
    return np.random.default_rng(int(seed) & 0x7FFFFFFF)


def peak(x) -> float:
    return float(np.max(np.abs(x))) if len(x) else 0.0


def rms(x) -> float:
    return float(np.sqrt(np.mean(np.square(np.asarray(x, np.float64))))) if len(x) else 0.0


def dbfs(v: float) -> float:
    return -120.0 if v <= 1e-9 else 20.0 * math.log10(v)


def snap(f: float, n: int) -> float:
    """Частота, дающая целое число периодов на n отсчётов (для лупов)."""
    return round(float(f) * n / SR) * SR / n


def to_wav(name: str, x: np.ndarray) -> str:
    """Пишет моно 16-бит PCM WAV в assets/audio (Godot сам сделает .import)."""
    P.ensure_dirs()
    path = os.path.join(P.AUD, name + ".wav")
    a = np.clip(np.asarray(x, np.float64), -1.0, 1.0)
    pcm = np.round(a * 32767.0).astype("<i2")
    with wave.open(path, "wb") as fh:
        fh.setnchannels(1)
        fh.setsampwidth(2)
        fh.setframerate(SR)
        fh.writeframes(pcm.tobytes())
    return path


# --------------------------------------------------------- спектральные фильтры
def resp(f, kind: str = "lp", fc: float = 1000.0, order: int = 2,
         q: float = 0.7, gain_db: float = 6.0) -> np.ndarray:
    """АЧХ фильтра по сетке частот f (фильтры нулевой фазы, без IIR-циклов)."""
    f = np.maximum(np.asarray(f, np.float64), 1e-6)
    fc = max(float(fc), 1.0)
    if kind == "lp":
        return 1.0 / np.sqrt(1.0 + (f / fc) ** (2.0 * order))
    if kind == "hp":
        return 1.0 / np.sqrt(1.0 + (fc / f) ** (2.0 * order))
    if kind == "peak":                      # подъём полосы (gain_db, полоса fc/q)
        bw = fc / max(q, 0.05)
        return 1.0 + (10.0 ** (gain_db / 20.0) - 1.0) / (1.0 + ((f - fc) / bw) ** 2)
    if kind == "notch":
        bw = fc / max(q, 0.05)
        return 1.0 - (1.0 - 10.0 ** (-abs(gain_db) / 20.0)) / (1.0 + ((f - fc) / bw) ** 2)
    raise ValueError("неизвестный фильтр: %r" % (kind,))


def filt(x, kind: str = "lp", fc: float = 1000.0, order: int = 2,
         q: float = 0.7, gain_db: float = 6.0, circular: bool = False) -> np.ndarray:
    """Фильтр нулевой фазы через спектр.

    circular=True — кольцевая свёртка: для лупов периодичность сохраняется;
    иначе сигнал дополняется нулями, чтобы предзвон не съедал атаку.
    """
    x = np.asarray(x, np.float64)
    n = len(x)
    if n < 8:
        return x.copy()
    if circular:
        xp, pad = x, 0
    else:
        pad = n // 3 + 128
        xp = np.concatenate([np.zeros(pad), x, np.zeros(pad)])
    N = len(xp)
    f = np.fft.rfftfreq(N, 1.0 / SR)
    y = np.fft.irfft(np.fft.rfft(xp) * resp(f, kind, fc, order, q, gain_db), N)
    return y[pad:pad + n] if pad else y


def band(x, lo: float, hi: float, order: int = 2, circular: bool = False) -> np.ndarray:
    """Полосовой = ФВЧ(lo) * ФНЧ(hi), порядок на склон."""
    return filt(filt(x, "hp", lo, order, circular=circular), "lp", hi, order,
                circular=circular)


def peak_eq(x, fc: float, gain_db: float, q: float = 1.0, circular: bool = False):
    """Колоночный подъём/провал узкой полосы (металлические призвуки)."""
    return filt(x, "peak", fc, 2, q, gain_db, circular=circular)


def morph_bands(x, edges, envs, circular: bool = False) -> np.ndarray:
    """Разложение на полосы edges=[f0..fK] с покадровыми коэффициентами envs (K x n).

    Так делаются «плывущие» спектры: свист ветра, whoosh, зип-рикошет.
    """
    x = np.asarray(x, np.float64)
    n = len(x)
    out = np.zeros(n)
    for k in range(len(edges) - 1):
        b = band(x, edges[k], edges[k + 1], 2, circular=circular)
        e = np.asarray(envs[k], np.float64)
        if len(e) != n:
            e = np.interp(np.linspace(0.0, 1.0, n), np.linspace(0.0, 1.0, len(e)), e)
        out += b * e
    return out


# ------------------------------------------------------------- шум и огибающие
def _shaped_noise(n: int, seed: int, f, mag) -> np.ndarray:
    """Периодический (ровно n отсчётов) шум с заданной АЧХ mag."""
    r = rng(seed)
    spec = mag * np.exp(1j * r.uniform(0.0, 2.0 * np.pi, len(f)))
    spec[0] = 0.0
    y = np.fft.irfft(spec, n)
    s = float(np.std(y))
    return y / s if s > 1e-12 else y


def noise(n: int, seed: int, kind: str = "lp", fc: float = 2000.0, order: int = 2,
          tilt: float = 0.0) -> np.ndarray:
    """Шум с АЧХ «ФНЧ/ФВЧ fc», опционально с наклоном tilt (дБ/окт / 6)."""
    f = np.fft.rfftfreq(n, 1.0 / SR)
    mag = np.ones_like(f)
    if kind is not None:
        mag = mag * resp(f, kind, fc, order)
    if tilt:
        mag = mag * (np.maximum(f, 2.0) / 1000.0) ** tilt
    return _shaped_noise(n, seed, f, mag)


def noise_band(n: int, seed: int, lo: float, hi: float, order: int = 2,
               tilt: float = 0.0) -> np.ndarray:
    """Шум в полосе lo..hi (единичный СКО)."""
    f = np.fft.rfftfreq(n, 1.0 / SR)
    mag = resp(f, "hp", lo, order) * resp(f, "lp", hi, order)
    if tilt:
        mag = mag * (np.maximum(f, 2.0) / 1000.0) ** tilt
    return _shaped_noise(n, seed, f, mag)


def noise_burst(n: int, seed: int, tau: float = 0.05, lo: float = 200.0,
                hi: float = 8000.0, atk: float = 0.001, order: int = 2,
                tilt: float = 0.0) -> np.ndarray:
    """Вспышка шума: полоса lo..hi и огибающая «атака atk, спад tau»."""
    return noise_band(n, seed, lo, hi, order, tilt) * bell(n, atk, tau)


def bell(n: int, atk: float = 0.002, tau: float = 0.2, start: float = 0.0,
         pow_r: float = 1.0) -> np.ndarray:
    """Огибающая (1-exp(-t/atk)) * exp(-(t/tau)^pow_r) — транзиент + хвост."""
    t = np.maximum(np.arange(n) / SR - max(start, 0.0), 0.0)
    return (1.0 - np.exp(-t / max(atk, 1e-5))) * np.exp(-(t / max(tau, 1e-5)) ** pow_r)


def expdec(n: int, tau: float, start: float = 0.0) -> np.ndarray:
    t = np.maximum(np.arange(n) / SR - max(start, 0.0), 0.0)
    return np.exp(-t / max(tau, 1e-5))


def env_points(n: int, pts, gamma: float = 1.0) -> np.ndarray:
    """Кусочно-линейная огибающая по точкам [(сек, значение), ...]."""
    xs = np.array([p[0] for p in pts], np.float64) * SR
    ys = np.array([p[1] for p in pts], np.float64)
    y = np.interp(np.arange(n, dtype=np.float64), xs, ys)
    return np.clip(y, 0.0, None) ** gamma


def adsr(n: int, a: float = 0.005, d: float = 0.05, s: float = 0.4,
         r: float = 0.1) -> np.ndarray:
    dur = n / SR
    r = min(r, max(dur - a - d, 1e-4))
    return env_points(n, [(0.0, 0.0), (a, 1.0), (a + d, s),
                          (max(dur - r, a + d), s), (dur, 0.0)])


def lfo(n: int, freq: float, depth: float = 1.0, phase: float = 0.0,
        circular: bool = True) -> np.ndarray:
    """Низкочастотный модулятор; для лупов частота квантуется в целые циклы."""
    f = snap(freq, n) if circular else float(freq)
    return depth * np.sin(2.0 * np.pi * f * np.arange(n) / SR + phase)


# ------------------------------------------------------------- осцилляторы
def sine(n: int, f: float, phase: float = 0.0) -> np.ndarray:
    return np.sin(2.0 * np.pi * f * np.arange(n) / SR + phase)


def saw(n: int, f: float, nh: int = 16, phase: float = 0.0) -> np.ndarray:
    """Пила аддитивно (без алиасинга): nh — число гармоник."""
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(1, nh + 1):
        if f * k > 0.45 * SR:
            break
        out += np.sin(2.0 * np.pi * f * k * t + k * phase) / k
    return out * (2.0 / math.pi)


def square(n: int, f: float, nh: int = 12, duty: float = 0.5,
           phase: float = 0.0) -> np.ndarray:
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(1, nh + 1):
        if f * k > 0.45 * SR:
            break
        out += (np.sin(np.pi * k * duty) / k) * np.sin(2.0 * np.pi * f * k * t + k * phase)
    return out * (4.0 / math.pi)


def fm(n: int, fc: float, ratio: float = 1.0, index: float = 2.0,
       decay: float = 0.0) -> np.ndarray:
    """ЧМ-тон; index может спадать с временем decay (с) — «звяк», «вззз»."""
    t = np.arange(n) / SR
    idx = index * (expdec(n, decay) if decay > 0 else 1.0)
    return np.sin(2.0 * np.pi * fc * t + idx * np.sin(2.0 * np.pi * fc * ratio * t))


def sweep(n: int, f0: float, f1: float, mode: str = "log",
          phase: float = 0.0) -> np.ndarray:
    """Скользящий тон (фаза интегрируется — щелчков нет)."""
    T = n / SR
    t = np.arange(n) / SR
    if mode == "lin" or f0 <= 0.0 or f1 <= 0.0:
        ph = 2.0 * np.pi * (f0 * t + 0.5 * (f1 - f0) * t * t / max(T, 1e-9))
    else:
        k = math.log(f1 / f0)
        ph = 2.0 * np.pi * f0 * T / k * (np.exp(k * t / T) - 1.0)
    return np.sin(ph + phase)


def pitch_sweep(n: int, f0: float, f1: float, mode: str = "log",
                atk: float = 0.002, tau: float = 0.15) -> np.ndarray:
    """Скользящий тон под огибающей «транзиент+спад» (тело удара, зип, бум)."""
    return sweep(n, f0, f1, mode) * bell(n, atk, tau)


def f_glide(n: int, f0: float, f1: float, mode: str = "log") -> np.ndarray:
    """Кривая мгновенной частоты (для глоттального источника)."""
    if f0 <= 0.0:
        f0 = 1.0
    if abs(f1 - f0) < 1e-6 or mode == "lin":
        return np.linspace(f0, f1, n)
    k = math.log(f1 / f0)
    return f0 * np.exp(k * np.linspace(0.0, 1.0, n))


def glottal(n: int, seed: int, f0, jitter: float = 0.02, tau: float = 0.0022,
            amp_var: float = 0.12) -> np.ndarray:
    """Глоттальный источник: последовательность коротких спадающих импульсов.

    f0 — число или кривая (глиссандо). Джиттер и разброс амплитуды делают голос
    живым, а не «синтетическим писком».
    """
    r = rng(seed)
    y = np.zeros(n)
    fc = np.asarray(f0, np.float64)
    if fc.ndim == 0:
        fc = np.full(n, float(fc))
    m = max(4, int(tau * SR * 5.0))
    shape = np.exp(-np.arange(m) / max(tau * SR, 1.5))
    shape = shape - shape.mean()
    pos = 0.0
    while pos < n - 1:
        i = int(pos)
        k = min(m, n - i)
        y[i:i + k] += shape[:k] * (1.0 + amp_var * r.normal())
        pos += SR / max(float(fc[min(i, n - 1)]), 20.0) * (1.0 + jitter * r.normal())
    return y


VOWEL_A = ((700.0, 130.0, 1.0), (1150.0, 160.0, 0.55), (2600.0, 260.0, 0.28),
           (3600.0, 400.0, 0.12))
VOWEL_OH = ((480.0, 110.0, 1.0), (850.0, 140.0, 0.6), (2400.0, 260.0, 0.2),
            (3300.0, 380.0, 0.1))
VOWEL_UH = ((450.0, 100.0, 1.0), (1050.0, 150.0, 0.5), (2300.0, 240.0, 0.18),
            (3200.0, 360.0, 0.08))
VOWEL_EE = ((330.0, 90.0, 1.0), (2100.0, 220.0, 0.5), (2900.0, 300.0, 0.3),
            (3900.0, 420.0, 0.1))


def voice(n: int, seed: int, f0: float = 130.0, f1: float | None = None,
          formants=VOWEL_UH, env=None, breath: float = 0.12, jitter: float = 0.02,
          rough: float = 0.0, bright: float = 0.0) -> np.ndarray:
    """Формантный голос: глоттальный пульс + формантные полосы + дыхание.

    f0/f1 — тон в начале/конце, formants — (центр, полоса, вес).
    """
    fc = f_glide(n, float(f0), float(f1 if f1 is not None else f0))
    src = glottal(n, seed, fc, jitter=jitter)
    wet = np.zeros(n)
    for (c, b, g) in formants:
        wet += band(src, max(c - b, 40.0), c + b, 2) * g
    r = rng(seed + 7)
    if breath > 0.0:
        wet += noise_band(n, seed + 11, 400.0, 5000.0, 2) * breath
    if rough > 0.0:
        wet *= np.clip(1.0 - rough * 0.5 + rough * 0.5
                       * noise_band(n, seed + 13, 18.0, 110.0, 1), 0.0, 2.0)
    if bright > 0.0:
        wet += band(wet, 2000.0, 8000.0, 1) * bright
    wet = filt(wet, "lp", 9000.0, 2)
    e = adsr(n, 0.02, 0.12, 0.55, 0.25) if env is None else np.asarray(env, np.float64)
    return wet * e * (1.0 / max(peak(wet), 1e-9)) * r.uniform(0.98, 1.02)


def metallic(n: int, seed: int, base: float = 600.0, partials: int = 6,
             tau: float = 0.5, atk: float = 0.0008, stretch: float = 1.73,
             spread: float = 0.06, jitter_tau: float = 0.4) -> np.ndarray:
    """Негармонический «металл»: частичные с разными временами спада."""
    r = rng(seed)
    out = np.zeros(n)
    for k in range(partials):
        f = base * (stretch ** k) * (1.0 + spread * r.uniform(-1.0, 1.0))
        if f > 0.45 * SR:
            break
        g = 1.0 / (1.0 + 0.6 * k)
        t = tau * (1.0 + jitter_tau * r.uniform(-0.5, 0.6)) / (1.0 + 0.35 * k)
        out += sine(n, f, r.uniform(0.0, 6.28)) * g * bell(n, atk, t)
    return out / max(peak(out), 1e-9)


def thump(n: int, f0: float = 120.0, f1: float = 55.0, tau: float = 0.12,
          atk: float = 0.001, mode: str = "log") -> np.ndarray:
    """Низкий «бум»: скользящий тон с быстрым спадом (тело выстрела, удар)."""
    return sweep(n, f0, f1, mode) * bell(n, atk, tau)


# ------------------------------------------------ задержки, реверберация, кольцо
def shift(x, d: int, circular: bool = False) -> np.ndarray:
    """Сдвиг сигнала на d отсчётов (circular — кольцевой, для лупов)."""
    d = int(d)
    x = np.asarray(x, np.float64)
    if d <= 0:
        return x.copy()
    if circular:
        return np.roll(x, d)
    out = np.zeros_like(x)
    if d < len(x):
        out[d:] = x[:-d]
    return out


def fftconv(x, k, circular: bool = False) -> np.ndarray:
    """Свёртка с коротким ядром: circular=True — кольцевая (лупы остаются лупами)."""
    x = np.asarray(x, np.float64)
    k = np.asarray(k, np.float64)
    n = len(x)
    if circular:
        kk = np.zeros(n)
        m = min(len(k), n)
        kk[:m] = k[:m]
        return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(kk), n)
    N = int(2 ** math.ceil(math.log2(max(n + len(k) + 1, 8))))
    return np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(k, N), N)[:n]


def comb_filter(x, delay: float, rt60: float = 0.5, damp: float = 6000.0,
                circular: bool = False) -> np.ndarray:
    """Гребёнка с обратной связью: wet = Σ fb^k x[t-k*d], fb из времени RT60."""
    x = np.asarray(x, np.float64)
    d = max(1, int(delay * SR))
    fb = 10.0 ** (-3.0 * d / (SR * max(rt60, 0.02)))
    out = np.zeros(len(x))
    g, k = fb, 1
    while g >= 0.002 and k * d < max(len(x), 1) * 2:
        if not circular and k * d >= len(x):
            break
        out += g * shift(x, k * d, circular)
        g *= fb
        k += 1
    if damp < 18000.0:
        out = filt(out, "lp", damp, 2, circular=circular)
    return out


def allpass_sum(x, delay: float, g: float = 0.6, circular: bool = False) -> np.ndarray:
    """Всёпропускающее звено (-g + z^-d)/(1 - g z^-d) — размывает отражения."""
    x = np.asarray(x, np.float64)
    d = max(1, int(delay * SR))
    out = -float(g) * x
    gg, k = 1.0, 1
    while gg * (1.0 - g * g) >= 1e-3 and k * d < max(len(x), 1):
        out += gg * (1.0 - g * g) * shift(x, k * d, circular)
        gg *= g
        k += 1
    return out


def delay_reverb(x, seed: int = 1, rt60: float = 0.8, mix: float = 0.35,
                 damp: float = 5000.0, circular: bool = False,
                 size: float = 1.0) -> np.ndarray:
    """Реверберация Шрёдера: 5 гребёнок + 2 всёпропускающих.

    circular=True — хвост заворачивается в начало, так реверберация не ломает
    периодичность лупа (музыка, эмбиент).
    """
    r = rng(seed)
    x = np.asarray(x, np.float64)
    px = max(peak(x), 1e-9)
    wet = np.zeros(len(x))
    for f in (1.0, 1.19, 1.37, 1.61, 1.93):
        d = 0.0293 * size * f * (1.0 + 0.05 * r.random())
        wet += comb_filter(x, d, rt60, damp, circular)
    for f in (0.0051, 0.0117):
        wet = allpass_sum(wet, f * size * (1.0 + 0.08 * r.random()), 0.62, circular)
    wet = filt(wet, "lp", max(damp, 1500.0), 2, circular=circular)
    wet *= px / max(peak(wet), 1e-9)
    return x + mix * wet


def circ_add(buf: np.ndarray, sig, start: int) -> None:
    """Кольцевая запись сигнала в буфер лупа (хвост переносится в начало)."""
    n = len(buf)
    m = min(len(sig), n)
    p = np.zeros(n)
    p[:m] = np.asarray(sig, np.float64)[:m]
    buf += np.roll(p, int(start) % n)


def grain_gate(n: int, seed: int, rate: float = 60.0, dec: float = 0.004,
               jitter: float = 0.6) -> np.ndarray:
    """Разреженная импульсная решётка (щебень, крэки, гургл)."""
    r = rng(seed)
    env = np.zeros(n)
    pos = 0.0
    while pos < n:
        env[int(pos)] += 1.0
        pos += (SR / max(rate, 0.5)) * (1.0 + jitter * r.normal())
    m = max(2, int(dec * SR))
    return fftconv(env, np.exp(-np.arange(m) / max(m * 0.35, 1.0)))[:n]


# ------------------------------------------------------------- обработка
def soft_clip(x, drive: float = 2.0) -> np.ndarray:
    d = max(drive, 1e-3)
    return np.tanh(d * np.asarray(x, np.float64)) / math.tanh(d)


def distort(x, drive: float = 3.0, bias: float = 0.0, mix: float = 1.0) -> np.ndarray:
    """Асимметричный перегруз (хрип мутанта, грязь аномалии)."""
    x = np.asarray(x, np.float64)
    b = float(bias)
    y = np.tanh(drive * (x + b)) - math.tanh(drive * b)
    y = y / max(peak(y), 1e-9)
    return (1.0 - mix) * x + mix * y * max(peak(x), 1e-9)


def normalize(x, target: float = PEAK_ONE) -> np.ndarray:
    x = np.asarray(x, np.float64)
    p = peak(x)
    return x * (target / p) if p > 1e-9 else x


def dc_block(x) -> np.ndarray:
    x = np.asarray(x, np.float64)
    return x - float(np.mean(x))


def fade(x, fin_ms: float = FADE_IN_MS, fout_ms: float = FADE_OUT_MS) -> np.ndarray:
    """Микрофейды одношота (2 мс вход / 5 мс выход), чтобы не щёлкало."""
    y = np.asarray(x, np.float64).copy()
    a = min(ns(fin_ms / 1000.0), len(y) // 2)
    b = min(ns(fout_ms / 1000.0), len(y) // 2)
    if a > 1:
        y[:a] *= np.sin(np.linspace(0.0, np.pi / 2, a)) ** 2
    if b > 1:
        y[-b:] *= np.cos(np.linspace(0.0, np.pi / 2, b)) ** 2
    return y


def loop_crossfade(src, n: int, xf: int = 1024) -> np.ndarray:
    """Сшивка лупа: хвост перекрывается началом по равномощному окну.

    Нужна только для материала, сгенерированного «как есть» (не кольцевым
    способом): конец буфера подмешивает голову, стык становится плавным.
    """
    src = np.asarray(src, np.float64)
    xf = int(max(0, min(xf, n // 2)))
    out = src[:n].astype(np.float64)
    if xf >= 8:
        t = np.linspace(0.0, 1.0, xf)
        a = np.sin(t * np.pi / 2) ** 2      # вес головы
        b = np.cos(t * np.pi / 2) ** 2      # вес хвоста
        out[n - xf:] = src[n - xf:n] * b + src[:xf] * a
    return out


# ============================================================ вспомогательное
def at(n_total: int, offset: float, sig) -> np.ndarray:
    """Сигнал, поставленный в позицию offset внутри буфера длиной n_total."""
    out = np.zeros(int(n_total))
    i = max(0, int(round(float(offset) * SR)))
    m = min(len(sig), int(n_total) - i)
    if m > 0:
        out[i:i + m] = np.asarray(sig, np.float64)[:m]
    return out


def band_envs(n: int, k: int, center, width: float = 0.22, weight=None):
    """Коэффициенты для morph_bands: гауссов профиль по оси 0..1, центр плывёт.

    center — число (статичный профиль) или кривая длиной n (свист, whoosh).
    """
    c = np.asarray(center, np.float64)
    if c.ndim == 0:
        c = np.full(n, float(c))
    axis = np.linspace(0.0, 1.0, k)
    out = []
    for i in range(k):
        e = np.exp(-((axis[i] - c) ** 2) / (2.0 * width * width))
        if weight is not None:
            e = e * float(weight[i])
        out.append(e)
    return out


def tone_sum(n: int, seed: int, partials, loop: bool = False,
             atk: float = 0.05) -> np.ndarray:
    """Сумма частичных (частота, вес, время спада); loop=True — целые периоды."""
    r = rng(seed)
    out = np.zeros(n)
    for (f, g, t) in partials:
        ff = snap(f, n) if loop else float(f)
        if ff > 0.45 * SR:
            continue
        env = np.ones(n) if loop else bell(n, atk, max(t, 1e-4))
        out += g * sine(n, ff, r.uniform(0.0, 6.283)) * env
    return out


def pluck(n: int, seed: int, f: float, tau: float = 1.2, nh: int = 10,
          detune: float = 0.004, pick: float = 0.2, bright: float = 2600.0,
          loop: bool = False) -> np.ndarray:
    """Щипок (гитара/арфа): гармоники с разными спадами + шумовой «щипок»."""
    r = rng(seed)
    ff = snap(f, n) if loop else float(f)
    out = np.zeros(n)
    for k in range(1, nh + 1):
        fk = ff * k * (1.0 + detune * (k - 1))
        if fk > 0.45 * SR:
            break
        env = np.ones(n) if loop else bell(n, 0.0015 + 0.0005 * k, tau / (1.0 + 0.5 * k))
        out += (1.0 / k ** 1.35) * sine(n, fk, r.uniform(0.0, 6.283)) * env
    if pick > 0.0:
        out += noise_burst(n, seed + 3, 0.006, 900.0, 6500.0, 0.0003) * pick
    return filt(out, "lp", bright, 2)


# ============================================================ оружие
def g_shot_pm() -> np.ndarray:
    """ПМ: сухой резкий щелчок, низкое тело, короткий уличный хвост."""
    n = ns(0.5)
    crack = noise_burst(n, 1001, 0.014, 800.0, 11000.0, 0.0005, tilt=0.25)
    snap = noise_burst(n, 1002, 0.004, 2500.0, 16000.0, 0.0003)
    body = thump(n, 210.0, 60.0, 0.06) * 0.85
    mech = peak_eq(metallic(n, 1003, 2200.0, 4, 0.05, 0.0004), 3200.0, 6.0, 2.0) * 0.22
    x = crack + 0.7 * snap + body + mech
    x = delay_reverb(x, 1004, rt60=0.30, mix=0.30, damp=7000.0)
    x += at(n, 0.16, noise_burst(ns(0.34), 1005, 0.05, 400.0, 2600.0, 0.006) * 0.06)
    return x


def g_shot_ak() -> np.ndarray:
    """АК: звонкий «пак», лязг затвора, эхо по улице."""
    n = ns(0.6)
    crack = noise_burst(n, 1011, 0.009, 1200.0, 14000.0, 0.0003, tilt=0.3)
    mid = noise_burst(n, 1012, 0.030, 400.0, 3200.0, 0.0004)
    body = thump(n, 265.0, 75.0, 0.045) * 0.8
    mech = at(n, 0.085, metallic(ns(0.17), 1013, 3000.0, 3, 0.03, 0.0005) * 0.3)
    mech += at(n, 0.085, noise_burst(ns(0.1), 1014, 0.004, 3000.0, 13000.0, 0.0004) * 0.25)
    x = crack + 0.55 * mid + body + mech
    x = delay_reverb(x, 1015, rt60=0.42, mix=0.32, damp=8000.0)
    x += at(n, 0.14, noise_burst(ns(0.45), 1016, 0.09, 300.0, 2200.0, 0.008) * 0.08)
    return x


def g_shot_shotgun() -> np.ndarray:
    """Дробовик: тяжёлый низкий бум, плотный сноп дроби, длинный хвост."""
    n = ns(0.9)
    sub = sweep(n, 130.0, 34.0, "log") * bell(n, 0.004, 0.22)
    blast = noise_burst(n, 1021, 0.07, 110.0, 3600.0, 0.0006, tilt=-0.15)
    crack = noise_burst(n, 1022, 0.012, 900.0, 12000.0, 0.0004, tilt=0.2)
    chuff = noise_burst(n, 1023, 0.03, 300.0, 1400.0, 0.002) * 0.7
    x = 1.1 * sub + blast + 0.5 * crack + chuff
    x = delay_reverb(x, 1024, rt60=0.75, mix=0.40, damp=3600.0)
    x += at(n, 0.22, noise_burst(ns(0.6), 1025, 0.16, 200.0, 1600.0, 0.01) * 0.1)
    return x


def g_shot_crossbow() -> np.ndarray:
    """Арбалет: щелчок тетивы, «тванг», глухой удар болта."""
    n = ns(0.4)
    snap = noise_burst(n, 1031, 0.005, 1800.0, 15000.0, 0.0003)
    twang = (sweep(n, 330.0, 205.0, "log") * bell(n, 0.0012, 0.075)
             + sweep(n, 498.0, 305.0, "log") * bell(n, 0.0012, 0.05) * 0.6)
    thud = at(n, 0.045, thump(ns(0.28), 120.0, 48.0, 0.075) * 0.9)
    thud += at(n, 0.05, noise_burst(ns(0.2), 1032, 0.03, 150.0, 1200.0, 0.002) * 0.5)
    air = at(n, 0.02, noise_burst(ns(0.2), 1033, 0.05, 700.0, 5000.0, 0.02) * 0.18)
    x = snap + twang + thud + air
    return delay_reverb(x, 1034, rt60=0.28, mix=0.25, damp=6000.0)


def g_melee_swing() -> np.ndarray:
    """Замах: воздушный «вууш» — центр тяжести спектра уходит вверх и обратно."""
    n = ns(0.35)
    base = noise(n, 2001, "hp", 160.0, 1)
    t = np.linspace(0.0, 1.0, n)
    c = 0.22 + 0.62 * np.sin(np.pi * t) ** 1.3
    edges = [160.0, 480.0, 1100.0, 2300.0, 4400.0, 8000.0, 14000.0]
    whoosh = morph_bands(base, edges, band_envs(n, 6, c, 0.26))
    shape = env_points(n, [(0.0, 0.0), (0.06, 0.35), (0.16, 1.0), (0.28, 0.45), (0.35, 0.0)])
    whoosh = whoosh * shape * (1.0 + 0.25 * sine(n, 34.0))
    return whoosh * 1.2 + thump(n, 220.0, 120.0, 0.05) * 0.12


# ============================================================ хелперы звуков
def blip(n: int, f0: float, f1: float, atk: float = 0.001, tau: float = 0.08,
         gain: float = 1.0, harmonics: int = 3) -> np.ndarray:
    """Короткий музыкальный «пинг»: скользящий тон + 2-3 гармоники со спадом.

    При f0 == f1 скольжение вырождается — берётся линейный режим (без деления
    на log(1) = 0).
    """
    mode = "log" if (f0 > 0.0 and f1 > 0.0 and abs(f1 - f0) > 1e-6) else "lin"
    s = sweep(n, f0, f1, mode) * bell(n, atk, tau)
    if harmonics > 1:
        s += 0.35 * sweep(n, f0 * 2.0, f1 * 2.0, mode) * bell(n, atk, tau * 0.55)
    if harmonics > 2:
        s += 0.16 * sweep(n, f0 * 3.0, f1 * 3.0, mode) * bell(n, atk, tau * 0.35)
    return s * gain


def ring(n: int, seed: int, base: float, tau: float = 0.12,
         stretch: float = 1.73, gain: float = 0.3) -> np.ndarray:
    """Звонкий призвук удара по металлу (короткий, не «колокол храма»)."""
    m = metallic(n, seed, base, 5, tau, 0.0005, stretch)
    return peak_eq(m, base * 1.9, 5.0, 2.5) * gain


def pad(n: int, notes, seed: int, bright: float = 2000.0, detune: float = 0.004,
        level: float = 1.0, circular: bool = False) -> np.ndarray:
    """Пад: расстроенные синусы + пила по нотам; circular=True — целые периоды.

    В кольцевом режиме квантуется каждая компонента (включая расстроенные копии
    и гармоники), иначе луп перестал бы быть периодичным и щёлкал бы на стыке.
    """
    r = rng(seed)
    out = np.zeros(n)
    for f in notes:
        ff = snap(f, n) if circular else float(f)
        for mul, g in ((1.0 - detune, 0.5), (1.0 + detune, 0.5), (2.0, 0.16),
                       (3.0, 0.07), (4.0, 0.04)):
            fk = snap(ff * mul, n) if circular else ff * mul
            if fk > 0.45 * SR:
                continue
            out += g * sine(n, fk, r.uniform(0.0, 6.283))
        out += 0.22 * saw(n, ff, 6, r.uniform(0.0, 6.283))
    return filt(out, "lp", bright, 2, circular=circular) * level


def chord(dur: float, notes, seed: int, atk: float = 0.5,
          rel: float = 1.0) -> np.ndarray:
    """Аккорд длиной dur секунд: пад под огибающей «вдох-выдох» (для circ_add)."""
    n = ns(dur)
    env = env_points(n, [(0.0, 0.0), (atk, 1.0),
                         (max(dur - rel, atk + 0.05), 1.0), (dur, 0.0)])
    return pad(n, notes, seed, 2000.0, 0.004, 1.0, False) * env


def kick(dur: float = 0.35, seed: int = 1) -> np.ndarray:
    """Бочка: скользящий низ + щелчок биты."""
    n = ns(dur)
    body = thump(n, 150.0, 46.0, 0.11)
    click = noise_burst(n, 7000 + seed, 0.004, 1200.0, 6000.0, 0.0003) * 0.35
    return distort(body + click, 1.6, 0.0, 0.25)


def snare(dur: float = 0.3, seed: int = 1) -> np.ndarray:
    """Жестяной малый: шумовой сноп + короткое тело."""
    n = ns(dur)
    s = noise_burst(n, 7100 + seed, 0.075, 900.0, 9000.0, 0.0006, tilt=0.15)
    body = (sine(n, 210.0) + sine(n, 305.0) * 0.6) * bell(n, 0.0008, 0.05) * 0.25
    return s + body


def hat(dur: float = 0.08, seed: int = 1) -> np.ndarray:
    """Хэт: очень короткий ВЧ-шум."""
    return noise_burst(ns(dur), 7200 + seed, 0.022, 6000.0, 16000.0, 0.0004,
                       tilt=0.2)


def seam_db(x: np.ndarray) -> float:
    """Стык лупа в дБ: разрыв на шве относительно обычного шага сигнала."""
    d_joint = abs(float(x[0]) - float(x[-1]))
    step = float(np.sqrt(np.mean(np.diff(x) ** 2))) * 2.0
    return dbfs(d_joint / max(step, 1e-12))


# ============================================================ удары и попадания
def g_melee_hit() -> np.ndarray:
    """Попадание клинком: щелчок, мясистое тело, короткий металлический звон."""
    n = ns(0.45)
    click = noise_burst(n, 2101, 0.006, 900.0, 9000.0, 0.0004)
    slap = noise_burst(n, 2102, 0.035, 220.0, 2600.0, 0.0006, tilt=-0.1)
    body = thump(n, 180.0, 62.0, 0.13) * 1.1
    x = click + 0.8 * slap + body + at(n, 0.004, ring(ns(0.25), 2103, 1500.0))
    return delay_reverb(x, 2104, rt60=0.22, mix=0.18, damp=5200.0)


def g_hit_flesh() -> np.ndarray:
    """Попадание по плоти: мокрый шлепок, глухое тело, «чвак»."""
    n = ns(0.35)
    wet = noise_burst(n, 2111, 0.05, 150.0, 2200.0, 0.0008, tilt=-0.2)
    body = thump(n, 150.0, 58.0, 0.10)
    squelch = band(grain_gate(n, 2112, 90.0, 0.006, 0.9) * bell(n, 0.003, 0.045),
                   300.0, 3000.0) * 0.35
    return wet + body + squelch


def g_hit_wall() -> np.ndarray:
    """Пуля в бетон: крошка, пыль, короткий глухой отскок."""
    n = ns(0.30)
    chip = noise_burst(n, 2121, 0.004, 2500.0, 14000.0, 0.0003)
    dust = noise_burst(n, 2122, 0.06, 500.0, 6000.0, 0.0015) * 0.5
    body = thump(n, 240.0, 90.0, 0.05) * 0.7
    grit = band(grain_gate(n, 2123, 45.0, 0.003, 1.0), 1200.0, 8000.0) * 0.25
    x = chip + dust + body + grit
    return delay_reverb(x, 2124, rt60=0.20, mix=0.16, damp=7000.0)


def g_explosion() -> np.ndarray:
    """Взрыв: инфраниз, сноп бласта, катящийся рокот и град обломков."""
    n = ns(2.2)
    sub = sweep(n, 110.0, 26.0, "log") * bell(n, 0.006, 0.55, 0.0, 0.8) * 1.4
    blast = noise_burst(n, 2131, 0.22, 60.0, 5000.0, 0.0008, tilt=-0.2)
    crack = noise_burst(n, 2132, 0.02, 800.0, 12000.0, 0.0004, tilt=0.2)
    rumble = noise_band(n, 2133, 30.0, 220.0, 2) * bell(n, 0.02, 0.9, 0.0, 0.7) * 0.9
    debris = band(grain_gate(n, 2134, 28.0, 0.01, 1.2)
                  * bell(n, 0.02, 1.2, 0.0, 0.6), 900.0, 9000.0) * 0.35
    x = sub + 1.1 * blast + 0.6 * crack + rumble + debris
    x = distort(x, 1.4, 0.0, 0.18)
    return delay_reverb(x, 2135, rt60=1.6, mix=0.30, damp=3200.0, size=1.4)


# ============================================================ шаги
def g_step_gravel(variant: int = 1) -> np.ndarray:
    """Шаг по гравию/щебню: сухой хруст, немного пыли, мягкое тело."""
    seed = 3000 + variant * 17
    n = ns(0.22)
    crunch = band(grain_gate(n, seed, 110.0, 0.0025, 1.1), 700.0, 11000.0)
    grit = noise_burst(n, seed + 1, 0.03, 400.0, 7000.0, 0.0015, tilt=0.1)
    body = thump(n, 150.0, 70.0, 0.035) * 0.5
    x = 0.9 * crunch + 0.5 * grit + body
    x *= env_points(n, [(0.0, 0.0), (0.01, 1.0), (0.05, 0.55), (n / SR, 0.0)])
    return delay_reverb(x, seed + 2, rt60=0.16, mix=0.12, damp=6500.0)


def g_step_grass(variant: int = 1) -> np.ndarray:
    """Шаг по сухой траве: шорох листвы, мало тела."""
    seed = 3100 + variant * 23
    n = ns(0.20)
    rustle = band(grain_gate(n, seed, 150.0, 0.003, 1.3), 1500.0, 12000.0)
    swish = noise_burst(n, seed + 1, 0.045, 900.0, 9000.0, 0.004, tilt=0.25)
    body = thump(n, 165.0, 80.0, 0.028) * 0.3
    x = 0.7 * rustle + 0.8 * swish + body
    x *= env_points(n, [(0.0, 0.0), (0.015, 1.0), (0.06, 0.45), (n / SR, 0.0)])
    return delay_reverb(x, seed + 2, rt60=0.12, mix=0.10, damp=8000.0)


def g_step_metal() -> np.ndarray:
    """Шаг по железу: звонкий щелчок подошвы и короткий гул листа."""
    n = ns(0.28)
    click = noise_burst(n, 3201, 0.004, 2000.0, 15000.0, 0.0003)
    plate = at(n, 0.003, ring(ns(0.22), 3202, 620.0, 0.16, 1.41, 0.35))
    scrape = noise_burst(n, 3203, 0.03, 1500.0, 8000.0, 0.004) * 0.35
    body = thump(n, 200.0, 95.0, 0.03) * 0.4
    x = click + plate + scrape + body
    return delay_reverb(x, 3204, rt60=0.4, mix=0.22, damp=6000.0)


# ============================================================ игрок
def g_player_hurt() -> np.ndarray:
    """Ранение: сдавленный вскрик, шорох одежды, глухой толчок."""
    n = ns(0.55)
    env = env_points(n, [(0.0, 0.0), (0.012, 1.0), (0.08, 0.55), (0.5, 0.0)])
    v = voice(n, 3101, 195.0, 140.0, VOWEL_A, env=env, breath=0.18,
              jitter=0.03, rough=0.25)
    cloth = noise_burst(n, 3102, 0.06, 300.0, 4000.0, 0.002) * 0.25
    body = thump(n, 130.0, 60.0, 0.06) * 0.35
    return delay_reverb(v + cloth + body, 3103, rt60=0.35, mix=0.25, damp=5000.0)


def g_player_die() -> np.ndarray:
    """Смерть: длинный затухающий выдох-стон и падение тела."""
    n = ns(1.7)
    env = env_points(n, [(0.0, 0.0), (0.03, 1.0), (0.35, 0.72), (0.95, 0.28),
                         (1.55, 0.0)])
    v = voice(n, 3111, 150.0, 84.0, VOWEL_OH, env=env, breath=0.22,
              jitter=0.05, rough=0.35, bright=0.15)
    fall = thump(n, 120.0, 44.0, 0.5) * 0.5 * expdec(n, 0.7, 0.6)
    land = at(n, 1.15, thump(ns(0.35), 90.0, 40.0, 0.11) * 0.6
              + noise_burst(ns(0.35), 3112, 0.09, 120.0, 1800.0, 0.005) * 0.45)
    return delay_reverb(v + fall + land, 3113, rt60=0.9, mix=0.34, damp=3400.0)


# ============================================================ интерфейс
def g_ui_click() -> np.ndarray:
    """Клик: сухой высокий тик с коротким тоном (не раздражает при спаме)."""
    n = ns(0.06)
    tick = noise_burst(n, 4001, 0.0035, 2200.0, 13000.0, 0.0002)
    blip_ = sweep(n, 2400.0, 1500.0, "log") * bell(n, 0.0006, 0.012)
    body = sine(n, 900.0) * bell(n, 0.0006, 0.02) * 0.3
    return tick + 0.5 * blip_ + body


def g_ui_open() -> np.ndarray:
    """Открытие панели: «вдох» воздуха и восходящий пинг."""
    n = ns(0.30)
    air = noise_burst(n, 4011, 0.10, 700.0, 6000.0, 0.02, tilt=0.15)
    air *= env_points(n, [(0.0, 0.0), (0.06, 1.0), (n / SR, 0.0)])
    return 0.55 * air + at(n, 0.04, blip(ns(0.20), 620.0, 880.0, 0.001, 0.09, 0.8))


def g_ui_close() -> np.ndarray:
    """Закрытие панели: короткий выдох и нисходящий пинг."""
    n = ns(0.26)
    air = noise_burst(n, 4021, 0.07, 600.0, 5000.0, 0.012, tilt=0.15)
    air *= env_points(n, [(0.0, 0.0), (0.04, 0.9), (n / SR, 0.0)])
    return 0.45 * air + at(n, 0.01, blip(ns(0.18), 880.0, 560.0, 0.001, 0.075, 0.7))


def g_ui_deny() -> np.ndarray:
    """Отказ: низкий двойной «бз-з» — действие недоступно."""
    n = ns(0.26)
    buzz = filt(square(n, 148.0, 10, 0.35), "lp", 1600.0, 2)
    buzz *= env_points(n, [(0.0, 0.0), (0.004, 1.0), (0.07, 0.35), (0.075, 1.0),
                           (0.16, 0.3), (n / SR, 0.0)])
    dust = noise_burst(n, 4031, 0.03, 200.0, 2500.0, 0.002) * 0.25
    return distort(buzz * 0.6 + dust, 1.4, 0.0, 0.2)


def g_quest_new() -> np.ndarray:
    """Новое задание: две светлые ноты колокольчика с металлическим призвуком."""
    n = ns(0.75)
    x = at(n, 0.0, blip(ns(0.38), 784.0, 784.0, 0.002, 0.18, 0.75))
    x += at(n, 0.16, blip(ns(0.44), 1046.0, 1046.0, 0.002, 0.24, 0.7))
    x += at(n, 0.16, ring(ns(0.44), 4035, 2093.0, 0.28, 1.41, 0.12))
    return delay_reverb(x, 4036, rt60=0.5, mix=0.2, damp=8000.0)


def g_quest_done() -> np.ndarray:
    """Задание выполнено: восходящее трезвучие с искристым хвостом."""
    n = ns(1.0)
    x = np.zeros(n)
    for i, f in enumerate((523.25, 659.25, 783.99)):
        x += at(n, 0.13 * i, blip(ns(0.4), f, f, 0.002, 0.22, 0.6))
    x += at(n, 0.26, noise_band(ns(0.5), 4041, 3000.0, 11000.0, 2)
            * env_points(ns(0.5), [(0.0, 0.0), (0.04, 0.7), (0.45, 0.0)]) * 0.12)
    return delay_reverb(x, 4042, rt60=0.7, mix=0.25, damp=7000.0)


def g_levelup() -> np.ndarray:
    """Уровень: короткая фанфара из четырёх нот, последняя тянется."""
    n = ns(1.4)
    x = np.zeros(n)
    for i, f in enumerate((392.0, 523.25, 659.25, 783.99)):
        x += at(n, 0.11 * i, blip(ns(0.5), f, f, 0.002, 0.2 if i < 3 else 0.45,
                                  0.55))
    x += at(n, 0.33, chord(0.9, (783.99, 987.77, 1174.66), 4051, 0.06, 0.5) * 0.35)
    x += at(n, 0.33, noise_band(ns(0.8), 4052, 4000.0, 14000.0, 2)
            * env_points(ns(0.8), [(0.0, 0.0), (0.05, 0.5), (0.75, 0.0)]) * 0.10)
    return delay_reverb(x, 4053, rt60=0.9, mix=0.28, damp=8000.0)


def g_notify() -> np.ndarray:
    """Уведомление: мягкий двойной пинг (журнал, счётчик, подсказка)."""
    n = ns(0.5)
    x = at(n, 0.0, blip(ns(0.22), 880.0, 880.0, 0.003, 0.10, 0.5))
    x += at(n, 0.11, blip(ns(0.26), 1174.7, 1174.7, 0.003, 0.13, 0.42))
    return delay_reverb(x, 4061, rt60=0.4, mix=0.18, damp=9000.0)


# ============================================================ предметы
def g_pickup_item() -> np.ndarray:
    """Подбор предмета: шорох ткани/бумаги и тихий металлический цок."""
    n = ns(0.30)
    rustle = noise_burst(n, 4101, 0.09, 900.0, 9000.0, 0.006, tilt=0.2)
    rustle *= env_points(n, [(0.0, 0.0), (0.03, 1.0), (0.12, 0.4), (n / SR, 0.0)])
    clink = at(n, 0.05, ring(ns(0.2), 4102, 1450.0, 0.14, 2.1, 0.30))
    return 0.7 * rustle + clink


def g_pickup_artefact() -> np.ndarray:
    """Подбор артефакта: яркий колокольчик с искристым «стеклянным» хвостом."""
    n = ns(1.1)
    x = at(n, 0.0, metallic(ns(0.9), 4111, 780.0, 6, 0.7, 0.0006, 1.41) * 0.5)
    x += at(n, 0.02, blip(ns(0.5), 1170.0, 780.0, 0.0015, 0.35, 0.4))
    shimmer = noise_band(n, 4112, 2000.0, 9000.0, 2)
    shimmer *= env_points(n, [(0.0, 0.0), (0.05, 0.8), (0.6, 0.25), (n / SR, 0.0)])
    return delay_reverb(x + 0.18 * shimmer, 4113, rt60=0.9, mix=0.35, damp=6000.0)


def g_artifact_taken() -> np.ndarray:
    """Артефакт «вынут» из аномалии/тайника: затягивающий вдох, пинг, толчок."""
    n = ns(0.9)
    base = noise(n, 4121, "hp", 200.0, 1)
    t = np.linspace(0.0, 1.0, n)
    c = 0.15 + 0.70 * t ** 0.8
    edges = [150.0, 500.0, 1200.0, 2600.0, 5200.0, 10000.0, 16000.0]
    suck = morph_bands(base, edges, band_envs(n, 6, c, 0.24))
    suck *= env_points(n, [(0.0, 0.0), (0.12, 0.65), (0.35, 1.0), (n / SR, 0.0)])
    ping = at(n, 0.22, blip(ns(0.5), 660.0, 990.0, 0.002, 0.3, 0.5))
    thud = at(n, 0.20, thump(ns(0.3), 110.0, 48.0, 0.12) * 0.6)
    return delay_reverb(0.5 * suck + ping + thud, 4122, rt60=0.8, mix=0.35,
                        damp=6000.0)


def g_artifact_hum() -> np.ndarray:
    """Фон артефакта: низкий пульсирующий гул с биениями (одношот на 1.2 с)."""
    n = ns(1.2)
    hum = (sine(n, 58.0) * 0.9 + sine(n, 58.7) * 0.6 + sine(n, 116.0) * 0.25
           + sine(n, 174.3) * 0.12)
    env = env_points(n, [(0.0, 0.0), (0.12, 1.0), (0.9, 0.85), (n / SR, 0.0)])
    hum *= env * (1.0 + 0.25 * lfo(n, 5.5, 1.0, 0.0, False))
    hum += 0.06 * noise_band(n, 4131, 200.0, 1600.0, 2) * env
    return filt(hum, "lp", 2600.0, 2)


# ============================================================ аномалии и радиация
def g_anomaly_hum() -> np.ndarray:
    """Гул аномалии: расстроенный низкий дрон с медленным «дыханием»."""
    n = ns(1.4)
    drone = (sine(n, 61.0) + sine(n, 61.7) * 0.8 + sine(n, 91.5) * 0.35
             + sine(n, 122.0) * 0.2 + sine(n, 183.0) * 0.08)
    drone *= 1.0 + 0.3 * lfo(n, 0.9, 1.0, 0.0, False)
    env = env_points(n, [(0.0, 0.0), (0.2, 1.0), (1.1, 0.85), (n / SR, 0.0)])
    eerie = noise_band(n, 4201, 1200.0, 5200.0, 2) * env * 0.10
    return filt(drone * env + eerie, "lp", 4200.0, 2)


def g_anomaly_zap() -> np.ndarray:
    """Электрический разряд: треск, щелчки дуги, звон и короткое эхо."""
    n = ns(0.5)
    arc = noise_burst(n, 4211, 0.05, 1500.0, 15000.0, 0.0003, tilt=0.2)
    arc += noise_burst(n, 4212, 0.012, 3000.0, 16000.0, 0.0002) * 0.7
    arc += grain_gate(n, 4215, 70.0, 0.002, 1.0) * 0.25
    body = thump(n, 260.0, 70.0, 0.05) * 0.7
    x = arc + body + at(n, 0.006, ring(ns(0.3), 4213, 2400.0, 0.09, 1.41, 0.25))
    x = distort(x, 2.2, 0.0, 0.35)
    return delay_reverb(x, 4214, rt60=0.3, mix=0.25, damp=8000.0)


def g_anomaly_warp() -> np.ndarray:
    """Искажение пространства: спектр «схлопывается» вниз, тон уходит в инфра."""
    n = ns(0.9)
    base = noise(n, 4221, "hp", 120.0, 1)
    t = np.linspace(0.0, 1.0, n)
    c = 0.85 - 0.75 * t ** 0.7
    edges = [120.0, 420.0, 950.0, 2100.0, 4200.0, 9000.0, 16000.0]
    warp = morph_bands(base, edges, band_envs(n, 6, c, 0.20))
    warp *= env_points(n, [(0.0, 0.0), (0.06, 0.8), (0.3, 1.0), (n / SR, 0.0)])
    tone = sweep(n, 900.0, 90.0, "log") * bell(n, 0.01, 0.4) * 0.35
    return delay_reverb(warp + tone, 4222, rt60=0.8, mix=0.4, damp=5000.0)


def g_geiger_click() -> np.ndarray:
    """Щелчок дозиметра: предельно короткий, играется очередями с разным тоном."""
    n = ns(0.035)
    tick = noise_burst(n, 4301, 0.0018, 3000.0, 16000.0, 0.00012)
    body = sine(n, 1700.0) * bell(n, 0.0002, 0.004) * 0.25
    return tick + body


def g_geiger_burst() -> np.ndarray:
    """Всплеск радиации: часто-частая дробь щелчков (0.55 с)."""
    n = ns(0.55)
    out = np.zeros(n)
    r = rng(4307)
    t = 0.0
    while t < 0.5:
        click = noise_burst(ns(0.03), 4300 + int(t * 977.0), 0.0016, 3200.0,
                            16000.0, 0.0001)
        out += at(n, t, click * float(r.uniform(0.65, 1.0)))
        t += float(r.uniform(0.022, 0.085))
    return out


def g_detector_ping() -> np.ndarray:
    """Детектор «Отклик»: сонаровый пинг и два затухающих эха."""
    n = ns(1.2)
    p = blip(ns(0.35), 1180.0, 1180.0, 0.002, 0.16, 0.9)
    x = at(n, 0.0, p)
    x += at(n, 0.28, p * 0.35)
    x += at(n, 0.62, p * 0.16)
    x += at(n, 0.0, noise_burst(ns(0.2), 4311, 0.05, 900.0, 6000.0, 0.004) * 0.10)
    return delay_reverb(x, 4312, rt60=0.5, mix=0.2, damp=7000.0)


# ============================================================ существа
def g_dog_growl() -> np.ndarray:
    """Рычание слепого пса: низкий дрожащий голос с хрипом."""
    n = ns(1.0)
    env = env_points(n, [(0.0, 0.0), (0.08, 1.0), (0.7, 0.85), (n / SR, 0.0)])
    g = voice(n, 5001, 92.0, 76.0, VOWEL_OH, env=env, breath=0.20, jitter=0.06,
              rough=0.70, bright=0.20)
    return delay_reverb(distort(g, 2.5, 0.02, 0.4), 5002, rt60=0.4, mix=0.22,
                        damp=4500.0)


def g_dog_bark() -> np.ndarray:
    """Лай: резкая атака, быстрый уход тона вниз, рычащий тембр."""
    n = ns(0.45)
    env = env_points(n, [(0.0, 0.0), (0.008, 1.0), (0.05, 0.75), (0.28, 0.0)])
    v = voice(n, 5011, 240.0, 150.0, VOWEL_OH, env=env, breath=0.25, jitter=0.05,
              rough=0.5, bright=0.3)
    crack = noise_burst(n, 5012, 0.02, 900.0, 8000.0, 0.0006) * 0.35
    return delay_reverb(distort(v + crack, 2.0, 0.0, 0.3), 5013, rt60=0.35,
                        mix=0.20, damp=5000.0)


def g_mutant_roar() -> np.ndarray:
    """Рёв мутанта: длинный, перегруженный, с рокотом в груди."""
    n = ns(1.9)
    env = env_points(n, [(0.0, 0.0), (0.05, 1.0), (0.5, 0.9), (1.2, 0.5),
                         (n / SR, 0.0)])
    v = voice(n, 5021, 155.0, 74.0, VOWEL_A, env=env, breath=0.28, jitter=0.07,
              rough=0.60, bright=0.25)
    v = distort(v, 3.4, 0.03, 0.55)
    chest = noise_band(n, 5022, 40.0, 260.0, 2) * env * 0.35
    return delay_reverb(v + chest, 5023, rt60=1.1, mix=0.32, damp=3800.0, size=1.3)


def g_zombie_moan() -> np.ndarray:
    """Стон зомби: «плавающий» тон с тремоло — связки не слушаются."""
    n = ns(1.6)
    env = env_points(n, [(0.0, 0.0), (0.25, 0.9), (0.6, 1.0), (1.3, 0.6),
                         (n / SR, 0.0)])
    v = voice(n, 5031, 118.0, 96.0, VOWEL_OH, env=env, breath=0.30, jitter=0.09,
              rough=0.45, bright=0.10)
    v *= 1.0 + 0.22 * lfo(n, 4.6, 1.0, 0.0, False)
    return delay_reverb(distort(v, 2.0, 0.0, 0.3), 5032, rt60=0.9, mix=0.30,
                        damp=3600.0)


def g_boar_snort() -> np.ndarray:
    """Сопение кабана: два шумных «пыха» и низкое рычание горлом."""
    n = ns(0.55)
    out = np.zeros(n)
    for i, t0 in enumerate((0.0, 0.18)):
        huff = noise_burst(ns(0.3), 5041 + i, 0.05, 260.0, 3200.0, 0.004, tilt=-0.1)
        huff *= env_points(ns(0.3), [(0.0, 0.0), (0.02, 1.0), (0.1, 0.4), (0.28, 0.0)])
        out += at(n, t0, band(huff, 200.0, 4200.0) * (1.0 - 0.2 * i))
    env = env_points(n, [(0.0, 0.0), (0.03, 0.8), (0.35, 0.4), (n / SR, 0.0)])
    out += 0.5 * voice(n, 5043, 70.0, 58.0, VOWEL_OH, env=env, breath=0.10,
                       rough=0.60)
    return delay_reverb(out, 5044, rt60=0.3, mix=0.18, damp=4500.0)


def g_creature_die() -> np.ndarray:
    """Смерть существа: предсмертный визг, падение тела и затихающее эхо."""
    n = ns(1.5)
    env = env_points(n, [(0.0, 0.0), (0.03, 1.0), (0.25, 0.8), (0.7, 0.35),
                         (1.1, 0.0)])
    v = voice(n, 5051, 320.0, 88.0, VOWEL_EE, env=env, breath=0.30, jitter=0.08,
              rough=0.55, bright=0.20)
    v = distort(v, 2.4, 0.0, 0.4)
    fall = at(n, 0.75, thump(ns(0.4), 100.0, 42.0, 0.14) * 0.7
              + noise_burst(ns(0.4), 5052, 0.10, 150.0, 2000.0, 0.005) * 0.4)
    return delay_reverb(v + fall, 5053, rt60=0.85, mix=0.32, damp=4200.0)


# ============================================================ лупы: эмбиент
def _wind_body(n: int, seed: int, bright: float = 3400.0) -> np.ndarray:
    """Основа ветра: периодический шум с блуждающим по полосам горбом."""
    base = noise(n, seed, None, 0.0, 1, tilt=-0.03)
    t = np.linspace(0.0, 1.0, n)
    c = (0.30 + 0.20 * np.sin(2.0 * np.pi * t)
         + 0.12 * np.sin(6.0 * np.pi * t + 1.0)
         + 0.08 * np.sin(10.0 * np.pi * t + 2.0))
    edges = [80.0, 220.0, 600.0, 1400.0, 3000.0, 6500.0, 12000.0, 16000.0]
    w = morph_bands(base, edges, band_envs(n, 7, c, 0.22), circular=True)
    return filt(w, "lp", bright, 2, circular=True)


def g_amb_wind_loop() -> np.ndarray:
    """Открытая местность: ветер с порывами, гул в проводах (луп 8 с)."""
    n = ns(8.0)
    gust = 0.55 + 0.45 * (0.5 + 0.5 * lfo(n, 0.125, 1.0))
    gust *= 0.70 + 0.30 * (0.5 + 0.5 * lfo(n, 0.375, 1.0, 1.7))
    x = _wind_body(n, 6101) * gust
    x += 0.22 * noise_band(n, 6102, 40.0, 180.0, 2) * gust
    x += 0.10 * noise_band(n, 6103, 2500.0, 9000.0, 2) * (1.0 - gust)
    return filt(x, "lp", 9000.0, 2, circular=True)


def g_amb_zone_loop() -> np.ndarray:
    """Зона днём: ветер, дальние скрипы железа, гул промышленности (луп 8 с)."""
    n = ns(8.0)
    x = _wind_body(n, 6111, 3000.0) * (0.5 + 0.5 * (0.5 + 0.5 * lfo(n, 0.25, 1.0)))
    x += 0.16 * noise_band(n, 6112, 45.0, 200.0, 2)
    x += 0.07 * noise_band(n, 6113, 3000.0, 11000.0, 2)
    for i, t0 in enumerate((0.9, 3.4, 5.1, 6.8)):
        creak = ring(ns(1.2), 6120 + i, 380.0 + 90.0 * i, 0.5, 1.62, 0.10)
        creak *= env_points(ns(1.2), [(0.0, 0.0), (0.05, 0.8), (0.5, 0.3), (1.2, 0.0)])
        circ_add(x, creak, ns(t0))
    for i, t0 in enumerate((0.42, 1.95, 3.10, 4.60, 6.05, 7.35)):
        tick = 0.5 * band(grain_gate(ns(0.07), 6131 + i, 120.0, 0.004, 1.0),
                          1500.0, 9000.0)          # остывающий металл
        circ_add(x, tick, ns(t0))
    x = delay_reverb(x, 6132, rt60=1.6, mix=0.25, damp=3000.0, circular=True,
                     size=1.4)
    return filt(x, "lp", 8000.0, 2, circular=True)


def g_amb_cave_loop() -> np.ndarray:
    """Бункер/подвал: глухой гул, капель в воду, длинное эхо (луп 8 с)."""
    n = ns(8.0)
    x = 0.50 * noise_band(n, 6201, 30.0, 420.0, 2) * (0.6 + 0.4 * (0.5 + 0.5 * lfo(n, 0.25, 1.0)))
    x += 0.18 * noise_band(n, 6202, 200.0, 1800.0, 2) * (0.5 + 0.5 * (0.5 + 0.5 * lfo(n, 0.5, 1.0, 0.9)))
    for i, t0 in enumerate((0.7, 2.2, 3.1, 4.9, 6.4, 7.3)):
        drip = blip(ns(0.25), 1500.0 + 260.0 * (i % 3), 900.0, 0.0015, 0.10, 0.5)
        drip += noise_burst(ns(0.25), 6220 + i, 0.02, 1200.0, 9000.0, 0.001) * 0.4
        circ_add(x, drip, ns(t0))
    x = delay_reverb(x, 6231, rt60=2.6, mix=0.45, damp=1800.0, circular=True,
                     size=2.0)
    return filt(x, "lp", 6500.0, 2, circular=True)


def g_amb_danger_loop() -> np.ndarray:
    """Опасность рядом: диссонирующий дрон, пульс, шёпот неба (луп 6 с)."""
    n = ns(6.0)
    x = pad(n, (55.0, 58.27, 82.41), 6301, 900.0, 0.006, 1.0, True)
    x *= 0.75 + 0.25 * (0.5 + 0.5 * lfo(n, 0.5, 1.0))
    beat = np.zeros(n)
    one = thump(ns(0.35), 80.0, 42.0, 0.12) * 0.5
    for k in range(12):
        circ_add(beat, one, ns(0.5 * k))
    x += beat * (0.35 + 0.65 * (0.5 + 0.5 * lfo(n, 0.33, 1.0)))
    x += 0.10 * noise_band(n, 6302, 1800.0, 8000.0, 2) * (0.5 + 0.5 * (0.5 + 0.5 * lfo(n, 0.16, 1.0, 2.0)))
    x = distort(x, 1.8, 0.0, 0.25)
    x = delay_reverb(x, 6303, rt60=1.8, mix=0.30, damp=2400.0, circular=True,
                     size=1.6)
    return filt(x, "lp", 7000.0, 2, circular=True)


# ============================================================ лупы: тело игрока
def g_heartbeat_loop() -> np.ndarray:
    """Сердцебиение: пара «луб-дуб» за 0.6 с с паузой (луп 1.2 с, ~100 уд/мин)."""
    n = ns(1.2)
    buf = np.zeros(n)
    lub = filt(thump(ns(0.35), 62.0, 34.0, 0.09), "lp", 260.0, 2)
    dub = filt(thump(ns(0.30), 54.0, 30.0, 0.07), "lp", 220.0, 2) * 0.72
    circ_add(buf, lub, 0)
    circ_add(buf, dub, ns(0.30))
    circ_add(buf, lub, ns(0.60))
    circ_add(buf, dub, ns(0.90))
    buf += 0.035 * noise_band(n, 6001, 40.0, 320.0, 2)      # кровь в ушах
    return filt(buf, "lp", 520.0, 2, circular=True)


def g_breath_loop() -> np.ndarray:
    """Дыхание раненого: два вдоха-выдоха на 4 с, сухой шершавый тембр."""
    n = ns(4.0)
    air = noise_band(n, 6011, 180.0, 4200.0, 2, tilt=0.1)
    env = 0.30 + 0.70 * (0.5 + 0.5 * lfo(n, 0.5, 1.0))
    env *= 0.60 + 0.40 * (0.5 + 0.5 * lfo(n, 0.25, 1.0, 1.2))
    c = 0.30 + 0.35 * (0.5 + 0.5 * lfo(n, 0.5, 1.0, 1.5708))
    br = morph_bands(air * env, [120.0, 500.0, 1500.0, 3400.0, 9000.0],
                     band_envs(n, 4, c, 0.30), circular=True)
    br += 0.10 * noise_band(n, 6012, 2200.0, 9000.0, 2) * env * (1.0 - c)
    return filt(br, "lp", 5200.0, 2, circular=True)


# ============================================================ музыка
def g_mus_menu_loop() -> np.ndarray:
    """Меню: 16 с, прогрессия Am–F–G–Em, редкие щипки и далёкий гул зоны."""
    n = ns(16.0)
    x = np.zeros(n)
    step = 4.0
    chords = ((55.00, 82.41, 110.00, 164.81),      # Am
              (43.65, 87.31, 110.00, 130.81),      # F
              (49.00, 98.00, 123.47, 146.83),      # G
              (41.20, 82.41, 98.00, 123.47))       # Em
    for i, notes in enumerate(chords):
        cnt = ns(step + 0.3)
        ch = pad(cnt, notes, 8001 + i, 1500.0, 0.005, 0.55, False)
        ch *= env_points(cnt, [(0.0, 0.0), (1.6, 1.0), (2.6, 0.85), (cnt / SR, 0.0)])
        circ_add(x, ch, ns(step * i))       # хвост аккорда заворачивается в начало
    x += 0.30 * pad(n, (55.0, 110.0, 164.81), 8010, 700.0, 0.004, 1.0, True) * (
        0.6 + 0.4 * (0.5 + 0.5 * lfo(n, 0.125, 1.0)))
    for i, (t0, f) in enumerate(((2.4, 440.0), (5.8, 523.25), (7.2, 659.25),
                                 (10.6, 587.33), (13.4, 440.0), (15.1, 392.0))):
        pl = pluck(ns(2.6), 8020 + i, f, 1.4, 8, 0.003, 0.12, 3000.0)
        pl *= env_points(ns(2.6), [(0.0, 0.0), (0.01, 1.0), (0.7, 0.35), (2.6, 0.0)])
        circ_add(x, pl * 0.22, ns(t0))
    for i, t0 in enumerate((1.1, 9.3, 14.4)):           # далёкие щелчки металла
        circ_add(x, ring(ns(0.8), 8030 + i, 320.0 + 60.0 * i, 0.4, 1.55, 0.05),
                 ns(t0))
    x += 0.06 * noise_band(n, 8040, 60.0, 2200.0, 2) * (
        0.5 + 0.5 * (0.5 + 0.5 * lfo(n, 0.1875, 1.0, 2.0)))
    x = delay_reverb(x, 8041, rt60=2.4, mix=0.34, damp=2600.0, circular=True,
                     size=1.8)
    return filt(x, "lp", 7000.0, 2, circular=True)


def g_mus_raid_loop() -> np.ndarray:
    """Рейд: 120 BPM, бас-риф на 8 половинных, бочка/жестяной/хэт, луп 12 с."""
    n = ns(12.0)
    x = np.zeros(n)
    k = kick(0.40, 9001)
    sar = snare(0.30, 9002)
    h = hat(0.09, 9003)
    for i in range(24):                                  # бочка на каждой доле
        circ_add(x, k * (1.0 if i % 2 == 0 else 0.8), ns(0.5 * i))
    for i in range(12):                                  # малый на слабой доле
        circ_add(x, sar * (0.9 if i % 2 else 0.7), ns(0.25 + 1.0 * i))
    for i in range(24):                                  # хэт восьмыми
        circ_add(x, h * (0.85 if i % 2 else 0.45), ns(0.25 * i))
    riff = (55.0, 55.0, 65.41, 55.0, 73.42, 65.41, 55.0, 61.74)
    for i, f in enumerate(riff):
        cnt = ns(1.4)
        note = pad(cnt, (f,), 9010 + i, 420.0, 0.004, 1.0, False)
        note += 0.45 * saw(cnt, f, 6) * bell(cnt, 0.006, 0.55)
        note *= env_points(cnt, [(0.0, 0.0), (0.012, 1.0), (0.8, 0.7),
                                 (cnt / SR, 0.0)])
        circ_add(x, note * 0.6, ns(1.5 * i))
    x += 0.22 * pad(n, (110.0, 130.81, 164.81), 9020, 1300.0, 0.006, 1.0, True) * (
        0.55 + 0.45 * (0.5 + 0.5 * lfo(n, 0.25, 1.0)))
    x = distort(x, 1.5, 0.0, 0.2)
    x = delay_reverb(x, 9030, rt60=1.0, mix=0.16, damp=4200.0, circular=True,
                     size=1.1)
    return filt(x, "lp", 9000.0, 2, circular=True)


# ============================================================ контракт и сборка
## Зеркало Assets.SOUND_NAMES (autoload/assets.gd) — гейт полноты сборки:
## если реестр ниже не покрывает этот список ровно, main() завершится с кодом 2.
CONTRACT = (
    "shot_pm", "shot_ak", "shot_shotgun", "shot_crossbow", "melee_swing",
    "melee_hit", "hit_flesh", "hit_wall", "explosion",
    "step_gravel_1", "step_gravel_2", "step_gravel_3", "step_grass_1",
    "step_grass_2", "step_metal_1",
    "player_hurt", "player_die", "heartbeat_loop", "breath_loop",
    "pickup_item", "pickup_artefact", "ui_click", "ui_open", "ui_close",
    "ui_deny", "quest_new", "quest_done", "levelup", "notify",
    "geiger_click", "geiger_burst", "detector_ping", "anomaly_hum",
    "anomaly_zap", "anomaly_warp", "artifact_hum", "artifact_taken",
    "dog_growl", "dog_bark", "mutant_roar", "zombie_moan", "boar_snort",
    "creature_die",
    "amb_wind_loop", "amb_zone_loop", "amb_cave_loop", "amb_danger_loop",
    "mus_menu_loop", "mus_raid_loop",
)


def registry() -> list:
    """[(имя, фабрика, луп?)] — порядок и набор совпадают с Assets.SOUND_NAMES."""
    return [
        ("shot_pm", g_shot_pm, False),
        ("shot_ak", g_shot_ak, False),
        ("shot_shotgun", g_shot_shotgun, False),
        ("shot_crossbow", g_shot_crossbow, False),
        ("melee_swing", g_melee_swing, False),
        ("melee_hit", g_melee_hit, False),
        ("hit_flesh", g_hit_flesh, False),
        ("hit_wall", g_hit_wall, False),
        ("explosion", g_explosion, False),
        ("step_gravel_1", lambda: g_step_gravel(1), False),
        ("step_gravel_2", lambda: g_step_gravel(2), False),
        ("step_gravel_3", lambda: g_step_gravel(3), False),
        ("step_grass_1", lambda: g_step_grass(1), False),
        ("step_grass_2", lambda: g_step_grass(2), False),
        ("step_metal_1", g_step_metal, False),
        ("player_hurt", g_player_hurt, False),
        ("player_die", g_player_die, False),
        ("heartbeat_loop", g_heartbeat_loop, True),
        ("breath_loop", g_breath_loop, True),
        ("pickup_item", g_pickup_item, False),
        ("pickup_artefact", g_pickup_artefact, False),
        ("ui_click", g_ui_click, False),
        ("ui_open", g_ui_open, False),
        ("ui_close", g_ui_close, False),
        ("ui_deny", g_ui_deny, False),
        ("quest_new", g_quest_new, False),
        ("quest_done", g_quest_done, False),
        ("levelup", g_levelup, False),
        ("notify", g_notify, False),
        ("geiger_click", g_geiger_click, False),
        ("geiger_burst", g_geiger_burst, False),
        ("detector_ping", g_detector_ping, False),
        ("anomaly_hum", g_anomaly_hum, False),
        ("anomaly_zap", g_anomaly_zap, False),
        ("anomaly_warp", g_anomaly_warp, False),
        ("artifact_hum", g_artifact_hum, False),
        ("artifact_taken", g_artifact_taken, False),
        ("dog_growl", g_dog_growl, False),
        ("dog_bark", g_dog_bark, False),
        ("mutant_roar", g_mutant_roar, False),
        ("zombie_moan", g_zombie_moan, False),
        ("boar_snort", g_boar_snort, False),
        ("creature_die", g_creature_die, False),
        ("amb_wind_loop", g_amb_wind_loop, True),
        ("amb_zone_loop", g_amb_zone_loop, True),
        ("amb_cave_loop", g_amb_cave_loop, True),
        ("amb_danger_loop", g_amb_danger_loop, True),
        ("mus_menu_loop", g_mus_menu_loop, True),
        ("mus_raid_loop", g_mus_raid_loop, True),
    ]


# ============================================================ сборка и отчёт
def make_sound(fac, loop: bool) -> np.ndarray:
    """Сгенерировать и привести к норме: луп -3 dBFS (без фейдов, шов чистый),
    одношот -1.5 dBFS с микрофейдами 2 мс / 5 мс."""
    x = dc_block(np.asarray(fac(), np.float64))
    if loop:
        return normalize(x, PEAK_LOOP)
    return fade(normalize(x, PEAK_ONE))


def _stats(name: str, x: np.ndarray, loop: bool) -> dict:
    return {"name": name, "dur": len(x) / SR, "peak": peak(x), "rms": rms(x),
            "dc": float(np.mean(x)), "clips": int(np.sum(np.abs(x) > 0.999)),
            "loop": loop, "seam": (seam_db(x) if loop else None), "x": x}


def _spectrum_db(x: np.ndarray, bands: int) -> np.ndarray:
    """Сводный спектр для картинки: max по лог-полосам 40 Гц..16 кГц."""
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    mag = np.abs(np.fft.rfft(x * np.hanning(len(x)))) / max(len(x), 1)
    edges = np.geomspace(40.0, 16000.0, bands + 1)
    out = []
    for k in range(bands):
        m = (f >= edges[k]) & (f < edges[k + 1])
        out.append(float(np.max(mag[m])) if m.any() else 1e-9)
    return 20.0 * np.log10(np.maximum(np.array(out), 1e-9))


def _summary_png(rows, path: str, cell: int = 260, height: int = 100,
                 cols: int = 7) -> str:
    """PNG-сводка waveform + спектр по всем звукам (визуальная приёмка)."""
    bands = cell - 12
    lines = max(1, (len(rows) + cols - 1) // cols)
    img = Image.new("RGB", (cols * cell, lines * height), (18, 18, 22))
    d = ImageDraw.Draw(img)
    for i, s in enumerate(rows):
        x0, y0 = (i % cols) * cell, (i // cols) * height
        x = s["x"]
        d.rectangle([x0, y0, x0 + cell - 1, y0 + height - 1], outline=(58, 58, 68))
        d.text((x0 + 5, y0 + 3),
               "%s  %.2fс  %+.1fдБ" % (s["name"], s["dur"], dbfs(s["peak"])),
               fill=(216, 200, 152))
        m = max(1, (len(x) + bands - 1) // bands)
        mid = y0 + height * 0.52
        amp = (height * 0.30) / max(peak(x), 1e-9)
        hi, lo = [], []
        for k in range(bands):
            seg = x[k * m:(k + 1) * m]
            seg = seg if len(seg) else np.zeros(1)
            hi.append(mid - float(np.max(seg)) * amp)
            lo.append(mid - float(np.min(seg)) * amp)
        d.line([(x0 + 6, mid), (x0 + cell - 6, mid)], fill=(70, 70, 84))
        d.line([(x0 + 6 + k, hi[k]) for k in range(bands)], fill=(150, 190, 235))
        d.line([(x0 + 6 + k, lo[k]) for k in range(bands)], fill=(150, 190, 235))
        sp = _spectrum_db(x, bands)
        sp = np.clip((sp - float(np.max(sp)) + 42.0) / 42.0, 0.0, 1.0)
        top = y0 + height - 6.0
        d.line([(x0 + 6 + k, top - float(sp[k]) * height * 0.36) for k in range(bands)],
               fill=(240, 170, 90))
    img.save(path)
    return path


def main(argv=None) -> int:
    """Сгенерировать все звуки контракта в assets/audio + сводку в _out."""
    args = list(sys.argv[1:] if argv is None else argv)
    only = [a for a in args if not a.startswith("-")]
    want_png = "--no-png" not in args
    os.makedirs(OUT, exist_ok=True)
    reg = registry()
    names = [e[0] for e in reg]
    missing = [n for n in CONTRACT if n not in names]
    extra = [n for n in names if n not in CONTRACT]
    swap = [n for n, _f, l in reg if l != n.endswith("_loop")]
    loops = sum(1 for _n, _f, l in reg if l)
    print("gen_audio: контракт %d, реестр %d (одношотов %d, лупов %d)"
          % (len(CONTRACT), len(names), len(names) - loops, loops))
    if missing or extra or swap:
        print("  нет в реестре  : " + (", ".join(missing) or "-"))
        print("  лишние в реестре: " + (", ".join(extra) or "-"))
        print("  путаница лупов : " + (", ".join(swap) or "-"))
        return 2
    picked = [e for e in reg if not only or e[0] in only]
    if not picked:
        print("  нечего генерировать (фильтр: %s)" % ", ".join(only))
        return 2
    print("  %-16s %7s %8s %8s %10s %6s %8s"
          % ("звук", "длит,с", "пик,дБ", "RMS,дБ", "DC", "клипы", "шов,дБ"))
    rows = []
    t0 = time.time()
    for name, fac, loop in picked:
        x = make_sound(fac, loop)
        to_wav(name, x)
        s = _stats(name, x, loop)
        rows.append(s)
        print("  %-16s %7.2f %+8.2f %+8.2f %+10.1e %6d %8s"
              % (name, s["dur"], dbfs(s["peak"]), dbfs(s["rms"]), s["dc"],
                 s["clips"],
                 "-" if s["seam"] is None else "%+.1f" % s["seam"]))
    if want_png and rows:
        print("  сводка: "
              + _summary_png(rows, os.path.join(OUT, "audio_waveforms.png")))
    print("готово: %d WAV в %s за %.1f с" % (len(rows), P.AUD, time.time() - t0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())














