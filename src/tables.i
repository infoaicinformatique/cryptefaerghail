;----------------------------------------------------------
; tables.i - GENERE PAR tools/gen_tables.py
;----------------------------------------------------------

; nom (18), type, des, faces, bonus, valeur, bruitage,
; marge critique, multiplicateur
ItemTable:
	; 1 DAGUE
	dc.b	"DAGUE",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,1,4,0,2,0,19,2
	; 2 EPEE COURTE
	dc.b	"EPEE COURTE",0,0,0,0,0,0,0
	dc.w	0,1,6,0,10,0,19,2
	; 3 EPEE LONGUE
	dc.b	"EPEE LONGUE",0,0,0,0,0,0,0
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
	; 9 EPEE LONGUE +1
	dc.b	"EPEE LONGUE +1",0,0,0,0
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
	; 21 PARCH. BRULURE
	dc.b	"PARCH. BRULURE",0,0,0,0
	dc.w	4,2,0,0,60,0,20,2
	; 22 PARCH. ARMURE
	dc.b	"PARCH. ARMURE",0,0,0,0,0
	dc.w	4,3,0,0,60,0,20,2
	; 23 PARCH. EFFROI
	dc.b	"PARCH. EFFROI",0,0,0,0,0
	dc.w	4,4,0,0,80,0,20,2
	; 24 PARCH. ECLAIR
	dc.b	"PARCH. ECLAIR",0,0,0,0,0
	dc.w	4,5,0,0,120,0,20,2
	; 25 CLE DE FER
	dc.b	"CLE DE FER",0,0,0,0,0,0,0,0
	dc.w	5,0,0,0,10,0,20,2
	; 26 CLE D'ARGENT
	dc.b	"CLE D'ARGENT",0,0,0,0,0,0
	dc.w	5,0,0,0,25,0,20,2
	; 27 GEMME
	dc.b	"GEMME",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	6,0,0,0,120,0,20,2
	; 28 COURONNE
	dc.b	"COURONNE",0,0,0,0,0,0,0,0,0,0
	dc.w	6,0,0,0,400,0,20,2

; nom (20), niveau, effet, des/niveau, faces, bonus, plafond,
; sauvegarde, moitie si reussie, ecole
SpellTable:
	dc.b	"RAYON DE GIVRE",0,0,0,0,0,0
	dc.w	0,0,0,3,0,1,0,0,1
	dc.b	"PROJECTILE MAGIQUE",0,0
	dc.w	1,0,0,4,1,5,0,0,1
	dc.b	"MAINS BRULANTES",0,0,0,0,0
	dc.w	1,0,1,4,0,5,2,1,1
	dc.b	"ARMURE DE MAGE",0,0,0,0,0,0
	dc.w	1,2,0,0,4,0,0,0,1
	dc.b	"SOINS LEGERS",0,0,0,0,0,0,0,0
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
	dc.b	"ECLAIR",0,0,0,0,0,0,0,0,0,0,0,0,0,0
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
; Vigueur, Reflexes, Volonte, PX, or, silhouette
MonTypes:
	dc.b	"KOBOLD",0,0,0,0,0,0,0,0,0,0
	dc.w	1,8,0,15,1,1,6,-1,20,2,2,2,0,18,4,2
	dc.b	"GOBELIN",0,0,0,0,0,0,0,0,0
	dc.w	1,8,1,15,2,1,6,0,20,2,3,1,-1,24,6,2
	dc.b	"RAT SANGUIN",0,0,0,0,0
	dc.w	1,8,1,15,4,1,4,0,20,2,3,3,3,24,0,0
	dc.b	"SQUELETTE",0,0,0,0,0,0,0
	dc.w	1,12,0,15,1,1,6,1,18,2,0,1,2,24,0,1
	dc.b	"ORC",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	1,8,1,15,4,2,4,4,18,2,3,0,-2,37,10,2
	dc.b	"HOBGOBELIN",0,0,0,0,0,0
	dc.w	1,8,2,15,2,1,8,1,19,2,4,1,-1,37,12,2
	dc.b	"ZOMBI",0,0,0,0,0,0,0,0,0,0,0
	dc.w	2,12,3,11,2,1,6,1,20,2,0,-1,3,37,0,1
	dc.b	"LOUP",0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	2,8,4,14,3,1,6,1,20,2,5,5,1,75,0,0
	dc.b	"GNOLL",0,0,0,0,0,0,0,0,0,0,0
	dc.w	2,8,2,15,3,1,8,2,20,3,4,0,0,75,14,2
	dc.b	"GOULE",0,0,0,0,0,0,0,0,0,0,0
	dc.w	2,12,0,14,2,1,6,1,20,2,0,2,5,75,0,1
	dc.b	"BUGBEAR",0,0,0,0,0,0,0,0,0
	dc.w	3,8,3,17,5,1,8,2,20,2,4,3,1,150,22,2
	dc.b	"WORG",0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	4,10,8,14,7,1,6,4,20,2,6,6,3,150,0,0
	dc.b	"OMBRE",0,0,0,0,0,0,0,0,0,0,0
	dc.w	3,12,0,13,3,1,6,0,20,2,1,3,4,225,0,1
	dc.b	"OGRE",0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	4,8,11,16,8,2,8,7,20,2,6,0,1,225,45,2
	dc.b	"HOMME-LEZARD",0,0,0,0
	dc.w	2,8,2,15,3,1,8,1,20,2,3,3,0,75,12,2
	dc.b	"GARGOUILLE",0,0,0,0,0,0
	dc.w	4,8,19,16,6,1,4,2,20,2,5,6,4,300,30,3
	dc.b	"OMBRE BLEME",0,0,0,0,0
	dc.w	4,12,0,15,3,1,4,1,20,2,1,2,5,225,25,1
	dc.b	"OURSALOUP",0,0,0,0,0,0,0
	dc.w	5,10,25,15,9,1,6,5,20,2,9,5,2,300,0,0
	dc.b	"HARPIE",0,0,0,0,0,0,0,0,0,0
	dc.w	7,8,0,15,7,1,6,0,20,2,2,7,6,300,40,3
	dc.b	"MINOTAURE",0,0,0,0,0,0,0
	dc.w	6,8,12,15,9,3,6,6,20,3,6,5,5,300,60,2
	dc.b	"TROLL",0,0,0,0,0,0,0,0,0,0,0
	dc.w	6,8,36,16,9,1,6,6,20,2,11,4,3,375,55,2
	dc.b	"SPECTRE",0,0,0,0,0,0,0,0,0
	dc.w	7,12,0,15,6,1,8,0,20,2,2,5,7,525,70,1
	dc.b	"MOMIE",0,0,0,0,0,0,0,0,0,0,0
	dc.w	8,12,3,20,11,1,6,10,20,2,4,2,8,375,90,1
	dc.b	"HYDRE",0,0,0,0,0,0,0,0,0,0,0
	dc.w	5,10,28,15,6,1,10,3,20,2,9,5,3,375,80,3
	dc.b	"GEANT COLLINE",0,0,0
	dc.w	12,8,48,17,16,2,8,10,20,2,12,3,4,525,200,2
NMONSTERS	= 25

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
	dc.b	13,15,16,17,18,19,20,21,22,23,24
	dc.b	11
	even
EncounterTab:
	dc.l	Encounter0,Encounter1,Encounter2

; nom (12), de de vie, attaque, sauvegardes fortes, lanceur
ClassTable:
	dc.b	"GUERRIER",0,0,0,0
	dc.w	10,0,1,0,0,0
	dc.b	"BARBARE",0,0,0,0,0
	dc.w	12,0,1,0,0,0
	dc.b	"ROUBLARD",0,0,0,0
	dc.w	6,1,0,1,0,0
	dc.b	"RODEUR",0,0,0,0,0,0
	dc.w	8,0,1,1,0,2
	dc.b	"PALADIN",0,0,0,0,0
	dc.w	10,0,1,0,1,2
	dc.b	"CLERC",0,0,0,0,0,0,0
	dc.w	8,1,1,0,1,2
	dc.b	"MAGICIEN",0,0,0,0
	dc.w	4,2,0,0,1,1
	dc.b	"ENSORCELEUR",0
	dc.w	4,2,0,0,1,1
NCLASSES	= 8

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
	dc.w	3,14,16,0
	dc.w	4,13,0,0
	dc.w	2,13,0,0
	dc.w	7,13,0,0
	dc.w	3,14,16,2
	dc.w	6,13,16,66
	dc.w	8,12,0,13
	dc.w	8,12,0,5

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
