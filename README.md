# La Crypte de Faerghail — Amiga 1200 / AmigaOS 3.1+

Un dungeon crawler AGA **entièrement assemblable depuis Linux ou macOS**, écrit
en assembleur Motorola pour `vasm`, lié en exécutable *hunk* Amiga par `vlink`.

`bin/AGACrawl` — vue subjective façon Black Crypt : création de groupe et
règles reprises du SRD 3.5, inventaire, magie, échoppes, dalles piégées,
portes à runes, monstres animés qui marchent vers vous, bruitages, et un
module ProTracker 4 voies sur Paula cadencé par le timer A du CIA-B.

![La Crypte de Faerghail](docs/crawl.png)

*(image produite par le modèle Python `tools/dungeon_preview.py` — voir plus
bas.)*

## Cible

| | |
|---|---|
| Machine | Amiga 1200 (chipset AGA), 68020+ |
| Système | AmigaOS 3.0 / 3.1 et supérieur (`graphics.library` V39) |
| Écran | PAL lores 320×256 |
| Mémoire | environ 700 Ko de Chip : deux tampons d'écran à huit bitplanes, les décors, et les deux modules |
| Audio | 4 voies Paula, module ProTracker cadencé par le timer A du CIA-B |

## Compilation

```sh
make toolchain     # télécharge et compile vasm + vlink dans tools/bin (une fois)
make               # produit bin/AGACrawl
```

`make toolchain` récupère les sources de Frank Wille
(<http://sun.hasenbraten.de/vasm/>, <http://sun.hasenbraten.de/vlink/>) et les
compile avec `gcc`. Si `vasmm68k_mot` et `vlink` sont déjà dans votre `PATH`,
`make` les utilise directement.

Régénérer les données du jeu, et en voir un écran :

```sh
make dungeon       # décors, cartes, police, tables, bruitages, musiques --
                   # vérifie aussi que chaque niveau a son escalier
                   # atteignable depuis le départ, et le greffe avec
python3 tools/dungeon_preview.py 0 3 1 1 docs/crawl.png
python3 tools/dungeon_preview.py 0 3 1 1 combat.png 2   # ecran de combat
```

Écouter les deux musiques sans Amiga :

```sh
make wav           # rejoue les modules en Python et écrit deux WAV
```

## Disquette prête à l'emploi

`dist/Faerghail.adf` est une disquette 880 Ko **OFS amorçable** (DOS0, lisible
de Kickstart 1.3 à 3.x) contenant le jeu, tout son source écrit à la main, un
`Lisezmoi.txt` et un `S/Startup-Sequence` qui le lance au démarrage.

Elle est pleine à 98 % : à huit bitplanes le jeu pèse à lui seul plus d'un
demi-mégaoctet — six cent mille octets une fois sur la disquette, où un bloc de
512 n'en porte que 488 — sur huit cent quatre-vingt. Le script écrit donc ce
qui rentre, dans un ordre fixé, et dit ce qu'il laisse.

Ce qui n'y est pas : les **tables générées**, dont `surfgrad.i` qui pèse à lui
seul quatre-vingt mille octets. Elles vivent dans **`dist/Faerghail.lha`**, qui
porte tout, et les générateurs Python les refont en une seconde.

```sh
make disk          # refabrique les deux -- nécessite pip install amitools
```

- **Émulateur** : montez l'ADF dans DF0: et démarrez dessus.
- **Machine réelle** : écrivez l'ADF sur une disquette (ADF Blitzer,
  X-Copy + Amiga Explorer, Greaseweazle…), ou copiez le `.lha` sur le disque
  dur et faites `lha x Faerghail.lha`.

## Exécution

- **FS-UAE / WinUAE** : configurez une A1200 (Kickstart 3.1, AGA, 68020, 2 Mo
  Chip), montez le dossier `bin/` comme disque dur, puis depuis le Shell :
  `AGACrawl`.
- **Machine réelle** : copiez l'exécutable et lancez-le **depuis un Shell** (il
  ne gère pas le message `WBStartup` d'un lancement depuis le Workbench).

## Structure

```
src/crawl.s      le jeu : moteur, rendu, combats, magie, interface
src/hardware.i   equates des registres custom et LVO exec/graphics
src/ptreplay.i   replayer ProTracker 4 voies pour Paula
src/vblank.i     interruption de retour trame (niveau 3, VERTB)
src/ciatimer.i   timer A du CIA-B : le tempo du module (niveau 6)
src/tables.i     objets, sorts, monstres, classes, noms          (généré)
src/dgnpal.i     palette 16 couleurs du donjon                   (généré)
src/dgncol.i     noms des gammes de la palette                   (généré)
src/font8.i      police 8x8 de l'interface                       (généré)
src/surfgrad.i   dégradés que le copper pose ligne par ligne     (généré)
src/pointer.i    sprite 0 : le pointeur de souris                (généré)
src/artidx.i     index des morceaux de décor                     (généré)
data/dgnart.bin  décors en perspective et monstres               (généré)
data/dgnmap.bin  les trois niveaux                               (généré)
data/sfx.bin     bruitages synthétisés                           (généré)
data/crawlmus.mod  la marche du donjon                           (généré)
data/titlemus.mod  la procession de l'accueil                    (généré)
tools/gen_dungeon.py générateur des décors, des cartes et de la police 8x8
tools/gen_tables.py  générateur des tables du jeu
tools/gen_sfx.py     générateur des bruitages
tools/gen_score.py   générateur des deux musiques (accueil et donjon)
tools/glyphs.py      la table de glyphes 5×7 et la carte Latin-1
tools/palette.py     la palette 256 couleurs AGA, décrite matière par matière
tools/dungeon_preview.py rend un écran du jeu en PNG et contrôle les données
tools/screens.py     rejoue les mises en page et les rend en PNG
tools/render_mod.py  rejoue un module en Python et écrit un WAV
tools/make_lha.py    écrit l'archive LhA (et se relit pour se vérifier)
tools/run68k.py      banc 68020 : charge l'exécutable, émule chipset et clavier
tools/test_game.py   fait tourner le jeu et contrôle ses invariants
tools/play_game.py   pilote le jeu vers les monstres, les objets, l'escalier
tools/shot68k.py     photographie les écrans dessinés par le processeur émulé
tools/test_sfx.py    vérifie les bruitages aux registres de Paula
tools/test_replay.py rejoue le module et compare au modèle Python
tools/test_copper.py contrôle la copperlist du jeu
tools/test_save.py   accueil, sauvegarde et reprise, fichiers à l'appui
tools/test_layout.py vérifie qu'aucun panneau ne déborde de la vue
docs/histoire.md     le fond de fiction : ce qu'était Faerghail
disk/                fichiers écrits à la main pour la disquette
scripts/make-disk.sh fabrique l'ADF amorçable et le .lha
scripts/get-toolchain.sh  installation de vasm + vlink
```

## Le jeu — `AGACrawl`

Un crawler dans l'esprit de Black Crypt : on avance case par case, on tourne
de 90°, et le donjon est dessiné en vue subjective.

### L'histoire

La crypte a un fond, écrit dans [docs/histoire.md](docs/histoire.md).

`Faerghail` n'est pas un nom d'homme mais un mot de contrat : **faergh**, le
gage, et **gail**, le seuil. *Le seuil du gage.* C'était une **maison de
garde** — l'endroit où, faute de juge et de prince, on descendait déposer un
objet pour garantir une promesse, et où un greffier tenait le registre des
échéances. Trois étages, un par génération de greffiers, creusés dans une
ancienne carrière de schiste : d'où la forme du lieu, qui n'est ni un tombeau
ni un donjon de guerre mais un **classement**, et d'où la sortie tout en bas,
là où la carrière débouche sur la vallée.

Le fond n'a pas été inventé à côté du jeu, mais à partir de lui : chaque règle
déjà écrite y trouve sa raison.

| Ce que le jeu fait | Pourquoi la maison le fait |
|---|---|
| Le grand registre, au fond du dernier étage | C'est un greffe : la maison tient ses comptes, et la ligne se raye là où elle est écrite |
| Les quatre noms du groupe y font les quatre colonnes | Une quittance porte quatre signatures |
| La sortie ne s'ouvre qu'une fois la ligne rayée | On ne sort de Faerghail qu'acquitté |
| Un marchand scellé dans un mur, un par étage | L'emmurement de garde du dernier greffier : il est devenu une clause de la maison, et un guichet est un endroit, pas un homme |
| Il rachète à moitié prix | Le taux d'un dépôt refait |
| Une porte à runes par étage, **trois** réponses | Le contrôle par question — une clé se vole, pas une réponse — et les trois colonnes du registre |
| Une réponse fausse brûle un aventurier | La rune ne punit pas : elle inscrit |
| Des dalles piégées, deux fois plus en bas | Une dette impayée, un ressort tendu ; en bas, les échéances sont plus vieilles |
| Une dalle ne se déclenche qu'une fois | Le ressort détendu, le compte est soldé |
| Une croix à la craie sur la dalle repérée | La marque des greffiers, sur un compte à examiner |
| Quatre aventuriers, ni trois ni cinq | Quatre colonnes de signature au bas d'une quittance |
| La sortie est tout en bas | La gueule de la carrière, devenue porte des quittances |

Dans le jeu, cela se lit à l'accueil — **touche 3**, quatre pages tournées à
n'importe quelle touche, les flèches pour revenir, `ESC` pour ressortir ; la
page d'après la dernière rend l'accueil, pour qui lit sans regarder les
touches. Et cela affleure en jouant : la ligne d'ouverture, une inscription
par étage dans le journal, la voix derrière le mur à l'échoppe, et la
quittance en guise de victoire — **on ne sort de Faerghail qu'acquitté**.

![Le prologue](docs/emu-prologue.png)

Les quatre pages sont des listes de lignes terminées par un long nul : on en
ajoute une sans rien recompter, et la dernière page ne demande pas de cas
particulier. Une ligne marquée d'une étoile passe à l'or — il n'y en a
qu'une. `PROLOGROWS` borne le dessin à ce que le cadre tient : une ligne de
trop déborderait du plan et retomberait en haut du suivant, ce que
`tools/test_layout.py` va justement chercher, page par page, en regardant la
bordure de l'écran et la bande laissée entre le texte et le pied de page.

### Création du groupe

Quatre aventuriers, chacun d'une classe (guerrier, barbare, éclaireur, clerc)
qui décide du dé de vie, de la progression à l'attaque et de l'accès à la
magie. Les six caractéristiques sont tirées **à 4d6 en gardant les trois
meilleurs dés**, comme il se doit ; `R` relance, `ENTRÉE` valide. Le nom se
tape au clavier — et comme le CIA rend des **positions de touches**, pas des
caractères, `TAB` bascule entre AZERTY et QWERTY.

### Règles

Reprises du **SRD 3.5** (le contenu de D&D 3.5 publié sous Open Game
License) — les créatures « Product Identity » qui n'y figurent pas, comme le
beholder ou le flagelleur mental, sont donc absentes :

- **Modificateurs** : `(carac − 10) / 2`, arrondi vers le bas.
- **Classe d'armure** : `10 + mod. Dextérité + armure + bouclier`.
- **Attaque** : `1d20 + bonus de base + mod. Force` contre la CA du monstre.
  Le bonus de base suit le niveau chez les guerriers, les trois quarts
  ailleurs. Un 20 naturel touche toujours et **double les dégâts**.
- **Dégâts** : dés de l'arme + bonus magique + mod. Force. À l'arc, c'est la
  Dextérité qui sert à toucher.
- **Attaques multiples** : une attaque supplémentaire à −5 par tranche de 5
  points de bonus de base, comme la règle d'attaque à outrance.
- **Critiques par arme** : marge et multiplicateur du SRD (19-20/×2 pour les
  épées, ×3 pour les haches et l'arc), avec **jet de confirmation**.
- **Progression d'attaque** : complète, aux trois quarts ou de moitié selon la
  classe.
- **Sauvegardes** : Vigueur, Réflexes, Volonté — `2 + niveau/2` si la
  sauvegarde est forte pour la classe, `niveau/3` sinon, plus le modificateur
  de Constitution, Dextérité ou Sagesse.
- **Points de vie** : dé de classe maximal au niveau 1, puis un jet par
  niveau, plus le mod. Constitution.
- **Magie** : 16 sorts du SRD répartis sur les niveaux 0 à 3, avec
  **emplacements par niveau de sort** suivant la table de progression, plus
  les emplacements bonus de caractéristique. Le degré de difficulté vaut
  `10 + niveau du sort + mod. de lancement`, et les monstres y opposent leurs
  propres sauvegardes — réussie, une boule de feu n'inflige que la moitié des
  dégâts. Les sorts s'apprennent sur des **parchemins**.

### Les huit classes

Guerrier, barbare, roublard, rôdeur, paladin, clerc, magicien, ensorceleur —
chacune avec son dé de vie, sa progression d'attaque, ses sauvegardes fortes
et son type de lanceur (profane sur l'Intelligence, divin sur la Sagesse).

### Le bestiaire

25 créatures du SRD, avec leurs statistiques d'origine : kobold, gobelin, rat
sanguin, squelette, orc, hobgobelin, zombi, loup, gnoll, goule, bugbear, worg,
ombre, ogre, homme-lézard, gargouille, oursaloup, harpie, minotaure, troll,
spectre, momie, hydre, géant des collines… Chaque monstre tire ses points de
vie à ses dés de vie à l'apparition, et les rencontres sont réparties par
niveau de donjon selon leur facteur de puissance.

### Commandes

À l'accueil : `1` commence une partie, `2` reprend la partie sauvée, `3`
ouvre le prologue, `ESC` quitte.

| Touche | Effet |
|---|---|
| Flèches | avancer, reculer, tourner (l'escalier montant est sur la case d'arrivée) |
| Espace | ouvrir une porte, fouiller une niche, entrer à l'échoppe, lire le grand registre, désamorcer un piège |
| C / I | fiche d'aventure, sac à dos |
| 1 à 4 | choisir le héros courant |
| A / S / F | attaquer, lancer un sort, fuir (en combat) |
| E / U / D | équiper, utiliser, jeter (dans le sac) |
| M / L / P | carte du niveau, grimoire, réglages |
| Souris | clic gauche : rose des vents dans la vue, choisir un aventurier, poser un curseur ; clic droit : agir, ou refermer un panneau |
| Tab | à l'échoppe : passer de l'achat à la vente |
| ESC | fermer un écran, puis quitter |

### Contenu

Trois niveaux, 28 objets (11 armes, 5 protections, potions, 6 parchemins,
clés, trésors), 4 monstres animés sur deux poses, coffres, objets au sol,
niches creusées dans les murs, portes ordinaires, portes verrouillées, le
grand registre au fond du dernier étage — et
une **porte à runes** par niveau, qui pose une énigme à trois réponses :
juste, elle s'efface et le groupe gagne de l'expérience ; faux, la rune brûle
un aventurier.

**Les monstres marchent.** Ils tenaient leur case et attendaient qu'on leur
rentre dedans : un couloir vide était sûr, et le donjon n'avait pas de nerf.
Ils font maintenant un pas toutes les quatorze trames vers le groupe, s'il est
à moins de six cases — de plus loin, ils n'ont rien entendu. Le pas se pose
sur du dallage nu et rien d'autre : ni porte, ni dalle piégée, ni escalier, ni
la case d'un autre. Celui qui arrive sur le groupe engage le combat lui-même,
et **meurt chez lui** : la case nettoyée à sa mort est la sienne, plus celle
du groupe — les deux étaient la même tant que c'était toujours nous qui
entrions dedans.

Un bit de travail marque ceux qui ont déjà bougé pendant le balayage de la
carte : sans lui, un monstre qui avance dans le sens du balayage serait
rencontré une seconde fois par la même boucle et traverserait l'étage d'un
coup. La marque est effacée avant de sortir, pour qu'elle ne parte jamais dans
une sauvegarde.

**On remonte.** Chaque étage sous le premier a son escalier montant, sur la
case d'arrivée : on redescend par où l'on est venu, et l'on retombe sur
l'escalier descendant de l'étage du dessus. Au-dessus du premier, c'est le
jour, et la crypte ne se quitte que par le bas.

Cela demandait de **garder l'état de chaque étage** : le jeu n'en tenait qu'un
à la fois et relisait `dgnmap.bin` en descendant. Tant qu'on ne remontait
jamais, cela ne se voyait pas ; sinon on retrouverait l'étage neuf à chaque
passage — coffres pleins, monstres debout, échoppe regarnie — et le donjon se
moissonnerait en boucle. Les trois états (terrain, paramètres, relevé de la
carte, étal) tiennent maintenant côte à côte, et c'est eux que la sauvegarde
emporte.

**Le grand registre**, au greffe du dernier étage. Scellé dans un mur comme
l'échoppe, mais loin du départ : il faut le chercher. `ESPACE` ouvre la page,
qui porte les quatre noms du groupe — ce sont les quatre colonnes de signature
d'une quittance. `ENTRÉE` raye la ligne, une fois pour toutes, et vaut de
l'expérience à tout le monde.

Le pupitre donne sur une **petite salle** creusée devant lui : le générateur
n'ouvre que du mur nu, et jamais au contact d'un levier ou d'une herse — ceux
-là comptent sur le tracé pour couper la route, et une salle percée à côté
leur ferait un contournement.

Sans cela, **l'escalier du dernier étage ne mène nulle part** : la porte des
quittances ne cède qu'à qui a rayé sa ligne. Le troisième étage a donc un
objet, et pas seulement une sortie — trouver le greffe, puis trouver
l'escalier. Le générateur place le registre dans un mur bordé par un couloir
atteignable **sans forcer une serrure**, jamais collé à l'escalier, et le
contrôle par parcours en largeur, comme il le fait déjà pour les clés ; il
tient aussi les dalles piégées à distance de son pupitre. La quittance est
dans la partie sauvée — d'où un nouveau nombre magique, `FAE2` : une
sauvegarde d'avant le registre n'a plus le bon compte et se refuse.

![Le grand registre](docs/emu-registre.png)

**Une échoppe par étage.** L'or ramassé dans les coffres et sur les cadavres
ne servait à rien : chaque objet portait pourtant un prix dans `ItemTable`, et
personne ne le lisait. Le marchand est scellé dans un mur comme une niche, à
trois à neuf pas du départ pour qu'on puisse s'équiper avant de s'enfoncer.
Espace ouvre son étal : huit articles choisis pour l'étage, au prix de
l'objet ; Tab passe de l'autre côté du comptoir, où il rachète le butin à
moitié prix. Ce qui est vendu reste vendu — l'étal fait partie de la partie
sauvée.

**Des dalles piégées**, quatre au premier étage, huit au dernier. Elles ne se
voient pas. En marchant dessus, chaque aventurier debout tente un jet contre
DD 14 + 2 × étage : le roublard ajoute son niveau et 4, les autres se
contentent de leur sagesse et d'un tiers de leur niveau. Repérée, la dalle
est marquée d'une croix à la craie et le groupe s'arrête net ; Espace tente
de la désamorcer, ce qui rapporte de l'expérience à tout le monde et, raté de
plus de 5, la fait sauter. Non repérée, elle se détend : jet de Réflexes (de
Vigueur pour le nuage acide), un dé de dégâts par étage plus un, moitié moins
si la sauvegarde passe. Un ressort ne sert qu'une fois — la dalle redevient
du dallage.

Le générateur **vérifie que chaque niveau reste finissable** : il place les
serrures loin du départ et les clés près, puis contrôle par parcours en
largeur qu'on atteint l'escalier ou au moins une clé sans forcer une serrure.
Ce contrôle a déjà attrapé un niveau coupé en deux dès la deuxième case.

### Les accents

Le jeu est en français et s'écrit tout en capitales. Il criait donc `ETAGE`,
`PIEGE`, `CLE` et `RAYEE` : la police n'avait que `A-Z`, les chiffres et une
poignée de signes — 49 glyphes.

Une cellule de 8×8 ne laisse **pas** de place au-dessus d'une capitale de sept
lignes. Les capitales accentuées sont donc redessinées sur six lignes, l'accent
occupant la première : **la ligne de base ne bouge pas**, un `É` reste aligné
sur le `E` d'à côté. La cédille, elle, descend sous la ligne de base, où la
huitième ligne l'attendait déjà.

```
E : #####  É : ...#.    l'accent, une ligne
    #....      #####    puis la lettre sur six
    #....      #....
    ###..      ###..
    #....      #....
    #....      #####
    #####
```

Douze capitales accentuées — `À Â Ç È É Ê Ë Î Ï Ô Ù Û` — et une table de
glyphes qui couvre Latin-1 de 32 à 255 au lieu de l'ASCII 32 à 127, dans les
deux polices. Les minuscules d'un texte y prennent le glyphe de leur capitale.

Les sources qui portent du texte — `src/crawl.s`, `src/scroll.s`,
`src/tables.i` — sont donc **en Latin-1**, un octet par signe, comme la police
les attend ; les outils Python qui les relisent le savent.

### La souris

Le pointeur est un **sprite matériel** — sprite 0, seize pixels de côté, quatre
couleurs. Il ne coûte rien : ni blit, ni sauvegarde de fond, ni redessin. Ses
couleurs viennent du bloc `$f0`, que `BPLCON4` (ESPRM/OSPRM = `$f`) lui réserve
et qu'aucune teinte du décor n'occupe.

`JOY0DAT` ne donne pas une position mais deux compteurs de huit bits qui
tournent en rond : on lit une différence par trame, en étendant le signe du
huitième bit — sans quoi un pas vers la gauche se lirait comme un bond de 255
pixels vers la droite. Le bouton gauche est le bit 6 de `CIAAPRA`, le droit le
bit 10 de `POTGOR`, tous deux à zéro quand ils sont enfoncés.

Un clic ne double pas la logique du clavier : il se traduit en touche et repart
dans `HandleKey`. Dans la vue, la souris dessine une rose des vents en trois
colonnes et trois rangées — avancer, reculer, tourner, agir au centre ; en
combat, cliquer c'est frapper. Sur le panneau du groupe, un clic choisit
l'aventurier de ce bloc. Dans une liste — sac, échoppe, grimoire, réglages —
il pose le curseur sur la ligne visée, et un second clic sur la même ligne
conclut. Le bouton droit referme un panneau ; dans la vue il agit, plutôt que
de quitter le jeu par mégarde.

### Rendu

Aucun calcul 3D à l'exécution : les murs sont pré-calculés en perspective par
`tools/gen_dungeon.py` — un morceau par position, y compris le fond et le mur
extérieur des passages latéraux — et posés au blitter du plus loin au plus
proche, en cookie-cut (minterme `$CA`) et **sans décalage**, puisque la
géométrie est fixe et chaque morceau calé sur un mot. Les murs latéraux se
projettent en droites passant par le point de fuite : à la colonne `x`, la
distance vaut `64/|96−x|`, ce qui donne un placage de texture exact. Les
dalles du sol et du plafond suivent la même règle. La pierre a son grain, ses
fissures et sa mousse, tirés d'un bruit stable.

Écran 320×256 en **8 bitplanes** — 256 couleurs choisies parmi seize millions,
la palette chargée en 24 bits (`BPLCON3` LOCT, huit banques de trente-deux),
double tampon ; l'affichage n'est refait qu'après une action.

### Le copper : plus de couleurs que la palette n'en tient

La gamme de pierre compte vingt teintes. Sur les cinquante-sept lignes qui
séparent l'horizon du bord de l'écran, la profondeur s'y lisait donc en vingt
marches, et le dallage montrait des bandes.

Le sol et la voûte ne portent plus leur profondeur dans la palette : ils ne
gardent que leur **variation locale** — joint de terre, usure du passage,
mousse, suie, nervure, extinction latérale — codée sur douze cases,
`$f4`–`$ff`. Le copper réécrit ces douze cases **toutes les deux lignes** avec
la profondeur de la ligne, calculée sur la même loi de lumière que les murs.
Il y a donc **68 profondeurs à l'écran là où la palette n'en tient que vingt**,
et les douze cases ne coûtent rien au reste du décor.

Ces douze cases tombent dans le bloc `$f0` que `BPLCON4` donne aux sprites,
dont ceux-ci n'utilisent que les quatre premières : le matériel lit les mêmes
registres, chacun n'y regarde que ce qui le concerne.

Le coût : 26 instructions copper par bloc, soit **28 cycles couleur par ligne
sur 227**. `tools/test_copper.py` relit la liste construite et le vérifie.

**La flamme.** Six degrés de clarté sont préparés à la génération ; à chaque
trame le jeu passe de l'un à l'autre par une marche au hasard bornée et
centrée, en recopiant 1 632 mots dans la copperlist juste après le retour
trame. Le décor ne bouge pas d'un pixel — seule la lumière respire.

### Son

Deux modules ProTracker quatre voies, tous deux en ré mineur : la procession
de l'écran d'accueil et la marche du donjon. Quatorze instruments synthétisés
— timbale, taïko, cymbale, bourdon, cor, chœur, cordes, harpe, orgue, fifre,
viole, cloche, gong, tambour. La quatrième voie est **empruntée** le temps
d'un bruitage (épée, hache, arc, impact, esquive, porte, coffre, potion, sort,
rugissement, montée de niveau, pas, mort, piège, pièces), le replayer laissant
le canal tranquille pendant la durée indiquée dans la table.

**Le replayer honore 23 des effets de ProTracker**, contre neuf auparavant :

| | |
|---|---|
| Hauteur | `0xy` arpège, `1xx`/`2xx` glissandos, `3xx` portamento vers la note, `4xy` vibrato, `E1x`/`E2x` glissandos fins |
| Volume | `Cxx`, `Axy` glissement, `7xy` trémolo, `EAx`/`EBx` glissement fin, `ECx` coupure |
| Combinés | `5xy` portamento + volume, `6xy` vibrato + volume |
| Déclenchement | `9xx` départ dans le sample, `E9x` relance, `EDx` note retardée |
| Structure | `Bxx` saut, `Dxx` break, `Fxx` vitesse, `E6x` boucle de motif, `EEx` ligne retenue |
| Matériel | `E0x` filtre passe-bas (la diode) |

Manquent `E3x` (glissando), `E4x`/`E7x` (choix de forme d'onde), `E5x`
(finetune) et `EFx` (inversion de boucle) : les samples étant synthétisés sans
table de finetune, ils n'auraient rien à modifier.

Les partitions s'en servent : vibrato sur les tenues du cor et du chœur,
trémolo lent sous le bourdon, roulement de tambour par relance plutôt que
réécrit ligne par ligne, coups doubles par note retardée, cymbale prise après
son attaque par `9xx`, cadence élargie par `EEx`.

Le replayer est écrit **deux fois** — en 68k dans `src/ptreplay.i`, en Python
dans `tools/render_mod.py` — à partir de la même lecture du format. Quand les
deux divergent, l'une a tort, et `tools/test_replay.py` dit laquelle : il écrit
de vrais motifs dans le module chargé, appelle `PT_Tick` tic par tic, et lit ce
qui part vers `AUDxPER`, `AUDxVOL`, `AUDxLC` et `DMACON`.

Le module perdait des tics pendant les déplacements : un redessin complet dure
plus qu'une image, et le tic n'était appelé qu'une fois par tour de boucle.
`MusicPoll`, semé dans les traitements longs, rejoue un tic dès qu'une image
s'est écoulée — le tempo tient désormais pendant le rendu.

## Points techniques — le retour trame (`src/vblank.i`)

Les trois programmes attendaient la trame en surveillant `VPOSR` dans une
boucle, et faisaient tout le reste à la file : échange de copperlist, tic de
musique, rendu. Cela marche tant que la boucle tient dans une image. Le jeu ne
tenait pas : un redessin à huit bitplanes dépasse la trame, et le module
perdait des tics dès qu'on se déplaçait — le hoquet qu'on entendait en
marchant. On avait colmaté en semant des appels au replayer au milieu du
redessin ; ce n'était qu'un rattrapage.

Le travail cadencé se fait maintenant dans une **interruption de niveau 3**,
armée sur `VERTB` :

```
INTENA = INTF_SETCLR | INTF_INTEN | INTF_VERTB
```

**Le VBR.** Sur 68000 la table des vecteurs est en `$000000` ; dès le 68010
elle se déplace, et le Kickstart d'un 1200 la recopie en Fast RAM. On demande
donc son adresse au processeur — `movec vbr,d0`, instruction privilégiée,
d'où le détour par `exec/Supervisor()` — après avoir vérifié le bit `68010`
d'`AttnFlags`. L'ancien vecteur est rendu au système en quittant.

**Le gestionnaire** vérifie d'abord que la cause est bien le retour trame : le
niveau 3 est partagé (VERTB, COPER, BLIT), et une interruption d'un autre
appareil serait comptée comme une image. L'acquittement s'écrit **deux fois** —
le custom chip met un cycle à voir la valeur, et sans la seconde écriture le
processeur peut sortir avant que `INTREQ` ne soit retombé, et rentrer aussitôt
dans la même interruption.

**Le jeton d'échange.** L'interruption ne met une copperlist (ou un tampon) à
l'affiche que si la boucle principale a signalé l'avoir finie, sinon une trame
en avance montrerait un dégradé à moitié écrit. La boucle pose `SwapReq` /
`DrawReady`, l'interruption le consomme.

**L'attente** n'est plus une surveillance du balayage mais la consommation
d'un drapeau posé par l'interruption : si une trame est passée pendant que la
boucle travaillait, l'attente est nulle. Et comme le drapeau ne compte pas,
trois trames perdues n'en rendent qu'une — la boucle reprend au présent au
lieu de rattraper dans le vide.

**Les sections critiques.** Lancer un bruitage emprunte un canal de Paula au
replayer ; coupé en deux par une interruption, il laisserait un canal à moitié
armé. `VBI_Disable` / `VBI_Enable` encadrent ces passages — le lancement d'un
effet, et le changement de module entre l'accueil et le donjon.

**Le banc en tient compte** : `machine68k` n'a pas de ligne d'IRQ, donc
`tools/run68k.py` empile lui-même le cadre d'exception (format 0 du 68020 :
SR, PC, mot de format) et détourne le processeur vers le vecteur, comme le
ferait Paula. `INTENA` et `INTREQ` y sont modélisés comme les registres à
bascule qu'ils sont — bit 15 pose, sinon efface. Les appels directs de
routines depuis le banc, eux, restent à l'abri de l'interruption : c'est le
test qui tient l'horloge, et un tic de musique par-dessus le bruitage que l'on
mesure fausserait la mesure.

## Points techniques — le tempo (`src/ciatimer.i`)

Un module ProTracker ne se joue pas à 50 Hz. Il se joue à **BPM × 2 / 5 tics
par seconde** — 50 Hz n'est que le cas du tempo par défaut, 125. L'effet `Fxx`
avec un paramètre d'au moins 32 change ce tempo, et le replayer n'avait aucun
moyen de l'honorer tant qu'il était attelé au balayage : le code l'ignorait,
avec un commentaire qui le disait.

Il est maintenant attelé au **timer A du CIA-B**, dont l'horloge vaut
709 379 Hz en PAL. Un compte de `709379 × 5 / (2 × BPM)` donne exactement la
bonne cadence : 14 187 à 125 BPM, soit 50,00 Hz. L'interruption est de
**niveau 6** (`INTF_EXTER`), son vecteur pris et rendu comme celui du retour
trame.

**L'ordre d'acquittement compte.** On efface `INTREQ` *avant* de lire l'ICR du
CIA : la lecture efface les drapeaux du CIA et fait retomber sa ligne, et
l'ordre inverse laisserait passer une interruption fantôme.

**Ce que l'on ne rend pas** en sortant : le compte du timer, qui est en
écriture seule — on ne peut pas savoir ce qu'il valait. On rend le vecteur, le
masque du CIA et `INTENA` ; le timer reste sur notre tempo, muet.

**Le retour trame garde l'image**, le timer garde la musique : `VBI_Frame` ne
fait plus que l'échange de copperlist ou de tampons, `CIA_Tick` le tic du
module. Les sections critiques du son — lancement d'un bruitage, changement de
module — passent par `CIA_Lock`.

**Un bug est tombé avec.** Le replayer arme le point de boucle d'une note au
tic suivant son lancement, comme Paula l'exige. Il le faisait aussi sur le
canal 3 quand un bruitage venait de l'emprunter : deux écritures qui posaient
la boucle du module sur un canal en train de jouer autre chose. Le banc des
bruitages l'a vu dès que la musique a changé de cadence — il vérifiait
exactement cela depuis toujours, mais l'état du module ne tombait jamais au
bon endroit.

## Points techniques — musique (`src/ptreplay.i`)

**Cadence.** `PT_Tick` est appelé une fois par image depuis la boucle
principale, juste après l'échange de copperlist : le VBlank sert d'horloge
(50 Hz), et `Fxx` règle le nombre de ticks par ligne (6 par défaut). Pas
d'interruption de niveau 3, donc pas de vecteur à installer ni de passage en
mode superviseur — en contrepartie, une image trop longue ralentirait la
musique.

**La séquence que Paula impose** pour lancer une note, et qui est la source
d'erreur classique :

1. couper le DMA du canal ;
2. écrire `AUDxLC`, `AUDxLEN`, `AUDxPER`, `AUDxVOL` ;
3. attendre deux lignes raster, le temps que Paula constate l'arrêt ;
4. relancer le DMA ;
5. **au tick suivant seulement**, écrire le point de boucle dans `AUDxLC` /
   `AUDxLEN` — Paula a alors déjà chargé l'adresse de départ, et rebouclera
   sur la boucle du sample.

**Le module doit être en Chip RAM** : `incbin` dans une section `DATA_C`, ce
que l'on vérifie sur le fichier lié (le hunk du module porte bien le drapeau
CHIP). Le filtre passe-bas est coupé au démarrage (`bset #1,$BFE001`, le bit
de la LED) et remis dans son état d'origine à la sortie.

**Effets implémentés** : `0xy` arpège, `1xx`/`2xx` portamento, `3xx`
portamento vers la note, `Axy` volume slide, `Cxx` volume, `Fxx` vitesse,
`Bxx` saut de position, `Dxx` break. Les autres sont ignorés, ainsi que le
finetune : c'est un sous-ensemble assumé, pas un replayer ProTracker complet.

**Les deux modules sont synthétisés** par `tools/gen_score.py` — samples et
partitions, la procession de l'accueil et la marche du donjon, toutes deux en
ré mineur. Rien n'est emprunté à un module existant, le dépôt reste libre de
droits.

## Ce qui est vérifié, et ce qui ne l'est pas

**Le jeu tourne pour de bon** : `tools/run68k.py` charge l'exécutable hunk, le
relocalise, remplace `exec.library`, `graphics.library` et `dos.library` par
des souches, et exécute le vrai code dans un 68020 émulé — chipset simulé au
strict nécessaire (balayage, blitter rectangulaire, souris et clavier au CIA-A,
timer A du CIA-B, retour trame au niveau 3 et timer au niveau 6, les deux avec
leur vrai cadre d'exception). Six bancs s'appuient dessus : invariants du jeu,
bruitages relus aux registres de Paula, replayer, copperlist, sauvegarde,
largeur des panneaux, plus un parcours dirigé de quatre cents pas qui descend
jusqu'au greffe et raye la ligne.

`tools/gen_dungeon.py` vérifie par parcours en largeur que l'escalier de chaque
niveau est atteignable depuis le départ, et que le grand registre l'est aussi —
un donjon injouable serait invisible à la relecture du code. `tools/screens.py`
et `tools/dungeon_preview.py` rejouent les mises en page et l'algorithme
d'affichage sur les vraies données pour produire les captures.

Côté musique, `tools/render_mod.py` rejoue un module avec exactement la même
sémantique que le replayer 68k (mêmes effets, même cadence — `BPM × 2 / 5`
tics par seconde —, mêmes règles de boucle) et produit un WAV : c'est ce qui
vérifie les modules et la logique de rejeu.

Tout cela tourne à chaque poussée, dans **`.github/workflows/build.yml`**, qui
vérifie en plus que les binaires suivis correspondent au source et que les
générateurs redonnent `data/` et `src/` bit pour bit.

En revanche **rien n'a encore tourné sur Amiga réel** : les modèles valident
l'arithmétique et la logique du code, pas le comportement du chipset ni celui
de Paula.

## Pistes pour la suite

- Une vraie salle de greffe autour du registre, et une phrase d'accueil par
  étage pour la voix derrière le comptoir : voir la fin de
  [docs/histoire.md](docs/histoire.md).
- Interruption COPER : découper l'image en bandes et changer de palette à
  mi-écran depuis le processeur. Le jeu ne s'en sert pas encore ; le
  gestionnaire de niveau 3 est prêt à accueillir la cause.
