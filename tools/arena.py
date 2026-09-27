#!/usr/bin/env python3
"""L'arene : un groupe d'un niveau donne, reposé, contre une espece, N
fois. Pour regler l'equilibre sans dependre des errances du pilote.

    python3 tools/arena.py NIVEAU ESPECE [ETAGE] [N]
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T                            # noqa: E402


def arena(level, kind, floor=2, n=12):
    g = T.Game()
    T.create_party(g)
    base0 = g.addr("Heroes")
    for i in range(T.NH):
        a6 = base0 + i * T.HR["hr_SIZEOF"]
        for _ in range(level - 1):
            g.call(g.addr("TrainHero"), a6=a6)
    g.setw("Level", floor)
    wins, rounds, deaths = 0, 0, 0
    for _ in range(n):
        T.heal(g)
        for i in range(T.NH):                    # et les sorts rendus
            g.call(g.addr("FillSlots"), a6=base0 + i * T.HR["hr_SIZEOF"])
        g.setw("GameOver", 0)
        T.meet(g, kind)
        grp = g.w("GroupN")
        g.key(T.K_A)                             # on degaine
        for _ in range(400):
            if not g.w("InCombat") or g.w("GameOver"):
                break
            g.key(T.K_A)
            rounds += 1
        dead = sum(1 for i in range(T.NH) if g.hero(i, "hr_Hp") <= 0)
        deaths += dead
        if not g.w("GameOver") and not g.w("InCombat"):
            wins += 1
        g.setw("InCombat", 0)
        g.setw("GameOver", 0)
    hps = [g.hero(i, "hr_HpMax") for i in range(T.NH)]
    print(f"niveau {level} contre {kind} (groupe jusqu'a {grp}) : "
          f"{wins}/{n} victoires, {deaths / n:.1f} morts par combat, "
          f"{rounds / n:.0f} touches ; PV max {hps}")
    return wins, deaths


if __name__ == "__main__":
    a = [int(x) for x in sys.argv[1:]]
    arena(a[0], a[1], *(a[2:]))
