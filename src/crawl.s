;----------------------------------------------------------------------
; crawl.s - LES CAVES DE FAERGHAIL, dungeon crawler en vue subjective
;
; Cible  : Amiga 1200 (AGA), AmigaOS 3.1+, 68020+
; Ecran  : PAL lores 320x256, 4 bitplanes (16 couleurs 24 bits), double
;          tampon ; l'affichage n'est refait qu'apres une action.
; Vue    : grille de cases, murs pre-calcules en perspective et poses au
;          blitter du plus loin au plus proche (comme les crawlers de
;          l'epoque : aucun calcul 3D a l'execution).
; Entree : clavier lu directement sur le CIA-A, sans l'OS.
; Son    : le replayer ProTracker de ptreplay.i.
;----------------------------------------------------------------------

	include	"hardware.i"

SCRW		= 320
SCRH		= 256
SCRBPL		= 40			; octets par ligne et par plan
DEPTH		= 4			; bitplanes
PLANESIZE	= SCRBPL*SCRH
SCRSIZE		= PLANESIZE*DEPTH

MAPW		= 24
MAPH		= 24
MAPBYTES	= MAPW*MAPH
LEVELS		= 3
LEVELSIZE	= 4+MAPBYTES

; --- cases ---
CELL_FLOOR	= 0
CELL_WALL	= 1
CELL_DOOR	= 2
CELL_STAIRS	= 3
CONT_CHEST	= $10			; quartet haut : contenu
CONT_MONSTER	= $20
CONT_MASK	= $30

; --- morceaux de decor, dans l'ordre de data/dgnart.bin ---
ART_BG		= 0
ART_FRONT	= 1			; distances 1 a 4
ART_LEFT	= 5			; profondeurs 0 a 3
ART_RIGHT	= 9
ART_DOOR	= 13			; distances 1 a 3
ART_MONSTER	= 16			; 4 monstres

; --- structure d'un heros ---
hr_Name		= 0			; 8 octets
hr_Level	= 8
hr_Xp		= 10
hr_Hp		= 12
hr_HpMax	= 14
hr_Atk		= 16
hr_Def		= 18
hr_SIZEOF	= 20
NHEROES		= 4

; --- type de monstre ---
mt_Name		= 0			; 12 octets
mt_Hp		= 12
mt_Atk		= 14
mt_Def		= 16
mt_Xp		= 18
mt_Gold		= 20
mt_SIZEOF	= 22

; --- codes clavier bruts ---
KEY_UP		= $4c
KEY_DOWN	= $4d
KEY_RIGHT	= $4e
KEY_LEFT	= $4f
KEY_SPACE	= $40
KEY_ESC		= $45
KEY_A		= $20
KEY_F		= $23
KEY_P		= $19
KEY_Q		= $10
KEY_E		= $12

; --- disposition de l'ecran ---
PANEL_X		= 224			; en pixels, cale sur un mot
PANEL_W		= 96
LOG_Y		= 160
LOG_H		= 96
LOGLINES	= 4
LOGWIDTH	= 36

COPSIZE		= 512

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
	bsr	PT_Init
	move.w	#DMAF_SETCLR|DMAF_MASTER|DMAF_RASTER|DMAF_COPPER|DMAF_BLITTER|DMAF_AUDIO,DMACON(a5)

	bsr	Redraw			; les deux tampons, pour demarrer propre
	bsr	SwapBuffers
	bsr	Redraw

;----------------------------------------------------------------------
; Boucle principale : une image = un tick de musique et une touche au plus
;----------------------------------------------------------------------
MainLoop:
	bsr	WaitVBlank
	bsr	PT_Tick

	tst.w	DrawReady		; un affichage vient d'etre prepare ?
	beq.s	.noSwap
	clr.w	DrawReady
	bsr	SwapBuffers
.noSwap:
	bsr	PollKey
	tst.w	d0
	bmi.s	.noKey
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
; InitScreen : copperlist, palette 24 bits, tampons
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
	move.w	#$4201,(a2)+		; 4 plans, COLOR, ECSENA
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

	move.l	a2,CopBplPtrs		; les 8 MOVE de pointeurs de plans
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

	lea	DgnPalette,a3		; 16 couleurs, quartets hauts puis bas
	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+
	move.w	#COLOR00,d1
	moveq	#15,d2
.hiLoop:
	move.w	d1,(a2)+
	move.w	(a3),(a2)+
	addq.l	#4,a3
	addq.w	#2,d1
	dbf	d2,.hiLoop
	lea	DgnPalette+2,a3
	move.w	#BPLCON3,(a2)+
	move.w	#$0200,(a2)+
	move.w	#COLOR00,d1
	moveq	#15,d2
.loLoop:
	move.w	d1,(a2)+
	move.w	(a3),(a2)+
	addq.l	#4,a3
	addq.w	#2,d1
	dbf	d2,.loLoop
	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+
	move.l	#$fffffffe,(a2)+

	bsr	SetBplPtrs
	lea	CUSTOM,a5
	move.l	#CopList,COP1LCH(a5)
	move.w	d0,COPJMP1(a5)
	rts

; Ecrit dans la copperlist les pointeurs du tampon affiche
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
; BlitPiece : pose un morceau de decor dans le tampon de dessin
;   d0 = numero du morceau, d1 = 0 avec masque, sinon copie simple
;
; Les morceaux sont cales sur des mots et toujours a la meme place :
; aucun decalage a faire, le blitter n'a qu'a recopier a travers le
; masque (minterme $CA : D = A ET B, ou C la ou le masque est a zero).
;----------------------------------------------------------------------
BlitPiece:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	CUSTOM,a6
	lea	DgnArt,a0
	move.w	d0,d2
	mulu.w	#12,d2
	lea	2(a0,d2.w),a1		; descripteur
	move.l	(a1),d3
	add.l	a0,d3			; adresse des donnees
	moveq	#0,d4
	move.w	4(a1),d4		; largeur en mots
	moveq	#0,d5
	move.w	6(a1),d5		; hauteur
	moveq	#0,d6
	move.w	8(a1),d6		; offset dans un plan

	move.l	d4,d7			; taille d'un plan du morceau
	add.l	d7,d7
	mulu.w	d5,d7

	move.l	DrawBuf,a2
	add.l	d6,a2			; destination, plan 0
	move.l	d3,a3			; masque
	add.l	d7,d3			; plan 0 du morceau

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
	move.w	d2,BLTSIZE(a6)		; lance le blit

	add.l	d7,d3			; plan suivant du morceau
	lea	PLANESIZE(a2),a2
	dbf	d0,.planeLoop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; FillRect : remplit un rectangle d'une couleur
;   d0 = x (multiple de 16), d1 = y, d2 = largeur (multiple de 16),
;   d3 = hauteur, d4 = couleur
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
	add.l	d5,a2			; coin, plan 0

	lsr.w	#4,d2			; largeur en mots
	move.w	d2,d6
	add.w	d6,d6
	neg.w	d6
	add.w	#SCRBPL,d6		; modulo

	moveq	#0,d5			; numero de plan
.planeLoop:
	bsr	WaitBlit
	btst	d5,d4
	beq.s	.zero
	move.w	#BLT_USED|$00ff,BLTCON0(a6)	; minterme 1 : que des uns
	bra.s	.set
.zero:
	move.w	#BLT_USED,BLTCON0(a6)		; minterme 0 : que des zeros
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

;----------------------------------------------------------------------
; HLine / VLine : traits d'encadrement
;   HLine : d0 = x (multiple de 8), d1 = y, d2 = longueur (mult. de 8),
;           d3 = couleur
;----------------------------------------------------------------------
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
	lsr.w	#3,d2			; longueur en octets
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
	eor.w	#7,d7			; numero de bit dans l'octet
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
DrawBox:
	movem.l	d0-d4,-(sp)
	move.l	d4,d5
	exg	d3,d5			; HLine attend la couleur en d3
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
; DrawText : a0 = chaine (0 final), d0 = colonne (x/8), d1 = ligne,
;            d2 = couleur
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
	btst	d5,d2
	beq.s	.planeNext
	moveq	#7,d6
	move.l	a2,a4
	move.l	a1,a5
.rowLoop:
	move.b	(a5)+,d7
	or.b	d7,(a4)
	lea	SCRBPL(a4),a4
	dbf	d6,.rowLoop
.planeNext:
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

;----------------------------------------------------------------------
; Chaines : copie et conversion decimale dans TmpStr
;----------------------------------------------------------------------
; StrCopy : a0 = source, a1 = destination ; a1 pointe le zero final
StrCopy:
	move.b	(a0)+,(a1)
	beq.s	.done
	addq.l	#1,a1
	bra.s	StrCopy
.done:
	rts

; StrNum : d0 = valeur (0..65535), a1 = destination
StrNum:
	movem.l	d0-d3/a2,-(sp)
	lea	NumBuf+8,a2
	clr.b	-(a2)
	and.l	#$0000ffff,d0
.digit:
	divu.w	#10,d0
	move.l	d0,d1
	swap	d1			; reste
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
	movem.l	(sp)+,d0-d3/a2
	rts

;----------------------------------------------------------------------
; PollKey : renvoie d0 = code brut d'une touche enfoncee, ou -1
;
; Le clavier arrive en serie sur le CIA-A : le code est inverse et
; decale d'un bit, et il faut renvoyer une poignee de main en passant
; le port serie en sortie pendant une centaine de microsecondes.
;----------------------------------------------------------------------
PollKey:
	move.b	CIAAICR,d1		; la lecture efface les drapeaux
	btst	#3,d1			; SP : un octet est arrive
	beq.s	.none
	moveq	#0,d0
	move.b	CIAASDR,d0
	not.b	d0
	ror.b	#1,d0
	bset	#6,CIAACRA		; poignee de main
	bsr	KeyDelay
	bclr	#6,CIAACRA
	btst	#7,d0			; bit 7 : relachement
	bne.s	.none
	and.w	#$007f,d0
	rts
.none:
	moveq	#-1,d0
	rts

KeyDelay:				; environ deux lignes raster
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
; Rnd : xorshift 32 bits ; RndMod renvoie d0 = Rnd modulo d1
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

RndMod:					; d1 = borne, resultat dans d0
	movem.l	d1-d2,-(sp)
	move.l	d1,d2
	bsr	Rnd
	and.l	#$00007fff,d0
	divu.w	d2,d0
	clr.w	d0
	swap	d0			; reste
	movem.l	(sp)+,d1-d2
	rts

;----------------------------------------------------------------------
; Carte : MapCell renvoie d0 = octet de la case (d0 = x, d1 = y)
;----------------------------------------------------------------------
MapCell:
	cmp.w	#0,d0
	blt.s	.wall
	cmp.w	#MAPW,d0
	bge.s	.wall
	cmp.w	#0,d1
	blt.s	.wall
	cmp.w	#MAPH,d1
	bge.s	.wall
	movem.l	d1-d2/a0,-(sp)
	move.l	MapBase,a0
	move.w	d1,d2
	mulu.w	#MAPW,d2
	add.w	d0,d2
	moveq	#0,d0
	move.b	(a0,d2.w),d0
	movem.l	(sp)+,d1-d2/a0
	rts
.wall:
	moveq	#CELL_WALL,d0
	rts

; MapSet : d0 = x, d1 = y, d2 = nouvelle valeur
MapSet:
	movem.l	d0-d3/a0,-(sp)
	move.l	MapBase,a0
	move.w	d1,d3
	mulu.w	#MAPW,d3
	add.w	d0,d3
	move.b	d2,(a0,d3.w)
	movem.l	(sp)+,d0-d3/a0
	rts

; IsSolid : d0 = octet de case -> Z=0 si le mur bloque la vue
IsSolid:
	move.w	d0,d2
	and.w	#$000f,d2
	cmp.w	#CELL_WALL,d2
	beq.s	.yes
	cmp.w	#CELL_DOOR,d2
	beq.s	.yes
	moveq	#0,d2
	rts
.yes:
	moveq	#1,d2
	rts

;----------------------------------------------------------------------
; DrawScene : la vue subjective, ou le monstre pendant un combat
;----------------------------------------------------------------------
DrawScene:
	movem.l	d0-d7/a0-a6,-(sp)
	moveq	#ART_BG,d0		; sol et plafond
	moveq	#1,d1
	bsr	BlitPiece

	tst.w	InCombat
	beq.s	.dungeon
	move.w	MonKind,d0
	add.w	#ART_MONSTER,d0
	moveq	#0,d1
	bsr	BlitPiece
	bra	.done

.dungeon:
	; --- premier mur rencontre devant soi ---
	moveq	#0,d7			; distance du mur, 0 = aucun
	moveq	#1,d6
.scan:
	move.w	d6,d2
	bsr	CellAhead		; d0,d1 = case a la distance d6
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
	beq.s	.noFront
	move.w	d7,d2			; le mur : porte ou pierre ?
	bsr	CellAhead
	bsr	MapCell
	and.w	#$000f,d0
	cmp.w	#CELL_DOOR,d0
	bne.s	.stone
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
.noFront:
	; --- murs lateraux, du plus loin au plus proche ---
	move.w	d7,d6
	subq.w	#1,d6			; derniere profondeur visible
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
	move.w	d6,d2
	bsr	CellAhead		; case a la profondeur d6
	move.w	d0,d4
	move.w	d1,d5
	movem.l	d4-d5,-(sp)
	move.w	d4,d0
	move.w	d5,d1
	moveq	#-1,d2			; voisin de gauche
	bsr	CellSide
	bsr	MapCell
	bsr	IsSolid
	tst.w	d2
	beq.s	.noLeft
	move.w	d6,d0
	add.w	#ART_LEFT,d0
	moveq	#0,d1
	bsr	BlitPiece
.noLeft:
	movem.l	(sp)+,d4-d5
	move.w	d4,d0
	move.w	d5,d1
	moveq	#1,d2			; voisin de droite
	bsr	CellSide
	bsr	MapCell
	bsr	IsSolid
	tst.w	d2
	beq.s	.noRight
	move.w	d6,d0
	add.w	#ART_RIGHT,d0
	moveq	#0,d1
	bsr	BlitPiece
.noRight:
	dbf	d6,.sideLoop
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; CellAhead : d2 = distance -> d0,d1 = coordonnees de la case visee
CellAhead:
	movem.l	d2-d4/a0,-(sp)
	lea	DirTable,a0
	move.w	Dir,d3
	lsl.w	#2,d3
	move.w	(a0,d3.w),d4		; dx
	muls.w	d2,d4
	move.w	PosX,d0
	add.w	d4,d0
	move.w	2(a0,d3.w),d4		; dy
	muls.w	d2,d4
	move.w	PosY,d1
	add.w	d4,d1
	movem.l	(sp)+,d2-d4/a0
	rts

; CellSide : d0,d1 = case, d2 = -1 gauche / +1 droite -> case voisine
CellSide:
	movem.l	d2-d4/a0,-(sp)
	lea	DirTable,a0
	move.w	Dir,d3
	add.w	d2,d3
	add.w	#4,d3
	and.w	#3,d3
	lsl.w	#2,d3
	add.w	(a0,d3.w),d0
	add.w	2(a0,d3.w),d1
	movem.l	(sp)+,d2-d4/a0
	rts

;----------------------------------------------------------------------
; Redraw : tout l'ecran dans le tampon de dessin
;----------------------------------------------------------------------
Redraw:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#PANEL_X,d0		; nettoyage du panneau et du journal
	moveq	#8,d1
	move.w	#PANEL_W,d2
	move.w	#152,d3
	moveq	#0,d4
	bsr	FillRect
	moveq	#0,d0
	move.w	#LOG_Y,d1
	move.w	#SCRW,d2
	move.w	#LOG_H,d3
	moveq	#0,d4
	bsr	FillRect

	bsr	DrawScene

	moveq	#8,d0			; encadrements
	moveq	#8,d1
	move.w	#208,d2
	move.w	#152,d3
	moveq	#6,d4
	bsr	DrawBox
	move.w	#PANEL_X,d0
	moveq	#8,d1
	move.w	#88,d2
	move.w	#152,d3
	moveq	#6,d4
	bsr	DrawBox
	moveq	#8,d0
	move.w	#164,d1
	move.w	#304,d2
	move.w	#88,d3
	moveq	#6,d4
	bsr	DrawBox

	bsr	DrawParty
	bsr	DrawLog
	bsr	DrawStatus
	movem.l	(sp)+,d0-d7/a0-a6
	rts

DrawParty:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	Heroes,a6
	moveq	#0,d7			; numero de heros
.heroLoop:
	move.w	d7,d5
	mulu.w	#36,d5
	add.w	#16,d5			; ligne de depart

	move.l	a6,a0			; nom
	move.w	#29,d0
	move.w	d5,d1
	moveq	#13,d2
	tst.w	hr_Hp(a6)
	bne.s	.alive
	moveq	#5,d2			; mort : en gris
.alive:
	bsr	DrawText

	lea	TmpStr,a1		; "PV xx/yy"
	lea	TxtPv,a0
	bsr	StrCopy
	move.w	hr_Hp(a6),d0
	bsr	StrNum
	move.b	#'/',(a1)+
	move.w	hr_HpMax(a6),d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#29,d0
	move.w	d5,d1
	add.w	#10,d1
	moveq	#12,d2
	move.w	hr_Hp(a6),d3
	add.w	d3,d3
	cmp.w	hr_HpMax(a6),d3
	bge.s	.hpOk
	moveq	#15,d2			; sous la moitie : en rouge
.hpOk:
	bsr	DrawText

	lea	TmpStr,a1		; "NIV n"
	lea	TxtNiv,a0
	bsr	StrCopy
	move.w	hr_Level(a6),d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#29,d0
	move.w	d5,d1
	add.w	#20,d1
	moveq	#2,d2
	bsr	DrawText

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
	moveq	#2,d2
	cmp.w	#LOGLINES-1,d7
	bne.s	.old
	moveq	#13,d2			; la derniere ligne en blanc
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
	lea	TmpStr,a1		; "NIVEAU n  OR nnn  POTIONS n"
	lea	TxtNiveau,a0
	bsr	StrCopy
	move.w	Level,d0
	addq.w	#1,d0
	bsr	StrNum
	lea	TxtOr,a0
	bsr	StrCopy
	move.w	Gold,d0
	bsr	StrNum
	lea	TxtPot,a0
	bsr	StrCopy
	move.w	Potions,d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#2,d0
	move.w	#224,d1
	moveq	#14,d2
	bsr	DrawText

	tst.w	InCombat		; rappel des commandes
	beq.s	.explore
	lea	TxtHelpFight,a0
	bra.s	.help
.explore:
	lea	TxtHelpMove,a0
.help:
	move.w	#2,d0
	move.w	#238,d1
	moveq	#4,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Journal : LogAdd fait remonter les lignes et ecrit la nouvelle
;   a0 = chaine
;----------------------------------------------------------------------
LogAdd:
	movem.l	d0-d3/a0-a2,-(sp)
	lea	LogBuf,a1
	lea	LogBuf+LOGWIDTH+2,a2
	moveq	#LOGLINES-2,d3
.shift:
	move.w	#LOGWIDTH+1,d2		; un emplacement entier
.copy:
	move.b	(a2)+,(a1)+
	dbf	d2,.copy
	dbf	d3,.shift
	move.w	#LOGWIDTH-1,d2		; derniere ligne = la nouvelle
.write:
	move.b	(a0),(a1)+
	beq.s	.done
	addq.l	#1,a0
	dbf	d2,.write
	clr.b	(a1)			; texte trop long : on le ferme
.done:
	movem.l	(sp)+,d0-d3/a0-a2
	rts

;----------------------------------------------------------------------
; Nouvelle partie
;----------------------------------------------------------------------
NewGame:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	#$1234abcd,RngSeed
	clr.w	Level
	clr.w	InCombat
	clr.w	Quit
	clr.w	GameOver
	move.w	#40,Gold
	move.w	#3,Potions

	lea	HeroInit,a0		; le groupe de depart
	lea	Heroes,a1
	move.w	#NHEROES*hr_SIZEOF-1,d0
.copy:
	move.b	(a0)+,(a1)+
	dbf	d0,.copy

	lea	LogBuf,a0		; journal vide
	move.w	#LOGLINES*(LOGWIDTH+2)-1,d0
.clr:
	clr.b	(a0)+
	dbf	d0,.clr

	bsr	LoadLevel
	lea	TxtIntro,a0
	bsr	LogAdd
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; LoadLevel : recopie le niveau courant dans la carte de travail
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
	lea	MapWork,a1
	move.l	a1,MapBase
	move.w	#MAPBYTES-1,d2
.copy:
	move.b	(a0)+,(a1)+
	dbf	d2,.copy
	movem.l	(sp)+,d0-d3/a0-a1
	rts

;----------------------------------------------------------------------
; Touches
;----------------------------------------------------------------------
HandleKey:
	movem.l	d1-d7/a0-a6,-(sp)
	cmp.w	#KEY_ESC,d0
	bne.s	.notEsc
	move.w	#1,Quit
	bra	.done
.notEsc:
	tst.w	GameOver
	bne	.done
	tst.w	InCombat
	bne	.fight

	cmp.w	#KEY_UP,d0
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
	move.w	#1,NeedRedraw
	bra	.done
.notLeft:
	cmp.w	#KEY_RIGHT,d0
	bne.s	.notRight
	move.w	Dir,d1
	addq.w	#1,d1
	and.w	#3,d1
	move.w	d1,Dir
	move.w	#1,NeedRedraw
	bra	.done
.notRight:
	cmp.w	#KEY_SPACE,d0
	bne.s	.notSpace
	bsr	OpenDoor
	bra	.done
.notSpace:
	cmp.w	#KEY_P,d0
	bne.s	.done
	bsr	UsePotion
	bra.s	.done

.fight:
	cmp.w	#KEY_A,d0
	beq.s	.attack
	cmp.w	#KEY_SPACE,d0
	beq.s	.attack
	cmp.w	#KEY_F,d0
	beq.s	.flee
	cmp.w	#KEY_P,d0
	bne.s	.done
	bsr	UsePotion
	bra.s	.done
.attack:
	bsr	CombatRound
	bra.s	.done
.flee:
	bsr	CombatFlee
.done:
	movem.l	(sp)+,d1-d7/a0-a6
	rts

;----------------------------------------------------------------------
; TryMove : d1 = +1 en avant, -1 en arriere
;----------------------------------------------------------------------
TryMove:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	d1,d2
	bsr	CellAhead		; case visee
	move.w	d0,d4
	move.w	d1,d5
	bsr	MapCell
	move.w	d0,d3			; octet de la case
	and.w	#$000f,d0
	cmp.w	#CELL_WALL,d0
	bne.s	.notWall
	lea	TxtWall,a0
	bsr	LogAdd
	bra	.redraw
.notWall:
	cmp.w	#CELL_DOOR,d0
	bne.s	.enter
	lea	TxtDoorShut,a0
	bsr	LogAdd
	bra	.redraw
.enter:
	move.w	d4,PosX
	move.w	d5,PosY
	move.w	d3,d6
	and.w	#$000f,d6
	cmp.w	#CELL_STAIRS,d6
	beq	.stairs

	move.w	d3,d6			; contenu de la case
	and.w	#CONT_MASK,d6
	cmp.w	#CONT_CHEST,d6
	beq.s	.chest
	cmp.w	#CONT_MONSTER,d6
	beq.s	.monster
	bra	.redraw

.chest:
	move.w	d3,d2			; le coffre est vide desormais
	and.w	#$000f,d2
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapSet
	moveq	#40,d1
	bsr	RndMod
	add.w	#20,d0
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
	moveq	#4,d1			; une fois sur quatre, une potion
	bsr	RndMod
	tst.w	d0
	bne.s	.redraw
	addq.w	#1,Potions
	lea	TxtPotionFound,a0
	bsr	LogAdd
	bra.s	.redraw

.monster:
	move.w	d3,d0
	lsr.w	#6,d0
	and.w	#3,d0
	move.w	d0,MonKind
	bsr	StartCombat
	bra.s	.redraw

.stairs:
	bsr	Descend
.redraw:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; OpenDoor : ouvre la porte devant soi
;----------------------------------------------------------------------
OpenDoor:
	movem.l	d0-d7/a0-a6,-(sp)
	moveq	#1,d2
	bsr	CellAhead
	move.w	d0,d4
	move.w	d1,d5
	bsr	MapCell
	move.w	d0,d3
	and.w	#$000f,d0
	cmp.w	#CELL_DOOR,d0
	bne.s	.nothing
	move.w	d3,d2
	and.w	#$00f0,d2		; devient du sol
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapSet
	lea	TxtDoorOpen,a0
	bsr	LogAdd
	bra.s	.done
.nothing:
	lea	TxtNothing,a0
	bsr	LogAdd
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Descend : niveau suivant, ou victoire
;----------------------------------------------------------------------
Descend:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	Level,d0
	addq.w	#1,d0
	cmp.w	#LEVELS,d0
	blt.s	.next
	move.w	#1,GameOver
	lea	TxtWin,a0
	bsr	LogAdd
	bra.s	.done
.next:
	move.w	d0,Level
	bsr	LoadLevel
	lea	TxtDescend,a0
	bsr	LogAdd
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Combat
;----------------------------------------------------------------------
StartCombat:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#1,InCombat
	move.w	MonKind,d0
	mulu.w	#mt_SIZEOF,d0
	lea	MonTypes,a2
	add.l	d0,a2
	move.l	a2,MonPtr
	move.w	mt_Hp(a2),MonHp
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

CombatRound:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	MonPtr,a2
	moveq	#0,d7			; degats du groupe
	lea	Heroes,a6
	moveq	#NHEROES-1,d6
.heroLoop:
	tst.w	hr_Hp(a6)
	beq.s	.heroNext
	moveq	#6,d1
	bsr	RndMod
	add.w	hr_Atk(a6),d0
	sub.w	mt_Def(a2),d0
	tst.w	d0
	bgt.s	.dmgOk
	moveq	#1,d0
.dmgOk:
	add.w	d0,d7
.heroNext:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.heroLoop

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

	tst.w	MonHp
	bgt.s	.monsterTurn
	bsr	MonsterDies
	bra	.done
.monsterTurn:
	bsr	MonsterAttack
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

MonsterAttack:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	MonPtr,a2
	moveq	#NHEROES,d1		; cible au hasard parmi les vivants
	bsr	RndMod
	move.w	d0,d5
	moveq	#NHEROES-1,d6
.find:
	move.w	d5,d0
	mulu.w	#hr_SIZEOF,d0
	lea	Heroes,a6
	add.l	d0,a6
	tst.w	hr_Hp(a6)
	bne.s	.found
	addq.w	#1,d5
	and.w	#3,d5
	dbf	d6,.find
	bsr	PartyWiped
	bra	.done
.found:
	moveq	#4,d1
	bsr	RndMod
	add.w	mt_Atk(a2),d0
	sub.w	hr_Def(a6),d0
	tst.w	d0
	bgt.s	.hit
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtParry,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra.s	.done
.hit:
	move.w	d0,d4
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
	lea	TxtFor,a0
	bsr	StrCopy
	move.w	d4,d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	tst.w	hr_Hp(a6)
	bne.s	.checkParty
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

	move.w	mt_Xp(a2),d5		; experience pour tout le monde
	lea	Heroes,a6
	moveq	#NHEROES-1,d6
.xpLoop:
	tst.w	hr_Hp(a6)
	beq.s	.xpNext
	add.w	d5,hr_Xp(a6)
	bsr	CheckLevel
.xpNext:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.xpLoop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; CheckLevel : a6 = heros
CheckLevel:
	movem.l	d0-d2/a0-a1,-(sp)
	move.w	hr_Level(a6),d0
	mulu.w	#30,d0			; seuil : 30 points par niveau
	cmp.w	hr_Xp(a6),d0
	bgt.s	.done
	addq.w	#1,hr_Level(a6)
	add.w	#6,hr_HpMax(a6)
	move.w	hr_HpMax(a6),hr_Hp(a6)
	addq.w	#1,hr_Atk(a6)
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtLevelUp,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
.done:
	movem.l	(sp)+,d0-d2/a0-a1
	rts

CombatFlee:
	movem.l	d0-d7/a0-a6,-(sp)
	moveq	#2,d1
	bsr	RndMod
	tst.w	d0
	beq.s	.fail
	clr.w	InCombat
	lea	TxtFlee,a0
	bsr	LogAdd
	moveq	#-1,d2			; on recule d'une case
	bsr	CellAhead
	move.w	d0,d4
	move.w	d1,d5
	bsr	MapCell
	bsr	IsSolid
	tst.w	d2
	bne.s	.stay
	move.w	d4,PosX
	move.w	d5,PosY
.stay:
	bra.s	.done
.fail:
	lea	TxtFleeFail,a0
	bsr	LogAdd
	bsr	MonsterAttack
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

UsePotion:
	movem.l	d0-d7/a0-a6,-(sp)
	tst.w	Potions
	bne.s	.have
	lea	TxtNoPotion,a0
	bsr	LogAdd
	bra.s	.done
.have:
	lea	Heroes,a6		; le plus mal en point, encore vivant
	moveq	#NHEROES-1,d6
	moveq	#0,d7
	move.l	a6,a5
	move.w	#9999,d5
.pick:
	tst.w	hr_Hp(a6)
	beq.s	.pickNext
	move.w	hr_HpMax(a6),d0
	sub.w	hr_Hp(a6),d0
	cmp.w	d5,d0
	ble.s	.pickNext
	move.w	d0,d5
	move.l	a6,a5
	moveq	#1,d7
.pickNext:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.pick
	tst.w	d7
	beq.s	.done
	subq.w	#1,Potions
	move.l	a5,a6
	add.w	#15,hr_Hp(a6)
	move.w	hr_HpMax(a6),d0
	cmp.w	hr_Hp(a6),d0
	bge.s	.capped
	move.w	d0,hr_Hp(a6)
.capped:
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtDrinks,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; --- replayer ProTracker, dans la meme section de code ---
	include	"ptreplay.i"

;======================================================================
	SECTION	crawldata,DATA
;======================================================================

GfxName:	dc.b	"graphics.library",0
	even

	include	"dgnpal.i"
	include	"font8.i"
	even

DirTable:				; nord, est, sud, ouest
	dc.w	0,-1
	dc.w	1,0
	dc.w	0,1
	dc.w	-1,0

HeroInit:
	dc.b	"ALDER",0,0,0
	dc.w	1,0,32,32,7,3
	dc.b	"MYRA",0,0,0,0
	dc.w	1,0,24,24,5,2
	dc.b	"BORIN",0,0,0
	dc.w	1,0,30,30,6,4
	dc.b	"SELVA",0,0,0
	dc.w	1,0,22,22,6,2

MonTypes:
	dc.b	"RAT GEANT",0,0,0
	dc.w	14,4,1,12,6
	dc.b	"SQUELETTE",0,0,0
	dc.w	22,6,3,20,14
	dc.b	"ORC",0,0,0,0,0,0,0,0,0
	dc.w	34,8,4,32,26
	dc.b	"DRAGONNET",0,0,0
	dc.w	52,12,6,60,80

TxtIntro:	dc.b	"LES CAVES DE FAERGHAIL. BON COURAGE.",0
TxtWall:	dc.b	"UN MUR BLOQUE LE PASSAGE.",0
TxtDoorShut:	dc.b	"PORTE FERMEE. ESPACE POUR OUVRIR.",0
TxtDoorOpen:	dc.b	"LA PORTE S'OUVRE EN GRINCANT.",0
TxtNothing:	dc.b	"RIEN A FAIRE ICI.",0
TxtChest:	dc.b	"UN COFFRE ! VOUS TROUVEZ ",0
TxtGoldSuffix:	dc.b	" OR.",0
TxtPotionFound:	dc.b	"ET UNE POTION DE SOIN.",0
TxtDescend:	dc.b	"UN ESCALIER. VOUS DESCENDEZ.",0
TxtWin:		dc.b	"LA SORTIE ! VOUS REMONTEZ, VIVANTS.",0
TxtAppears:	dc.b	"UN ",0
TxtBang:	dc.b	" SURGIT !",0
TxtYouHit:	dc.b	"LE GROUPE INFLIGE ",0
TxtDamage:	dc.b	" DEGATS.",0
TxtHits:	dc.b	" TOUCHE ",0
TxtFor:		dc.b	" : ",0
TxtParry:	dc.b	" PARE LE COUP.",0
TxtFalls:	dc.b	" S'EFFONDRE !",0
TxtDies:	dc.b	" TOMBE ! +",0
TxtXpGold:	dc.b	" PX, ",0
TxtLevelUp:	dc.b	" PASSE UN NIVEAU !",0
TxtFlee:	dc.b	"VOUS PRENEZ LA FUITE.",0
TxtFleeFail:	dc.b	"LA FUITE ECHOUE !",0
TxtWiped:	dc.b	"LE GROUPE EST ANEANTI. C'EST FINI.",0
TxtNoPotion:	dc.b	"PLUS AUCUNE POTION.",0
TxtDrinks:	dc.b	" BOIT UNE POTION.",0
TxtPv:		dc.b	"PV ",0
TxtNiv:		dc.b	"NIV ",0
TxtPx:		dc.b	"PX ",0
TxtNiveau:	dc.b	"NIVEAU ",0
TxtOr:		dc.b	"   OR ",0
TxtPot:		dc.b	"   POTIONS ",0
TxtHelpMove:	dc.b	"FLECHES  ESPACE OUVRIR  P BOIRE  ESC",0
TxtHelpFight:	dc.b	"A ATTAQUER  F FUIR  P BOIRE  ESC",0
	even

;======================================================================
	SECTION	crawlchip,DATA_C	; le blitter ne lit que la Chip RAM
;======================================================================

DgnArt:
	incbin	"data/dgnart.bin"
	even
DgnMap:
	incbin	"data/dgnmap.bin"
	even

;======================================================================
	SECTION	crawlbss,BSS
;======================================================================

GfxBase:	ds.l	1
OldView:	ds.l	1
OldCopper:	ds.l	1
ShowBuf:	ds.l	1
DrawBuf:	ds.l	1
CopBplPtrs:	ds.l	1
MapBase:	ds.l	1
MonPtr:		ds.l	1
RngSeed:	ds.l	1
OldIntena:	ds.w	1
OldDmacon:	ds.w	1
PosX:		ds.w	1
PosY:		ds.w	1
Dir:		ds.w	1
Level:		ds.w	1
Gold:		ds.w	1
Potions:	ds.w	1
InCombat:	ds.w	1
MonKind:	ds.w	1
MonHp:		ds.w	1
GameOver:	ds.w	1
Quit:		ds.w	1
NeedRedraw:	ds.w	1
DrawReady:	ds.w	1
Heroes:		ds.b	NHEROES*hr_SIZEOF
MapWork:	ds.b	MAPBYTES
LogBuf:		ds.b	LOGLINES*(LOGWIDTH+2)
TmpStr:		ds.b	80
NumBuf:		ds.b	12
	even

;======================================================================
	SECTION	crawlbuf,BSS_C		; tampons d'ecran et copperlist
;======================================================================

ScreenA:	ds.b	SCRSIZE
ScreenB:	ds.b	SCRSIZE
CopList:	ds.b	COPSIZE
