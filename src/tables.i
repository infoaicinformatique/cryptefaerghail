;----------------------------------------------------------
; tables.i - GENERE PAR tools/gen_tables.py
;----------------------------------------------------------

; nom (18 octets), type, des, faces, bonus, valeur, bruitage
ItemTable:
	; 1 DAGUE
	dc.b	"DAGUE",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,1,4,0,2,0
	; 2 EPEE COURTE
	dc.b	"EPEE COURTE",0,0,0,0,0,0,0
	dc.w	0,1,6,0,10,0
	; 3 EPEE LONGUE
	dc.b	"EPEE LONGUE",0,0,0,0,0,0,0
	dc.w	0,1,8,0,15,0
	; 4 HACHE
	dc.b	"HACHE",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,1,8,0,12,1
	; 5 HACHE DE GUERRE
	dc.b	"HACHE DE GUERRE",0,0,0
	dc.w	0,1,10,0,20,1
	; 6 MASSE
	dc.b	"MASSE",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,1,8,0,12,1
	; 7 ARC COURT
	dc.b	"ARC COURT",0,0,0,0,0,0,0,0,0
	dc.w	0,1,6,0,30,2
	; 8 BATON
	dc.b	"BATON",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,1,6,0,5,0
	; 9 EPEE LONGUE +1
	dc.b	"EPEE LONGUE +1",0,0,0,0
	dc.w	0,1,8,1,100,0
	; 10 HACHE RUNIQUE +2
	dc.b	"HACHE RUNIQUE +2",0,0
	dc.w	0,1,10,2,200,1
	; 11 DAGUE DE FEU +1
	dc.b	"DAGUE DE FEU +1",0,0,0
	dc.w	0,2,4,1,120,0
	; 12 ROBE
	dc.b	"ROBE",0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	1,0,0,0,5,0
	; 13 ARMURE DE CUIR
	dc.b	"ARMURE DE CUIR",0,0,0,0
	dc.w	1,2,0,0,20,0
	; 14 COTTE DE MAILLES
	dc.b	"COTTE DE MAILLES",0,0
	dc.w	1,5,0,0,80,0
	; 15 HARNOIS
	dc.b	"HARNOIS",0,0,0,0,0,0,0,0,0,0,0
	dc.w	1,8,0,0,300,0
	; 16 BOUCLIER
	dc.b	"BOUCLIER",0,0,0,0,0,0,0,0,0,0
	dc.w	2,2,0,0,25,0
	; 17 POTION DE SOIN
	dc.b	"POTION DE SOIN",0,0,0,0
	dc.w	3,2,4,2,25,0
	; 18 POTION MAJEURE
	dc.b	"POTION MAJEURE",0,0,0,0
	dc.w	3,3,8,3,70,0
	; 19 PARCH. TRAIT
	dc.b	"PARCH. TRAIT",0,0,0,0,0,0
	dc.w	4,0,0,0,40,0
	; 20 PARCH. SOINS
	dc.b	"PARCH. SOINS",0,0,0,0,0,0
	dc.w	4,1,0,0,40,0
	; 21 PARCH. BRULURE
	dc.b	"PARCH. BRULURE",0,0,0,0
	dc.w	4,2,0,0,60,0
	; 22 PARCH. ARMURE
	dc.b	"PARCH. ARMURE",0,0,0,0,0
	dc.w	4,3,0,0,60,0
	; 23 PARCH. EFFROI
	dc.b	"PARCH. EFFROI",0,0,0,0,0
	dc.w	4,4,0,0,80,0
	; 24 PARCH. ECLAIR
	dc.b	"PARCH. ECLAIR",0,0,0,0,0
	dc.w	4,5,0,0,120,0
	; 25 CLE DE FER
	dc.b	"CLE DE FER",0,0,0,0,0,0,0,0
	dc.w	5,0,0,0,10,0
	; 26 CLE D'ARGENT
	dc.b	"CLE D'ARGENT",0,0,0,0,0,0
	dc.w	5,0,0,0,25,0
	; 27 GEMME
	dc.b	"GEMME",0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	6,0,0,0,120,0
	; 28 COURONNE
	dc.b	"COURONNE",0,0,0,0,0,0,0,0,0,0
	dc.w	6,0,0,0,400,0

; nom (20 octets), cout, genre, des, faces, bonus
SpellTable:
	dc.b	"TRAIT MAGIQUE",0,0,0,0,0,0,0
	dc.w	2,0,1,4,1
	dc.b	"SOINS LEGERS",0,0,0,0,0,0,0,0
	dc.w	2,1,1,8,1
	dc.b	"MAINS BRULANTES",0,0,0,0,0
	dc.w	3,0,2,4,0
	dc.b	"ARMURE DE MAGE",0,0,0,0,0,0
	dc.w	3,2,0,0,4
	dc.b	"EFFROI",0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	4,3,0,0,0
	dc.b	"ECLAIR",0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	6,0,3,6,0

; nom (12 octets), PV, CA, attaque, des, faces, PX, or
MonTypes:
	dc.b	"RAT GEANT",0,0,0
	dc.w	12,12,2,1,4,12,6
	dc.b	"SQUELETTE",0,0,0
	dc.w	20,14,3,1,6,24,15
	dc.b	"ORC",0,0,0,0,0,0,0,0,0
	dc.w	30,15,5,1,8,38,30
	dc.b	"DRAGONNET",0,0,0
	dc.w	48,17,7,2,6,75,95

; nom (12 octets), de de vie, magie, attaque rapide
ClassTable:
	dc.b	"GUERRIER",0,0,0,0
	dc.w	10,0,1
	dc.b	"BARBARE",0,0,0,0,0
	dc.w	12,0,1
	dc.b	"ECLAIREUR",0,0,0
	dc.w	8,2,0
	dc.b	"CLERC",0,0,0,0,0,0,0
	dc.w	8,6,0

StartGear:			; arme, armure, bouclier, sorts
	dc.w	3,14,16,0
	dc.w	4,13,0,0
	dc.w	7,13,0,0
	dc.w	6,13,0,2

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
