# Démo AGA — Amiga 1200 / AmigaOS 3.1+

Squelette de démo 68k **entièrement assemblable depuis Linux ou macOS**, écrit
en assembleur Motorola pour `vasm`, lié en exécutable *hunk* Amiga par `vlink`.

Ce qu'elle affiche : un dégradé arc-en-ciel plein écran généré **ligne par
ligne par le copper en 24 bits réels** (fonction AGA), plus une boule affichée
par un **sprite matériel** suivant une trajectoire de Lissajous. Sortie par le
bouton gauche de la souris.

## Cible

| | |
|---|---|
| Machine | Amiga 1200 (chipset AGA), 68020+ |
| Système | AmigaOS 3.0 / 3.1 et supérieur (`graphics.library` V39) |
| Écran | PAL lores 320×256, 0 bitplane (le fond vient du copper) |
| Mémoire | quelques Ko de Chip (2 copperlists + sprite) |

## Compilation

```sh
make toolchain     # télécharge et compile vasm + vlink dans tools/bin (une fois)
make               # produit bin/AGADemo
```

`make toolchain` récupère les sources de Frank Wille
(<http://sun.hasenbraten.de/vasm/>, <http://sun.hasenbraten.de/vlink/>) et les
compile avec `gcc`. Si `vasmm68k_mot` et `vlink` sont déjà dans votre `PATH`,
`make` les utilise directement.

Régénérer les données (table sinus, pixels du sprite) :

```sh
make data          # Python 3, réécrit src/sine.i et src/sprite.i
```

## Exécution

- **FS-UAE / WinUAE** : configurez une A1200 (Kickstart 3.1, AGA, 68020, 2 Mo
  Chip), montez le dossier `bin/` comme disque dur, puis depuis le Shell :
  `AGADemo`.
- **Machine réelle** : copiez `bin/AGADemo` et lancez-le **depuis un Shell**
  (le programme ne gère pas le message `WBStartup` d'un lancement depuis le
  Workbench).

## Structure

```
src/demo.s       programme principal (prise de contrôle, copper, sprite)
src/hardware.i   equates des registres custom et LVO exec/graphics
src/sine.i       table sinus 256 entrées         (généré)
src/sprite.i     boule 16×16, 2 plans            (généré)
tools/gen_data.py  générateur des deux fichiers ci-dessus
scripts/get-toolchain.sh  installation de vasm + vlink
```

## Points techniques

**Prise de contrôle propre.** `OpenLibrary("graphics.library", 39)`,
`Forbid()`, `LoadView(NULL)` + deux `WaitTOF()`, `OwnBlitter()`, sauvegarde de
`INTENAR` / `DMACONR` et de `GfxBase->copinit`. À la sortie, tout est rendu :
copperlist système restaurée via `COP1LC` + strobe `COPJMP1`, DMA et
interruptions remis dans leur état, `DisownBlitter()`, `LoadView(ancienne vue)`,
`RethinkDisplay()`, `CloseLibrary()`, `Permit()`.

**Couleur 24 bits AGA.** Chaque ligne écrit `COLOR00` deux fois : d'abord avec
`BPLCON3` bit 9 (LOCT) à 0 pour les quartets de poids fort, puis avec LOCT à 1
pour les quartets de poids faible. On obtient 8 bits par composante au lieu des
4 bits de l'OCS/ECS — le dégradé est lisse, sans banding.

**Double buffer de copperlist.** Deux listes en Chip RAM : celle qui est
affichée et celle qu'on remplit. L'échange se fait en début de VBlank via
`COP1LC` puis un strobe sur `COPJMP1`, donc jamais de déchirure sur les
couleurs.

**Franchissement de la ligne 255.** Le comparateur vertical du copper est sur
8 bits : la liste insère la classique attente `$FFDF,$FFFE` avant de repartir
sur des positions verticales « enroulées ».

**Sprite matériel.** `SPR0POS` / `SPR0CTL` sont recalculés à chaque image
(VSTART, VSTOP, HSTART, plus les bits 8 de VSTART/VSTOP et le bit 0 de HSTART
placés dans SPR0CTL). Les canaux 1 à 7 pointent sur un sprite vide.
`BPLCON4 = $0011` garde la palette sprite historique (couleurs 16 à 31).

## Pistes pour la suite

- 8 bitplanes AGA (256 couleurs) + `FMODE` en fetch 32/64 bits pour le scrolling.
- Blitter : effacement, dessin de bobs avec masque (cookie-cut), lignes.
- Interruption niveau 3 (VERTB / COPER) plutôt qu'une attente active.
- Replayer ProTracker et DMA Paula pour la musique.
- Scroller sinusoïdal avec police 8×8 et copper text.
