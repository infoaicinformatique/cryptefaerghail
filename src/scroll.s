;----------------------------------------------------------------------
; scroll.s - 8 bitplanes AGA (256 couleurs 24 bits) + scrolling materiel
;
; Cible  : Amiga 1200 (AGA), AmigaOS 3.1+, 68020+, ~1 Mo de Chip libre
; Ecran  : PAL lores 320x256, 8 bitplanes (256 couleurs)
; Bitmap : 640x384 pixels, 8 plans, en Chip RAM (240 Ko), genere au
;          demarrage (plasma) puis parcouru par une camera sinusoidale.
; Sortie : bouton gauche de la souris.
;
; Le scrolling est 100 % materiel : aucun pixel n'est deplace.
;   - deplacement grossier : on decale les pointeurs de bitplanes
;     (2 octets = 16 pixels lores) et on utilise les modulos pour que le
;     DMA saute la partie non affichee de chaque ligne ;
;   - deplacement fin (0..15 pixels) : BPLCON1, qui retarde l'affichage
;     du playfield ; on fetch un mot de plus par ligne (DDFSTRT recule
;     de 8 color clocks) pour avoir la matiere a decaler.
;
; Points AGA :
;   - BPLCON0 bit 4 (BPU3) = 8 bitplanes, bits 14-12 a zero ;
;   - 256 couleurs chargees par le copper en 8 banques de 32
;     (BPLCON3 BANK), chacune ecrite deux fois (LOCT) => 24 bits ;
;   - BPLCON4 = $00FF : les sprites prennent leurs couleurs dans la
;     banque $F (240..255), donc sans manger la palette de l'image ;
;   - en lores, 8 plans passent en fetch 16 bits (FMODE = 0) : le
;     scroll fin reste sur les bits classiques de BPLCON1.
;----------------------------------------------------------------------

	include	"hardware.i"

; --- ecran ---
SCRW		= 320
SCRH		= 256
FIRSTLINE	= $2c
DEPTH		= 8

; --- bitmap ---
BMW		= 640			; largeur en pixels
BMWB		= BMW/8			; 80 octets par ligne et par plan
BMH		= 384			; hauteur en lignes
PLSIZE		= BMWB*BMH		; 30720 octets par plan
BMSIZE		= PLSIZE*DEPTH		; 245760 octets au total

; --- fenetre de fetch : 21 mots au lieu de 20 (marge de scroll) ---
DDF_START	= $0030			; $0038 - 8 : un mot de plus
DDF_STOP	= $00d0
FETCHBYTES	= 42			; 21 mots
BPLMODULO	= BMWB-FETCHBYTES	; 38

; --- camera : X dans [16,304], Y dans [0,127] ---
PANX_MIN	= 16
PANX_AMP	= 288
PANY_AMP	= 128

; --- bande de scrolltext, en bas de l'ecran ---
SPLITLINE	= 236			; le playfield occupe 44..235
SCRTEXTH	= 64			; hauteur de la bande
SCRBPL		= 48			; 384 pixels de large, un seul plan
SCRMOD		= SCRBPL-FETCHBYTES
SCROLL_XOFF	= 16			; le fetch commence 16 px avant l'ecran
SCROLL_CHARS	= 22			; caracteres visibles au plus
SCROLL_SPEED	= 2			; pixels par image
SCROLL_BASEY	= 24			; ligne centrale de l'onde
CHARW		= 16

; --- barres copper derriere le texte ---
NBARS		= 3
BARSTEPS	= 32			; entrees d'un degrade
BAR_CENTER	= 32			; milieu de la bande
BAR_AMP		= 26			; amplitude du va-et-vient, en lignes

; --- palette ---
PALROT		= 240			; couleurs 0..239 en rotation
PALBANKSZ	= 264			; taille d'une banque dans la copperlist
COPMAXSIZE	= 4608

; --- structure decrivant une copperlist ---
li_Cop		= 0			; adresse de la liste
li_Pal		= 4			; premier mot BPLCON3 du bloc palette
li_Ptrs		= 8			; premier MOVE de BPL1PTH
li_Con1		= 12			; mot de valeur de BPLCON1
li_BarTab	= 16			; table des 64 mots de couleur des barres
li_SIZEOF	= 20

;======================================================================
	SECTION	scroll,CODE
;======================================================================

Start:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	4.w,a6
	lea	GfxName,a1
	moveq	#39,d0
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,GfxBase
	beq	ExitNoGfx

	move.l	#BMSIZE,d0		; le bitmap doit etre en Chip RAM
	move.l	#MEMF_CHIP|MEMF_CLEAR,d1
	jsr	_LVOAllocMem(a6)
	move.l	d0,BitmapBase
	beq	ExitNoMem

	bsr	GeneratePlayfield	; ~1 seconde, ecran encore noir

	move.l	4.w,a6
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

	bsr	InitDemo
	lea	PT_ModuleData,a0	; module ProTracker
	bsr	PT_Init

	move.w	#DMAF_SETCLR|DMAF_MASTER|DMAF_RASTER|DMAF_COPPER|DMAF_SPRITE|DMAF_BLITTER|DMAF_AUDIO,DMACON(a5)
	bsr	VBI_Install		; a partir d'ici, la trame nous appelle
	bsr	CIA_Install		; et le timer A bat la mesure

;----------------------------------------------------------------------
; Boucle principale : on batit la liste cachee, puis on l'offre a
; l'interruption de retour trame, qui seule la met a l'affiche et
; avance la musique (VBI_Frame, plus bas).
;----------------------------------------------------------------------
MainLoop:
	addq.w	#1,FrameCnt
	move.w	PalRot,d0		; rotation de la palette
	addq.w	#1,d0
	cmp.w	#PALROT,d0
	blt.s	.rotOk
	moveq	#0,d0
.rotOk:
	move.w	d0,PalRot

	move.l	BackRec,a0
	bsr	UpdateBitplanes		; pointeurs + scroll fin
	move.l	BackRec,a0
	bsr	UpdatePalette
	move.l	BackRec,a0
	bsr	UpdateBars
	bsr	MoveSprite
	bsr	ScrollUpdate
	move.w	#1,SwapReq		; la liste est prete a etre montree

.wait:
	bsr	VBI_Wait		; une trame passe
	tst.w	SwapReq			; l'a-t-elle prise ?
	bne.s	.wait

	btst	#6,CIAAPRA
	bne	MainLoop

	bsr	CIA_Remove
	bsr	VBI_Remove
	bsr	PT_Stop
	bsr	RestoreSystem
	move.l	4.w,a6
	jsr	_LVOPermit(a6)
ExitNoMem:
	move.l	BitmapBase,d0
	beq.s	.noFree
	move.l	d0,a1
	move.l	#BMSIZE,d0
	move.l	4.w,a6
	jsr	_LVOFreeMem(a6)
.noFree:
	move.l	GfxBase,a1
	move.l	4.w,a6
	jsr	_LVOCloseLibrary(a6)
ExitNoGfx:
	movem.l	(sp)+,d0-d7/a0-a6
	moveq	#0,d0
	rts

;----------------------------------------------------------------------
; Restitution de la machine au systeme (graphics.library fermee plus tard)
;----------------------------------------------------------------------
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
; InitDemo : construction des deux copperlists et premier remplissage
;----------------------------------------------------------------------
InitDemo:
	lea	Rec1,a0
	move.l	a0,FrontRec
	lea	BarTab1,a1
	move.l	a1,li_BarTab(a0)
	lea	Rec2,a0
	move.l	a0,BackRec
	lea	BarTab2,a1
	move.l	a1,li_BarTab(a0)

	lea	Rec1,a0
	lea	CopList1,a1
	bsr	BuildCopperList
	lea	Rec2,a0
	lea	CopList2,a1
	bsr	BuildCopperList

	clr.w	FrameCnt
	clr.w	PalRot
	lea	Rec1,a0
	bsr	UpdateBitplanes
	lea	Rec1,a0
	bsr	UpdatePalette
	lea	Rec2,a0
	bsr	UpdateBitplanes
	lea	Rec2,a0
	bsr	UpdatePalette
	lea	Rec1,a0
	bsr	UpdateBars
	lea	Rec2,a0
	bsr	UpdateBars
	bsr	MoveSprite
	bsr	ScrollInit

	lea	CUSTOM,a5
	move.l	FrontRec,a0
	move.l	li_Cop(a0),COP1LCH(a5)
	move.w	d0,COPJMP1(a5)
	rts

;----------------------------------------------------------------------
; BuildCopperList
;   a0 = structure a remplir, a1 = buffer de copperlist (Chip RAM)
;----------------------------------------------------------------------
BuildCopperList:
	movem.l	d0-d4/a0-a3,-(sp)
	move.l	a1,li_Cop(a0)
	move.l	a1,a2			; a2 = curseur d'ecriture

	move.w	#FMODE,(a2)+		; fetch 16 bits : suffisant en lores
	move.w	#$0000,(a2)+
	move.w	#BPLCON0,(a2)+
	move.w	#$0211,(a2)+		; BPU3 (8 plans) + COLOR + ECSENA
	move.w	#BPLCON2,(a2)+
	move.w	#$0024,(a2)+		; sprites devant le playfield
	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+
	move.w	#BPLCON4,(a2)+
	move.w	#$00ff,(a2)+		; sprites : banque de couleurs $F
	move.w	#DIWSTRT,(a2)+
	move.w	#$2c81,(a2)+
	move.w	#DIWSTOP,(a2)+
	move.w	#$2cc1,(a2)+
	move.w	#DDFSTRT,(a2)+
	move.w	#DDF_START,(a2)+	; un mot fetche en plus
	move.w	#DDFSTOP,(a2)+
	move.w	#DDF_STOP,(a2)+
	move.w	#BPL1MOD,(a2)+
	move.w	#BPLMODULO,(a2)+
	move.w	#BPL2MOD,(a2)+
	move.w	#BPLMODULO,(a2)+

	move.l	#Sprite0,d1		; pointeurs de sprites
	move.w	#$0120,d3
	moveq	#7,d4
.sprLoop:
	move.w	d3,(a2)+
	move.l	d1,d2
	swap	d2
	move.w	d2,(a2)+		; poids fort
	addq.w	#2,d3
	move.w	d3,(a2)+
	move.w	d1,(a2)+		; poids faible
	addq.w	#2,d3
	move.l	#NullSprite,d1		; sprites 1 a 7 : vides
	dbf	d4,.sprLoop

	; --- palette : 8 banques de 32 couleurs, chacune en deux passes ---
	move.l	a2,li_Pal(a0)
	moveq	#0,d1			; numero de banque
.bankLoop:
	move.w	d1,d2
	lsl.w	#8,d2
	lsl.w	#5,d2			; BANK dans les bits 15-13
	move.w	#BPLCON3,(a2)+
	move.w	d2,(a2)+		; LOCT = 0 : quartets hauts
	move.w	#COLOR00,d3
	moveq	#31,d4
.hiLoop:
	move.w	d3,(a2)+
	clr.w	(a2)+
	addq.w	#2,d3
	dbf	d4,.hiLoop
	move.w	#BPLCON3,(a2)+
	or.w	#$0200,d2
	move.w	d2,(a2)+		; LOCT = 1 : quartets bas
	move.w	#COLOR00,d3
	moveq	#31,d4
.loLoop:
	move.w	d3,(a2)+
	clr.w	(a2)+
	addq.w	#2,d3
	dbf	d4,.loLoop
	addq.w	#1,d1
	cmp.w	#8,d1
	blt.s	.bankLoop

	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+		; retour banque 0, LOCT = 0

	; --- pointeurs de bitplanes (mis a jour a chaque image) ---
	move.l	a2,li_Ptrs(a0)
	move.w	#BPL1PTH,d3
	moveq	#DEPTH-1,d4
.bplLoop:
	move.w	d3,(a2)+
	clr.w	(a2)+
	addq.w	#2,d3
	move.w	d3,(a2)+
	clr.w	(a2)+
	addq.w	#2,d3
	dbf	d4,.bplLoop

	move.w	#BPLCON1,(a2)+		; scroll fin (mis a jour par image)
	move.l	a2,li_Con1(a0)
	clr.w	(a2)+

	; --- bascule vers la bande de scrolltext ---
	; A partir de SPLITLINE le copper repasse a un seul bitplane, celui
	; du scroller, avec ses propres couleurs. Rien n'est a restaurer
	; ensuite : l'image suivante recharge tout depuis le haut de la liste.
	move.w	#(SPLITLINE<<8)|$07,(a2)+
	move.w	#$fffe,(a2)+
	move.w	#BPLCON0,(a2)+
	move.w	#$1201,(a2)+		; BPU = 1, COLOR, ECSENA
	move.w	#BPLCON1,(a2)+
	move.w	#$0000,(a2)+		; pas de scroll fin sur la bande
	move.w	#BPL1MOD,(a2)+
	move.w	#SCRMOD,(a2)+
	move.l	#ScrollBitmap,d1
	move.w	#BPL1PTH,(a2)+
	move.l	d1,d2
	swap	d2
	move.w	d2,(a2)+
	move.w	#BPL1PTH+2,(a2)+
	move.w	d1,(a2)+
	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+
	move.w	#COLOR01,(a2)+
	move.w	#$0fff,(a2)+		; texte : blanc
	move.w	#BPLCON3,(a2)+
	move.w	#$0200,(a2)+
	move.w	#COLOR01,(a2)+
	move.w	#$0fff,(a2)+
	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+

	; --- barres copper : COLOR00 change a chaque ligne de la bande ---
	move.l	li_BarTab(a0),a3
	move.w	#SPLITLINE,d3
	moveq	#0,d4
.barBlock:
	cmp.w	#256,d3
	bne.s	.barNoWrap
	move.w	#$ffdf,(a2)+		; franchissement de la ligne 255
	move.w	#$fffe,(a2)+
.barNoWrap:
	move.w	d3,d1
	lsl.w	#8,d1
	or.w	#$0007,d1
	move.w	d1,(a2)+
	move.w	#$fffe,(a2)+
	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+
	move.w	#COLOR00,(a2)+
	move.l	a2,(a3)+		; memorise pour UpdateBars
	clr.w	(a2)+
	move.w	#BPLCON3,(a2)+
	move.w	#$0200,(a2)+
	move.w	#COLOR00,(a2)+
	clr.w	(a2)+
	addq.w	#1,d3
	addq.w	#1,d4
	cmp.w	#SCRTEXTH,d4
	blt.s	.barBlock
	move.w	#BPLCON3,(a2)+
	move.w	#$0000,(a2)+

	move.l	#$fffffffe,(a2)+	; fin de copperlist
	movem.l	(sp)+,d0-d4/a0-a3
	rts

;----------------------------------------------------------------------
; UpdateBitplanes : position de camera -> pointeurs + BPLCON1
;   a0 = structure de la liste a mettre a jour
;
;   Le mot pointe contient les pixels [W*16 .. W*16+15] et le fetch
;   commence 16 pixels avant la fenetre d'affichage : le pixel visible
;   en colonne 0 vaut donc W*16 + 16 - delai. Pour afficher le pixel X :
;       W     = (X-1)>>4        delai = (-X) & 15
;----------------------------------------------------------------------
UpdateBitplanes:
	movem.l	d0-d7/a0-a2,-(sp)
	lea	SinTab,a2

	move.w	FrameCnt,d0		; X = 16 + sin * 288/256
	and.w	#255,d0
	moveq	#0,d1
	move.b	(a2,d0.w),d1
	mulu.w	#PANX_AMP,d1
	lsr.l	#8,d1
	add.w	#PANX_MIN,d1

	move.w	FrameCnt,d0		; Y = cos(3t) * 128/256
	add.w	d0,d0
	add.w	FrameCnt,d0		; *3
	add.w	#64,d0			; dephasage
	and.w	#255,d0
	moveq	#0,d2
	move.b	(a2,d0.w),d2
	mulu.w	#PANY_AMP,d2
	lsr.l	#8,d2

	move.w	d1,d3			; scroll fin : (-X) & 15
	neg.w	d3
	and.w	#15,d3
	move.w	d3,d4
	lsl.w	#4,d4
	or.w	d3,d4			; meme valeur pour PF1 et PF2
	move.l	li_Con1(a0),a1
	move.w	d4,(a1)

	move.w	d1,d3			; deplacement grossier : W = (X-1)>>4
	subq.w	#1,d3
	asr.w	#4,d3
	add.w	d3,d3			; en octets
	ext.l	d3
	move.w	d2,d4
	mulu.w	#BMWB,d4		; + Y lignes
	add.l	d4,d3
	add.l	BitmapBase,d3		; adresse du plan 0

	move.l	li_Ptrs(a0),a1
	moveq	#DEPTH-1,d0
.planeLoop:
	move.l	d3,d4
	swap	d4
	move.w	d4,2(a1)		; BPLxPTH
	move.w	d3,6(a1)		; BPLxPTL
	lea	8(a1),a1
	add.l	#PLSIZE,d3
	dbf	d0,.planeLoop

	movem.l	(sp)+,d0-d7/a0-a2
	rts

;----------------------------------------------------------------------
; UpdatePalette : recopie la palette (avec rotation) dans la copperlist
;   a0 = structure de la liste a mettre a jour
;   Les couleurs 0..239 tournent, 240..255 restent fixes (sprite).
;----------------------------------------------------------------------
UpdatePalette:
	movem.l	d0-d7/a0-a4,-(sp)
	move.l	li_Pal(a0),a1
	lea	PaletteTab,a2

	move.w	PalRot,d2		; index source de la couleur 0
	move.w	d2,d1
	lsl.w	#2,d1
	lea	(a2,d1.w),a3
	moveq	#0,d5			; index destination
.rotLoop:
	bsr	.writeEntry
	lea	4(a3),a3
	addq.w	#1,d2
	cmp.w	#PALROT,d2
	blt.s	.noWrap
	moveq	#0,d2
	move.l	a2,a3
.noWrap:
	addq.w	#1,d5
	cmp.w	#PALROT,d5
	blt.s	.rotLoop

	move.w	#PALROT*4,d1		; couleurs fixes 240..255
	lea	(a2,d1.w),a3
.fixLoop:
	bsr	.writeEntry
	lea	4(a3),a3
	addq.w	#1,d5
	cmp.w	#256,d5
	blt.s	.fixLoop

	movem.l	(sp)+,d0-d7/a0-a4
	rts

; d5 = index destination, a3 = entree source, a1 = base du bloc palette
.writeEntry:
	move.w	d5,d6
	lsr.w	#5,d6
	mulu.w	#PALBANKSZ,d6		; banque = index / 32
	move.w	d5,d7
	and.w	#31,d7
	lsl.w	#2,d7			; 4 octets par MOVE
	add.w	d7,d6
	lea	(a1,d6.w),a4
	move.w	(a3),6(a4)		; quartets hauts
	move.w	2(a3),138(a4)		; quartets bas
	rts

;----------------------------------------------------------------------
; GeneratePlayfield : plasma 8 plans dans le bitmap Chip
;   couleur = (sin(3x) + sin(5y) + sin(2(x+y))) * 80 / 256  -> 0..239
;   Conversion chunky -> planar par paquets de 16 pixels, en deux
;   passes de 4 plans (roxl.w recupere le bit sorti par lsr.b).
;----------------------------------------------------------------------
GeneratePlayfield:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	SinTab,a2
	move.l	BitmapBase,a6
	moveq	#0,d3			; y
.lineLoop:
	move.w	d3,d0			; sin(5y), constant sur la ligne
	add.w	d0,d0
	add.w	d0,d0
	add.w	d3,d0			; *5
	and.w	#255,d0
	moveq	#0,d2
	move.b	(a2,d0.w),d2
	move.w	d2,LineTerm

	move.w	d3,d0			; (x+y)*2 avec x = 0
	add.w	d0,d0
	move.w	d0,DiagAcc
	clr.w	XAcc

	move.l	a6,a3			; a3 = plan 0, ligne courante
	move.w	d3,d0
	mulu.w	#BMWB,d0
	add.l	d0,a3

	moveq	#0,d4			; compteur de mots
.wordLoop:
	; --- 16 couleurs dans le tampon ---
	lea	Scratch,a0
	move.w	XAcc,d0
	move.w	DiagAcc,d1
	move.w	LineTerm,d2
	moveq	#15,d5
.pixLoop:
	move.w	d0,d6
	and.w	#255,d6
	moveq	#0,d7
	move.b	(a2,d6.w),d7		; sin(3x)
	add.w	d2,d7			; + sin(5y)
	move.w	d1,d6
	and.w	#255,d6
	move.b	(a2,d6.w),d6
	and.w	#255,d6
	add.w	d6,d7			; + sin(2(x+y))
	mulu.w	#80,d7
	lsr.l	#8,d7			; -> 0..239
	move.b	d7,(a0)+
	addq.w	#3,d0
	addq.w	#2,d1
	dbf	d5,.pixLoop
	move.w	d0,XAcc
	move.w	d1,DiagAcc

	; --- plans 0 a 3 ---
	lea	Scratch,a0
	moveq	#0,d1
	moveq	#0,d2
	moveq	#0,d5
	moveq	#0,d6
	moveq	#15,d7
.c2pLow:
	move.b	(a0)+,d0
	lsr.b	#1,d0
	roxl.w	#1,d1
	lsr.b	#1,d0
	roxl.w	#1,d2
	lsr.b	#1,d0
	roxl.w	#1,d5
	lsr.b	#1,d0
	roxl.w	#1,d6
	dbf	d7,.c2pLow
	move.l	a3,a4
	move.w	d1,(a4)
	lea	PLSIZE(a4),a4
	move.w	d2,(a4)
	lea	PLSIZE(a4),a4
	move.w	d5,(a4)
	lea	PLSIZE(a4),a4
	move.w	d6,(a4)

	; --- plans 4 a 7 ---
	lea	Scratch,a0
	moveq	#0,d1
	moveq	#0,d2
	moveq	#0,d5
	moveq	#0,d6
	moveq	#15,d7
.c2pHigh:
	move.b	(a0)+,d0
	lsr.b	#4,d0
	lsr.b	#1,d0
	roxl.w	#1,d1
	lsr.b	#1,d0
	roxl.w	#1,d2
	lsr.b	#1,d0
	roxl.w	#1,d5
	lsr.b	#1,d0
	roxl.w	#1,d6
	dbf	d7,.c2pHigh
	lea	PLSIZE(a4),a4
	move.w	d1,(a4)
	lea	PLSIZE(a4),a4
	move.w	d2,(a4)
	lea	PLSIZE(a4),a4
	move.w	d5,(a4)
	lea	PLSIZE(a4),a4
	move.w	d6,(a4)

	addq.w	#2,a3			; mot suivant
	addq.w	#1,d4
	cmp.w	#BMW/16,d4
	blt	.wordLoop

	addq.w	#1,d3
	cmp.w	#BMH,d3
	blt	.lineLoop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; MoveSprite : la boule, en couleurs 241..243 (banque $F via BPLCON4)
;----------------------------------------------------------------------
MoveSprite:
	movem.l	d0-d4/a2,-(sp)
	lea	SinTab,a2
	move.w	FrameCnt,d0
	add.w	d0,d0			; deux fois plus vite que la camera

	move.w	d0,d1
	and.w	#255,d1
	moveq	#0,d2
	move.b	(a2,d1.w),d2
	sub.w	#128,d2
	muls.w	#7,d2
	asr.w	#3,d2
	add.w	#152,d2			; X ecran

	move.w	d0,d1
	add.w	#64,d1
	and.w	#255,d1
	moveq	#0,d3
	move.b	(a2,d1.w),d3
	sub.w	#128,d3
	muls.w	#5,d3
	asr.w	#3,d3
	add.w	#120,d3			; Y ecran

	add.w	#$0080,d2
	add.w	#FIRSTLINE,d3
	move.w	d3,d4
	add.w	#16,d4			; VSTOP = VSTART + 16

	move.w	d3,d0
	lsl.w	#8,d0
	move.w	d2,d1
	lsr.w	#1,d1
	and.w	#$00ff,d1
	or.w	d1,d0
	move.w	d0,Sprite0		; SPR0POS

	move.w	d4,d0
	lsl.w	#8,d0
	move.w	d2,d1
	and.w	#1,d1
	or.w	d1,d0
	btst	#8,d3
	beq.s	.noVStartHi
	or.w	#%100,d0
.noVStartHi:
	btst	#8,d4
	beq.s	.noVStopHi
	or.w	#%10,d0
.noVStopHi:
	move.w	d0,Sprite0+2		; SPR0CTL
	movem.l	(sp)+,d0-d4/a2
	rts

;----------------------------------------------------------------------
; UpdateBars : trois barres qui se croisent derriere le texte
;   a0 = structure de la liste a mettre a jour
;
; Chaque barre a son degrade (distance au centre -> couleur) ; les trois
; sont additionnees ligne par ligne et saturees, d'ou le blanc a leurs
; croisements. Le resultat est ecrit dans les MOVE de COLOR00 de la
; bande, en 24 bits comme le reste (deux ecritures, LOCT a 0 puis a 1).
;----------------------------------------------------------------------
UpdateBars:
	movem.l	d0-d7/a0-a4,-(sp)
	move.l	li_BarTab(a0),a4

	lea	BarDefs,a2		; centre courant de chaque barre
	lea	BarCenters,a3
	lea	SinTab,a1
	moveq	#NBARS-1,d7
.centerLoop:
	move.w	(a2),d0			; vitesse
	mulu.w	FrameCnt,d0
	add.w	2(a2),d0		; dephasage
	and.w	#255,d0
	moveq	#0,d1
	move.b	(a1,d0.w),d1
	sub.w	#128,d1
	muls.w	#BAR_AMP,d1
	asr.w	#7,d1
	add.w	#BAR_CENTER,d1
	move.w	d1,(a3)+
	lea	8(a2),a2
	dbf	d7,.centerLoop

	moveq	#0,d6			; ligne dans la bande
.lineLoop:
	moveq	#0,d2			; rouge
	moveq	#0,d3			; vert
	moveq	#0,d4			; bleu
	lea	BarDefs,a2
	lea	BarCenters,a3
	moveq	#NBARS-1,d7
.barLoop:
	move.w	(a3)+,d0
	sub.w	d6,d0			; distance de la ligne au centre
	bpl.s	.posDist
	neg.w	d0
.posDist:
	cmp.w	#BARSTEPS,d0
	bge.s	.barNext
	lsl.w	#2,d0			; 4 octets par entree
	move.l	4(a2),a1
	add.w	d0,a1
	moveq	#0,d1
	move.b	1(a1),d1
	add.w	d1,d2
	move.b	2(a1),d1
	add.w	d1,d3
	move.b	3(a1),d1
	add.w	d1,d4
.barNext:
	lea	8(a2),a2
	dbf	d7,.barLoop

	cmp.w	#255,d2			; saturation des trois composantes
	ble.s	.rOk
	move.w	#255,d2
.rOk:
	cmp.w	#255,d3
	ble.s	.gOk
	move.w	#255,d3
.gOk:
	cmp.w	#255,d4
	ble.s	.bOk
	move.w	#255,d4
.bOk:
	move.w	d2,d0			; quartets hauts
	lsr.w	#4,d0
	lsl.w	#8,d0
	move.w	d3,d1
	lsr.w	#4,d1
	lsl.w	#4,d1
	or.w	d1,d0
	move.w	d4,d1
	lsr.w	#4,d1
	or.w	d1,d0
	move.w	d2,d1			; quartets bas
	and.w	#15,d1
	lsl.w	#8,d1
	move.w	d3,d5
	and.w	#15,d5
	lsl.w	#4,d5
	or.w	d5,d1
	move.w	d4,d5
	and.w	#15,d5
	or.w	d5,d1

	move.l	(a4)+,a1
	move.w	d0,(a1)			; COLOR00 poids forts
	move.w	d1,8(a1)		; COLOR00 poids faibles
	addq.w	#1,d6
	cmp.w	#SCRTEXTH,d6
	blt	.lineLoop
	movem.l	(sp)+,d0-d7/a0-a4
	rts

;----------------------------------------------------------------------
; ScrollInit : longueur du texte et position de depart
;----------------------------------------------------------------------
ScrollInit:
	lea	ScrollText,a0
	moveq	#0,d0
.count:
	tst.b	(a0)+
	beq.s	.done
	addq.w	#1,d0
	bra.s	.count
.done:
	move.w	d0,ScrollLen
	clr.w	ScrollChar
	clr.w	ScrollFine
	clr.w	ScrollPhase
	rts

;----------------------------------------------------------------------
; ScrollUpdate : efface la bande et redessine les caracteres visibles
;
; L'onde est fixe dans l'espace : la hauteur d'un caractere ne depend que
; de son abscisse, le texte la traverse. Chaque caractere est donc
; redessine a chaque image, ce que le blitter fait sans effort : 22 blits
; de 16 lignes sur deux mots, tous dans le VBlank.
;----------------------------------------------------------------------
ScrollUpdate:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	CUSTOM,a6

	move.w	ScrollFine,d0		; avance du texte
	add.w	#SCROLL_SPEED,d0
.advance:
	cmp.w	#CHARW,d0
	blt.s	.advanceDone
	sub.w	#CHARW,d0
	move.w	ScrollChar,d1
	addq.w	#1,d1
	cmp.w	ScrollLen,d1
	blt.s	.charOk
	moveq	#0,d1
.charOk:
	move.w	d1,ScrollChar
	bra.s	.advance
.advanceDone:
	move.w	d0,ScrollFine

	bsr	WaitBlit		; effacement de la bande : D seul,
	move.w	#BLT_USED,BLTCON0(a6)	; minterme 0 donc on ecrit des zeros
	clr.w	BLTCON1(a6)
	clr.w	BLTDMOD(a6)
	move.l	#ScrollBitmap,BLTDPT(a6)
	move.w	#(SCRTEXTH<<6)|(SCRBPL/2),BLTSIZE(a6)

	move.w	ScrollChar,d6		; caractere le plus a gauche
	move.w	ScrollFine,d7
	neg.w	d7
	add.w	#SCROLL_XOFF,d7		; son abscisse dans le bitmap
	moveq	#SCROLL_CHARS-1,d5
.charLoop:
	lea	ScrollText,a0
	move.w	d6,d0
	moveq	#0,d1
	move.b	(a0,d0.w),d1
	sub.w	#FONTCHARS,d1		; hors table : rien a dessiner
	bmi.s	.skip
	cmp.w	#FONTLAST-FONTCHARS+1,d1
	bge.s	.skip
	lea	FontMap,a1
	moveq	#0,d2
	move.b	(a1,d1.w),d2
	cmp.w	#$ff,d2
	beq.s	.skip
	lsl.w	#6,d2			; 64 octets par glyphe
	lea	FontData,a0
	add.w	d2,a0

	move.w	d7,d3			; hauteur : sinus de l'abscisse
	add.w	d3,d3
	add.w	ScrollPhase,d3
	and.w	#255,d3
	lea	SinTab,a1
	moveq	#0,d4
	move.b	(a1,d3.w),d4
	sub.w	#128,d4
	muls.w	#3,d4
	asr.w	#4,d4			; +/- 24 lignes
	add.w	#SCROLL_BASEY,d4

	move.w	d7,d0
	move.w	d4,d1
	bsr	BlitChar
.skip:
	add.w	#CHARW,d7
	addq.w	#1,d6
	cmp.w	ScrollLen,d6
	blt.s	.wrapOk
	moveq	#0,d6
.wrapOk:
	dbf	d5,.charLoop

	move.w	ScrollPhase,d0		; derive lente de l'onde
	addq.w	#1,d0
	and.w	#255,d0
	move.w	d0,ScrollPhase
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; BlitChar : un glyphe 16x16 dans la bande
;   d0 = x, d1 = y, a0 = glyphe, a6 = CUSTOM
;
; Le decalage de 0 a 15 pixels est fait par le barrel shifter du canal A ;
; c'est pour cela que la source fait deux mots de large, le second nul.
; Minterme $FA : D = A OR C, le glyphe se superpose au fond.
;----------------------------------------------------------------------
BlitChar:
	movem.l	d0-d4/a0,-(sp)
	move.w	d0,d2
	and.w	#15,d2
	ror.w	#4,d2			; decalage dans les bits 15-12
	or.w	#BLT_USEA|BLT_USEC|BLT_USED|BLT_A_OR_C,d2

	move.w	d1,d3
	mulu.w	#SCRBPL,d3		; y * octets par ligne
	move.w	d0,d4
	lsr.w	#4,d4
	add.w	d4,d4			; mot de destination
	ext.l	d4
	add.l	d4,d3
	add.l	#ScrollBitmap,d3

	bsr	WaitBlit
	move.w	d2,BLTCON0(a6)
	clr.w	BLTCON1(a6)
	move.w	#-1,BLTAFWM(a6)
	move.w	#-1,BLTALWM(a6)
	clr.w	BLTAMOD(a6)		; source : exactement deux mots
	move.w	#SCRBPL-4,BLTCMOD(a6)
	move.w	#SCRBPL-4,BLTDMOD(a6)
	move.l	a0,BLTAPT(a6)
	move.l	d3,BLTCPT(a6)
	move.l	d3,BLTDPT(a6)
	move.w	#(16<<6)|2,BLTSIZE(a6)	; ecrire BLTSIZE lance le blit
	movem.l	(sp)+,d0-d4/a0
	rts

;----------------------------------------------------------------------
WaitBlit:
	tst.w	DMACONR(a6)		; lecture a vide : bug connu du 68000
.wait:
	btst	#6,DMACONR(a6)		; BBUSY
	bne.s	.wait
	rts

;----------------------------------------------------------------------
; VBI_Frame : le travail cadence, appele depuis l'interruption de
; retour trame. a5 = CUSTOM, tous les registres sont libres.
;
; L'echange n'a lieu que si la boucle principale a fini sa liste
; (SwapReq) : une trame en avance montrerait sinon des barres a moitie
; posees et un scroll a cheval sur deux images.
;----------------------------------------------------------------------
VBI_Frame:
	tst.w	SwapReq
	beq.s	.noSwap
	clr.w	SwapReq
	move.l	BackRec,a0		; la liste preparee devient visible
	move.l	li_Cop(a0),d0
	move.l	d0,COP1LCH(a5)
	move.w	d0,COPJMP1(a5)

	move.l	FrontRec,d0		; echange front / back
	move.l	BackRec,d1
	move.l	d1,FrontRec
	move.l	d0,BackRec
.noSwap:
	rts				; la musique, elle, suit le timer A

; CIA_Tick : le tic du module, appele par le timer A.
CIA_Tick:
	bsr	PT_Tick
	rts

; --- retour trame, timer et replayer : dans cette meme section ---
	include	"vblank.i"
	include	"ciatimer.i"
	include	"ptreplay.i"

;======================================================================
	SECTION	scrolldata,DATA
;======================================================================

GfxName:	dc.b	"graphics.library",0
	even

	include	"sine.i"
	include	"palette.i"
	include	"bars.i"

; Une barre : vitesse, dephasage, adresse de son degrade.
BarDefs:
	dc.w	2,0
	dc.l	BarGrad0
	dc.w	3,85
	dc.l	BarGrad1
	dc.w	5,170
	dc.l	BarGrad2

ScrollText:
	dc.b	"   BIENVENUE SUR AMIGA 1200 !   "
	dc.b	"8 BITPLANES AGA, 256 COULEURS EN 24 BITS VRAIES, "
	dc.b	"SCROLLING 100 POUR 100 MATÉRIEL, "
	dc.b	"UN SPRITE, UN PLASMA ET PROTRACKER SUR PAULA...   "
	dc.b	"LE COPPER FAIT LE RESTE.   "
	dc.b	"BOUTON GAUCHE POUR SORTIR.        ",0
	even

;======================================================================
	SECTION	chipdata,DATA_C
;======================================================================

Sprite0:
	dc.w	$0000,$0000		; SPR0POS / SPR0CTL
	include	"sprite.i"

NullSprite:
	dc.w	$0000,$0000

	include	"font.i"		; source du blitter : doit etre en Chip

;======================================================================
	SECTION	scrollbss,BSS
;======================================================================

GfxBase:	ds.l	1
BitmapBase:	ds.l	1
OldView:	ds.l	1
OldCopper:	ds.l	1
FrontRec:	ds.l	1
BackRec:	ds.l	1
Rec1:		ds.b	li_SIZEOF
Rec2:		ds.b	li_SIZEOF
OldIntena:	ds.w	1
OldDmacon:	ds.w	1
FrameCnt:	ds.w	1
SwapReq:	ds.w	1
VBI_Vbr:	ds.l	1
VBI_OldLvl3:	ds.l	1
VBI_Count:	ds.w	1
VBI_Flag:	ds.w	1
CIA_Vbr:	ds.l	1
CIA_OldLvl6:	ds.l	1
CIA_Count:	ds.w	1
CIA_Bpm:	ds.w	1
PalRot:		ds.w	1
BarCenters:	ds.w	NBARS
BarTab1:	ds.l	SCRTEXTH
BarTab2:	ds.l	SCRTEXTH
ScrollLen:	ds.w	1
ScrollChar:	ds.w	1
ScrollFine:	ds.w	1
ScrollPhase:	ds.w	1
XAcc:		ds.w	1
DiagAcc:	ds.w	1
LineTerm:	ds.w	1
Scratch:	ds.b	16
	even

;======================================================================
	SECTION	copbuffers,BSS_C
;======================================================================

CopList1:	ds.b	COPMAXSIZE
CopList2:	ds.b	COPMAXSIZE
ScrollBitmap:	ds.b	SCRBPL*SCRTEXTH

