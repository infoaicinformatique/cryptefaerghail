#!/usr/bin/env python3
"""Rejoue data/music.mod avec la meme semantique que src/ptreplay.i et
ecrit un WAV. Sert a la fois de verification du module et d'apercu sonore.

    python3 tools/render_mod.py [secondes] [sortie.wav] [module.mod]

Le replayer 68k est cadence par le timer A du CIA-B, a BPM x 2 / 5 tics
par seconde -- 50 Hz au tempo par defaut de 125. Ce modele suit la meme
cadence, effet Fxx compris : au-dela de 32, le parametre est un tempo.
Effets simules : 0xy arpege, 1xx/2xx portamento, 3xx portamento vers la
note, 4xy vibrato, 5xy et 6xy leurs combinaisons avec le volume, 7xy
tremolo, 9xx depart dans le sample, Axy volume slide, Bxx saut, Cxx
volume, Dxx break, Fxx vitesse, et les commandes etendues E1x/E2x
glissandos fins, E6x boucle de motif, E9x relance, EAx/EBx volume fin,
ECx coupure, EDx note retardee, EEx ligne retenue -- exactement le
sous-ensemble implemente en assembleur.

Les deux implementations sont donc ecrites deux fois, en 68k et en
Python, a partir de la meme lecture du format : quand elles divergent,
l'une des deux a tort, et tools/test_replay.py dit laquelle.
"""
import os
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL_CLOCK = 3546895                      # Hz, horloge Paula en PAL
BPM_DEFAULT = 125                        # tempo d'un module, en BPM
TICK_HZ = BPM_DEFAULT * 2 / 5            # 50 Hz au tempo par defaut
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


# Le quart de sinusoide de ProTracker, comme dans src/ptreplay.i
SINE = [0, 24, 49, 74, 97, 120, 141, 161, 180, 197, 212, 224, 235, 244,
        250, 253, 255, 253, 250, 244, 235, 224, 212, 197, 180, 161, 141,
        120, 97, 74, 49, 24]


class Channel:
    def __init__(self):
        self.data, self.pos, self.step = [], 0.0, 0.0
        self.rep, self.replen = 0, 0
        self.period, self.volume = 0, 0
        self.effect, self.param = 0, 0
        self.porta, self.portaspd, self.arp = 0, 0, 0
        self.playing = False
        self.vibpos, self.vibcmd = 0, 0
        self.trempos, self.tremcmd = 0, 0
        self.offset = 0
        self.retrig, self.cutat, self.delayto = 0, -1, -1
        self.heldper, self.heldins = 0, 0
        self.realvol = 0

    def restart(self, at=0):
        self.pos = float(at)
        self.playing = True

    def wave(self, pos, depth, shift):
        v = SINE[(pos >> 2) & 31] * depth >> shift
        return -v if pos & 32 else v

    def note_index(self):                            # index dans la table
        for i, p in enumerate(PERIODS):
            if self.period >= p:
                return i
        return len(PERIODS) - 1


def render(mod, seconds, path):
    chans = [Channel() for _ in range(4)]
    speed, tickcnt, row, songpos = 6, 6, 0, 0
    bpm = BPM_DEFAULT
    out = []
    samples_per_tick = int(RATE / TICK_HZ)
    total_ticks = int(seconds * TICK_HZ)

    loop_row, loop_cnt, pattdelay = 0, 0, 0
    for _ in range(total_ticks):
        if tickcnt >= speed and pattdelay:           # EEx : la ligne dure
            tickcnt, pattdelay = 0, pattdelay - 1
        if tickcnt >= speed:                         # nouvelle ligne
            tickcnt = 0
            pattern = mod.patterns[mod.order[songpos]]
            do_jump = do_break = None
            do_loop = False
            was_playing = [c.playing for c in chans]
            old_period = [c.period for c in chans]
            for c in range(4):
                off = row * 16 + c * 4
                b0, b1, b2, b3 = pattern[off:off + 4]
                per = ((b0 & 0x0f) << 8) | b1
                ins = (b0 & 0xf0) | (b2 >> 4)
                fx, param = b2 & 0x0f, b3
                ch = chans[c]
                ch.effect, ch.param = fx, param
                ch.cutat, ch.delayto, ch.retrig = -1, -1, 0
                if ins:
                    info = mod.instruments[ins - 1]
                    ch.data = info["data"]
                    ch.rep = info["rep"] * 2
                    ch.replen = info["replen"] * 2
                    ch.volume = info["vol"]
                delayed = fx == 0xe and (param >> 4) == 0xd and (param & 0xf)
                if per and not delayed:
                    if fx in (3, 5):
                        ch.porta = per
                    else:
                        ch.period = per
                        ch.pos, ch.arp, ch.playing = 0.0, 0, True
                        if fx not in (4, 6):
                            ch.vibpos = 0
                        ch.trempos = 0
                if fx == 0x3 and param:
                    ch.portaspd = param
                elif fx == 0x4 and param:
                    ch.vibcmd = param
                elif fx == 0x7 and param:
                    ch.tremcmd = param
                elif fx == 0xc:
                    ch.volume = min(64, param)
                elif fx == 0xf and param:
                    if param >= 32:                  # Fxx : au-dela de 32,
                        bpm = param                  # c'est un tempo, et la
                        samples_per_tick = int(RATE / (bpm * 2 / 5))
                    else:                            # cadence change ; en
                        speed = param                # deca, des tics par ligne
                elif fx == 0xb:
                    do_jump = param
                elif fx == 0xd:
                    do_break = (param >> 4) * 10 + (param & 0x0f)
                if fx == 0x9:                        # depart dans le sample
                    if param:
                        ch.offset = param
                    if per and ch.offset * 256 < len(ch.data):
                        ch.restart(ch.offset * 256)
                if fx == 0xe:                        # commandes etendues
                    sub, y = param >> 4, param & 0x0f
                    if sub == 0x1:
                        ch.period = max(113, ch.period - y)
                    elif sub == 0x2:
                        ch.period = min(856, ch.period + y)
                    elif sub == 0x6:
                        if y == 0:
                            loop_row = row
                        elif loop_cnt == 0:
                            loop_cnt, do_loop = y, True
                        else:
                            loop_cnt -= 1
                            do_loop = loop_cnt > 0
                    elif sub == 0x9:
                        ch.retrig = y
                    elif sub == 0xa:
                        ch.volume = min(64, ch.volume + y)
                    elif sub == 0xb:
                        ch.volume = max(0, ch.volume - y)
                    elif sub == 0xc:
                        ch.cutat = y
                    elif sub == 0xd and y:
                        ch.delayto, ch.heldper = y, per
                        ch.playing = was_playing[c]  # la note attend
                        ch.period = old_period[c]
                    elif sub == 0xe:
                        pattdelay = y
                ch.realvol = ch.volume
            row += 1
            if do_break is not None:
                row, songpos = do_break, songpos + 1
            elif do_jump is not None:
                row, songpos = 0, do_jump
            elif do_loop:
                row = loop_row
            elif row >= 64:
                row, songpos = 0, songpos + 1
            if songpos >= mod.songlen:
                songpos = 0
        else:                                        # ticks intermediaires
            for ch in chans:
                fx, param = ch.effect, ch.param
                ch.volume = ch.realvol
                if tickcnt == ch.cutat:
                    ch.volume = ch.realvol = 0
                if tickcnt == ch.delayto and ch.heldper:
                    ch.period, ch.delayto = ch.heldper, -1
                    ch.pos, ch.arp, ch.playing = 0.0, 0, True
                    ch.vibpos = ch.trempos = 0
                if ch.retrig and tickcnt % ch.retrig == 0:
                    ch.restart()
                if fx == 0x0 and param:
                    ch.arp = (ch.arp + 1) % 3
                elif fx == 0x1:
                    ch.period = max(113, ch.period - param)
                elif fx == 0x2:
                    ch.period = min(856, ch.period + param)
                elif fx in (0x3, 0x5) and ch.porta:
                    if ch.period > ch.porta:
                        ch.period = max(ch.porta, ch.period - ch.portaspd)
                    elif ch.period < ch.porta:
                        ch.period = min(ch.porta, ch.period + ch.portaspd)
                if fx in (0xa, 0x5, 0x6):
                    up, down = param >> 4, param & 0x0f
                    ch.realvol = min(64, ch.realvol + up) if up \
                        else max(0, ch.realvol - down)
                    ch.volume = ch.realvol
                if fx == 0x7 and ch.tremcmd:
                    d = ch.wave(ch.trempos, ch.tremcmd & 0x0f, 6)
                    ch.volume = max(0, min(64, ch.realvol + d))
                    ch.trempos = (ch.trempos + 2 * (ch.tremcmd >> 4)) & 63
        tickcnt += 1

        # --- periode reellement envoyee a Paula (arpege compris) ---
        for ch in chans:
            per = ch.period
            if ch.effect in (0x4, 0x6) and ch.vibcmd:
                per += ch.wave(ch.vibpos, ch.vibcmd & 0x0f, 7)
                per = max(113, min(856, per))
                if tickcnt:                          # pas au tic zero
                    ch.vibpos = (ch.vibpos + 2 * (ch.vibcmd >> 4)) & 63
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
    name = sys.argv[3] if len(sys.argv) > 3 else "data/music.mod"
    mod = Module(open(os.path.join(ROOT, name), "rb").read())
    print(f"module : {mod.npat} patterns, ordre {mod.order[:mod.songlen]}, "
          f"{sum(1 for i in mod.instruments if i['length'])} instruments")
    render(mod, seconds, path)
