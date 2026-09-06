;----------------------------------------------------------------------
; crawl.s - LA CRYPTE DE FAERGHAIL
;
; Dungeon crawler en vue subjective pour Amiga 1200 (AGA), 68020+,
; AmigaOS 3.1. Dans l'esprit de Black Crypt et des jeux de role Amiga
; de 1990, avec des regles inspirees de D&D 3.5 : six caracteristiques,
; modificateurs, classe d'armure, jets d'attaque au d20, des de degats
; par arme, sorts a points de magie appris sur des parchemins.
;
; Ecran  : 320x256, 4 bitplanes, palette 24 bits, double tampon.
; Vue    : murs pre-calcules en perspective, poses au blitter du plus
;          loin au plus proche. Aucun calcul 3D a l'execution.
; Entree : clavier lu directement sur le CIA-A (AZERTY ou QWERTY).
; Son    : module ProTracker sur trois voies, bruitages sur la
;          quatrieme, empruntee le temps de l'effet.
;----------------------------------------------------------------------

	include	"hardware.i"
	include	"dgncol.i"		; noms des gammes de la palette

SCRW		= 320
SCRH		= 256
SCRBPL		= 40
DEPTH		= 8			; AGA : huit bitplanes, 256 couleurs
PLANESIZE	= SCRBPL*SCRH
SCRSIZE		= PLANESIZE*DEPTH

MAPW		= 24
MAPH		= 24
MAPBYTES	= MAPW*MAPH
LEVELS		= 5
LEVELSIZE	= 4+MAPBYTES*2		; entete, terrain, parametres

; --- terrain ---
T_FLOOR		= 0
T_WALL		= 1
T_DOOR		= 2
T_STAIRS	= 3
T_LOCKED	= 4
T_NICHE		= 5
T_RUNE		= 6
T_LEVER		= 7			; levier scelle dans un mur
T_GATE		= 8			; herse commandee par un levier
T_SHOP		= 9			; echoppe scellee dans un mur
T_TRAP		= 10			; dallage piege, invisible au depart
T_STELE		= 11			; stele gravee : une page du journal

; MapParam d'un piege : le quartet bas donne l'espece, le bit 7 dit que
; le groupe l'a repere. Un piege desamorce redevient du dallage.
TRAP_SEEN	= 7			; numero de bit
NTRAPS		= 4
tp_Name		= 0			; 16 octets
tp_Save		= 16			; 0 Vigueur, 1 Reflexes, 2 Volonte
tp_Faces	= 18			; faces du de de degats
tp_SIZEOF	= 20

NSHOP		= 8			; etals d'une echoppe
SHOPROWS	= 8			; lignes visibles
; --- contenu, quartet haut ---
C_CHEST		= $10
C_MONSTER	= $20
C_ITEM		= $30
C_MASK		= $30

; --- morceaux de decor : indices generes avec l'art lui-meme ---
	include	"artidx.i"

; --- heros ---
hr_Name		= 0			; 10 octets
hr_Class	= 10
hr_Level	= 12
hr_Xp		= 14
hr_Hp		= 16
hr_HpMax	= 18
hr_Mp		= 20
hr_MpMax	= 22
hr_Str		= 24
hr_Dex		= 26
hr_Con		= 28
hr_Int		= 30
hr_Wis		= 32
hr_Cha		= 34
hr_Weapon	= 36			; numero d'objet equipe
hr_Armor	= 38
hr_Shield	= 40
hr_Spells	= 42			; masque des sorts connus
hr_AcTemp	= 44			; bonus temporaire de CA
hr_Slots	= 46			; emplacements de sorts, niveaux 0 a 3
hr_Stun		= 54			; tours a passer : paralysie ou effroi
hr_StrLoss	= 56			; force perdue au poison, rendue au repos
hr_SIZEOF	= 58
NHEROES		= 4
NAMELEN		= 9

; --- objets ---
it_Name		= 0			; 18 octets
it_Type		= 18
it_Dice		= 20			; arme : nombre de des ; armure : CA
it_Faces	= 22
it_Bonus	= 24
it_Value	= 26
it_Sfx		= 28
it_Crit		= 30			; marge critique (19 = 19-20)
it_Mult		= 32
it_SIZEOF	= 34
IT_WEAPON	= 0
IT_ARMOR	= 1
IT_SHIELD	= 2
IT_POTION	= 3
IT_SCROLL	= 4
IT_KEY		= 5
IT_TREASURE	= 6
INVSIZE		= 24

; --- sorts ---
sp_Name		= 0			; 20 octets
sp_Level	= 20			; niveau de sort, 0 a 3
sp_Kind		= 22			; 0 degats, 1 soin, 2 armure, 3 terreur,
sp_Dice		= 24			; 4 benediction
sp_Faces	= 26
sp_Plus		= 28
sp_Cap		= 30			; plafond de des
sp_Save		= 32			; 0 aucun, 1 Vig, 2 Ref, 3 Vol
sp_Half		= 34
sp_School	= 36			; 1 profane, 2 divin, 3 les deux
sp_SIZEOF	= 38
MAXSPLEVEL	= 4

; --- monstres ---
mt_Name		= 0			; 16 octets
mt_Hd		= 16			; des de vie
mt_HdF		= 18
mt_HpB		= 20
mt_Ac		= 22
mt_Atk		= 24
mt_Dice		= 26
mt_Faces	= 28
mt_Dmg		= 30
mt_Crit		= 32
mt_Mult		= 34
mt_Fort		= 36
mt_Ref		= 38
mt_Will		= 40
mt_Xp		= 42
mt_Gold		= 44
mt_Art		= 46
mt_Special	= 48			; champ de bits, cf. gen_tables.py
mt_Pack		= 50			; combien s'en presentent a la fois
mt_SIZEOF	= 52

; Ce qu'une creature sait faire en plus de frapper. Vingt-cinq monstres
; qui se battaient tous de la meme facon ne valaient que par leurs
; nombres : une goule et un orc, c'etait le meme combat.
SP_POISON	= $01			; Vigueur, ou la force s'en va
SP_PARALYSE	= $02			; Vigueur, ou le heros perd un tour
SP_DRAIN	= $04			; Volonte, ou des PV pour de bon
SP_FEAR		= $08			; Volonte, ou il n'ose pas frapper
SP_REGEN	= $10			; la creature se referme
SP_DR		= $20			; sa peau encaisse les coups
SP_MULTI	= $40			; elle frappe deux fois
MON_DR		= 3			; ce qu'une peau epaisse retient
MON_REGEN	= 4			; ce qu'une chair qui se referme reprend

; --- classes ---
cl_Name		= 0			; 12 octets
cl_Hd		= 12			; de de vie
cl_Bab		= 14			; 0 complete, 1 trois quarts, 2 demie
cl_Fort		= 16			; 1 = sauvegarde forte
cl_Ref		= 18
cl_Will		= 20
cl_Cast		= 22			; 0 aucun, 1 profane (INT), 2 divin (SAG)
cl_SIZEOF	= 24
CLS_ROUBLARD	= 2
CLS_CLERC	= 5

; --- effets sonores ---
SFX_SWORD	= 0
SFX_AXE		= 1
SFX_BOW		= 2
SFX_HIT		= 3
SFX_MISS	= 4
SFX_DOOR	= 5
SFX_CHEST	= 6
SFX_POTION	= 7
SFX_SPELL	= 8
SFX_GROWL	= 9
SFX_LEVEL	= 10
SFX_STEP	= 11
SFX_DEATH	= 12
SFX_TRAP	= 13
SFX_COIN	= 14

; --- phases et ecrans ---
PHASE_CREATE	= 0
PHASE_PLAY	= 1
PHASE_TITLE	= 2			; l'ecran d'accueil
TITLEH		= 176			; hauteur de l'illustration
SAVEMAGIC	= $46414552		; "FAER"
SAVESIZE	= 4+12+NHEROES*hr_SIZEOF+INVSIZE+3*MAPBYTES+NSHOP+2
UI_VIEW		= 0
UI_SHEET	= 1
UI_INV		= 2
UI_SPELL	= 3
UI_RIDDLE	= 4
UI_MAP		= 5
UI_BOOK		= 6			; le grimoire
UI_OPTS		= 7			; les reglages
UI_SHOP		= 8			; l'echoppe du marchand
UI_LORE		= 9			; une page du journal

; Le journal. Un donjon sans recit n'est qu'un couloir : les steles
; gravees racontent la crypte a mesure qu'on s'y enfonce, comme les
; paragraphes numerotes des jeux dont celui-ci descend.
LORELINES	= 12			; lignes par page
LORECOLS	= 23		; ce que le panneau tient en largeur
LORE_INTRO	= 0			; la page qu'on lit avant de partir
LORE_WIN	= 1			; celle qui ferme le jeu
LORE_LOST	= 2			; et celle qui le ferme mal
LORE_FIRST	= 3			; les steles commencent la

; Les trois partitions. La musique change quand on s'enfonce : sur cinq
; etages, deux morceaux tournaient trop.
MUS_TITLE	= 0
MUS_DUNGEON	= 1
MUS_DEEP	= 2			; a partir de DEEP_LEVEL
DEEP_LEVEL	= 3			; le quatrieme etage, compte depuis zero

rd_SIZEOF	= 28
MAXCLEVEL	= 10			; plafond de niveau des heros
MAP_X		= 2			; carte : colonne octet du coin
MAP_Y		= 28			; et ligne du coin
MAP_CH		= 4			; hauteur d'une case, en lignes
SPELLMENU	= 10			; entrees du menu : touches 1 a 9 et 0

; --- codes clavier bruts ---
KEY_UP		= $4c
KEY_DOWN	= $4d
KEY_RIGHT	= $4e
KEY_LEFT	= $4f
KEY_SPACE	= $40
KEY_ESC		= $45
KEY_RETURN	= $44
KEY_BACKSP	= $41
KEY_TAB		= $42
KEY_1		= $01
KEY_A_QW	= $20			; A en QWERTY, Q en AZERTY
KEY_A_AZ	= $10			; A en AZERTY, Q en QWERTY
KEY_C		= $33
KEY_D		= $22
KEY_E		= $12
KEY_F		= $23
KEY_I		= $17
KEY_P		= $19
KEY_L		= $28			; meme place en AZERTY et en QWERTY
KEY_R		= $13
KEY_S		= $21
KEY_M_QW	= $37			; M sur un clavier anglais
KEY_M_AZ	= $29			; M sur un clavier francais
KEY_U		= $16

; --- disposition de l'ecran ---
PANEL_X		= 224
PANEL_W		= 96
LOG_Y		= 160
LOG_H		= 96
LOGLINES	= 4
LOGWIDTH	= 36

; Ou la souris tombe. Ce sont les bornes que les panneaux dessinent
; deja : elles vivent ici pour qu'un clic et un pixel s'accordent.
VIEW_L		= 16
VIEW_R		= 208
VIEW_T		= 16
VIEW_B		= 152
PANEL_TOP	= 12			; premier bloc d'aventurier
PANEL_STEP	= 37			; hauteur d'un bloc
PANEL_BOT	= 160
SPELLROW_Y	= 40			; premiere ligne du menu de sorts
RIDDLEROW_Y	= 60			; premiere reponse d'une enigme
COPSIZE		= 12000			; palette, sprites, et le degrade
					; de profondeur, ligne par ligne

;======================================================================
	SECTION	crawl,CODE
;======================================================================

Start:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	4.w,a6
	lea	GfxName,a1
	moveq	#39,d0
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,GfxBase
	beq	ExitNoGfx
	lea	DosName,a1		; pour lire et ecrire la sauvegarde
	moveq	#0,d0
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,DosBase
	bsr	CheckSave
	jsr	_LVOForbid(a6)

	move.l	GfxBase,a6
	move.l	gb_ActiView(a6),OldView
	move.l	gb_copinit(a6),OldCopper
	sub.l	a1,a1
	jsr	_LVOLoadView(a6)
	jsr	_LVOWaitTOF(a6)
	jsr	_LVOWaitTOF(a6)
	jsr	_LVOOwnBlitter(a6)
	jsr	_LVOWaitBlit(a6)

	lea	CUSTOM,a5
	move.w	INTENAR(a5),d0
	or.w	#DMAF_SETCLR,d0
	move.w	d0,OldIntena
	move.w	DMACONR(a5),d0
	or.w	#DMAF_SETCLR,d0
	move.w	d0,OldDmacon
	move.w	#$7fff,INTENA(a5)
	move.w	#$7fff,INTREQ(a5)
	move.w	#$7fff,DMACON(a5)

	bsr	InitScreen
	bsr	NewGame
	move.w	#PHASE_TITLE,Phase	; on arrive par l'accueil
	move.w	#1,OptMusic
	move.w	#1,OptSfx
	move.w	#MOUSE_W/2,MouseX	; le pointeur demarre au centre
	move.w	#MOUSE_H/2,MouseY
	move.w	JOY0DAT(a5),d0		; caler les compteurs, sinon le premier
	move.w	d0,d1			; ecart serait celui d'une machine
	and.w	#$00ff,d1		; allumee il y a longtemps
	move.w	d1,MouseRawX
	lsr.w	#8,d0
	move.w	d0,MouseRawY
	bsr	MoveSprite
	move.w	#-1,CurMusic		; l'accueil a sa propre musique
	moveq	#MUS_TITLE,d0
	bsr	PlayMusic
	move.w	#DMAF_SETCLR|DMAF_MASTER|DMAF_RASTER|DMAF_COPPER|DMAF_BLITTER|DMAF_AUDIO|DMAF_SPRITE,DMACON(a5)

	bsr	Redraw
	bsr	SwapBuffers
	bsr	Redraw

;----------------------------------------------------------------------
; Boucle principale
;
; MusicPoll est appele aussi pendant les longs redessins : sans cela le
; module perd des tics des qu'on se deplace, puisqu'un redessin complet
; depasse la duree d'une image.
;----------------------------------------------------------------------
MainLoop:
	bsr	WaitVBlank
	bsr	SurfFlicker		; la torche respire, sans un blit
	move.w	VHPOSR+CUSTOM,d0	; le balayage brasse le hasard : sans
	eor.w	d0,RngSeed+2		; cela, chaque partie serait identique
	bsr	MusicPoll

	tst.w	DrawReady
	beq.s	.noSwap
	clr.w	DrawReady
	bsr	SwapBuffers
.noSwap:
	tst.w	InCombat		; les monstres respirent
	beq.s	.noAnim
	addq.w	#1,AnimCount
	move.w	AnimCount,d0
	and.w	#7,d0
	bne.s	.noAnim
	move.w	AnimFrame,d0
	eor.w	#1,d0
	move.w	d0,AnimFrame
	move.w	#1,NeedRedraw
.noAnim:
	bsr	ReadMouse
	bsr	MouseAct
	bsr	PollKey
	tst.w	d0
	bmi.s	.noKey
	move.w	Phase,d1
	cmp.w	#PHASE_TITLE,d1
	bne.s	.notTitleKey
	bsr	TitleKey
	bra.s	.noKey
.notTitleKey:
	tst.w	d1
	bne.s	.playKey
	bsr	CreateKey
	bra.s	.noKey
.playKey:
	bsr	HandleKey
.noKey:
	tst.w	ShowIntro		; le recit s'ouvre sur la premiere
	beq.s	.noIntro		; image de jeu, une fois les visages
	clr.w	ShowIntro		; du groupe a l'ecran
	moveq	#LORE_INTRO,d0
	bsr	ShowLore
.noIntro:
	tst.w	NeedRedraw
	beq.s	.noDraw
	clr.w	NeedRedraw
	bsr	Redraw
	move.w	#1,DrawReady
.noDraw:
	tst.w	Quit
	beq	MainLoop

	bsr	PT_Stop
	bsr	RestoreSystem
	move.l	4.w,a6
	jsr	_LVOPermit(a6)
	move.l	DosBase,d0
	beq.s	.noDos
	move.l	d0,a1
	move.l	4.w,a6
	jsr	_LVOCloseLibrary(a6)
.noDos:
	move.l	GfxBase,a1
	move.l	4.w,a6
	jsr	_LVOCloseLibrary(a6)
ExitNoGfx:
	movem.l	(sp)+,d0-d7/a0-a6
	moveq	#0,d0
	rts

RestoreSystem:
	lea	CUSTOM,a5
	move.w	#$7fff,INTENA(a5)
	move.w	#$7fff,INTREQ(a5)
	move.w	#$7fff,DMACON(a5)
	move.l	OldCopper,COP1LCH(a5)
	move.w	d0,COPJMP1(a5)
	move.w	OldDmacon,DMACON(a5)
	move.w	OldIntena,INTENA(a5)
	move.l	GfxBase,a6
	jsr	_LVODisownBlitter(a6)
	move.l	OldView,a1
	jsr	_LVOLoadView(a6)
	jsr	_LVOWaitTOF(a6)
	jsr	_LVOWaitTOF(a6)
	jsr	_LVORethinkDisplay(a6)
	rts

;----------------------------------------------------------------------
; MusicPoll : un tic de module par trame, cadence sur le balayage ;
; a semer dans les traitements longs pour que le son ne decroche pas
;----------------------------------------------------------------------
; MusicPoll : un tic de replay par trame, ou que l'on en soit.
;
; L'ancienne version n'acceptait de rattraper un tic que si le balayage
; se trouvait dans le retour trame : treize lignes sur trois cent
; treize. Pendant un redessin qui dure deux trames, presque tous les
; appels tombaient a cote et la musique hoquetait -- c'est le defaut
; entendu en se deplacant. On regarde maintenant si le balayage a
; reboucle depuis le dernier appel : cela marche a n'importe quel
; moment de la trame.
MusicPoll:
	tst.w	OptMusic		; coupee dans les reglages
	beq.s	.muted
	movem.l	d0-d1/a5,-(sp)
	lea	CUSTOM,a5
	move.l	VPOSR(a5),d0
	and.l	#$0001ff00,d0
	lsr.l	#8,d0			; ligne courante
	move.w	MusicLine,d1
	move.w	d0,MusicLine
	cmp.w	d1,d0
	bge.s	.done			; toujours dans la meme trame
	bsr	PT_Tick			; le balayage a reboucle
.done:
	movem.l	(sp)+,d0-d1/a5
.muted:
	rts

;----------------------------------------------------------------------
; SfxPlay : d0 = numero d'effet, joue sur le canal 3
;
; Paula exige la meme sequence que pour une note : DMA coupe, registres
; charges, attente, DMA relance. Le replayer laisse le canal tranquille
; pendant le nombre de tics indique dans la table.
;----------------------------------------------------------------------
SfxPlay:
	tst.w	OptSfx			; coupes dans les reglages
	beq.s	.off
	movem.l	d0-d3/a0-a2/a6,-(sp)
	cmp.w	#SFX_STEP,d0		; le pas ne coupe pas un bruit en cours,
	bne.s	.play			; sinon la melodie hoquete quand on
	tst.w	PT_SfxLock		; enchaine les deplacements
	bne	.skip
.play:
	lea	SfxData,a0
	move.w	d0,d1
	mulu.w	#12,d1
	lea	2(a0,d1.w),a1
	move.l	(a1),d2
	add.l	a0,d2			; adresse de l'echantillon
	lea	CUSTOM,a6
	lea	CUSTOM+$d0,a2		; canal 3
	move.w	#$0008,DMACON(a6)	; DMA coupe
	move.l	d2,(a2)
	move.w	4(a1),4(a2)		; longueur
	move.w	6(a1),6(a2)		; periode
	move.w	8(a1),8(a2)		; volume
	bsr	RasterWait
	move.w	#$8008,DMACON(a6)	; relance
	move.l	#SfxSilence,(a2)	; puis boucle sur du silence
	move.w	#1,4(a2)
	move.w	10(a1),PT_SfxLock
.skip:
	movem.l	(sp)+,d0-d3/a0-a2/a6
.off:
	rts

;----------------------------------------------------------------------
; La souris
;
; JOY0DAT tient deux compteurs de huit bits qui tournent en rond : on
; ne lit pas une position mais une difference depuis la derniere image.
; Il faut donc etendre le signe du huitieme bit, sans quoi un mouvement
; vers la gauche se lit comme un bond de 255 pixels vers la droite.
;----------------------------------------------------------------------
MOUSE_W		= 320
MOUSE_H		= 256
SPR_HSTART	= $81			; premier pixel affiche, cf. DIWSTRT
SPR_VSTART	= $2c

ReadMouse:
	movem.l	d0-d4/a5,-(sp)
	lea	CUSTOM,a5
	move.w	JOY0DAT(a5),d0
	move.w	d0,d1
	and.w	#$00ff,d1		; compteur horizontal
	lsr.w	#8,d0			; compteur vertical
	move.w	d1,d2
	sub.w	MouseRawX,d2
	move.w	d0,d3
	sub.w	MouseRawY,d3
	move.w	d1,MouseRawX
	move.w	d0,MouseRawY
	bsr	MouseWrap		; d2 : -128..127
	move.w	d2,d4
	move.w	d3,d2
	bsr	MouseWrap
	move.w	d2,d3

	move.w	MouseX,d0
	add.w	d4,d0
	bpl.s	.xLow
	moveq	#0,d0
.xLow:
	cmp.w	#MOUSE_W-1,d0
	ble.s	.xOk
	move.w	#MOUSE_W-1,d0
.xOk:
	move.w	d0,MouseX
	move.w	MouseY,d0
	add.w	d3,d0
	bpl.s	.yLow
	moveq	#0,d0
.yLow:
	cmp.w	#MOUSE_H-1,d0
	ble.s	.yOk
	move.w	#MOUSE_H-1,d0
.yOk:
	move.w	d0,MouseY

	moveq	#0,d0			; --- boutons
	btst	#6,CIAAPRA		; gauche : le CIA, 0 = appuye
	bne.s	.noLeft
	moveq	#1,d0
.noLeft:
	move.w	POTGOR(a5),d1		; droit : POTGOR bit 10, 0 = appuye
	btst	#10,d1
	bne.s	.noRight
	or.w	#2,d0
.noRight:
	move.w	MouseBtn,d1
	move.w	d0,MouseBtn
	not.w	d1			; ce qui vient d'etre presse
	and.w	d0,d1
	or.w	d1,MouseHit
	bsr	MoveSprite
	movem.l	(sp)+,d0-d4/a5
	rts

MouseWrap:				; d2 : 0..255 tournant -> -128..127
	and.w	#$00ff,d2
	cmp.w	#128,d2
	blt.s	.done
	sub.w	#256,d2
.done:
	rts

; MoveSprite : pose les deux mots de controle du sprite 0. VSTART et
; VSTOP portent chacun un neuvieme bit dans SPRxCTL, et HSTART son bit
; zero : c'est la seule subtilite du format.
MoveSprite:
	movem.l	d0-d3/a0,-(sp)
	lea	MousePointer,a0
	move.w	MouseY,d0
	add.w	#SPR_VSTART,d0		; VSTART
	move.w	d0,d1
	add.w	#POINTER_H,d1		; VSTOP
	move.w	MouseX,d2
	add.w	#SPR_HSTART,d2		; HSTART
	move.w	d0,d3
	lsl.w	#8,d3
	move.w	d2,-(sp)
	lsr.w	#1,d2
	and.w	#$00ff,d2
	or.w	d2,d3
	move.w	d3,(a0)			; SPR0POS
	move.w	(sp)+,d2
	move.w	d1,d3
	lsl.w	#8,d3
	btst	#8,d0			; VSTART bit 8 -> bit 2
	beq.s	.noV8
	or.w	#$0004,d3
.noV8:
	btst	#8,d1			; VSTOP bit 8 -> bit 1
	beq.s	.noS8
	or.w	#$0002,d3
.noS8:
	btst	#0,d2			; HSTART bit 0 -> bit 0
	beq.s	.noH0
	or.w	#$0001,d3
.noH0:
	move.w	d3,2(a0)		; SPR0CTL
	movem.l	(sp)+,d0-d3/a0
	rts


;----------------------------------------------------------------------
; MouseAct : ce qu'un clic veut dire, selon l'endroit
;
; Plutot que de doubler la logique du clavier, un clic se traduit en
; touche et repart dans HandleKey : tout ce qui vaut pour l'une vaut
; pour l'autre, y compris le redessin.
;----------------------------------------------------------------------
MouseAct:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	MouseHit,d7
	beq	.done
	clr.w	MouseHit
	cmp.w	#PHASE_PLAY,Phase	; l'accueil et la creation restent au
	bne	.done			; clavier : trop peu de cibles
	tst.w	GameOver
	bne	.done
	move.w	MouseX,d5
	move.w	MouseY,d6

	cmp.w	#PANEL_X-4,d5		; --- le panneau du groupe : un clic
	blt.s	.notParty		; sur un bloc choisit ce heros
	cmp.w	#PANEL_BOT,d6
	bge	.done
	move.w	d6,d0
	sub.w	#PANEL_TOP,d0
	bmi	.done
	and.l	#$0000ffff,d0
	divu.w	#PANEL_STEP,d0
	and.l	#$0000ffff,d0
	cmp.w	#NHEROES,d0
	bge	.done
	add.w	#KEY_1,d0
	bsr	HandleKey
	bra	.done

.notParty:
	cmp.w	#VIEW_L,d5		; hors de la vue : rien a faire
	blt	.done
	cmp.w	#VIEW_R,d5
	bge	.done
	cmp.w	#VIEW_T,d6
	blt	.done
	cmp.w	#VIEW_B,d6
	bge	.done

	move.w	UiMode,d4
	bne	.panel

	btst	#1,d7			; --- la vue. Le bouton droit agit :
	beq.s	.viewLeft		; il ne quitte pas le jeu, ce serait
	moveq	#KEY_SPACE,d0		; trop facile a faire par megarde
	bsr	HandleKey
	bra	.done
.viewLeft:
	tst.w	InCombat		; en combat, cliquer c'est frapper
	beq.s	.viewMove
	moveq	#KEY_A_QW,d0
	bsr	HandleKey
	bra	.done
.viewMove:
	move.w	d5,d1			; la rose des vents : trois colonnes,
	sub.w	#VIEW_L,d1		; trois rangees
	cmp.w	#(VIEW_R-VIEW_L)/3,d1
	blt.s	.colLeft
	cmp.w	#2*(VIEW_R-VIEW_L)/3,d1
	bge.s	.colRight
	move.w	d6,d1
	sub.w	#VIEW_T,d1
	cmp.w	#(VIEW_B-VIEW_T)/3,d1
	blt.s	.fwd
	cmp.w	#2*(VIEW_B-VIEW_T)/3,d1
	blt.s	.act
	moveq	#KEY_DOWN,d0
	bra.s	.hit
.fwd:
	moveq	#KEY_UP,d0
	bra.s	.hit
.act:
	moveq	#KEY_SPACE,d0
	bra.s	.hit
.colLeft:
	moveq	#KEY_LEFT,d0
	bra.s	.hit
.colRight:
	moveq	#KEY_RIGHT,d0
.hit:
	bsr	HandleKey
	bra	.done

.panel:
	btst	#1,d7			; bouton droit : refermer
	beq.s	.panelLeft
	moveq	#KEY_ESC,d0
	bsr	HandleKey
	bra	.done
.panelLeft:
	cmp.w	#UI_SPELL,d4		; ces deux-la se repondent au chiffre
	beq.s	.digits
	cmp.w	#UI_RIDDLE,d4
	beq.s	.digits
	lea	PanelHit,a3		; les listes a curseur
.seek:
	move.w	(a3),d0
	beq	.done			; panneau sans liste
	cmp.w	d4,d0
	beq.s	.found
	lea	ph_SIZEOF(a3),a3
	bra.s	.seek
.found:
	move.w	d6,d0
	move.w	ph_First(a3),d1
	move.w	ph_Step(a3),d2
	bsr	MouseRow
	tst.w	d0
	bmi	.done
	cmp.w	ph_Count(a3),d0
	bge	.done
	move.l	ph_Top(a3),a0
	add.w	(a0),d0			; la liste peut avoir defile
	move.l	ph_Cursor(a3),a1
	cmp.w	(a1),d0			; deja sous le curseur : on conclut
	beq.s	.confirm
	move.w	d0,(a1)
	move.w	#1,NeedRedraw
	bra.s	.done
.confirm:
	move.w	ph_Key(a3),d0
	beq.s	.done
	bsr	HandleKey
	bra.s	.done
.digits:
	move.w	d6,d0
	move.w	#SPELLROW_Y,d1
	moveq	#11,d2
	cmp.w	#UI_SPELL,d4
	beq.s	.rowGo
	move.w	#RIDDLEROW_Y,d1
	moveq	#12,d2
.rowGo:
	bsr	MouseRow
	tst.w	d0
	bmi.s	.done
	cmp.w	#SPELLMENU,d0
	bge.s	.done
	add.w	#KEY_1,d0
	bsr	HandleKey
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; MouseRow : d0 = ordonnee du clic, d1 = premiere ligne, d2 = pas
;         -> d0 = numero de ligne, ou -1 si le clic tombe entre deux
MouseRow:
	sub.w	d1,d0
	bmi.s	.none
	and.l	#$0000ffff,d0
	divu.w	d2,d0
	move.l	d0,d1
	swap	d1
	cmp.w	#8,d1			; le texte ne fait que huit pixels
	bge.s	.none
	and.l	#$0000ffff,d0
	rts
.none:
	moveq	#-1,d0
	rts


RasterWait:				; environ deux lignes
	movem.l	d0-d1/a6,-(sp)
	lea	CUSTOM,a6
	moveq	#1,d1
.line:
	move.b	VHPOSR(a6),d0
.wait:
	cmp.b	VHPOSR(a6),d0
	beq.s	.wait
	dbf	d1,.line
	movem.l	(sp)+,d0-d1/a6
	rts

;----------------------------------------------------------------------
; Ecran : copperlist, palette 24 bits, double tampon
;----------------------------------------------------------------------
InitScreen:
	lea	ScreenA,a0
	move.l	a0,ShowBuf
	lea	ScreenB,a0
	move.l	a0,DrawBuf

	lea	CopList,a2
	move.w	#FMODE,(a2)+
	move.w	#$0000,(a2)+
	move.w	#BPLCON0,(a2)+
	move.w	#$0211,(a2)+		; BPU3 = 8 plans, COLOR, ECSENA
	move.w	#BPLCON1,(a2)+
	move.w	#$0000,(a2)+
	move.w	#BPLCON2,(a2)+
	move.w	#$0024,(a2)+
	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+
	move.w	#BPLCON4,(a2)+
	move.w	#$00ff,(a2)+		; ESPRM/OSPRM = $f : couleurs $f0-$ff
	move.w	#DIWSTRT,(a2)+
	move.w	#$2c81,(a2)+
	move.w	#DIWSTOP,(a2)+
	move.w	#$2cc1,(a2)+
	move.w	#DDFSTRT,(a2)+
	move.w	#$0038,(a2)+
	move.w	#DDFSTOP,(a2)+
	move.w	#$00d0,(a2)+
	move.w	#BPL1MOD,(a2)+
	move.w	#$0000,(a2)+
	move.w	#BPL2MOD,(a2)+
	move.w	#$0000,(a2)+

	move.w	#SPR0PTH,d1		; sprite 0 : le pointeur ; les sept
	moveq	#7,d2			; autres pointent sur deux zeros
	lea	MousePointer,a3
.sprLoop:
	move.l	a3,d0
	move.w	d1,(a2)+
	swap	d0
	move.w	d0,(a2)+
	addq.w	#2,d1
	swap	d0
	move.w	d1,(a2)+
	move.w	d0,(a2)+
	addq.w	#2,d1
	lea	NullSprite,a3
	dbf	d2,.sprLoop

	move.l	a2,CopBplPtrs
	move.w	#BPL1PTH,d1
	moveq	#DEPTH-1,d2
.bplLoop:
	move.w	d1,(a2)+
	clr.w	(a2)+
	addq.w	#2,d1
	move.w	d1,(a2)+
	clr.w	(a2)+
	addq.w	#2,d1
	dbf	d2,.bplLoop

	; --- 256 couleurs : huit banques de trente-deux, chacune ecrite
	; deux fois, quartets hauts puis quartets bas (LOCT).
	lea	DgnPalette,a3
	moveq	#0,d3			; numero de banque
.bankLoop:
	move.w	d3,d4
	lsl.w	#8,d4
	lsl.w	#5,d4			; BANK dans les bits 15-13
	move.w	#BPLCON3,(a2)+
	move.w	d4,(a2)+
	move.w	#COLOR00,d1
	moveq	#31,d2
.hiLoop:
	move.w	d1,(a2)+
	move.w	(a3),(a2)+
	addq.l	#4,a3
	addq.w	#2,d1
	dbf	d2,.hiLoop
	sub.l	#32*4,a3		; on relit la meme banque
	move.w	#BPLCON3,(a2)+
	or.w	#$0200,d4
	move.w	d4,(a2)+
	move.w	#COLOR00,d1
	moveq	#31,d2
.loLoop:
	move.w	d1,(a2)+
	move.w	2(a3),(a2)+
	addq.l	#4,a3
	addq.w	#2,d1
	dbf	d2,.loLoop
	addq.w	#1,d3
	cmp.w	#8,d3
	blt.s	.bankLoop
	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+		; retour banque 0, LOCT = 0

	; --- Le degrade de profondeur du sol et de la voute.
	;
	; La gamme de pierre compte vingt teintes : la profondeur s'y
	; lisait en vingt marches sur cinquante-sept lignes, et le
	; dallage montrait des bandes. Le sol et la voute ne portent plus
	; que leur variation locale -- joint, usure, mousse, suie -- sur
	; douze cases, et le copper reecrit ces douze cases toutes les
	; deux lignes. Il y a donc soixante-huit profondeurs a l'ecran la
	; ou la palette n'en tient que vingt, et les douze cases ne
	; coutent rien au reste du decor.
	move.l	a2,CopSurf		; on y revient a chaque trame
	lea	SurfGradient,a3
	moveq	#0,d3
.surfLoop:
	move.w	d3,d4
	mulu.w	#SURF_LINES,d4
	add.w	#SURF_FIRST+SPR_VSTART,d4
	lsl.w	#8,d4
	or.w	#$0001,d4		; WAIT en debut de ligne
	move.w	d4,(a2)+
	move.w	#$fffe,(a2)+
	move.w	#BPLCON3,(a2)+
	move.w	#$e000,(a2)+		; banque 7, quartets hauts
	bsr	CopSurfBlock
	move.w	#BPLCON3,(a2)+
	move.w	#$e200,(a2)+		; banque 7, LOCT : quartets bas
	bsr	CopSurfBlock
	addq.w	#1,d3
	cmp.w	#SURF_BLOCKS,d3
	blt	.surfLoop
	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+

	move.l	#$fffffffe,(a2)+

	bsr	SetBplPtrs
	lea	CUSTOM,a5
	move.l	#CopList,COP1LCH(a5)
	move.w	d0,COPJMP1(a5)
	rts

; CopSurfBlock : douze paires registre/couleur, a3 lisant le degrade
CopSurfBlock:
	movem.l	d1-d2,-(sp)
	move.w	#COLOR00+2*(C_SURF-224),d1
	moveq	#N_SURF-1,d2
.loop:
	move.w	d1,(a2)+
	move.w	(a3)+,(a2)+
	addq.w	#2,d1
	dbf	d2,.loop
	movem.l	(sp)+,d1-d2
	rts

; SurfFlicker : fait respirer la lumiere de la torche.
;
; Le decor ne bouge pas d'un pixel : on ne recopie que les valeurs de
; couleur dans la copperlist, en piochant dans l'une des clartes
; preparees. Mille six cent trente-deux mots par trame, ecrits juste
; apres le retour trame -- le copper ne relira le degrade qu'a la ligne
; soixante.
SurfFlicker:
	movem.l	d0-d3/a0-a1,-(sp)
	bsr	Rnd			; une marche au hasard, bornee : une
	and.w	#3,d0			; flamme ne saute pas d'un extreme
	cmp.w	#3,d0			; a l'autre. Le pas doit etre centre,
	bne.s	.step			; sinon la marche derive vers le haut
	moveq	#1,d0			; et s'y colle
.step:
	subq.w	#1,d0			; -1, 0 ou +1
	add.w	SurfPhase,d0
	bpl.s	.notLow
	moveq	#0,d0
.notLow:
	cmp.w	#SURF_VARIANTS,d0
	blt.s	.inRange
	move.w	#SURF_VARIANTS-1,d0
.inRange:
	cmp.w	SurfPhase,d0
	beq.s	.done			; rien de neuf : on ne recopie pas
	move.w	d0,SurfPhase
	mulu.w	#SURF_VARSIZE*2,d0
	lea	SurfGradient,a0
	add.l	d0,a0
	move.l	CopSurf,d1
	beq.s	.done
	move.l	d1,a1
	move.w	#SURF_BLOCKS-1,d3
.block:
	addq.l	#8,a1			; le WAIT et le BPLCON3
	moveq	#N_SURF-1,d2
.hi:
	addq.l	#2,a1			; le numero de registre ne change pas
	move.w	(a0)+,(a1)+
	dbf	d2,.hi
	addq.l	#4,a1			; le BPLCON3 qui arme LOCT
	moveq	#N_SURF-1,d2
.lo:
	addq.l	#2,a1
	move.w	(a0)+,(a1)+
	dbf	d2,.lo
	dbf	d3,.block
.done:
	movem.l	(sp)+,d0-d3/a0-a1
	rts


SetBplPtrs:
	movem.l	d0-d2/a0-a1,-(sp)
	move.l	CopBplPtrs,a1
	move.l	ShowBuf,d0
	moveq	#DEPTH-1,d2
.loop:
	move.l	d0,d1
	swap	d1
	move.w	d1,2(a1)
	move.w	d0,6(a1)
	lea	8(a1),a1
	add.l	#PLANESIZE,d0
	dbf	d2,.loop
	movem.l	(sp)+,d0-d2/a0-a1
	rts

SwapBuffers:
	move.l	ShowBuf,d0
	move.l	DrawBuf,d1
	move.l	d1,ShowBuf
	move.l	d0,DrawBuf
	bsr	SetBplPtrs
	rts

WaitVBlank:
	movem.l	d0/a5,-(sp)
	lea	CUSTOM,a5
.wait:
	move.l	VPOSR(a5),d0
	and.l	#$0001ff00,d0
	cmp.l	#300<<8,d0
	bne.s	.wait
	movem.l	(sp)+,d0/a5
	rts

WaitBlit:
	tst.w	DMACONR+CUSTOM
.wb:
	btst	#6,DMACONR+CUSTOM
	bne.s	.wb
	rts

;----------------------------------------------------------------------
; BlitPiece  : d0 = morceau, d1 = 0 avec masque sinon copie simple
; BlitPieceAt: idem, mais d2 impose la destination (portraits, icones)
;----------------------------------------------------------------------
BlitPiece:
	moveq	#-1,d2
BlitPieceAt:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	CUSTOM,a6
	lea	DgnArt,a0
	move.w	d0,d3
	mulu.w	#12,d3
	lea	2(a0,d3.w),a1
	move.l	(a1),d3
	add.l	a0,d3
	moveq	#0,d4
	move.w	4(a1),d4		; largeur en mots
	moveq	#0,d5
	move.w	6(a1),d5		; hauteur
	tst.l	d2
	bpl.s	.haveDst
	moveq	#0,d2
	move.w	8(a1),d2		; destination par defaut
.haveDst:
	move.l	d4,d7
	add.l	d7,d7
	mulu.w	d5,d7			; octets par plan du morceau

	move.l	DrawBuf,a2
	add.l	d2,a2
	move.l	d3,a3			; masque
	add.l	d7,d3			; premier plan

	move.w	d4,d6
	add.w	d6,d6
	neg.w	d6
	add.w	#SCRBPL,d6		; modulo destination

	moveq	#DEPTH-1,d0
.planeLoop:
	bsr	WaitBlit
	tst.w	d1
	bne.s	.noMask
	move.w	#BLT_USEA|BLT_USEB|BLT_USEC|BLT_USED|BLT_COOKIE,BLTCON0(a6)
	clr.w	BLTCON1(a6)
	move.w	#-1,BLTAFWM(a6)
	move.w	#-1,BLTALWM(a6)
	clr.w	BLTAMOD(a6)
	clr.w	BLTBMOD(a6)
	move.w	d6,BLTCMOD(a6)
	move.w	d6,BLTDMOD(a6)
	move.l	a3,BLTAPT(a6)
	move.l	d3,BLTBPT(a6)
	move.l	a2,BLTCPT(a6)
	move.l	a2,BLTDPT(a6)
	bra.s	.go
.noMask:
	move.w	#BLT_USEA|BLT_USED|BLT_COPY,BLTCON0(a6)
	clr.w	BLTCON1(a6)
	move.w	#-1,BLTAFWM(a6)
	move.w	#-1,BLTALWM(a6)
	clr.w	BLTAMOD(a6)
	move.w	d6,BLTDMOD(a6)
	move.l	d3,BLTAPT(a6)
	move.l	a2,BLTDPT(a6)
.go:
	move.w	d5,d2
	lsl.w	#6,d2
	or.w	d4,d2
	move.w	d2,BLTSIZE(a6)
	add.l	d7,d3
	lea	PLANESIZE(a2),a2
	dbf	d0,.planeLoop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; FillRect : d0 = x (mult. de 16), d1 = y, d2 = largeur, d3 = hauteur,
;            d4 = couleur
;----------------------------------------------------------------------
FillRect:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	CUSTOM,a6
	move.l	DrawBuf,a2
	move.w	d1,d5
	mulu.w	#SCRBPL,d5
	move.w	d0,d6
	lsr.w	#3,d6
	add.w	d6,d5
	add.l	d5,a2
	lsr.w	#4,d2
	move.w	d2,d6
	add.w	d6,d6
	neg.w	d6
	add.w	#SCRBPL,d6
	moveq	#0,d5
.planeLoop:
	bsr	WaitBlit
	btst	d5,d4
	beq.s	.zero
	move.w	#BLT_USED|$00ff,BLTCON0(a6)
	bra.s	.set
.zero:
	move.w	#BLT_USED,BLTCON0(a6)
.set:
	clr.w	BLTCON1(a6)
	move.w	d6,BLTDMOD(a6)
	move.l	a2,BLTDPT(a6)
	move.w	d3,d7
	lsl.w	#6,d7
	or.w	d2,d7
	move.w	d7,BLTSIZE(a6)
	lea	PLANESIZE(a2),a2
	addq.w	#1,d5
	cmp.w	#DEPTH,d5
	blt.s	.planeLoop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; HLine : d0 = x (mult. de 8), d1 = y, d2 = longueur, d3 = couleur
HLine:
	movem.l	d0-d7/a0-a2,-(sp)
	bsr	WaitBlit
	move.l	DrawBuf,a2
	move.w	d1,d4
	mulu.w	#SCRBPL,d4
	move.w	d0,d5
	lsr.w	#3,d5
	add.w	d5,d4
	add.l	d4,a2
	lsr.w	#3,d2			; largeur en octets
	beq	.tooThin		; moins d'un octet : rien a tracer
	moveq	#0,d5
.planeLoop:
	move.l	a2,a0
	move.w	d2,d6
	subq.w	#1,d6
	btst	d5,d3
	beq.s	.clear
.setLoop:
	move.b	#$ff,(a0)+
	dbf	d6,.setLoop
	bra.s	.next
.clear:
	clr.b	(a0)+
	dbf	d6,.clear
.next:
	lea	PLANESIZE(a2),a2
	addq.w	#1,d5
	cmp.w	#DEPTH,d5
	blt.s	.planeLoop
.tooThin:
	movem.l	(sp)+,d0-d7/a0-a2
	rts

; VLine : d0 = x, d1 = y, d2 = hauteur, d3 = couleur
VLine:
	movem.l	d0-d7/a0-a2,-(sp)
	bsr	WaitBlit
	move.l	DrawBuf,a2
	move.w	d1,d4
	mulu.w	#SCRBPL,d4
	move.w	d0,d5
	lsr.w	#3,d5
	add.w	d5,d4
	add.l	d4,a2
	move.w	d0,d7
	and.w	#7,d7
	eor.w	#7,d7
	moveq	#0,d5
.planeLoop:
	move.l	a2,a0
	move.w	d2,d6
	subq.w	#1,d6
	btst	d5,d3
	beq.s	.clear
.setLoop:
	bset	d7,(a0)
	lea	SCRBPL(a0),a0
	dbf	d6,.setLoop
	bra.s	.next
.clear:
	bclr	d7,(a0)
	lea	SCRBPL(a0),a0
	dbf	d6,.clear
.next:
	lea	PLANESIZE(a2),a2
	addq.w	#1,d5
	cmp.w	#DEPTH,d5
	blt.s	.planeLoop
	movem.l	(sp)+,d0-d7/a0-a2
	rts

; DrawBox : d0 = x, d1 = y, d2 = largeur, d3 = hauteur, d4 = couleur
; DrawFrame : un cadre de bronze biseaute, d0,d1 = coin, d2,d3 = taille.
; Trois traits -- ombre exterieure, corps du bronze, arete eclairee en
; haut et a gauche -- et un clou a chaque angle. En 256 couleurs le
; relief se lit tout seul, la ou un trait unique restait plat.
DrawFrame:
	movem.l	d0-d4,-(sp)
	subq.w	#1,d0			; ombre portee, un pixel dehors
	subq.w	#1,d1
	addq.w	#2,d2
	addq.w	#2,d3
	move.w	#C_FRAMEDK,d4
	bsr	DrawBox
	movem.l	(sp),d0-d4		; le corps du cadre
	move.w	#C_FRAME,d4
	bsr	DrawBox
	movem.l	(sp),d0-d4		; arete eclairee : le haut
	addq.w	#1,d0
	addq.w	#1,d1
	subq.w	#2,d2
	move.w	#C_FRAMELIT,d3
	bsr	HLine
	movem.l	(sp),d0-d4		; arete eclairee : la gauche
	addq.w	#1,d0
	addq.w	#1,d1
	subq.w	#2,d3
	move.w	d3,d2
	move.w	#C_FRAMELIT,d3
	bsr	VLine
	movem.l	(sp),d0-d4		; les quatre clous
	bsr	DrawStud
	movem.l	(sp),d0-d4
	add.w	d2,d0
	subq.w	#4,d0
	bsr	DrawStud
	movem.l	(sp),d0-d4
	add.w	d3,d1
	subq.w	#4,d1
	bsr	DrawStud
	movem.l	(sp),d0-d4
	add.w	d2,d0
	subq.w	#4,d0
	add.w	d3,d1
	subq.w	#4,d1
	bsr	DrawStud
	movem.l	(sp)+,d0-d4
	rts

; DrawStud : un clou de trois pixels sur trois, d0,d1 = coin.
; On passe par VLine, seul trait au pixel pres : HLine travaille a
; l'octet et ne saurait pas dessiner trois pixels de large.
DrawStud:
	movem.l	d0-d4,-(sp)
	moveq	#3,d2
	move.w	#C_FRAMELIT,d3
	bsr	VLine
	movem.l	(sp),d0-d4
	addq.w	#1,d0
	moveq	#3,d2
	move.w	#C_GOLD+N_GOLD-2,d3
	bsr	VLine
	movem.l	(sp),d0-d4
	addq.w	#2,d0
	moveq	#3,d2
	move.w	#C_FRAMEDK,d3
	bsr	VLine
	movem.l	(sp)+,d0-d4
	rts

; DrawGauge : une jauge de trois pixels de haut, au pixel pres.
;   d0 = x, d1 = y, d2 = largeur, d3 = valeur, d4 = maximum,
;   d5 = couleur de la part remplie ; le creux reste sombre.
DrawGauge:
	movem.l	d0-d7,-(sp)
	moveq	#0,d6			; nombre de pixels remplis
	tst.w	d4
	beq.s	.haveN
	tst.w	d3
	ble.s	.haveN
	move.w	d3,d6
	mulu.w	d2,d6
	divu.w	d4,d6
	and.l	#$0000ffff,d6
.haveN:
	move.w	d2,d7
	subq.w	#1,d7
	moveq	#0,d2			; colonne courante
.colLoop:
	movem.l	d0-d7,-(sp)
	move.w	d5,d3
	cmp.w	d6,d2
	blt.s	.filled
	move.w	#C_FRAMEDK,d3		; le creux de la jauge
.filled:
	add.w	d2,d0
	moveq	#3,d2
	bsr	VLine
	movem.l	(sp)+,d0-d7
	addq.w	#1,d2
	dbf	d7,.colLoop
	movem.l	(sp)+,d0-d7
	rts

DrawBox:
	movem.l	d0-d4,-(sp)
	move.l	d4,d5
	exg	d3,d5
	bsr	HLine
	movem.l	(sp),d0-d4
	add.w	d3,d1
	subq.w	#1,d1
	move.l	d4,d5
	exg	d3,d5
	bsr	HLine
	movem.l	(sp),d0-d4
	move.w	d3,d2
	move.w	d4,d3
	bsr	VLine
	movem.l	(sp),d0-d4
	add.w	d2,d0
	subq.w	#1,d0
	move.w	d3,d2
	move.w	d4,d3
	bsr	VLine
	movem.l	(sp)+,d0-d4
	rts

;----------------------------------------------------------------------
; DrawText : a0 = chaine, d0 = colonne, d1 = ligne, d2 = couleur
;----------------------------------------------------------------------
DrawText:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	d1,d3
	mulu.w	#SCRBPL,d3
	add.w	d0,d3
	move.l	DrawBuf,a3
	add.l	d3,a3
.charLoop:
	moveq	#0,d4
	move.b	(a0)+,d4
	beq	.done
	sub.w	#32,d4
	bmi.s	.next
	cmp.w	#96,d4
	bge.s	.next
	lea	Font8Map,a1
	move.b	(a1,d4.w),d4
	and.w	#$00ff,d4
	cmp.w	#$00ff,d4
	beq.s	.next
	lsl.w	#3,d4
	lea	Font8,a1
	add.w	d4,a1
	moveq	#0,d5
	move.l	a3,a2
.planeLoop:
	moveq	#0,d3			; $ff si ce plan porte la couleur
	btst	d5,d2
	beq.s	.planeZero
	moveq	#-1,d3
.planeZero:
	moveq	#7,d6
	move.l	a2,a4
	move.l	a1,a5
.rowLoop:
	; Le texte etait pose au OU : il ne rendait juste que sur du noir,
	; et virait de couleur des qu'un fond passait dessous. On efface
	; donc le pave du caractere avant d'y poser le glyphe.
	move.b	(a5)+,d4		; bits du glyphe
	move.b	(a4),d7
	move.b	d4,d0
	not.b	d0
	and.b	d0,d7			; trou a la forme du caractere
	and.b	d3,d4			; le glyphe, si le plan est allume
	or.b	d4,d7
	move.b	d7,(a4)
	lea	SCRBPL(a4),a4
	dbf	d6,.rowLoop
	lea	PLANESIZE(a2),a2
	addq.w	#1,d5
	cmp.w	#DEPTH,d5
	blt.s	.planeLoop
.next:
	addq.l	#1,a3
	bra	.charLoop
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; StrCopy : a0 = source, a1 = destination (laisse a1 sur le zero final)
StrCopy:
	move.b	(a0)+,(a1)
	beq.s	.done
	addq.l	#1,a1
	bra.s	StrCopy
.done:
	rts

; StrNum : d0 = valeur, a1 = destination
StrNum:
	movem.l	d0-d3/a0/a2,-(sp)
	lea	NumBuf+10,a2
	clr.b	-(a2)
	and.l	#$0000ffff,d0
.digit:
	divu.w	#10,d0
	move.l	d0,d1
	swap	d1
	add.b	#'0',d1
	move.b	d1,-(a2)
	and.l	#$0000ffff,d0
	tst.w	d0
	bne.s	.digit
	move.l	a2,a0
.copy:
	move.b	(a0)+,(a1)
	beq.s	.done
	addq.l	#1,a1
	bra.s	.copy
.done:
	movem.l	(sp)+,d0-d3/a0/a2
	rts

; StrSigned : d0 = valeur signee, a1 = destination ("+3" ou "-1")
StrSigned:
	movem.l	d0,-(sp)
	tst.w	d0
	bmi.s	.neg
	move.b	#'+',(a1)+
	bra.s	.num
.neg:
	move.b	#'-',(a1)+
	neg.w	d0
.num:
	and.l	#$0000ffff,d0
	bsr	StrNum
	movem.l	(sp)+,d0
	rts

;----------------------------------------------------------------------
; Clavier : le CIA donne des codes de position, pas des caracteres
;----------------------------------------------------------------------
PollKey:
	move.b	CIAAICR,d1
	btst	#3,d1
	beq.s	.none
	moveq	#0,d0
	move.b	CIAASDR,d0
	not.b	d0
	ror.b	#1,d0
	bset	#6,CIAACRA
	bsr	RasterWait
	bclr	#6,CIAACRA
	btst	#7,d0
	bne.s	.none
	and.w	#$007f,d0
	rts
.none:
	moveq	#-1,d0
	rts

;----------------------------------------------------------------------
; Hasard et des
;----------------------------------------------------------------------
Rnd:
	move.l	RngSeed,d0
	move.l	d0,d1
	lsl.l	#8,d1
	lsl.l	#5,d1
	eor.l	d1,d0
	move.l	d0,d1
	lsr.l	#8,d1
	lsr.l	#8,d1
	lsr.l	#1,d1
	eor.l	d1,d0
	move.l	d0,d1
	lsl.l	#5,d1
	eor.l	d1,d0
	move.l	d0,RngSeed
	rts

RndMod:					; d1 = borne -> d0 = 0..d1-1
	tst.w	d1			; borne nulle : pas de division
	bne.s	.ok
	moveq	#0,d0
	rts
.ok:
	movem.l	d1-d2,-(sp)
	move.l	d1,d2
	bsr	Rnd
	and.l	#$00007fff,d0
	divu.w	d2,d0
	clr.w	d0
	swap	d0
	movem.l	(sp)+,d1-d2
	rts

; RollDice : d0 = nombre de des, d1 = faces -> d0 = total
RollDice:
	movem.l	d1-d3,-(sp)
	move.w	d0,d3
	moveq	#0,d2
.loop:
	tst.w	d3
	beq.s	.done
	bsr	RndMod
	addq.w	#1,d0
	add.w	d0,d2
	subq.w	#1,d3
	bra.s	.loop
.done:
	move.w	d2,d0
	movem.l	(sp)+,d1-d3
	rts

D20:
	moveq	#20,d1
	bsr	RndMod
	addq.w	#1,d0
	rts

; StatMod : d0 = caracteristique -> d0 = modificateur (D&D 3.5)
StatMod:
	sub.w	#10,d0
	asr.w	#1,d0
	rts

;----------------------------------------------------------------------
; Carte : terrain et parametre, deux plans de MAPBYTES octets
;----------------------------------------------------------------------
MapCell:				; d0 = x, d1 = y -> d0 = terrain
	cmp.w	#0,d0
	blt.s	.wall
	cmp.w	#MAPW,d0
	bge.s	.wall
	cmp.w	#0,d1
	blt.s	.wall
	cmp.w	#MAPH,d1
	bge.s	.wall
	movem.l	d1-d2/a0,-(sp)
	lea	MapTerrain,a0
	move.w	d1,d2
	mulu.w	#MAPW,d2
	add.w	d0,d2
	moveq	#0,d0
	move.b	(a0,d2.w),d0
	movem.l	(sp)+,d1-d2/a0
	rts
.wall:
	moveq	#T_WALL,d0
	rts

MapGetParam:				; d0 = x, d1 = y -> d0 = parametre
	movem.l	d1-d2/a0,-(sp)
	lea	MapParam,a0
	move.w	d1,d2
	mulu.w	#MAPW,d2
	add.w	d0,d2
	moveq	#0,d0
	move.b	(a0,d2.w),d0
	movem.l	(sp)+,d1-d2/a0
	rts

MapSet:					; d0 = x, d1 = y, d2 = terrain
	movem.l	d0-d3/a0,-(sp)
	lea	MapTerrain,a0
	move.w	d1,d3
	mulu.w	#MAPW,d3
	add.w	d0,d3
	move.b	d2,(a0,d3.w)
	movem.l	(sp)+,d0-d3/a0
	rts

MapSetParam:				; d0 = x, d1 = y, d2 = parametre
	movem.l	d0-d3/a0,-(sp)
	lea	MapParam,a0
	move.w	d1,d3
	mulu.w	#MAPW,d3
	add.w	d0,d3
	move.b	d2,(a0,d3.w)
	movem.l	(sp)+,d0-d3/a0
	rts

IsSolid:				; d0 = terrain -> d2 = 1 si opaque
	move.w	d0,d2
	and.w	#$000f,d2
	cmp.w	#T_WALL,d2
	beq.s	.yes
	cmp.w	#T_DOOR,d2
	beq.s	.yes
	cmp.w	#T_LOCKED,d2
	beq.s	.yes
	cmp.w	#T_NICHE,d2
	beq.s	.yes
	cmp.w	#T_RUNE,d2
	beq.s	.yes
	cmp.w	#T_LEVER,d2
	beq.s	.yes
	cmp.w	#T_GATE,d2
	beq.s	.yes
	cmp.w	#T_SHOP,d2
	beq.s	.yes
	cmp.w	#T_STELE,d2
	beq.s	.yes
	moveq	#0,d2
	rts
.yes:
	moveq	#1,d2
	rts

; CellAt : d2 = profondeur, d3 = decalage lateral -> d0,d1 = case
CellAt:
	movem.l	d2-d5/a0,-(sp)
	lea	DirTable,a0
	move.w	Dir,d4
	lsl.w	#2,d4
	move.w	(a0,d4.w),d5
	muls.w	d2,d5
	move.w	PosX,d0
	add.w	d5,d0
	move.w	2(a0,d4.w),d5
	muls.w	d2,d5
	move.w	PosY,d1
	add.w	d5,d1
	move.w	Dir,d4
	addq.w	#1,d4
	and.w	#3,d4
	lsl.w	#2,d4
	move.w	(a0,d4.w),d5
	muls.w	d3,d5
	add.w	d5,d0
	move.w	2(a0,d4.w),d5
	muls.w	d3,d5
	add.w	d5,d1
	movem.l	(sp)+,d2-d5/a0
	rts

CellAhead:				; d2 = distance -> d0,d1
	movem.l	d3,-(sp)
	moveq	#0,d3
	bsr	CellAt
	movem.l	(sp)+,d3
	rts

;----------------------------------------------------------------------
; DrawScene : la vue, le combat, ou un ecran d'interface
;----------------------------------------------------------------------
DrawScene:
	movem.l	d0-d7/a0-a6,-(sp)
	tst.w	Phase
	bne.s	.inGame
	bsr	DrawCreate
	bra	.done
.inGame:
	move.w	UiMode,d0
	beq.s	.world
	cmp.w	#UI_SHEET,d0
	bne.s	.notSheet
	bsr	DrawSheet
	bra	.done
.notSheet:
	cmp.w	#UI_INV,d0
	bne.s	.notInv
	bsr	DrawInventory
	bra	.done
.notInv:
	cmp.w	#UI_RIDDLE,d0
	bne.s	.notRiddle
	bsr	DrawRiddle
	bra	.done
.notRiddle:
	cmp.w	#UI_MAP,d0
	bne.s	.notMap
	bsr	DrawMap
	bra	.done
.notMap:
	cmp.w	#UI_BOOK,d0
	bne.s	.notBook
	bsr	DrawBook
	bra	.done
.notBook:
	cmp.w	#UI_OPTS,d0
	bne.s	.notOpts
	bsr	DrawOptions
	bra	.done
.notOpts:
	cmp.w	#UI_SHOP,d0
	bne.s	.notShop
	bsr	DrawShop
	bra	.done
.notShop:
	cmp.w	#UI_LORE,d0
	bne.s	.notLore
	bsr	DrawLore
	bra	.done
.notLore:
	bsr	DrawSpellMenu
	bra	.done

.world:
	moveq	#ART_BG,d0
	moveq	#1,d1
	bsr	BlitPiece
	bsr	MusicPoll

	tst.w	InCombat
	beq.s	.dungeon
	move.w	MonArt,d0
	add.w	d0,d0
	add.w	AnimFrame,d0
	add.w	#ART_MONSTER,d0
	moveq	#0,d1
	bsr	BlitPiece
	bsr	DrawFoeBanner
	bra	.done

.dungeon:
	moveq	#0,d7			; distance du premier mur
	moveq	#1,d6
.scan:
	move.w	d6,d2
	bsr	CellAhead
	bsr	MapCell
	bsr	IsSolid
	tst.w	d2
	beq.s	.scanNext
	move.w	d6,d7
	bra.s	.scanDone
.scanNext:
	addq.w	#1,d6
	cmp.w	#5,d6
	blt.s	.scan
.scanDone:
	tst.w	d7
	beq	.noFront
	move.w	d7,d2
	bsr	CellAhead
	bsr	MapCell
	move.w	d0,d4			; terrain du mur
	and.w	#$000f,d4
	cmp.w	#T_DOOR,d4
	beq.s	.asDoor
	cmp.w	#T_LOCKED,d4
	beq.s	.asDoor
	cmp.w	#T_RUNE,d4
	beq.s	.asDoor
	cmp.w	#T_GATE,d4
	bne.s	.stone
	cmp.w	#4,d7			; herse : barreaux, le couloir se voit
	bge.s	.stone
	move.w	d7,d0
	add.w	#ART_FRONT-1,d0		; le mur du fond, puis les barreaux
	moveq	#0,d1
	bsr	BlitPiece
	move.w	d7,d0
	add.w	#ART_GATE-1,d0
	bra.s	.blitFront
.asDoor:
	cmp.w	#4,d7
	bge.s	.stone
	move.w	d7,d0
	add.w	#ART_DOOR-1,d0
	bra.s	.blitFront
.stone:
	move.w	d7,d0
	add.w	#ART_FRONT-1,d0
.blitFront:
	moveq	#0,d1
	bsr	BlitPiece
	cmp.w	#1,d7			; les details ne se voient que de pres
	bne.s	.noFront
	cmp.w	#T_NICHE,d4
	bne.s	.notNicheArt
	moveq	#ART_NICHE,d0
	moveq	#0,d1
	bsr	BlitPiece
	bra.s	.noFront
.notNicheArt:
	cmp.w	#T_SHOP,d4		; l'etal du marchand
	bne.s	.notShopArt
	moveq	#ART_SHOP,d0
	moveq	#0,d1
	bsr	BlitPiece
	bra.s	.noFront
.notShopArt:
	cmp.w	#T_STELE,d4		; la stele gravee
	bne.s	.notSteleArt
	moveq	#ART_STELE,d0
	moveq	#0,d1
	bsr	BlitPiece
	bra.s	.noFront
.notSteleArt:
	cmp.w	#T_LEVER,d4		; levier : leve ou abaisse
	bne.s	.noFront
	move.w	d7,d2
	bsr	CellAhead
	bsr	MapGetParam
	moveq	#ART_LEVER,d1
	btst	#7,d0
	beq.s	.leverArt
	addq.w	#1,d1
.leverArt:
	move.w	d1,d0
	moveq	#0,d1
	bsr	BlitPiece
.noFront:
	moveq	#1,d2			; la dalle juste devant, si on l'a vue
	bsr	CellAhead
	move.w	d0,d3
	move.w	d1,d4
	bsr	MapCell
	and.w	#$000f,d0
	cmp.w	#T_TRAP,d0
	bne.s	.noTrapArt
	move.w	d3,d0
	move.w	d4,d1
	bsr	MapGetParam
	btst	#TRAP_SEEN,d0
	beq.s	.noTrapArt
	moveq	#ART_TRAP,d0
	moveq	#0,d1
	bsr	BlitPiece
.noTrapArt:
	bsr	MusicPoll
	move.w	d7,d6
	subq.w	#1,d6
	tst.w	d7
	bne.s	.haveMax
	moveq	#3,d6
.haveMax:
	cmp.w	#3,d6
	ble.s	.clamped
	moveq	#3,d6
.clamped:
	tst.w	d6
	bmi	.done
.sideLoop:
	moveq	#-1,d5
.sideEach:
	move.w	d6,d2
	move.w	d5,d3
	bsr	CellAt
	bsr	MapCell
	bsr	IsSolid
	tst.w	d2
	beq.s	.open
	move.w	d6,d0
	tst.w	d5
	bmi.s	.leftWall
	add.w	#ART_RIGHT,d0
	bra.s	.blitSide
.leftWall:
	add.w	#ART_LEFT,d0
.blitSide:
	moveq	#0,d1
	bsr	BlitPiece
	bra	.sideNext
.open:
	move.w	d6,d2			; fond du passage
	addq.w	#1,d2
	move.w	d5,d3
	bsr	CellAt
	bsr	MapCell
	bsr	IsSolid
	tst.w	d2
	beq.s	.noBack
	move.w	d6,d0
	tst.w	d5
	bmi.s	.leftBack
	add.w	#ART_FRONTR,d0
	bra.s	.blitBack
.leftBack:
	add.w	#ART_FRONTL,d0
.blitBack:
	moveq	#0,d1
	bsr	BlitPiece
.noBack:
	cmp.w	#2,d6
	blt.s	.sideNext
	move.w	d6,d2			; mur exterieur du passage
	move.w	d5,d3
	add.w	d3,d3
	bsr	CellAt
	bsr	MapCell
	bsr	IsSolid
	tst.w	d2
	beq.s	.sideNext
	move.w	d6,d0
	subq.w	#2,d0
	tst.w	d5
	bmi.s	.leftOuter
	add.w	#ART_OUTERR,d0
	bra.s	.blitOuter
.leftOuter:
	add.w	#ART_OUTERL,d0
.blitOuter:
	moveq	#0,d1
	bsr	BlitPiece
.sideNext:
	tst.w	d5
	bpl.s	.sideDone
	moveq	#1,d5
	bra	.sideEach
.sideDone:
	bsr	MusicPoll
	dbf	d6,.sideLoop
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Redraw : tout l'ecran dans le tampon de dessin
;----------------------------------------------------------------------
Redraw:
	movem.l	d0-d7/a0-a6,-(sp)
	cmp.w	#PHASE_TITLE,Phase
	bne.s	.game
	bsr	DrawTitle
	bra	.drawn
.game:
	cmp.w	#PHASE_PLAY,Phase	; le releve suit le groupe
	bne.s	.noMark
	bsr	MarkSeen
.noMark:
	move.w	#PANEL_X,d0
	moveq	#8,d1
	move.w	#PANEL_W,d2
	move.w	#152,d3
	move.w	#C_PANEL,d4
	bsr	FillRect
	moveq	#0,d0
	move.w	#LOG_Y,d1
	move.w	#SCRW,d2
	move.w	#LOG_H,d3
	move.w	#C_PANEL,d4
	bsr	FillRect

	bsr	DrawScene
	bsr	MusicPoll

	moveq	#8,d0
	moveq	#8,d1
	move.w	#208,d2
	move.w	#152,d3
	bsr	DrawFrame
	move.w	#PANEL_X,d0
	moveq	#8,d1
	move.w	#88,d2
	move.w	#152,d3
	bsr	DrawFrame
	moveq	#8,d0
	move.w	#164,d1
	move.w	#304,d2
	move.w	#88,d3
	bsr	DrawFrame

	bsr	DrawParty
	bsr	MusicPoll
	bsr	DrawLog
	bsr	DrawStatus
.drawn:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; DrawParty : portrait, nom, points de vie et de magie
;----------------------------------------------------------------------
DrawParty:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	Heroes,a6
	moveq	#0,d7
.heroLoop:
	move.w	d7,d5
	mulu.w	#36,d5
	add.w	#14,d5			; ligne du bloc

	tst.w	hr_HpMax(a6)
	bne.s	.exists
	lea	TxtEmptySlot,a0
	move.w	#29,d0
	move.w	d5,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	bra	.heroNext
.exists:
	; --- le nom prend toute la largeur du panneau, le niveau se range
	; a sa droite : plus besoin d'abreger, et le portrait descend
	; sous cette ligne.
	move.l	a6,a0
	move.w	#29,d0
	move.w	d5,d1
	move.w	#C_TEXT,d2
	tst.w	hr_Hp(a6)
	bne.s	.alive
	move.w	#C_TEXTLOW,d2		; a terre : le nom s'eteint
.alive:
	cmp.w	SelHero,d7
	bne.s	.notSel
	move.w	#C_HILITE,d2		; heros choisi : en or
.notSel:
	bsr	DrawText

	lea	TmpStr,a1		; niveau, cale sur le bord droit
	move.w	hr_Level(a6),d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#37,d0
	cmp.w	#10,hr_Level(a6)
	blt.s	.lvlOne
	subq.w	#1,d0			; deux chiffres : une colonne de plus
.lvlOne:
	move.w	d5,d1
	move.w	#C_PARCHD,d2		; l'or est reserve au heros choisi
	bsr	DrawText

	move.w	hr_Class(a6),d0		; portrait, sous le nom
	add.w	#ART_PORTRAIT,d0
	moveq	#0,d1
	move.w	d5,d2
	addq.w	#8,d2
	mulu.w	#SCRBPL,d2
	add.w	#28,d2
	bsr	BlitPieceAt

	lea	TmpStr,a1		; points de vie, sans etiquette :
	move.w	hr_Hp(a6),d0		; la jauge dit deja de quoi il s'agit
	bsr	StrNum
	cmp.w	#100,hr_HpMax(a6)	; au-dela de cent, le total ne tient
	bge.s	.hpShort		; pas dans le panneau
	move.b	#'/',(a1)+
	move.w	hr_HpMax(a6),d0
	bsr	StrNum
.hpShort:
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#32,d0
	move.w	d5,d1
	add.w	#10,d1
	move.w	#C_HEALTH,d2
	move.w	hr_Hp(a6),d3
	add.w	d3,d3
	cmp.w	hr_HpMax(a6),d3
	bge.s	.hpOk
	move.w	#C_ALERT,d2		; sous la moitie : en rouge
.hpOk:
	move.w	d2,d6			; on garde la teinte pour la jauge
	bsr	DrawText

	movem.l	d5-d6,-(sp)		; d5 porte la ligne du bloc
	move.w	#256,d0
	move.w	d5,d1
	add.w	#19,d1
	moveq	#48,d2
	move.w	hr_Hp(a6),d3
	move.w	hr_HpMax(a6),d4
	move.w	d6,d5
	bsr	DrawGauge
	movem.l	(sp)+,d5-d6

	tst.w	hr_MpMax(a6)		; la magie, si la classe en a
	bne.s	.hasMp
	lea	TmpStr,a1		; sinon la classe d'armure, qui
	lea	TxtCa,a0		; comblait un blanc pour rien
	bsr	StrCopy
	bsr	HeroAc
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#32,d0
	move.w	d5,d1
	add.w	#23,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	bra	.heroNext
.hasMp:
	lea	TmpStr,a1
	move.w	hr_Mp(a6),d0
	bsr	StrNum
	move.b	#'/',(a1)+
	move.w	hr_MpMax(a6),d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#32,d0
	move.w	d5,d1
	add.w	#23,d1
	move.w	#C_MANA,d2
	bsr	DrawText

	movem.l	d5-d6,-(sp)
	move.w	#256,d0
	move.w	d5,d1
	add.w	#32,d1
	moveq	#48,d2
	move.w	hr_Mp(a6),d3
	move.w	hr_MpMax(a6),d4
	move.w	#C_MANA,d5
	bsr	DrawGauge
	movem.l	(sp)+,d5-d6
.heroNext:
	lea	hr_SIZEOF(a6),a6
	addq.w	#1,d7
	cmp.w	#NHEROES,d7
	blt	.heroLoop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

DrawLog:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	LogBuf,a6
	moveq	#0,d7
.lineLoop:
	move.l	a6,a0
	move.w	#2,d0
	move.w	d7,d1
	mulu.w	#12,d1
	add.w	#172,d1
	move.w	#C_TEXTDIM,d2
	cmp.w	#LOGLINES-1,d7
	bne.s	.old
	move.w	#C_TEXT,d2
.old:
	bsr	DrawText
	lea	LOGWIDTH+2(a6),a6
	addq.w	#1,d7
	cmp.w	#LOGLINES,d7
	blt.s	.lineLoop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; DrawFoeBanner : en haut de la vue, ce que le groupe a en face.
;
; Le joueur frappait a l'aveugle : il voyait la creature, jamais ses
; blessures, et rien ne disait combien elles etaient. Un bandeau porte
; son nom, la jauge de ses points de vie, et le compte de celles qui
; restent debout.
FOEBAR_X	= 20
FOEBAR_Y	= 20
FOEBAR_W	= 184

DrawFoeBanner:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#FOEBAR_X-2,d0
	move.w	#FOEBAR_Y-2,d1
	move.w	#FOEBAR_W+4,d2
	moveq	#20,d3
	move.w	#C_BLACK,d4
	bsr	FillRect

	lea	TmpStr,a1		; le nom, et combien elles sont
	move.l	MonPtr,a0
	bsr	StrCopy
	move.w	MonCount,d0
	cmp.w	#1,d0
	ble.s	.single
	lea	TxtTimes,a0
	bsr	StrCopy
	move.w	MonCount,d0
	bsr	StrNum
.single:
	tst.w	MonRange
	beq.s	.near
	lea	TxtFar,a0
	bsr	StrCopy
.near:
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#FOEBAR_X,d0
	move.w	#FOEBAR_Y,d1
	move.w	#C_ALERT,d2
	bsr	DrawText

	move.w	#FOEBAR_X,d0		; la jauge de ses points de vie
	move.w	#FOEBAR_Y+10,d1
	move.w	#FOEBAR_W,d2
	move.w	MonHp,d3
	move.w	MonHpMax,d4
	move.w	#C_BLOOD+4,d5
	bsr	DrawGauge
	movem.l	(sp)+,d0-d7/a0-a6
	rts

DrawStatus:
	movem.l	d0-d7/a0-a6,-(sp)
	tst.w	Phase
	bne.s	.playing
	lea	TxtCreateTitle,a0
	move.w	#2,d0
	move.w	#224,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	lea	TxtHelpCreate,a0
	bra	.help
.playing:
	lea	TmpStr,a1
	lea	TxtNiveau,a0
	bsr	StrCopy
	move.w	Level,d0
	addq.w	#1,d0
	bsr	StrNum
	lea	TxtOr,a0
	bsr	StrCopy
	move.w	Gold,d0
	bsr	StrNum
	lea	TxtKeys,a0
	bsr	StrCopy
	move.w	KeyCount,d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#2,d0
	move.w	#224,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	move.w	UiMode,d0
	beq	.helpView
	cmp.w	#UI_INV,d0
	bne.s	.helpSpell
	lea	TxtHelpInv,a0
	bra	.help
.helpSpell:
	cmp.w	#UI_SPELL,d0
	bne.s	.helpRiddle
	lea	TxtHelpSpell,a0
	bra	.help
.helpRiddle:
	cmp.w	#UI_RIDDLE,d0
	bne.s	.helpMap
	lea	TxtHelpRiddle,a0
	bra	.help
.helpMap:
	cmp.w	#UI_MAP,d0
	bne.s	.helpBook
	lea	TxtHelpMap,a0
	bra	.help
.helpBook:
	cmp.w	#UI_BOOK,d0
	bne.s	.helpOpts
	lea	TxtHelpBook,a0
	bra	.help
.helpOpts:
	cmp.w	#UI_OPTS,d0
	bne.s	.helpShop
	lea	TxtHelpOpts,a0
	bra	.help
.helpShop:
	cmp.w	#UI_SHOP,d0
	bne.s	.helpLore
	lea	TxtHelpShop,a0
	bra	.help
.helpLore:
	cmp.w	#UI_LORE,d0
	bne.s	.helpOther
	lea	TxtLoreHelp,a0
	bra	.help
.helpOther:
	lea	TxtHelpSheet,a0
	bra	.help
.helpView:
	tst.w	InCombat
	beq.s	.helpMove
	lea	TxtHelpFight,a0
	bra	.help
.helpMove:
	lea	TxtHelpMove,a0
.help:
	move.w	#2,d0
	move.w	#238,d1
	move.w	#C_TEXTLOW,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

BOOKROWS	= 8			; sorts visibles a la fois

;----------------------------------------------------------------------
; Grimoire : les seize sorts, ceux que le heros connait en clair, les
; autres en gris, et le detail complet de celui que vise le curseur.
;----------------------------------------------------------------------
DrawBook:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect

	lea	TmpStr,a1		; GRIMOIRE DE <nom>
	lea	TxtBookTitle,a0
	bsr	StrCopy
	move.w	SelHero,d0
	bsr	HeroPtr
	move.l	a6,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	moveq	#18,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	move.w	BookCursor,d0		; garder le curseur dans la page
	move.w	BookTop,d1
	cmp.w	d1,d0
	bge.s	.notAbove
	move.w	d0,BookTop
	bra.s	.pageOk
.notAbove:
	sub.w	d1,d0
	cmp.w	#BOOKROWS,d0
	blt.s	.pageOk
	move.w	BookCursor,d0
	sub.w	#BOOKROWS-1,d0
	move.w	d0,BookTop
.pageOk:
	moveq	#0,d7			; ligne affichee
.listLoop:
	move.w	BookTop,d6
	add.w	d7,d6			; numero du sort
	cmp.w	#NSPELLS,d6
	bge	.listDone
	lea	TmpStr,a1
	move.w	d6,d0
	addq.w	#1,d0
	bsr	StrNum
	move.b	#' ',(a1)+
	move.w	d6,d0
	bsr	SpellPtr
	move.l	a0,a2
	bsr	StrCopy
	clr.b	(a1)

	move.w	#C_TEXTLOW,d2		; sort inconnu : en gris
	move.w	hr_Spells(a6),d0
	btst	d6,d0
	beq.s	.dim
	move.w	#C_TEXT,d2
.dim:
	cmp.w	BookCursor,d6
	bne.s	.notHere
	move.w	#C_HILITE,d2		; celui que vise le curseur
.notHere:
	lea	TmpStr,a0
	moveq	#4,d0
	move.w	d7,d1
	mulu.w	#10,d1
	add.w	#32,d1
	bsr	DrawText
	cmp.w	BookCursor,d6
	bne.s	.noMark
	lea	TxtBookMark,a0
	moveq	#3,d0
	move.w	d7,d1
	mulu.w	#10,d1
	add.w	#32,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
.noMark:
	addq.w	#1,d7
	cmp.w	#BOOKROWS,d7
	blt	.listLoop
.listDone:
	move.w	#24,d0			; un filet sous la liste ; HLine veut
	move.w	#114,d1			; des pixels, pas des colonnes
	move.w	#176,d2
	move.w	#C_FRAME,d3
	bsr	HLine

	move.w	BookCursor,d0		; --- le detail du sort vise
	bsr	SpellPtr
	move.l	a0,a2
	lea	TmpStr,a1
	lea	TxtBookLevel,a0
	bsr	StrCopy
	move.w	sp_Level(a2),d0
	bsr	StrNum
	lea	TxtBookSchool,a0
	bsr	StrCopy
	move.w	sp_School(a2),d0
	lsl.w	#2,d0
	lea	SchoolNames-4,a0
	move.l	(a0,d0.w),a0
	bsr	StrCopy
	lea	TxtBookSlots,a0		; ce qu'il reste a ce niveau de sort
	bsr	StrCopy
	move.w	sp_Level(a2),d0
	add.w	d0,d0
	move.w	hr_Slots(a6,d0.w),d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#120,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText

	lea	TmpStr,a1		; effet et des
	move.w	sp_Kind(a2),d0
	lsl.w	#2,d0
	lea	KindNames,a0
	move.l	(a0,d0.w),a0
	bsr	StrCopy
	move.w	sp_Dice(a2),d0
	beq.s	.fixed
	bsr	StrNum
	lea	TxtBookPerLvl,a0
	bsr	StrCopy
	bra.s	.faces
.fixed:
	move.w	sp_Cap(a2),d0
	beq.s	.noDice
	bsr	StrNum
.faces:
	move.b	#'D',(a1)+
	move.w	sp_Faces(a2),d0
	bsr	StrNum
	move.w	sp_Plus(a2),d0
	beq.s	.noDice
	move.b	#'+',(a1)+
	bsr	StrNum
.noDice:
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#130,d1
	move.w	#C_TEXT,d2
	bsr	DrawText

	lea	TmpStr,a1		; sauvegarde et emplacements
	move.w	sp_Save(a2),d0
	beq.s	.noSave
	lea	TxtBookSave,a0
	bsr	StrCopy
	move.w	sp_Save(a2),d0
	lsl.w	#2,d0
	lea	SaveNames-4,a0
	move.l	(a0,d0.w),a0
	bsr	StrCopy
	tst.w	sp_Half(a2)
	beq.s	.noHalf
	lea	TxtBookHalf,a0
	bsr	StrCopy
.noHalf:
	bra.s	.slots
.noSave:
	lea	TxtBookNoSave,a0
	bsr	StrCopy
.slots:
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#140,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

BookKey:				; d0 = touche
	movem.l	d1-d7/a0-a6,-(sp)
	cmp.w	#KEY_UP,d0
	bne.s	.notUp
	move.w	BookCursor,d1
	subq.w	#1,d1
	bpl.s	.set
	moveq	#0,d1
	bra.s	.set
.notUp:
	cmp.w	#KEY_DOWN,d0
	bne.s	.done
	move.w	BookCursor,d1
	addq.w	#1,d1
	cmp.w	#NSPELLS,d1
	blt.s	.set
	move.w	#NSPELLS-1,d1
.set:
	move.w	d1,BookCursor
	move.w	#1,NeedRedraw
.done:
	movem.l	(sp)+,d1-d7/a0-a6
	rts

OPTROWS		= 5			; lignes de reglage

;----------------------------------------------------------------------
; Reglages, accessibles en cours de partie.
;----------------------------------------------------------------------
DrawOptions:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect
	lea	TxtOptTitle,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	moveq	#0,d7
.loop:
	lea	TmpStr,a1
	move.w	d7,d0			; le libelle
	lsl.w	#2,d0
	lea	OptNames,a0
	move.l	(a0,d0.w),a0
	bsr	StrCopy
	move.w	d7,d0			; puis la valeur
	bsr	OptValue
	move.l	d0,a0
	tst.l	a0
	beq.s	.noValue
	bsr	StrCopy
.noValue:
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#4,d0
	move.w	d7,d1
	mulu.w	#18,d1
	add.w	#44,d1
	move.w	#C_TEXT,d2
	cmp.w	OptCursor,d7
	bne.s	.notHere
	move.w	#C_HILITE,d2
.notHere:
	bsr	DrawText
	cmp.w	OptCursor,d7
	bne.s	.next
	lea	TxtBookMark,a0
	moveq	#3,d0
	move.w	d7,d1
	mulu.w	#18,d1
	add.w	#44,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
.next:
	addq.w	#1,d7
	cmp.w	#OPTROWS,d7
	blt	.loop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

OptValue:				; d0 = ligne -> d0 = texte, 0 si aucun
	movem.l	d1,-(sp)
	move.w	d0,d1
	moveq	#0,d0
	tst.w	d1
	bne.s	.notMusic
	move.l	#TxtOptOff,d0
	tst.w	OptMusic
	beq.s	.done
	move.l	#TxtOptOn,d0
	bra.s	.done
.notMusic:
	cmp.w	#1,d1
	bne.s	.notSfx
	move.l	#TxtOptOff,d0
	tst.w	OptSfx
	beq.s	.done
	move.l	#TxtOptOn,d0
	bra.s	.done
.notSfx:
	cmp.w	#2,d1
	bne.s	.done
	move.l	#TxtOptAzerty,d0
	tst.w	KbLayout
	beq.s	.done
	move.l	#TxtOptQwerty,d0
.done:
	movem.l	(sp)+,d1
	rts

OptToggle:				; agit sur la ligne visee
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	OptCursor,d0
	tst.w	d0
	bne.s	.notMusic
	eor.w	#1,OptMusic
	tst.w	OptMusic
	bne.s	.redraw
	lea	CUSTOM+AUD0LCH,a0	; on coupe le son tout de suite
	moveq	#3,d1
.silence:
	clr.w	AUDx_VOL(a0)
	lea	16(a0),a0
	dbf	d1,.silence
	bra.s	.redraw
.notMusic:
	cmp.w	#1,d0
	bne.s	.notSfx
	eor.w	#1,OptSfx
	bra.s	.redraw
.notSfx:
	cmp.w	#2,d0
	bne.s	.notKb
	eor.w	#1,KbLayout
	bra.s	.redraw
.notKb:
	cmp.w	#3,d0
	bne.s	.notSave
	bsr	SaveGame
	lea	TxtSaved,a0
	bsr	LogAdd
	bra.s	.redraw
.notSave:
	bsr	SaveGame		; retour a l'accueil
	clr.w	UiMode
	move.w	#PHASE_TITLE,Phase
	bsr	ClearScreens
	moveq	#0,d0			; et sa musique revient avec lui
	bsr	PlayMusic
.redraw:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

OptKey:					; d0 = touche
	movem.l	d1-d7/a0-a6,-(sp)
	cmp.w	#KEY_UP,d0
	bne.s	.notUp
	move.w	OptCursor,d1
	subq.w	#1,d1
	bpl.s	.set
	moveq	#0,d1
	bra.s	.set
.notUp:
	cmp.w	#KEY_DOWN,d0
	bne.s	.notDown
	move.w	OptCursor,d1
	addq.w	#1,d1
	cmp.w	#OPTROWS,d1
	blt.s	.set
	move.w	#OPTROWS-1,d1
	bra.s	.set
.notDown:
	cmp.w	#KEY_RETURN,d0
	beq.s	.act
	cmp.w	#KEY_LEFT,d0
	beq.s	.act
	cmp.w	#KEY_RIGHT,d0
	bne.s	.done
.act:
	bsr	OptToggle
	bra.s	.done
.set:
	move.w	d1,OptCursor
	move.w	#1,NeedRedraw
.done:
	movem.l	(sp)+,d1-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Ecran d'accueil
;----------------------------------------------------------------------
DrawTitle:
	movem.l	d0-d7/a0-a6,-(sp)
	moveq	#ART_TITLE,d0		; l'illustration, copie simple
	moveq	#1,d1
	moveq	#0,d2
	bsr	BlitPieceAt

	moveq	#0,d0
	move.w	#TITLEH,d1
	move.w	#SCRW,d2
	move.w	#SCRH-TITLEH,d3
	move.w	#C_PANEL,d4
	bsr	FillRect
	moveq	#8,d0
	move.w	#TITLEH+6,d1
	move.w	#304,d2
	move.w	#66,d3
	bsr	DrawFrame

	lea	TxtMenuNew,a0
	moveq	#5,d0
	move.w	#TITLEH+14,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	lea	TxtMenuLoad,a0
	moveq	#5,d0
	move.w	#TITLEH+28,d1
	move.w	#C_HILITE,d2
	tst.w	HasSave
	bne.s	.hasSave
	move.w	#C_TEXTLOW,d2		; rien a reprendre : en gris
.hasSave:
	bsr	DrawText

	lea	TxtMenuQuit,a0
	moveq	#5,d0
	move.w	#TITLEH+42,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText

	lea	TxtMenuHint,a0
	moveq	#5,d0
	move.w	#TITLEH+58,d1
	move.w	#C_TEXTLOW,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; PlayMusic : d0 = 0 pour l'accueil, 1 pour le donjon. Le replayer ne
; tient qu'un module a la fois : on l'arrete, on le reinitialise sur
; l'autre partition, et on rend le DMA audio que PT_Stop avait coupe.
PlayMusic:
	movem.l	d0-d1/a0-a1/a5,-(sp)
	cmp.w	CurMusic,d0
	beq.s	.done
	move.w	d0,CurMusic
	bsr	PT_Stop
	lea	PT_TitleModule,a0	; MUS_TITLE
	tst.w	d0
	beq.s	.init
	lea	PT_ModuleData,a0	; MUS_DUNGEON
	cmp.w	#MUS_DEEP,d0
	bne.s	.init
	lea	PT_DeepModule,a0	; MUS_DEEP : les derniers etages
.init:
	bsr	PT_Init
	lea	CUSTOM,a5
	move.w	#DMAF_SETCLR|DMAF_AUDIO,DMACON(a5)
.done:
	movem.l	(sp)+,d0-d1/a0-a1/a5
	rts

; LevelMusic : lance la partition de l'etage ou l'on se trouve.
LevelMusic:
	movem.l	d0,-(sp)
	move.w	#MUS_DUNGEON,d0
	cmp.w	#DEEP_LEVEL,Level
	blt.s	.play
	move.w	#MUS_DEEP,d0
.play:
	bsr	PlayMusic
	movem.l	(sp)+,d0
	rts

; ClearScreens : les deux tampons d'un coup. En quittant l'accueil,
; l'illustration restait visible dans la bordure que le decor ne
; repeint pas -- huit pixels tout autour de la vue.
ClearScreens:
	movem.l	d0-d4/a0,-(sp)
	move.l	DrawBuf,a0
	move.l	ShowBuf,DrawBuf
	bsr	.wipe
	move.l	a0,DrawBuf
	bsr	.wipe
	movem.l	(sp)+,d0-d4/a0
	rts
.wipe:
	moveq	#0,d0
	moveq	#0,d1
	move.w	#SCRW,d2
	move.w	#SCRH,d3
	move.w	#C_BLACK,d4
	bra	FillRect

TitleKey:
	movem.l	d1-d7/a0-a6,-(sp)
	cmp.w	#KEY_ESC,d0
	bne.s	.notEsc
	move.w	#1,Quit
	bra	.done
.notEsc:
	cmp.w	#KEY_1,d0
	bne.s	.notNew
	bsr	NewGame			; une nouvelle equipe
	bsr	ClearScreens
	bsr	LevelMusic		; on descend : la marche du donjon
	clr.w	Phase
	move.w	#1,ShowIntro		; le recit s'ouvre apres la creation
	bra.s	.redraw
.notNew:
	cmp.w	#KEY_1+1,d0
	bne.s	.done
	tst.w	HasSave
	beq.s	.done
	bsr	LoadGame
	tst.w	d0
	beq.s	.done
	bsr	ClearScreens
	bsr	LevelMusic		; la reprise retrouve sa partition
	move.w	#PHASE_PLAY,Phase
	lea	TxtResumed,a0
	bsr	LogAdd
.redraw:
	move.w	#1,NeedRedraw
.done:
	movem.l	(sp)+,d1-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Sauvegarde : un bloc unique ecrit par dos.library.
;
; Le jeu tourne sous Forbid ; dos.library a besoin du multitache, on
; rend donc la main le temps de l'acces au fichier, puis on la reprend.
;----------------------------------------------------------------------
PackSave:
	movem.l	d0/a0-a2,-(sp)
	lea	SaveBuf,a1
	move.l	#SAVEMAGIC,(a1)+
	lea	SaveList,a2
.loop:
	move.l	(a2)+,a0
	move.l	(a2)+,d0
	cmp.l	#0,a0
	beq.s	.done
	subq.l	#1,d0
.copy:
	move.b	(a0)+,(a1)+
	dbf	d0,.copy
	bra.s	.loop
.done:
	movem.l	(sp)+,d0/a0-a2
	rts

UnpackSave:				; -> d0 = 1 si la sauvegarde est bonne
	movem.l	d1/a0-a2,-(sp)
	lea	SaveBuf,a1
	cmp.l	#SAVEMAGIC,(a1)+
	bne.s	.bad
	lea	SaveList,a2
.loop:
	move.l	(a2)+,a0
	move.l	(a2)+,d1
	cmp.l	#0,a0
	beq.s	.good
	subq.l	#1,d1
.copy:
	move.b	(a1)+,(a0)+
	dbf	d1,.copy
	bra.s	.loop
.bad:
	moveq	#0,d0
	bra.s	.done
.good:
	moveq	#1,d0
.done:
	movem.l	(sp)+,d1/a0-a2
	rts

SaveGame:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	DosBase,d0
	beq	.done
	bsr	PackSave
	move.l	4.w,a6
	jsr	_LVOPermit(a6)
	move.l	DosBase,a6
	move.l	#SaveName,d1
	move.l	#MODE_NEWFILE,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.s	.reforbid
	move.l	d4,d1
	move.l	#SaveBuf,d2
	move.l	#SAVESIZE,d3
	jsr	_LVOWrite(a6)
	move.l	d4,d1
	jsr	_LVOClose(a6)
	move.w	#1,HasSave
.reforbid:
	move.l	4.w,a6
	jsr	_LVOForbid(a6)
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

LoadGame:				; -> d0 = 1 si la partie est reprise
	movem.l	d1-d7/a0-a6,-(sp)
	moveq	#0,d5
	move.l	DosBase,d0
	beq.s	.done
	move.l	4.w,a6
	jsr	_LVOPermit(a6)
	move.l	DosBase,a6
	move.l	#SaveName,d1
	move.l	#MODE_OLDFILE,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.s	.reforbid
	move.l	d4,d1
	move.l	#SaveBuf,d2
	move.l	#SAVESIZE,d3
	jsr	_LVORead(a6)
	cmp.l	#SAVESIZE,d0
	bne.s	.close
	moveq	#1,d5
.close:
	move.l	d4,d1
	jsr	_LVOClose(a6)
.reforbid:
	move.l	4.w,a6
	jsr	_LVOForbid(a6)
	tst.w	d5
	beq.s	.done
	bsr	UnpackSave
	move.w	d0,d5
.done:
	move.w	d5,d0
	movem.l	(sp)+,d1-d7/a0-a6
	rts

CheckSave:				; y a-t-il une partie a reprendre ?
	movem.l	d0-d4/a0-a6,-(sp)
	clr.w	HasSave
	move.l	DosBase,d0
	beq.s	.done
	move.l	DosBase,a6
	move.l	#SaveName,d1
	move.l	#MODE_OLDFILE,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.s	.done
	move.l	d4,d1
	move.l	#SaveBuf,d2
	moveq	#4,d3
	jsr	_LVORead(a6)
	cmp.l	#4,d0
	bne.s	.close
	cmp.l	#SAVEMAGIC,SaveBuf
	bne.s	.close
	move.w	#1,HasSave
.close:
	move.l	d4,d1
	jsr	_LVOClose(a6)
.done:
	movem.l	(sp)+,d0-d4/a0-a6
	rts

;----------------------------------------------------------------------
; Journal
;----------------------------------------------------------------------
LogAdd:
	movem.l	d0-d3/a0-a2,-(sp)
	lea	LogBuf,a1
	lea	LogBuf+LOGWIDTH+2,a2
	moveq	#LOGLINES-2,d3
.shift:
	move.w	#LOGWIDTH+1,d2
.copy:
	move.b	(a2)+,(a1)+
	dbf	d2,.copy
	dbf	d3,.shift
	move.w	#LOGWIDTH-1,d2
.write:
	move.b	(a0),(a1)+
	beq.s	.done
	addq.l	#1,a0
	dbf	d2,.write
	clr.b	(a1)
.done:
	movem.l	(sp)+,d0-d3/a0-a2
	rts

;----------------------------------------------------------------------
; Acces aux tables
;----------------------------------------------------------------------
HeroPtr:				; d0 = numero -> a6
	movem.l	d0,-(sp)
	mulu.w	#hr_SIZEOF,d0
	lea	Heroes,a6
	add.l	d0,a6
	movem.l	(sp)+,d0
	rts

ItemPtr:				; d0 = objet -> a0
	movem.l	d1,-(sp)
	move.w	d0,d1
	subq.w	#1,d1
	mulu.w	#it_SIZEOF,d1
	lea	ItemTable,a0
	add.l	d1,a0
	movem.l	(sp)+,d1
	rts

SpellPtr:				; d0 = sort (0..5) -> a0
	movem.l	d1,-(sp)
	move.w	d0,d1
	mulu.w	#sp_SIZEOF,d1
	lea	SpellTable,a0
	add.l	d1,a0
	movem.l	(sp)+,d1
	rts

; HeroAc : a6 = heros -> d0 = classe d'armure
HeroAc:
	movem.l	d1-d2/a0,-(sp)
	move.w	hr_Dex(a6),d0
	bsr	StatMod
	add.w	#10,d0
	move.w	d0,d2
	move.w	hr_Armor(a6),d0
	beq.s	.noArmor
	bsr	ItemPtr
	add.w	it_Dice(a0),d2
	add.w	it_Bonus(a0),d2
.noArmor:
	move.w	hr_Shield(a6),d0
	beq.s	.noShield
	bsr	ItemPtr
	add.w	it_Dice(a0),d2
.noShield:
	add.w	hr_AcTemp(a6),d2
	move.w	d2,d0
	movem.l	(sp)+,d1-d2/a0
	rts

; HeroBab : a6 = heros -> d0 = bonus de base a l'attaque
HeroBab:
	movem.l	d1-d2/a0,-(sp)
	bsr	ClassPtr
	move.w	hr_Level(a6),d0
	move.w	cl_Bab(a0),d2
	beq.s	.done			; progression complete : un par niveau
	cmp.w	#1,d2
	bne.s	.half
	move.w	d0,d1			; trois quarts
	mulu.w	#3,d1
	lsr.w	#2,d1
	move.w	d1,d0
	bra.s	.done
.half:
	lsr.w	#1,d0			; demie
.done:
	movem.l	(sp)+,d1-d2/a0
	rts

ClassPtr:				; a6 = heros -> a0 = sa classe
	movem.l	d0,-(sp)
	move.w	hr_Class(a6),d0
	mulu.w	#cl_SIZEOF,d0
	lea	ClassTable,a0
	add.l	d0,a0
	movem.l	(sp)+,d0
	rts

; HeroSave : d0 = 0 Vigueur, 1 Reflexes, 2 Volonte -> d0 = bonus total
; Base du SRD : 2 + niveau/2 si la sauvegarde est forte, sinon niveau/3,
; plus le modificateur de Constitution, Dexterite ou Sagesse.
HeroSave:
	movem.l	d1-d4/a0-a1,-(sp)
	move.w	d0,d3
	bsr	ClassPtr
	move.w	d3,d1
	add.w	d1,d1
	lea	cl_Fort(a0),a1
	move.w	(a1,d1.w),d2
	move.w	hr_Level(a6),d0
	tst.w	d2
	beq.s	.poor
	lsr.w	#1,d0
	addq.w	#2,d0
	bra.s	.abil
.poor:
	and.l	#$0000ffff,d0
	divu.w	#3,d0
	and.l	#$0000ffff,d0
.abil:
	move.w	d0,d4
	tst.w	d3
	bne.s	.notFort
	move.w	hr_Con(a6),d0
	bra.s	.mod
.notFort:
	cmp.w	#1,d3
	bne.s	.will
	move.w	hr_Dex(a6),d0
	bra.s	.mod
.will:
	move.w	hr_Wis(a6),d0
.mod:
	bsr	StatMod
	add.w	d4,d0
	movem.l	(sp)+,d1-d4/a0-a1
	rts

; CastMod : a6 = heros -> d0 = modificateur de lanceur, d1 = type (0 aucun)
CastMod:
	movem.l	d2/a0,-(sp)
	bsr	ClassPtr
	move.w	cl_Cast(a0),d1
	beq.s	.none
	cmp.w	#1,d1
	bne.s	.divine
	move.w	hr_Int(a6),d0
	bra.s	.mod
.divine:
	move.w	hr_Wis(a6),d0
.mod:
	bsr	StatMod
	bra.s	.done
.none:
	moveq	#0,d0
.done:
	movem.l	(sp)+,d2/a0
	rts

; FillSlots : emplacements de sorts du niveau courant (a6 = heros)
FillSlots:
	movem.l	d0-d7/a0-a1,-(sp)
	bsr	CastMod
	move.w	d0,d4			; modificateur de lanceur
	move.w	d1,d3			; type de lanceur
	moveq	#0,d5
	tst.w	d3
	beq	.noMagic
	move.w	hr_Level(a6),d0
	cmp.w	#8,d0
	ble.s	.lvlOk
	moveq	#8,d0
.lvlOk:
	subq.w	#1,d0
	lsl.w	#3,d0			; quatre mots par niveau
	lea	SlotTable,a1
	add.w	d0,a1
	moveq	#0,d6
.loop:
	move.w	(a1)+,d2
	beq.s	.store
	tst.w	d6
	beq.s	.store			; pas de bonus pour les sorts mineurs
	cmp.w	d6,d4
	blt.s	.store
	addq.w	#1,d2			; emplacement bonus de caracteristique
.store:
	move.w	d6,d0
	add.w	d0,d0
	move.w	d2,hr_Slots(a6,d0.w)
	add.w	d2,d5
	addq.w	#1,d6
	cmp.w	#MAXSPLEVEL,d6
	blt.s	.loop
	bra.s	.total
.noMagic:
	moveq	#0,d6
.clear:
	move.w	d6,d0
	add.w	d0,d0
	clr.w	hr_Slots(a6,d0.w)
	addq.w	#1,d6
	cmp.w	#MAXSPLEVEL,d6
	blt.s	.clear
.total:
	move.w	d5,hr_Mp(a6)
	move.w	d5,hr_MpMax(a6)
	movem.l	(sp)+,d0-d7/a0-a1
	rts

;----------------------------------------------------------------------
; Fiche d'aventure du heros selectionne
;----------------------------------------------------------------------
DrawSheet:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect
	move.w	SelHero,d0
	bsr	HeroPtr
	tst.w	hr_HpMax(a6)
	bne.s	.ok
	lea	TxtNoHero,a0
	moveq	#3,d0
	moveq	#60,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	bra	.done
.ok:
	lea	TmpStr,a1		; nom et classe
	move.l	a6,a0
	bsr	StrCopy
	move.b	#' ',(a1)+
	move.w	hr_Class(a6),d0
	mulu.w	#cl_SIZEOF,d0
	lea	ClassTable,a0
	add.l	d0,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	lea	TmpStr,a1		; niveau et experience
	lea	TxtNiv,a0
	bsr	StrCopy
	move.w	hr_Level(a6),d0
	bsr	StrNum
	lea	TxtSpPx,a0
	bsr	StrCopy
	move.w	hr_Xp(a6),d0
	bsr	StrNum
	lea	TxtSpPv,a0
	bsr	StrCopy
	move.w	hr_Hp(a6),d0
	bsr	StrNum
	move.b	#'/',(a1)+
	move.w	hr_HpMax(a6),d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	moveq	#32,d1
	move.w	#C_TEXT,d2
	bsr	DrawText

	moveq	#0,d7			; les six caracteristiques
.statLoop:
	lea	TmpStr,a1
	move.w	d7,d0
	lsl.w	#2,d0
	lea	StatNames,a0
	move.l	(a0,d0.w),a0
	bsr	StrCopy
	move.w	d7,d0
	add.w	d0,d0
	lea	StatOffsets,a0
	move.w	(a0,d0.w),d1
	move.w	0(a6,d1.w),d0
	move.w	d0,d3
	bsr	StrNum
	move.b	#' ',(a1)+
	move.w	d3,d0
	bsr	StatMod
	bsr	StrSigned
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	d7,d1
	moveq	#3,d0
	btst	#0,d1
	beq.s	.leftCol
	moveq	#14,d0			; deuxieme colonne
.leftCol:
	move.w	d7,d1
	lsr.w	#1,d1
	mulu.w	#11,d1
	add.w	#48,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	addq.w	#1,d7
	cmp.w	#6,d7
	blt	.statLoop

	lea	TmpStr,a1		; defense et attaque
	lea	TxtCa,a0
	bsr	StrCopy
	bsr	HeroAc
	bsr	StrNum
	lea	TxtAtt,a0
	bsr	StrCopy
	bsr	HeroBab
	move.w	d0,d3
	move.w	hr_Str(a6),d0
	bsr	StatMod
	add.w	d3,d0
	bsr	StrSigned
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#88,d1
	move.w	#C_HEALTH,d2
	bsr	DrawText

	lea	TmpStr,a1		; arme portee
	lea	TxtWeapon,a0
	bsr	StrCopy
	move.w	hr_Weapon(a6),d0
	beq.s	.bare
	bsr	ItemPtr
	bsr	StrCopy
	bra.s	.weaponDone
.bare:
	lea	TxtBare,a0
	bsr	StrCopy
.weaponDone:
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#100,d1
	move.w	#C_TEXT,d2
	bsr	DrawText

	lea	TmpStr,a1		; armure
	lea	TxtArmorLbl,a0
	bsr	StrCopy
	move.w	hr_Armor(a6),d0
	beq.s	.noArm
	bsr	ItemPtr
	bsr	StrCopy
	bra.s	.armDone
.noArm:
	lea	TxtNone,a0
	bsr	StrCopy
.armDone:
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#110,d1
	move.w	#C_TEXT,d2
	bsr	DrawText

	lea	TmpStr,a1		; jets de sauvegarde
	lea	TxtSavesLbl,a0
	bsr	StrCopy
	moveq	#0,d7
.saveLoop:
	move.w	d7,d0
	bsr	HeroSave
	bsr	StrSigned
	move.b	#' ',(a1)+
	addq.w	#1,d7
	cmp.w	#3,d7
	blt.s	.saveLoop
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#120,d1
	move.w	#C_HEALTH,d2
	bsr	DrawText

	lea	TmpStr,a1		; sorts connus
	lea	TxtSpells,a0
	bsr	StrCopy
	moveq	#0,d7
	moveq	#0,d6			; meme numerotation que le menu de sorts
.spellLoop:
	move.w	hr_Spells(a6),d0
	btst	d7,d0
	beq.s	.spellNext
	addq.w	#1,d6
	cmp.w	#SPELLMENU,d6
	bgt.s	.spellNext
	move.w	d6,d0
	cmp.w	#10,d0			; la dixieme, c'est la touche 0
	blt.s	.spNum
	moveq	#0,d0
.spNum:
	bsr	StrNum
	move.b	#' ',(a1)+
.spellNext:
	addq.w	#1,d7
	cmp.w	#NSPELLS,d7
	blt.s	.spellLoop
	tst.w	d6
	bne.s	.spellsDone
	lea	TxtNone,a0
	bsr	StrCopy
.spellsDone:
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#130,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Sac a dos
;----------------------------------------------------------------------
DrawInventory:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect
	lea	TxtBag,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	moveq	#0,d7			; huit lignes visibles
.itemLoop:
	move.w	InvTop,d6
	add.w	d7,d6
	cmp.w	#INVSIZE,d6
	bge	.listDone
	lea	Inventory,a0
	moveq	#0,d0
	move.b	(a0,d6.w),d0
	beq	.itemNext
	move.w	d0,d5			; numero d'objet

	lea	TmpStr,a1
	cmp.w	InvCursor,d6
	bne.s	.noCursor
	move.b	#'>',(a1)+
	move.b	#' ',(a1)+
	bra.s	.name
.noCursor:
	move.b	#' ',(a1)+
	move.b	#' ',(a1)+
.name:
	move.w	d5,d0
	bsr	ItemPtr
	move.l	a0,a2
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#5,d0
	move.w	d7,d1
	mulu.w	#11,d1
	add.w	#34,d1
	move.w	#C_TEXT,d2
	cmp.w	InvCursor,d6
	bne.s	.dim
	move.w	#C_TEXT,d2
.dim:
	bsr	DrawText

	move.w	it_Type(a2),d0		; une icone par type d'objet. Il n'y
	cmp.w	#NICONS,d0		; en avait que cinq pour sept types,
	blt.s	.iconOk			; et le jeu ramenait le reste sur la
	moveq	#NICONS-1,d0		; derniere : une potion montrait un
.iconOk:				; parchemin, un parchemin une cle
	add.w	#ART_ICON,d0
	moveq	#0,d1
	move.w	d7,d2
	mulu.w	#11,d2
	add.w	#32,d2
	mulu.w	#SCRBPL,d2
	addq.w	#2,d2			; colle a gauche, sur un mot
	bsr	BlitPieceAt
.itemNext:
	addq.w	#1,d7
	cmp.w	#8,d7
	blt	.itemLoop
.listDone:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Choix d'un sort, pendant un combat
;----------------------------------------------------------------------
DrawSpellMenu:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect
	lea	TxtChooseSpell,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	bsr	BuildSpellMenu
	move.w	SelHero,d0
	bsr	HeroPtr
	tst.w	SpellCount
	bne.s	.list
	lea	TxtNoSpellKnown,a0	; ce heros n'a rien appris
	moveq	#3,d0
	moveq	#48,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	bra	.done
.list:
	lea	SpellList,a3
	moveq	#0,d7
.loop:
	move.w	(a3,d7.w*2),d4		; numero reel du sort
	lea	TmpStr,a1		; "n-NOM DU SORT" : les noms longs
	move.w	d7,d0			; iraient hors du cadre avec des
	addq.w	#1,d0			; espaces autour du tiret
	cmp.w	#10,d0			; la dixieme entree, c'est la touche 0
	blt.s	.num
	moveq	#0,d0
.num:
	bsr	StrNum
	lea	TxtHyphen,a0
	bsr	StrCopy
	move.w	d4,d0
	bsr	SpellPtr
	move.l	a0,a2
	bsr	StrCopy
	clr.b	(a1)
	move.w	d7,d1
	mulu.w	#11,d1
	add.w	#40,d1
	move.w	d1,d5			; ligne retenue pour le niveau
	moveq	#13,d2
	move.w	sp_Level(a2),d3		; reste-t-il un emplacement ?
	add.w	d3,d3
	tst.w	hr_Slots(a6,d3.w)
	bne.s	.draw
	moveq	#4,d2			; connu mais plus d'emplacement
.draw:
	lea	TmpStr,a0
	moveq	#3,d0
	bsr	DrawText
	lea	TmpStr,a1		; le niveau du sort, colle a droite
	lea	TxtNivShort,a0
	bsr	StrCopy
	move.w	sp_Level(a2),d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#24,d0
	move.w	d5,d1
	bsr	DrawText
	addq.w	#1,d7
	cmp.w	SpellCount,d7
	blt	.loop
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; BuildSpellMenu : les sorts connus du heros choisi, dans l'ordre.
; Le menu et le clavier lisent la meme liste : la touche N lance
; toujours le sort affiche en N, meme apres un parchemin appris.
BuildSpellMenu:
	movem.l	d0-d3/a0-a1/a6,-(sp)
	move.w	SelHero,d0
	bsr	HeroPtr
	lea	SpellList,a1
	moveq	#0,d1
	moveq	#0,d2
.loop:
	move.w	hr_Spells(a6),d3
	btst	d1,d3
	beq.s	.next
	move.w	d1,(a1)+
	addq.w	#1,d2
	cmp.w	#SPELLMENU,d2
	bge.s	.full
.next:
	addq.w	#1,d1
	cmp.w	#NSPELLS,d1
	blt.s	.loop
.full:
	move.w	d2,SpellCount
	movem.l	(sp)+,d0-d3/a0-a1/a6
	rts

;----------------------------------------------------------------------
; Creation du groupe : classe, jets 4d6 dont on garde les trois
; meilleurs, puis le nom
;----------------------------------------------------------------------
Roll4d6:				; -> d0 = somme des trois meilleurs de
	movem.l	d1-d5,-(sp)
	moveq	#0,d4			; total
	moveq	#7,d5			; plus petit de
	moveq	#3,d3
.loop:
	moveq	#1,d0
	moveq	#6,d1
	bsr	RollDice
	add.w	d0,d4
	cmp.w	d5,d0
	bge.s	.notMin
	move.w	d0,d5
.notMin:
	dbf	d3,.loop
	sub.w	d5,d4
	move.w	d4,d0
	movem.l	(sp)+,d1-d5
	rts

RollHero:
	movem.l	d0-d5/a0-a2,-(sp)
	lea	CreStr,a2		; six caracteristiques
	moveq	#5,d5
.stats:
	bsr	Roll4d6
	move.w	d0,(a2)+
	dbf	d5,.stats

	move.w	CreClass,d0
	mulu.w	#cl_SIZEOF,d0
	lea	ClassTable,a0
	add.l	d0,a0
	move.w	cl_Hd(a0),d2		; au niveau 1, le de de vie est maximal
	move.w	CreCon,d0
	bsr	StatMod
	add.w	d0,d2
	cmp.w	#1,d2
	bge.s	.hpOk
	moveq	#1,d2
.hpOk:
	move.w	d2,CreHp
	clr.w	CreMp			; les emplacements sont calcules apres
	movem.l	(sp)+,d0-d5/a0-a2
	rts

PickName:
	movem.l	d0-d2/a0-a1,-(sp)
	lea	CreName,a1
	moveq	#NAMELEN,d2
.clear:
	clr.b	(a1)+
	dbf	d2,.clear
	move.w	CreNameIdx,d0
	mulu.w	#NAMELEN,d0
	lea	NameList,a0
	add.l	d0,a0
	lea	CreName,a1
	moveq	#0,d2
.copy:
	move.b	(a0)+,(a1)+
	beq.s	.done
	addq.w	#1,d2
	bra.s	.copy
.done:
	move.w	d2,CreNameLen
	movem.l	(sp)+,d0-d2/a0-a1
	rts

CommitHero:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	CreIndex,d0
	bsr	HeroPtr
	tst.w	CreNameLen
	bne.s	.haveName
	bsr	PickName
.haveName:
	lea	CreName,a0
	move.l	a6,a1
	moveq	#NAMELEN-1,d1
.copyName:
	move.b	(a0)+,(a1)+
	dbf	d1,.copyName
	clr.b	(a1)

	move.w	CreClass,hr_Class(a6)
	move.w	#1,hr_Level(a6)
	clr.w	hr_Xp(a6)
	move.w	CreHp,hr_Hp(a6)
	move.w	CreHp,hr_HpMax(a6)
	clr.w	hr_Mp(a6)
	clr.w	hr_MpMax(a6)
	lea	CreStr,a0
	move.w	(a0)+,hr_Str(a6)
	move.w	(a0)+,hr_Dex(a6)
	move.w	(a0)+,hr_Con(a6)
	move.w	(a0)+,hr_Int(a6)
	move.w	(a0)+,hr_Wis(a6)
	move.w	(a0)+,hr_Cha(a6)
	clr.w	hr_Spells(a6)
	clr.w	hr_AcTemp(a6)

	move.w	CreClass,d0		; equipement de depart
	mulu.w	#8,d0
	lea	StartGear,a0
	add.l	d0,a0
	move.w	(a0)+,hr_Weapon(a6)
	move.w	(a0)+,hr_Armor(a6)
	move.w	(a0)+,hr_Shield(a6)
	move.w	(a0),hr_Spells(a6)
	bsr	FillSlots

	addq.w	#1,CreIndex
	clr.w	CreStep
	clr.w	CreCursor
	clr.w	CreNameLen
	move.w	CreIndex,d0
	cmp.w	#NHEROES,d0
	blt.s	.done
	bsr	StartAdventure
	bsr	SaveGame		; l'equipe est prete : on la garde
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

StartAdventure:
	move.w	#PHASE_PLAY,Phase
	clr.w	SelHero
	bsr	LoadLevel
	moveq	#17,d0			; deux potions pour la route
	bsr	AddItem
	moveq	#17,d0
	bsr	AddItem
	lea	TxtIntro,a0
	bsr	LogAdd
	rts

CreateKey:
	movem.l	d1-d7/a0-a6,-(sp)
	cmp.w	#KEY_ESC,d0
	bne.s	.notEsc
	move.w	#1,Quit
	bra	.done
.notEsc:
	move.w	CreStep,d7
	bne	.notClass
	cmp.w	#KEY_UP,d0		; le curseur parcourt les classes
	bne.s	.notClsUp
	move.w	CreCursor,d2
	subq.w	#1,d2
	bpl.s	.setCursor
	moveq	#0,d2
	bra.s	.setCursor
.notClsUp:
	cmp.w	#KEY_DOWN,d0
	bne.s	.notClsDown
	move.w	CreCursor,d2
	addq.w	#1,d2
	cmp.w	#NCLASSES,d2
	blt.s	.setCursor
	move.w	#NCLASSES-1,d2
.setCursor:
	move.w	d2,CreCursor
	bra	.redraw
.notClsDown:
	cmp.w	#KEY_RETURN,d0		; ENTREE prend celle qui est visee
	bne.s	.classDigit
	move.w	CreCursor,d2
	bra.s	.takeClass
.classDigit:
	move.w	d0,d2
	sub.w	#KEY_1,d2
	bmi	.done
	cmp.w	#NCLASSES,d2
	bge	.done
	move.w	d2,CreCursor
.takeClass:
	move.w	d2,CreClass
	bsr	RollHero
	move.w	#1,CreStep
	bra	.redraw
.notClass:
	cmp.w	#1,d7
	bne	.nameStep
	cmp.w	#KEY_R,d0
	bne.s	.notReroll
	bsr	RollHero
	bra	.redraw
.notReroll:
	cmp.w	#KEY_RETURN,d0
	bne	.done
	move.w	CreIndex,d2
	move.w	d2,CreNameIdx
	bsr	PickName
	move.w	#2,CreStep
	bra	.redraw
.nameStep:
	cmp.w	#KEY_RETURN,d0
	beq	.commit
	cmp.w	#KEY_TAB,d0
	bne.s	.notTab
	move.w	KbLayout,d2
	eor.w	#1,d2
	move.w	d2,KbLayout
	bra	.redraw
.notTab:
	cmp.w	#KEY_BACKSP,d0
	bne.s	.notBack
	move.w	CreNameLen,d2
	beq	.done
	subq.w	#1,d2
	move.w	d2,CreNameLen
	lea	CreName,a0
	clr.b	(a0,d2.w)
	bra	.redraw
.notBack:
	cmp.w	#KEY_LEFT,d0
	bne.s	.notPrev
	move.w	CreNameIdx,d2
	subq.w	#1,d2
	bpl.s	.setName
	move.w	#NNAMES-1,d2
	bra.s	.setName
.notPrev:
	cmp.w	#KEY_RIGHT,d0
	bne.s	.letter
	move.w	CreNameIdx,d2
	addq.w	#1,d2
	cmp.w	#NNAMES,d2
	blt.s	.setName
	moveq	#0,d2
.setName:
	move.w	d2,CreNameIdx
	bsr	PickName
	bra	.redraw
.letter:
	cmp.w	#$40,d0
	bge	.done
	move.w	CreNameLen,d2
	cmp.w	#NAMELEN-2,d2
	bge	.done
	lea	KeyAzerty,a0
	tst.w	KbLayout
	beq.s	.haveMap
	lea	KeyQwerty,a0
.haveMap:
	move.b	(a0,d0.w),d1
	beq	.done
	lea	CreName,a0
	move.b	d1,(a0,d2.w)
	addq.w	#1,d2
	move.w	d2,CreNameLen
	clr.b	(a0,d2.w)
	bra.s	.redraw
.commit:
	bsr	CommitHero
.redraw:
	move.w	#1,NeedRedraw
.done:
	movem.l	(sp)+,d1-d7/a0-a6
	rts

DrawCreate:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0			; strictement la zone que le fond repeint
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect

	lea	TmpStr,a1
	lea	TxtHero,a0
	bsr	StrCopy
	move.w	CreIndex,d0
	addq.w	#1,d0
	bsr	StrNum
	lea	TxtOn4,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	moveq	#18,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	move.w	CreStep,d7
	bne	.chosen

	lea	ClassTable,a6		; la liste des classes
	moveq	#0,d6
.classLoop:
	lea	TmpStr,a1
	move.w	d6,d0
	addq.w	#1,d0
	bsr	StrNum
	lea	TxtDash,a0
	bsr	StrCopy
	move.l	a6,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	d6,d1
	mulu.w	#11,d1
	add.w	#34,d1
	move.w	#C_TEXTDIM,d2
	cmp.w	CreCursor,d6		; la classe visee ressort
	bne.s	.dimClass
	move.w	#C_TEXT,d2
.dimClass:
	bsr	DrawText
	lea	cl_SIZEOF(a6),a6
	addq.w	#1,d6
	cmp.w	#NCLASSES,d6
	blt	.classLoop

	move.w	CreCursor,d0		; sa description, en bas du cadre
	lsl.w	#2,d0
	lea	ClassDesc,a5
	move.l	(a5,d0.w),a0
	moveq	#3,d0
	move.w	#126,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	lea	TxtPickClass,a0
	moveq	#3,d0
	move.w	#138,d1
	move.w	#C_HEALTH,d2
	bsr	DrawText
	bra	.done

.chosen:
	move.w	CreClass,d0		; classe retenue
	mulu.w	#cl_SIZEOF,d0
	lea	ClassTable,a0
	add.l	d0,a0
	moveq	#3,d0
	moveq	#38,d1
	move.w	#C_TEXT,d2
	bsr	DrawText

	lea	CreStr,a6		; les six jets
	moveq	#0,d6
.statLoop:
	lea	TmpStr,a1
	move.w	d6,d0
	lsl.w	#2,d0
	lea	StatNames,a0
	move.l	(a0,d0.w),a0
	bsr	StrCopy
	move.w	d6,d0
	add.w	d0,d0
	move.w	0(a6,d0.w),d0
	move.w	d0,d3
	bsr	StrNum
	move.b	#' ',(a1)+
	move.w	d3,d0
	bsr	StatMod
	bsr	StrSigned
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	btst	#0,d6
	beq.s	.leftCol
	moveq	#14,d0
.leftCol:
	move.w	d6,d1
	lsr.w	#1,d1
	mulu.w	#11,d1
	add.w	#52,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	addq.w	#1,d6
	cmp.w	#6,d6
	blt	.statLoop

	lea	TmpStr,a1		; vie et magie
	lea	TxtPv,a0
	bsr	StrCopy
	move.w	CreHp,d0
	bsr	StrNum
	lea	TxtSpPm,a0
	bsr	StrCopy
	move.w	CreMp,d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#90,d1
	move.w	#C_HEALTH,d2
	bsr	DrawText

	cmp.w	#1,d7
	bne.s	.nameUi
	lea	TxtRoll,a0
	moveq	#3,d0
	move.w	#112,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	bra	.done
.nameUi:
	lea	TmpStr,a1
	lea	TxtName,a0
	bsr	StrCopy
	lea	CreName,a0
	bsr	StrCopy
	move.b	#'_',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#106,d1
	move.w	#C_TEXT,d2
	bsr	DrawText
	lea	TxtNameHelp,a0
	moveq	#3,d0
	move.w	#120,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	lea	TxtAzerty,a0
	tst.w	KbLayout
	beq.s	.layout
	lea	TxtQwerty,a0
.layout:
	moveq	#3,d0
	move.w	#132,d1
	move.w	#C_TEXTLOW,d2
	bsr	DrawText
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Partie et niveaux
;----------------------------------------------------------------------
NewGame:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	#$1234abcd,RngSeed
	clr.w	Level
	clr.w	InCombat
	clr.w	Quit
	clr.w	GameOver
	clr.w	BossDead
	clr.w	UiMode
	clr.w	SelHero
	clr.w	InvCursor
	clr.w	InvTop
	clr.w	KeyCount
	move.w	#20,Gold
	lea	Heroes,a1
	move.w	#NHEROES*hr_SIZEOF-1,d0
.clrHero:
	clr.b	(a1)+
	dbf	d0,.clrHero
	lea	Inventory,a1
	moveq	#INVSIZE-1,d0
.clrInv:
	clr.b	(a1)+
	dbf	d0,.clrInv
	lea	LogBuf,a0
	move.w	#LOGLINES*(LOGWIDTH+2)-1,d0
.clrLog:
	clr.b	(a0)+
	dbf	d0,.clrLog
	move.w	#PHASE_CREATE,Phase
	clr.w	CreIndex
	clr.w	CreCursor
	clr.w	CreStep
	clr.w	KbLayout
	lea	TxtCreate1,a0
	bsr	LogAdd
	lea	TxtCreate2,a0
	bsr	LogAdd
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

LoadLevel:
	movem.l	d0-d3/a0-a1,-(sp)
	lea	DgnMap,a0
	move.w	Level,d0
	mulu.w	#LEVELSIZE,d0
	add.l	d0,a0
	moveq	#0,d1
	move.b	(a0)+,d1
	move.w	d1,PosX
	move.b	(a0)+,d1
	move.w	d1,PosY
	move.b	(a0)+,d1
	move.w	d1,Dir
	addq.l	#1,a0
	lea	MapTerrain,a1
	move.w	#MAPBYTES-1,d2
.copyT:
	move.b	(a0)+,(a1)+
	dbf	d2,.copyT
	lea	MapParam,a1
	move.w	#MAPBYTES-1,d2
.copyP:
	move.b	(a0)+,(a1)+
	dbf	d2,.copyP
	bsr	ShopFillStock		; le marchand de l'etage regarnit
	lea	MapSeen,a1		; on ne connait rien de cet etage
	move.w	#MAPBYTES-1,d2
.clearSeen:
	clr.b	(a1)+
	dbf	d2,.clearSeen
	bsr	MarkSeen
	movem.l	(sp)+,d0-d3/a0-a1
	rts

; MarkSeen : le groupe voit sa case et les huit qui l'entourent
MarkSeen:
	movem.l	d0-d4/a0,-(sp)
	move.w	PosY,d3
	subq.w	#1,d3
	moveq	#2,d4
.rowLoop:
	tst.w	d3
	bmi.s	.rowNext
	cmp.w	#MAPH,d3
	bge.s	.rowNext
	move.w	PosX,d2
	subq.w	#1,d2
	moveq	#2,d1
.colLoop:
	tst.w	d2
	bmi.s	.colNext
	cmp.w	#MAPW,d2
	bge.s	.colNext
	move.w	d3,d0
	mulu.w	#MAPW,d0
	add.w	d2,d0
	lea	MapSeen,a0
	move.b	#1,(a0,d0.w)
.colNext:
	addq.w	#1,d2
	dbf	d1,.colLoop
.rowNext:
	addq.w	#1,d3
	dbf	d4,.rowLoop
	movem.l	(sp)+,d0-d4/a0
	rts

;----------------------------------------------------------------------
; Sac a dos
;----------------------------------------------------------------------
AddItem:				; d0 = objet -> Z=1 si le sac est plein
	movem.l	d1-d2/a0,-(sp)
	lea	Inventory,a0
	moveq	#INVSIZE-1,d1
.find:
	tst.b	(a0)
	beq.s	.free
	addq.l	#1,a0
	dbf	d1,.find
	lea	TxtBagFull,a0
	bsr	LogAdd
	moveq	#0,d0
	bra.s	.done
.free:
	move.b	d0,(a0)
	moveq	#1,d0
.done:
	movem.l	(sp)+,d1-d2/a0
	rts

; LogItem : d0 = objet, a0 = prefixe
LogItem:
	movem.l	d0-d1/a0-a2,-(sp)
	move.l	a0,a2
	lea	TmpStr,a1
	move.l	a2,a0
	bsr	StrCopy
	move.w	d0,-(sp)
	move.w	(sp)+,d0
	bsr	ItemPtr
	bsr	StrCopy
	move.b	#'.',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	movem.l	(sp)+,d0-d1/a0-a2
	rts

;----------------------------------------------------------------------
; Deplacement
;----------------------------------------------------------------------
TryMove:				; d1 = +1 en avant, -1 en arriere
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	d1,d2
	bsr	CellAhead
	move.w	d0,d4
	move.w	d1,d5
	bsr	MapCell
	move.w	d0,d3
	and.w	#$000f,d0
	cmp.w	#T_WALL,d0
	beq	.blocked
	cmp.w	#T_NICHE,d0
	beq	.blocked
	cmp.w	#T_DOOR,d0
	beq	.shut
	cmp.w	#T_LOCKED,d0
	beq	.locked
	cmp.w	#T_RUNE,d0
	beq	.rune
	cmp.w	#T_LEVER,d0
	beq	.lever
	cmp.w	#T_GATE,d0
	beq	.gate
	cmp.w	#T_SHOP,d0
	beq	.shop
	cmp.w	#T_TRAP,d0
	beq	.trap
	cmp.w	#T_STELE,d0
	beq	.stele

	move.w	d4,PosX
	move.w	d5,PosY
	moveq	#SFX_STEP,d0
	bsr	SfxPlay
	move.w	d3,d6
	and.w	#$000f,d6
	cmp.w	#T_STAIRS,d6
	beq	.stairs
	move.w	d3,d6
	and.w	#C_MASK,d6
	cmp.w	#C_CHEST,d6
	beq	.chest
	cmp.w	#C_MONSTER,d6
	beq	.monster
	cmp.w	#C_ITEM,d6
	beq	.item
	bra	.redraw

.blocked:
	lea	TxtWall,a0
	bsr	LogAdd
	bra	.redraw
.shut:
	lea	TxtDoorShut,a0
	bsr	LogAdd
	bra	.redraw
.locked:
	lea	TxtLocked,a0
	bsr	LogAdd
	bra	.redraw
.rune:
	lea	TxtRuneDoor,a0
	bsr	LogAdd
	bra	.redraw
.lever:
	lea	TxtLeverSeen,a0
	bsr	LogAdd
	bra	.redraw
.gate:
	lea	TxtGateShut,a0
	bsr	LogAdd
	bra	.redraw
.shop:
	lea	TxtShopSeen,a0
	bsr	LogAdd
	bra	.redraw
.stele:
	lea	TxtSteleSeen,a0
	bsr	LogAdd
	bra	.redraw

; Un dallage piege. Tant que personne ne l'a vu, on marche dessus et il
; se detend. Une fois repere il barre le chemin : le desamorcer demande
; d'appuyer sur espace en le regardant.
.trap:
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapGetParam
	btst	#TRAP_SEEN,d0
	bne.s	.trapStep		; deja repere : on l'enjambe en sachant
	move.w	d4,d0			; sinon, le groupe a une chance de le
	move.w	d5,d1			; voir a temps
	bsr	SpotTrap
	tst.w	d0
	bne	.redraw			; repere : le groupe s'arrete net
.trapStep:
	move.w	d4,PosX
	move.w	d5,PosY
	move.w	d4,d0
	move.w	d5,d1
	bsr	SpringTrap
	bra	.redraw

.chest:
	move.w	d3,d2			; le coffre se vide
	and.w	#$000f,d2
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapSet
	moveq	#SFX_CHEST,d0
	bsr	SfxPlay
	moveq	#60,d1
	bsr	RndMod
	add.w	#25,d0
	add.w	d0,Gold
	lea	TmpStr,a1
	lea	TxtChest,a0
	bsr	StrCopy
	bsr	StrNum
	lea	TxtGoldSuffix,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	move.w	d4,d0			; et livre son objet
	move.w	d5,d1
	bsr	MapGetParam
	tst.w	d0
	beq	.redraw
	move.w	d0,d7
	bsr	AddItem
	tst.w	d0
	beq	.redraw
	move.w	d7,d0
	lea	TxtFound,a0
	bsr	LogItem
	move.w	d7,d0
	bsr	CheckKey
	bra	.redraw

.item:
	move.w	d3,d2
	and.w	#$000f,d2
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapSet
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapGetParam
	move.w	d0,d7
	bsr	AddItem
	tst.w	d0
	beq	.redraw
	moveq	#SFX_CHEST,d0
	bsr	SfxPlay
	move.w	d7,d0
	lea	TxtFound,a0
	bsr	LogItem
	move.w	d7,d0
	bsr	CheckKey
	bra	.redraw

.monster:
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapGetParam
	cmp.w	#NMONSTERS,d0
	blt.s	.kindOk
	moveq	#0,d0
.kindOk:
	move.w	d0,MonKind
	bsr	StartCombat
	bra.s	.redraw
.stairs:
	bsr	Descend
.redraw:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

CheckKey:				; d0 = objet : compter les cles
	movem.l	d0/a0,-(sp)
	bsr	ItemPtr
	cmp.w	#IT_KEY,it_Type(a0)
	bne.s	.done
	addq.w	#1,KeyCount
.done:
	movem.l	(sp)+,d0/a0
	rts

;----------------------------------------------------------------------
; Action : ouvrir une porte, fouiller une niche
;----------------------------------------------------------------------
DoAction:
	movem.l	d0-d7/a0-a6,-(sp)
	moveq	#1,d2
	bsr	CellAhead
	move.w	d0,d4
	move.w	d1,d5
	bsr	MapCell
	move.w	d0,d3
	and.w	#$000f,d0
	cmp.w	#T_DOOR,d0
	beq	.door
	cmp.w	#T_LOCKED,d0
	beq	.lockedDoor
	cmp.w	#T_NICHE,d0
	beq	.niche
	cmp.w	#T_RUNE,d0
	beq	.rune
	cmp.w	#T_LEVER,d0
	beq	.lever
	cmp.w	#T_SHOP,d0
	beq	.shopOpen
	cmp.w	#T_TRAP,d0
	beq	.trapDisarm
	cmp.w	#T_STELE,d0
	beq	.steleRead
	lea	TxtNothing,a0
	bsr	LogAdd
	bra	.done
.shopOpen:
	move.w	#UI_SHOP,UiMode
	clr.w	ShopMode
	clr.w	ShopCursor
	clr.w	ShopTop
	moveq	#SFX_COIN,d0
	bsr	SfxPlay
	lea	TxtShopHello,a0
	bsr	LogAdd
	bra	.done
.steleRead:
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapGetParam
	add.w	#LORE_FIRST,d0
	bsr	ShowLore
	moveq	#SFX_LEVEL,d0
	bsr	SfxPlay
	bra	.done
.trapDisarm:
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapGetParam
	btst	#TRAP_SEEN,d0		; on ne desamorce que ce qu'on voit
	bne.s	.disarmGo
	lea	TxtNothing,a0
	bsr	LogAdd
	bra	.done
.disarmGo:
	move.w	d4,d0
	move.w	d5,d1
	bsr	DisarmTrap
	bra	.done
.door:
	move.w	d3,d2
	and.w	#$00f0,d2
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapSet
	moveq	#SFX_DOOR,d0
	bsr	SfxPlay
	lea	TxtDoorOpen,a0
	bsr	LogAdd
	bra	.done
.lockedDoor:
	tst.w	KeyCount
	beq.s	.noKey
	subq.w	#1,KeyCount
	move.w	d3,d2
	and.w	#$00f0,d2
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapSet
	moveq	#SFX_DOOR,d0
	bsr	SfxPlay
	lea	TxtUnlock,a0
	bsr	LogAdd
	bra	.done
.noKey:
	lea	TxtNeedKey,a0
	bsr	LogAdd
	bra	.done
.niche:
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapGetParam
	tst.w	d0
	beq.s	.emptyNiche
	move.w	d0,d7
	bsr	AddItem
	tst.w	d0
	beq	.done
	moveq	#SFX_CHEST,d0
	bsr	SfxPlay
	move.w	d4,d0			; la niche devient un mur ordinaire
	move.w	d5,d1
	moveq	#T_WALL,d2
	bsr	MapSet
	move.w	d4,d0
	move.w	d5,d1
	moveq	#0,d2
	bsr	MapSetParam
	move.w	d7,d0
	lea	TxtNiche,a0
	bsr	LogItem
	move.w	d7,d0
	bsr	CheckKey
	bra	.done
.emptyNiche:
	lea	TxtNicheEmpty,a0
	bsr	LogAdd
	bra	.done
.lever:
	move.w	d4,d0			; le numero du mecanisme
	move.w	d5,d1
	bsr	MapGetParam
	move.w	d0,d6
	and.w	#$007f,d6		; sans le drapeau d'etat
	beq	.done
	move.w	d0,d3			; etat courant
	eor.w	#$0080,d3		; on bascule le levier
	move.w	d4,d0
	move.w	d5,d1
	move.w	d3,d2
	bsr	MapSetParam
	btst	#7,d3
	beq.s	.leverUp
	moveq	#T_FLOOR,d3		; abaisse : les herses s'ouvrent
	lea	TxtLeverDown,a0
	bra.s	.leverGo
.leverUp:
	moveq	#T_GATE,d3		; releve : elles retombent
	lea	TxtLeverUp,a0
.leverGo:
	bsr	LogAdd
	moveq	#SFX_DOOR,d0
	bsr	SfxPlay
	bsr	SetGates
	bra	.done

.rune:
	move.w	d4,d0			; l'enigme gravee sur la porte
	move.w	d5,d1
	bsr	MapGetParam
	cmp.w	#3,d0
	blt.s	.riddleOk
	moveq	#0,d0
.riddleOk:
	move.w	d0,RiddleIdx
	move.w	d4,RiddleX
	move.w	d5,RiddleY
	move.w	#UI_RIDDLE,UiMode
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Carte du niveau : une case du donjon par bloc de huit pixels sur
; quatre. On ne montre que ce que le groupe a longe -- MapSeen -- pour
; que le releve se dessine au fur et a mesure de l'exploration.
;----------------------------------------------------------------------
; MapBlock : d0 = colonne octet, d1 = ligne, d2 = hauteur, d3 = couleur
MapBlock:
	movem.l	d0-d7/a0-a1,-(sp)
	tst.w	d3
	beq.s	.done			; couleur zero : le fond suffit
	move.l	DrawBuf,a0
	move.w	d1,d5
	mulu.w	#SCRBPL,d5
	add.w	d0,d5
	add.l	d5,a0
	moveq	#0,d6
.plane:
	btst	d6,d3
	beq.s	.next
	move.l	a0,a1
	move.w	d2,d7
	subq.w	#1,d7
.rows:
	move.b	#$ff,(a1)
	lea	SCRBPL(a1),a1
	dbf	d7,.rows
.next:
	lea	PLANESIZE(a0),a0
	addq.w	#1,d6
	cmp.w	#DEPTH,d6
	blt.s	.plane
.done:
	movem.l	(sp)+,d0-d7/a0-a1
	rts

; MapColour : d1 = case, d6 = x, d7 = y -> d0 = couleur
MapColour:
	movem.l	d1-d3,-(sp)
	cmp.w	PosX,d6
	bne.s	.notHere
	cmp.w	PosY,d7
	bne.s	.notHere
	move.w	#C_WHITE,d0		; le groupe, en blanc
	bra	.done
.notHere:
	move.w	d1,d2
	and.w	#$000f,d2		; terrain
	move.w	d1,d3
	and.w	#C_MASK,d3		; ce que la case contient
	cmp.w	#T_STAIRS,d2
	bne.s	.notStairs
	move.w	#C_GOLD+N_GOLD-2,d0	; escalier
	bra	.done
.notStairs:
	cmp.w	#T_DOOR,d2
	bne.s	.notDoor
	move.w	#C_WOOD+N_WOOD-4,d0	; porte
	bra	.done
.notDoor:
	cmp.w	#T_LOCKED,d2
	bne.s	.notLocked
	move.w	#C_BLOOD+3,d0		; porte verrouillee
	bra.s	.done
.notLocked:
	cmp.w	#T_RUNE,d2
	bne.s	.notRune
	move.w	#C_MAGIC+4,d0		; porte a runes
	bra.s	.done
.notRune:
	cmp.w	#T_LEVER,d2
	bne.s	.notLever
	move.w	#C_GOLD+2,d0		; levier
	bra.s	.done
.notLever:
	cmp.w	#T_GATE,d2
	bne.s	.notGate
	move.w	#C_IRON+N_IRON-3,d0	; herse fermee
	bra.s	.done
.notGate:
	cmp.w	#T_NICHE,d2
	bne.s	.notNiche
	move.w	#C_STONE+12,d0		; niche
	bra.s	.done
.notNiche:
	cmp.w	#T_WALL,d2
	bne.s	.floor
	move.w	#C_STONE+4,d0		; mur reconnu
	bra.s	.done
.floor:
	cmp.w	#C_MONSTER,d3
	bne.s	.notMon
	move.w	#C_ALERT,d0		; monstre
	bra.s	.done
.notMon:
	cmp.w	#C_CHEST,d3
	bne.s	.notChest
	move.w	#C_HILITE,d0		; coffre
	bra.s	.done
.notChest:
	cmp.w	#C_ITEM,d3
	bne.s	.plain
	move.w	#C_PARCH,d0		; objet
	bra.s	.done
.plain:
	move.w	#C_EARTH+N_EARTH-5,d0	; sol parcouru
.done:
	movem.l	(sp)+,d1-d3
	rts

DrawMap:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect

	lea	TmpStr,a1		; CARTE NIVEAU n - direction
	lea	TxtMapTitle,a0
	bsr	StrCopy
	move.w	Level,d0
	addq.w	#1,d0
	bsr	StrNum
	lea	TxtDash2,a0
	bsr	StrCopy
	move.w	Dir,d0
	lsl.w	#2,d0
	lea	DirNames,a0
	move.l	(a0,d0.w),a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	moveq	#18,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	moveq	#0,d7			; ligne de la carte
.rowLoop:
	moveq	#0,d6			; colonne
.colLoop:
	move.w	d7,d0
	mulu.w	#MAPW,d0
	add.w	d6,d0
	lea	MapSeen,a0
	tst.b	(a0,d0.w)
	beq.s	.cellNext		; jamais longee : noir
	lea	MapTerrain,a0
	moveq	#0,d1
	move.b	(a0,d0.w),d1
	bsr	MapColour
	move.w	d0,d3
	move.w	d6,d0
	add.w	#MAP_X,d0
	move.w	d7,d1
	mulu.w	#MAP_CH,d1
	add.w	#MAP_Y,d1
	moveq	#MAP_CH,d2
	bsr	MapBlock
.cellNext:
	addq.w	#1,d6
	cmp.w	#MAPW,d6
	blt	.colLoop
	addq.w	#1,d7
	cmp.w	#MAPH,d7
	blt	.rowLoop

	lea	LegendTab,a2		; la legende, chacun dans sa couleur
	moveq	#5,d7
.legLoop:
	move.l	(a2)+,a0
	moveq	#0,d0
	move.b	(a2)+,d0
	moveq	#0,d1
	move.b	(a2)+,d1
	moveq	#0,d2
	move.b	(a2)+,d2
	addq.l	#1,a2
	bsr	DrawText
	dbf	d7,.legLoop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Enigmes des portes a runes
;----------------------------------------------------------------------
DrawRiddle:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect
	lea	TxtRuneTitle,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	move.w	RiddleIdx,d0
	mulu.w	#rd_SIZEOF,d0
	lea	RiddleTable,a2
	add.l	d0,a2
	moveq	#0,d7
.qLoop:				; trois lignes de question
	move.w	d7,d0
	lsl.w	#2,d0
	move.l	(a2,d0.w),a0
	moveq	#3,d0
	move.w	d7,d1
	mulu.w	#11,d1
	add.w	#38,d1
	move.w	#C_TEXT,d2
	bsr	DrawText
	addq.w	#1,d7
	cmp.w	#3,d7
	blt.s	.qLoop

	moveq	#0,d7
.aLoop:				; trois reponses numerotees
	lea	TmpStr,a1
	move.w	d7,d0
	addq.w	#1,d0
	bsr	StrNum
	lea	TxtDash,a0
	bsr	StrCopy
	move.w	d7,d0
	addq.w	#3,d0
	lsl.w	#2,d0
	move.l	(a2,d0.w),a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	d7,d1
	mulu.w	#13,d1
	add.w	#84,d1
	move.w	#C_HEALTH,d2
	bsr	DrawText
	addq.w	#1,d7
	cmp.w	#3,d7
	blt.s	.aLoop

	lea	TxtRuneAsk,a0
	moveq	#3,d0
	move.w	#128,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

AnswerRiddle:				; d0 = reponse donnee (0..2)
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	d0,d7
	move.w	RiddleIdx,d0
	mulu.w	#rd_SIZEOF,d0
	lea	RiddleTable,a2
	add.l	d0,a2
	cmp.w	24(a2),d7
	bne.s	.wrong
	move.w	RiddleX,d0		; la porte s'ouvre
	move.w	RiddleY,d1
	moveq	#T_FLOOR,d2
	bsr	MapSet
	moveq	#SFX_LEVEL,d0
	bsr	SfxPlay
	lea	TxtRuneOk,a0
	bsr	LogAdd
	lea	Heroes,a6		; un peu d'experience pour la sagacite
	moveq	#NHEROES-1,d6
.xpLoop:
	tst.w	hr_Hp(a6)
	beq.s	.xpNext
	add.w	#15,hr_Xp(a6)
	bsr	CheckLevel
.xpNext:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.xpLoop
	bra.s	.done
.wrong:
	moveq	#SFX_HIT,d0
	bsr	SfxPlay
	lea	TxtRuneBad,a0
	bsr	LogAdd
	moveq	#NHEROES,d1		; la rune mord celui qui se trompe
	bsr	RndMod
	bsr	HeroPtr
	tst.w	hr_Hp(a6)
	beq.s	.done
	moveq	#1,d0
	moveq	#6,d1
	bsr	RollDice
	move.w	d0,d5
	sub.w	d5,hr_Hp(a6)
	tst.w	hr_Hp(a6)
	bgt.s	.alive
	clr.w	hr_Hp(a6)
.alive:
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtRuneBurn,a0
	bsr	StrCopy
	move.w	d5,d0
	bsr	StrNum
	lea	TxtPvSuffix,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bsr	CheckWipe
.done:
	clr.w	UiMode
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts


;----------------------------------------------------------------------
; L'echoppe
;
; L'or s'entassait sans emploi : les coffres en donnaient, les monstres
; aussi, et rien n'en demandait jamais. Le marchand vend ce qu'il a sur
; son etal au prix de l'objet, et rachete le butin a moitie prix.
;----------------------------------------------------------------------
ShopRows:				; -> d0 = lignes du cote ouvert
	tst.w	ShopMode
	bne.s	.sell
	moveq	#NSHOP,d0
	rts
.sell:
	move.w	#INVSIZE,d0
	rts

ShopItem:				; d0 = ligne -> d0 = objet, Z si vide
	movem.l	d1/a0,-(sp)
	move.w	d0,d1
	moveq	#0,d0
	tst.w	ShopMode
	bne.s	.sell
	cmp.w	#NSHOP,d1
	bge.s	.done
	lea	ShopStock,a0
	bra.s	.read
.sell:
	cmp.w	#INVSIZE,d1
	bge.s	.done
	lea	Inventory,a0
.read:
	move.b	(a0,d1.w),d0
.done:
	movem.l	(sp)+,d1/a0
	tst.w	d0
	rts

ShopPrice:				; d0 = objet -> d0 = prix du cote ouvert
	movem.l	a0,-(sp)
	bsr	ItemPtr
	move.w	it_Value(a0),d0
	tst.w	ShopMode
	beq.s	.done
	lsr.w	#1,d0			; il rachete a moitie
	tst.w	d0
	bne.s	.done
	moveq	#1,d0			; jamais pour rien
.done:
	movem.l	(sp)+,a0
	rts

ShopFillStock:				; l'etal de l'etage courant
	movem.l	d0-d2/a0-a1,-(sp)
	lea	ShopTable,a0
	move.w	Level,d0
	mulu.w	#NSHOP,d0
	add.l	d0,a0
	lea	ShopStock,a1
	moveq	#NSHOP-1,d1
.copy:
	move.b	(a0)+,(a1)+
	dbf	d1,.copy
	movem.l	(sp)+,d0-d2/a0-a1
	rts

DrawShop:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect
	lea	TxtShopTitle,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	lea	TxtShopBuy,a0
	tst.w	ShopMode
	beq.s	.side
	lea	TxtShopSell,a0
.side:
	moveq	#11,d0
	moveq	#20,d1
	move.w	#C_ALERT,d2
	bsr	DrawText
	lea	TmpStr,a1
	lea	TxtShopGold,a0
	bsr	StrCopy
	move.w	Gold,d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#18,d0
	moveq	#20,d1
	move.w	#C_GOLD+2,d2
	bsr	DrawText

	moveq	#0,d7
.rowLoop:
	move.w	ShopTop,d6
	add.w	d7,d6
	bsr	ShopRows
	cmp.w	d0,d6
	bge	.rowsDone
	move.w	d6,d0
	bsr	ShopItem
	beq	.rowNext
	move.w	d0,d5

	lea	TmpStr,a1
	cmp.w	ShopCursor,d6
	bne.s	.noCur
	move.b	#'>',(a1)+
	move.b	#' ',(a1)+
	bra.s	.name
.noCur:
	move.b	#' ',(a1)+
	move.b	#' ',(a1)+
.name:
	move.w	d5,d0
	bsr	ItemPtr
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	d7,d1
	mulu.w	#11,d1
	add.w	#34,d1
	move.w	#C_TEXT,d2
	bsr	DrawText

	move.w	d5,d0			; le prix, cale sur la marge droite
	bsr	ShopPrice
	move.w	d0,d4
	lea	TmpStr,a1
	move.w	d4,d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	lea	TmpStr,a2		; un chiffre de moins, une colonne
	moveq	#25,d0			; de plus vers la droite
.count:
	tst.b	(a2)+
	beq.s	.counted
	subq.w	#1,d0
	bra.s	.count
.counted:
	move.w	d7,d1
	mulu.w	#11,d1
	add.w	#34,d1
	move.w	#C_GOLD+2,d2
	cmp.w	Gold,d4			; hors de prix : le chiffre s'eteint
	ble.s	.afford
	tst.w	ShopMode
	bne.s	.afford
	move.w	#C_TEXTLOW,d2
.afford:
	bsr	DrawText
.rowNext:
	addq.w	#1,d7
	cmp.w	#SHOPROWS,d7
	blt	.rowLoop
.rowsDone:
	lea	TxtShopHelp,a0
	moveq	#3,d0
	move.w	#124,d1
	move.w	#C_TEXTLOW,d2
	bsr	DrawText
	lea	TxtShopHelp2,a0
	moveq	#3,d0
	move.w	#135,d1
	move.w	#C_TEXTLOW,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ShopDeal : conclut la ligne visee, dans un sens ou dans l'autre
ShopDeal:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	ShopCursor,d0
	bsr	ShopItem
	bne.s	.have
	tst.w	ShopMode
	bne.s	.noSell
	lea	TxtShopEmpty,a0
	bra	.say
.noSell:
	lea	TxtShopNoSell,a0
	bra	.say
.have:
	move.w	d0,d7			; objet
	bsr	ShopPrice
	move.w	d0,d6			; prix
	tst.w	ShopMode
	bne	.sell

	cmp.w	Gold,d6
	ble.s	.rich
	lea	TxtShopPoor,a0
	bra	.say
.rich:
	move.w	d7,d0
	bsr	AddItem
	tst.w	d0
	bne.s	.taken
	lea	TxtShopFull,a0		; AddItem l'a deja dit, mais le
	bra	.say			; panneau reste ouvert
.taken:
	sub.w	d6,Gold
	move.w	d7,d0
	bsr	CheckKey
	lea	ShopStock,a0		; l'etal se vide de cette piece
	move.w	ShopCursor,d0
	clr.b	(a0,d0.w)
	lea	TxtShopBought,a0
	bra.s	.receipt

.sell:
	move.w	d7,d0
	bsr	ItemPtr
	cmp.w	#IT_KEY,it_Type(a0)	; les cles comptent a part
	bne.s	.notKey
	tst.w	KeyCount
	beq.s	.notKey
	subq.w	#1,KeyCount
.notKey:
	move.w	ShopCursor,InvCursor	; InvClear travaille sur le curseur
	bsr	InvClear		; du sac : on les fait coincider
	add.w	d6,Gold
	lea	TxtShopSold,a0

.receipt:
	lea	TmpStr,a1
	bsr	StrCopy
	move.w	d7,d0
	bsr	ItemPtr
	bsr	StrCopy
	lea	TxtShopFor,a0
	bsr	StrCopy
	move.w	d6,d0
	bsr	StrNum
	lea	TxtShopOr,a0
	bsr	StrCopy
	clr.b	(a1)
	moveq	#SFX_COIN,d0
	bsr	SfxPlay
	lea	TmpStr,a0
.say:
	bsr	LogAdd
	bsr	ShopClamp
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; ShopClamp : garde le curseur dans la liste et sur l'ecran
ShopClamp:
	movem.l	d0-d2,-(sp)
	bsr	ShopRows
	move.w	d0,d2
	subq.w	#1,d2
	move.w	ShopCursor,d0
	cmp.w	d2,d0
	ble.s	.notPast
	move.w	d2,d0
.notPast:
	bpl.s	.notNeg
	moveq	#0,d0
.notNeg:
	move.w	d0,ShopCursor
	move.w	ShopTop,d1
	cmp.w	d1,d0
	bge.s	.notAbove
	move.w	d0,ShopTop
	bra.s	.done
.notAbove:
	sub.w	d1,d0
	cmp.w	#SHOPROWS,d0
	blt.s	.done
	move.w	ShopCursor,d0
	sub.w	#SHOPROWS-1,d0
	move.w	d0,ShopTop
.done:
	movem.l	(sp)+,d0-d2
	rts

ShopKey:				; d0 = touche
	movem.l	d0-d7/a0-a6,-(sp)
	cmp.w	#KEY_UP,d0
	bne.s	.notUp
	subq.w	#1,ShopCursor
	bra.s	.moved
.notUp:
	cmp.w	#KEY_DOWN,d0
	bne.s	.notDown
	addq.w	#1,ShopCursor
	bra.s	.moved
.notDown:
	cmp.w	#KEY_TAB,d0		; on passe d'un cote du comptoir
	bne.s	.notTab			; a l'autre
	eor.w	#1,ShopMode
	clr.w	ShopCursor
	clr.w	ShopTop
	bra.s	.moved
.notTab:
	cmp.w	#KEY_RETURN,d0
	beq.s	.deal
	cmp.w	#KEY_SPACE,d0
	bne.s	.done
.deal:
	bsr	ShopDeal
	bra.s	.done
.moved:
	bsr	ShopClamp
	move.w	#1,NeedRedraw
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts


;----------------------------------------------------------------------
; Le journal
;
; Un donjon sans recit n'est qu'un couloir. Les steles gravees, les
; registres et les lettres racontent la crypte a mesure qu'on descend ;
; l'introduction et les deux fins passent par le meme panneau.
;----------------------------------------------------------------------
ShowLore:				; d0 = numero de page
	movem.l	d0-d1,-(sp)
	cmp.w	#NLORE,d0
	blt.s	.ok
	moveq	#0,d0
.ok:
	move.w	d0,LorePage
	move.w	#UI_LORE,UiMode
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d1
	rts

LorePtr:				; d0 = page -> a0 = son titre
	movem.l	d1/a1,-(sp)
	move.w	d0,d1
	add.w	d1,d1
	add.w	d1,d1
	lea	LoreTable,a1
	move.l	(a1,d1.w),a0
	movem.l	(sp)+,d1/a1
	rts

DrawLore:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect

	move.w	LorePage,d0
	bsr	LorePtr
	move.l	a0,a2			; le titre, puis les lignes a la suite
	moveq	#3,d0
	moveq	#18,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	bsr	StrSkip			; a2 avance sur la premiere ligne

	moveq	#0,d7
.lineLoop:
	move.l	a2,a0
	tst.b	(a0)
	beq.s	.blank
	moveq	#3,d0
	move.w	d7,d1
	mulu.w	#10,d1
	add.w	#32,d1
	move.w	#C_PARCH,d2
	bsr	DrawText
.blank:
	move.l	a2,a0
	bsr	StrSkip
	move.l	a0,a2
	addq.w	#1,d7
	cmp.w	#LORELINES,d7
	blt.s	.lineLoop

	movem.l	(sp)+,d0-d7/a0-a6
	rts

; StrSkip : a0 (et a2 pour l'appelant) passe a la chaine suivante
StrSkip:
	tst.b	(a0)+
	bne.s	StrSkip
	move.l	a0,a2
	rts


;----------------------------------------------------------------------
; Les pieges
;
; Un dallage piege ne se voit pas. En marchant dessus, le groupe a
; d'abord une chance de le repere : chacun tente sa chance, le roublard
; a l'oeil et les autres leur bon sens. Repere, le piege reste marque
; sur le plan et ne bouge plus : on l'enjambe en connaissance de cause,
; ou on le desamorce.
;----------------------------------------------------------------------
TrapPtr:				; d0 = espece -> a0
	movem.l	d1,-(sp)
	move.w	d0,d1
	and.w	#NTRAPS-1,d1
	mulu.w	#tp_SIZEOF,d1
	lea	TrapTable,a0
	add.l	d1,a0
	movem.l	(sp)+,d1
	rts

TrapDC:					; -> d0 = difficulte, selon l'etage
	move.w	Level,d0
	add.w	d0,d0
	add.w	#14,d0
	rts

; TrapSkill : a6 = heros -> d0 = ce qu'il ajoute a son d20. Le roublard
; est du metier ; les autres n'ont que leur sagesse et l'habitude.
TrapSkill:
	movem.l	d1-d2/a0,-(sp)
	moveq	#0,d2
	cmp.w	#2,hr_Class(a6)		; ROUBLARD
	bne.s	.plain
	move.w	hr_Level(a6),d2
	addq.w	#4,d2
	bra.s	.wis
.plain:
	move.w	hr_Level(a6),d2
	and.l	#$0000ffff,d2
	divu.w	#3,d2
	and.l	#$0000ffff,d2
.wis:
	move.w	hr_Wis(a6),d0
	bsr	StatMod
	add.w	d2,d0
	movem.l	(sp)+,d1-d2/a0
	rts

MarkTrapSeen:				; d0 = x, d1 = y
	movem.l	d0-d2,-(sp)
	move.w	d0,d2
	bsr	MapGetParam
	bset	#TRAP_SEEN,d0
	move.w	d0,-(sp)
	move.w	d2,d0
	move.w	(sp)+,d2
	bsr	MapSetParam
	movem.l	(sp)+,d0-d2
	rts

; SpotTrap : d0 = x, d1 = y -> d0 = 1 si quelqu'un l'a vu a temps
SpotTrap:
	movem.l	d1-d7/a0-a6,-(sp)
	move.w	d0,d6
	move.w	d1,d7
	bsr	TrapDC
	move.w	d0,d5
	lea	Heroes,a6
	moveq	#NHEROES-1,d4
	moveq	#0,d3
.loop:
	tst.w	hr_Hp(a6)
	beq.s	.next
	bsr	TrapSkill
	move.w	d0,d2
	bsr	D20
	add.w	d2,d0
	cmp.w	d5,d0
	blt.s	.next
	moveq	#1,d3
.next:
	lea	hr_SIZEOF(a6),a6
	dbf	d4,.loop
	tst.w	d3
	beq.s	.missed
	move.w	d6,d0
	move.w	d7,d1
	bsr	MarkTrapSeen
	move.w	d6,d0			; nommer ce qu'on a repere
	move.w	d7,d1
	bsr	MapGetParam
	bsr	TrapPtr
	lea	TmpStr,a1
	move.l	a0,-(sp)
	lea	TxtTrapSpot,a0
	bsr	StrCopy
	move.l	(sp)+,a0
	bsr	StrCopy
	move.b	#'.',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	moveq	#1,d0
	bra.s	.done
.missed:
	moveq	#0,d0
.done:
	movem.l	(sp)+,d1-d7/a0-a6
	rts

; SpringTrap : d0 = x, d1 = y. Le piege se detend, puis disparait :
; un ressort ne sert qu'une fois.
SpringTrap:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	d0,d6
	move.w	d1,d7
	bsr	MapGetParam
	move.w	d0,d5			; espece
	bsr	TrapPtr
	move.l	a0,a5			; descripteur du piege
	move.w	d6,d0			; le dallage redevient ordinaire
	move.w	d7,d1
	moveq	#T_FLOOR,d2
	bsr	MapSet
	move.w	d6,d0
	move.w	d7,d1
	moveq	#0,d2
	bsr	MapSetParam

	moveq	#SFX_TRAP,d0
	bsr	SfxPlay
	lea	TmpStr,a1
	move.l	a5,a0
	bsr	StrCopy
	lea	TxtTrapFires,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd

	bsr	TrapDC
	move.w	d0,d4			; difficulte de la sauvegarde
	lea	Heroes,a6
	moveq	#NHEROES-1,d3
	moveq	#0,d2			; total perdu par le groupe
.hurt:
	tst.w	hr_Hp(a6)
	beq	.next
	move.w	Level,d0		; degats : un de par etage, plus un
	addq.w	#1,d0
	move.w	tp_Faces(a5),d1
	bsr	RollDice
	move.w	d0,d6
	move.w	tp_Save(a5),d0		; la bonne sauvegarde du piege
	bsr	HeroSave
	move.w	d0,d7
	bsr	D20
	add.w	d7,d0
	cmp.w	d4,d0
	blt.s	.full
	lsr.w	#1,d6			; sauvegarde reussie : moitie moins
.full:
	tst.w	d6
	beq.s	.next
	sub.w	d6,hr_Hp(a6)
	tst.w	hr_Hp(a6)
	bgt.s	.alive
	clr.w	hr_Hp(a6)
.alive:
	add.w	d6,d2
.next:
	lea	hr_SIZEOF(a6),a6
	dbf	d3,.hurt

	tst.w	d2
	beq.s	.spared
	lea	TmpStr,a1
	lea	TxtTrapHurt,a0
	bsr	StrCopy
	move.w	d2,d0
	bsr	StrNum
	lea	TxtPvSuffix,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bsr	CheckWipe
	bra.s	.done
.spared:
	lea	TxtTrapMiss,a0
	bsr	LogAdd
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; DisarmTrap : d0 = x, d1 = y. Le heros choisi s'y colle. Rate de peu,
; il recommencera ; rate de loin, le piege lui saute au visage.
DisarmTrap:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	d0,d6
	move.w	d1,d7
	move.w	SelHero,d0
	bsr	HeroPtr
	tst.w	hr_Hp(a6)
	beq	.down
	bsr	TrapDC
	move.w	d0,d5
	bsr	TrapSkill
	move.w	d0,d4
	bsr	D20
	add.w	d4,d0
	cmp.w	d5,d0
	blt.s	.failed
	move.w	d6,d0			; desamorce : plus rien sous la dalle
	move.w	d7,d1
	moveq	#T_FLOOR,d2
	bsr	MapSet
	move.w	d6,d0
	move.w	d7,d1
	moveq	#0,d2
	bsr	MapSetParam
	moveq	#SFX_LEVEL,d0
	bsr	SfxPlay
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtTrapOff,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	lea	Heroes,a6		; le tour de main profite a tous
	moveq	#NHEROES-1,d3
.xp:
	tst.w	hr_Hp(a6)
	beq.s	.xpNext
	move.w	Level,d0
	mulu.w	#15,d0
	add.w	#25,d0
	add.w	d0,hr_Xp(a6)
	bsr	CheckLevel
.xpNext:
	lea	hr_SIZEOF(a6),a6
	dbf	d3,.xp
	bra.s	.done
.failed:
	add.w	#5,d0			; rate de peu : la main a tremble
	cmp.w	d5,d0
	blt.s	.sprung
	lea	TxtTrapSlip,a0
	bsr	LogAdd
	bra.s	.done
.sprung:
	move.w	d6,d0
	move.w	d7,d1
	bsr	SpringTrap
	bra.s	.done
.down:
	lea	TxtTrapDown,a0
	bsr	LogAdd
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

Descend:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	Level,d0
	addq.w	#1,d0
	cmp.w	#LEVELS,d0
	blt	.next
	tst.w	BossDead		; la sortie se merite : le gardien
	bne.s	.out			; veille au pied de l'escalier
	moveq	#SFX_GROWL,d0
	bsr	SfxPlay
	lea	TxtGuardian,a0
	bsr	LogAdd
	move.w	#MON_BOSS,MonKind
	bsr	StartCombat
	bra	.done
.out:
	move.w	#1,GameOver
	moveq	#SFX_LEVEL,d0
	bsr	SfxPlay
	lea	TxtWin,a0
	bsr	LogAdd
	moveq	#LORE_WIN,d0		; et la derniere page du recit
	bsr	ShowLore
	bra.s	.done
.next:
	move.w	d0,Level
	bsr	LevelMusic		; les profondeurs ont leur musique
	bsr	LoadLevel
	bsr	PartyRest
	bsr	SaveGame		; un etage franchi, une partie sauvee
	moveq	#SFX_DOOR,d0
	bsr	SfxPlay
	lea	TxtDescend,a0
	bsr	LogAdd
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; SetGates : d6 = numero du mecanisme, d3 = terrain a poser sur ses
; herses. Un seul levier peut en commander plusieurs.
SetGates:
	movem.l	d0-d7/a0-a1,-(sp)
	lea	MapTerrain,a0
	lea	MapParam,a1
	move.w	#MAPBYTES-1,d7
	moveq	#0,d5
.loop:
	moveq	#0,d0
	move.b	(a0,d5.w),d0
	move.w	d0,d1
	and.w	#$000f,d1
	cmp.w	#T_GATE,d1
	beq.s	.match
	tst.w	d1			; une herse ouverte est du sol
	bne.s	.next
.match:
	moveq	#0,d2
	move.b	(a1,d5.w),d2
	and.w	#$007f,d2
	cmp.w	d6,d2
	bne.s	.next
	tst.w	d1			; ne toucher qu'aux cases du mecanisme
	beq.s	.isOpen
	bra.s	.set
.isOpen:
	tst.w	d2			; du sol sans numero : ce n'est pas
	beq.s	.next			; une herse
.set:
	and.w	#$00f0,d0		; on garde le contenu de la case
	or.w	d3,d0
	move.b	d0,(a0,d5.w)
.next:
	addq.w	#1,d5
	dbf	d7,.loop
	movem.l	(sp)+,d0-d7/a0-a1
	rts

; PartyRest : une halte entre deux niveaux rend les sorts et un peu
; de souffle. Sans elle les lanceurs restent a sec des le premier etage.
PartyRest:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	Heroes,a6
	moveq	#NHEROES-1,d6
.loop:
	tst.w	hr_HpMax(a6)
	beq.s	.next
	move.w	hr_HpMax(a6),d0
	lsr.w	#1,d0			; la moitie des points de vie
	tst.w	d0
	bne.s	.heal
	moveq	#1,d0
.heal:
	move.w	hr_StrLoss(a6),d1	; le poison se dissipe
	beq.s	.noPoison
	add.w	d1,hr_Str(a6)
	clr.w	hr_StrLoss(a6)
.noPoison:
	clr.w	hr_Stun(a6)
	add.w	d0,hr_Hp(a6)
	move.w	hr_HpMax(a6),d0
	cmp.w	hr_Hp(a6),d0
	bge.s	.capped
	move.w	d0,hr_Hp(a6)
.capped:
	bsr	FillSlots
.next:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.loop
	lea	TxtRested,a0
	bsr	LogAdd
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Combat, avec des jets au d20 contre la classe d'armure
;----------------------------------------------------------------------
StartCombat:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#1,InCombat
	clr.w	AnimFrame
	clr.w	MonStun
	move.w	MonKind,d0
	mulu.w	#mt_SIZEOF,d0
	lea	MonTypes,a2
	add.l	d0,a2
	move.l	a2,MonPtr
	bsr	FoeRollHp
	move.w	mt_Art(a2),MonArt
	clr.w	PartyBless

	move.w	mt_Pack(a2),d1		; combien s'en presentent
	cmp.w	#1,d1
	ble.s	.alone
	bsr	RndMod			; 0..pack-1
	addq.w	#1,d0			; 1..pack
	; Les premieres salles ne jettent pas quatre kobolds sur un
	; groupe de niveau un : quatre heros de onze points de vie n'y
	; survivent pas, et le banc l'a montre avant que le joueur ne
	; l'apprenne a ses depens. La bande grossit avec la profondeur --
	; deux au premier etage, trois au deuxieme, quatre ensuite.
	move.w	Level,d1
	addq.w	#2,d1
	cmp.w	d1,d0
	ble.s	.haveCount
	move.w	d1,d0
	bra.s	.haveCount
.alone:
	moveq	#1,d0
.haveCount:
	move.w	d0,MonCount
	move.w	d0,MonPack
	move.w	#1,MonRange		; elle est encore au bout du couloir
	cmp.w	#MON_BOSS,MonKind	; le gardien, lui, barre l'escalier :
	bne.s	.notBoss		; on lui marche dessus
	clr.w	MonRange
.notBoss:

	moveq	#SFX_GROWL,d0
	bsr	SfxPlay
	lea	TmpStr,a1
	lea	TxtAppears,a0
	bsr	StrCopy
	move.l	a2,a0
	bsr	StrCopy
	move.w	MonPack,d0		; "ORC, ET TROIS AUTRES !"
	subq.w	#1,d0
	beq.s	.justOne
	lea	TxtAndMore,a0
	bsr	StrCopy
	move.w	MonPack,d0
	subq.w	#1,d0
	bsr	StrNum
	lea	TxtOthers,a0
	bsr	StrCopy
	bra.s	.said
.justOne:
	lea	TxtBang,a0
	bsr	StrCopy
.said:
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; CampRest : le groupe fait halte la ou il se trouve.
;
; La halte entre deux etages ne suffisait pas : les creatures arrivent
; en bande depuis peu, et le banc de jeu voyait le groupe tomber au
; deuxieme etage faute d'avoir jamais pu souffler. Camper rend la
; moitie des points de vie et tous les emplacements de sorts -- mais
; une halte sur trois est troublee, et ce qui rode a cet etage tombe
; alors sur un groupe qui n'a rien recupere.
CampRest:
	movem.l	d0-d7/a0-a6,-(sp)
	tst.w	InCombat
	bne.s	.leave
	tst.w	GameOver
	bne.s	.leave
	moveq	#3,d1
	bsr	RndMod
	tst.w	d0
	bne.s	.quiet
	lea	TxtCampBad,a0
	bsr	LogAdd
	bsr	WanderingFoe
	bra.s	.leave
.quiet:
	lea	TxtCamp,a0
	bsr	LogAdd
	bsr	PartyRest
.leave:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; WanderingFoe : une creature de cet etage, tiree dans sa table de
; rencontres.
WanderingFoe:
	movem.l	d0-d2/a0-a1,-(sp)
	lea	EncounterTab,a0
	move.w	Level,d0
	cmp.w	#NTIERS,d0
	blt.s	.lvOk
	moveq	#NTIERS-1,d0
.lvOk:
	lsl.w	#2,d0
	move.l	(a0,d0.w),a1
	moveq	#0,d1
	move.b	(a1)+,d1		; combien d'especes a cet etage
	bsr	RndMod
	moveq	#0,d1
	move.b	(a1,d0.w),d1
	move.w	d1,MonKind
	bsr	StartCombat
	movem.l	(sp)+,d0-d2/a0-a1
	rts

; FoeRollHp : a2 = type de creature -> MonHp et MonHpMax pour celle qui
; se presente. Chaque creature de la bande tire ses propres points de
; vie : la seconde n'est pas la copie de la premiere.
FoeRollHp:
	movem.l	d0-d1,-(sp)
	move.w	mt_Hd(a2),d0
	move.w	mt_HdF(a2),d1
	bsr	RollDice
	add.w	mt_HpB(a2),d0
	cmp.w	#1,d0
	bge.s	.hpOk
	moveq	#1,d0
.hpOk:
	move.w	d0,MonHp
	move.w	d0,MonHpMax
	movem.l	(sp)+,d0-d1
	rts

; HeroAttack : a6 = heros, a2 = monstre -> d0 = degats (0 si rate)
HeroAttack:
	movem.l	d1-d7/a0/a3,-(sp)
	tst.w	hr_Stun(a6)		; paralyse, ou trop effraye pour
	beq.s	.able			; lever son arme
	subq.w	#1,hr_Stun(a6)
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtStunned,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	moveq	#0,d7
	bra	.leave
.able:
	moveq	#0,d7			; degats
	move.w	hr_Weapon(a6),d0
	beq.s	.bare
	bsr	ItemPtr
	move.l	a0,a3
	move.w	it_Sfx(a3),d0
	cmp.w	#SFX_BOW,d0		; a l'arc, c'est la dexterite
	bne.s	.melee
	move.w	hr_Dex(a6),d0
	bra.s	.haveMod
.melee:
	move.w	hr_Str(a6),d0
	bra.s	.haveMod
.bare:
	lea	BareHands,a3
	move.w	hr_Str(a6),d0
.haveMod:
	bsr	StatMod
	move.w	d0,d6			; modificateur
	bsr	HeroBab
	moveq	#0,d3			; le BBA seul donne les attaques
	move.w	d0,d3
	subq.w	#1,d3
	bmi.s	.oneAttack
	divu.w	#5,d3
	and.l	#$0000ffff,d3
	bra.s	.haveAtk
.oneAttack:
	moveq	#0,d3
.haveAtk:
	move.w	d3,AtkMax
	add.w	d0,d6
	add.w	PartyBless,d6
	move.w	d6,d4			; bonus d'attaque total
	moveq	#0,d7
	moveq	#0,d2			; numero d'attaque
.attackLoop:
	bsr	D20
	move.w	d0,d5			; le de brut
	add.w	d4,d0
	cmp.w	#20,d5
	beq.s	.hit			; un 20 touche toujours
	cmp.w	mt_Ac(a2),d0
	blt	.next
.hit:
	move.w	it_Dice(a3),d0
	move.w	it_Faces(a3),d1
	bsr	RollDice
	add.w	it_Bonus(a3),d0
	move.w	d0,d1
	move.w	hr_Str(a6),d0
	bsr	StatMod
	add.w	d1,d0
	move.w	d0,d1			; degats de ce coup
	cmp.w	it_Crit(a3),d5		; dans la marge critique ?
	blt.s	.noCrit
	bsr	D20			; jet de confirmation
	add.w	d4,d0
	cmp.w	mt_Ac(a2),d0
	blt.s	.noCrit
	move.w	it_Mult(a3),d0		; degats multiplies
	subq.w	#1,d0
	move.w	d1,d3
.critLoop:
	tst.w	d0
	beq.s	.noCrit
	add.w	d3,d1
	subq.w	#1,d0
	bra.s	.critLoop
.noCrit:
	tst.w	d1
	bgt.s	.addDmg
	moveq	#1,d1
.addDmg:
	add.w	d1,d7
.next:
	addq.w	#1,d2			; attaque suivante : bonus reduit de 5
	sub.w	#5,d4
	cmp.w	AtkMax,d2		; une attaque de plus tous les +5 de BBA
	bgt.s	.done
	cmp.w	#4,d2			; quatre attaques au maximum
	blt	.attackLoop
.done:
	move.l	MonPtr,a0		; une peau epaisse retient chaque coup
	btst	#5,mt_Special+1(a0)	; SP_DR
	beq.s	.leave
	tst.w	d7
	beq.s	.leave
	sub.w	#MON_DR,d7
	bpl.s	.leave
	moveq	#0,d7
.leave:
	move.w	d7,d0
	movem.l	(sp)+,d1-d7/a0/a3
	rts

CombatRound:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	MonPtr,a2
	moveq	#0,d7			; degats du groupe
	moveq	#0,d4			; bruitage de la premiere arme
	moveq	#0,d3			; un heros a-t-il frappe
	lea	Heroes,a6
	moveq	#NHEROES-1,d6
.heroLoop:
	tst.w	hr_Hp(a6)
	beq	.heroNext
	tst.w	MonRange		; tant que la distance n'est pas
	beq.s	.inReach		; comblee, seul l'arc porte
	move.w	hr_Weapon(a6),d0
	beq	.heroNext		; a mains nues, on attend
	bsr	ItemPtr
	move.w	it_Sfx(a0),d0
	cmp.w	#SFX_BOW,d0
	bne	.heroNext
.inReach:
	tst.w	d3
	bne.s	.haveSfx
	moveq	#1,d3
	move.w	hr_Weapon(a6),d0
	beq.s	.bareSfx
	bsr	ItemPtr
	move.w	it_Sfx(a0),d4
	bra.s	.haveSfx
.bareSfx:
	moveq	#SFX_SWORD,d4
.haveSfx:
	bsr	HeroAttack
	add.w	d0,d7
.heroNext:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.heroLoop

	move.w	d4,d0
	bsr	SfxPlay
	tst.w	d7
	beq.s	.allMissed
	moveq	#SFX_HIT,d0
	bsr	SfxPlay
	sub.w	d7,MonHp
	lea	TmpStr,a1
	lea	TxtYouHit,a0
	bsr	StrCopy
	move.w	d7,d0
	bsr	StrNum
	lea	TxtDamage,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra.s	.check
.allMissed:
	moveq	#SFX_MISS,d0
	bsr	SfxPlay
	lea	TxtAllMiss,a0
	bsr	LogAdd
.check:
	tst.w	MonHp
	bgt.s	.monsterTurn
	bsr	MonsterDies
	bra.s	.done
.monsterTurn:
	bsr	MonsterTurn
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

MonsterTurn:
	movem.l	d0-d1/a0-a2,-(sp)
	move.l	MonPtr,a2
	btst	#4,mt_Special+1(a2)	; SP_REGEN : la chair se referme
	beq.s	.noRegen
	move.w	MonHpMax,d0
	cmp.w	MonHp,d0
	ble.s	.noRegen
	add.w	#MON_REGEN,MonHp
	cmp.w	MonHp,d0
	bge.s	.capped
	move.w	d0,MonHp
.capped:
	lea	TmpStr,a1
	move.l	a2,a0
	bsr	StrCopy
	lea	TxtRegen,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
.noRegen:
	; Le premier round se joue a distance : les archers et les
	; lanceurs de sorts ont une salve d'avance, ceux qui n'ont
	; qu'une lame attendent. Puis la bande comble le couloir. Un
	; rodeur dans le groupe cesse ainsi d'etre un guerrier en moins.
	tst.w	MonRange
	beq.s	.closed
	clr.w	MonRange
	lea	TxtCharge,a0
	bsr	LogAdd
	bra	.done
.closed:
	; Toute la bande riposte, pas seulement celle de devant : le
	; groupe ne frappe qu'un adversaire a la fois -- c'est un
	; couloir, pas une plaine -- mais il les a tous sur le dos.
	move.w	MonCount,d1
	subq.w	#1,d1
	bmi.s	.done
	tst.w	MonStun			; l'effroi ne saisit que celle de
	beq.s	.packLoop		; devant : les autres avancent
	clr.w	MonStun
	lea	TxtMonStunned,a0
	bsr	LogAdd
	dbf	d1,.packLoop
	bra.s	.done
.packLoop:
	tst.w	GameOver
	bne.s	.done
	tst.w	InCombat
	beq.s	.done
	bsr	MonsterAttack
	btst	#6,mt_Special+1(a2)	; SP_MULTI : elle frappe deux fois
	beq.s	.packNext
	tst.w	GameOver
	bne.s	.done
	bsr	MonsterAttack
.packNext:
	dbf	d1,.packLoop
.done:
	movem.l	(sp)+,d0-d1/a0-a2
	rts

MonsterAttack:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	MonPtr,a2
	moveq	#NHEROES,d1
	bsr	RndMod
	move.w	d0,d5
	moveq	#NHEROES-1,d6
.find:
	move.w	d5,d0
	bsr	HeroPtr
	tst.w	hr_Hp(a6)
	bne.s	.found
	addq.w	#1,d5
	and.w	#3,d5
	dbf	d6,.find
	bsr	PartyWiped
	bra	.done
.found:
	bsr	D20
	add.w	mt_Atk(a2),d0
	move.w	d0,d4
	bsr	HeroAc
	cmp.w	d0,d4
	bge.s	.hit
	moveq	#SFX_MISS,d0
	bsr	SfxPlay
	lea	TmpStr,a1
	move.l	a2,a0
	bsr	StrCopy
	lea	TxtMissed,a0
	bsr	StrCopy
	move.l	a6,a0
	bsr	StrCopy
	move.b	#'.',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra	.done
.hit:
	move.w	mt_Dice(a2),d0
	move.w	mt_Faces(a2),d1
	bsr	RollDice
	add.w	mt_Dmg(a2),d0		; force de la creature
	cmp.w	#1,d0			; au moins un point
	bge.s	.dmgOk
	moveq	#1,d0
.dmgOk:
	move.w	d0,d4
	moveq	#SFX_HIT,d0
	bsr	SfxPlay
	sub.w	d4,hr_Hp(a6)
	tst.w	hr_Hp(a6)
	bgt.s	.alive
	clr.w	hr_Hp(a6)
.alive:
	lea	TmpStr,a1
	move.l	a2,a0
	bsr	StrCopy
	lea	TxtHits,a0
	bsr	StrCopy
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtFor2,a0
	bsr	StrCopy
	move.w	d4,d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bsr	MonsterSpecial		; poison, paralysie, effroi, energie
	tst.w	hr_Hp(a6)
	bne.s	.checkParty
	moveq	#SFX_DEATH,d0
	bsr	SfxPlay
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtFalls,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
.checkParty:
	bsr	CheckWipe
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; MonsterSpecial : ce que la creature fait en plus de blesser
;   a2 = descripteur du monstre, a6 = le heros touche
;
; Chaque capacite se joue sur une sauvegarde du SRD : Vigueur contre ce
; qui attaque le corps, Volonte contre ce qui attaque l'esprit. Le
; degre suit les des de vie de la creature, comme dans les regles.
;----------------------------------------------------------------------
MonsterSpecial:
	movem.l	d0-d5/a0-a1,-(sp)
	tst.w	hr_Hp(a6)		; un heros a terre ne subit plus rien
	beq	.done
	move.w	mt_Special(a2),d5
	beq	.done
	move.w	mt_Hd(a2),d0		; DD = 10 + la moitie des des de vie
	lsr.w	#1,d0
	add.w	#10,d0
	move.w	d0,d4

	btst	#0,d5			; SP_POISON
	beq.s	.notPoison
	moveq	#0,d0			; Vigueur
	bsr	SpecialSave
	bne.s	.notPoison
	moveq	#1,d0
	moveq	#3,d1
	bsr	RollDice
	move.w	d0,d3
	move.w	hr_Str(a6),d2		; on ne descend jamais sous trois
	subq.w	#3,d2
	bpl.s	.floorOk
	moveq	#0,d2
.floorOk:
	cmp.w	d2,d3
	ble.s	.poisonOk
	move.w	d2,d3
.poisonOk:
	tst.w	d3
	beq.s	.notPoison
	sub.w	d3,hr_Str(a6)
	add.w	d3,hr_StrLoss(a6)
	lea	TxtPoisoned,a0
	bsr	SpecialLog
.notPoison:
	btst	#1,d5			; SP_PARALYSE
	beq.s	.notParalyse
	moveq	#0,d0			; Vigueur
	bsr	SpecialSave
	bne.s	.notParalyse
	moveq	#1,d1
	bsr	RndMod
	addq.w	#1,d0
	add.w	d0,hr_Stun(a6)
	lea	TxtParalysed,a0
	bsr	SpecialLog
.notParalyse:
	btst	#2,d5			; SP_DRAIN
	beq.s	.notDrain
	moveq	#2,d0			; Volonte
	bsr	SpecialSave
	bne.s	.notDrain
	moveq	#1,d0
	moveq	#4,d1
	bsr	RollDice
	move.w	d0,d3
	move.w	hr_HpMax(a6),d0		; on ne descend pas sous un point
	subq.w	#1,d0
	cmp.w	d0,d3
	ble.s	.drainOk
	move.w	d0,d3
.drainOk:
	sub.w	d3,hr_HpMax(a6)
	move.w	hr_HpMax(a6),d0
	cmp.w	hr_Hp(a6),d0
	bge.s	.hpOk
	move.w	d0,hr_Hp(a6)
.hpOk:
	lea	TxtDrained,a0
	bsr	SpecialLog
.notDrain:
	btst	#3,d5			; SP_FEAR
	beq.s	.done
	tst.w	hr_Stun(a6)		; deja fige : rien a ajouter
	bne.s	.done
	moveq	#2,d0			; Volonte
	bsr	SpecialSave
	bne.s	.done
	move.w	#1,hr_Stun(a6)
	lea	TxtAfraid,a0
	bsr	SpecialLog
.done:
	movem.l	(sp)+,d0-d5/a0-a1
	rts

; SpecialSave : d0 = type de sauvegarde, d4 = degre, a6 = heros
;            -> Z = 1 si le heros echoue
SpecialSave:
	movem.l	d1-d3,-(sp)
	bsr	HeroSave
	move.w	d0,d3
	bsr	D20
	add.w	d3,d0
	cmp.w	d4,d0
	movem.l	(sp)+,d1-d3
	bge.s	.made
	moveq	#0,d0			; rate : Z = 1
	tst.w	d0
	rts
.made:
	moveq	#1,d0
	tst.w	d0
	rts

; SpecialLog : a0 = ce qui arrive, a6 = a qui
SpecialLog:
	movem.l	d0/a0-a1,-(sp)
	move.l	a0,-(sp)
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	move.l	(sp)+,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	movem.l	(sp)+,d0/a0-a1
	rts

CheckWipe:
	movem.l	d0-d2/a0,-(sp)
	lea	Heroes,a0
	moveq	#NHEROES-1,d1
	moveq	#0,d2
.loop:
	tst.w	hr_Hp(a0)
	beq.s	.next
	addq.w	#1,d2
.next:
	lea	hr_SIZEOF(a0),a0
	dbf	d1,.loop
	tst.w	d2
	bne.s	.done
	bsr	PartyWiped
.done:
	movem.l	(sp)+,d0-d2/a0
	rts

PartyWiped:
	movem.l	d0,-(sp)
	move.w	#1,GameOver
	clr.w	InCombat
	lea	TxtWiped,a0
	bsr	LogAdd
	moveq	#LORE_LOST,d0		; la crypte a le dernier mot
	bsr	ShowLore
	movem.l	(sp)+,d0
	rts

; MonsterDies : celle de devant tombe. S'il en reste, une autre
; s'avance et le combat continue ; sinon il s'acheve.
MonsterDies:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	MonPtr,a2
	moveq	#SFX_DEATH,d0
	bsr	SfxPlay
	bsr	FoeReward		; or et experience, creature par
					; creature
	subq.w	#1,MonCount
	tst.w	MonCount
	ble.s	.lastOne
	bsr	FoeRollHp		; la suivante s'avance
	clr.w	MonRange		; et elle, elle est deja sur vous
	clr.w	MonStun
	clr.w	AnimFrame
	lea	TmpStr,a1
	lea	TxtAnother,a0
	bsr	StrCopy
	move.l	a2,a0
	bsr	StrCopy
	lea	TxtSteps,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	moveq	#SFX_GROWL,d0
	bsr	SfxPlay
	bra	.leave
.lastOne:
	clr.w	InCombat
	clr.w	MonCount
	cmp.w	#MON_BOSS,MonKind	; le gardien ne tombe qu'une fois
	bne.s	.ordinary
	move.w	#1,BossDead
	moveq	#SFX_LEVEL,d0
	bsr	SfxPlay
	lea	TxtGuardDown,a0
	bsr	LogAdd
.ordinary:
	move.w	PosX,d0			; la case est nettoyee
	move.w	PosY,d1
	bsr	MapCell
	move.w	d0,d2
	and.w	#$000f,d2
	move.w	PosX,d0
	move.w	PosY,d1
	bsr	MapSet
	lea	Heroes,a6		; bonus de fin de combat
	moveq	#NHEROES-1,d6
.blessLoop:
	clr.w	hr_AcTemp(a6)
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.blessLoop
.leave:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; FoeReward : a2 = type -> or, journal de combat et experience pour une
; creature abattue.
FoeReward:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	mt_Gold(a2),d0
	add.w	d0,Gold
	lea	TmpStr,a1
	move.l	a2,a0
	bsr	StrCopy
	lea	TxtDies,a0
	bsr	StrCopy
	move.w	mt_Xp(a2),d0
	bsr	StrNum
	lea	TxtXpGold,a0
	bsr	StrCopy
	move.w	mt_Gold(a2),d0
	bsr	StrNum
	lea	TxtGoldSuffix,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd

	lea	Heroes,a6		; l'experience va aux survivants
	moveq	#NHEROES-1,d6
.xpLoop:
	tst.w	hr_Hp(a6)
	beq.s	.xpNext
	move.w	mt_Xp(a2),d0
	add.w	d0,hr_Xp(a6)
	bsr	CheckLevel
.xpNext:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.xpLoop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

CheckLevel:				; a6 = heros
	movem.l	d0-d3/a0-a1,-(sp)
.again:
	move.w	hr_Level(a6),d0		; palier = 150 x n x (n+1) / 2
	cmp.w	#MAXCLEVEL,d0
	bge	.done
	move.w	d0,d1
	addq.w	#1,d1
	mulu.w	d1,d0
	lsr.l	#1,d0
	mulu.w	#150,d0
	cmp.w	hr_Xp(a6),d0
	bgt	.done
	addq.w	#1,hr_Level(a6)
	move.w	hr_Class(a6),d0
	mulu.w	#cl_SIZEOF,d0
	lea	ClassTable,a0
	add.l	d0,a0
	moveq	#1,d0			; un de de vie de plus
	move.w	cl_Hd(a0),d1
	bsr	RollDice
	move.w	d0,d3
	move.w	hr_Con(a6),d0
	bsr	StatMod
	add.w	d0,d3
	tst.w	d3
	bgt.s	.hpOk
	moveq	#1,d3
.hpOk:
	add.w	d3,hr_HpMax(a6)
	move.w	hr_HpMax(a6),hr_Hp(a6)
	bsr	FillSlots
	moveq	#SFX_LEVEL,d0
	bsr	SfxPlay
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtLevelUp,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra	.again
.done:
	movem.l	(sp)+,d0-d3/a0-a1
	rts

CombatFlee:
	movem.l	d0-d7/a0-a6,-(sp)
	moveq	#CLS_ROUBLARD,d0
	bsr	CountClass
	move.w	d1,d3
	mulu.w	#15,d3
	add.w	#50,d3
	cmp.w	#90,d3
	ble.s	.cap
	move.w	#90,d3
.cap:
	moveq	#100,d1
	bsr	RndMod
	cmp.w	d3,d0
	bge.s	.fail
	clr.w	InCombat
	lea	TxtFlee,a0
	bsr	LogAdd
	moveq	#-1,d2
	bsr	CellAhead
	move.w	d0,d4
	move.w	d1,d5
	bsr	MapCell
	bsr	IsSolid
	tst.w	d2
	bne.s	.done
	move.w	d4,PosX
	move.w	d5,PosY
	bra.s	.done
.fail:
	lea	TxtFleeFail,a0
	bsr	LogAdd
	bsr	MonsterTurn
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

CountClass:				; d0 = classe -> d1 = combien en vie
	movem.l	d0/d2/a0,-(sp)
	lea	Heroes,a0
	moveq	#NHEROES-1,d2
	moveq	#0,d1
.loop:
	tst.w	hr_Hp(a0)
	beq.s	.next
	cmp.w	hr_Class(a0),d0
	bne.s	.next
	addq.w	#1,d1
.next:
	lea	hr_SIZEOF(a0),a0
	dbf	d2,.loop
	movem.l	(sp)+,d0/d2/a0
	rts

;----------------------------------------------------------------------
; Sorts
;----------------------------------------------------------------------
CastSpell:				; d0 = sort
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	d0,d7
	move.w	SelHero,d0
	bsr	HeroPtr
	tst.w	hr_Hp(a6)
	beq	.cannot
	move.w	hr_Spells(a6),d0
	btst	d7,d0
	beq	.unknown
	move.w	d7,d0
	bsr	SpellPtr
	move.l	a0,a2
	tst.w	sp_Kind(a2)		; un sort d'attaque exige une cible
	bne.s	.hasTarget
	tst.w	InCombat
	beq	.noTarget
.hasTarget:
	move.w	sp_Level(a2),d6		; niveau de sort
	move.w	d6,d0
	add.w	d0,d0
	move.w	hr_Slots(a6,d0.w),d1
	tst.w	d1
	beq	.noSlot
	subq.w	#1,d1			; un emplacement de consomme
	move.w	d1,hr_Slots(a6,d0.w)
	subq.w	#1,hr_Mp(a6)

	moveq	#SFX_SPELL,d0
	bsr	SfxPlay
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtCasts,a0
	bsr	StrCopy
	move.l	a2,a0
	bsr	StrCopy
	move.b	#'.',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd

	move.w	hr_Level(a6),d5		; niveau de lanceur
	move.w	sp_Kind(a2),d4
	bne	.notDamage

	; --- degats : des selon le niveau de lanceur, plafonnes
	move.w	sp_Dice(a2),d0
	beq.s	.fixedDice
	mulu.w	d5,d0			; tant de des par niveau
	cmp.w	sp_Cap(a2),d0
	ble.s	.diceOk
	move.w	sp_Cap(a2),d0
	bra.s	.diceOk
.fixedDice:
	tst.w	sp_Plus(a2)
	beq.s	.capDice
	move.w	d5,d0			; projectiles : un de plus tous les
	addq.w	#1,d0			; deux niveaux
	lsr.w	#1,d0
	cmp.w	sp_Cap(a2),d0
	ble.s	.diceOk
	move.w	sp_Cap(a2),d0
	bra.s	.diceOk
.capDice:
	move.w	sp_Cap(a2),d0
.diceOk:
	tst.w	d0
	bne.s	.rollDmg
	moveq	#1,d0
.rollDmg:
	move.w	d0,d3			; nombre de des
	move.w	sp_Faces(a2),d1
	bsr	RollDice
	move.w	sp_Plus(a2),d1
	mulu.w	d3,d1
	add.w	d1,d0			; bonus par de (projectiles)
	move.w	d0,d3			; degats bruts

	tst.w	sp_Save(a2)		; le monstre peut-il resister ?
	beq.s	.noSave
	bsr	SpellDC
	move.w	d0,d2
	move.w	sp_Save(a2),d0
	bsr	MonsterSave
	tst.w	d0
	beq.s	.noSave
	tst.w	sp_Half(a2)
	beq.s	.resisted
	lsr.w	#1,d3			; sauvegarde reussie : moitie des degats
	lea	TxtHalfSave,a0
	bsr	LogAdd
	bra.s	.noSave
.resisted:
	lea	TxtResisted,a0
	bsr	LogAdd
	bra	.after
.noSave:
	sub.w	d3,MonHp
	lea	TmpStr,a1
	lea	TxtSpellHit,a0
	bsr	StrCopy
	move.w	d3,d0
	bsr	StrNum
	lea	TxtDamage,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra	.after

.notDamage:
	cmp.w	#1,d4
	bne.s	.notHeal
	move.w	d6,d0			; --- soin : un de par niveau de sort
	tst.w	d0
	bne.s	.healDice
	moveq	#1,d0
.healDice:
	move.w	sp_Faces(a2),d1
	bsr	RollDice
	move.w	d5,d1			; plus le niveau de lanceur, plafonne
	cmp.w	sp_Cap(a2),d1
	ble.s	.healCap
	move.w	sp_Cap(a2),d1
.healCap:
	add.w	d1,d0
	move.w	d0,d5
	bsr	HealWeakest
	bra	.after
.notHeal:
	cmp.w	#2,d4
	bne.s	.notShield
	lea	Heroes,a0		; --- armure : tout le groupe
	moveq	#NHEROES-1,d1
.shieldLoop:
	move.w	sp_Plus(a2),d2
	add.w	d2,hr_AcTemp(a0)
	lea	hr_SIZEOF(a0),a0
	dbf	d1,.shieldLoop
	lea	TxtShieldUp,a0
	bsr	LogAdd
	bra	.after
.notShield:
	cmp.w	#4,d4
	bne.s	.fear
	move.w	sp_Plus(a2),PartyBless	; --- benediction
	lea	TxtBlessed,a0
	bsr	LogAdd
	bra.s	.after
.fear:
	bsr	SpellDC			; --- terreur : jet de Volonte
	move.w	d0,d2
	moveq	#3,d0
	bsr	MonsterSave
	tst.w	d0
	beq.s	.feared
	lea	TxtResisted,a0
	bsr	LogAdd
	bra.s	.after
.feared:
	move.w	#1,MonStun
	lea	TxtFear,a0
	bsr	LogAdd
.after:
	tst.w	InCombat		; hors combat, personne ne riposte
	beq.s	.done
	tst.w	MonHp
	bgt.s	.monsterTurn
	bsr	MonsterDies
	bra.s	.done
.monsterTurn:
	bsr	MonsterTurn
	bra.s	.done
.unknown:
	lea	TxtUnknownSpell,a0
	bsr	LogAdd
	bra.s	.done
.noSlot:
	lea	TxtNoSlot,a0
	bsr	LogAdd
	bra.s	.done
.noTarget:
	lea	TxtNoTarget,a0
	bsr	LogAdd
	bra.s	.done
.cannot:
	lea	TxtHeroDown,a0
	bsr	LogAdd
.done:
	clr.w	UiMode
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; SpellDC : a6 = lanceur, a2 = sort -> d0 = degre de difficulte
; 10 + niveau du sort + modificateur de la caracteristique de lancement
SpellDC:
	movem.l	d1-d2,-(sp)
	bsr	CastMod
	add.w	sp_Level(a2),d0
	add.w	#10,d0
	movem.l	(sp)+,d1-d2
	rts

; MonsterSave : d0 = type (1 Vig, 2 Ref, 3 Vol), d2 = DD
;               -> d0 = 1 si le monstre resiste
MonsterSave:
	movem.l	d1-d3/a0-a2,-(sp)
	move.l	MonPtr,a2
	lea	mt_Fort(a2),a0
	subq.w	#1,d0
	add.w	d0,d0
	move.w	(a0,d0.w),d3		; bonus de sauvegarde
	bsr	D20
	add.w	d3,d0
	cmp.w	d2,d0
	bge.s	.saved
	moveq	#0,d0
	bra.s	.done
.saved:
	moveq	#1,d0
.done:
	movem.l	(sp)+,d1-d3/a0-a2
	rts

HealWeakest:				; d5 = points rendus
	movem.l	d0-d7/a0-a6,-(sp)
	lea	Heroes,a6
	moveq	#NHEROES-1,d6
	move.l	a6,a5
	moveq	#-1,d4
	moveq	#0,d7
.pick:
	tst.w	hr_HpMax(a6)		; un heros a terre reste soignable
	beq.s	.next
	move.w	hr_HpMax(a6),d0
	sub.w	hr_Hp(a6),d0
	cmp.w	d4,d0
	ble.s	.next
	move.w	d0,d4
	move.l	a6,a5
	moveq	#1,d7
.next:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.pick
	tst.w	d7
	beq.s	.done
	move.l	a5,a6
	moveq	#0,d3
	tst.w	hr_Hp(a6)
	bne.s	.wasUp
	moveq	#1,d3
.wasUp:
	add.w	d5,hr_Hp(a6)
	move.w	hr_HpMax(a6),d0
	cmp.w	hr_Hp(a6),d0
	bge.s	.capped
	move.w	d0,hr_Hp(a6)
.capped:
	tst.w	d3			; il etait a terre : il se releve
	beq.s	.notRaised
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtRaised,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
.notRaised:
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtHealed,a0
	bsr	StrCopy
	move.w	d5,d0
	bsr	StrNum
	lea	TxtPvSuffix,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Actions du sac : equiper, utiliser, jeter
;----------------------------------------------------------------------
InvItem:				; -> d0 = objet sous le curseur, Z si vide
	movem.l	d1/a0,-(sp)
	lea	Inventory,a0
	move.w	InvCursor,d1
	moveq	#0,d0
	move.b	(a0,d1.w),d0
	movem.l	(sp)+,d1/a0
	tst.w	d0
	rts

InvClear:				; vide la case sous le curseur
	movem.l	d0-d1/a0-a1,-(sp)
	lea	Inventory,a0
	move.w	InvCursor,d1
	lea	(a0,d1.w),a0		; le sac se retasse : pas de trou
	lea	1(a0),a1		; sous le curseur, sinon la ligne
	move.w	#INVSIZE-1,d0		; disparait de la liste
	sub.w	d1,d0
	subq.w	#1,d0
	bmi.s	.last
.shift:
	move.b	(a1)+,(a0)+
	dbf	d0,.shift
.last:
	clr.b	(a0)
	movem.l	(sp)+,d0-d1/a0-a1
	rts

EquipItem:
	movem.l	d0-d7/a0-a6,-(sp)
	bsr	InvItem
	beq	.done
	move.w	d0,d7
	bsr	ItemPtr
	move.l	a0,a2
	move.w	SelHero,d0
	bsr	HeroPtr
	tst.w	hr_Hp(a6)
	beq	.done
	move.w	it_Type(a2),d0
	bne.s	.notWeapon
	move.w	hr_Weapon(a6),d6	; l'ancienne arme retourne au sac
	move.w	d7,hr_Weapon(a6)
	bra.s	.swap
.notWeapon:
	cmp.w	#IT_ARMOR,d0
	bne.s	.notArmor
	move.w	hr_Armor(a6),d6
	move.w	d7,hr_Armor(a6)
	bra.s	.swap
.notArmor:
	cmp.w	#IT_SHIELD,d0
	bne	.cannot
	move.w	hr_Shield(a6),d6
	move.w	d7,hr_Shield(a6)
.swap:
	bsr	InvClear
	tst.w	d6
	beq.s	.noOld
	move.w	d6,d0
	bsr	AddItem
.noOld:
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtEquips,a0
	bsr	StrCopy
	move.l	a2,a0
	bsr	StrCopy
	move.b	#'.',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra.s	.done
.cannot:
	lea	TxtCannotEquip,a0
	bsr	LogAdd
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

UseItem:
	movem.l	d0-d7/a0-a6,-(sp)
	bsr	InvItem
	beq	.done
	move.w	d0,d7
	bsr	ItemPtr
	move.l	a0,a2
	move.w	SelHero,d0
	bsr	HeroPtr
	move.w	it_Type(a2),d0
	cmp.w	#IT_POTION,d0
	beq.s	.potion
	cmp.w	#IT_SCROLL,d0
	beq	.scroll
	lea	TxtCannotUse,a0
	bsr	LogAdd
	bra	.done
.potion:
	move.w	it_Dice(a2),d0
	move.w	it_Faces(a2),d1
	bsr	RollDice
	add.w	it_Bonus(a2),d0
	move.w	d0,d5
	moveq	#CLS_CLERC,d0		; un clerc tire plus des potions
	bsr	CountClass
	move.w	d1,d0
	mulu.w	#3,d0
	add.w	d0,d5
	bsr	HealWeakest
	moveq	#SFX_POTION,d0
	bsr	SfxPlay
	bsr	InvClear
	bra	.done
.scroll:
	tst.w	hr_MpMax(a6)
	beq.s	.noMagic
	move.w	it_Dice(a2),d6		; numero du sort
	move.w	hr_Spells(a6),d0
	btst	d6,d0
	bne.s	.known
	bset	d6,d0
	move.w	d0,hr_Spells(a6)
	moveq	#SFX_SPELL,d0
	bsr	SfxPlay
	bsr	InvClear
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtLearns,a0
	bsr	StrCopy
	move.w	d6,d0
	bsr	SpellPtr
	bsr	StrCopy
	move.b	#'.',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra.s	.done
.known:
	lea	TxtAlreadyKnown,a0
	bsr	LogAdd
	bra.s	.done
.noMagic:
	lea	TxtNoMagic,a0
	bsr	LogAdd
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

DropItem:
	movem.l	d0-d7/a0-a6,-(sp)
	bsr	InvItem
	beq.s	.done
	move.w	d0,d7
	bsr	ItemPtr
	cmp.w	#IT_KEY,it_Type(a0)
	bne.s	.notKey
	tst.w	KeyCount
	beq.s	.notKey
	subq.w	#1,KeyCount
.notKey:
	bsr	InvClear
	move.w	d7,d0
	lea	TxtDrops,a0
	bsr	LogItem
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Touches, selon l'ecran ouvert
;----------------------------------------------------------------------
HandleKey:
	movem.l	d1-d7/a0-a6,-(sp)
	cmp.w	#KEY_ESC,d0
	bne.s	.notEsc
	tst.w	UiMode
	beq.s	.quit
	clr.w	UiMode
	bra	.redraw
.quit:
	tst.w	QuitArm			; une seule touche ne doit pas effacer
	bne.s	.reallyQuit		; une partie entiere
	move.w	#1,QuitArm
	lea	TxtConfirmQuit,a0
	bsr	LogAdd
	bra	.redraw
.reallyQuit:
	bsr	SaveGame		; on ne perd pas la partie en sortant
	move.w	#1,Quit
	bra	.done
.notEsc:
	clr.w	QuitArm
	tst.w	GameOver
	bne	.done

	move.w	UiMode,d1		; --- reponse a une enigme
	cmp.w	#UI_RIDDLE,d1
	bne.s	.notRiddleUi
	move.w	d0,d2
	sub.w	#KEY_1,d2
	bmi	.done
	cmp.w	#3,d2
	bge	.done
	move.w	d2,d0
	bsr	AnswerRiddle
	bra	.done
.notRiddleUi:
	cmp.w	#UI_SPELL,d1		; --- choix d'un sort
	bne.s	.notSpellUi
	move.w	d0,d2
	sub.w	#KEY_1,d2
	bmi	.done
	cmp.w	#SPELLMENU,d2
	bge	.done
	bsr	BuildSpellMenu
	cmp.w	SpellCount,d2
	bge	.done
	add.w	d2,d2
	lea	SpellList,a0
	move.w	(a0,d2.w),d0
	bsr	CastSpell
	bra	.done
.notSpellUi:
	move.w	d0,d2			; 1 a 4 : heros courant
	sub.w	#KEY_1,d2
	bmi.s	.notHero
	cmp.w	#NHEROES,d2
	bge.s	.notHero
	move.w	d2,SelHero
	bra	.redraw
.notHero:
	cmp.w	#KEY_C,d0		; fiche d'aventure
	bne.s	.notSheet
	move.w	#UI_SHEET,d1
	cmp.w	UiMode,d1
	bne.s	.openSheet
	clr.w	UiMode
	bra	.redraw
.openSheet:
	move.w	#UI_SHEET,UiMode
	bra	.redraw
.notSheet:
	cmp.w	#KEY_I,d0		; sac a dos
	bne.s	.notInv
	move.w	#UI_INV,d1
	cmp.w	UiMode,d1
	bne.s	.openInv
	clr.w	UiMode
	bra	.redraw
.openInv:
	move.w	#UI_INV,UiMode
	bra	.redraw
.notInv:
	cmp.w	#KEY_L,d0		; grimoire
	bne.s	.notBookKey
	move.w	#UI_BOOK,d1
	cmp.w	UiMode,d1
	bne.s	.openBook
	clr.w	UiMode
	bra	.redraw
.openBook:
	move.w	#UI_BOOK,UiMode
	bra	.redraw
.notBookKey:
	cmp.w	#KEY_P,d0		; reglages
	bne.s	.notOptsKey
	move.w	#UI_OPTS,d1
	cmp.w	UiMode,d1
	bne.s	.openOpts
	clr.w	UiMode
	bra	.redraw
.openOpts:
	move.w	#UI_OPTS,UiMode
	bra	.redraw
.notOptsKey:
	move.w	UiMode,d1		; ces ecrans ont leurs propres fleches
	cmp.w	#UI_LORE,d1
	bne.s	.notInLore
	cmp.w	#KEY_SPACE,d0		; une page se referme d'un espace
	bne	.done
	clr.w	UiMode
	bra	.redraw
.notInLore:
	cmp.w	#UI_SHOP,d1
	bne.s	.notInShop
	bsr	ShopKey
	bra	.done
.notInShop:
	cmp.w	#UI_BOOK,d1
	bne.s	.notInBook
	bsr	BookKey
	bra	.done
.notInBook:
	cmp.w	#UI_OPTS,d1
	bne.s	.notInOpts
	bsr	OptKey
	bra	.done
.notInOpts:
	cmp.w	#KEY_M_QW,d0		; carte du niveau
	beq.s	.mapKey
	cmp.w	#KEY_M_AZ,d0
	bne.s	.notMapKey
.mapKey:
	move.w	#UI_MAP,d1
	cmp.w	UiMode,d1
	bne.s	.openMap
	clr.w	UiMode
	bra	.redraw
.openMap:
	move.w	#UI_MAP,UiMode
	bra	.redraw
.notMapKey:
	move.w	UiMode,d1
	cmp.w	#UI_INV,d1
	beq	.invKeys
	tst.w	d1
	bne	.done			; fiche ouverte : rien d'autre

	tst.w	InCombat
	bne	.fight

	cmp.w	#KEY_UP,d0		; --- exploration
	bne.s	.notUp
	moveq	#1,d1
	bsr	TryMove
	bra	.done
.notUp:
	cmp.w	#KEY_DOWN,d0
	bne.s	.notDown
	moveq	#-1,d1
	bsr	TryMove
	bra	.done
.notDown:
	cmp.w	#KEY_LEFT,d0
	bne.s	.notLeft
	move.w	Dir,d1
	subq.w	#1,d1
	and.w	#3,d1
	move.w	d1,Dir
	bra	.redraw
.notLeft:
	cmp.w	#KEY_RIGHT,d0
	bne.s	.notRight
	move.w	Dir,d1
	addq.w	#1,d1
	and.w	#3,d1
	move.w	d1,Dir
	bra	.redraw
.notRight:
	cmp.w	#KEY_S,d0		; sorts hors combat : soins, protections
	bne.s	.notCast
	move.w	#UI_SPELL,UiMode
	bra	.redraw
.notCast:
	cmp.w	#KEY_R,d0		; camper sur place
	bne.s	.notCamp
	bsr	CampRest
	bra	.done
.notCamp:
	cmp.w	#KEY_SPACE,d0
	bne	.done
	bsr	DoAction
	bra	.done

.fight:					; --- combat
	cmp.w	#KEY_A_QW,d0
	beq.s	.attack
	cmp.w	#KEY_A_AZ,d0
	beq.s	.attack
	cmp.w	#KEY_SPACE,d0
	beq.s	.attack
	cmp.w	#KEY_F,d0
	beq.s	.flee
	cmp.w	#KEY_S,d0
	bne	.done
	move.w	#UI_SPELL,UiMode
	bra	.redraw
.attack:
	bsr	CombatRound
	bra	.done
.flee:
	bsr	CombatFlee
	bra	.done

.invKeys:				; --- sac a dos
	cmp.w	#KEY_UP,d0
	bne.s	.notInvUp
	move.w	InvCursor,d1
	subq.w	#1,d1
	bpl.s	.setCursor
	moveq	#0,d1
	bra.s	.setCursor
.notInvUp:
	cmp.w	#KEY_DOWN,d0
	bne.s	.notInvDown
	move.w	InvCursor,d1
	addq.w	#1,d1
	cmp.w	#INVSIZE,d1
	blt.s	.setCursor
	move.w	#INVSIZE-1,d1
.setCursor:
	move.w	d1,InvCursor
	move.w	InvTop,d2		; garder le curseur visible
	cmp.w	d2,d1
	bge.s	.notAbove
	move.w	d1,InvTop
	bra	.redraw
.notAbove:
	sub.w	d2,d1
	cmp.w	#8,d1
	blt	.redraw
	move.w	InvCursor,d1
	sub.w	#7,d1
	move.w	d1,InvTop
	bra	.redraw
.notInvDown:
	cmp.w	#KEY_E,d0
	bne.s	.notEquip
	bsr	EquipItem
	bra	.done
.notEquip:
	cmp.w	#KEY_U,d0
	bne.s	.notUse
	bsr	UseItem
	bra	.done
.notUse:
	cmp.w	#KEY_D,d0
	bne	.done
	bsr	DropItem
	bra	.done
.redraw:
	move.w	#1,NeedRedraw
.done:
	movem.l	(sp)+,d1-d7/a0-a6
	rts

; --- replayer ProTracker, dans la meme section de code ---
PT_SCORE	= 1			; musique heroique du donjon
	include	"ptreplay.i"

;======================================================================
	SECTION	crawldata,DATA
;======================================================================

GfxName:	dc.b	"graphics.library",0
	even

	include	"dgnpal.i"
	include	"font8.i"
	even
	include	"tables.i"
	even

BareHands:				; "objet" des poings nus
	dc.b	"POINGS",0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,1,3,0,0,0

DirTable:
	dc.w	0,-1
	dc.w	1,0
	dc.w	0,1
	dc.w	-1,0

SaveName:	dc.b	"PROGDIR:AGACrawl.sav",0
DosName:	dc.b	"dos.library",0
	even

; Les pieges : nom (16 octets), sauvegarde qui sauve, faces du de.
; Les degats montent d'un de par etage.
TrapTable:
	dc.b	"JET DE DARDS",0,0,0,0
	dc.w	1,6
	dc.b	"LAME DE FAUX",0,0,0,0
	dc.w	1,8
	dc.b	"FOSSE A PIEUX",0,0,0
	dc.w	1,6
	dc.b	"NUAGE ACIDE",0,0,0,0,0
	dc.w	0,4

; L'etal du marchand, un par etage : huit numeros d'objet dans
; ItemTable. Le prix est celui de l'objet ; il rachete a moitie.
ShopTable:
	dc.b	17,17,13,16,2,20,25,8	; potions, cuir, bouclier, cle
	dc.b	17,17,13,16,4,20,21,25	; hache, parchemins
	dc.b	17,18,14,3,6,22,21,26	; mailles, epee longue
	dc.b	18,18,14,5,16,22,23,26	; hache de guerre, argent
	dc.b	18,18,15,9,10,11,24,23	; harnois et lames enchantees
	even


; Le journal. Un donjon sans recit n'est qu'un couloir : ces
; pages racontent la crypte a mesure qu'on descend, comme les
; paragraphes numerotes des jeux dont celui-ci descend. Le
; decoupage est fait a la generation, jamais compte a la main :
; le panneau ne tient que 23 colonnes, pas les 36 du journal.
LoreTable:
	dc.l	Lore0
	dc.l	Lore1
	dc.l	Lore2
	dc.l	Lore3
	dc.l	Lore4
	dc.l	Lore5
	dc.l	Lore6
	dc.l	Lore7
	dc.l	Lore8
	dc.l	Lore9
	dc.l	Lore10
NLORE		= 11

Lore0:
	dc.b	"LA CRYPTE",0
	dc.b	"Il y a trois cents ans,",0
	dc.b	"la maison de Faerghail",0
	dc.b	"scella sous sa chapelle",0
	dc.b	"ce qu'elle n'osait pas",0
	dc.b	"detruire.",0
	dc.b	"",0
	dc.b	"Depuis un an, les betes",0
	dc.b	"remontent. Le village a",0
	dc.b	"paye quatre epees.",0
	dc.b	"Vous.",0
	dc.b	"",0
	dc.b	"Cinq etages. Descendez.",0
	even
Lore1:
	dc.b	"VOUS REVOYEZ LE JOUR",0
	dc.b	"Le gardien tombe, et le",0
	dc.b	"silence qui suit est le",0
	dc.b	"premier depuis trois",0
	dc.b	"cents ans.",0
	dc.b	"",0
	dc.b	"Vous remontez sans",0
	dc.b	"croiser une ombre. La",0
	dc.b	"crypte se tait enfin.",0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	even
Lore2:
	dc.b	"LA CRYPTE VOUS GARDE",0
	dc.b	"Le dernier d'entre vous",0
	dc.b	"tombe la ou les autres",0
	dc.b	"sont deja couches.",0
	dc.b	"",0
	dc.b	"La crypte ne rend rien.",0
	dc.b	"Dans un an, le village",0
	dc.b	"paiera quatre autres",0
	dc.b	"epees.",0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	even
Lore3:
	dc.b	"PREMIERE STELE",0
	dc.b	"Ici commence la",0
	dc.b	"descente.",0
	dc.b	"",0
	dc.b	"Nous avons mure la",0
	dc.b	"chapelle et brise",0
	dc.b	"l'escalier.",0
	dc.b	"",0
	dc.b	"Ordre de Faerghail, an",0
	dc.b	"212",0
	dc.b	0
	dc.b	0
	dc.b	0
	even
Lore4:
	dc.b	"PLAINTE D'UN TAILLEUR",0
	dc.b	"Trente hommes ont",0
	dc.b	"creuse. Dix-sept sont",0
	dc.b	"remontes.",0
	dc.b	"",0
	dc.b	"Le maitre dit que le",0
	dc.b	"fond n'est pas de la",0
	dc.b	"roche.",0
	dc.b	"",0
	dc.b	"Je ne descendrai plus.",0
	dc.b	0
	dc.b	0
	dc.b	0
	even
Lore5:
	dc.b	"DEUXIEME STELE",0
	dc.b	"Les leviers commandent",0
	dc.b	"les herses. Ceux qui",0
	dc.b	"les ont scelles",0
	dc.b	"voulaient qu'on ferme",0
	dc.b	"derriere soi.",0
	dc.b	"",0
	dc.b	"Contre quoi, nul ne l'a",0
	dc.b	"dit.",0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	even
Lore6:
	dc.b	"REGISTRE DES OFFRANDES",0
	dc.b	"Aux niches : du pain,",0
	dc.b	"du sel, une piece. On",0
	dc.b	"les trouvait vides au",0
	dc.b	"matin.",0
	dc.b	"",0
	dc.b	"Le chapelain disait que",0
	dc.b	"c'etaient les rats. Il",0
	dc.b	"n'est plus la pour le",0
	dc.b	"dire.",0
	dc.b	0
	dc.b	0
	dc.b	0
	even
Lore7:
	dc.b	"TROISIEME STELE",0
	dc.b	"Ne lisez pas les runes",0
	dc.b	"a voix haute.",0
	dc.b	"",0
	dc.b	"Elles posent une",0
	dc.b	"question et attendent.",0
	dc.b	"Repondez juste, la",0
	dc.b	"porte s'ouvre.",0
	dc.b	"",0
	dc.b	"Repondez faux, elle",0
	dc.b	"vous repond.",0
	dc.b	0
	dc.b	0
	even
Lore8:
	dc.b	"LETTRE, NON ENVOYEE",0
	dc.b	"Mere, il y a un",0
	dc.b	"marchand ici. Sous",0
	dc.b	"terre. Il tient",0
	dc.b	"boutique et prend notre",0
	dc.b	"or.",0
	dc.b	"",0
	dc.b	"Nul ne demande d'ou il",0
	dc.b	"vient : on a trop",0
	dc.b	"besoin de ses potions.",0
	dc.b	0
	dc.b	0
	dc.b	0
	even
Lore9:
	dc.b	"QUATRIEME STELE",0
	dc.b	"Au-dela, la pierre est",0
	dc.b	"chaude.",0
	dc.b	"",0
	dc.b	"Nous avons cesse de",0
	dc.b	"tailler. Ce qui reste a",0
	dc.b	"creuser, quelque chose",0
	dc.b	"l'a deja creuse.",0
	dc.b	"",0
	dc.b	"An 219",0
	dc.b	0
	dc.b	0
	dc.b	0
	even
Lore10:
	dc.b	"DERNIERE PAGE",0
	dc.b	"Il ne dort pas. Il",0
	dc.b	"attend.",0
	dc.b	"",0
	dc.b	"Nous lui avons donne",0
	dc.b	"l'escalier pour qu'il",0
	dc.b	"ait quelque chose a",0
	dc.b	"garder.",0
	dc.b	"",0
	dc.b	"Si vous lisez ceci,",0
	dc.b	"Faerghail a echoue. A",0
	dc.b	"vous.",0
	dc.b	0
	even

; Les panneaux en liste, pour la souris : ecran, premiere ligne, pas,
; nombre de lignes visibles, curseur, premiere ligne affichee, et la
; touche qu'un second clic sur la meme ligne envoie.
ph_Mode		= 0
ph_First	= 2
ph_Step		= 4
ph_Count	= 6
ph_Cursor	= 8
ph_Top		= 12
ph_Key		= 16
ph_SIZEOF	= 20

PanelHit:
	dc.w	UI_INV,34,11,8
	dc.l	InvCursor,InvTop
	dc.w	KEY_U,0
	dc.w	UI_SHOP,34,11,SHOPROWS
	dc.l	ShopCursor,ShopTop
	dc.w	KEY_RETURN,0
	dc.w	UI_BOOK,32,10,BOOKROWS
	dc.l	BookCursor,BookTop
	dc.w	0,0
	dc.w	UI_OPTS,44,18,OPTROWS
	dc.l	OptCursor,ZeroWord
	dc.w	KEY_RETURN,0
	dc.w	0,0,0,0
	dc.l	0,0
	dc.w	0,0
ZeroWord:	dc.w	0

; Ce qu'une partie contient : adresse et longueur de chaque bloc.
SaveList:
	dc.l	PosX,12			; PosX, PosY, Dir, Level, Gold, KeyCount
	dc.l	Heroes,NHEROES*hr_SIZEOF
	dc.l	Inventory,INVSIZE
	dc.l	MapTerrain,MAPBYTES
	dc.l	MapParam,MAPBYTES
	dc.l	MapSeen,MAPBYTES
	dc.l	ShopStock,NSHOP
	dc.l	BossDead,2
	dc.l	0,0

	include	"surfgrad.i"

OptNames:
	dc.l	TxtOptMusic,TxtOptSfx,TxtOptKb,TxtOptSave,TxtOptTitleBack

SchoolNames:				; 1 profane, 2 divin, 3 les deux
	dc.l	TxtSchoolArc,TxtSchoolDiv,TxtSchoolBoth

KindNames:				; l'effet du sort, dans l'ordre sp_Kind
	dc.l	TxtKindDmg,TxtKindHeal,TxtKindWard,TxtKindFear,TxtKindBless

SaveNames:				; 1 Vigueur, 2 Reflexes, 3 Volonte
	dc.l	TxtSaveFort,TxtSaveRef,TxtSaveWill

DirNames:
	dc.l	TxtNord,TxtEst,TxtSud,TxtOuest

; legende de la carte : texte, colonne, ligne, couleur, remplissage
LegendTab:
	dc.l	TxtLegDoor
	dc.b	3,130,6,0
	dc.l	TxtLegRune
	dc.b	9,130,10,0
	dc.l	TxtLegShut
	dc.b	14,130,9,0
	dc.l	TxtLegYou
	dc.b	21,130,15,0
	dc.l	TxtLegStairs
	dc.b	3,140,14,0
	dc.l	TxtLegMonster
	dc.b	12,140,3,0

ClassDesc:
	dc.l	TxtCls0,TxtCls1,TxtCls2,TxtCls3
	dc.l	TxtCls4,TxtCls5,TxtCls6,TxtCls7

RiddleTable:				; trois lignes, trois reponses, la bonne
	dc.l	TxtR0Q1,TxtR0Q2,TxtR0Q3,TxtR0A1,TxtR0A2,TxtR0A3
	dc.w	0,0
	dc.l	TxtR1Q1,TxtR1Q2,TxtR1Q3,TxtR1A1,TxtR1A2,TxtR1A3
	dc.w	1,0
	dc.l	TxtR2Q1,TxtR2Q2,TxtR2Q3,TxtR2A1,TxtR2A2,TxtR2A3
	dc.w	1,0
StatNames:
	dc.l	TxtFor,TxtDex,TxtCon,TxtInt,TxtSag,TxtCha
StatOffsets:
	dc.w	hr_Str,hr_Dex,hr_Con,hr_Int,hr_Wis,hr_Cha

TxtCls0:	dc.b	"SOLIDE, FRAPPE FORT",0
TxtCls1:	dc.b	"TRES ROBUSTE, BRUTAL",0
TxtCls2:	dc.b	"AGILE, FUIT PLUS VITE",0
TxtCls3:	dc.b	"ARC ET SORTS DES BOIS",0
TxtCls4:	dc.b	"LA LAME ET LA FOI",0
TxtCls5:	dc.b	"SOINS ET SORTS DIVINS",0
TxtCls6:	dc.b	"FRAGILE, MAGIE VASTE",0
TxtCls7:	dc.b	"MAGIE INNEE ET CHARME",0
TxtFor:		dc.b	"FOR ",0
TxtDex:		dc.b	"DEX ",0
TxtCon:		dc.b	"CON ",0
TxtInt:		dc.b	"INT ",0
TxtSag:		dc.b	"SAG ",0
TxtCha:		dc.b	"CHA ",0

TxtIntro:	dc.b	"LA CRYPTE DE FAERGHAIL VOUS ATTEND.",0
TxtCreate1:	dc.b	"CREEZ VOS QUATRE AVENTURIERS.",0
TxtCreate2:	dc.b	"CHAQUE CLASSE A SES FORCES.",0
TxtCreateTitle:	dc.b	"CREATION DU GROUPE",0
TxtEmptySlot:	dc.b	"-----",0
TxtHero:	dc.b	"HEROS ",0
TxtOn4:		dc.b	" SUR 4",0
TxtDash:	dc.b	" - ",0
TxtHyphen:	dc.b	"-",0
TxtNivShort:	dc.b	"N",0
TxtPickClass:	dc.b	"FLECHES, ENTREE OU 1-8",0
TxtRoll:	dc.b	"R RELANCER  ENTREE OK",0
TxtName:	dc.b	"NOM : ",0
TxtNameHelp:	dc.b	"TAPEZ OU FLECHES",0
TxtAzerty:	dc.b	"TAB : AZERTY",0
TxtQwerty:	dc.b	"TAB : QWERTY",0
TxtWall:	dc.b	"UN MUR BLOQUE LE PASSAGE.",0
TxtDoorShut:	dc.b	"PORTE FERMEE. ESPACE POUR OUVRIR.",0
TxtDoorOpen:	dc.b	"LA PORTE S'OUVRE EN GRINCANT.",0
TxtLocked:	dc.b	"CETTE PORTE EST VERROUILLEE.",0
TxtNeedKey:	dc.b	"IL VOUS FAUT UNE CLE.",0
TxtUnlock:	dc.b	"LA CLE TOURNE. LA PORTE CEDE.",0
TxtNothing:	dc.b	"RIEN A FAIRE ICI.",0
TxtNiche:	dc.b	"DANS LA NICHE : ",0
TxtNicheEmpty:	dc.b	"LA NICHE EST VIDE.",0
TxtChest:	dc.b	"UN COFFRE ! ",0
TxtGoldSuffix:	dc.b	" OR.",0
TxtFound:	dc.b	"VOUS TROUVEZ ",0
TxtDrops:	dc.b	"VOUS JETEZ ",0
TxtBagFull:	dc.b	"LE SAC EST PLEIN.",0
TxtDescend:	dc.b	"UN ESCALIER. VOUS DESCENDEZ.",0
TxtWin:		dc.b	"LA SORTIE ! VOUS REVOYEZ LE JOUR.",0
TxtAppears:	dc.b	"UN ",0
TxtBang:	dc.b	" SURGIT !",0
TxtAndMore:	dc.b	" SURGIT, ET ",0
TxtOthers:	dc.b	" AUTRES !",0
TxtAnother:	dc.b	"UN AUTRE ",0
TxtTimes:	dc.b	" X",0
TxtSteps:	dc.b	" S'AVANCE !",0
TxtCharge:	dc.b	"ILS COMBLENT LA DISTANCE.",0
TxtFar:		dc.b	" AU LOIN",0
TxtYouHit:	dc.b	"LE GROUPE INFLIGE ",0
TxtDamage:	dc.b	" DEGATS.",0
TxtAllMiss:	dc.b	"TOUS LES COUPS SE PERDENT.",0
TxtHits:	dc.b	" TOUCHE ",0
TxtFor2:	dc.b	" : ",0
TxtMissed:	dc.b	" MANQUE ",0
TxtFalls:	dc.b	" S'EFFONDRE !",0
TxtDies:	dc.b	" TOMBE ! +",0
TxtXpGold:	dc.b	" PX, ",0
TxtLevelUp:	dc.b	" PASSE UN NIVEAU !",0
TxtFlee:	dc.b	"VOUS PRENEZ LA FUITE.",0
TxtFleeFail:	dc.b	"LA FUITE ECHOUE !",0
TxtWiped:	dc.b	"LE GROUPE EST ANEANTI.",0
TxtMonStunned:	dc.b	"LE MONSTRE RECULE, TERRIFIE.",0
TxtCasts:	dc.b	" LANCE ",0
TxtSpellHit:	dc.b	"LE SORT INFLIGE ",0
TxtHealed:	dc.b	" RECUPERE ",0
TxtPvSuffix:	dc.b	" PV.",0
TxtStunned:	dc.b	" NE PEUT PAS BOUGER.",0
TxtPoisoned:	dc.b	" EST EMPOISONNE.",0
TxtParalysed:	dc.b	" EST PARALYSE !",0
TxtDrained:	dc.b	" SENT SA VIE S'EN ALLER.",0
TxtAfraid:	dc.b	" RECULE, TERRIFIE.",0
TxtRegen:	dc.b	" SE REFERME.",0
TxtGuardian:	dc.b	"UNE PRESENCE BARRE LA SORTIE.",0
TxtGuardDown:	dc.b	"LE GARDIEN TOMBE. LA VOIE EST LIBRE.",0
TxtCured:	dc.b	"LE REPOS CHASSE LE POISON.",0
TxtShopSeen:	dc.b	"UNE ECHOPPE ! ESPACE POUR ENTRER.",0
TxtSteleSeen:	dc.b	"UNE STELE GRAVEE. ESPACE POUR LIRE.",0
TxtLoreHelp:	dc.b	"ESPACE OU ESC POUR REFERMER",0
TxtShopHello:	dc.b	"BIENVENUE, DIT LE MARCHAND.",0
TxtShopTitle:	dc.b	"ECHOPPE",0
TxtShopBuy:	dc.b	"ACHAT",0
TxtShopSell:	dc.b	"VENTE",0
TxtShopHelp:	dc.b	"TAB CHANGE DE COTE",0
TxtShopHelp2:	dc.b	"ENTREE CONCLUT, ESC SORT",0
TxtShopGold:	dc.b	"OR ",0
TxtShopEmpty:	dc.b	"L'ETAL EST VIDE.",0
TxtShopNoSell:	dc.b	"VOTRE SAC EST VIDE.",0
TxtShopPoor:	dc.b	"PAS ASSEZ D'OR.",0
TxtShopFull:	dc.b	"LE SAC EST PLEIN.",0
TxtShopBought:	dc.b	"ACHETE : ",0
TxtShopSold:	dc.b	"VENDU : ",0
TxtShopFor:	dc.b	", ",0
TxtShopOr:	dc.b	" OR.",0
TxtTrapSpot:	dc.b	"PIEGE REPERE : ",0
TxtTrapFires:	dc.b	" SE DECLENCHE !",0
TxtTrapHurt:	dc.b	"LE GROUPE PERD ",0
TxtTrapMiss:	dc.b	"LE GROUPE S'EN TIRE INDEMNE.",0
TxtTrapOff:	dc.b	" DESAMORCE LE PIEGE.",0
TxtTrapSlip:	dc.b	"LA MAIN TREMBLE. RIEN N'EST FAIT.",0
TxtTrapDown:	dc.b	"CE HEROS N'EST PLUS EN ETAT.",0
TxtShieldUp:	dc.b	"UNE AURA PROTEGE LE GROUPE.",0
TxtFear:	dc.b	"LE MONSTRE EST TERRIFIE !",0
TxtUnknownSpell: dc.b	"CE SORT VOUS EST INCONNU.",0
TxtNoSlot:	dc.b	"PLUS D'EMPLACEMENT A CE NIVEAU.",0
TxtHalfSave:	dc.b	"IL ESQUIVE EN PARTIE !",0
TxtResisted:	dc.b	"LE MONSTRE RESISTE AU SORT.",0
TxtBlessed:	dc.b	"UNE BENEDICTION GUIDE VOS COUPS.",0
TxtHeroDown:	dc.b	"CE HEROS EST HORS DE COMBAT.",0
TxtEquips:	dc.b	" EQUIPE ",0
TxtCannotEquip:	dc.b	"CELA NE S'EQUIPE PAS.",0
TxtCannotUse:	dc.b	"CELA NE S'UTILISE PAS.",0
TxtLearns:	dc.b	" APPREND ",0
TxtAlreadyKnown: dc.b	"CE SORT EST DEJA CONNU.",0
TxtNoMagic:	dc.b	"CE HEROS N'EST PAS MAGICIEN.",0
TxtNoHero:	dc.b	"AUCUN HEROS ICI.",0
TxtBag:		dc.b	"SAC A DOS",0
TxtChooseSpell:	dc.b	"QUEL SORT ?",0
TxtPmSuffix:	dc.b	"PM",0
TxtSpLevel:	dc.b	" NIV ",0
TxtPv:		dc.b	"PV ",0
TxtPm:		dc.b	"PM ",0
TxtNiv:		dc.b	"NIV ",0
TxtSpPx:	dc.b	"  PX ",0
TxtSpPv:	dc.b	"  PV ",0
TxtSpPm:	dc.b	"   PM ",0
TxtCa:		dc.b	"CA ",0
TxtAtt:		dc.b	"   ATT ",0
TxtWeapon:	dc.b	"ARME: ",0
TxtArmorLbl:	dc.b	"ARM: ",0
TxtBare:	dc.b	"POINGS NUS",0
TxtNone:	dc.b	"AUCUNE",0
TxtSpells:	dc.b	"SORTS : ",0
TxtSavesLbl:	dc.b	"VIG/REF/VOL ",0
TxtNiveau:	dc.b	"NIVEAU ",0
TxtOr:		dc.b	"   OR ",0
TxtKeys:	dc.b	"   CLES ",0
TxtRuneDoor:	dc.b	"UNE PORTE COUVERTE DE RUNES.",0
TxtLeverSeen:	dc.b	"UN LEVIER SCELLE DANS LE MUR.",0
TxtGateShut:	dc.b	"UNE HERSE DE FER BARRE LE PASSAGE.",0
TxtLeverDown:	dc.b	"LE LEVIER CEDE. UNE HERSE SE LEVE.",0
TxtLeverUp:	dc.b	"LE LEVIER REMONTE. LA HERSE RETOMBE.",0
TxtRuneTitle:	dc.b	"LA PORTE VOUS PARLE",0
TxtRuneAsk:	dc.b	"REPONDEZ : 1, 2 OU 3",0
TxtRuneOk:	dc.b	"LES RUNES S'EFFACENT. PASSAGE !",0
TxtRuneBad:	dc.b	"LA RUNE ROUGEOIT DE COLERE.",0
TxtRuneBurn:	dc.b	" EST BRULE, ",0
TxtR0Q1:	dc.b	"JE PARLE SANS BOUCHE",0
TxtR0Q2:	dc.b	"ET J'ENTENDS SANS",0
TxtR0Q3:	dc.b	"OREILLE. QUI SUIS-JE ?",0
TxtR0A1:	dc.b	"L'ECHO",0
TxtR0A2:	dc.b	"LE VENT",0
TxtR0A3:	dc.b	"LA PIERRE",0
TxtR1Q1:	dc.b	"PLUS ON EN PREND,",0
TxtR1Q2:	dc.b	"PLUS ON EN LAISSE",0
TxtR1Q3:	dc.b	"DERRIERE SOI. QUOI ?",0
TxtR1A1:	dc.b	"DES PIECES D'OR",0
TxtR1A2:	dc.b	"DES PAS",0
TxtR1A3:	dc.b	"DES ANNEES",0
TxtR2Q1:	dc.b	"J'AI UN OEIL",0
TxtR2Q2:	dc.b	"MAIS JE NE VOIS RIEN.",0
TxtR2Q3:	dc.b	"QUI SUIS-JE ?",0
TxtR2A1:	dc.b	"LE BORGNE",0
TxtR2A2:	dc.b	"L'AIGUILLE",0
TxtR2A3:	dc.b	"LA TOUR DE GUET",0
TxtHelpRiddle:	dc.b	"1 2 OU 3 POUR REPONDRE  ESC",0
TxtHelpCreate:	dc.b	"1-8 CLASSE  R DES  ENTREE OK  ESC",0
TxtHelpMove:	dc.b	"ESPACE C I M CARTE L LIVRE R CAMP P REGL",0
TxtRaised:	dc.b	" SE RELEVE.",0
TxtRested:	dc.b	"LE GROUPE FAIT HALTE ET RECUPERE.",0
TxtCamp:	dc.b	"VOUS DRESSEZ LE CAMP.",0
TxtCampBad:	dc.b	"UN BRUIT DANS LE NOIR : PAS DE REPOS !",0
TxtNoTarget:	dc.b	"AUCUNE CIBLE ICI.",0
TxtMenuNew:	dc.b	"1   COMMENCER UNE NOUVELLE PARTIE",0
TxtMenuLoad:	dc.b	"2   REPRENDRE LA PARTIE SAUVEE",0
TxtMenuQuit:	dc.b	"ESC QUITTER",0
TxtMenuHint:	dc.b	"LA PARTIE SE SAUVE A CHAQUE ETAGE",0
TxtResumed:	dc.b	"VOUS REPRENEZ VOTRE DESCENTE.",0
TxtSaved:	dc.b	"LA PARTIE EST SAUVEE.",0
TxtOptTitle:	dc.b	"REGLAGES",0
TxtOptMusic:	dc.b	"MUSIQUE       ",0
TxtOptSfx:	dc.b	"BRUITAGES     ",0
TxtOptKb:	dc.b	"CLAVIER       ",0
TxtOptSave:	dc.b	"SAUVEGARDER MAINTENANT",0
TxtOptTitleBack:	dc.b	"RETOUR A L'ACCUEIL",0
TxtOptOn:	dc.b	"OUI",0
TxtOptOff:	dc.b	"NON",0
TxtOptAzerty:	dc.b	"AZERTY",0
TxtOptQwerty:	dc.b	"QWERTY",0
TxtHelpOpts:	dc.b	"FLECHES  ENTREE CHANGE  P OU ESC",0
TxtBookTitle:	dc.b	"GRIMOIRE DE ",0
TxtBookMark:	dc.b	">",0
TxtBookLevel:	dc.b	"NIV ",0
TxtBookSchool:	dc.b	" ",0
TxtBookPerLvl:	dc.b	" PAR NIV. ",0
TxtBookSave:	dc.b	"JET ",0
TxtBookHalf:	dc.b	", MOITIE",0
TxtBookNoSave:	dc.b	"SANS JET",0
TxtBookSlots:	dc.b	"  RESTE ",0
TxtSchoolArc:	dc.b	"PROFANE",0
TxtSchoolDiv:	dc.b	"DIVIN",0
TxtSchoolBoth:	dc.b	"MIXTE",0
TxtKindDmg:	dc.b	"DEGATS ",0
TxtKindHeal:	dc.b	"SOINS ",0
TxtKindWard:	dc.b	"PROTECTION +",0
TxtKindFear:	dc.b	"TERREUR ",0
TxtKindBless:	dc.b	"BENEDICTION +",0
TxtSaveFort:	dc.b	"VIGUEUR",0
TxtSaveRef:	dc.b	"REFLEXES",0
TxtSaveWill:	dc.b	"VOLONTE",0
TxtHelpBook:	dc.b	"FLECHES  1-4 HEROS  L OU ESC FERMER",0
TxtMapTitle:	dc.b	"CARTE NIVEAU ",0
TxtDash2:	dc.b	" - ",0
TxtNord:	dc.b	"NORD",0
TxtEst:		dc.b	"EST",0
TxtSud:		dc.b	"SUD",0
TxtOuest:	dc.b	"OUEST",0
TxtLegDoor:	dc.b	"PORTE",0
TxtLegRune:	dc.b	"RUNE",0
TxtLegShut:	dc.b	"FERMEE",0
TxtLegYou:	dc.b	"VOUS",0
TxtLegStairs:	dc.b	"ESCALIER",0
TxtLegMonster:	dc.b	"MONSTRE",0
TxtHelpMap:	dc.b	"M OU ESC POUR REFERMER LA CARTE",0
TxtConfirmQuit:	dc.b	"ESC A NOUVEAU POUR ABANDONNER.",0
TxtNoSpellKnown:	dc.b	"AUCUN SORT CONNU.",0
TxtHelpFight:	dc.b	"A ATTAQUER  S SORT  F FUIR  I SAC",0
TxtHelpInv:	dc.b	"E EQUIPER U UTILISER D JETER 1-4",0
TxtHelpSpell:	dc.b	"CHIFFRE POUR LANCER   ESC ANNULE",0
TxtHelpSheet:	dc.b	"1-4 HEROS  I SAC  L LIVRE  P REGLAGES",0
TxtHelpShop:	dc.b	"FLECHES  TAB COTE  ENTREE  ESC SORT",0
	even

;======================================================================
	SECTION	crawlchip,DATA_C	; blitter et Paula : Chip RAM
;======================================================================

	include	"pointer.i"		; sprite 0 : le pointeur de souris
NullSprite:				; les sept autres, eteints
	dc.w	$0000,$0000
	even

DgnArt:
	incbin	"data/dgnart.bin"
	even
DgnMap:
	incbin	"data/dgnmap.bin"
	even
SfxData:
	incbin	"data/sfx.bin"
	even
SfxSilence:
	dc.w	0,0

;======================================================================
	SECTION	crawlbss,BSS
;======================================================================

GfxBase:	ds.l	1
DosBase:	ds.l	1
OldView:	ds.l	1
OldCopper:	ds.l	1
ShowBuf:	ds.l	1
DrawBuf:	ds.l	1
CopBplPtrs:	ds.l	1
MonPtr:		ds.l	1
RngSeed:	ds.l	1
OldIntena:	ds.w	1
OldDmacon:	ds.w	1
PosX:		ds.w	1
PosY:		ds.w	1
Dir:		ds.w	1
Level:		ds.w	1
Gold:		ds.w	1
KeyCount:	ds.w	1
InCombat:	ds.w	1
MonKind:	ds.w	1
MonArt:		ds.w	1
PartyBless:	ds.w	1
MonHp:		ds.w	1
MonHpMax:	ds.w	1
BossDead:	ds.w	1
MonStun:	ds.w	1
MonCount:	ds.w	1		; creatures encore debout, celle de
					; devant comprise
MonPack:	ds.w	1		; combien s'en presentaient au depart
MonRange:	ds.w	1		; 1 tant que la bande n'a pas comble
					; la distance
AtkMax:		ds.w	1
QuitArm:	ds.w	1
HasSave:	ds.w	1
BookCursor:	ds.w	1
BookTop:	ds.w	1
OptCursor:	ds.w	1
OptMusic:	ds.w	1
OptSfx:	ds.w	1
CurMusic:	ds.w	1
CopSurf:	ds.l	1
SurfPhase:	ds.w	1
LorePage:	ds.w	1
ShowIntro:	ds.w	1
MouseX:	ds.w	1
MouseY:	ds.w	1
MouseRawX:	ds.w	1
MouseRawY:	ds.w	1
MouseBtn:	ds.w	1
MouseHit:	ds.w	1
ShopMode:	ds.w	1
ShopCursor:	ds.w	1
ShopTop:	ds.w	1
SpellCount:	ds.w	1
SpellList:	ds.w	SPELLMENU
AnimFrame:	ds.w	1
AnimCount:	ds.w	1
GameOver:	ds.w	1
Quit:		ds.w	1
NeedRedraw:	ds.w	1
DrawReady:	ds.w	1
MusicLine:	ds.w	1
Phase:		ds.w	1
UiMode:		ds.w	1
SelHero:	ds.w	1
InvCursor:	ds.w	1
InvTop:		ds.w	1
RiddleIdx:	ds.w	1
RiddleX:	ds.w	1
RiddleY:	ds.w	1
CreIndex:	ds.w	1
CreStep:	ds.w	1
CreCursor:	ds.w	1
CreClass:	ds.w	1
CreHp:		ds.w	1
CreMp:		ds.w	1
CreNameLen:	ds.w	1
CreNameIdx:	ds.w	1
KbLayout:	ds.w	1
CreStr:		ds.w	1		; les six caracteristiques tirees
CreDex:		ds.w	1
CreCon:		ds.w	1
CreInt:		ds.w	1
CreWis:		ds.w	1
CreCha:		ds.w	1
CreName:	ds.b	NAMELEN+2
	even
Heroes:		ds.b	NHEROES*hr_SIZEOF
Inventory:	ds.b	INVSIZE
	even
MapTerrain:	ds.b	MAPBYTES
MapParam:	ds.b	MAPBYTES
MapSeen:	ds.b	MAPBYTES
ShopStock:	ds.b	NSHOP
	even
	even
SaveBuf:	ds.b	SAVESIZE
LogBuf:		ds.b	LOGLINES*(LOGWIDTH+2)
TmpStr:		ds.b	96
NumBuf:		ds.b	14
	even

;======================================================================
	SECTION	crawlbuf,BSS_C
;======================================================================

ScreenA:	ds.b	SCRSIZE
ScreenB:	ds.b	SCRSIZE
CopList:	ds.b	COPSIZE
