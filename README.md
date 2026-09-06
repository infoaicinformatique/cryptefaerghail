# Démos AGA — Amiga 1200 / AmigaOS 3.1+

Deux démos 68k **entièrement assemblables depuis Linux ou macOS**, écrites en
assembleur Motorola pour `vasm`, liées en exécutables *hunk* Amiga par `vlink`.

| Programme | Contenu |
|---|---|
| `bin/AGADemo` | dégradé plein écran généré **ligne par ligne par le copper en 24 bits réels**, plus une boule en **sprite matériel** |
| `bin/AGAScroll` | playfield **8 bitplanes (256 couleurs 24 bits)** de 640×384 pixels, parcouru par une caméra en **scrolling 100 % matériel** |

Les deux se quittent par le bouton gauche de la souris.

![Aperçu de AGAScroll](docs/preview.png)

*(image produite par `tools/preview.py`, un modèle Python du pipeline — voir
plus bas.)*

## Cible

| | |
|---|---|
| Machine | Amiga 1200 (chipset AGA), 68020+ |
| Système | AmigaOS 3.0 / 3.1 et supérieur (`graphics.library` V39) |
| Écran | PAL lores 320×256 |
| Mémoire | `AGADemo` : quelques Ko de Chip — `AGAScroll` : 240 Ko de Chip pour le bitmap, plus 8 Ko de copperlists |

## Compilation

```sh
make toolchain     # télécharge et compile vasm + vlink dans tools/bin (une fois)
make               # produit bin/AGADemo et bin/AGAScroll
```

`make toolchain` récupère les sources de Frank Wille
(<http://sun.hasenbraten.de/vasm/>, <http://sun.hasenbraten.de/vlink/>) et les
compile avec `gcc`. Si `vasmm68k_mot` et `vlink` sont déjà dans votre `PATH`,
`make` les utilise directement.

Régénérer les données (table sinus, pixels du sprite, palette 256 couleurs) :

```sh
make data          # Python 3, réécrit src/sine.i, src/sprite.i, src/palette.i
```

Vérifier l'arithmétique du scrolling et la disposition de la copperlist, et
produire un aperçu :

```sh
make check         # rejoue en Python les calculs du code 68k
make preview       # écrit docs/preview.png
```

## Exécution

- **FS-UAE / WinUAE** : configurez une A1200 (Kickstart 3.1, AGA, 68020, 2 Mo
  Chip), montez le dossier `bin/` comme disque dur, puis depuis le Shell :
  `AGADemo`.
- **Machine réelle** : copiez les exécutables et lancez-les **depuis un Shell**
  (ils ne gèrent pas le message `WBStartup` d'un lancement depuis le Workbench).

## Structure

```
src/demo.s       démo 1 : prise de contrôle, dégradé copper 24 bits, sprite
src/scroll.s     démo 2 : 8 bitplanes AGA + scrolling matériel
src/hardware.i   equates des registres custom et LVO exec/graphics
src/sine.i       table sinus 256 entrées                    (généré)
src/sprite.i     boule 16×16, 2 plans                       (généré)
src/palette.i    256 couleurs 24 bits (hauts / bas)         (généré)
tools/gen_data.py  générateur des trois fichiers ci-dessus
tools/preview.py   modèle Python du pipeline de scroll.s : contrôles + aperçu
scripts/get-toolchain.sh  installation de vasm + vlink
```

## Points techniques — `AGADemo`

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

## Points techniques — `AGAScroll`

**8 bitplanes.** `BPLCON0` bit 4 (`BPU3`) à 1 et bits 14-12 à 0 : c'est le
codage AGA de « 8 plans ». En lores, 8 plans passent avec le fetch 16 bits
habituel (`FMODE = 0`), donc pas de contrainte d'alignement 32/64 bits ni de
bits de scroll étendus.

**256 couleurs en 24 bits.** Le copper charge la palette en 8 banques de 32
(`BPLCON3` bits 15-13), chaque banque écrite deux fois (LOCT = 0 puis 1) : 528
`MOVE`, soit environ 5 lignes de raster, largement avant le début de l'affichage
en ligne $2C.

**Scrolling matériel.** Aucun pixel n'est déplacé :
- *grossier* — les pointeurs `BPL1PT`…`BPL8PT` sont décalés de 2 octets par
  tranche de 16 pixels et de `BMWB` octets par ligne ; les modulos
  (`BPL1MOD`/`BPL2MOD` = 38) font sauter au DMA la partie non affichée ;
- *fin* — `BPLCON1` retarde le playfield de 0 à 15 pixels. Comme il faut de la
  matière à décaler, `DDFSTRT` recule de 8 color clocks ($30 au lieu de $38) :
  21 mots fetchés par ligne au lieu de 20.

La relation exacte, avec `W` le mot pointé et `d` le retard : le pixel affiché
en colonne 0 vaut `W*16 + 16 - d`. Pour afficher le pixel `X` de l'image, on
prend donc `W = (X-1)>>4` et `d = (-X) & 15`. `make check` rejoue ce calcul sur
les 256 images d'un cycle.

**Couleurs des sprites.** `BPLCON4 = $00FF` (ESPRM = OSPRM = $F) : les sprites
prennent leurs couleurs dans la banque $F, soit 241 à 243 — sinon ils
mangeraient les couleurs 17 à 19 de l'image. Les entrées 240 à 255 de la
palette sont d'ailleurs exclues de la rotation de couleurs.

**Double buffer de copperlist.** Chaque image, la liste cachée reçoit les 16
`MOVE` de pointeurs, le `MOVE` de `BPLCON1` et la palette tournée ; l'échange se
fait en début de VBlank.

**Génération du playfield.** Le plasma est calculé au démarrage (avant la prise
de contrôle de l'affichage, donc sous Workbench) par un chunky-to-planar par
paquets de 16 pixels, en deux passes de 4 plans : `lsr.b` sort le bit dans X,
`roxl.w` le récupère dans l'accumulateur du plan.

## Ce qui est vérifié, et ce qui ne l'est pas

Les deux programmes s'assemblent et se lient (exécutables hunk valides, hunks
Chip correctement marqués), et `tools/preview.py` rejoue en Python la
disposition de la copperlist, les adresses patchées à chaque image, le
chunky-to-planar et le calcul de scroll — c'est ce modèle qui produit
`docs/preview.png`.

En revanche **rien n'a encore tourné sur Amiga réel ni sous émulateur** : le
modèle valide l'arithmétique du code, pas le comportement du chipset.

## Pistes pour la suite

- Scrolling infini : bitmap de la largeur de l'écran + 16 pixels, avec une
  colonne redessinée au blitter à chaque franchissement de mot.
- Blitter : effacement, dessin de bobs avec masque (cookie-cut), lignes.
- Interruption niveau 3 (VERTB / COPER) plutôt qu'une attente active.
- Replayer ProTracker et DMA Paula pour la musique.
- Scroller sinusoïdal avec police 8×8 et copper text.
