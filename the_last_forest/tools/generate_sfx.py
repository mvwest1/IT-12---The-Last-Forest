"""Generates the game's sound effects as small 16-bit mono WAV files
(synthesised, so every sound is original and license-free).
Run from the project root:  python the_last_forest/tools/generate_sfx.py
"""
import math, random, struct, wave, os

RATE = 22050
OUT = "the_last_forest/audio"
random.seed(7)


def env(i, n, attack=0.01, release=0.6):
    t = i / RATE
    dur = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = max(0.0, 1.0 - max(0.0, t - (dur * (1 - release))) / (dur * release)) if release > 0 else 1.0
    return a * r


def tone(freqs, dur, vol=0.5, wave_kind="sine", attack=0.005, release=0.7, slide=0.0):
    n = int(dur * RATE)
    out = []
    ph = 0.0
    for i in range(n):
        f = freqs[min(len(freqs) - 1, int(i / n * len(freqs)))] * (1 + slide * i / n)
        ph += 2 * math.pi * f / RATE
        if wave_kind == "sine":
            v = math.sin(ph)
        elif wave_kind == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        else:  # soft square
            v = math.tanh(3 * math.sin(ph)) * 0.6
        out.append(v * vol * env(i, n, attack, release))
    return out


def noise(dur, vol=0.3, lp=0.15, attack=0.005, release=0.9):
    n = int(dur * RATE)
    out, last = [], 0.0
    for i in range(n):
        last += lp * (random.uniform(-1, 1) - last)
        out.append(last * vol * 3 * env(i, n, attack, release))
    return out


def mix(*parts, offsets=None):
    offsets = offsets or [0] * len(parts)
    n = max(len(p) + int(o * RATE) for p, o in zip(parts, offsets))
    out = [0.0] * n
    for p, o in zip(parts, offsets):
        s = int(o * RATE)
        for i, v in enumerate(p):
            out[s + i] += v
    return out


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(v) for v in samples))
    k = min(1.0, 0.89 / peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * k)) * 32767)) for v in samples))
    print("wrote", name)


C5, E5, G5, C6, E6, G6 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0

save("seed_pickup", mix(tone([E5], 0.07, 0.5, "tri"), tone([C6], 0.12, 0.5, "tri"), offsets=[0, 0.06]))
save("plant", mix(noise(0.18, 0.5, 0.05), tone([196, 262], 0.25, 0.35, "sine", release=0.8), offsets=[0, 0.05]))
save("tree_grown", mix(tone([C5], 0.14, 0.4, "tri"), tone([E5], 0.14, 0.4, "tri"),
                       tone([G5], 0.14, 0.4, "tri"), tone([C6], 0.35, 0.45, "tri"),
                       offsets=[0, 0.1, 0.2, 0.3]))
save("shoo", noise(0.3, 0.5, 0.35, attack=0.05, release=0.8))
save("lever", mix(noise(0.04, 0.6, 0.6), tone([300], 0.08, 0.4, "square", release=0.9), offsets=[0, 0.02]))
save("water", mix(*[tone([random.uniform(700, 1300)], 0.06, 0.25, "sine", slide=0.6) for _ in range(5)],
                  offsets=[i * 0.05 for i in range(5)]))
save("hurt", tone([330, 247], 0.25, 0.45, "square", release=0.6, slide=-0.3))
save("ui_click", tone([880], 0.05, 0.35, "tri", release=0.9))
save("card_open", mix(noise(0.12, 0.35, 0.3, attack=0.02), tone([E6], 0.18, 0.15, "sine"), offsets=[0, 0.04]))
save("quiz_done", mix(tone([G5], 0.1, 0.4, "tri"), tone([C6], 0.25, 0.4, "tri"), offsets=[0, 0.09]))
save("stage_clear", mix(tone([C5], 0.15, 0.4, "tri"), tone([E5], 0.15, 0.4, "tri"), tone([G5], 0.15, 0.4, "tri"),
                        tone([C6], 0.15, 0.4, "tri"), tone([E6, G6], 0.6, 0.45, "tri"),
                        offsets=[0, 0.12, 0.24, 0.36, 0.5]))
save("jump", tone([392, 523], 0.12, 0.35, "tri", slide=0.3))
