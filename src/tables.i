;----------------------------------------------------------
; tables.i - GENERE PAR tools/gen_tables.py
;----------------------------------------------------------

; nom (18), type, des, faces, bonus, valeur, bruitage,
; marge critique, multiplicateur
ItemTable:
	; 1 DAGUE
	dc.b	"DAGUE",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,1,4,0,2,0,19,2
	; 2 ÉPÉE COURTE
	dc.b	"ÉPÉE COURTE",0,0,0,0,0,0,0
	dc.w	0,1,6,0,10,0,19,2
	; 3 ÉPÉE LONGUE
	dc.b	"ÉPÉE LONGUE",0,0,0,0,0,0,0
	dc.w	0,1,8,0,15,0,19,2
	; 4 HACHE
	dc.b	"HACHE",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,1,8,0,12,1,20,3
	; 5 HACHE DE GUERRE
	dc.b	"HACHE DE GUERRE",0,0,0
	dc.w	0,1,12,0,20,1,20,3
	; 6 MASSE
	dc.b	"MASSE",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,1,8,0,12,1,20,2
	; 7 ARC COURT
	dc.b	"ARC COURT",0,0,0,0,0,0,0,0,0
	dc.w	0,1,6,0,30,2,20,3
	; 8 BATON
	dc.b	"BATON",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,1,6,0,5,0,20,2
	; 9 ÉPÉE LONGUE +1
	dc.b	"ÉPÉE LONGUE +1",0,0,0,0
	dc.w	0,1,8,1,100,0,19,2
	; 10 HACHE RUNIQUE +2
	dc.b	"HACHE RUNIQUE +2",0,0
	dc.w	0,1,12,2,200,1,20,3
	; 11 DAGUE DE FEU +1
	dc.b	"DAGUE DE FEU +1",0,0,0
	dc.w	0,2,4,1,120,0,19,2
	; 12 ROBE
	dc.b	"ROBE",0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	1,0,0,0,5,0,20,2
	; 13 ARMURE DE CUIR
	dc.b	"ARMURE DE CUIR",0,0,0,0
	dc.w	1,2,0,0,20,0,20,2
	; 14 COTTE DE MAILLES
	dc.b	"COTTE DE MAILLES",0,0
	dc.w	1,5,0,0,80,0,20,2
	; 15 HARNOIS
	dc.b	"HARNOIS",0,0,0,0,0,0,0,0,0,0,0
	dc.w	1,8,0,0,300,0,20,2
	; 16 BOUCLIER
	dc.b	"BOUCLIER",0,0,0,0,0,0,0,0,0,0
	dc.w	2,2,0,0,25,0,20,2
	; 17 POTION DE SOIN
	dc.b	"POTION DE SOIN",0,0,0,0
	dc.w	3,2,4,2,25,0,20,2
	; 18 POTION MAJEURE
	dc.b	"POTION MAJEURE",0,0,0,0
	dc.w	3,3,8,3,70,0,20,2
	; 19 PARCH. TRAIT
	dc.b	"PARCH. TRAIT",0,0,0,0,0,0
	dc.w	4,0,0,0,40,0,20,2
	; 20 PARCH. SOINS
	dc.b	"PARCH. SOINS",0,0,0,0,0,0
	dc.w	4,1,0,0,40,0,20,2
	; 21 PARCH. BRÛLURE
	dc.b	"PARCH. BRÛLURE",0,0,0,0
	dc.w	4,2,0,0,60,0,20,2
	; 22 PARCH. ARMURE
	dc.b	"PARCH. ARMURE",0,0,0,0,0
	dc.w	4,3,0,0,60,0,20,2
	; 23 PARCH. EFFROI
	dc.b	"PARCH. EFFROI",0,0,0,0,0
	dc.w	4,4,0,0,80,0,20,2
	; 24 PARCH. ÉCLAIR
	dc.b	"PARCH. ÉCLAIR",0,0,0,0,0
	dc.w	4,5,0,0,120,0,20,2
	; 25 CLÉ DE FER
	dc.b	"CLÉ DE FER",0,0,0,0,0,0,0,0
	dc.w	5,0,0,0,10,0,20,2
	; 26 CLÉ D'ARGENT
	dc.b	"CLÉ D'ARGENT",0,0,0,0,0,0
	dc.w	5,0,0,0,25,0,20,2
	; 27 GEMME
	dc.b	"GEMME",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	6,0,0,0,120,0,20,2
	; 28 COURONNE
	dc.b	"COURONNE",0,0,0,0,0,0,0,0,0,0
	dc.w	6,0,0,0,400,0,20,2
	; 29 ÉPÉE LONGUE +2
	dc.b	"ÉPÉE LONGUE +2",0,0,0,0
	dc.w	0,1,8,2,300,0,19,2
	; 30 MARTEAU +1
	dc.b	"MARTEAU +1",0,0,0,0,0,0,0,0
	dc.w	0,1,8,1,150,1,20,3
	; 31 ARC LONG +1
	dc.b	"ARC LONG +1",0,0,0,0,0,0,0
	dc.w	0,1,8,1,250,2,20,3
	; 32 MAILLES ELFIQUES
	dc.b	"MAILLES ELFIQUES",0,0
	dc.w	1,6,0,0,400,0,20,2
	; 33 BOUCLIER +1
	dc.b	"BOUCLIER +1",0,0,0,0,0,0,0
	dc.w	2,3,0,0,150,0,20,2
	; 34 POTION SUPRÊME
	dc.b	"POTION SUPRÊME",0,0,0,0
	dc.w	3,4,8,4,150,0,20,2
	; 35 SCEAU DU GAGE
	dc.b	"SCEAU DU GAGE",0,0,0,0,0
	dc.w	6,0,0,0,600,0,20,2

; nom (20), niveau, effet, des/niveau, faces, bonus, plafond,
; sauvegarde, moitie si reussie, ecole
SpellTable:
	dc.b	"RAYON DE GIVRE",0,0,0,0,0,0
	dc.w	0,0,0,3,0,1,0,0,1
	dc.b	"PROJECTILE MAGIQUE",0,0
	dc.w	1,0,0,4,1,5,0,0,1
	dc.b	"MAINS BRÛLANTES",0,0,0,0,0
	dc.w	1,0,1,4,0,5,2,1,1
	dc.b	"ARMURE DE MAGE",0,0,0,0,0,0
	dc.w	1,2,0,0,4,0,0,0,1
	dc.b	"SOINS LÉGERS",0,0,0,0,0,0,0,0
	dc.w	1,1,0,8,1,5,0,0,2
	dc.b	"BENEDICTION",0,0,0,0,0,0,0,0,0
	dc.w	1,4,0,0,1,0,0,0,2
	dc.b	"TERREUR",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	1,3,0,0,0,0,3,0,3
	dc.b	"FLECHE ACIDE",0,0,0,0,0,0,0,0
	dc.w	2,0,0,4,0,2,0,0,1
	dc.b	"RAYON ARDENT",0,0,0,0,0,0,0,0
	dc.w	2,0,0,6,0,4,0,0,1
	dc.b	"SOINS MODERES",0,0,0,0,0,0,0
	dc.w	2,1,0,8,1,10,0,0,2
	dc.b	"IMMOBILISATION",0,0,0,0,0,0
	dc.w	2,3,0,0,0,0,3,0,3
	dc.b	"BOULE DE FEU",0,0,0,0,0,0,0,0
	dc.w	3,0,1,6,0,10,2,1,1
	dc.b	"ÉCLAIR",0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	3,0,1,6,0,10,2,1,1
	dc.b	"SOINS IMPORTANTS",0,0,0,0
	dc.w	3,1,0,8,1,15,0,0,2
	dc.b	"FLEAU",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	3,0,1,8,0,5,1,1,2
	dc.b	"BOUCLIER DE FOI",0,0,0,0,0
	dc.w	1,2,0,0,2,0,0,0,2
NSPELLS		= 16

; nom (16), des de vie, faces, bonus PV, CA, attaque, des,
; faces, bonus degats, marge critique, multiplicateur,
; Vigueur, Reflexes, Volonte, PX, or, silhouette, langue,
; temperament (0 hostile, 1 mefiant, 2 paisible)
MonTypes:
	dc.b	"KOBOLD",0,0,0,0,0,0,0,0,0,0
	dc.w	1,8,0,15,1,1,6,-1,20,2,2,2,0,18,4,2,2,1
	dc.b	"GOBELIN",0,0,0,0,0,0,0,0,0
	dc.w	1,8,1,15,2,1,6,0,20,2,3,1,-1,24,6,2,2,1
	dc.b	"RAT SANGUIN",0,0,0,0,0
	dc.w	1,8,1,15,4,1,4,0,20,2,3,3,3,24,0,0,0,0
	dc.b	"SQUELETTE",0,0,0,0,0,0,0
	dc.w	1,12,0,15,1,1,6,1,18,2,0,1,2,24,0,1,0,0
	dc.b	"ORC",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	1,8,1,15,4,2,4,4,18,2,3,0,-2,37,10,3,3,1
	dc.b	"HOBGOBELIN",0,0,0,0,0,0
	dc.w	1,8,2,15,2,1,8,1,19,2,4,1,-1,37,12,2,2,1
	dc.b	"ZOMBI",0,0,0,0,0,0,0,0,0,0,0
	dc.w	2,12,3,11,2,1,6,1,20,2,0,-1,3,37,0,1,0,0
	dc.b	"LOUP",0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	2,8,4,14,3,1,6,1,20,2,5,5,1,75,0,0,0,0
	dc.b	"GNOLL",0,0,0,0,0,0,0,0,0,0,0
	dc.w	2,8,2,15,3,1,8,2,20,3,4,0,0,75,14,3,3,1
	dc.b	"GOULE",0,0,0,0,0,0,0,0,0,0,0
	dc.w	2,12,0,14,2,1,6,1,20,2,0,2,5,75,0,1,0,0
	dc.b	"BUGBEAR",0,0,0,0,0,0,0,0,0
	dc.w	3,8,3,17,5,1,8,2,20,2,4,3,1,150,22,3,2,1
	dc.b	"WORG",0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	4,10,8,14,7,1,6,4,20,2,6,6,3,150,0,0,0,0
	dc.b	"OMBRE",0,0,0,0,0,0,0,0,0,0,0
	dc.w	3,12,0,13,3,1,6,0,20,2,1,3,4,225,0,5,0,0
	dc.b	"OGRE",0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	4,8,11,16,8,2,8,7,20,2,6,0,1,225,45,4,4,1
	dc.b	"HOMME-LÉZARD",0,0,0,0
	dc.w	2,8,2,15,3,1,8,1,20,2,3,3,0,75,12,3,5,2
	dc.b	"GARGOUILLE",0,0,0,0,0,0
	dc.w	4,8,19,16,6,1,4,2,20,2,5,6,4,300,30,7,0,0
	dc.b	"OMBRE BLÊME",0,0,0,0,0
	dc.w	4,12,0,15,3,1,4,1,20,2,1,2,5,225,25,5,0,0
	dc.b	"OURSALOUP",0,0,0,0,0,0,0
	dc.w	5,10,25,15,9,1,6,5,20,2,9,5,2,300,0,0,0,0
	dc.b	"HARPIE",0,0,0,0,0,0,0,0,0,0
	dc.w	7,8,0,15,7,1,6,0,20,2,2,7,6,300,40,7,1,0
	dc.b	"MINOTAURE",0,0,0,0,0,0,0
	dc.w	6,8,12,15,9,3,6,6,20,3,6,5,5,300,60,4,4,0
	dc.b	"TROLL",0,0,0,0,0,0,0,0,0,0,0
	dc.w	6,8,36,16,9,1,6,6,20,2,11,4,3,375,55,4,4,0
	dc.b	"SPECTRE",0,0,0,0,0,0,0,0,0
	dc.w	7,12,0,15,6,1,8,0,20,2,2,5,7,525,70,5,0,0
	dc.b	"MOMIE",0,0,0,0,0,0,0,0,0,0,0
	dc.w	8,12,3,20,11,1,6,10,20,2,4,2,8,375,90,6,1,0
	dc.b	"HYDRE",0,0,0,0,0,0,0,0,0,0,0
	dc.w	5,10,28,15,6,1,10,3,20,2,9,5,3,375,80,8,0,0
	dc.b	"GÉANT COLLINE",0,0,0
	dc.w	12,8,48,17,16,2,8,10,20,2,12,3,4,525,200,4,4,1
	dc.b	"NÉCROPHAGE",0,0,0,0,0,0
	dc.w	4,12,0,15,3,1,4,1,20,2,1,1,5,225,30,1,1,0
	dc.b	"CHIEN INFERNAL",0,0
	dc.w	4,8,4,16,5,1,8,1,20,2,5,5,1,225,0,0,0,0
	dc.b	"APPARITION",0,0,0,0,0,0
	dc.w	5,12,0,15,5,1,4,0,20,2,1,3,6,375,50,5,0,0
	dc.b	"BASILIC",0,0,0,0,0,0,0,0,0
	dc.w	6,10,12,16,8,1,8,3,20,2,9,4,3,375,0,8,0,0
	dc.b	"MANTICORE",0,0,0,0,0,0,0
	dc.w	6,10,24,17,10,2,4,5,20,2,9,7,3,375,70,7,1,0
	dc.b	"ETTIN",0,0,0,0,0,0,0,0,0,0,0
	dc.w	10,8,20,18,12,2,6,6,20,2,9,3,5,450,120,4,4,1
	dc.b	"GOLEM DE CHAIR",0,0
	dc.w	9,10,30,18,10,2,8,5,20,2,3,2,3,525,0,3,0,0
NMONSTERS	= 32

; rencontres par niveau de donjon : numeros de monstres
Encounter0:
	dc.b	0,1,2,3,4,5,6,7,8,9
	dc.b	10
	even
Encounter1:
	dc.b	4,5,6,7,8,9,10,11,12,13,14,16
	dc.b	12
	even
Encounter2:
	dc.b	13,15,16,17,18,19,20,21,22,23,24,25,26
	dc.b	13
	even
Encounter3:
	dc.b	17,19,20,21,22,23,24,25,26,27,28,29,30,31
	dc.b	14
	even
EncounterTab:
	dc.l	Encounter0,Encounter1,Encounter2,Encounter3

; nom (12), de de vie, attaque, sauvegardes fortes, lanceur
ClassTable:
	dc.b	"GUERRIER",0,0,0,0
	dc.w	10,0,1,0,0,0
	dc.b	"BARBARE",0,0,0,0,0
	dc.w	12,0,1,0,0,0
	dc.b	"ROUBLARD",0,0,0,0
	dc.w	6,1,0,1,0,0
	dc.b	"RÔDEUR",0,0,0,0,0,0
	dc.w	8,0,1,1,0,2
	dc.b	"PALADIN",0,0,0,0,0
	dc.w	10,0,1,0,1,2
	dc.b	"CLERC",0,0,0,0,0,0,0
	dc.w	8,1,1,0,1,2
	dc.b	"MAGICIEN",0,0,0,0
	dc.w	4,2,0,0,1,1
	dc.b	"ENSORCELEUR",0
	dc.w	4,2,0,0,1,1
	dc.b	"DRUIDE",0,0,0,0,0,0
	dc.w	8,1,1,0,1,2
	dc.b	"MOINE",0,0,0,0,0,0,0
	dc.w	8,1,1,1,1,0
	dc.b	"FORGERON",0,0,0,0
	dc.w	10,0,1,0,0,0
NCLASSES	= 11

; emplacements de sorts : niveaux 1 a 8, sorts de niveau 0 a 3
SlotTable:
	dc.w	3,1,0,0
	dc.w	4,2,0,0
	dc.w	4,2,1,0
	dc.w	4,3,2,0
	dc.w	4,3,2,1
	dc.w	4,3,3,2
	dc.w	4,4,3,2
	dc.w	4,4,3,3

StartGear:			; arme, armure, bouclier, sorts
	dc.w	3,14,16,$0000	; 
	dc.w	4,13,0,$0000	; 
	dc.w	2,13,0,$0000	; 
	dc.w	7,13,0,$0000	; 
	dc.w	3,14,16,$0010	; SOINS LÉGERS
	dc.w	6,13,16,$0030	; SOINS LÉGERS, BENEDICTION
	dc.w	8,12,0,$0007	; RAYON DE GIVRE, PROJECTILE MAGIQUE, MAINS BRÛLANTES
	dc.w	8,12,0,$0003	; RAYON DE GIVRE, PROJECTILE MAGIQUE
	dc.w	8,13,0,$0050	; SOINS LÉGERS, TERREUR
	dc.w	8,12,0,$0000	; 
	dc.w	6,14,16,$0000	; 

; nom (12), FOR, DEX, CON, INT, SAG, CHA, classes interdites
RaceTable:
	dc.b	"HUMAIN",0,0,0,0,0,0
	dc.w	0,0,0,0,0,0,$0000
	dc.b	"NAIN",0,0,0,0,0,0,0,0
	dc.w	0,0,2,0,0,-2,$00c0
	dc.b	"ELFE",0,0,0,0,0,0,0,0
	dc.w	0,2,-2,0,0,0,$0012
	dc.b	"HALFELIN",0,0,0,0
	dc.w	-2,2,0,0,0,0,$0402
	dc.b	"DEMI-ELFE",0,0,0
	dc.w	0,0,0,0,0,0,$0000
	dc.b	"DEMI-ORC",0,0,0,0
	dc.w	2,0,0,-2,0,-2,$0140
NRACES		= 6

; les langues : leur nom, puis ce que parlent races et classes
NTONGUES	= 6
TongueNames:
	dc.l	TxtTongue0
	dc.l	TxtTongue1
	dc.l	TxtTongue2
	dc.l	TxtTongue3
	dc.l	TxtTongue4
	dc.l	TxtTongue5
TxtTongue0:	dc.b	"",0
TxtTongue1:	dc.b	"COMMUN",0
TxtTongue2:	dc.b	"GOBELIN",0
TxtTongue3:	dc.b	"ORC",0
TxtTongue4:	dc.b	"GÉANT",0
TxtTongue5:	dc.b	"DRACONIQUE",0
	even
RaceTongues:
	dc.w	$0002	; HUMAIN
	dc.w	$0016	; NAIN
	dc.w	$0022	; ELFE
	dc.w	$0006	; HALFELIN
	dc.w	$000a	; DEMI-ELFE
	dc.w	$000e	; DEMI-ORC
ClassTongues:
	dc.w	$0002	; GUERRIER
	dc.w	$0002	; BARBARE
	dc.w	$0002	; ROUBLARD
	dc.w	$000a	; RÔDEUR
	dc.w	$0002	; PALADIN
	dc.w	$0002	; CLERC
	dc.w	$0022	; MAGICIEN
	dc.w	$0022	; ENSORCELEUR
	dc.w	$0012	; DRUIDE
	dc.w	$0002	; MOINE
	dc.w	$0002	; FORGERON

; competences : leur nom, puis le depart par classe et ce que
; la race y ajoute, un octet par competence
NSKILLS		= 6
SkillNames:
	dc.l	TxtSkill0
	dc.l	TxtSkill1
	dc.l	TxtSkill2
	dc.l	TxtSkill3
	dc.l	TxtSkill4
	dc.l	TxtSkill5
TxtSkill0:	dc.b	"COMBAT",0
TxtSkill1:	dc.b	"DÉFENSE",0
TxtSkill2:	dc.b	"CONCENTRATION",0
TxtSkill3:	dc.b	"VIGILANCE",0
TxtSkill4:	dc.b	"DÉSAMORÇAGE",0
TxtSkill5:	dc.b	"MARCHANDAGE",0
	even
SkillClass:
	dc.b	30,25,0,10,5,10	; GUERRIER
	dc.b	30,20,0,15,0,5	; BARBARE
	dc.b	15,15,0,30,35,20	; ROUBLARD
	dc.b	25,15,10,25,10,10	; RÔDEUR
	dc.b	25,25,15,10,5,10	; PALADIN
	dc.b	15,20,25,10,5,15	; CLERC
	dc.b	5,10,30,10,5,15	; MAGICIEN
	dc.b	5,10,30,10,5,20	; ENSORCELEUR
	dc.b	10,15,25,20,10,10	; DRUIDE
	dc.b	25,30,20,20,10,5	; MOINE
	dc.b	25,25,0,10,15,30	; FORGERON
SkillRace:
	dc.b	5,0,0,0,0,5	; HUMAIN
	dc.b	0,5,0,0,5,5	; NAIN
	dc.b	0,0,5,10,0,0	; ELFE
	dc.b	0,0,0,5,10,0	; HALFELIN
	dc.b	0,0,0,5,0,5	; DEMI-ELFE
	dc.b	10,0,0,0,0,0	; DEMI-ORC
	even

NameList:			; 9 octets par nom
	dc.b	"ALDER",0,0,0,0
	dc.b	"MYRA",0,0,0,0,0
	dc.b	"BORIN",0,0,0,0
	dc.b	"SELVA",0,0,0,0
	dc.b	"THORGAL",0,0
	dc.b	"ELWIN",0,0,0,0
	dc.b	"KAREN",0,0,0,0
	dc.b	"DRAKE",0,0,0,0
	dc.b	"LYRA",0,0,0,0,0
	dc.b	"GORIM",0,0,0,0
	dc.b	"NESSA",0,0,0,0
	dc.b	"VALDIS",0,0,0
	dc.b	"ORRIN",0,0,0,0
	dc.b	"SIBYL",0,0,0,0
	dc.b	"HAKON",0,0,0,0
	dc.b	"MAEVE",0,0,0,0
NNAMES		= 16

; Le CIA rend la position de la touche, pas le caractere.
KeyAzerty:
	dc.b	$00,$31,$32,$33,$34,$35,$36,$37,$38,$39,$30,$00,$00,$00,$00,$00
	dc.b	$41,$5a,$45,$52,$54,$59,$55,$49,$4f,$50,$00,$00,$00,$00,$00,$00
	dc.b	$51,$53,$44,$46,$47,$48,$4a,$4b,$4c,$4d,$00,$00,$00,$00,$00,$00
	dc.b	$00,$57,$58,$43,$56,$42,$4e,$00,$00,$00,$00,$00,$00,$00,$00,$00
KeyQwerty:
	dc.b	$00,$31,$32,$33,$34,$35,$36,$37,$38,$39,$30,$00,$00,$00,$00,$00
	dc.b	$51,$57,$45,$52,$54,$59,$55,$49,$4f,$50,$00,$00,$00,$00,$00,$00
	dc.b	$41,$53,$44,$46,$47,$48,$4a,$4b,$4c,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$5a,$58,$43,$56,$42,$4e,$4d,$00,$00,$00,$00,$00,$00,$00,$00
