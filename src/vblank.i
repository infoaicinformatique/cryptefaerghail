;----------------------------------------------------------------------
; vblank.i - interruption de retour trame (niveau 3, VERTB)
;
; A inclure dans la SECTION de code du programme, comme ptreplay.i :
; le code se place dans cette section.
;
; Interface :
;   VBI_Install   installe le vecteur de niveau 3 et arme VERTB
;   VBI_Remove    coupe VERTB et rend le vecteur au systeme
;   VBI_Wait      attend la prochaine trame
;   VBI_Count     word : nombre de trames depuis l'installation
; Toutes preservent l'integralite des registres.
;
; Le programme fournit VBI_Frame : le travail d'une trame, appele depuis
; l'interruption. Tous les registres y sont libres (le gestionnaire les
; a deja empiles) et a5 y vaut CUSTOM. Il fournit aussi VBI_Mid, appele
; quand le copper reveille le processeur en cours d'image -- un simple
; rts pour qui ne s'en sert pas. Il reserve aussi trois variables
; dans sa propre section BSS -- ce fichier ne declare aucune section,
; pour que son code reste dans le hunk de l'appelant et que les bsr
; internes restent des sauts courts :
;
;   VBI_Vbr:      ds.l 1
;   VBI_OldLvl3:  ds.l 1
;   VBI_Count:    ds.w 1
;   VBI_Flag:     ds.w 1
;   VBI_Mids:     ds.w 1
;
; Pourquoi une interruption plutot qu'une attente active sur VPOSR :
; le processeur n'a plus a surveiller le balayage, et surtout le travail
; cadence (echange de copperlist, tic de musique) tombe exactement au
; retour trame, meme si la boucle principale est en retard. Un redessin
; qui deborde d'une trame ne fait donc plus hoqueter le module.
;
; Le VBR : sur 68000 la table des vecteurs est en $000000, mais des le
; 68010 elle se deplace, et sur un 1200 le Kickstart la recopie en Fast
; RAM. On demande donc son adresse au processeur -- instruction
; privilegiee, d'ou le detour par exec/Supervisor().
;----------------------------------------------------------------------

VBI_Install:
	movem.l	d0-d1/a0-a1/a5-a6,-(sp)
	moveq	#0,d0			; 68000 : table des vecteurs en zero
	move.l	4.w,a6
	btst	#AFB_68010,AttnFlags+1(a6)
	beq.s	.noVbr
	lea	VBI_GetVbr(pc),a5
	jsr	_LVOSupervisor(a6)	; rend le VBR dans d0
.noVbr:
	move.l	d0,VBI_Vbr
	move.l	d0,a0
	move.l	LVL3_VECTOR(a0),VBI_OldLvl3
	lea	VBI_Handler(pc),a1
	move.l	a1,LVL3_VECTOR(a0)
	clr.w	VBI_Count
	clr.w	VBI_Flag
	clr.w	VBI_Mids
	lea	CUSTOM,a5
	move.w	#INTF_VERTB,INTREQ(a5)	; pas d'interruption en retard
	move.w	#INTF_SETCLR|INTF_INTEN|INTF_VERTB,INTENA(a5)
	movem.l	(sp)+,d0-d1/a0-a1/a5-a6
	rts

; Execute en mode superviseur par exec/Supervisor() : rte, pas rts.
VBI_GetVbr:
	movec	vbr,d0
	rte

VBI_Remove:
	movem.l	d0/a0,-(sp)
	lea	CUSTOM,a0
	move.w	#INTF_VERTB,INTENA(a0)	; bit 15 a zero : on desarme
	move.w	#INTF_VERTB,INTREQ(a0)
	move.l	VBI_Vbr,a0
	move.l	VBI_OldLvl3,LVL3_VECTOR(a0)
	movem.l	(sp)+,d0/a0
	rts

;----------------------------------------------------------------------
; VBI_Handler : le gestionnaire de niveau 3
;
; Le niveau 3 est partage : VERTB pour le retour trame, COPER quand le
; copper ecrit lui-meme dans INTREQ au milieu de l'image. On regarde
; donc ce qui a frappe avant de faire quoi que ce soit, et l'on sert
; les deux causes -- elles peuvent tomber ensemble.
;
; L'acquittement est ecrit deux fois : le custom chip met un cycle a
; voir la valeur, et sans cette seconde ecriture le processeur peut
; sortir du gestionnaire avant que INTREQ ne soit retombe -- et rentrer
; aussitot dans la meme interruption.
;----------------------------------------------------------------------
VBI_Handler:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	CUSTOM,a5
	move.w	INTREQR(a5),d7		; ce qui a frappe

	move.w	d7,d0
	and.w	#INTF_COPER,d0		; le copper, au milieu de l'image
	beq.s	.notCopper
	move.w	#INTF_COPER,INTREQ(a5)
	move.w	#INTF_COPER,INTREQ(a5)
	addq.w	#1,VBI_Mids
	bsr	VBI_Mid			; la bande du bas
.notCopper:
	move.w	d7,d0
	and.w	#INTF_VERTB,d0
	beq.s	.notMine
	move.w	#INTF_VERTB,INTREQ(a5)
	move.w	#INTF_VERTB,INTREQ(a5)
	addq.w	#1,VBI_Count
	move.w	#1,VBI_Flag		; une trame a servir a la boucle
	bsr	VBI_Frame		; le travail de trame du programme
.notMine:
	movem.l	(sp)+,d0-d7/a0-a6
	rte

;----------------------------------------------------------------------
; VBI_Wait : rend la main sur la trame suivante.
;
; Le drapeau est pose par l'interruption et consomme ici. Si une trame
; est passee pendant que l'appelant travaillait, l'attente est nulle :
; un redessin qui deborde ne coute pas une trame de plus. Et comme le
; drapeau ne compte pas, trois trames perdues n'en rendent qu'une --
; la boucle reprend au present au lieu de rattraper dans le vide.
;----------------------------------------------------------------------
VBI_Wait:
	tst.w	VBI_Flag
	beq.s	VBI_Wait
	clr.w	VBI_Flag
	rts
