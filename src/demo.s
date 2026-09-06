;----------------------------------------------------------------------
; demo.s - Demo AGA : degrade copper 24 bits + sprite hardware
;
; Cible   : Amiga 1200 (AGA), AmigaOS 3.1+, 68020+
; Ecran   : PAL lores 320x256, 0 bitplane (le fond est genere par le
;           copper), 1 sprite materiel 16x16 en mouvement sinusoidal.
; Sortie  : bouton gauche de la souris.
;
; Style "prise de controle" (demo/jeu) : on coupe proprement l'affichage
; systeme (LoadView(NULL)), on sauvegarde DMACON/INTENA et la copperlist
; du systeme, puis on rend tout a l'OS en quittant.
;
; Ce qui est specifiquement AGA :
;   - BPLCON3 bit 9 (LOCT) : chaque couleur est ecrite en deux temps,
;     nibbles hauts puis nibbles bas => 24 bits reels (pas de banding
;     comme sur les 12 bits de l'OCS/ECS).
;   - BPLCON4 : ESPRM/OSPRM (banque de palette des sprites).
;   - FMODE   : largeur de fetch (0 = compatible OCS, 16 bits).
;----------------------------------------------------------------------

	include	"hardware.i"

NUMLINES	= 256			; lignes affichees
FIRSTLINE	= $2c			; premiere ligne visible (PAL)
SPRHEIGHT	= 16
COPMAXSIZE	= 128+NUMLINES*20+16	; taille d'une copperlist

;======================================================================
	SECTION	demo,CODE
;======================================================================

Start:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	4.w,a6			; ExecBase
	lea	GfxName,a1
	moveq	#39,d0			; V39 = Kickstart 3.0/3.1
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,GfxBase
	beq	ExitNoGfx		; pas de graphics.library : on ressort
	jsr	_LVOForbid(a6)		; apres OpenLibrary (qui peut attendre)

	move.l	GfxBase,a6
	move.l	gb_ActiView(a6),OldView
	move.l	gb_copinit(a6),OldCopper
	sub.l	a1,a1
	jsr	_LVOLoadView(a6)	; LoadView(NULL) : plus d'affichage OS
	jsr	_LVOWaitTOF(a6)
	jsr	_LVOWaitTOF(a6)
	jsr	_LVOOwnBlitter(a6)
	jsr	_LVOWaitBlit(a6)

	lea	CUSTOM,a5
	move.w	INTENAR(a5),d0		; sauvegarde de l'etat systeme
	or.w	#DMAF_SETCLR,d0
	move.w	d0,OldIntena
	move.w	DMACONR(a5),d0
	or.w	#DMAF_SETCLR,d0
	move.w	d0,OldDmacon

	move.w	#$7fff,INTENA(a5)	; interruptions coupees
	move.w	#$7fff,INTREQ(a5)
	move.w	#$7fff,DMACON(a5)	; tout le DMA coupe

	bsr	InitDemo
	bsr	PT_Init			; module ProTracker

	move.w	#DMAF_SETCLR|DMAF_MASTER|DMAF_RASTER|DMAF_COPPER|DMAF_SPRITE|DMAF_BLITTER|DMAF_AUDIO,DMACON(a5)

;----------------------------------------------------------------------
; Boucle principale : une image = un echange de copperlist + un rendu
;----------------------------------------------------------------------
MainLoop:
	bsr	WaitVBlank

	move.l	BackCop,d0		; la liste construite devient visible
	move.l	d0,COP1LCH(a5)
	move.w	d0,COPJMP1(a5)		; strobe : le copper repart en haut

	move.l	FrontCop,d1		; echange front / back
	move.l	d0,FrontCop
	move.l	d1,BackCop
	move.l	FrontPtrTab,d0
	move.l	BackPtrTab,d1
	move.l	d1,FrontPtrTab
	move.l	d0,BackPtrTab

	bsr	PT_Tick			; un tick de musique par image

	addq.w	#2,FrameCnt
	move.l	BackPtrTab,a0
	bsr	BuildGradient		; on remplit la liste cachee
	bsr	MoveSprite

	btst	#6,CIAAPRA		; bouton gauche souris ?
	bne	MainLoop

	bsr	PT_Stop
	bsr	RestoreSystem
	move.l	4.w,a6
	jsr	_LVOPermit(a6)
ExitNoGfx:
	movem.l	(sp)+,d0-d7/a0-a6
	moveq	#0,d0
	rts

;----------------------------------------------------------------------
; Restitution complete de la machine au systeme
;----------------------------------------------------------------------
RestoreSystem:
	lea	CUSTOM,a5
	move.w	#$7fff,INTENA(a5)
	move.w	#$7fff,INTREQ(a5)
	move.w	#$7fff,DMACON(a5)
	move.l	OldCopper,COP1LCH(a5)	; copperlist du systeme
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
	move.l	a6,a1
	move.l	4.w,a6
	jsr	_LVOCloseLibrary(a6)
	rts

;----------------------------------------------------------------------
; Preparation des deux copperlists et du premier rendu
;----------------------------------------------------------------------
InitDemo:
	lea	CopList1,a0
	move.l	a0,FrontCop
	lea	CopList2,a0
	move.l	a0,BackCop
	lea	PtrTab1,a0
	move.l	a0,FrontPtrTab
	lea	PtrTab2,a0
	move.l	a0,BackPtrTab

	lea	CopList1,a0
	lea	PtrTab1,a1
	bsr	BuildCopperList
	lea	CopList2,a0
	lea	PtrTab2,a1
	bsr	BuildCopperList

	clr.w	FrameCnt
	move.l	FrontPtrTab,a0
	bsr	BuildGradient
	move.l	BackPtrTab,a0
	bsr	BuildGradient
	bsr	MoveSprite

	lea	CUSTOM,a5
	move.l	FrontCop,COP1LCH(a5)
	move.w	d0,COPJMP1(a5)
	rts

;----------------------------------------------------------------------
; BuildCopperList
;   a0 = buffer copperlist (memoire CHIP)
;   a1 = table de 256 pointeurs (adresse du mot "nibbles hauts")
;
; Structure generee, pour chaque ligne ecran :
;   WAIT ligne
;   BPLCON3 = $0000  /  COLOR00 = nibbles hauts
;   BPLCON3 = $0200  /  COLOR00 = nibbles bas     <- LOCT, specifique AGA
;----------------------------------------------------------------------
BuildCopperList:
	movem.l	d0-d3/a0-a3,-(sp)
	move.l	a0,a3			; debut de la liste
	lea	CopHeader,a2
	move.w	#(CopHeaderEnd-CopHeader)/2-1,d0
.copyHeader:
	move.w	(a2)+,(a0)+
	dbf	d0,.copyHeader

	lea	(CopSprPtrs-CopHeader)(a3),a2	; pointeurs de sprites
	move.l	#Sprite0,d1			; sprite 0 = la boule
	moveq	#7,d2
.sprLoop:
	move.l	d1,d3
	swap	d3
	move.w	d3,2(a2)		; poids fort
	move.w	d1,6(a2)		; poids faible
	lea	8(a2),a2
	move.l	#NullSprite,d1		; sprites 1 a 7 = sprite vide
	dbf	d2,.sprLoop

	moveq	#0,d0			; compteur de lignes
	move.w	#FIRSTLINE,d2		; position verticale courante
.lineLoop:
	cmp.w	#256,d2
	bne.s	.noWrap
	move.w	#$ffdf,(a0)+		; franchissement de la ligne 255
	move.w	#$fffe,(a0)+
.noWrap:
	move.w	d2,d3
	lsl.w	#8,d3
	or.w	#$0007,d3
	move.w	d3,(a0)+		; WAIT (ligne, position horiz. $07)
	move.w	#$fffe,(a0)+
	move.w	#BPLCON3,(a0)+
	move.w	#$0000,(a0)+		; LOCT = 0
	move.w	#COLOR00,(a0)+
	move.l	a0,(a1)+		; memorise pour BuildGradient
	clr.w	(a0)+
	move.w	#BPLCON3,(a0)+
	move.w	#$0200,(a0)+		; LOCT = 1
	move.w	#COLOR00,(a0)+
	clr.w	(a0)+
	addq.w	#1,d2
	addq.w	#1,d0
	cmp.w	#NUMLINES,d0
	blt.s	.lineLoop

	move.w	#BPLCON3,(a0)+
	move.w	#$0000,(a0)+		; on laisse LOCT a 0
	move.l	#$fffffffe,(a0)+	; fin de copperlist
	movem.l	(sp)+,d0-d3/a0-a3
	rts

;----------------------------------------------------------------------
; BuildGradient : calcule le degrade de l'image courante
;   a0 = table de pointeurs de la liste a remplir
; Trois sinus dephases de 120 degres => arc-en-ciel defilant, en 24 bits.
;----------------------------------------------------------------------
BuildGradient:
	movem.l	d0-d7/a0-a2,-(sp)
	lea	SinTab,a2
	move.w	FrameCnt,d7
	moveq	#0,d6			; numero de ligne
.lineLoop:
	move.w	d6,d0
	add.w	d0,d0			; deux barres par ecran
	add.w	d7,d0			; defilement

	move.w	d0,d1
	and.w	#255,d1
	moveq	#0,d2
	move.b	(a2,d1.w),d2		; rouge
	move.w	d0,d1
	add.w	#85,d1
	and.w	#255,d1
	moveq	#0,d3
	move.b	(a2,d1.w),d3		; vert
	move.w	d0,d1
	add.w	#170,d1
	and.w	#255,d1
	moveq	#0,d4
	move.b	(a2,d1.w),d4		; bleu

	move.w	d2,d5			; nibbles hauts : $0RGB
	lsr.w	#4,d5
	lsl.w	#8,d5
	move.w	d3,d1
	lsr.w	#4,d1
	lsl.w	#4,d1
	or.w	d1,d5
	move.w	d4,d1
	lsr.w	#4,d1
	or.w	d1,d5

	and.w	#15,d2			; nibbles bas : $0rgb
	lsl.w	#8,d2
	and.w	#15,d3
	lsl.w	#4,d3
	and.w	#15,d4
	move.w	d2,d1
	or.w	d3,d1
	or.w	d4,d1

	move.l	(a0)+,a1
	move.w	d5,(a1)			; COLOR00 poids forts
	move.w	d1,8(a1)		; COLOR00 poids faibles

	addq.w	#1,d6
	cmp.w	#NUMLINES,d6
	blt.s	.lineLoop
	movem.l	(sp)+,d0-d7/a0-a2
	rts

;----------------------------------------------------------------------
; MoveSprite : trajectoire de Lissajous, ecriture de SPR0POS / SPR0CTL
;----------------------------------------------------------------------
MoveSprite:
	movem.l	d0-d4/a2,-(sp)
	lea	SinTab,a2
	move.w	FrameCnt,d0

	move.w	d0,d1			; X = 152 + sin * 112/128
	and.w	#255,d1
	moveq	#0,d2
	move.b	(a2,d1.w),d2
	sub.w	#128,d2
	muls.w	#7,d2
	asr.w	#3,d2
	add.w	#152,d2

	move.w	d0,d1			; Y = 120 + cos * 80/128
	add.w	#64,d1			; +90 degres
	and.w	#255,d1
	moveq	#0,d3
	move.b	(a2,d1.w),d3
	sub.w	#128,d3
	muls.w	#5,d3
	asr.w	#3,d3
	add.w	#120,d3

	add.w	#$0080,d2		; -> coordonnee materielle horizontale
	add.w	#FIRSTLINE,d3		; -> coordonnee materielle verticale
	move.w	d3,d4
	add.w	#SPRHEIGHT,d4		; VSTOP

	move.w	d3,d0			; SPR0POS : VSTART<<8 | HSTART>>1
	lsl.w	#8,d0
	move.w	d2,d1
	lsr.w	#1,d1
	and.w	#$00ff,d1
	or.w	d1,d0
	move.w	d0,Sprite0

	move.w	d4,d0			; SPR0CTL : VSTOP<<8 | bits hauts
	lsl.w	#8,d0
	move.w	d2,d1
	and.w	#1,d1			; HSTART bit 0
	or.w	d1,d0
	btst	#8,d3
	beq.s	.noVStartHi
	or.w	#%100,d0		; VSTART bit 8
.noVStartHi:
	btst	#8,d4
	beq.s	.noVStopHi
	or.w	#%10,d0			; VSTOP bit 8
.noVStopHi:
	move.w	d0,Sprite0+2
	movem.l	(sp)+,d0-d4/a2
	rts

;----------------------------------------------------------------------
; WaitVBlank (a5 = CUSTOM) - lecture longue de VPOSR/VHPOSR
;----------------------------------------------------------------------
WaitVBlank:
	move.l	d0,-(sp)
.wait:
	move.l	VPOSR(a5),d0
	and.l	#$0001ff00,d0
	cmp.l	#300<<8,d0
	bne.s	.wait
	move.l	(sp)+,d0
	rts

; --- replayer ProTracker : son code reste dans cette section ---
	include	"ptreplay.i"

;======================================================================
	SECTION	demodata,DATA
;======================================================================

GfxName:	dc.b	"graphics.library",0
	even

; Modele de copperlist : entete recopie en tete de chaque liste.
CopHeader:
	dc.w	FMODE,$0000		; fetch 16 bits (compatible OCS)
	dc.w	BPLCON0,$0200		; 0 bitplane, sortie couleur active
	dc.w	BPLCON1,$0000
	dc.w	BPLCON2,$0024		; sprites devant le playfield
	dc.w	BPLCON3,$0000		; banque 0, LOCT = 0
	dc.w	BPLCON4,$0011		; palette sprites 16..31 (comme OCS)
	dc.w	BPL1MOD,$0000
	dc.w	BPL2MOD,$0000
	dc.w	DIWSTRT,$2c81		; fenetre 320x256
	dc.w	DIWSTOP,$2cc1
	dc.w	DDFSTRT,$0038
	dc.w	DDFSTOP,$00d0
CopSprPtrs:
	dc.w	$0120,$0000,$0122,$0000	; SPR0PT .. SPR7PT (remplis au runtime)
	dc.w	$0124,$0000,$0126,$0000
	dc.w	$0128,$0000,$012a,$0000
	dc.w	$012c,$0000,$012e,$0000
	dc.w	$0130,$0000,$0132,$0000
	dc.w	$0134,$0000,$0136,$0000
	dc.w	$0138,$0000,$013a,$0000
	dc.w	$013c,$0000,$013e,$0000
	dc.w	BPLCON3,$0000		; couleurs du sprite, nibbles hauts
	dc.w	COLOR17,$0fff		; $ffffff
	dc.w	COLOR18,$07af		; $70a0ff
	dc.w	COLOR19,$0126		; $102060
	dc.w	BPLCON3,$0200		; nibbles bas (AGA)
	dc.w	COLOR17,$0fff
	dc.w	COLOR18,$000f
	dc.w	COLOR19,$0000
	dc.w	BPLCON3,$0000
CopHeaderEnd:

	include	"sine.i"

;======================================================================
	SECTION	chipdata,DATA_C		; doit resider en memoire CHIP
;======================================================================

Sprite0:
	dc.w	$0000,$0000		; SPR0POS / SPR0CTL (mis a jour par frame)
	include	"sprite.i"

NullSprite:
	dc.w	$0000,$0000		; sprite vide pour les canaux 1 a 7

;======================================================================
	SECTION	demobss,BSS
;======================================================================

GfxBase:	ds.l	1
OldView:	ds.l	1
OldCopper:	ds.l	1
FrontCop:	ds.l	1
BackCop:	ds.l	1
FrontPtrTab:	ds.l	1
BackPtrTab:	ds.l	1
OldIntena:	ds.w	1
OldDmacon:	ds.w	1
FrameCnt:	ds.w	1
PtrTab1:	ds.l	NUMLINES
PtrTab2:	ds.l	NUMLINES

;======================================================================
	SECTION	copbuffers,BSS_C	; copperlists en memoire CHIP
;======================================================================

CopList1:	ds.b	COPMAXSIZE
CopList2:	ds.b	COPMAXSIZE

