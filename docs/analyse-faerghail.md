# Legend of Faerghail (1990) : analyse, et ce qu'il faudrait pour en reprendre le game design

*Legend of Faerghail* a été développé par Electronic Design Hannover et publié
en 1990 par reLINE, puis par Rainbow Arts à l'international, sur Amiga, Atari
ST et PC. Cette analyse part de deux sources :

- **les trois disquettes Amiga fournies** : structure des fichiers, et les
  textes de l'exécutable et des fichiers de créatures, lisibles en clair ;
- **des analyses publiées** :
  [CRPG Addict](http://crpgaddict.blogspot.com/2013/11/game-122-legend-of-faerghail-1990.html),
  [Wikipédia](https://en.wikipedia.org/wiki/Legend_of_Faerghail),
  [dungeoncrawlers.org](https://www.dungeoncrawlers.org/game/legend-of-faerghail/).

Les deux vidéos YouTube n'ont pas pu être consultées : YouTube refuse l'accès
automatisé. Les images et les cartes du jeu sont dans un format compressé
maison (`Y\x10…`, `L000…`) que je n'ai pas décodé.

**Rien de ce qui suit n'est à copier dans le dépôt.** Les noms propres (Thyn,
Cyldane, Ihl Kazar, Siegurd…), les textes, les images, les sons, la musique et
le code du jeu restent la propriété de leurs auteurs. Ce qui se reprend, ce sont
les **mécaniques** : un système de jeu n'est pas protégé, son expression l'est.

## 1. Ce que les disquettes révèlent de l'architecture

| Disquette | Contenu | Rôle |
|---|---|---|
| 3 (démarrage) | `lof` (195 Ko, l'exécutable), `SYST/` (`ROST`, `ITEM`, `SPEL`, `SHOP`, `BOXS`, `SCRN`, `SNSC`), `DNGS/TOWNE`, `DNGS/WILDS`, donjon 0, `DSND/` (grillon, corbeau, vent, herbe…) | le moteur, les tables, la **ville**, l'**extérieur** et le premier donjon |
| 1 | donjons 1 à 4 : `GRPHn` (décors, ~43 Ko chacun), `MAPSn`, `NSC0n` (créatures), `SPECn` (événements), `TEXTn`, `ANIMS` (animations de combat), `PICTS` (300 Ko d'images) | un jeu de fichiers **par donjon**, chargés à la demande |
| 2 | donjons 5 à 7, et `LAST/` (5 images, 5 textes, un hymne de 123 Ko) | la fin du jeu |

Ce qu'il faut en retenir :

- **Un donjon, c'est un paquet de fichiers.** Décors, carte, bestiaire, scripts
  d'événements et textes sont chargés depuis la disquette en y entrant. C'est ce
  qui permet huit donjons sur 2,6 Mo. Notre jeu fait l'inverse : tout est
  incorporé à l'exécutable.
- **Le bestiaire est propre à chaque donjon** (`NSC0n`), avec des groupes
  nommés : le donjon des elfes a ses soldats, officiers et magiciens elfes ;
  celui des nains ses nains ; la crypte ses morts-vivants ; le dernier ses
  élémentaires, golems et êtres de magma.
- **Les événements sont scriptés par donjon** (`SPECn`) : fontaines qui
  soignent ou augmentent une caractéristique, épée dans la pierre, énigmes
  (« le nom du père de Findal »), bâton à placer devant une porte au lever du
  soleil, sarcophage…
- **Le son est d'ambiance** : pluie, vent, tonnerre, grillons, corbeau, gouttes,
  pas sur la pierre, magma. C'était l'un des points forts salués à l'époque.

## 2. Le game design

### Le groupe

- **Six personnages** ; les places libres peuvent accueillir des **PNJ recrutés**
  en route (« … est convaincu et rejoint votre équipe »).
- **Six races** : humain, nain, elfe, halfelin, demi-elfe, demi-orc.
- **Onze classes** : paladin, guerrier, voleur, prêtre, druide, magicien,
  illusionniste, guérisseur, moine, barbare, forgeron. Certaines combinaisons
  sont interdites (pas de paladin elfe, de magicien nain…).
- **Cinq caractéristiques** : Force, Dextérité, Constitution, Intelligence,
  Sagesse. Le sexe du personnage joue aussi.
- **Des compétences qui progressent à l'usage** : chaque action réussie peut les
  améliorer (« Pick-pocketing improves! », « Stalking improves! »,
  « Concentration improves! », « Negotiating ability improves! », « Defence
  ability improves! »).
- **Des langues** qu'on apprend en ville, et sans lesquelles on ne parle pas aux
  autres peuples.
- **Des états** : empoisonné, aveugle, malade, pétrifié, lycanthrope, niveau
  drainé, paralysé.

### Le monde

- **Un extérieur** en vue subjective, sur une grille, découpé par les montagnes,
  avec l'heure du jour et la météo.
- **Deux villes à menus**, sans exploration :
  - l'échoppe : acheter, vendre, faire réparer, marchander ;
  - la banque : dépôts, avec le risque d'un vol entre deux visites ;
  - l'auberge : nuit simple ou avec vivres ;
  - le temple : soigner, ressusciter, avec le risque de rater ;
  - la guilde : entraînement contre or et expérience, sorts, langues ;
  - le vol à la tire, avec la prison ou la main coupée en cas d'échec.
- **Huit donjons thématiques**, chacun avec ses décors, son peuple et ses
  énigmes.
- **La survie** : six rations par jour et par groupe. Le moral baisse avec la
  marche et les blessures. Se cogner dans un mur blesse.

### Les rencontres et le combat

- **Une rencontre commence avant le combat** : on peut *saluer*, *parler* (si
  l'on connaît la langue : marchander, négocier un passage, recruter) ou
  *se retirer*. Certains groupes sont pacifiques.
- **Les rangs** : chaque camp se range sur plusieurs lignes. La position compte :
  un mage trop près de l'ennemi perd sa concentration et rate ses sorts.
- **Des rounds à ordres** : on donne un ordre à chaque personnage (tuer,
  attaquer, défendre, lancer un sort, se faufiler, utiliser un objet), puis le
  round se joue. Il se regarde en détail, attaque par attaque avec animation, ou
  se résume en « combat rapide ».
- **Le jeu mémorise** les ordres et les positions d'un combat au suivant.
- **Le matériel s'use** : les armes cassent, les armures rouillent, les
  munitions s'épuisent. Le forgeron répare.

### La magie et la progression

- Les **sorts** s'apprennent à la guilde et demandent un grimoire. Ils sont
  limités par jour (« isn't available for today »).
- **Monter de niveau coûte de l'or** à la guilde : environ 1 500 pièces par
  niveau. L'expérience seule ne suffit pas.
- Une **fin mise en scène** : images, textes, hymne.

## 3. Ce qui sépare La Crypte de ce design

| | La Crypte aujourd'hui | Legend of Faerghail | Effort |
|---|---|---|---|
| Groupe | 4 héros | 6, et des PNJ recrutables | moyen : panneau, sauvegarde, combats |
| Races | aucune | 6, avec des interdits par classe | moyen |
| Classes | 8 (SRD) | 11 | faible : les tables existent |
| Compétences | aucune | progressent à l'usage | moyen |
| Langues et dialogue | non | oui | moyen |
| Monde | 3 étages d'une crypte | extérieur + 2 villes + 8 donjons | **important** : chargement depuis disquette |
| Ville | une échoppe par étage | 6 services à menus | moyen : menus, sans rendu 3D |
| Rencontres | le combat commence tout de suite | saluer / parler / fuir, groupes pacifiques | moyen |
| Combat | un monstre, attaque/sort/fuite | des groupes, des rangs, des ordres par personnage, rounds, combat rapide | **important** |
| Survie | non | rations, moral, heure, météo | moyen |
| Usure | non | armes, armures, munitions, réparation | faible |
| Progression | l'expérience seule | expérience + or à la guilde | faible |
| Son | musique + bruitages | ambiance par lieu | moyen |
| Disquettes | 2 (jeu, source) | 3, chargées à la demande | **important** |

## 4. Proposition de feuille de route

Chaque étape laisse un jeu jouable, testé par les bancs, avant la suivante.

1. **Chargement à la demande.** Le moteur charge un donjon depuis la disquette
   (`dos.library` : `Open`/`Read`) au lieu de tout incorporer. C'est la
   condition de tout le reste : huit donjons, un extérieur et une ville ne
   tiennent pas dans un seul exécutable.
2. **Le groupe de six**, les races, les onze classes, les compétences à l'usage.
3. **Le combat à rangs** : groupes d'ennemis, lignes, ordres par personnage,
   déroulé détaillé ou rapide, mémoire des ordres.
4. **Les rencontres** : saluer, parler, se retirer ; langues ; recrutement.
5. **La ville** : échoppe, banque, auberge, temple, guilde (entraînement payant,
   sorts, langues), vol à la tire.
6. **L'extérieur** : grille en plein air, heure, météo, rations, moral.
7. **Les donjons thématiques**, avec leur bestiaire, leurs événements scriptés
   et leurs décors. La Crypte actuelle et son greffe en deviennent un.
8. **La fin**, et les sons d'ambiance.

Les noms, l'histoire, les lieux et les peuples restent les nôtres. La maison de
garde, le greffe et Ossian ont déjà la matière d'un monde entier.

Un point à trancher avant de publier : le projet porte le mot « Faerghail »,
titre d'un jeu commercial toujours référencé. Pour un projet personnel, ce
n'est pas un problème. Pour une diffusion, un autre nom serait plus prudent.
