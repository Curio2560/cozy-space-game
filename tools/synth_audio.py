#!/usr/bin/env python3
"""Sintetiza os sons e as músicas do Correio Cósmico (sem samples externos: são do projeto,
sem licenças de terceiros). Gera WAV mono 16-bit em assets/audio/.

Uso: python3 tools/synth_audio.py

Para trocar por sons de um pack (p. ex. CC0), basta pôr ficheiros com o mesmo nome."""
import math, os, random, struct, wave

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")


def write(name, samples, folder="sfx"):
    path = os.path.join(OUT, folder, name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    k = 0.89 / peak if peak > 0.89 else 1.0
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * k)) * 32767)) for s in samples))
    print(path, f"{len(samples) / RATE:.2f}s")


def n(sec):
    return int(sec * RATE)


def env(i, total, attack=0.005, release=None):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    if release is None:
        return a * (1.0 - i / total)
    rel_start = total - n(release)
    return a * (1.0 if i < rel_start else max(0.0, (total - i) / max(1, n(release))))


def lowpass(xs, k):
    out, y = [], 0.0
    for x in xs:
        y += k * (x - y)
        out.append(y)
    return out


rnd = random.Random(7)


def noise(count):
    return [rnd.uniform(-1, 1) for _ in range(count)]


# Efeitos ------------------------------------------------------------------------------------

def mech_shot():
    N = n(0.09)
    ph, out = 0.0, []
    nz = lowpass(noise(N), 0.35)
    for i in range(N):
        f = 520 - 380 * i / N
        ph += f / RATE
        sq = 1.0 if (ph % 1.0) < 0.5 else -1.0
        out.append((0.45 * sq + 0.55 * nz[i]) * (1 - i / N) ** 2)
    return out


def laser():
    N = n(0.16)
    ph, out = 0.0, []
    for i in range(N):
        f = 1800 * (1 - i / N) ** 1.6 + 300
        ph += f / RATE
        out.append(math.sin(2 * math.pi * ph) * (1 - i / N) * 0.8)
    return out


def hit():
    N = n(0.07)
    nz = lowpass(noise(N), 0.25)
    return [nz[i] * (1 - i / N) ** 1.5 for i in range(N)]


def slam():
    N = n(0.6)
    nz = lowpass(noise(N), 0.08)
    out, ph = [], 0.0
    for i in range(N):
        f = 90 - 50 * i / N
        ph += f / RATE
        e = math.exp(-5.5 * i / N)
        out.append((math.sin(2 * math.pi * ph) * 0.9 + nz[i] * 0.8) * e)
    return out


def boss_roar():
    N = n(1.3)
    out, ph = [], 0.0
    nz = lowpass(noise(N), 0.15)
    for i in range(N):
        t = i / RATE
        f = 140 - 60 * i / N + 9 * math.sin(2 * math.pi * 7 * t)
        ph += f / RATE
        saw = 2 * (ph % 1.0) - 1
        out.append((0.7 * saw + 0.4 * nz[i]) * env(i, N, 0.08, 0.5))
    return lowpass(out, 0.3)


def tone(freq, sec, shape="sine", vol=0.6, attack=0.005, release=0.05):
    N = n(sec)
    out, ph = [], 0.0
    for i in range(N):
        ph += freq / RATE
        if shape == "sine":
            s = math.sin(2 * math.pi * ph)
        elif shape == "square":
            s = 1.0 if (ph % 1.0) < 0.5 else -1.0
        else:  # triângulo
            s = 4 * abs((ph % 1.0) - 0.5) - 1
        out.append(s * vol * env(i, N, attack, release))
    return out


def warn():
    return tone(880, 0.14, "triangle") + [0.0] * n(0.06) + tone(660, 0.2, "triangle")


def wave_horn():
    out = []
    for f in (220, 277, 330):
        out += lowpass(tone(f, 0.24, "square", 0.45, 0.02, 0.06), 0.25)
    return out


def ship():
    N = n(2.4)
    nz = noise(N)
    out, y = [], 0.0
    for i in range(N):
        k = 0.02 + 0.25 * (i / N)
        y += k * (nz[i] - y)
        out.append(y * env(i, N, 0.4, 0.6) * 1.6)
    return out


def coin():
    return tone(988, 0.07, "square", 0.35) + tone(1319, 0.16, "square", 0.35, 0.002, 0.1)


def boom():
    N = n(1.1)
    nz = lowpass(noise(N), 0.06)
    return [nz[i] * math.exp(-3.2 * i / N) * 2.0 for i in range(N)]


def click():
    return tone(1500, 0.025, "sine", 0.5, 0.001, 0.015)


# Música -------------------------------------------------------------------------------------

def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def pluck(freq, sec, vol):
    N = n(sec)
    out, ph = [], 0.0
    for i in range(N):
        ph += freq / RATE
        s = math.sin(2 * math.pi * ph) + 0.25 * math.sin(4 * math.pi * ph)
        out.append(s * vol * math.exp(-4.0 * i / N) * min(1.0, i / 60))
    return out


def pad(freq, sec, vol):
    N = n(sec)
    out, p1, p2 = [], 0.0, 0.0
    for i in range(N):
        p1 += freq / RATE
        p2 += freq * 1.004 / RATE
        s = 4 * abs((p1 % 1.0) - 0.5) - 1 + 4 * abs((p2 % 1.0) - 0.5) - 1
        out.append(s * vol * env(i, N, sec * 0.3, sec * 0.4))
    return out


def mix_into(buf, at, xs):
    for i, x in enumerate(xs):
        j = at + i
        if j < len(buf):
            buf[j] += x


def song(chords, bpm, bars_per_chord, arp, pad_vol, pluck_vol, bell=False):
    beat = 60.0 / bpm
    bar = beat * 4
    total = n(bar * bars_per_chord * len(chords))
    buf = [0.0] * total
    t = 0
    rng = random.Random(3)
    for chord in chords:
        for b in range(bars_per_chord):
            start = n(t * bar)
            for note in chord[:3]:
                mix_into(buf, start, pad(midi(note - 12), bar, pad_vol))
            for k, idx in enumerate(arp):
                note = chord[idx % len(chord)] + (12 if idx >= len(chord) else 0)
                mix_into(buf, start + n(k * bar / len(arp)), pluck(midi(note), bar / len(arp) * 1.8, pluck_vol))
            if bell and rng.random() < 0.5:
                mix_into(buf, start + n(beat * rng.choice([1, 2, 3])), pluck(midi(chord[0] + 24), beat * 2, pluck_vol * 0.5))
            t += 1
    # Cauda suave para o loop não estalar.
    fade = n(0.05)
    for i in range(fade):
        buf[i] *= i / fade
        buf[-1 - i] *= i / fade
    return lowpass(buf, 0.45)


def main():
    for name, fn in [("mech_shot", mech_shot), ("laser", laser), ("hit", hit), ("slam", slam),
                     ("boss_roar", boss_roar), ("warn", warn), ("wave", wave_horn), ("ship", ship),
                     ("coin", coin), ("boom", boom), ("click", click)]:
        write(name, fn())
    # Dia: Cmaj7 – Am7 – Fmaj7 – G6, calma, arpejo a 84 bpm.
    day = [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 64]]
    write("day", song(day, 84, 4, [0, 1, 2, 3, 4, 2, 1, 3], 0.05, 0.16), "music")
    # Noite: Am – F – C – Em, mais lenta e escura, com sinos raros.
    night = [[57, 60, 64, 67], [53, 57, 60, 64], [48, 52, 55, 59], [52, 55, 59, 62]]
    write("night", song(night, 66, 4, [0, 2, 1, 3], 0.07, 0.11, bell=True), "music")


main()
