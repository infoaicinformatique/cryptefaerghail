;----------------------------------------------------------------------
; ptreplay.i - replayer ProTracker 4 voies pour Paula
;
; A inclure a la fin de la SECTION de code du programme : le code du
; replayer se place dans cette section (les bsr restent internes au hunk),
; puis le fichier declare ses propres sections de donnees.
; Interface :
;   PT_Init   ouvre le module (incbin) et prepare les canaux
;   PT_Tick   a appeler une fois par image (50 Hz) : c'est la cadence
;   PT_Stop   coupe le DMA audio et rend le filtre a son etat d'origine
; Toutes preservent l'integralite des registres.
;
; Effets gerees : 0xy arpege, 1xx / 2xx portamento, 3xx portamento vers la
; note, Axy volume slide, Cxx volume, Fxx vitesse (ticks par ligne), Bxx
; saut de position, Dxx break. Les autres sont ignores, de meme que le
; finetune : c'est un sous-ensemble, pas un replayer ProTracker complet.
;
; Sequence de lancement d'une note, telle que Paula l'exige :
;   1. couper le DMA du canal ;
;   2. ecrire AUDxLC / AUDxLEN / AUDxPER / AUDxVOL ;
;   3. attendre deux lignes raster (Paula doit voir le canal a l'arret) ;
;   4. relancer le DMA ;
;   5. a l'appel suivant seulement, ecrire le point de boucle dans
;      AUDxLC / AUDxLEN : Paula a alors deja charge l'adresse de depart.
;----------------------------------------------------------------------

; --- structure de canal (longs alignes sur 4) ---
chn_Data	= 0			; long : debut du sample joue
chn_RepData	= 4			; long : point de boucle
chn_AudBase	= 8			; long : registres Paula du canal
chn_Len		= 12			; word : longueur en mots
chn_RepLen	= 14			; word : longueur de boucle en mots
chn_Period	= 16			; word : periode de la note
chn_Volume	= 18			; word
chn_Effect	= 20			; word
chn_Param	= 22			; word
chn_Porta	= 24			; word : periode visee (effet 3)
chn_PortaSpd	= 26			; word
chn_ArpPos	= 28			; word : 0, 1 ou 2
chn_Trigger	= 30			; word : note a lancer
chn_SetRep	= 32			; word : boucle a armer au prochain tick
chn_DmaBit	= 34			; word
chn_PlayPer	= 36			; word : periode reellement envoyee
chn_VibPos	= 38			; word : position dans la sinusoide
chn_VibCmd	= 40			; word : vitesse et amplitude (4xy)
chn_TremPos	= 42			; word
chn_TremCmd	= 44			; word (7xy)
chn_Offset	= 46			; word : depart dans le sample (9xx)
chn_Retrig	= 48			; word : relance tous les n tics (E9x)
chn_CutAt	= 50			; word : tic ou la note se tait (ECx)
chn_DelayTo	= 52			; word : tic ou la note part (EDx)
chn_HeldPer	= 54			; word : periode gardee sous le coude
chn_HeldIns	= 56			; word : instrument idem
chn_RealVol	= 58			; word : volume hors tremolo
chn_SIZEOF	= 60

; --- table d'instruments ---
ins_Data	= 0			; long
ins_RepData	= 4			; long
ins_Len		= 8			; word (mots)
ins_RepLen	= 10			; word (mots)
ins_Vol		= 12			; word
ins_SIZEOF	= 16

;----------------------------------------------------------------------
; PT_Init : analyse l'entete du module et prepare les 4 canaux
;----------------------------------------------------------------------
; PT_Init : a0 = module ProTracker a jouer. Le pointeur est passe par
; l'appelant depuis qu'un programme peut en avoir plusieurs.
PT_Init:
	movem.l	d0-d7/a0-a6,-(sp)
	moveq	#0,d0
	move.b	950(a0),d0		; longueur du morceau
	move.w	d0,PT_SongLen
	lea	952(a0),a1		; table d'ordre, 128 octets
	move.l	a1,PT_Order

	moveq	#0,d1			; nombre de patterns = max(ordre)+1
	moveq	#127,d2
.scan:
	moveq	#0,d0
	move.b	(a1)+,d0
	cmp.w	d1,d0
	ble.s	.scanNext
	move.w	d0,d1
.scanNext:
	dbf	d2,.scan
	addq.w	#1,d1

	lea	1084(a0),a1		; donnees de patterns
	move.l	a1,PT_Patterns
	move.w	d1,d0
	mulu.w	#1024,d0
	add.l	d0,a1			; a1 = debut des donnees de samples

	lea	20(a0),a2		; entetes de samples
	lea	PT_Instruments,a3
	moveq	#30,d2
.inst:
	moveq	#0,d0
	move.w	22(a2),d0		; longueur en mots
	move.l	a1,ins_Data(a3)
	move.w	d0,ins_Len(a3)
	moveq	#0,d3
	move.w	26(a2),d3		; debut de boucle en mots
	add.l	d3,d3
	move.l	a1,d4
	add.l	d3,d4
	move.l	d4,ins_RepData(a3)
	move.w	28(a2),ins_RepLen(a3)
	moveq	#0,d4
	move.b	25(a2),d4		; volume
	move.w	d4,ins_Vol(a3)
	add.l	d0,d0			; longueur en octets
	add.l	d0,a1
	tst.w	ins_Len(a3)		; longueur nulle : AUDxLEN = 0 vaut
	bne.s	.instNext		; 65536 mots pour Paula, on l'evite
	move.w	#1,ins_Len(a3)
	move.w	#1,ins_RepLen(a3)
.instNext:
	lea	30(a2),a2
	lea	ins_SIZEOF(a3),a3
	dbf	d2,.inst

	lea	PT_Channels,a3		; canaux : registres Paula et bit DMA
	move.l	#CUSTOM+AUD0LCH,d0
	moveq	#DMAF_AUD0,d1
	moveq	#3,d2
.chan:
	move.l	d0,chn_AudBase(a3)
	move.w	d1,chn_DmaBit(a3)
	clr.w	chn_Period(a3)
	clr.w	chn_PlayPer(a3)
	clr.w	chn_Volume(a3)
	clr.w	chn_Effect(a3)
	clr.w	chn_Param(a3)
	clr.w	chn_Porta(a3)
	clr.w	chn_PortaSpd(a3)
	clr.w	chn_ArpPos(a3)
	clr.w	chn_Trigger(a3)
	clr.w	chn_SetRep(a3)
	clr.w	chn_VibPos(a3)
	clr.w	chn_VibCmd(a3)
	clr.w	chn_TremPos(a3)
	clr.w	chn_TremCmd(a3)
	clr.w	chn_Offset(a3)
	clr.w	chn_Retrig(a3)
	move.w	#-1,chn_CutAt(a3)
	move.w	#-1,chn_DelayTo(a3)
	clr.w	chn_HeldPer(a3)
	clr.w	chn_HeldIns(a3)
	clr.w	chn_RealVol(a3)
	add.l	#$10,d0
	add.w	d1,d1
	lea	chn_SIZEOF(a3),a3
	dbf	d2,.chan

	move.w	#6,PT_Speed		; 6 ticks par ligne
	move.w	#5,PT_TickCnt		; le premier appel joue une ligne
	clr.w	PT_Row
	clr.w	PT_Pos
	clr.w	PT_DoJump
	clr.w	PT_DoBreak
	clr.w	PT_PattDelay
	clr.w	PT_LoopRow
	clr.w	PT_LoopCnt

	clr.w	PT_SfxLock
	move.b	CIAAPRA,PT_OldFilter	; filtre passe-bas coupe (bit 1 = LED)
	bset	#1,CIAAPRA
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; PT_Stop : silence, DMA audio coupe, filtre restaure
;----------------------------------------------------------------------
PT_Stop:
	movem.l	d0/a0/a5-a6,-(sp)
	lea	CUSTOM,a6
	move.w	#DMAF_AUDIO,DMACON(a6)
	lea	PT_Channels,a5
	moveq	#3,d0
.loop:
	move.l	chn_AudBase(a5),a0
	clr.w	AUDx_VOL(a0)
	lea	chn_SIZEOF(a5),a5
	dbf	d0,.loop
	btst	#1,PT_OldFilter		; filtre remis comme on l'a trouve
	bne.s	.done
	bclr	#1,CIAAPRA
.done:
	movem.l	(sp)+,d0/a0/a5-a6
	rts

;----------------------------------------------------------------------
; PT_Tick : un appel par image
;----------------------------------------------------------------------
PT_Tick:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	CUSTOM,a6

	lea	PT_Channels,a5		; boucles des notes lancees au tick
	moveq	#3,d7			; precedent : Paula a charge l'adresse
.repLoop:				; de depart, on peut armer la boucle
	tst.w	chn_SetRep(a5)
	beq.s	.repNext
	clr.w	chn_SetRep(a5)
	move.l	chn_AudBase(a5),a0
	move.l	chn_RepData(a5),AUDx_LC(a0)
	move.w	chn_RepLen(a5),AUDx_LEN(a0)
.repNext:
	lea	chn_SIZEOF(a5),a5
	dbf	d7,.repLoop

	tst.w	PT_SfxLock		; le canal 3 est-il prete a un bruitage ?
	beq.s	.noSfx
	subq.w	#1,PT_SfxLock
.noSfx:
	move.w	PT_TickCnt,d0
	addq.w	#1,d0
	cmp.w	PT_Speed,d0
	blt.s	.effects
	clr.w	PT_TickCnt
	tst.w	PT_PattDelay		; EEx : la ligne est retenue
	beq.s	.newRow
	subq.w	#1,PT_PattDelay
	bsr	PT_Effects
	bra.s	.hardware
.newRow:
	bsr	PT_NewRow
	bra.s	.hardware
.effects:
	move.w	d0,PT_TickCnt
	bsr	PT_Effects
.hardware:
	lea	PT_Channels,a5
	moveq	#3,d7
.hwLoop:
	move.w	chn_DmaBit(a5),d1	; canal emprunte par un bruitage ?
	cmp.w	#8,d1
	bne.s	.hwOk
	tst.w	PT_SfxLock
	bne.s	.hwSkip
.hwOk:
	move.l	chn_AudBase(a5),a0
	move.w	chn_PlayPer(a5),d0
	beq.s	.hwNoPeriod
	move.w	d0,AUDx_PER(a0)
.hwNoPeriod:
	move.w	chn_Volume(a5),AUDx_VOL(a0)
.hwSkip:
	lea	chn_SIZEOF(a5),a5
	dbf	d7,.hwLoop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; PT_NewRow : joue une ligne de pattern (a6 = CUSTOM)
;----------------------------------------------------------------------
PT_NewRow:
	move.l	PT_Order,a0
	moveq	#0,d0
	move.w	PT_Pos,d1
	move.b	(a0,d1.w),d0		; pattern a jouer
	mulu.w	#1024,d0
	move.l	PT_Patterns,a4
	add.l	d0,a4
	move.w	PT_Row,d0
	mulu.w	#16,d0
	add.l	d0,a4			; premiere case de la ligne

	lea	PT_Channels,a5
	moveq	#3,d7
.chLoop:
	move.l	(a4)+,d0
	bsr	PT_DecodeNote
	lea	chn_SIZEOF(a5),a5
	dbf	d7,.chLoop

	moveq	#0,d6			; masque des canaux a relancer
	lea	PT_Channels,a5
	moveq	#3,d7
.maskLoop:
	tst.w	chn_Trigger(a5)
	beq.s	.maskNext
	move.w	chn_DmaBit(a5),d0
	cmp.w	#8,d0			; canal 3 pris par un bruitage : on
	bne.s	.maskAdd		; laisse tomber la note
	tst.w	PT_SfxLock
	beq.s	.maskAdd
	clr.w	chn_Trigger(a5)
	bra.s	.maskNext
.maskAdd:
	or.w	d0,d6
.maskNext:
	lea	chn_SIZEOF(a5),a5
	dbf	d7,.maskLoop
	tst.w	d6
	beq.s	.advance

	move.w	d6,DMACON(a6)		; 1. DMA coupe sur ces canaux
	lea	PT_Channels,a5
	moveq	#3,d7
.setLoop:
	tst.w	chn_Trigger(a5)
	beq.s	.setNext
	clr.w	chn_Trigger(a5)
	move.w	#1,chn_SetRep(a5)
	move.l	chn_AudBase(a5),a0
	move.l	chn_Data(a5),AUDx_LC(a0)	; 2. sample, longueur,
	move.w	chn_Len(a5),AUDx_LEN(a0)	;    periode et volume
	move.w	chn_Period(a5),AUDx_PER(a0)
	move.w	chn_Volume(a5),AUDx_VOL(a0)
.setNext:
	lea	chn_SIZEOF(a5),a5
	dbf	d7,.setLoop
	bsr	PT_WaitLines		; 3. laisser Paula voir l'arret
	or.w	#DMAF_SETCLR,d6
	move.w	d6,DMACON(a6)		; 4. relance

.advance:
	addq.w	#1,PT_Row
	tst.w	PT_DoBreak
	beq.s	.noBreak
	clr.w	PT_DoBreak
	move.w	PT_BreakRow,PT_Row
	addq.w	#1,PT_Pos
	bra.s	.checkPos
.noBreak:
	tst.w	PT_DoJump
	beq.s	.noJump
	clr.w	PT_DoJump
	clr.w	PT_Row
	move.w	PT_JumpPos,PT_Pos
	bra.s	.checkPos
.noJump:
	cmp.w	#64,PT_Row
	blt.s	.done
	clr.w	PT_Row
	addq.w	#1,PT_Pos
.checkPos:
	move.w	PT_Pos,d0
	cmp.w	PT_SongLen,d0
	blt.s	.done
	clr.w	PT_Pos			; le morceau boucle
	clr.w	PT_Row
.done:
	rts

;----------------------------------------------------------------------
; PT_DecodeNote : une case de pattern
;   d0 = les 4 octets, a5 = canal
;
;   octet 0 : instrument (poids fort) et periode (bits 11-8)
;   octet 1 : periode (bits 7-0)
;   octet 2 : instrument (poids faible) et numero d'effet
;   octet 3 : parametre de l'effet
;----------------------------------------------------------------------
PT_DecodeNote:
	movem.l	d0-d6/a0-a2,-(sp)
	move.l	d0,d1
	swap	d1			; d1 = octets 0 et 1
	move.w	d1,d2
	and.w	#$0fff,d2		; periode
	move.w	d0,d3			; octets 2 et 3
	moveq	#0,d4
	move.b	d3,d4			; parametre
	lsr.w	#8,d3			; octet 2
	move.w	d3,d5
	and.w	#$000f,d5		; effet
	lsr.w	#4,d3
	move.w	d1,d6
	lsr.w	#8,d6
	and.w	#$00f0,d6
	or.w	d3,d6			; numero d'instrument

	tst.w	d6			; instrument : charge sample et volume
	beq.s	.noInst
	move.w	d6,d0
	subq.w	#1,d0
	mulu.w	#ins_SIZEOF,d0
	lea	PT_Instruments,a2
	add.l	d0,a2
	move.l	ins_Data(a2),chn_Data(a5)
	move.w	ins_Len(a2),chn_Len(a5)
	move.l	ins_RepData(a2),chn_RepData(a5)
	move.w	ins_RepLen(a2),chn_RepLen(a5)
	move.w	ins_Vol(a2),chn_Volume(a5)
.noInst:
	move.w	d5,chn_Effect(a5)
	move.w	d4,chn_Param(a5)

	move.w	#-1,chn_CutAt(a5)	; les ordres de la case precedente
	move.w	#-1,chn_DelayTo(a5)	; ne durent pas
	clr.w	chn_Retrig(a5)
	cmp.w	#$e,d5			; EDx : la note part plus tard
	bne.s	.notDelay
	move.w	d4,d0
	and.w	#$00f0,d0
	cmp.w	#$00d0,d0
	bne.s	.notDelay
	move.w	d4,d0
	and.w	#$000f,d0
	beq.s	.notDelay
	move.w	d0,chn_DelayTo(a5)
	move.w	d2,chn_HeldPer(a5)	; on garde la note sous le coude
	move.w	d6,chn_HeldIns(a5)
	moveq	#0,d2			; et la case ne declenche rien
.notDelay:
	tst.w	d2			; periode : nouvelle note ?
	beq	.noNote
	cmp.w	#3,d5			; sauf portamento vers la note, qui
	beq.s	.portaTarget		; vise sans relancer le sample
	cmp.w	#5,d5
	beq.s	.portaTarget
	move.w	d2,chn_Period(a5)
	clr.w	chn_ArpPos(a5)
	cmp.w	#4,d5			; une note remet la sinusoide a zero,
	beq.s	.keepVib		; sauf si le vibrato continue
	cmp.w	#6,d5
	beq.s	.keepVib
	clr.w	chn_VibPos(a5)
.keepVib:
	clr.w	chn_TremPos(a5)
	move.w	#1,chn_Trigger(a5)
	bra.s	.noNote
.portaTarget:
	move.w	d2,chn_Porta(a5)
.noNote:
	move.w	chn_Period(a5),chn_PlayPer(a5)

	cmp.w	#$3,d5			; --- effets appliques des le tick 0
	bne.s	.notPorta
	tst.w	d4
	beq.s	.notPorta
	move.w	d4,chn_PortaSpd(a5)
.notPorta:
	cmp.w	#$4,d5			; 4xy : vibrato. Un parametre nul
	bne.s	.notVib			; reprend le precedent, comme sur
	tst.w	d4			; ProTracker ; 6xy garde toujours
	beq.s	.notVib			; celui de la derniere commande 4
	move.w	d4,chn_VibCmd(a5)
.notVib:
	cmp.w	#$7,d5			; 7xy : tremolo
	bne.s	.notTrem
	tst.w	d4
	beq.s	.notTrem
	move.w	d4,chn_TremCmd(a5)
.notTrem:
	cmp.w	#$9,d5			; 9xx : demarrer plus loin dans le
	bne.s	.notOffset		; sample
	tst.w	d4
	beq.s	.useOffset
	move.w	d4,chn_Offset(a5)
.useOffset:
	tst.w	chn_Trigger(a5)
	beq.s	.notOffset
	moveq	#0,d0
	move.w	chn_Offset(a5),d0
	lsl.l	#7,d0			; xx * 256 octets, soit xx * 128 mots
	cmp.w	chn_Len(a5),d0
	bge.s	.notOffset		; au-dela du sample : on n'y touche pas
	sub.w	d0,chn_Len(a5)
	add.l	d0,d0			; le pointeur, lui, compte en octets
	add.l	d0,chn_Data(a5)
.notOffset:
	cmp.w	#$c,d5			; Cxx : volume
	bne.s	.notVol
	cmp.w	#64,d4
	ble.s	.volOk
	moveq	#64,d4
.volOk:
	move.w	d4,chn_Volume(a5)
.notVol:
	cmp.w	#$f,d5			; Fxx : vitesse (le tempo BPM, >= 32,
	bne.s	.notSpeed		; n'a pas de sens en cadence VBlank)
	tst.w	d4
	beq.s	.notSpeed
	cmp.w	#32,d4
	bge.s	.notSpeed
	move.w	d4,PT_Speed
.notSpeed:
	cmp.w	#$b,d5			; Bxx : saut de position
	bne.s	.notJump
	move.w	d4,PT_JumpPos
	move.w	#1,PT_DoJump
.notJump:
	cmp.w	#$e,d5			; Exy : les commandes etendues
	bne	.notExt
	move.w	d4,d0
	lsr.w	#4,d0			; x : laquelle
	move.w	d4,d1
	and.w	#$000f,d1		; y : son parametre

	cmp.w	#$0,d0			; E0x : filtre passe-bas (la diode)
	bne.s	.notFilter
	tst.w	d1
	bne.s	.filterOff
	bclr	#1,CIAAPRA
	bra	.notExt
.filterOff:
	bset	#1,CIAAPRA
	bra	.notExt
.notFilter:
	cmp.w	#$1,d0			; E1x : glissando fin vers l'aigu
	bne.s	.notFineUp
	sub.w	d1,chn_Period(a5)
	cmp.w	#113,chn_Period(a5)
	bge	.notExt
	move.w	#113,chn_Period(a5)
	bra	.notExt
.notFineUp:
	cmp.w	#$2,d0			; E2x : et vers le grave
	bne.s	.notFineDn
	add.w	d1,chn_Period(a5)
	cmp.w	#856,chn_Period(a5)
	ble	.notExt
	move.w	#856,chn_Period(a5)
	bra	.notExt
.notFineDn:
	cmp.w	#$6,d0			; E6x : boucle de pattern
	bne.s	.notLoop
	tst.w	d1
	bne.s	.loopSet
	move.w	PT_Row,PT_LoopRow	; E60 : ici commence la boucle
	bra	.notExt
.loopSet:
	tst.w	PT_LoopCnt
	bne.s	.loopAgain
	move.w	d1,PT_LoopCnt		; premier passage : n tours
	bra.s	.loopBack
.loopAgain:
	subq.w	#1,PT_LoopCnt
	beq	.notExt			; tours epuises : on continue
.loopBack:
	move.w	PT_LoopRow,d2
	subq.w	#1,d2			; PT_Row sera incremente ensuite
	move.w	d2,PT_Row
	bra	.notExt
.notLoop:
	cmp.w	#$9,d0			; E9x : relancer la note tous les y tics
	bne.s	.notRetrig
	move.w	d1,chn_Retrig(a5)
	bra.s	.notExt
.notRetrig:
	cmp.w	#$a,d0			; EAx : volume fin vers le haut
	bne.s	.notFineVolUp
	add.w	d1,chn_Volume(a5)
	cmp.w	#64,chn_Volume(a5)
	ble.s	.notExt
	move.w	#64,chn_Volume(a5)
	bra.s	.notExt
.notFineVolUp:
	cmp.w	#$b,d0			; EBx : et vers le bas
	bne.s	.notFineVolDn
	sub.w	d1,chn_Volume(a5)
	bpl.s	.notExt
	clr.w	chn_Volume(a5)
	bra.s	.notExt
.notFineVolDn:
	cmp.w	#$c,d0			; ECx : couper la note au tic y
	bne.s	.notCut
	move.w	d1,chn_CutAt(a5)
	bra.s	.notExt
.notCut:
	cmp.w	#$e,d0			; EEx : tenir la ligne y tours de plus
	bne.s	.notPattDelay
	move.w	d1,PT_PattDelay
.notPattDelay:
.notExt:
	move.w	chn_Volume(a5),chn_RealVol(a5)

	cmp.w	#$d,d5			; Dxx : break, parametre en BCD
	bne.s	.notBreak
	move.w	d4,d0
	lsr.w	#4,d0
	mulu.w	#10,d0
	move.w	d4,d1
	and.w	#$000f,d1
	add.w	d1,d0
	cmp.w	#64,d0
	blt.s	.breakOk
	moveq	#0,d0
.breakOk:
	move.w	d0,PT_BreakRow
	move.w	#1,PT_DoBreak
.notBreak:
	movem.l	(sp)+,d0-d6/a0-a2
	rts

;----------------------------------------------------------------------
; PT_Effects : ticks intermediaires
;----------------------------------------------------------------------
PT_Effects:
	lea	PT_Channels,a5
	moveq	#3,d7
.chLoop:
	move.w	chn_Period(a5),d4	; periode a jouer par defaut
	move.w	chn_Effect(a5),d0
	move.w	chn_Param(a5),d1
	move.w	chn_RealVol(a5),chn_Volume(a5)	; le tremolo ne s'accumule pas

	move.w	PT_TickCnt,d2		; --- ECx : la note se tait
	cmp.w	chn_CutAt(a5),d2
	bne.s	.notCutNow
	clr.w	chn_Volume(a5)
	clr.w	chn_RealVol(a5)
.notCutNow:
	cmp.w	chn_DelayTo(a5),d2	; --- EDx : la note part enfin
	bne.s	.notDelayNow
	move.w	#-1,chn_DelayTo(a5)
	move.w	chn_HeldPer(a5),d3
	beq.s	.notDelayNow
	move.w	d3,chn_Period(a5)
	move.w	d3,d4
	clr.w	chn_VibPos(a5)
	clr.w	chn_TremPos(a5)
	move.w	#1,chn_Trigger(a5)
	bsr	PT_Restart
.notDelayNow:
	move.w	chn_Retrig(a5),d3	; --- E9x : on relance en boucle
	beq.s	.notRetrigNow
	move.w	d2,d5
	and.l	#$0000ffff,d5
	divu.w	d3,d5
	swap	d5
	tst.w	d5
	bne.s	.notRetrigNow
	move.w	#1,chn_Trigger(a5)
	bsr	PT_Restart
.notRetrigNow:

	tst.w	d0			; 0xy : arpege
	bne.s	.not0
	tst.w	d1
	beq.s	.store
	bsr	PT_Arpeggio
	bra.s	.store
.not0:
	cmp.w	#1,d0			; 1xx : glissando vers l'aigu
	bne.s	.not1
	sub.w	d1,d4
	cmp.w	#113,d4
	bge.s	.keep
	move.w	#113,d4
	bra.s	.keep
.not1:
	cmp.w	#2,d0			; 2xx : glissando vers le grave
	bne.s	.not2
	add.w	d1,d4
	cmp.w	#856,d4
	ble.s	.keep
	move.w	#856,d4
	bra.s	.keep
.not2:
	cmp.w	#3,d0			; 3xx : portamento vers la note
	bne.s	.not3
	bsr	PT_TonePorta
	bra.s	.keep
.not3:
	cmp.w	#$4,d0			; 4xy : vibrato
	bne.s	.not4
	bsr	PT_Vibrato
	bra	.store			; la periode jouee bouge, pas la vraie
.not4:
	cmp.w	#$5,d0			; 5xy : portamento et volume
	bne.s	.not5
	bsr	PT_TonePorta
	bsr	PT_VolSlide
	bra	.keep
.not5:
	cmp.w	#$6,d0			; 6xy : vibrato et volume
	bne.s	.not6
	bsr	PT_Vibrato
	bsr	PT_VolSlide
	bra	.store
.not6:
	cmp.w	#$7,d0			; 7xy : tremolo
	bne.s	.not7
	bsr	PT_Tremolo
	bra	.store
.not7:
	cmp.w	#$a,d0			; Axy : volume slide
	bne.s	.store
	bsr	PT_VolSlide
	bra	.store
.keep:
	move.w	d4,chn_Period(a5)	; glissandos : la periode change
.store:
	move.w	d4,chn_PlayPer(a5)
	lea	chn_SIZEOF(a5),a5
	dbf	d7,.chLoop
	rts

;----------------------------------------------------------------------
; PT_SineTable : un quart de sinusoide, comme ProTracker
;----------------------------------------------------------------------
PT_SineTable:
	dc.b	0,24,49,74,97,120,141,161
	dc.b	180,197,212,224,235,244,250,253
	dc.b	255,253,250,244,235,224,212,197
	dc.b	180,161,141,120,97,74,49,24
	even

;----------------------------------------------------------------------
; PT_Vibrato : 4xy fait onduler la hauteur sans toucher a la note.
;   d1 = parametre, a5 = canal, d4 = periode a jouer
;
; C'est la meme sinusoide que ProTracker : trente-deux points pour une
; demi-periode, le signe venant du bit 5 de la position.
;----------------------------------------------------------------------
PT_Vibrato:
	movem.l	d0/d2-d3/d5-d6/a1,-(sp)
	move.w	chn_VibCmd(a5),d5
	beq.s	.done
	move.w	chn_VibPos(a5),d6
	move.w	d6,d0
	lsr.w	#2,d0
	and.w	#31,d0
	lea	PT_SineTable,a1
	moveq	#0,d2
	move.b	(a1,d0.w),d2
	move.w	d5,d3
	and.w	#$000f,d3		; y : amplitude
	mulu.w	d3,d2
	lsr.w	#7,d2
	btst	#5,d6			; la seconde moitie descend
	beq.s	.up
	sub.w	d2,d4
	bra.s	.step
.up:
	add.w	d2,d4
.step:
	move.w	d5,d3
	lsr.w	#4,d3			; x : vitesse
	add.w	d3,d3
	add.w	d3,d6
	and.w	#63,d6
	move.w	d6,chn_VibPos(a5)
	cmp.w	#113,d4
	bge.s	.hi
	move.w	#113,d4
	bra.s	.done
.hi:
	cmp.w	#856,d4
	ble.s	.done
	move.w	#856,d4
.done:
	movem.l	(sp)+,d0/d2-d3/d5-d6/a1
	rts

;----------------------------------------------------------------------
; PT_Tremolo : 7xy, le vibrato du volume
;----------------------------------------------------------------------
PT_Tremolo:
	movem.l	d0/d2-d3/d5-d6/a1,-(sp)
	move.w	chn_TremCmd(a5),d5
	beq.s	.done
	move.w	chn_TremPos(a5),d6
	move.w	d6,d0
	lsr.w	#2,d0
	and.w	#31,d0
	lea	PT_SineTable,a1
	moveq	#0,d2
	move.b	(a1,d0.w),d2
	move.w	d5,d3
	and.w	#$000f,d3
	mulu.w	d3,d2
	lsr.w	#6,d2
	move.w	chn_RealVol(a5),d3
	btst	#5,d6
	beq.s	.up
	sub.w	d2,d3
	bpl.s	.set
	moveq	#0,d3
	bra.s	.set
.up:
	add.w	d2,d3
	cmp.w	#64,d3
	ble.s	.set
	moveq	#64,d3
.set:
	move.w	d3,chn_Volume(a5)	; le volume reel, lui, ne bouge pas
	move.w	d5,d3
	lsr.w	#4,d3
	add.w	d3,d3
	add.w	d3,d6
	and.w	#63,d6
	move.w	d6,chn_TremPos(a5)
.done:
	movem.l	(sp)+,d0/d2-d3/d5-d6/a1
	rts

;----------------------------------------------------------------------
; PT_VolSlide : le Axy de ProTracker, partage par 5xy, 6xy et Axy
;   d1 = parametre, a5 = canal
;----------------------------------------------------------------------
PT_VolSlide:
	movem.l	d2-d3,-(sp)
	move.w	chn_RealVol(a5),d2
	move.w	d1,d3
	lsr.w	#4,d3
	beq.s	.down
	add.w	d3,d2
	cmp.w	#64,d2
	ble.s	.set
	moveq	#64,d2
	bra.s	.set
.down:
	move.w	d1,d3
	and.w	#$000f,d3
	sub.w	d3,d2
	bge.s	.set
	moveq	#0,d2
.set:
	move.w	d2,chn_RealVol(a5)
	move.w	d2,chn_Volume(a5)
	movem.l	(sp)+,d2-d3
	rts

;----------------------------------------------------------------------
; PT_Restart : relance le sample d'un canal en plein milieu d'une ligne
;
; E9x et EDx ne tombent pas sur une nouvelle ligne : la sequence de
; Paula -- DMA coupe, registres, attente, DMA -- doit se rejouer ici
; pour ce seul canal.
;----------------------------------------------------------------------
PT_Restart:
	movem.l	d0-d1/a0-a1,-(sp)
	move.w	chn_DmaBit(a5),d0
	cmp.w	#8,d0			; canal 3 pris par un bruitage ?
	bne.s	.go
	tst.w	PT_SfxLock
	beq.s	.go
	clr.w	chn_Trigger(a5)
	bra.s	.done
.go:
	lea	CUSTOM,a1
	move.w	d0,DMACON(a1)
	move.l	chn_AudBase(a5),a0
	move.l	chn_Data(a5),AUDx_LC(a0)
	move.w	chn_Len(a5),AUDx_LEN(a0)
	move.w	chn_Period(a5),AUDx_PER(a0)
	move.w	chn_Volume(a5),AUDx_VOL(a0)
	bsr	PT_WaitLines
	or.w	#DMAF_SETCLR,d0
	move.w	d0,DMACON(a1)
	clr.w	chn_Trigger(a5)
	move.w	#1,chn_SetRep(a5)
.done:
	movem.l	(sp)+,d0-d1/a0-a1
	rts


;----------------------------------------------------------------------
; PT_Arpeggio : 0xy alterne note, note + x demi-tons, note + y
;   d1 = parametre, a5 = canal ; renvoie la periode dans d4
;----------------------------------------------------------------------
PT_Arpeggio:
	movem.l	d0/d2-d3/d5-d6/a1,-(sp)
	move.w	chn_ArpPos(a5),d2
	addq.w	#1,d2
	cmp.w	#3,d2
	blt.s	.posOk
	moveq	#0,d2
.posOk:
	move.w	d2,chn_ArpPos(a5)
	tst.w	d2
	beq.s	.done			; position 0 : note de base
	move.w	d1,d3
	cmp.w	#1,d2
	bne.s	.low
	lsr.w	#4,d3			; position 1 : quartet haut
	bra.s	.shift
.low:
	and.w	#$000f,d3		; position 2 : quartet bas
.shift:
	lea	PT_PeriodTable,a1	; index de la periode courante
	move.w	chn_Period(a5),d5
	moveq	#0,d6
.search:
	cmp.w	(a1)+,d5
	bge.s	.found
	addq.w	#1,d6
	cmp.w	#36,d6
	blt.s	.search
	bra.s	.done			; periode inconnue : on ne touche pas
.found:
	add.w	d3,d6
	cmp.w	#36,d6
	blt.s	.inRange
	moveq	#35,d6
.inRange:
	add.w	d6,d6
	lea	PT_PeriodTable,a1
	move.w	(a1,d6.w),d4
.done:
	movem.l	(sp)+,d0/d2-d3/d5-d6/a1
	rts

;----------------------------------------------------------------------
; PT_TonePorta : 3xx, glisse vers chn_Porta ; periode dans d4
;----------------------------------------------------------------------
PT_TonePorta:
	movem.l	d2-d3,-(sp)
	move.w	chn_Porta(a5),d2
	beq.s	.done
	move.w	chn_PortaSpd(a5),d3
	cmp.w	d2,d4
	beq.s	.done
	bcs.s	.up
	sub.w	d3,d4			; periode trop grande : on la baisse
	cmp.w	d2,d4
	bgt.s	.done
	move.w	d2,d4
	bra.s	.done
.up:
	add.w	d3,d4
	cmp.w	d2,d4
	blt.s	.done
	move.w	d2,d4
.done:
	movem.l	(sp)+,d2-d3
	rts

;----------------------------------------------------------------------
; PT_WaitLines : deux lignes raster, le temps que Paula prenne en compte
; l'arret du DMA avant qu'on le relance (a6 = CUSTOM)
;----------------------------------------------------------------------
PT_WaitLines:
	movem.l	d0-d1,-(sp)
	moveq	#1,d1
.line:
	move.b	VHPOSR(a6),d0
.wait:
	cmp.b	VHPOSR(a6),d0
	beq.s	.wait
	dbf	d1,.line
	movem.l	(sp)+,d0-d1
	rts

;======================================================================
	SECTION	ptdata,DATA
;======================================================================

; Table de periodes ProTracker, finetune 0, octaves 1 a 3.
PT_PeriodTable:
	dc.w	856,808,762,720,678,640,604,570,538,508,480,453
	dc.w	428,404,381,360,339,320,302,285,269,254,240,226
	dc.w	214,202,190,180,170,160,151,143,135,127,120,113

;======================================================================
	SECTION	ptmodule,DATA_C		; Paula ne lit que la Chip RAM
;======================================================================

PT_ModuleData:
	ifd	PT_SCORE		; le jeu a sa propre partition ;
	incbin	"data/crawlmus.mod"	; les demos gardent la leur
	else
	incbin	"data/music.mod"
	endif
	even

	ifd	PT_SCORE
PT_TitleModule:				; devant le portail, avant la descente
	incbin	"data/titlemus.mod"
	even
	endif

;======================================================================
	SECTION	ptbss,BSS
;======================================================================

PT_Order:	ds.l	1
PT_Patterns:	ds.l	1
PT_SongLen:	ds.w	1
PT_Speed:	ds.w	1
PT_TickCnt:	ds.w	1
PT_Row:		ds.w	1
PT_Pos:		ds.w	1
PT_DoJump:	ds.w	1
PT_JumpPos:	ds.w	1
PT_DoBreak:	ds.w	1
PT_BreakRow:	ds.w	1
PT_SfxLock:	ds.w	1
PT_OldFilter:	ds.b	1
	even
PT_PattDelay:	ds.w	1		; EEx : lignes tenues
PT_LoopRow:	ds.w	1		; E60 : ligne de retour
PT_LoopCnt:	ds.w	1		; E6x : tours restants
PT_Channels:	ds.b	chn_SIZEOF*4
PT_Instruments:	ds.b	ins_SIZEOF*31
