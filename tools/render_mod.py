#!/usr/bin/env python3
"""Rejoue data/music.mod avec la meme semantique que src/ptreplay.i et
ecrit un WAV. Sert a la fois de verification du module et d'apercu sonore.

    python3 tools/render_mod.py [secondes] [sortie.wav]

Le replayer 68k est cadence par le VBlank (50 Hz) : c'est aussi le cas ici.
Effets simules : 0xy arpege, 1xx/2xx portamento, 3xx portamento vers la note,
Axy volume slide, Cxx volume, Fxx vitesse, Bxx saut, Dxx break -- exactement
le sous-ensemble implemente en assembleur.
"""
import os
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL_CLOCK = 3546895                      # Hz, horloge Paula en PAL
TICK_HZ = 50                             # cadence VBlank
RATE = 22050

PERIODS = [
    856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
    428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
    214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113,
]


class Module:
    def __init__(self, raw):
        assert raw[1080:1084] == b"M.K.", "signature M.K. absente"
        self.instruments = []
        for i in range(31):
            off = 20 + i * 30
            length = struct.unpack(">H", raw[off + 22:off + 24])[0]
            vol = raw[off + 25]
            rep = struct.unpack(">H", raw[off + 26:off + 28])[0]
            replen = struct.unpack(">H", raw[off + 28:off + 30])[0]
            self.instruments.append(dict(length=length, vol=vol,
                                         rep=rep, replen=replen))
        self.songlen = raw[950]
        self.order = list(raw[952:952 + 128])
        npat = max(self.order[:self.songlen]) + 1
        self.patterns = []
        for p in range(npat):
            off = 1084 + p * 1024
            self.patterns.append(raw[off:off + 1024])
        pos = 1084 + npat * 1024
        for ins in self.instruments:                 # donnees des samples
            n = ins["length"] * 2
            ins["data"] = [v - 256 if v > 127 else v for v in raw[pos:pos + n]]
            pos += n
        assert pos == len(raw), f"taille inattendue : {pos} != {len(raw)}"
        self.npat = npat


class Channel:
    def __init__(self):
        self.data, self.pos, self.step = [], 0.0, 0.0
        self.rep, self.replen = 0, 0
        self.period, self.volume = 0, 0
        self.effect, self.param = 0, 0
        self.porta, self.portaspd, self.arp = 0, 0, 0
        self.playing = False

    def note_index(self):                            # index dans la table
        for i, p in enumerate(PERIODS):
            if self.period >= p:
                return i
        return len(PERIODS) - 1


def render(mod, seconds, path):
    chans = [Channel() for _ in range(4)]
    speed, tickcnt, row, songpos = 6, 6, 0, 0
    out = []
    samples_per_tick = int(RATE / TICK_HZ)
    total_ticks = int(seconds * TICK_HZ)

    for _ in range(total_ticks):
        if tickcnt >= speed:                         # nouvelle ligne
            tickcnt = 0
            pattern = mod.patterns[mod.order[songpos]]
            do_jump = do_break = None
            for c in range(4):
                off = row * 16 + c * 4
                b0, b1, b2, b3 = pattern[off:off + 4]
                per = ((b0 & 0x0f) << 8) | b1
                ins = (b0 & 0xf0) | (b2 >> 4)
                fx, param = b2 & 0x0f, b3
                ch = chans[c]
                ch.effect, ch.param = fx, param
                if ins:
                    info = mod.instruments[ins - 1]
                    ch.data = info["data"]
                    ch.rep = info["rep"] * 2
                    ch.replen = info["replen"] * 2
                    ch.volume = info["vol"]
                if per:
                    if fx in (3, 5):
                        ch.porta = per
                    else:
                        ch.period = per
                        ch.pos, ch.arp, ch.playing = 0.0, 0, True
                if fx == 0x3 and param:
                    ch.portaspd = param
                elif fx == 0xc:
                    ch.volume = min(64, param)
                elif fx == 0xf and 0 < param < 32:
                    speed = param
                elif fx == 0xb:
                    do_jump = param
                elif fx == 0xd:
                    do_break = (param >> 4) * 10 + (param & 0x0f)
            row += 1
            if do_break is not None:
                row, songpos = do_break, songpos + 1
            elif do_jump is not None:
                row, songpos = 0, do_jump
            elif row >= 64:
                row, songpos = 0, songpos + 1
            if songpos >= mod.songlen:
                songpos = 0
        else:                                        # ticks intermediaires
            for ch in chans:
                fx, param = ch.effect, ch.param
                if fx == 0x0 and param:
                    ch.arp = (ch.arp + 1) % 3
                elif fx == 0x1:
                    ch.period = max(113, ch.period - param)
                elif fx == 0x2:
                    ch.period = min(856, ch.period + param)
                elif fx == 0x3 and ch.porta:
                    if ch.period > ch.porta:
                        ch.period = max(ch.porta, ch.period - ch.portaspd)
                    elif ch.period < ch.porta:
                        ch.period = min(ch.porta, ch.period + ch.portaspd)
                elif fx == 0xa:
                    up, down = param >> 4, param & 0x0f
                    ch.volume = min(64, ch.volume + up) if up \
                        else max(0, ch.volume - down)
        tickcnt += 1

        # --- periode reellement envoyee a Paula (arpege compris) ---
        for ch in chans:
            per = ch.period
            if ch.effect == 0 and ch.param and ch.arp:
                shift = (ch.param >> 4) if ch.arp == 1 else (ch.param & 0x0f)
                idx = min(len(PERIODS) - 1, ch.note_index() + shift)
                per = PERIODS[idx]
            ch.step = (PAL_CLOCK / per) / RATE if per else 0.0

        # --- mixage d'un tick, en stereo comme Paula (0/3 a gauche) ---
        for _ in range(samples_per_tick):
            left = right = 0.0
            for c, ch in enumerate(chans):
                if not ch.playing or not ch.data:
                    continue
                if ch.replen > 2:                    # sample boucle
                    if ch.pos >= ch.rep + ch.replen:
                        ch.pos -= ch.replen
                elif ch.pos >= len(ch.data):         # one-shot termine
                    ch.playing = False
                    continue
                v = ch.data[int(ch.pos)] * ch.volume / 64.0
                ch.pos += ch.step
                if c in (0, 3):
                    left += v
                else:
                    right += v
            out.append((left, right))

    peak = max(max(abs(l), abs(r)) for l, r in out) or 1.0
    gain = 0.89 * 32767 / peak
    frames = []
    for l, r in out:
        frames.append(int(l * gain))
        frames.append(int(r * gain))
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(struct.pack(f"<{len(frames)}h", *frames))
    print(f"{path} : {len(out) / RATE:.1f} s stereo, crete brute {peak:.0f} "
          f"(4 voies x 127 max = 508), normalise a 89 %")


if __name__ == "__main__":
    seconds = float(sys.argv[1]) if len(sys.argv) > 1 else 20.0
    path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "music.wav")
    mod = Module(open(os.path.join(ROOT, "data", "music.mod"), "rb").read())
    print(f"module : {mod.npat} patterns, ordre {mod.order[:mod.songlen]}, "
          f"{sum(1 for i in mod.instruments if i['length'])} instruments")
    render(mod, seconds, path)
