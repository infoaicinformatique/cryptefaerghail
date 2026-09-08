;----------------------------------------------------------------------
; ciatimer.i - le timer A du CIA-B cadence le replayer (niveau 6)
;
; A inclure dans la SECTION de code du programme, comme ptreplay.i.
;
; Interface :
;   CIA_Install   prend le timer A, installe le vecteur, arme EXTER
;   CIA_Remove    coupe l'interruption et rend le vecteur au systeme
;   CIA_SetBpm    d0 = tempo, 32 a 255
;   CIA_Lock      suspend le tic (section critique du son)
;   CIA_Unlock    le reprend
;   CIA_Count     word : nombre de tics depuis l'installation
; Toutes preservent l'integralite des registres.
;
; Le programme fournit CIA_Tick : ce qu'il faut faire d'un tic. Tous
; les registres y sont libres, et il n'est appele que si un module est
; ouvert (PT_Ready).
;
; Le programme reserve dans sa propre section BSS :
;   CIA_Vbr:      ds.l 1
;   CIA_OldLvl6:  ds.l 1
;   CIA_Count:    ds.w 1
;   CIA_Bpm:      ds.w 1
;
; Pourquoi pas le retour trame : un module ProTracker ne se joue pas a
; 50 Hz mais a BPM x 2 / 5 tics par seconde -- 50 Hz n'est que le cas
; du tempo par defaut, 125. L'effet Fxx avec un parametre d'au moins 32
; change ce tempo, et le replayer n'avait aucun moyen de l'honorer tant
; qu'il etait attele au balayage. Il l'est maintenant au timer A du
; CIA-B, dont l'horloge vaut 709379 Hz en PAL : un compte de
; CIA_CLOCK5 / BPM donne exactement la bonne cadence.
;
; Ce que l'on ne rend pas en sortant : le compte du timer, qui est en
; ecriture seule -- on ne peut pas savoir ce qu'il valait. On rend le
; vecteur, le masque du CIA et INTENA ; le timer, lui, reste sur notre
; tempo, muet. C'est le raccourci ordinaire des demos, et la raison
; pour laquelle on ne relance pas un jeu deux fois sans reboot sur une
; machine ou quelqu'un d'autre compte sur ce timer.
;----------------------------------------------------------------------

CIA_Install:
	movem.l	d0-d1/a0-a1/a5-a6,-(sp)
	moveq	#0,d0			; 68000 : table des vecteurs en zero
	move.l	4.w,a6
	btst	#AFB_68010,AttnFlags+1(a6)
	beq.s	.noVbr
	lea	CIA_GetVbr(pc),a5
	jsr	_LVOSupervisor(a6)	; rend le VBR dans d0
.noVbr:
	move.l	d0,CIA_Vbr
	move.l	d0,a0
	move.l	LVL6_VECTOR(a0),CIA_OldLvl6
	lea	CIA_Handler(pc),a1
	move.l	a1,LVL6_VECTOR(a0)
	clr.w	CIA_Count

	move.b	#CIAICR_CLEAR,CIABICR	; plus rien ne sort du CIA-B
	tst.b	CIABICR			; et les drapeaux en attente tombent
	moveq	#125,d0			; le tempo par defaut d'un module
	bsr	CIA_SetBpm
	move.b	#CIACRA_RUN,CIABCRA
	move.b	#CIAICR_TA,CIABICR	; le timer A, et lui seul
	lea	CUSTOM,a5
	move.w	#INTF_EXTER,INTREQ(a5)
	move.w	#INTF_SETCLR|INTF_INTEN|INTF_EXTER,INTENA(a5)
	movem.l	(sp)+,d0-d1/a0-a1/a5-a6
	rts

; Execute en mode superviseur par exec/Supervisor() : rte, pas rts.
CIA_GetVbr:
	movec	vbr,d0
	rte

CIA_Remove:
	movem.l	d0/a0,-(sp)
	lea	CUSTOM,a0
	move.w	#INTF_EXTER,INTENA(a0)	; bit 15 a zero : on desarme
	move.b	#CIAICR_CLEAR,CIABICR
	tst.b	CIABICR
	move.w	#INTF_EXTER,INTREQ(a0)
	move.l	CIA_Vbr,a0
	move.l	CIA_OldLvl6,LVL6_VECTOR(a0)
	movem.l	(sp)+,d0/a0
	rts

; CIA_Lock / CIA_Unlock : parenthese autour d'un passage que le tic ne
; doit pas traverser -- le lancement d'un bruitage, qui emprunte un
; canal de Paula au replayer, ou le changement de module.
CIA_Lock:
	move.w	#INTF_EXTER,INTENA+CUSTOM
	rts

CIA_Unlock:
	move.w	#INTF_SETCLR|INTF_EXTER,INTENA+CUSTOM
	rts

; CIA_SetBpm : d0 = tempo. Le compte tient dans un mot des 32 BPM ;
; en dessous, la division deborderait, et un module qui demande moins
; n'existe pas.
CIA_SetBpm:
	movem.l	d0-d2,-(sp)
	cmp.w	#32,d0
	bge.s	.floor
	moveq	#32,d0
.floor:
	cmp.w	#255,d0
	ble.s	.ceil
	move.w	#255,d0
.ceil:
	move.w	d0,CIA_Bpm
	and.l	#$0000ffff,d0
	move.l	#CIA_CLOCK5,d1
	divu.w	d0,d1
	move.w	d1,d2
	move.b	d2,CIABTALO
	lsr.w	#8,d2
	move.b	d2,CIABTAHI		; le poids fort recharge le timer
	movem.l	(sp)+,d0-d2
	rts

;----------------------------------------------------------------------
; CIA_Handler : le gestionnaire de niveau 6
;
; On acquitte INTREQ avant de lire l'ICR du CIA : la lecture efface les
; drapeaux du CIA et fait retomber sa ligne, et l'ordre inverse laisse
; passer une interruption fantome. On acquitte une seconde fois en
; sortant, pour la meme raison qu'au niveau 3 -- le custom chip met un
; cycle a voir la valeur.
;----------------------------------------------------------------------
CIA_Handler:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	CUSTOM,a5
	move.w	#INTF_EXTER,INTREQ(a5)
	moveq	#0,d0
	move.b	CIABICR,d0		; lecture = effacement des drapeaux
	btst	#0,d0			; le timer A, et pas un autre
	beq.s	.notMine
	addq.w	#1,CIA_Count
	tst.w	PT_Ready		; pas de module ouvert : rien a jouer
	beq.s	.notMine
	bsr	CIA_Tick		; le tic du programme
	tst.w	PT_BpmChanged		; le module a change de tempo
	beq.s	.notMine
	clr.w	PT_BpmChanged
	move.w	PT_Bpm,d0
	bsr	CIA_SetBpm
.notMine:
	move.w	#INTF_EXTER,INTREQ(a5)
	movem.l	(sp)+,d0-d7/a0-a6
	rte
