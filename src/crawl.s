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
LEVELS		= 3
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
hr_SIZEOF	= 54
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
mt_SIZEOF	= 48

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

; --- phases et ecrans ---
PHASE_CREATE	= 0
PHASE_PLAY	= 1
PHASE_TITLE	= 2			; l'ecran d'accueil
TITLEH		= 176			; hauteur de l'illustration
SAVEMAGIC	= $46414552		; "FAER"
SAVESIZE	= 4+12+NHEROES*hr_SIZEOF+INVSIZE+3*MAPBYTES
UI_VIEW		= 0
UI_SHEET	= 1
UI_INV		= 2
UI_SPELL	= 3
UI_RIDDLE	= 4
UI_MAP		= 5
UI_BOOK		= 6			; le grimoire
UI_OPTS		= 7			; les reglages
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
COPSIZE		= 2600			; 8 banques de palette + pointeurs + fin

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
	move.w	#-1,CurMusic		; l'accueil a sa propre musique
	moveq	#0,d0
	bsr	PlayMusic
	move.w	#DMAF_SETCLR|DMAF_MASTER|DMAF_RASTER|DMAF_COPPER|DMAF_BLITTER|DMAF_AUDIO,DMACON(a5)

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
	move.w	#$0011,(a2)+
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
	move.l	#$fffffffe,(a2)+

	bsr	SetBplPtrs
	lea	CUSTOM,a5
	move.l	#CopList,COP1LCH(a5)
	move.w	d0,COPJMP1(a5)
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
	beq.s	.helpView
	cmp.w	#UI_INV,d0
	bne.s	.helpSpell
	lea	TxtHelpInv,a0
	bra.s	.help
.helpSpell:
	cmp.w	#UI_SPELL,d0
	bne.s	.helpRiddle
	lea	TxtHelpSpell,a0
	bra.s	.help
.helpRiddle:
	cmp.w	#UI_RIDDLE,d0
	bne.s	.helpMap
	lea	TxtHelpRiddle,a0
	bra.s	.help
.helpMap:
	cmp.w	#UI_MAP,d0
	bne.s	.helpBook
	lea	TxtHelpMap,a0
	bra.s	.help
.helpBook:
	cmp.w	#UI_BOOK,d0
	bne.s	.helpOpts
	lea	TxtHelpBook,a0
	bra.s	.help
.helpOpts:
	cmp.w	#UI_OPTS,d0
	bne.s	.helpOther
	lea	TxtHelpOpts,a0
	bra.s	.help
.helpOther:
	lea	TxtHelpSheet,a0
	bra.s	.help
.helpView:
	tst.w	InCombat
	beq.s	.helpMove
	lea	TxtHelpFight,a0
	bra.s	.help
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
	lea	PT_TitleModule,a0
	tst.w	d0
	beq.s	.init
	lea	PT_ModuleData,a0
.init:
	bsr	PT_Init
	lea	CUSTOM,a5
	move.w	#DMAF_SETCLR|DMAF_AUDIO,DMACON(a5)
.done:
	movem.l	(sp)+,d0-d1/a0-a1/a5
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
	moveq	#1,d0			; on descend : la marche du donjon
	bsr	PlayMusic
	clr.w	Phase
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
	moveq	#1,d0
	bsr	PlayMusic
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

	move.w	it_Type(a2),d0		; icone du type
	cmp.w	#IT_SHIELD,d0
	bne.s	.icon
	moveq	#IT_ARMOR,d0
.icon:
	cmp.w	#5,d0
	blt.s	.iconOk
	moveq	#4,d0
.iconOk:
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
	beq.s	.door
	cmp.w	#T_LOCKED,d0
	beq	.lockedDoor
	cmp.w	#T_NICHE,d0
	beq	.niche
	cmp.w	#T_RUNE,d0
	beq	.rune
	cmp.w	#T_LEVER,d0
	beq	.lever
	lea	TxtNothing,a0
	bsr	LogAdd
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

Descend:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	Level,d0
	addq.w	#1,d0
	cmp.w	#LEVELS,d0
	blt.s	.next
	move.w	#1,GameOver
	moveq	#SFX_LEVEL,d0
	bsr	SfxPlay
	lea	TxtWin,a0
	bsr	LogAdd
	bra.s	.done
.next:
	move.w	d0,Level
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
	move.w	mt_Hd(a2),d0		; les PV se tirent aux des de vie
	move.w	mt_HdF(a2),d1
	bsr	RollDice
	add.w	mt_HpB(a2),d0
	cmp.w	#1,d0
	bge.s	.hpOk
	moveq	#1,d0
.hpOk:
	move.w	d0,MonHp
	move.w	mt_Art(a2),MonArt
	clr.w	PartyBless
	moveq	#SFX_GROWL,d0
	bsr	SfxPlay
	lea	TmpStr,a1
	lea	TxtAppears,a0
	bsr	StrCopy
	move.l	a2,a0
	bsr	StrCopy
	lea	TxtBang,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; HeroAttack : a6 = heros, a2 = monstre -> d0 = degats (0 si rate)
HeroAttack:
	movem.l	d1-d7/a0/a3,-(sp)
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
	beq.s	.heroNext
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
	tst.w	MonStun
	beq.s	.attack
	clr.w	MonStun
	lea	TxtMonStunned,a0
	bsr	LogAdd
	rts
.attack:
	bsr	MonsterAttack
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
	move.w	#1,GameOver
	clr.w	InCombat
	lea	TxtWiped,a0
	bsr	LogAdd
	rts

MonsterDies:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	MonPtr,a2
	clr.w	InCombat
	moveq	#SFX_DEATH,d0
	bsr	SfxPlay
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

	move.w	PosX,d0			; la case est nettoyee
	move.w	PosY,d1
	bsr	MapCell
	move.w	d0,d2
	and.w	#$000f,d2
	move.w	PosX,d0
	move.w	PosY,d1
	bsr	MapSet

	lea	Heroes,a6		; experience et bonus de fin de combat
	moveq	#NHEROES-1,d6
.xpLoop:
	tst.w	hr_Hp(a6)
	beq.s	.xpNext
	clr.w	hr_AcTemp(a6)
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
	move.w	UiMode,d1		; les deux ecrans ont leurs fleches
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

; Ce qu'une partie contient : adresse et longueur de chaque bloc.
SaveList:
	dc.l	PosX,12			; PosX, PosY, Dir, Level, Gold, KeyCount
	dc.l	Heroes,NHEROES*hr_SIZEOF
	dc.l	Inventory,INVSIZE
	dc.l	MapTerrain,MAPBYTES
	dc.l	MapParam,MAPBYTES
	dc.l	MapSeen,MAPBYTES
	dc.l	0,0

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
TxtHelpMove:	dc.b	"ESPACE C I M CARTE L LIVRE P REGLAGES",0
TxtRaised:	dc.b	" SE RELEVE.",0
TxtRested:	dc.b	"LE GROUPE FAIT HALTE ET RECUPERE.",0
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
	even

;======================================================================
	SECTION	crawlchip,DATA_C	; blitter et Paula : Chip RAM
;======================================================================

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
MonStun:	ds.w	1
AtkMax:		ds.w	1
QuitArm:	ds.w	1
HasSave:	ds.w	1
BookCursor:	ds.w	1
BookTop:	ds.w	1
OptCursor:	ds.w	1
OptMusic:	ds.w	1
OptSfx:	ds.w	1
CurMusic:	ds.w	1
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
