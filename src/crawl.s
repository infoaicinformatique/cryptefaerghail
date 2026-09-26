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
T_SHOP		= 9			; echoppe scellee dans un mur
T_TRAP		= 10			; dallage piege, invisible au depart
T_LEDGER	= 11			; le grand registre, scelle au greffe
T_STAIRSUP	= 12			; l'escalier qui remonte d'un etage
T_ARCHIVE	= 13			; un rayonnage du greffe

; MapParam d'un rayonnage : les sept bits bas donnent le livre qu'on y
; lit ($7f pour un rayonnage muet), le bit 7 dit que le groupe l'a lu.
ARCH_READ	= 7			; numero de bit
ARCH_MUTE	= $7f
NARCHIVES	= 3

; MapParam d'un piege : le quartet bas donne l'espece, le bit 7 dit que
; le groupe l'a repere. Un piege desamorce redevient du dallage.
TRAP_SEEN	= 7			; numero de bit
NTRAPS		= 4
tp_Name		= 0			; 16 octets
tp_Save		= 16			; 0 Vigueur, 1 Reflexes, 2 Volonte
tp_Faces	= 18			; faces du de de degats
tp_SIZEOF	= 20

; Les monstres marchent : un pas toutes les MONSTEP trames, vers le
; groupe et seulement s'il est a moins de MONRANGE cases. MON_MOVED est
; un bit de travail pose sur la case pendant le balayage.
MON_MOVED	= 6
MONSTEP		= 14
MONRANGE	= 6

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
hr_Race		= 54			; numero dans RaceTable
hr_Skills	= 56			; NSKILLS octets, 0 a 99 (voir SkillUse)
hr_SIZEOF	= 62

; les competences, dans l'ordre de SkillNames
SK_COMBAT	= 0
SK_DEFENSE	= 1
SK_CONCENT	= 2
SK_VIGIL	= 3
SK_DISARM	= 4
SK_TRADE	= 5
NHEROES		= 6			; six aventuriers, comme au temps des
					; jeux de roles a groupe
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
mt_Tongue	= 48			; langue parlee (TongueNames), 0 aucune
mt_Temper	= 50			; 0 hostile, 1 mefiant, 2 paisible
mt_SIZEOF	= 52

; --- classes ---
cl_Name		= 0			; 12 octets
cl_Hd		= 12			; de de vie
cl_Bab		= 14			; 0 complete, 1 trois quarts, 2 demie
cl_Fort		= 16			; 1 = sauvegarde forte
cl_Ref		= 18
cl_Will		= 20
cl_Cast		= 22			; 0 aucun, 1 profane (INT), 2 divin (SAG)
cl_SIZEOF	= 24

; RaceTable : nom, modificateurs des six caracteristiques, et un bit
; par classe que la race ne donne pas.
rc_Name		= 0			; 12 octets
rc_Mods		= 12			; FOR, DEX, CON, INT, SAG, CHA
rc_Ban		= 24			; masque des classes interdites
rc_SIZEOF	= 26
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
PHASE_PROLOG	= 3			; le prologue, depuis l'accueil
PROLOGPAGES	= 4			; pages du prologue
PROLOGROWS	= 16			; lignes qu'une page peut tenir
TITLEH		= 176			; hauteur de l'illustration
; L'etat d'un etage, garde d'une visite a l'autre : terrain, parametres,
; releve de la carte et etal du marchand. Sans lui, remonter un escalier
; rendrait l'etage neuf -- coffres pleins, monstres debout, echoppe
; regarnie -- et le donjon se moissonnerait en boucle.
LVSTATE		= 3*MAPBYTES+NSHOP
LVSTORE		= LEVELS*LVSTATE

; "FAE8" : le reglage du combat, detaille ou rapide, part avec les
; autres ; "FAE7" avait ajoute les competences, "FAE6" la race, "FAE5"
; passe le groupe a six. Une sauvegarde plus ancienne n'a plus le bon
; compte, et le nombre magique la fait refuser plutot que relire de
; travers.
SAVEMAGIC	= $46414538		; "FAE8"
SAVESIZE	= 4+14+NHEROES*hr_SIZEOF+INVSIZE+LVSTORE+LEVELS*2+8
UI_VIEW		= 0
UI_SHEET	= 1
UI_INV		= 2
UI_SPELL	= 3
UI_RIDDLE	= 4
UI_MAP		= 5
UI_BOOK		= 6			; le grimoire
UI_OPTS		= 7			; les reglages
UI_SHOP		= 8			; l'echoppe du marchand
UI_LEDGER	= 9			; le grand registre
UI_ARCHIVE	= 10			; un livre des rayonnages du greffe
UI_ROUND	= 11			; le resultat d'un round de combat

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
KEY_O		= $18
KEY_N		= $36			; meme place en AZERTY et en QWERTY			; meme place en AZERTY et en QWERTY

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
PANEL_STEP	= 24			; hauteur d'un bloc : six dans le panneau
PANEL_GAUGE	= 64			; longueur des jauges
FRONTRANK	= 3			; les trois premiers se tiennent devant
GROUPMAX	= 4			; creatures d'une meme rencontre, au plus
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
	bsr	LoadDungeon		; le paquet du donjon, depuis la disquette
	tst.w	d0
	beq	ExitNoDungeon
	bsr	CheckSave
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
	bsr	VBI_Install		; a partir d'ici, la trame nous appelle
	bsr	CIA_Install		; et le timer A bat la mesure -- les deux
					; avant la premiere musique, pour que
					; PlayMusic ne demasque jamais une
					; interruption sans gestionnaire
	move.w	#-1,CurMusic		; l'accueil a sa propre musique
	moveq	#0,d0
	bsr	PlayMusic
	move.w	#DMAF_SETCLR|DMAF_MASTER|DMAF_RASTER|DMAF_COPPER|DMAF_BLITTER|DMAF_AUDIO|DMAF_SPRITE,DMACON(a5)

	bsr	Redraw
	bsr	SwapBuffers
	bsr	Redraw

;----------------------------------------------------------------------
; Boucle principale
;
; La musique et l'echange de tampons ne sont plus de son ressort : ils
; se font dans l'interruption de retour trame (VBI_Frame, plus bas).
; C'est ce qui permet a un redessin de durer deux trames sans que le
; module perde un seul tic -- le defaut que l'on entendait en se
; deplacant, et que des appels au replayer semes dans le redessin ne
; rattrapaient qu'a moitie.
;----------------------------------------------------------------------
MainLoop:
	bsr	VBI_Wait
	bsr	SurfFlicker		; la torche respire, sans un blit
	move.w	VHPOSR+CUSTOM,d0	; le balayage brasse le hasard : sans
	eor.w	d0,RngSeed+2		; cela, chaque partie serait identique

	tst.w	InCombat		; la lanterne du guichet, si on la
	bne.s	.noFlame		; regarde : trois flammes en boucle
	tst.w	UiMode
	bne.s	.noFlame
	tst.w	ShopInSight
	beq.s	.noFlame
	addq.w	#1,AnimCount
	move.w	AnimCount,d0
	and.w	#7,d0
	bne.s	.noFlame
	move.w	FlameFrame,d0
	addq.w	#1,d0
	cmp.w	#3,d0
	blo.s	.flameOk
	moveq	#0,d0
.flameOk:
	move.w	d0,FlameFrame
	move.w	#1,NeedRedraw
.noFlame:
	tst.w	InCombat		; les monstres respirent
	beq.s	.noAnim
	tst.w	StrikeTime		; le coup porte, la pose d'attaque
	beq.s	.breath			; tient quelques trames
	subq.w	#1,StrikeTime
	bne.s	.noAnim
	move.w	#1,NeedRedraw
	bra.s	.noAnim
.breath:
	addq.w	#1,AnimCount
	move.w	AnimCount,d0
	and.w	#7,d0
	bne.s	.noAnim
	move.w	AnimFrame,d0
	eor.w	#1,d0
	move.w	d0,AnimFrame
	move.w	#1,NeedRedraw
.noAnim:
	bsr	MonWalk			; les monstres avancent d'une case
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
	cmp.w	#PHASE_PROLOG,d1
	bne.s	.notPrologKey
	bsr	PrologKey
	bra.s	.noKey
.notPrologKey:
	tst.w	d1
	bne.s	.playKey
	bsr	CreateKey
	bra.s	.noKey
.playKey:
	bsr	HandleKey
.noKey:
	tst.w	NeedRedraw
	beq.s	.noDraw
	tst.w	DrawReady		; l'image finie attend encore le retour
	bne.s	.noDraw			; trame : redessiner maintenant, ce
	clr.w	NeedRedraw		; serait se faire echanger les tampons
	bsr	Redraw			; en pleine page -- le fond efface dans
	move.w	#1,DrawReady		; l'un, le texte pose dans l'autre
.noDraw:
	tst.w	Quit
	beq	MainLoop

	bsr	CIA_Remove
	bsr	VBI_Remove
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

; Sans son donjon, le jeu n'a rien a montrer : on le dit dans le Shell
; et l'on rend la main avec un code d'echec, avant d'avoir touche a
; l'ecran ou aux interruptions.
ExitNoDungeon:
	move.l	DosBase,d0
	beq.s	.noDos
	move.l	d0,a6
	jsr	_LVOOutput(a6)
	move.l	d0,d1
	beq.s	.silent
	move.l	#TxtNoDungeon,d2
	move.l	#TXTNODUNGEON_LEN,d3
	jsr	_LVOWrite(a6)
.silent:
	move.l	DosBase,a1
	move.l	4.w,a6
	jsr	_LVOCloseLibrary(a6)
.noDos:
	move.l	4.w,a6
	move.l	GfxBase,a1
	jsr	_LVOCloseLibrary(a6)
	movem.l	(sp)+,d0-d7/a0-a6
	moveq	#20,d0
	rts

;----------------------------------------------------------------------
; LoadDungeon : le paquet du donjon, lu depuis la disquette
;
; Tout etait incorpore a l'executable : les decors, les cartes, le
; bestiaire. Un donjon est maintenant un fichier a part, comme dans
; les jeux de l'epoque ou chaque donjon avait ses fichiers sur la
; disquette -- c'est ce qui permettra d'en avoir plusieurs sans que
; l'executable grossisse d'autant. Le paquet porte les cartes de ses
; etages et son bestiaire ; il est lu tel quel en Chip, le blitter y
; prend les creatures directement.
;
; Format : "FDG1", puis decalage et taille des cartes, decalage et
; taille du banc de morceaux (quatre mots longs), puis les donnees.
; -> d0 = 1 si le donjon est charge
;----------------------------------------------------------------------
LoadDungeon:
	movem.l	d1-d7/a0-a6,-(sp)
	moveq	#0,d5
	move.l	DosBase,d0
	beq.s	.done
	move.l	d0,a6
	move.l	#DungeonName,d1
	move.l	#MODE_OLDFILE,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.s	.done
	move.l	d4,d1
	move.l	#DgnPack,d2
	move.l	#DGNPACKMAX,d3
	jsr	_LVORead(a6)
	move.l	d0,d6			; ce qui a ete lu
	move.l	d4,d1
	jsr	_LVOClose(a6)
	cmp.l	#20,d6			; au moins l'en-tete
	blt.s	.done
	lea	DgnPack,a0
	cmp.l	#DGNMAGIC,(a0)
	bne.s	.done
	move.l	4(a0),d0		; les cartes
	move.l	d0,d1
	add.l	8(a0),d1
	cmp.l	d6,d1			; le fichier doit les contenir
	bgt.s	.done
	add.l	a0,d0
	move.l	d0,DgnMapPtr
	move.l	12(a0),d0		; le bestiaire
	move.l	d0,d1
	add.l	16(a0),d1
	cmp.l	d6,d1
	bgt.s	.done
	add.l	a0,d0
	move.l	d0,DgnBank
	moveq	#1,d5
.done:
	move.l	d5,d0
	movem.l	(sp)+,d1-d7/a0-a6
	rts

DGNMAGIC	= $46444731		; "FDG1"

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
; VBI_Frame : le travail cadence, appele depuis l'interruption de
; retour trame. a5 = CUSTOM, tous les registres sont libres.
;
; Deux choses seulement, mais qui ne souffrent pas d'attendre que la
; boucle principale ait fini son redessin :
;   - l'echange des tampons, qui tombe ainsi dans le retour trame et
;     non au milieu de l'image (plus de dechirure) ;
;   - le tic du module, a 50 Hz quoi qu'il arrive.
;----------------------------------------------------------------------
VBI_Frame:
	tst.w	DrawReady		; une image finie attend d'etre montree
	beq.s	.noSwap
	clr.w	DrawReady
	bsr	SwapBuffers
.noSwap:
	rts				; la musique, elle, suit le timer A

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
	bsr	CIA_Lock		; le replayer ne doit pas passer ici
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
	bsr	CIA_Unlock
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
	cmp.w	#UI_ROUND,d4		; le resultat du round : un clic
	bne.s	.notRoundClick		; vaut une touche
	moveq	#KEY_SPACE,d0
	bsr	HandleKey
	bra	.done
.notRoundClick:
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
	lea	DgnArt,a0		; les morceaux communs, dans l'executable
	cmp.w	#ART_BANK,d0
	blo.s	.common
	move.l	DgnBank,a0		; ceux du donjon, dans son paquet
	sub.w	#ART_BANK,d0
.common:
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

; HLine : d0 = x, d1 = y, d2 = longueur, d3 = couleur -- au pixel pres
;
; Elle travaillait a l'octet : le x etait arrondi a l'octet du dessous
; et la longueur tronquee a l'octet. DrawFrame lui passe x-1 pour son
; ombre portee, et huit pixels s'allumaient donc tout a gauche de
; l'ecran, sur la ligne du haut du cadre comme sur celle du bas --
; caches partout ailleurs par un fond de panneau, bien visibles sur le
; prologue, qui est sur fond noir. Un trait de moins de huit pixels,
; lui, ne se dessinait pas du tout.
;
; On pose donc un masque a chaque bord : $ff decale a droite du reste
; du premier pixel, $ff decale a gauche du complement du dernier, et
; les octets pleins entre les deux.
HLine:
	movem.l	d0-d7/a0-a2,-(sp)
	bsr	WaitBlit
	tst.w	d2
	ble	.done			; longueur nulle : rien a tracer
	move.l	DrawBuf,a2
	move.w	d1,d4
	mulu.w	#SCRBPL,d4
	move.w	d0,d5
	lsr.w	#3,d5			; octet du premier pixel
	add.w	d5,d4
	add.l	d4,a2

	move.w	d0,d6			; masque de gauche : $ff >> (x et 7)
	and.w	#7,d6
	move.w	#$00ff,d4
	lsr.b	d6,d4

	move.w	d0,d1			; le dernier pixel du trait
	add.w	d2,d1
	subq.w	#1,d1
	move.w	d1,d5
	lsr.w	#3,d5
	move.w	d0,d6
	lsr.w	#3,d6
	sub.w	d6,d5			; d5 = nombre d'octets, moins un

	move.w	d1,d6			; masque de droite : $ff << 7-(fin et 7)
	not.w	d6
	and.w	#7,d6
	move.w	#$00ff,d7
	lsl.b	d6,d7

	tst.w	d5
	bne.s	.wide
	and.b	d7,d4			; tout tient dans un seul octet
.wide:
	moveq	#0,d6			; plan courant
.planeLoop:
	move.l	a2,a0
	moveq	#0,d2			; $ff si ce plan porte la couleur
	btst	d6,d3
	beq.s	.zero
	moveq	#-1,d2
.zero:
	move.b	(a0),d0			; le premier octet, sous son masque
	move.b	d4,d1
	not.b	d1
	and.b	d1,d0
	move.b	d4,d1
	and.b	d2,d1
	or.b	d1,d0
	move.b	d0,(a0)+
	tst.w	d5
	beq.s	.next			; il n'y en avait qu'un
	move.w	d5,d1
	subq.w	#2,d1			; les octets pleins du milieu
	bmi.s	.last
.mid:
	move.b	d2,(a0)+
	dbf	d1,.mid
.last:
	move.b	(a0),d0			; le dernier octet, sous son masque
	move.b	d7,d1
	not.b	d1
	and.b	d1,d0
	move.b	d7,d1
	and.b	d2,d1
	or.b	d1,d0
	move.b	d0,(a0)
.next:
	lea	PLANESIZE(a2),a2
	addq.w	#1,d6
	cmp.w	#DEPTH,d6
	blt.s	.planeLoop
.done:
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
	sub.w	#FONT8FIRST,d4
	bmi.s	.next
	cmp.w	#FONT8LAST-FONT8FIRST+1,d4
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
	cmp.w	#T_LEDGER,d2
	beq.s	.yes
	cmp.w	#T_ARCHIVE,d2
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
	beq	.world
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
	cmp.w	#UI_LEDGER,d0
	bne.s	.notLedger
	bsr	DrawLedger
	bra	.done
.notLedger:
	cmp.w	#UI_ARCHIVE,d0
	bne.s	.notArchive
	bsr	DrawArchive
	bra	.done
.notArchive:
	cmp.w	#UI_ROUND,d0
	bne.s	.notRound
	bsr	DrawRound
	bra	.done
.notRound:
	bsr	DrawSpellMenu
	bra	.done

.world:
	moveq	#ART_BG,d0
	moveq	#1,d1
	bsr	BlitPiece

	tst.w	InCombat
	beq.s	.dungeon
	move.w	MonArt,d0		; trois poses par famille : deux qui
	mulu.w	#NMONPOSES,d0		; respirent, et celle qui frappe
	tst.w	StrikeTime
	beq.s	.breathe
	addq.w	#2,d0
	bra.s	.posed
.breathe:
	add.w	AnimFrame,d0
.posed:
	add.w	#ART_MONSTER,d0
	moveq	#0,d1
	bsr	BlitPiece
	bsr	DrawOrderTag		; a qui l'ordre, et combien ils sont
	bra	.done

.dungeon:
	clr.w	ShopInSight		; le guichet le reposera s'il se voit
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
	cmp.w	#T_ARCHIVE,d4		; un rayonnage, a toute distance
	bne.s	.notShelf
	cmp.w	#4,d7
	bge.s	.stone
	move.w	d7,d0
	add.w	#ART_ARCHIVE-1,d0
	bra.s	.blitFront
.notShelf:
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
	cmp.w	#T_LEDGER,d4		; le pupitre se voit du fond du greffe
	bne.s	.notLedgerArt
	cmp.w	#4,d7
	bge	.noFront
	move.w	d7,d0
	add.w	#ART_LEDGER-1,d0
	moveq	#0,d1
	bsr	BlitPiece
	bra	.noFront
.notLedgerArt:
	cmp.w	#T_SHOP,d4		; le guichet aussi, a trois pas
	bne.s	.notShopFar
	cmp.w	#4,d7
	bge	.noFront
	move.w	d7,d0
	add.w	#ART_SHOP-1,d0
	moveq	#0,d1
	bsr	BlitPiece
	cmp.w	#1,d7			; de pres, sa lanterne brule
	bne	.noFront
	move.w	FlameFrame,d0
	add.w	#ART_FLAME,d0
	moveq	#0,d1
	bsr	BlitPiece
	move.w	#1,ShopInSight
	bra	.noFront
.notShopFar:
	cmp.w	#1,d7			; les autres details, de pres seulement
	bne	.noFront
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
	beq	.open
	and.w	#$000f,d0		; un rayonnage de biais : les
	cmp.w	#T_ARCHIVE,d0		; registres courent le long du mur
	bne.s	.stoneSide
	move.w	d6,d0
	tst.w	d5
	bmi.s	.shelfLeft
	add.w	#ART_ARCHR,d0
	bra.s	.blitSide
.shelfLeft:
	add.w	#ART_ARCHL,d0
	bra.s	.blitSide
.stoneSide:
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
	and.w	#$000f,d0		; des registres au fond du passage
	cmp.w	#T_ARCHIVE,d0
	bne.s	.stoneBack
	move.w	d6,d0
	tst.w	d5
	bmi.s	.shelfBackL
	add.w	#ART_ARCHFR,d0
	bra.s	.blitBack
.shelfBackL:
	add.w	#ART_ARCHFL,d0
	bra.s	.blitBack
.stoneBack:
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
	and.w	#$000f,d0		; le mur d'en face du passage peut
	cmp.w	#T_ARCHIVE,d0		; etre un rayonnage : le greffe vu
	bne.s	.stoneOuter		; de son entree
	move.w	d6,d0
	subq.w	#2,d0
	tst.w	d5
	bmi.s	.shelfOuterL
	add.w	#ART_ARCHOR,d0
	bra.s	.blitOuter
.shelfOuterL:
	add.w	#ART_ARCHOL,d0
	bra.s	.blitOuter
.stoneOuter:
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
	dbf	d6,.sideLoop
	bsr	DrawCorridorMon		; ce qui vient vers le groupe
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Redraw : tout l'ecran dans le tampon de dessin
;----------------------------------------------------------------------
Redraw:
	movem.l	d0-d7/a0-a6,-(sp)
	cmp.w	#PHASE_TITLE,Phase
	bne.s	.notTitle
	bsr	DrawTitle
	bra	.drawn
.notTitle:
	cmp.w	#PHASE_PROLOG,Phase
	bne.s	.game
	bsr	DrawProlog
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
	bsr	DrawLog
	bsr	DrawStatus
.drawn:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; DrawParty : portrait, nom, points de vie et de magie
;----------------------------------------------------------------------
;----------------------------------------------------------------------
; DrawParty : six blocs de vingt-quatre lignes
;
; Le groupe est passe de quatre a six, et le panneau n'a pas grandi :
; chaque bloc perd le grand portrait, qui reste sur la fiche, pour un
; visage reduit de seize pixels. Le nom et le niveau sur la premiere
; ligne ; a cote du visage, les points de vie, puis deux jauges -- la
; vie, et la magie pour qui en a.
;----------------------------------------------------------------------
DrawParty:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	Heroes,a6
	moveq	#0,d7
.heroLoop:
	move.w	d7,d5
	mulu.w	#PANEL_STEP,d5
	add.w	#PANEL_TOP,d5		; ligne du bloc

	tst.w	hr_HpMax(a6)
	bne.s	.exists
	lea	TxtEmptySlot,a0
	move.w	#29,d0
	move.w	d5,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	bra	.heroNext
.exists:
	move.l	a6,a0			; le nom, puis le niveau cale a droite
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

	lea	TmpStr,a1
	move.w	hr_Level(a6),d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#38,d0
	cmp.w	#10,hr_Level(a6)
	blt.s	.lvlOne
	subq.w	#1,d0			; deux chiffres : une colonne de plus
.lvlOne:
	move.w	d5,d1
	move.w	#C_PARCHD,d2		; l'or est reserve au heros choisi
	bsr	DrawText

	move.w	hr_Class(a6),d0		; le visage, sous le nom
	add.w	#ART_FACE,d0
	moveq	#0,d1
	move.w	d5,d2
	addq.w	#8,d2
	mulu.w	#SCRBPL,d2
	add.w	#PANEL_X/8,d2
	bsr	BlitPieceAt

	lea	TmpStr,a1		; les points de vie, a cote
	move.w	hr_Hp(a6),d0
	bsr	StrNum
	cmp.w	#100,hr_HpMax(a6)	; au-dela de cent, le total ne tient
	bge.s	.hpShort		; pas dans le panneau
	move.b	#'/',(a1)+
	move.w	hr_HpMax(a6),d0
	bsr	StrNum
.hpShort:
	clr.b	(a1)
	lea	TmpStr,a0
	move.w	#30,d0
	move.w	d5,d1
	addq.w	#8,d1
	move.w	#C_HEALTH,d2
	move.w	hr_Hp(a6),d3
	add.w	d3,d3
	cmp.w	hr_HpMax(a6),d3
	bge.s	.hpOk
	move.w	#C_ALERT,d2		; sous la moitie : en rouge
.hpOk:
	move.w	d2,d6			; on garde la teinte pour la jauge
	bsr	DrawText

	movem.l	d5-d6,-(sp)		; la jauge de vie
	move.w	#PANEL_X+16,d0
	move.w	d5,d1
	add.w	#17,d1
	moveq	#PANEL_GAUGE,d2
	move.w	hr_Hp(a6),d3
	move.w	hr_HpMax(a6),d4
	move.w	d6,d5
	bsr	DrawGauge
	movem.l	(sp)+,d5-d6

	tst.w	hr_MpMax(a6)		; et celle de la magie, si la classe
	beq.s	.heroNext		; en a
	movem.l	d5-d6,-(sp)
	move.w	#PANEL_X+16,d0
	move.w	d5,d1
	add.w	#21,d1
	moveq	#PANEL_GAUGE,d2
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

	move.w	#PANEL_X+4,d0		; entre l'avant et l'arriere, un trait
	move.w	#PANEL_TOP+FRONTRANK*PANEL_STEP-2,d1
	moveq	#80,d2
	move.w	#C_FRAME,d3
	bsr	HLine
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
	bne.s	.helpLedger
	lea	TxtHelpShop,a0
	bra	.help
.helpLedger:
	cmp.w	#UI_LEDGER,d0
	bne.s	.helpArchive
	lea	TxtHelpLedger,a0
	bra	.help
.helpArchive:
	cmp.w	#UI_ARCHIVE,d0
	bne.s	.helpRound
	lea	TxtHelpArchive,a0
	bra	.help
.helpRound:
	cmp.w	#UI_ROUND,d0
	bne.s	.helpOther
	lea	TxtRoundGo,a0
	bra	.help
.helpOther:
	lea	TxtHelpSheet,a0
	bra	.help
.helpView:
	tst.w	InCombat
	beq.s	.helpMove
	lea	TxtHelpFight,a0
	tst.w	MeetPhase
	beq	.help
	lea	TxtHelpMeet,a0
	cmp.w	#MEET_TOLL,MeetPhase
	bne	.help
	lea	TxtHelpToll,a0
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

OPTROWS		= 6			; lignes de reglage

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
	bne.s	.notKb
	move.l	#TxtOptAzerty,d0
	tst.w	KbLayout
	beq.s	.done
	move.l	#TxtOptQwerty,d0
	bra.s	.done
.notKb:
	cmp.w	#3,d1
	bne.s	.done
	move.l	#TxtOptDetail,d0
	tst.w	OptQuick
	beq.s	.done
	move.l	#TxtOptQuick,d0
.done:
	movem.l	(sp)+,d1
	rts

; SilenceAudio : les quatre volumes a zero. Le replayer garde son etat,
; il ne l'entend plus -- c'est ce que veut dire "musique : non", et
; c'est aussi ce qu'il faut faire en reprenant une partie sauvee sur ce
; reglage, sinon PT_Init rend la voix a un module qu'on avait tu.
SilenceAudio:
	movem.l	d1/a0,-(sp)
	lea	CUSTOM+AUD0LCH,a0
	moveq	#3,d1
.chan:
	clr.w	AUDx_VOL(a0)
	lea	16(a0),a0
	dbf	d1,.chan
	movem.l	(sp)+,d1/a0
	rts

OptToggle:				; agit sur la ligne visee
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	OptCursor,d0
	tst.w	d0
	bne.s	.notMusic
	eor.w	#1,OptMusic
	tst.w	OptMusic
	bne.s	.redraw
	bsr	SilenceAudio		; on coupe le son tout de suite
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
	bne.s	.notCombat
	eor.w	#1,OptQuick
	bra.s	.redraw
.notCombat:
	cmp.w	#4,d0
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
	move.w	#TITLEH+12,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	lea	TxtMenuLoad,a0
	moveq	#5,d0
	move.w	#TITLEH+24,d1
	move.w	#C_HILITE,d2
	tst.w	HasSave
	bne.s	.hasSave
	move.w	#C_TEXTLOW,d2		; rien a reprendre : en gris
.hasSave:
	bsr	DrawText

	lea	TxtMenuStory,a0
	moveq	#5,d0
	move.w	#TITLEH+36,d1
	move.w	#C_TEXT,d2
	bsr	DrawText

	lea	TxtMenuQuit,a0
	moveq	#5,d0
	move.w	#TITLEH+48,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText

	lea	TxtMenuHint,a0
	moveq	#5,d0
	move.w	#TITLEH+60,d1
	move.w	#C_TEXTLOW,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Le prologue : ce qu'etait Faerghail, en trois pages, depuis l'accueil.
;
; Le texte est celui de docs/histoire.md, resserre a trente-six signes
; -- la largeur du journal, donc celle que la police 8x8 tient dans le
; cadre. Chaque page est une liste de lignes terminee par un long nul :
; on ajoute une ligne sans rien recompter, et la derniere page ne
; demande pas de cas particulier.
;----------------------------------------------------------------------
DrawProlog:
	movem.l	d0-d7/a0-a6,-(sp)
	moveq	#0,d0
	moveq	#0,d1
	move.w	#SCRW,d2
	move.w	#SCRH,d3
	move.w	#C_BLACK,d4
	bsr	FillRect
	moveq	#8,d0
	moveq	#8,d1
	move.w	#304,d2
	move.w	#240,d3
	bsr	DrawFrame

	lea	TxtPrologTitle,a0
	moveq	#2,d0
	moveq	#16,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	move.w	PrologPage,d0
	lsl.w	#2,d0
	lea	PrologPages,a0
	move.l	(a0,d0.w),a3		; les lignes de la page
	moveq	#0,d7
.lineLoop:
	cmp.w	#PROLOGROWS,d7		; le cadre s'arrete la : au-dela, le
	bge.s	.linesDone		; texte deborderait dans le plan suivant
	move.l	(a3)+,d0
	beq.s	.linesDone
	move.l	d0,a0
	move.w	#C_TEXT,d2
	cmp.b	#$2a,(a0)		; une ligne marquee d'un * passe a l'or
	bne.s	.plain
	addq.l	#1,a0
	move.w	#C_HILITE,d2
.plain:
	moveq	#2,d0
	move.w	d7,d1
	mulu.w	#12,d1
	add.w	#32,d1
	bsr	DrawText
	addq.w	#1,d7
	bra.s	.lineLoop
.linesDone:
	lea	TmpStr,a1		; PAGE n SUR N
	lea	TxtPrologPage,a0
	bsr	StrCopy
	move.w	PrologPage,d0
	addq.w	#1,d0
	bsr	StrNum
	lea	TxtPrologOf,a0
	bsr	StrCopy
	move.w	#PROLOGPAGES,d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#2,d0
	move.w	#226,d1
	move.w	#C_TEXTLOW,d2
	bsr	DrawText

	lea	TxtPrologHelp,a0
	moveq	#2,d0
	move.w	#238,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; PrologKey : n'importe quelle touche tourne la page, les fleches
; reviennent en arriere, ESC rend l'accueil -- et la page tournee apres
; la derniere le rend aussi, pour qui lit sans regarder les touches.
PrologKey:
	movem.l	d1-d7/a0-a6,-(sp)
	cmp.w	#KEY_ESC,d0
	beq.s	.back
	cmp.w	#KEY_LEFT,d0
	beq.s	.prev
	cmp.w	#KEY_UP,d0
	beq.s	.prev
	move.w	PrologPage,d1
	addq.w	#1,d1
	cmp.w	#PROLOGPAGES,d1
	blt.s	.set
.back:
	move.w	#PHASE_TITLE,Phase
	bra.s	.redraw
.prev:
	move.w	PrologPage,d1
	subq.w	#1,d1
	bpl.s	.set
	moveq	#0,d1
.set:
	move.w	d1,PrologPage
.redraw:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d1-d7/a0-a6
	rts

; PlayMusic : d0 = 0 pour l'accueil, 1 pour le donjon. Le replayer ne
; tient qu'un module a la fois : on l'arrete, on le reinitialise sur
; l'autre partition, et on rend le DMA audio que PT_Stop avait coupe.
PlayMusic:
	movem.l	d0-d1/a0-a1/a5,-(sp)
	cmp.w	CurMusic,d0
	beq.s	.done
	move.w	d0,CurMusic
	bsr	CIA_Lock		; PT_Init refait les quatre canaux
	bsr	PT_Stop
	lea	PT_TitleModule,a0
	tst.w	d0
	beq.s	.init
	lea	PT_ModuleData,a0
.init:
	bsr	PT_Init
	lea	CUSTOM,a5
	move.w	#DMAF_SETCLR|DMAF_AUDIO,DMACON(a5)
	bsr	CIA_Unlock
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
	bne.s	.notLoad
	tst.w	HasSave
	beq.s	.done
	bsr	LoadGame
	tst.w	d0
	beq.s	.done
	bsr	ClearScreens
	moveq	#1,d0
	bsr	PlayMusic
	tst.w	OptMusic		; la partie reprend comme on l'a laissee
	bne.s	.music
	bsr	SilenceAudio
.music:
	move.w	#PHASE_PLAY,Phase
	lea	TxtResumed,a0
	bsr	LogAdd
	bra.s	.redraw
.notLoad:
	cmp.w	#KEY_1+2,d0		; ce qu'etait cette crypte
	bne.s	.done
	clr.w	PrologPage
	move.w	#PHASE_PROLOG,Phase
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
	bsr	LevelStash		; l'etage courant d'abord, il n'est
	bsr	PackSave		; dans la sauvegarde que par son etat
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
	tst.w	d5
	beq.s	.done
	bsr	LevelRestore		; la copie de travail vient de l'etat
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
	moveq	#SK_DEFENSE,d0		; savoir parer
	bsr	SkillTen
	add.w	d0,d2
	tst.w	InCombat		; et parer ce round-ci
	beq.s	.noGuard
	bsr	HeroIndex
	lea	Guarding,a0
	tst.b	(a0,d0.w)
	beq.s	.noGuard
	addq.w	#GUARDAC,d2
.noGuard:
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
	tst.w	SheetPage		; TAB : la page des competences
	beq.s	.page1
	bsr	DrawSkills
	bra	.done
.page1:
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

	move.w	hr_Race(a6),d0		; la race, dessous
	mulu.w	#rc_SIZEOF,d0
	lea	RaceTable,a0
	add.l	d0,a0
	moveq	#3,d0
	moveq	#30,d1
	move.w	#C_PARCHD,d2
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
	moveq	#40,d1
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
	mulu.w	#10,d1
	add.w	#52,d1
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

	move.w	CreRace,d0		; ce que la race y ajoute ou retire
	mulu.w	#rc_SIZEOF,d0
	lea	RaceTable,a0
	lea	rc_Mods(a0,d0.w),a0
	lea	CreStr,a2
	moveq	#5,d5
.race:
	move.w	(a0)+,d0
	add.w	d0,(a2)
	cmp.w	#3,(a2)			; jamais sous trois
	bge.s	.raceOk
	move.w	#3,(a2)
.raceOk:
	addq.l	#2,a2
	dbf	d5,.race

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
	move.w	CreRace,hr_Race(a6)
	lea	SkillClass,a0		; les competences : le metier, et ce
	move.w	CreClass,d0		; que la race y ajoute
	mulu.w	#NSKILLS,d0
	add.l	d0,a0
	lea	SkillRace,a1
	move.w	CreRace,d0
	mulu.w	#NSKILLS,d0
	add.l	d0,a1
	lea	hr_Skills(a6),a2
	moveq	#NSKILLS-1,d1
.skills:
	move.b	(a0)+,d0
	add.b	(a1)+,d0
	move.b	d0,(a2)+
	dbf	d1,.skills
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
	bsr	LevelEnter
	moveq	#17,d0			; deux potions pour la route
	bsr	AddItem
	moveq	#17,d0
	bsr	AddItem
	lea	TxtIntro,a0
	bsr	LogAdd
	bsr	LogFloor
	rts

CreateKey:
	movem.l	d1-d7/a0-a6,-(sp)
	cmp.w	#KEY_ESC,d0
	bne.s	.notEsc
	move.w	#1,Quit
	bra	.done
.notEsc:
	move.w	CreStep,d7
	bne	.notRace
	moveq	#NRACES,d3		; --- la race : six entrees
	bsr	CreListKey
	tst.w	d2
	bmi	.redraw
	move.w	d2,CreRace
	clr.w	CreCursor		; la premiere classe que la race donne
.firstClass:
	move.w	CreCursor,d2
	bsr	ClassBanned
	tst.w	d0
	beq.s	.toClass
	addq.w	#1,CreCursor
	bra.s	.firstClass
.toClass:
	move.w	#1,CreStep
	bra	.redraw
.notRace:
	cmp.w	#1,d7
	bne	.notClass
	moveq	#NCLASSES,d3		; --- la classe : onze entrees
	bsr	CreListKey
	tst.w	d2
	bmi	.redraw
	move.w	d2,d4
	bsr	ClassBanned		; la race ne la donne pas : on le dit
	tst.w	d0
	beq.s	.takeClass
	lea	TxtBanned,a0
	bsr	LogAdd
	bra	.redraw
.takeClass:
	move.w	d4,CreClass
	bsr	RollHero
	move.w	#2,CreStep
	bra	.redraw
.notClass:
	cmp.w	#2,d7
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
	move.w	#3,CreStep
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

;----------------------------------------------------------------------
; CreListKey : une liste a curseur (races, classes). d0 = touche,
; d3 = nombre d'entrees. -> d2 = entree choisie (ENTREE ou chiffre),
; -1 si la touche n'a fait que deplacer le curseur, ou rien.
;----------------------------------------------------------------------
CreListKey:
	cmp.w	#KEY_UP,d0
	bne.s	.notUp
	move.w	CreCursor,d2
	subq.w	#1,d2
	bpl.s	.move
	moveq	#0,d2
	bra.s	.move
.notUp:
	cmp.w	#KEY_DOWN,d0
	bne.s	.notDown
	move.w	CreCursor,d2
	addq.w	#1,d2
	cmp.w	d3,d2
	blt.s	.move
	move.w	d3,d2
	subq.w	#1,d2
.move:
	move.w	d2,CreCursor
	moveq	#-1,d2
	rts
.notDown:
	cmp.w	#KEY_RETURN,d0		; ENTREE prend celle qui est visee
	bne.s	.digit
	move.w	CreCursor,d2
	rts
.digit:
	move.w	d0,d2			; 1 a 9, puis 0 pour la dixieme
	cmp.w	#KEY_1+9,d2
	bne.s	.notZero
	moveq	#9,d2
	bra.s	.check
.notZero:
	sub.w	#KEY_1,d2
	bmi.s	.none
.check:
	cmp.w	d3,d2
	bge.s	.none
	move.w	d2,CreCursor
	rts
.none:
	moveq	#-1,d2
	rts

; ClassBanned : d2 = classe -> d0 = 1 si la race choisie ne la donne pas
ClassBanned:
	movem.l	d1/a0,-(sp)
	move.w	CreRace,d0
	mulu.w	#rc_SIZEOF,d0
	lea	RaceTable,a0
	move.w	rc_Ban(a0,d0.w),d1
	moveq	#0,d0
	btst	d2,d1
	beq.s	.ok
	moveq	#1,d0
.ok:
	movem.l	(sp)+,d1/a0
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
	bne	.notRaceList

	lea	RaceTable,a6		; --- les six races, et ce qu'elles
	moveq	#0,d6			; changent aux caracteristiques
.raceLoop:
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	d6,d1
	mulu.w	#11,d1
	add.w	#34,d1
	move.w	#C_TEXTDIM,d2
	cmp.w	CreCursor,d6
	bne.s	.dimRace
	move.w	#C_TEXT,d2
.dimRace:
	bsr	DrawText
	lea	rc_SIZEOF(a6),a6
	addq.w	#1,d6
	cmp.w	#NRACES,d6
	blt	.raceLoop

	move.w	CreCursor,d0		; sa description, en bas du cadre
	lsl.w	#2,d0
	lea	RaceDesc,a5
	move.l	(a5,d0.w),a0
	moveq	#3,d0
	move.w	#126,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	lea	TxtPickRace,a0
	moveq	#3,d0
	move.w	#138,d1
	move.w	#C_HEALTH,d2
	bsr	DrawText
	bra	.done

.notRaceList:
	cmp.w	#1,d7
	bne	.chosen
	lea	ClassTable,a6		; --- les onze classes, sur deux
	moveq	#0,d6			; colonnes ; celles que la race ne
.classLoop:				; donne pas s'eteignent
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	d6,d1
	cmp.w	#6,d1
	blt.s	.leftCls
	moveq	#14,d0			; la deuxieme colonne
	subq.w	#6,d1
.leftCls:
	mulu.w	#11,d1
	add.w	#34,d1
	move.w	#C_TEXTDIM,d2
	move.l	d0,-(sp)
	move.w	d6,d2
	bsr	ClassBanned
	move.w	d0,d3
	move.l	(sp)+,d0
	move.w	#C_TEXTDIM,d2
	tst.w	d3
	beq.s	.allowed
	move.w	#C_TEXTLOW,d2
.allowed:
	cmp.w	CreCursor,d6		; la classe visee ressort
	bne.s	.dimClass
	move.w	#C_TEXT,d2
	tst.w	d3
	beq.s	.dimClass
	move.w	#C_ALERT,d2		; visee mais interdite
.dimClass:
	bsr	DrawText
	lea	cl_SIZEOF(a6),a6
	addq.w	#1,d6
	cmp.w	#NCLASSES,d6
	blt	.classLoop

	lea	TmpStr,a1		; la race retenue, en rappel
	move.w	CreRace,d0
	mulu.w	#rc_SIZEOF,d0
	lea	RaceTable,a0
	add.l	d0,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#104,d1
	move.w	#C_PARCHD,d2
	bsr	DrawText

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
	lea	TmpStr,a1		; race et classe retenues
	move.w	CreRace,d0
	mulu.w	#rc_SIZEOF,d0
	lea	RaceTable,a0
	add.l	d0,a0
	bsr	StrCopy
	move.b	#' ',(a1)+
	move.w	CreClass,d0
	mulu.w	#cl_SIZEOF,d0
	lea	ClassTable,a0
	add.l	d0,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
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

	cmp.w	#2,d7
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
	clr.w	Acquitted
	lea	LevelKnown,a1		; aucun etage n'a encore ete vu
	moveq	#LEVELS-1,d0
.clrLevel:
	clr.w	(a1)+
	dbf	d0,.clrLevel
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
	move.l	DgnMapPtr,a0		; les cartes du paquet du donjon
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
	cmp.w	#T_LEDGER,d0
	beq	.ledger
	cmp.w	#T_ARCHIVE,d0
	beq	.archive
	cmp.w	#T_TRAP,d0
	beq	.trap

	move.w	d4,PosX
	move.w	d5,PosY
	moveq	#SFX_STEP,d0
	bsr	SfxPlay
	move.w	d3,d6
	and.w	#$000f,d6
	cmp.w	#T_STAIRS,d6
	beq	.stairs
	cmp.w	#T_STAIRSUP,d6
	beq	.stairsUp
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
.ledger:
	lea	TxtLedgerSeen,a0
	bsr	LogAdd
	bra	.redraw
.archive:
	lea	TxtArchiveSeen,a0
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
	move.w	d4,MonX			; c'est la case ou il tient
	move.w	d5,MonY
	clr.w	MeetAmbush		; c'est nous qui venons a lui
	bsr	StartCombat
	bra.s	.redraw
.stairs:
	bsr	Descend
	bra.s	.redraw
.stairsUp:
	bsr	Ascend
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
	cmp.w	#T_LEDGER,d0
	beq	.ledgerOpen
	cmp.w	#T_ARCHIVE,d0
	beq	.archiveOpen
	cmp.w	#T_TRAP,d0
	beq	.trapDisarm
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
.ledgerOpen:
	move.w	#UI_LEDGER,UiMode
	moveq	#SFX_CHEST,d0
	bsr	SfxPlay
	lea	TxtLedgerOpen,a0
	bsr	LogAdd
	bra	.done
.archiveOpen:
	move.w	d4,d0
	move.w	d5,d1
	bsr	OpenArchive
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
	bra	.done
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
	cmp.w	#T_LEDGER,d2
	bne.s	.notLedgerMap
	move.w	#C_PARCH,d0		; le greffe : on y revient
	bra.s	.done
.notLedgerMap:
	cmp.w	#T_ARCHIVE,d2
	bne.s	.notShelfMap
	move.w	#C_PARCHD,d0		; ses rayonnages, un ton en dessous
	bra.s	.done
.notShelfMap:
	cmp.w	#T_STAIRSUP,d2
	bne.s	.notUpMap
	move.w	#C_BONE+N_BONE-2,d0	; l'escalier qui remonte
	bra.s	.done
.notUpMap:
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
	moveq	#6,d7
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

; Le prix se marchande : celui du groupe qui s'y entend le mieux parle,
; et sa competence MARCHANDAGE retranche jusqu'au quart du prix a
; l'achat, ajoute jusqu'au quart a la vente.
ShopPrice:				; d0 = objet -> d0 = prix du cote ouvert
	movem.l	d1-d2/a0/a6,-(sp)
	bsr	ItemPtr
	move.w	it_Value(a0),d1
	bsr	BestTrader
	lsr.w	#2,d0			; 0 a 24 pour cent
	moveq	#100,d2
	tst.w	ShopMode
	bne.s	.selling
	sub.w	d0,d2			; a l'achat, on paie moins
	mulu.w	d2,d1
	divu.w	#100,d1
	bra.s	.priced
.selling:
	lsr.w	#1,d1			; il rachete a moitie
	add.w	d0,d2			; un peu plus, pour qui sait vendre
	mulu.w	d2,d1
	divu.w	#100,d1
.priced:
	moveq	#0,d0
	move.w	d1,d0
	tst.w	d0
	bne.s	.done
	moveq	#1,d0			; jamais pour rien
.done:
	movem.l	(sp)+,d1-d2/a0/a6
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
	moveq	#0,d5			; une affaire conclue ?
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
	moveq	#1,d5
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
	moveq	#1,d5
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
	tst.w	d5
	beq.s	.noDeal
	bsr	BestTrader		; celui qui a parle y gagne peut-etre
	moveq	#SK_TRADE,d0
	bsr	SkillUse
.noDeal:
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

; TrapSkill, DisarmSkill : a6 = heros -> d0 = ce qu'il ajoute a son
; d20. Le roublard avait un bonus a part ; ce sont maintenant les
; competences VIGILANCE et DESAMORCAGE, ou il part avec de l'avance, et
; que tout le monde fait progresser en s'en servant.
TrapSkill:				; reperer : l'oeil, et le bon sens
	movem.l	d1,-(sp)
	moveq	#SK_VIGIL,d0
	bsr	SkillFifth
	move.w	d0,d1
	move.w	hr_Wis(a6),d0
	bsr	StatMod
	add.w	d1,d0
	movem.l	(sp)+,d1
	rts

DisarmSkill:				; desamorcer : le metier, et la main
	movem.l	d1,-(sp)
	moveq	#SK_DISARM,d0
	bsr	SkillFifth
	move.w	d0,d1
	move.w	hr_Dex(a6),d0
	bsr	StatMod
	add.w	d1,d0
	movem.l	(sp)+,d1
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
	tst.w	d3
	bne.s	.next
	moveq	#1,d3
	move.l	a6,a5			; le premier qui l'a vu
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
	move.l	a5,a6			; son oeil s'aiguise
	moveq	#SK_VIGIL,d0
	bsr	SkillUse
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
	bsr	DisarmSkill
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
	moveq	#SK_DISARM,d0		; la main s'affermit
	bsr	SkillUse
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


;----------------------------------------------------------------------
; Le grand registre, au greffe du dernier etage
;
; La maison de garde tenait ses comptes ici : un nom, une promesse, un
; gage, et la ligne rayee le jour ou le deposant revenait le chercher.
; Personne n'est revenu depuis un siecle, et la maison recouvre sur les
; heritiers -- c'est pour cela que le groupe est descendu.
;
; Le registre montre les six noms du groupe, qui sont les six
; colonnes de signature d'une quittance. Rayer la ligne ouvre la porte
; des quittances, tout en bas : sans cela, l'escalier du dernier etage
; ne mene nulle part (voir Descend).
;----------------------------------------------------------------------
DrawLedger:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect

	lea	TxtLedgerTitle,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	lea	TxtLedgerHouse,a0
	moveq	#3,d0
	moveq	#32,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	lea	TxtLedgerFloor,a0
	moveq	#3,d0
	moveq	#42,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText

	lea	TxtLedgerHead,a0	; l'en-tete suit l'etat de la ligne
	tst.w	Acquitted
	beq.s	.headOk
	lea	TxtLedgerHeadOk,a0
.headOk:
	moveq	#3,d0
	moveq	#58,d1
	move.w	#C_TEXT,d2
	bsr	DrawText

	lea	Heroes,a6		; les six colonnes de signature
	moveq	#0,d7
.nameLoop:
	lea	TmpStr,a1
	move.w	d7,d0
	addq.w	#1,d0
	bsr	StrNum
	lea	TxtLedgerDot,a0
	bsr	StrCopy
	tst.w	hr_HpMax(a6)
	beq.s	.empty
	move.l	a6,a0
	bra.s	.copyName
.empty:
	lea	TxtEmptySlot,a0
.copyName:
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#5,d0			; six colonnes, six lignes
	move.w	d7,d1
	mulu.w	#9,d1
	add.w	#68,d1
	move.w	#C_TEXT,d2
	tst.w	Acquitted
	beq.s	.notPaid
	move.w	#C_TEXTLOW,d2		; raye : la ligne s'eteint
.notPaid:
	bsr	DrawText
	lea	hr_SIZEOF(a6),a6
	addq.w	#1,d7
	cmp.w	#NHEROES,d7
	blt.s	.nameLoop

	tst.w	Acquitted		; le pied de la page
	bne.s	.struck
	lea	TxtLedgerQuill,a0
	moveq	#3,d0
	move.w	#124,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	lea	TxtLedgerAsk,a0
	moveq	#3,d0
	move.w	#138,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	bra.s	.done
.struck:
	lea	TxtLedgerDone,a0
	moveq	#3,d0
	move.w	#124,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	lea	TxtLedgerFree,a0
	moveq	#3,d0
	move.w	#138,d1
	move.w	#C_TEXT,d2
	bsr	DrawText
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; LedgerKey : ENTREE raye la ligne, et on ne la raye qu'une fois.
LedgerKey:
	movem.l	d0-d7/a0-a6,-(sp)
	cmp.w	#KEY_RETURN,d0
	bne	.done
	tst.w	Acquitted
	bne	.done
	move.w	#1,Acquitted
	moveq	#SFX_LEVEL,d0
	bsr	SfxPlay
	lea	TxtLedgerStruck,a0
	bsr	LogAdd
	lea	TxtLedgerOut,a0
	bsr	LogAdd
	lea	Heroes,a6		; signer, c'est comprendre ou l'on est
	moveq	#NHEROES-1,d6
.xpLoop:
	tst.w	hr_Hp(a6)
	beq.s	.xpNext
	add.w	#60,hr_Xp(a6)
	bsr	CheckLevel
.xpNext:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.xpLoop
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Les rayonnages du greffe
;
; Le greffe n'est pas qu'un pupitre : c'est la salle ou la maison range
; ce qu'elle sait. Trois de ses rayonnages portent un livre qu'on peut
; ouvrir -- les dalles, les portes a question, le guichet -- et disent
; ce que le groupe n'a fait jusque-la que subir. Les autres sont muets :
; des comptes, des noms, rien qui le regarde.
;
; La premiere lecture de chaque livre vaut de l'experience a tous ; le
; bit ARCH_READ de la case le retient, et part avec l'etage dans la
; sauvegarde.
;----------------------------------------------------------------------
ARCH_XP		= 25			; ce que vaut une premiere lecture
ARCHROWS	= 10			; lignes d'un livre, sous sa cote

OpenArchive:				; d0 = x, d1 = y du rayonnage
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	d0,d4
	move.w	d1,d5
	bsr	MapGetParam
	move.w	d0,d3
	and.w	#ARCH_MUTE,d0
	cmp.w	#NARCHIVES,d0
	blo.s	.book
	lea	TxtArchiveMute,a0	; un rayonnage muet
	bsr	LogAdd
	bra	.done
.book:
	move.w	d0,ArchiveBook
	move.w	#UI_ARCHIVE,UiMode
	moveq	#SFX_CHEST,d0
	bsr	SfxPlay
	lea	TxtArchiveOpen,a0
	bsr	LogAdd
	btst	#ARCH_READ,d3		; deja lu : la page, sans plus
	bne.s	.done
	move.w	d3,d2
	bset	#ARCH_READ,d2
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapSetParam
	lea	TxtArchiveLearn,a0
	bsr	LogAdd
	lea	Heroes,a6		; lire, c'est comprendre ou l'on est
	moveq	#NHEROES-1,d6
.xpLoop:
	tst.w	hr_Hp(a6)
	beq.s	.xpNext
	add.w	#ARCH_XP,hr_Xp(a6)
	bsr	CheckLevel
.xpNext:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.xpLoop
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; DrawArchive : le livre ouvert. Un titre, la cote du livre, puis ses
; lignes ; une ligne marquee d'une etoile passe a l'or, comme au
; prologue.
DrawArchive:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect

	move.w	ArchiveBook,d0
	lsl.w	#2,d0
	lea	ArchiveBooks,a0
	move.l	(a0,d0.w),a3		; titre, cote, puis les lignes
	move.l	(a3)+,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	move.l	(a3)+,a0
	moveq	#3,d0
	moveq	#32,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	moveq	#0,d7
.lineLoop:
	cmp.w	#ARCHROWS,d7		; le panneau s'arrete la
	bge.s	.done
	move.l	(a3)+,d0
	beq.s	.done
	move.l	d0,a0
	move.w	#C_TEXT,d2
	cmp.b	#$2a,(a0)		; l'etoile : la ligne qui reste
	bne.s	.plain
	addq.l	#1,a0
	move.w	#C_HILITE,d2
.plain:
	moveq	#3,d0
	move.w	d7,d1
	mulu.w	#10,d1
	add.w	#46,d1
	bsr	DrawText
	addq.w	#1,d7
	bra.s	.lineLoop
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

Descend:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	Level,d0
	addq.w	#1,d0
	cmp.w	#LEVELS,d0
	blt.s	.next
	tst.w	Acquitted		; la porte des quittances ne s'ouvre
	beq.s	.unpaid			; qu'a qui a raye sa ligne
	move.w	#1,GameOver
	moveq	#SFX_LEVEL,d0
	bsr	SfxPlay
	lea	TxtWin,a0
	bsr	LogAdd
	bra.s	.done
.unpaid:
	moveq	#SFX_DOOR,d0
	bsr	SfxPlay
	lea	TxtDoorHeld,a0
	bsr	LogAdd
	lea	TxtDoorHeld2,a0
	bsr	LogAdd
	bra.s	.done
.next:
	bsr	LevelStash		; l'etage quitte reste comme on le laisse
	move.w	d0,Level
	bsr	LevelEnter
	bsr	PartyRest
	bsr	SaveGame		; un etage franchi, une partie sauvee
	moveq	#SFX_DOOR,d0
	bsr	SfxPlay
	lea	TxtDescend,a0
	bsr	LogAdd
	bsr	LogFloor
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts


;----------------------------------------------------------------------
; L'etat d'un etage, d'une visite a l'autre
;
; Le jeu ne tenait qu'un etage a la fois : descendre le relisait depuis
; DgnMap, et l'etage quitte etait oublie. Tant qu'on ne redescendait
; jamais, cela ne se voyait pas. Depuis qu'un escalier remonte, il
; faudrait sans cela retrouver l'etage neuf a chaque passage -- coffres
; pleins, monstres debout, echoppe regarnie -- et le donjon se
; moissonnerait en boucle.
;
; On garde donc les trois etats cote a cote : terrain, parametres,
; releve de la carte et etal, LVSTATE octets par etage.
;----------------------------------------------------------------------
LevelSlot:				; -> a0 = l'etat de l'etage courant
	move.w	d0,-(sp)
	move.w	Level,d0
	mulu.w	#LVSTATE,d0
	lea	LevelStore,a0
	add.l	d0,a0
	move.w	(sp)+,d0
	rts

LevelStash:				; la copie de travail part dans l'etat
	movem.l	d0/a0-a2,-(sp)
	bsr	LevelSlot
	move.l	a0,a1
	lea	MapTerrain,a2
	bsr	.copy
	lea	MapParam,a2
	bsr	.copy
	lea	MapSeen,a2
	bsr	.copy
	lea	ShopStock,a2
	move.w	#NSHOP-1,d0
.stock:
	move.b	(a2)+,(a1)+
	dbf	d0,.stock
	move.w	Level,d0		; cet etage est desormais connu
	add.w	d0,d0
	lea	LevelKnown,a0
	move.w	#1,(a0,d0.w)
	movem.l	(sp)+,d0/a0-a2
	rts
.copy:
	move.w	#MAPBYTES-1,d0
.one:
	move.b	(a2)+,(a1)+
	dbf	d0,.one
	rts

LevelRestore:				; et l'etat revient dans la copie
	movem.l	d0/a0-a2,-(sp)
	bsr	LevelSlot
	move.l	a0,a1
	lea	MapTerrain,a2
	bsr	.copy
	lea	MapParam,a2
	bsr	.copy
	lea	MapSeen,a2
	bsr	.copy
	lea	ShopStock,a2
	move.w	#NSHOP-1,d0
.stock:
	move.b	(a1)+,(a2)+
	dbf	d0,.stock
	movem.l	(sp)+,d0/a0-a2
	rts
.copy:
	move.w	#MAPBYTES-1,d0
.one:
	move.b	(a1)+,(a2)+
	dbf	d0,.one
	rts

; LevelEnter : met en place l'etage courant. Deja visite, on le reprend
; ou on l'avait laisse ; sinon on le lit dans DgnMap et on le garde.
LevelEnter:
	movem.l	d0/a0,-(sp)
	move.w	Level,d0
	add.w	d0,d0
	lea	LevelKnown,a0
	tst.w	(a0,d0.w)
	beq.s	.neuf
	bsr	LevelRestore
	bra.s	.done
.neuf:
	bsr	LoadLevel
	bsr	LevelStash
.done:
	movem.l	(sp)+,d0/a0
	rts

; Ascend : on remonte par ou l'on est venu, donc sur l'escalier qui
; descend de l'etage du dessus.
Ascend:
	movem.l	d0-d7/a0-a6,-(sp)
	tst.w	Level
	beq	.jour
	bsr	LevelStash
	subq.w	#1,Level
	bsr	LevelEnter
	moveq	#0,d7			; retrouver l'escalier descendant
.rowLoop:
	moveq	#0,d6
.colLoop:
	move.w	d6,d0
	move.w	d7,d1
	bsr	MapCell
	and.w	#$000f,d0
	cmp.w	#T_STAIRS,d0
	bne.s	.nextCell
	move.w	d6,PosX
	move.w	d7,PosY
	bra.s	.placed
.nextCell:
	addq.w	#1,d6
	cmp.w	#MAPW,d6
	blt.s	.colLoop
	addq.w	#1,d7
	cmp.w	#MAPH,d7
	blt.s	.rowLoop
.placed:
	bsr	MarkSeen
	bsr	SaveGame
	moveq	#SFX_DOOR,d0
	bsr	SfxPlay
	lea	TxtAscend,a0
	bsr	LogAdd
	bsr	LogFloor
	bra.s	.done
.jour:
	lea	TxtNoWayUp,a0		; au-dessus du premier, c'est le jour
	bsr	LogAdd
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; LogFloor : une ligne de journal propre a l'etage. La crypte etait une
; maison de garde -- un etage par generation de greffiers, et la
; profondeur vaut l'anciennete des dettes (voir docs/histoire.md).
LogFloor:
	movem.l	d0/a0,-(sp)
	move.w	Level,d0
	cmp.w	#LEVELS,d0
	bcc.s	.done
	lsl.w	#2,d0
	lea	FloorLore,a0
	move.l	(a0,d0.w),a0
	bsr	LogAdd
.done:
	movem.l	(sp)+,d0/a0
	rts


;----------------------------------------------------------------------
; Les monstres marchent
;
; Ils tenaient leur case et attendaient qu'on leur rentre dedans. Un
; couloir vide etait sur, et le donjon n'avait pas de nerf. Ils font
; maintenant un pas toutes les MONSTEP trames vers le groupe, s'il est
; a moins de MONRANGE cases -- de loin, ils n'ont rien entendu.
;
; Un pas ne se pose que sur du dallage nu, sans rien dessus et sans
; parametre : ni porte, ni piege, ni escalier, ni la case d'un autre
; monstre. Celui qui arrive sur le groupe engage le combat lui-meme.
;
; Le bit MON_MOVED marque ceux qui ont deja bouge : sans lui, un
; monstre qui avance dans le sens du balayage serait rencontre une
; seconde fois par la meme boucle et traverserait l'etage d'un coup.
; La marque est effacee avant de sortir, pour qu'elle ne parte jamais
; dans une sauvegarde.
;----------------------------------------------------------------------
MonWalk:
	movem.l	d0-d7/a0-a6,-(sp)
	cmp.w	#PHASE_PLAY,Phase
	bne	.done
	tst.w	InCombat
	bne	.done
	tst.w	GameOver
	bne	.done
	move.w	VBI_Count,d0		; le pas se compte en trames, pas en
	move.w	d0,d1			; tours de boucle : un redessin qui en
	sub.w	MonLastVbi,d0		; prend deux ne doit pas ralentir ceux
	move.w	d1,MonLastVbi		; qui viennent vers le groupe
	cmp.w	#MONSTEP,d0		; (et au retour d'un combat, pas plus
	bls.s	.elapsed		; d'un pas d'un coup)
	moveq	#MONSTEP,d0
.elapsed:
	add.w	d0,MonClock
	move.w	MonClock,d0
	cmp.w	#MONSTEP,d0
	blt	.done
	clr.w	MonClock
	clr.w	MonMoved

	moveq	#0,d7
.rowLoop:
	moveq	#0,d6
.colLoop:
	move.w	d6,d0
	move.w	d7,d1
	bsr	MapCell
	btst	#MON_MOVED,d0
	bne.s	.nextCell
	and.w	#C_MASK,d0
	cmp.w	#C_MONSTER,d0
	bne.s	.nextCell
	bsr	MonStep
	tst.w	InCombat		; il a aborde le groupe : on s'arrete
	bne.s	.sweep
.nextCell:
	addq.w	#1,d6
	cmp.w	#MAPW,d6
	blt.s	.colLoop
	addq.w	#1,d7
	cmp.w	#MAPH,d7
	blt.s	.rowLoop
.sweep:
	bsr	MonUnmark
	tst.w	MonMoved
	beq.s	.done
	move.w	#1,NeedRedraw
.done:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; MonUnmark : efface les marques de travail sur toute la carte.
MonUnmark:
	movem.l	d0-d2/a0,-(sp)
	lea	MapTerrain,a0
	move.w	#MAPBYTES-1,d0
.loop:
	move.b	(a0),d1
	bclr	#MON_MOVED,d1
	move.b	d1,(a0)+
	dbf	d0,.loop
	movem.l	(sp)+,d0-d2/a0
	rts

; MonStep : d6,d7 = case du monstre. Un pas vers le groupe, sur l'axe
; ou l'ecart est le plus grand ; si ce pas est bouche, sur l'autre.
MonStep:
	movem.l	d0-d5/a0,-(sp)
	move.w	PosX,d0
	sub.w	d6,d0			; ecart en x
	move.w	PosY,d1
	sub.w	d7,d1			; ecart en y
	move.w	d0,d2
	bpl.s	.absX
	neg.w	d2
.absX:
	move.w	d1,d3
	bpl.s	.absY
	neg.w	d3
.absY:
	move.w	d2,d4
	add.w	d3,d4
	cmp.w	#MONRANGE,d4
	bgt	.done			; trop loin : il n'a rien entendu

	moveq	#0,d4			; le pas horizontal, -1, 0 ou +1
	tst.w	d0
	beq.s	.noX
	moveq	#1,d4
	tst.w	d0
	bpl.s	.noX
	moveq	#-1,d4
.noX:
	moveq	#0,d5			; et le pas vertical
	tst.w	d1
	beq.s	.noY
	moveq	#1,d5
	tst.w	d1
	bpl.s	.noY
	moveq	#-1,d5
.noY:
	cmp.w	d3,d2			; quel axe mene le pas
	blt.s	.vertFirst
	move.w	d4,d0
	moveq	#0,d1
	bsr	MonTry
	tst.w	d0
	bne.s	.done
	moveq	#0,d0
	move.w	d5,d1
	bsr	MonTry
	bra.s	.done
.vertFirst:
	moveq	#0,d0
	move.w	d5,d1
	bsr	MonTry
	tst.w	d0
	bne.s	.done
	move.w	d4,d0
	moveq	#0,d1
	bsr	MonTry
.done:
	movem.l	(sp)+,d0-d5/a0
	rts

; MonTry : d0,d1 = pas a tenter, d6,d7 = case du monstre.
;          -> d0 = 1 si le monstre a bouge ou aborde le groupe.
MonTry:
	movem.l	d1-d5/a0,-(sp)
	move.w	d0,d2
	or.w	d1,d2
	beq	.no			; pas de pas du tout
	add.w	d6,d0
	move.w	d0,MonToX
	add.w	d7,d1
	move.w	d1,MonToY

	cmp.w	PosX,d0			; le groupe est la : il l'aborde
	bne.s	.notParty
	cmp.w	PosY,d1
	bne.s	.notParty
	move.w	d6,d0
	move.w	d7,d1
	bsr	MapGetParam
	cmp.w	#NMONSTERS,d0
	blt.s	.kindOk
	moveq	#0,d0
.kindOk:
	move.w	d0,MonKind
	move.w	d6,MonX			; c'est lui qui tient la case
	move.w	d7,MonY
	move.w	#1,MeetAmbush		; c'est lui qui vient : il peut
	bsr	StartCombat		; nous surprendre
	bra	.yes
.notParty:
	move.w	MonToX,d0		; du dallage nu, et rien dessus
	move.w	MonToY,d1
	bsr	MapCell
	tst.w	d0
	bne	.no
	move.w	MonToX,d0
	move.w	MonToY,d1
	bsr	MapGetParam
	tst.w	d0
	bne.s	.no

	move.w	d6,d0			; l'espece suit le monstre
	move.w	d7,d1
	bsr	MapGetParam
	move.w	d0,d5
	move.w	d6,d0			; la case quittee redevient nue
	move.w	d7,d1
	bsr	MapCell
	and.w	#$000f,d0
	move.w	d0,d2
	move.w	d6,d0
	move.w	d7,d1
	bsr	MapSet
	move.w	d6,d0
	move.w	d7,d1
	moveq	#0,d2
	bsr	MapSetParam

	move.w	MonToX,d0		; et la case atteinte le porte
	move.w	MonToY,d1
	bsr	MapCell
	or.w	#C_MONSTER,d0
	bset	#MON_MOVED,d0		; il a fait son pas pour ce tour
	move.w	d0,d2
	move.w	MonToX,d0
	move.w	MonToY,d1
	bsr	MapSet
	move.w	MonToX,d0
	move.w	MonToY,d1
	move.w	d5,d2
	bsr	MapSetParam
	move.w	#1,MonMoved
.yes:
	movem.l	(sp)+,d1-d5/a0
	moveq	#1,d0
	rts
.no:
	movem.l	(sp)+,d1-d5/a0
	moveq	#0,d0
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
	clr.w	StrikeTime
	clr.w	MonStun
	move.w	MonKind,d0
	mulu.w	#mt_SIZEOF,d0
	lea	MonTypes,a2
	add.l	d0,a2
	move.l	a2,MonPtr
	bsr	RollMonHp		; celui de devant
	move.w	d0,MonHp
	move.w	mt_Art(a2),MonArt

	; Le groupe : de un a quatre de la meme espece, d'autant moins que
	; l'espece est lourde, d'autant plus qu'on est bas. Chacun a ses
	; points de vie ; ceux de derriere attendent dans GroupHp.
	move.w	mt_Hd(a2),d0		; quatre au plus, un de moins tous
	subq.w	#1,d0			; les deux des de vie
	lsr.w	#1,d0
	moveq	#GROUPMAX,d1
	sub.w	d0,d1
	bgt.s	.maxOk
	moveq	#1,d1
.maxOk:
	move.w	Level,d0		; et pas plus que l'etage n'en autorise
	addq.w	#2,d0
	cmp.w	d0,d1
	ble.s	.capped
	move.w	d0,d1
.capped:
	bsr	RndMod
	addq.w	#1,d0
	move.w	d0,GroupN
	move.w	#1,GroupNext
	lea	GroupHp,a0
	move.w	MonHp,(a0)+
	moveq	#GROUPMAX-2,d2
.rollGroup:
	bsr	RollMonHp
	move.w	d0,(a0)+
	dbf	d2,.rollGroup
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
	cmp.w	#1,GroupN		; il n'est pas seul
	beq.s	.alone
	lea	TmpStr,a1
	lea	TxtNotAlone,a0
	bsr	StrCopy
	move.w	GroupN,d0
	bsr	StrNum
	move.b	#'.',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
.alone:
	bsr	FirstOrder		; le premier debout donne son ordre
	clr.w	RoundNo
	bsr	BeginMeet		; mais d'abord, la rencontre
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; RollMonHp : a2 = espece -> d0 = points de vie, tires aux des de vie
RollMonHp:
	movem.l	d1,-(sp)
	move.w	mt_Hd(a2),d0
	move.w	mt_HdF(a2),d1
	bsr	RollDice
	add.w	mt_HpB(a2),d0
	cmp.w	#1,d0
	bge.s	.ok
	moveq	#1,d0
.ok:
	movem.l	(sp)+,d1
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
	moveq	#SK_COMBAT,d0		; le metier des armes
	bsr	SkillTen
	add.w	d0,d6
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

;----------------------------------------------------------------------
; Le combat par rounds, a la maniere des jeux de role a groupe
;
; Un round commence par les ordres : chaque aventurier debout recoit le
; sien, a tour de role -- A frapper, D parer, S un sort --, et ENTREE
; reprend ceux du round d'avant pour tous ceux qui restent. Les ordres
; sont retenus d'un round et d'un combat a l'autre : le groupe se bat
; comme on l'a regle, et il suffit d'ENTREE pour enchainer.
;
; Puis le round se joue : les aventuriers dans l'ordre du groupe, puis
; chaque creature debout. Celui de l'arriere ne frappe qu'a l'arc -- sans
; quoi il pare ; celui de l'avant qui lance un sort peut perdre sa
; concentration, l'ennemi sous le nez. Le resultat s'affiche en detail,
; ou se resume au journal, selon le reglage (P).
;
; Orders : 0 frapper, 1 parer, 2 + n le sort n.
;----------------------------------------------------------------------
ORD_ATTACK	= 0
ORD_GUARD	= 1
ORD_SPELL	= 2

; resultats d'un aventurier dans le round, pour le panneau
RES_NONE	= 0			; a terre, ou rien a faire
RES_HIT		= 1			; ResVal : les degats
RES_MISS	= 2
RES_GUARD	= 3
RES_FAR		= 4			; trop loin pour frapper : il pare
RES_SPELL	= 5			; ResVal : ce que le sort a pris
RES_CONC	= 6			; concentration perdue
GUARDAC		= 4			; ce que parer ajoute a la CA

; FirstOrder : l'ordre revient au premier aventurier debout
FirstOrder:
	movem.l	d0/a6,-(sp)
	moveq	#-1,d0
	bsr	NextAlive
	move.w	d0,OrderHero
	bmi.s	.none
	move.w	d0,SelHero
.none:
	movem.l	(sp)+,d0/a6
	rts

; NextAlive : d0 = heros -> d0 = le suivant debout, -1 s'il n'y en a pas
NextAlive:
	movem.l	d1/a6,-(sp)
	move.w	d0,d1
.loop:
	addq.w	#1,d1
	cmp.w	#NHEROES,d1
	bge.s	.none
	move.w	d1,d0
	bsr	HeroPtr
	tst.w	hr_Hp(a6)
	beq.s	.loop
	move.w	d1,d0
	bra.s	.done
.none:
	moveq	#-1,d0
.done:
	movem.l	(sp)+,d1/a6
	rts

; SetOrder : d0 = ordre pour l'aventurier dont c'est le tour. On passe
; au suivant ; apres le dernier, le round se joue.
SetOrder:
	movem.l	d0-d1/a0,-(sp)
	move.w	OrderHero,d1
	bmi.s	.play
	lea	Orders,a0
	move.b	d0,(a0,d1.w)
	move.w	d1,d0
	bsr	NextAlive
	move.w	d0,OrderHero
	bmi.s	.play
	move.w	d0,SelHero
	move.w	#1,NeedRedraw
	bra.s	.done
.play:
	bsr	ResolveRound
.done:
	movem.l	(sp)+,d0-d1/a0
	rts

; ResolveRound : le round se joue, avec les ordres tels qu'ils sont.
ResolveRound:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#1,InResolve
	addq.w	#1,RoundNo
	lea	HitFlags,a0		; qui aura touche, qui pare
	lea	Guarding,a1
	lea	ResCode,a3
	moveq	#NHEROES-1,d0
.clear:
	clr.b	(a0)+
	clr.b	(a1)+
	clr.b	(a3)+
	dbf	d0,.clear
	clr.w	MonHits
	clr.w	MonDmg
	clr.w	RoundSfx		; l'arme du premier qui frappe
	moveq	#0,d7			; degats du groupe ce round
	moveq	#0,d6			; numero du heros
.heroLoop:
	tst.w	InCombat
	beq	.heroesDone
	move.w	d6,d0
	bsr	HeroPtr
	tst.w	hr_Hp(a6)
	beq	.heroNext
	lea	Orders,a0
	moveq	#0,d5
	move.b	(a0,d6.w),d5		; son ordre
	cmp.w	#ORD_GUARD,d5
	bne.s	.notGuard
.guard:
	lea	Guarding,a0
	st	(a0,d6.w)
	moveq	#RES_GUARD,d0
	bsr	SetRes
	bra	.heroNext
.notGuard:
	cmp.w	#ORD_SPELL,d5
	bhs	.spell

	cmp.w	#FRONTRANK,d6		; --- frapper
	blo.s	.canReach
	bsr	HasBow			; de l'arriere, a l'arc seulement
	tst.w	d0
	bne.s	.canReach
	lea	Guarding,a0		; trop loin : il pare
	st	(a0,d6.w)
	moveq	#RES_FAR,d0
	bsr	SetRes
	bra	.heroNext
.canReach:
	tst.w	RoundSfx		; le bruit de son arme, s'il est le
	bne.s	.sfxKnown		; premier a frapper
	moveq	#SFX_SWORD,d0
	move.w	hr_Weapon(a6),d1
	beq.s	.sfxSet
	move.w	d1,d0
	bsr	ItemPtr
	move.w	it_Sfx(a0),d0
.sfxSet:
	addq.w	#1,d0			; plus un : l'epee est le bruitage zero
	move.w	d0,RoundSfx
.sfxKnown:
	move.l	MonPtr,a2
	bsr	HeroAttack
	tst.w	d0
	bne.s	.hit
	moveq	#RES_MISS,d0
	bsr	SetRes
	bra	.heroNext
.hit:
	move.w	d0,d1
	add.w	d1,d7
	sub.w	d1,MonHp
	lea	HitFlags,a0
	st	(a0,d6.w)
	lea	ResVal,a0
	move.w	d6,d0
	add.w	d0,d0
	move.w	d1,(a0,d0.w)
	moveq	#RES_HIT,d0
	bsr	SetRes
	bra	.checkDead

.spell:					; --- un sort
	move.w	d6,SelHero
	cmp.w	#FRONTRANK,d6		; a l'avant, l'ennemi sous le nez
	bhs.s	.focused
	move.l	MonPtr,a2
	bsr	IsCaster
	tst.w	d0
	beq.s	.focused
	moveq	#SK_CONCENT,d0		; 40 % de perdre le fil, moins la
	bsr	SkillValue		; moitie de sa concentration
	lsr.w	#1,d0
	moveq	#40,d2
	sub.w	d0,d2
	ble.s	.focused
	moveq	#100,d1
	bsr	RndMod
	cmp.w	d2,d0
	bhs.s	.focused
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtLostFocus,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	moveq	#RES_CONC,d0
	bsr	SetRes
	bra.s	.heroNext
.focused:
	move.w	MonHp,d4
	move.w	d5,d0
	sub.w	#ORD_SPELL,d0
	bsr	CastSpell
	sub.w	MonHp,d4		; ce que le sort a pris
	bpl.s	.took
	moveq	#0,d4
.took:
	add.w	d4,d7
	lea	ResVal,a0
	move.w	d6,d0
	add.w	d0,d0
	move.w	d4,(a0,d0.w)
	moveq	#RES_SPELL,d0
	bsr	SetRes
.checkDead:
	tst.w	MonHp
	bgt.s	.heroNext
	bsr	MonsterDies		; la suivante s'avance, ou c'est fini
.heroNext:
	addq.w	#1,d6
	cmp.w	#NHEROES,d6
	blt	.heroLoop
.heroesDone:
	move.w	d7,RoundDmg
	move.w	RoundSfx,d0		; l'arme, puis l'impact ou l'esquive
	beq.s	.silent
	subq.w	#1,d0
	bsr	SfxPlay
	moveq	#SFX_MISS,d0
	tst.w	d7
	beq.s	.impact
	moveq	#SFX_HIT,d0
.impact:
	bsr	SfxPlay
.silent:
	tst.w	d7			; le recit du groupe, en une ligne
	beq.s	.noDamage
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
.noDamage:
	bsr	CombatProgress		; ceux qui ont touche y gagnent peut-etre
	tst.w	InCombat
	beq.s	.over
	tst.w	GameOver
	bne.s	.over
	bsr	MonsterTurn		; puis chaque creature debout
.over:
	clr.w	InResolve
	tst.w	InCombat
	beq.s	.done
	tst.w	GameOver
	bne.s	.done
	bsr	FirstOrder		; le round suivant commence par l'ordre
	tst.w	OptQuick		; du premier -- apres le resultat, si on
	bne.s	.done			; le veut en detail
	move.w	#UI_ROUND,UiMode
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; SetRes : d0 = resultat de l'aventurier d6
SetRes:
	move.l	a0,-(sp)
	lea	ResCode,a0
	move.b	d0,(a0,d6.w)
	move.l	(sp)+,a0
	rts

; HasBow : a6 = heros -> d0 = 1 s'il tient une arme de jet
HasBow:
	movem.l	a0,-(sp)
	move.w	hr_Weapon(a6),d0
	beq.s	.no
	bsr	ItemPtr
	cmp.w	#SFX_BOW,it_Sfx(a0)
	bne.s	.no
	moveq	#1,d0
	bra.s	.done
.no:
	moveq	#0,d0
.done:
	movem.l	(sp)+,a0
	rts

; IsCaster : a6 = heros -> d0 = 1 si sa classe lance des sorts
IsCaster:
	movem.l	a0,-(sp)
	bsr	ClassPtr
	move.w	cl_Cast(a0),d0
	beq.s	.done
	moveq	#1,d0
.done:
	movem.l	(sp)+,a0
	rts

; HeroIndex : a6 = heros -> d0 = son rang dans le groupe
HeroIndex:
	move.l	a6,d0
	sub.l	#Heroes,d0
	divu.w	#hr_SIZEOF,d0
	and.l	#$0000ffff,d0
	rts

; CombatKey : d0 = touche, pendant les ordres
CombatKey:
	cmp.w	#KEY_A_QW,d0
	beq.s	.attack
	cmp.w	#KEY_A_AZ,d0
	beq.s	.attack
	cmp.w	#KEY_SPACE,d0
	beq.s	.attack
	cmp.w	#KEY_D,d0
	beq.s	.guard
	cmp.w	#KEY_RETURN,d0
	beq.s	.repeat
	cmp.w	#KEY_F,d0
	beq.s	.flee
	cmp.w	#KEY_S,d0
	bne.s	.done
	movem.l	d0/a0-a1/a6,-(sp)	; qui ne connait aucun sort n'a pas
	move.w	OrderHero,d0		; de menu a ouvrir
	bmi.s	.noSpell
	bsr	HeroPtr
	tst.w	hr_Spells(a6)
	bne.s	.menu
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtNoSpells,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	move.w	#1,NeedRedraw
	bra.s	.noSpell
.menu:
	move.w	#UI_SPELL,UiMode	; le sort se choisit dans le menu,
	move.w	#1,NeedRedraw		; qui revient ici avec son numero
.noSpell:
	movem.l	(sp)+,d0/a0-a1/a6
	rts
.attack:
	moveq	#ORD_ATTACK,d0
	bra	SetOrder
.guard:
	moveq	#ORD_GUARD,d0
	bra	SetOrder
.repeat:
	bra	ResolveRound		; les ordres retenus, pour tous
.flee:
	bsr	CombatFlee
	tst.w	InCombat
	beq.s	.done
	bsr	FirstOrder
.done:
	rts

; DrawRound : le resultat du round, en detail (UI_ROUND)
DrawRound:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#16,d0
	moveq	#16,d1
	move.w	#192,d2
	move.w	#136,d3
	move.w	#C_BLACK,d4
	bsr	FillRect
	lea	TmpStr,a1
	lea	TxtRoundTitle,a0
	bsr	StrCopy
	move.w	RoundNo,d0
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText

	moveq	#0,d6
.row:
	move.w	d6,d0
	bsr	HeroPtr
	tst.w	hr_HpMax(a6)
	beq	.next
	move.l	a6,a0			; le nom
	moveq	#3,d0
	move.w	d6,d1
	mulu.w	#11,d1
	add.w	#36,d1
	move.w	#C_TEXT,d2
	tst.w	hr_Hp(a6)
	bne.s	.up
	move.w	#C_TEXTLOW,d2
.up:
	bsr	DrawText
	lea	ResCode,a0		; ce qu'il a fait
	moveq	#0,d0
	move.b	(a0,d6.w),d0
	move.w	d0,d5
	lsl.w	#2,d0
	lea	ResTexts,a0
	move.l	(a0,d0.w),a0
	lea	TmpStr,a1
	bsr	StrCopy
	cmp.w	#RES_HIT,d5		; avec des degats a dire
	beq.s	.value
	cmp.w	#RES_SPELL,d5
	bne.s	.noValue
	lea	ResVal,a0
	move.w	d6,d0
	add.w	d0,d0
	tst.w	(a0,d0.w)
	beq.s	.noValue
.value:
	move.b	#' ',(a1)+
	lea	ResVal,a0
	move.w	d6,d0
	add.w	d0,d0
	move.w	(a0,d0.w),d0
	bsr	StrNum
.noValue:
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#13,d0
	move.w	d6,d1
	mulu.w	#11,d1
	add.w	#36,d1
	move.w	#C_PARCHD,d2
	cmp.w	#RES_HIT,d5
	bne.s	.color
	move.w	#C_HEALTH,d2
.color:
	bsr	DrawText
.next:
	addq.w	#1,d6
	cmp.w	#NHEROES,d6
	blt	.row

	lea	TmpStr,a1		; et ce que les creatures ont fait
	lea	TxtRoundFoes,a0
	bsr	StrCopy
	move.w	MonHits,d0
	bsr	StrNum
	lea	TxtRoundBlows,a0
	bsr	StrCopy
	move.w	MonDmg,d0
	bsr	StrNum
	lea	TxtRoundHp,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#110,d1
	move.w	#C_ALERT,d2
	bsr	DrawText
	lea	TxtRoundGo,a0
	moveq	#3,d0
	move.w	#134,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; DrawOrderTag : pendant les ordres, sur la creature -- a qui c'est le
; tour et ce qu'il a fait au round d'avant ; en bas, combien ils sont.
DrawOrderTag:
	movem.l	d0-d7/a0-a6,-(sp)
	tst.w	MeetPhase		; la rencontre : la question, pas l'ordre
	beq.s	.orders
	lea	TxtMeetAsk,a0
	cmp.w	#MEET_TOLL,MeetPhase
	bne.s	.ask
	lea	TxtTollTag,a0
.ask:
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	bra	.foes
.orders:
	move.w	OrderHero,d0
	bmi	.foes
	bsr	HeroPtr
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtOrderSep,a0
	bsr	StrCopy
	lea	Orders,a0
	move.w	OrderHero,d0
	moveq	#0,d1
	move.b	(a0,d0.w),d1
	moveq	#ORD_SPELL,d2		; un sort : "SORT", et son nom dessous
	cmp.w	d2,d1
	bhs.s	.spellTag
	lsl.w	#2,d1
	lea	OrderNames,a0
	move.l	(a0,d1.w),a0
	bra.s	.named
.spellTag:
	lea	TxtResSpell,a0
.named:
	bsr	StrCopy
	move.b	#' ',(a1)+
	move.b	#'?',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	lea	Orders,a0
	move.w	OrderHero,d0
	moveq	#0,d1
	move.b	(a0,d0.w),d1
	cmp.w	#ORD_SPELL,d1
	blo.s	.foes
	sub.w	#ORD_SPELL,d1
	move.w	d1,d0
	bsr	SpellPtr
	moveq	#3,d0
	moveq	#40,d1
	move.w	#C_PARCHD,d2
	bsr	DrawText
.foes:
	lea	TmpStr,a1
	move.l	MonPtr,a0
	bsr	StrCopy
	cmp.w	#1,GroupN
	beq.s	.one
	lea	TxtTimes,a0
	bsr	StrCopy
	move.w	GroupN,d0
	bsr	StrNum
.one:
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0			; sous l'ordre, contre la voute
	moveq	#30,d1
	move.w	#C_TEXT,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

MonsterTurn:
	tst.w	MonStun
	beq.s	.attack
	clr.w	MonStun
	lea	TxtMonStunned,a0
	bsr	LogAdd
	rts
.attack:				; chacun du groupe frappe
	move.l	d7,-(sp)
	move.w	GroupN,d7
	subq.w	#1,d7
.each:
	tst.w	GameOver
	bne.s	.over
	bsr	MonsterAttack
	dbf	d7,.each
.over:
	move.l	(sp)+,d7
	rts

;----------------------------------------------------------------------
; Les competences, qui progressent a l'usage
;
; Comme dans Legend of Faerghail, un aventurier ne progresse pas qu'en
; niveaux : chaque fois qu'il reussit ce qu'une competence mesure --
; toucher, parer, lancer un sort, reperer ou desamorcer un piege,
; marchander --, il a une chance d'y gagner un point. Une chance
; d'autant plus mince que la competence est deja haute : (100 - valeur)
; sur trois cents. De 0 a 99, un octet par competence dans le heros.
;----------------------------------------------------------------------

; SkillValue : a6 = heros, d0 = competence -> d0 = valeur (0 a 99)
SkillValue:
	move.l	d1,-(sp)
	moveq	#0,d1
	move.b	hr_Skills(a6,d0.w),d1
	move.l	d1,d0
	move.l	(sp)+,d1
	rts

; SkillTen : -> d0 = valeur / 10, ce que la competence ajoute a un d20
; de combat (0 a +9)
SkillTen:
	bsr.s	SkillValue
	divu.w	#10,d0
	and.l	#$0000ffff,d0
	rts

; SkillFifth : -> d0 = valeur / 5, pour les pieges (0 a +19) : le
; metier y compte plus que l'epee au combat
SkillFifth:
	bsr.s	SkillValue
	divu.w	#5,d0
	and.l	#$0000ffff,d0
	rts

; SkillUse : a6 = heros, d0 = competence. Il vient de la reussir : il a
; une chance d'y gagner un point, et le journal le dit.
SkillUse:
	movem.l	d0-d3/a0-a1,-(sp)
	move.w	d0,d3
	bsr.s	SkillValue
	cmp.w	#99,d0
	bhs.s	.done
	move.w	d0,d2
	move.w	#300,d1
	bsr	RndMod
	moveq	#100,d1
	sub.w	d2,d1
	cmp.w	d1,d0
	bhs.s	.done
	addq.b	#1,hr_Skills(a6,d3.w)
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtProgress,a0
	bsr	StrCopy
	move.w	d3,d0
	lsl.w	#2,d0
	lea	SkillNames,a0
	move.l	(a0,d0.w),a0
	bsr	StrCopy
	move.b	#'.',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
.done:
	movem.l	(sp)+,d0-d3/a0-a1
	rts

; BestTrader : -> a6 = l'aventurier debout qui marchande le mieux, d0 =
; sa valeur. Au comptoir, c'est lui qui parle pour tout le groupe.
BestTrader:
	movem.l	d1-d3/a0,-(sp)
	lea	Heroes,a0
	move.l	a0,a6
	moveq	#-1,d2
	moveq	#NHEROES-1,d3
.loop:
	tst.w	hr_Hp(a0)
	beq.s	.next
	moveq	#0,d1
	move.b	hr_Skills+SK_TRADE(a0),d1
	cmp.w	d2,d1
	ble.s	.next
	move.w	d1,d2
	move.l	a0,a6
.next:
	lea	hr_SIZEOF(a0),a0
	dbf	d3,.loop
	moveq	#0,d0
	tst.w	d2
	bmi.s	.done
	move.w	d2,d0
.done:
	movem.l	(sp)+,d1-d3/a0
	rts

; CombatProgress : ceux qui ont touche pendant le round (HitFlags)
; tentent leur chance en COMBAT -- apres le recit du round, pour que le
; journal se lise dans l'ordre.
CombatProgress:
	movem.l	d0-d1/a0/a6,-(sp)
	lea	HitFlags,a0
	moveq	#0,d1
.loop:
	tst.b	(a0,d1.w)
	beq.s	.next
	move.w	d1,d0
	bsr	HeroPtr
	moveq	#SK_COMBAT,d0
	bsr	SkillUse
.next:
	addq.w	#1,d1
	cmp.w	#NHEROES,d1
	blt.s	.loop
	movem.l	(sp)+,d0-d1/a0/a6
	rts

; DrawSkills : la deuxieme page de la fiche, TAB depuis la premiere.
DrawSkills:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	TmpStr,a1
	lea	TxtSkillsOf,a0
	bsr	StrCopy
	move.l	a6,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	moveq	#20,d1
	move.w	#C_HILITE,d2
	bsr	DrawText
	moveq	#0,d7
.loop:
	move.w	d7,d0
	lsl.w	#2,d0
	lea	SkillNames,a0
	move.l	(a0,d0.w),a0
	moveq	#3,d0
	move.w	d7,d1
	mulu.w	#13,d1
	add.w	#40,d1
	move.w	#C_TEXT,d2
	bsr	DrawText
	lea	TmpStr,a1		; la valeur, calee a droite
	move.w	d7,d0
	bsr	SkillValue
	move.w	d0,d6
	bsr	StrNum
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#22,d0
	cmp.w	#10,d6
	bhs.s	.two
	moveq	#23,d0
.two:
	move.w	d7,d1
	mulu.w	#13,d1
	add.w	#40,d1
	move.w	#C_PARCHD,d2
	bsr	DrawText
	move.w	#24,d0			; et sa jauge, sous le nom
	move.w	d7,d1
	mulu.w	#13,d1
	add.w	#49,d1
	move.w	#176,d2
	move.w	d6,d3
	moveq	#99,d4
	move.w	#C_GOLD+N_GOLD-3,d5
	bsr	DrawGauge
	addq.w	#1,d7
	cmp.w	#NSKILLS,d7
	blt	.loop
	bsr	DrawTongues		; et les langues qu'il parle
	lea	TxtSkillsHelp,a0
	moveq	#3,d0
	move.w	#138,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; Les rencontres : avant le fer, la parole
;
; Comme dans Legend of Faerghail, une rencontre ne commence pas
; forcement par un combat. Le groupe voit ce qui vient, et choisit :
; S saluer, D discuter -- si quelqu'un parle la langue de ceux d'en
; face --, F se retirer, A attaquer. Chaque espece a sa langue et son
; temperament (MonTypes) : les morts et les betes ne repondent qu'au fer,
; les mefiants se laissent parler, et un jet de reaction -- charisme,
; marchandage, et ce qu'on a dit -- decide s'ils passent leur chemin,
; demandent un peage, ou degainent.
;
; Quand c'est la creature qui vient a nous, elle peut nous surprendre :
; elle frappe alors la premiere, et il n'y a plus rien a dire. La
; vigilance du groupe l'evite, et progresse quand elle y parvient.
;
; MeetPhase : 0 le combat, 1 la rencontre, 2 le peage en question.
;----------------------------------------------------------------------
MEET_CHOICE	= 1
MEET_TOLL	= 2
; Les seuils du jet de reaction. Un orc mefiant, a qui le negociateur
; du groupe parle sa langue, laisse passer deux fois sur trois, demande
; un peage le plus souvent le reste du temps, et degaine rarement --
; mesure par le banc sur quarante rencontres. Salue sans un mot de sa
; langue, il a quatre points de moins, et les seuils sont les memes.
GREET_PASS	= 20
GREET_STARE	= 12
TALK_PASS	= 20
TALK_TOLL	= 12

; BeginMeet : appele a la fin de StartCombat
BeginMeet:
	movem.l	d0-d3/a0-a2/a6,-(sp)
	clr.w	MeetGreeted
	move.w	#MEET_CHOICE,MeetPhase
	tst.w	MeetAmbush		; c'est lui qui vient : surprise ?
	beq.s	.done
	bsr	BestVigil		; a6 = le plus vigilant, d0 = sa valeur
	divu.w	#5,d0
	and.l	#$0000ffff,d0
	moveq	#30,d2			; trente pour cent, moins sa vigilance
	sub.w	d0,d2
	cmp.w	#5,d2
	bge.s	.chance
	moveq	#5,d2
.chance:
	moveq	#100,d1
	bsr	RndMod
	cmp.w	d2,d0
	bhs.s	.seen
	clr.w	MeetPhase		; surpris : pas un mot, ils frappent
	lea	TxtSurprised,a0
	bsr	LogAdd
	bsr	MonsterTurn
	bra.s	.done
.seen:
	lea	TxtSeenComing,a0	; on les a vus venir
	bsr	LogAdd
	moveq	#SK_VIGIL,d0
	bsr	SkillUse
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d3/a0-a2/a6
	rts

; MeetKey : d0 = touche, pendant la rencontre
MeetKey:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	MonPtr,a2
	cmp.w	#MEET_TOLL,MeetPhase
	bne.s	.choice
	cmp.w	#KEY_O,d0		; --- le peage : O payer, N refuser
	beq.s	.pay
	cmp.w	#KEY_N,d0
	bne	.done
	lea	TxtTollRefused,a0
	bsr	LogAdd
	bra	.fight
.pay:
	move.w	MeetToll,d1
	cmp.w	Gold,d1
	bls.s	.canPay
	lea	TxtTollPoor,a0
	bsr	LogAdd
	bra	.fight
.canPay:
	sub.w	d1,Gold
	moveq	#SFX_COIN,d0
	bsr	SfxPlay
	lea	TmpStr,a1
	lea	TxtTollPaid,a0
	bsr	StrCopy
	move.w	d1,d0
	bsr	StrNum
	lea	TxtTollPaid2,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra	.peace

.choice:
	cmp.w	#KEY_A_QW,d0		; --- A : attaquer
	beq.s	.attack
	cmp.w	#KEY_A_AZ,d0
	beq.s	.attack
	cmp.w	#KEY_F,d0		; --- F : se retirer
	bne.s	.notFlee
	clr.w	MeetPhase		; manquee, la retraite tourne au combat
	bsr	CombatFlee
	tst.w	InCombat
	beq	.done
	bsr	FirstOrder
	bra	.done
.notFlee:
	cmp.w	#KEY_S,d0
	beq.s	.greet
	cmp.w	#KEY_D,d0
	beq	.talk
	bra	.done
.attack:
	lea	TxtToArms,a0
	bsr	LogAdd
	bra	.fight

.greet:					; --- S : saluer
	tst.w	mt_Temper(a2)
	beq	.deaf
	tst.w	MeetGreeted		; on ne salue pas deux fois
	bne	.impatient
	move.w	#1,MeetGreeted
	moveq	#0,d3
	bsr	React
	cmp.w	#GREET_PASS,d0
	bge.s	.greetBack
	cmp.w	#GREET_STARE,d0
	bge.s	.stare
	lea	TxtMenacing,a0
	bsr	LogAdd
	bra	.fight
.greetBack:
	lea	TxtGreetBack,a0
	bsr	LogAdd
	bra	.peace
.stare:
	lea	TxtStare,a0
	bsr	LogAdd
	bra	.done
.impatient:
	lea	TxtImpatient,a0
	bsr	LogAdd
	bra	.fight

.talk:					; --- D : discuter
	move.w	mt_Tongue(a2),d2
	bne.s	.speaks
	lea	TxtNoTongue,a0		; ils ne parlent pas : rien de fait
	bsr	LogAdd
	bra	.done
.speaks:
	bsr	PartyTongues
	btst	d2,d0
	bne.s	.understood
	lea	TmpStr,a1		; personne ne parle leur langue
	lea	TxtNobodySpeaks,a0
	bsr	StrCopy
	move.w	d2,d0
	lsl.w	#2,d0
	lea	TongueNames,a0
	move.l	(a0,d0.w),a0
	bsr	StrCopy
	move.b	#'.',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra	.done
.understood:
	bsr	BestTrader		; a6 = celui qui parle
	lea	TmpStr,a1
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtParleys,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	tst.w	mt_Temper(a2)
	beq	.deaf
	moveq	#4,d3			; parler leur langue, ca compte
	bsr	React
	cmp.w	#TALK_PASS,d0
	bge.s	.letPass
	cmp.w	#TALK_TOLL,d0
	bge.s	.toll
	lea	TxtTalkFails,a0
	bsr	LogAdd
	bra	.fight
.letPass:
	moveq	#SK_TRADE,d0
	bsr	SkillUse
	lea	TxtLetPass,a0
	bsr	LogAdd
	bra	.peace
.toll:
	move.w	mt_Gold(a2),d0		; ce qu'ils portent, fois leur nombre,
	mulu.w	GroupN,d0		; et un peu plus a mesure qu'on descend
	move.w	Level,d1
	addq.w	#1,d1
	mulu.w	#5,d1
	add.w	d1,d0
	move.w	d0,MeetToll
	move.w	#MEET_TOLL,MeetPhase
	lea	TmpStr,a1
	lea	TxtTollAsk,a0
	bsr	StrCopy
	move.w	MeetToll,d0
	bsr	StrNum
	lea	TxtTollAsk2,a0
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra.s	.done

.deaf:
	lea	TxtDeaf,a0		; ils ne repondent qu'au fer
	bsr	LogAdd
.fight:
	clr.w	MeetPhase		; au combat : les ordres
	bsr	FirstOrder
	bra.s	.done
.peace:
	bsr	MeetPeace		; ils passent leur chemin
.done:
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; React : le jet de reaction. d3 = bonus de ce qu'on a dit -> d0.
; d20, plus trois fois le temperament, plus le charisme du meilleur
; negociateur et le dixieme de son marchandage.
React:
	movem.l	d1/a2/a6,-(sp)
	move.l	MonPtr,a2
	bsr	D20
	move.w	d0,d1
	move.w	mt_Temper(a2),d0
	mulu.w	#3,d0
	add.w	d0,d1
	add.w	d3,d1
	bsr	BestTrader
	moveq	#SK_TRADE,d0
	bsr	SkillTen
	add.w	d0,d1
	move.w	hr_Cha(a6),d0
	bsr	StatMod
	add.w	d1,d0
	movem.l	(sp)+,d1/a2/a6
	rts

; MeetPeace : ils passent leur chemin. Leur case se vide, sans or ni
; experience -- on n'a rien gagne qu'un peu de temps.
MeetPeace:
	movem.l	d0-d2,-(sp)
	clr.w	MeetPhase
	clr.w	InCombat
	move.w	MonX,d0
	move.w	MonY,d1
	bsr	MapCell
	move.w	d0,d2
	and.w	#$000f,d2
	move.w	MonX,d0
	move.w	MonY,d1
	bsr	MapSet
	movem.l	(sp)+,d0-d2
	rts

; PartyTongues : -> d0 = les langues que parle le groupe debout
PartyTongues:
	movem.l	d1-d2/a0/a6,-(sp)
	moveq	#0,d0
	lea	Heroes,a6
	moveq	#NHEROES-1,d2
.loop:
	tst.w	hr_Hp(a6)
	beq.s	.next
	bsr	HeroTongues
	or.w	d1,d0
.next:
	lea	hr_SIZEOF(a6),a6
	dbf	d2,.loop
	movem.l	(sp)+,d1-d2/a0/a6
	rts

; HeroTongues : a6 = heros -> d1 = ses langues, par sa race et sa classe
HeroTongues:
	movem.l	d0/a0,-(sp)
	move.w	hr_Race(a6),d0
	add.w	d0,d0
	lea	RaceTongues,a0
	move.w	(a0,d0.w),d1
	move.w	hr_Class(a6),d0
	add.w	d0,d0
	lea	ClassTongues,a0
	or.w	(a0,d0.w),d1
	movem.l	(sp)+,d0/a0
	rts

; BestVigil : -> a6 = l'aventurier debout le plus vigilant, d0 = sa valeur
BestVigil:
	movem.l	d1-d3/a0,-(sp)
	lea	Heroes,a0
	move.l	a0,a6
	moveq	#-1,d2
	moveq	#NHEROES-1,d3
.loop:
	tst.w	hr_Hp(a0)
	beq.s	.next
	moveq	#0,d1
	move.b	hr_Skills+SK_VIGIL(a0),d1
	cmp.w	d2,d1
	ble.s	.next
	move.w	d1,d2
	move.l	a0,a6
.next:
	lea	hr_SIZEOF(a0),a0
	dbf	d3,.loop
	moveq	#0,d0
	tst.w	d2
	bmi.s	.done
	move.w	d2,d0
.done:
	movem.l	(sp)+,d1-d3/a0
	rts

; DrawTongues : a6 = heros. Ses langues, sur la page des competences.
DrawTongues:
	movem.l	d0-d7/a0-a1,-(sp)
	lea	TxtTonguesLbl,a0
	moveq	#3,d0
	moveq	#118,d1
	move.w	#C_TEXTDIM,d2
	bsr	DrawText
	bsr	HeroTongues
	move.w	d1,d6
	lea	TmpStr,a1
	moveq	#1,d7			; la langue zero, c'est "ne parle pas"
.loop:
	btst	d7,d6
	beq.s	.next
	cmp.l	#TmpStr,a1
	beq.s	.first
	move.b	#' ',(a1)+
.first:
	move.w	d7,d0
	lsl.w	#2,d0
	lea	TongueNames,a0
	move.l	(a0,d0.w),a0
	bsr	StrCopy
.next:
	addq.w	#1,d7
	cmp.w	#NTONGUES,d7
	blt.s	.loop
	clr.b	(a1)
	lea	TmpStr,a0
	moveq	#3,d0
	move.w	#127,d1
	move.w	#C_PARCHD,d2
	bsr	DrawText
	movem.l	(sp)+,d0-d7/a0-a1
	rts

;----------------------------------------------------------------------
; DrawCorridorMon : les monstres marchent, et on les voit venir.
;
; Ils ne se montraient qu'une fois le combat engage : un couloir ou
; quelque chose avancait vers le groupe avait l'air vide jusqu'au
; dernier pas. On regarde les trois cases devant, jusqu'au premier mur
; (d7, 0 s'il n'y en a pas), et l'on pose ce qui s'y tient, du plus loin
; au plus pres : a un pas, la creature du combat ; au-dela, la meme
; reduite vers le point de fuite.
;----------------------------------------------------------------------
DrawCorridorMon:
	movem.l	d0-d7/a0-a6,-(sp)
	moveq	#3,d6
.loop:
	tst.w	d7
	beq.s	.inSight
	cmp.w	d7,d6			; derriere le mur : rien a voir
	bge.s	.next
.inSight:
	move.w	d6,d2
	bsr	CellAhead
	move.w	d0,d4
	move.w	d1,d5
	bsr	MapCell
	and.w	#C_MASK,d0
	cmp.w	#C_MONSTER,d0
	bne.s	.next
	move.w	d4,d0
	move.w	d5,d1
	bsr	MapGetParam		; l'espece, dans MonTypes
	mulu.w	#mt_SIZEOF,d0
	lea	MonTypes,a0
	move.w	mt_Art(a0,d0.l),d0
	cmp.w	#1,d6
	bne.s	.far
	mulu.w	#NMONPOSES,d0		; a un pas : la pose de repos
	add.w	#ART_MONSTER,d0
	bra.s	.blit
.far:
	add.w	d0,d0			; deux vues lointaines par famille
	add.w	d6,d0
	add.w	#ART_MONFAR-2,d0
.blit:
	moveq	#0,d1
	bsr	BlitPiece
.next:
	subq.w	#1,d6
	bne.s	.loop
	movem.l	(sp)+,d0-d7/a0-a6
	rts

STRIKEFRAMES	= 18			; la pose d'attaque, en trames

MonsterAttack:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	MonPtr,a2
	bsr	PickTarget		; l'avant d'abord, trois fois sur quatre
	move.w	d0,d5
	moveq	#NHEROES-1,d6
.find:
	move.w	d5,d0
	bsr	HeroPtr
	tst.w	hr_Hp(a6)
	bne.s	.found
	addq.w	#1,d5		; le suivant, en bouclant sur les six
	cmp.w	#NHEROES,d5
	blo.s	.wrapOk
	moveq	#0,d5
.wrapOk:
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
	moveq	#SK_DEFENSE,d0		; il a pare : il y gagne peut-etre
	bsr	SkillUse
	bra	.done
.hit:
	move.w	#STRIKEFRAMES,StrikeTime	; le monstre frappe : sa pose
	move.w	mt_Dice(a2),d0
	move.w	mt_Faces(a2),d1
	bsr	RollDice
	add.w	mt_Dmg(a2),d0		; force de la creature
	cmp.w	#1,d0			; au moins un point
	bge.s	.dmgOk
	moveq	#1,d0
.dmgOk:
	move.w	d0,d4
	addq.w	#1,MonHits		; pour le resultat du round
	add.w	d0,MonDmg
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

	lea	Heroes,a6		; chaque creature tombee paie son du
	moveq	#NHEROES-1,d6
.xpEach:
	tst.w	hr_Hp(a6)
	beq.s	.xpEachNext
	move.w	mt_Xp(a2),d0
	add.w	d0,hr_Xp(a6)
	bsr	CheckLevel
.xpEachNext:
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.xpEach

	subq.w	#1,GroupN		; la suivante s'avance
	beq.s	.last
	move.w	GroupNext,d0
	add.w	d0,d0
	lea	GroupHp,a0
	move.w	(a0,d0.w),MonHp
	addq.w	#1,GroupNext
	clr.w	MonStun
	lea	TmpStr,a1
	lea	TxtNextOne,a0
	bsr	StrCopy
	move.w	GroupN,d0
	bsr	StrNum
	move.b	#'.',(a1)+
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	bra	.stillFighting
.last:
	clr.w	InCombat

	move.w	MonX,d0			; sa case est nettoyee -- la sienne, et
	move.w	MonY,d1			; pas celle du groupe : depuis que les
	bsr	MapCell			; monstres marchent, c'est parfois lui
	move.w	d0,d2			; qui est venu, et le groupe n'a pas
	and.w	#$000f,d2		; bouge
	move.w	MonX,d0
	move.w	MonY,d1
	bsr	MapSet

	lea	Heroes,a6		; les effets du combat retombent
	moveq	#NHEROES-1,d6
.acLoop:
	clr.w	hr_AcTemp(a6)
	lea	hr_SIZEOF(a6),a6
	dbf	d6,.acLoop
.stillFighting:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; SwapRank : le heros choisi passe de l'avant a l'arriere, ou l'inverse,
; en changeant de place avec celui qui se tient au meme rang de l'autre
; ligne (le premier avec le quatrieme, et ainsi de suite). Il emporte
; tout, jusqu'a ses ordres de combat.
;----------------------------------------------------------------------
SwapRank:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	SelHero,d4
	move.w	d4,d5
	add.w	#FRONTRANK,d5
	cmp.w	#NHEROES,d5
	blt.s	.mirror
	sub.w	#NHEROES,d5
.mirror:
	move.w	d4,d0
	bsr	HeroPtr
	move.l	a6,a0
	move.w	d5,d0
	bsr	HeroPtr
	move.l	a6,a1
	moveq	#hr_SIZEOF-1,d2
.swap:
	move.b	(a0),d3
	move.b	(a1),(a0)+
	move.b	d3,(a1)+
	dbf	d2,.swap
	lea	Orders,a0		; ses ordres le suivent
	move.b	(a0,d4.w),d3
	move.b	(a0,d5.w),(a0,d4.w)
	move.b	d3,(a0,d5.w)
	move.w	d5,SelHero

	lea	TmpStr,a1		; le dire
	move.l	a6,a0
	bsr	StrCopy
	lea	TxtToBack,a0
	cmp.w	#FRONTRANK,d5
	bge.s	.said
	lea	TxtToFront,a0
.said:
	bsr	StrCopy
	clr.b	(a1)
	lea	TmpStr,a0
	bsr	LogAdd
	move.w	#1,NeedRedraw
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;----------------------------------------------------------------------
; PickTarget : qui la creature vise. -> d0 = numero de heros.
;
; Le groupe se tient sur deux rangs : les trois premiers devant, les
; trois autres derriere. Trois coups sur quatre vont a l'avant, tant
; qu'il y reste quelqu'un debout ; les autres cherchent derriere.
; MonsterAttack passe au suivant si le vise est a terre.
;----------------------------------------------------------------------
PickTarget:
	movem.l	d1-d3/a6,-(sp)
	moveq	#0,d3			; quelqu'un debout devant ?
	moveq	#0,d2
.front:
	move.w	d2,d0
	bsr	HeroPtr
	tst.w	hr_Hp(a6)
	beq.s	.frontNext
	moveq	#1,d3
.frontNext:
	addq.w	#1,d2
	cmp.w	#FRONTRANK,d2
	blt.s	.front
	moveq	#FRONTRANK,d2		; la base : l'avant ou l'arriere
	tst.w	d3
	beq.s	.pick			; personne devant : l'arriere
	moveq	#4,d1
	bsr	RndMod
	tst.w	d0
	beq.s	.pick			; un coup sur quatre : derriere
	moveq	#0,d2
.pick:
	moveq	#FRONTRANK,d1
	bsr	RndMod
	add.w	d2,d0
	movem.l	(sp)+,d1-d3/a6
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
	move.w	SelHero,d0		; le lanceur, qui a reussi sa formule
	bsr	HeroPtr
	moveq	#SK_CONCENT,d0
	bsr	SkillUse
	tst.w	InResolve		; dans un round : c'est le round qui
	bne.s	.done			; fait riposter, et tomber
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
	move.w	d0,d1
	moveq	#SK_CONCENT,d0		; la formule, dite sans trembler
	bsr	SkillTen
	add.w	d1,d0
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

	cmp.w	#UI_ROUND,UiMode	; --- le resultat du round : une
	bne.s	.notRoundUi		; touche, et l'on repasse aux ordres
	clr.w	UiMode
	bra	.redraw
.notRoundUi:
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
	cmp.w	#UI_LEDGER,d1		; --- le grand registre
	bne.s	.notLedgerUi
	bsr	LedgerKey
	bra	.done
.notLedgerUi:
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
	tst.w	InCombat		; en combat, c'est un ordre : il se
	beq.s	.castNow		; jouera avec le round
	clr.w	UiMode
	add.w	#ORD_SPELL,d0
	bsr	SetOrder
	bra	.redraw
.castNow:
	bsr	CastSpell
	bra	.done
.notSpellUi:
	move.w	d0,d2			; 1 a 6 : heros courant
	sub.w	#KEY_1,d2
	bmi.s	.notHero
	cmp.w	#NHEROES,d2
	bge.s	.notHero
	move.w	d2,SelHero
	tst.w	InCombat		; en combat : c'est a lui de recevoir
	beq	.redraw			; son ordre, s'il est debout
	move.w	d2,d0
	bsr	HeroPtr
	tst.w	hr_Hp(a6)
	beq	.redraw
	move.w	d2,OrderHero
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
	clr.w	SheetPage		; on ouvre toujours sur le heros
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
	cmp.w	#KEY_TAB,d0		; la fiche : TAB passe du heros a ses
	bne.s	.notSheetTab		; competences, et retour
	cmp.w	#UI_SHEET,UiMode
	bne.s	.notSheetTab
	eor.w	#1,SheetPage
	bra	.redraw
.notSheetTab:
	move.w	UiMode,d1		; ces ecrans ont leurs propres fleches
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
	cmp.w	#KEY_O,d0		; l'ordre de marche : l'avant, l'arriere
	bne.s	.notRank
	bsr	SwapRank
	bra	.done
.notRank:
	cmp.w	#KEY_S,d0		; sorts hors combat : soins, protections
	bne.s	.notCast
	move.w	#UI_SPELL,UiMode
	bra	.redraw
.notCast:
	cmp.w	#KEY_SPACE,d0
	bne	.done
	bsr	DoAction
	bra	.done

.fight:					; --- la rencontre, puis les ordres
	tst.w	MeetPhase
	beq.s	.orders
	bsr	MeetKey
	bra	.done
.orders:
	bsr	CombatKey
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

; CIA_Tick : le tic du module, appele par le timer A. Coupee dans les
; reglages, la musique n'avance plus du tout -- ce n'est pas seulement
; le volume qui tombe.
CIA_Tick:
	tst.w	OptMusic
	beq.s	.muted
	bsr	PT_Tick
.muted:
	rts

; --- retour trame, timer et replayer, dans la meme section ---
	include	"vblank.i"
	include	"ciatimer.i"
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
DungeonName:	dc.b	"PROGDIR:Donjons/Crypte.dgn",0
TxtNoDungeon:	dc.b	"AGACrawl : Donjons/Crypte.dgn introuvable ou abime.",10
TXTNODUNGEON_LEN = *-TxtNoDungeon
	even
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
	dc.b	17,18,14,3,6,22,21,26	; mailles, epee longue, parchemins
	dc.b	18,18,15,9,10,11,24,23	; harnois et lames enchantees
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
	dc.l	PosX,14			; PosX, PosY, Dir, Level, Gold, KeyCount,
					; Acquitted
	dc.l	Heroes,NHEROES*hr_SIZEOF
	dc.l	Inventory,INVSIZE
	dc.l	LevelStore,LVSTORE	; les trois etages, chacun dans son etat
	dc.l	LevelKnown,LEVELS*2	; et ceux que le groupe a deja vus
	dc.l	OptMusic,8		; musique, bruitages, disposition, combat
	dc.l	0,0

	include	"surfgrad.i"

OptNames:
	dc.l	TxtOptMusic,TxtOptSfx,TxtOptKb,TxtOptCombat,TxtOptSave
	dc.l	TxtOptTitleBack

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
	dc.l	TxtLegLedger
	dc.b	20,140,C_PARCH,0

ClassDesc:
	dc.l	TxtCls0,TxtCls1,TxtCls2,TxtCls3
	dc.l	TxtCls4,TxtCls5,TxtCls6,TxtCls7
	dc.l	TxtCls8,TxtCls9,TxtCls10

RaceDesc:
	dc.l	TxtRace0,TxtRace1,TxtRace2,TxtRace3,TxtRace4,TxtRace5

; Le prologue, page par page : chaque page est une liste de lignes
; terminee par un long nul. Une ligne marquee d'une etoile passe a
; l'or -- il n'y en a qu'une, la derniere.
PrologPages:
	dc.l	PrologP0,PrologP1,PrologP2,PrologP3

PrologP0:
	dc.l	TxtPr0L00
	dc.l	TxtPr0L01
	dc.l	TxtPr0L02
	dc.l	TxtPr0L03
	dc.l	TxtPr0L04
	dc.l	TxtPr0L05
	dc.l	TxtPr0L06
	dc.l	TxtPr0L07
	dc.l	TxtPr0L08
	dc.l	TxtPr0L09
	dc.l	TxtPr0L10
	dc.l	TxtPr0L11
	dc.l	TxtPr0L12
	dc.l	TxtPr0L13
	dc.l	0
PrologP1:
	dc.l	TxtPr1L00
	dc.l	TxtPr1L01
	dc.l	TxtPr1L02
	dc.l	TxtPr1L03
	dc.l	TxtPr1L04
	dc.l	TxtPr1L05
	dc.l	TxtPr1L06
	dc.l	TxtPr1L07
	dc.l	TxtPr1L08
	dc.l	TxtPr1L09
	dc.l	TxtPr1L10
	dc.l	TxtPr1L11
	dc.l	TxtPr1L12
	dc.l	TxtPr1L13
	dc.l	0
PrologP2:
	dc.l	TxtPr2L00
	dc.l	TxtPr2L01
	dc.l	TxtPr2L02
	dc.l	TxtPr2L03
	dc.l	TxtPr2L04
	dc.l	TxtPr2L05
	dc.l	TxtPr2L06
	dc.l	TxtPr2L07
	dc.l	TxtPr2L08
	dc.l	TxtPr2L09
	dc.l	TxtPr2L10
	dc.l	TxtPr2L11
	dc.l	0
PrologP3:
	dc.l	TxtPr3L00
	dc.l	TxtPr3L01
	dc.l	TxtPr3L02
	dc.l	TxtPr3L03
	dc.l	TxtPr3L04
	dc.l	TxtPr3L05
	dc.l	TxtPr3L06
	dc.l	TxtPr3L07
	dc.l	TxtPr3L08
	dc.l	TxtPr3L09
	dc.l	TxtPr3L10
	dc.l	TxtPr3L11
	dc.l	TxtPr3L12
	dc.l	TxtPr3L13
	dc.l	TxtPr3L14
	dc.l	TxtPr3L15
	dc.l	0

TxtPr0L00:	dc.b	"FAERGHAIL N'EST PAS UN NOM D'HOMME.",0
TxtPr0L01:	dc.b	"C'EST UN MOT DE CONTRAT : FAERGH,",0
TxtPr0L02:	dc.b	"LE GAGE -- CE QU'ON LAISSE POUR",0
TxtPr0L03:	dc.b	"GARANTIR CE QU'ON PROMET -- ET GAIL,",0
TxtPr0L04:	dc.b	"LE SEUIL. LE SEUIL DU GAGE.",0
TxtPr0L05:	dc.b	"",0
TxtPr0L06:	dc.b	"IL Y A QUATRE SIÈCLES, LA VALLÉE",0
TxtPr0L07:	dc.b	"N'AVAIT NI PRINCE NI JUGE. UNE",0
TxtPr0L08:	dc.b	"PAROLE VALAIT CE QUE VALAIT CELUI",0
TxtPr0L09:	dc.b	"QUI L'ENTENDAIT ; À SA MORT, ELLE",0
TxtPr0L10:	dc.b	"NE VALAIT PLUS RIEN.",0
TxtPr0L11:	dc.b	"",0
TxtPr0L12:	dc.b	"ON A DONC BÂTI UNE MAISON QUI NE",0
TxtPr0L13:	dc.b	"MEURT PAS.",0
TxtPr1L00:	dc.b	"CE QUI EST PROMIS EST DÉPOSÉ : UN",0
TxtPr1L01:	dc.b	"OBJET LAISSE EN GAGE, UN GREFFIER",0
TxtPr1L02:	dc.b	"QUI L'INSCRIT AU REGISTRE, ET LA",0
TxtPr1L03:	dc.b	"LIGNE RAYÉE QUAND ON REVIENT LE",0
TxtPr1L04:	dc.b	"CHERCHER. SINON, LE GAGE RESTE,",0
TxtPr1L05:	dc.b	"ET LA LIGNE AUSSI.",0
TxtPr1L06:	dc.b	"",0
TxtPr1L07:	dc.b	"LA MAISON N'A PAS ÉTÉ CONSTRUITE :",0
TxtPr1L08:	dc.b	"ELLE A ÉTÉ REPRISE. SOUS LA COLLINE",0
TxtPr1L09:	dc.b	"COURAIT UNE CARRIÈRE DE SCHISTE,",0
TxtPr1L10:	dc.b	"TROIS NIVEAUX DE GALERIES. UN ÉTAGE",0
TxtPr1L11:	dc.b	"PAR GÉNÉRATION DE GREFFIERS : PLUS",0
TxtPr1L12:	dc.b	"ON DESCEND, PLUS LES DETTES SONT",0
TxtPr1L13:	dc.b	"VIEILLES.",0
TxtPr2L00:	dc.b	"LE DERNIER GREFFIER N'AVAIT PAS",0
TxtPr2L01:	dc.b	"D'HÉRITIER. LA COUTUME PRÉVOYAIT LE",0
TxtPr2L02:	dc.b	"CAS, ET ELLE PRÉVOYAIT MAL :",0
TxtPr2L03:	dc.b	"L'EMMUREMENT DE GARDE. ON L'A",0
TxtPr2L04:	dc.b	"ENFERMÉ VIVANT DERRIÈRE SON",0
TxtPr2L05:	dc.b	"COMPTOIR, AVEC LE REGISTRE ET DE",0
TxtPr2L06:	dc.b	"QUOI ÉCRIRE.",0
TxtPr2L07:	dc.b	"",0
TxtPr2L08:	dc.b	"IL A CESSÉ D'ÊTRE UN HOMME POUR",0
TxtPr2L09:	dc.b	"DEVENIR UNE CLAUSE DE LA MAISON.",0
TxtPr2L10:	dc.b	"C'EST LA VOIX QUE VOUS ENTENDREZ",0
TxtPr2L11:	dc.b	"DERRIÈRE LE MUR, À CHAQUE ÉTAGE.",0
TxtPr3L00:	dc.b	"DEPUIS UN SIÈCLE, PLUS PERSONNE NE",0
TxtPr3L01:	dc.b	"DESCEND PAYER. LA MAISON RECOUVRE",0
TxtPr3L02:	dc.b	"CE QU'ON LUI DOIT LÀ OÙ ELLE LE",0
TxtPr3L03:	dc.b	"TROUVE : SUR LES HÉRITIERS.",0
TxtPr3L04:	dc.b	"",0
TxtPr3L05:	dc.b	"L'HIVER DERNIER, À AMBELUNE, DES",0
TxtPr3L06:	dc.b	"NOMS DE VIVANTS SONT APPARUS À LA",0
TxtPr3L07:	dc.b	"CRAIE SUR LES PORTES DE GRANGES.",0
TxtPr3L08:	dc.b	"LES GENS DONT ON LISAIT LE NOM SE",0
TxtPr3L09:	dc.b	"SONT MIS A MANQUER.",0
TxtPr3L10:	dc.b	"",0
TxtPr3L11:	dc.b	"SIX PERSONNES DESCENDENT : LE",0
TxtPr3L12:	dc.b	"REGISTRE A SIX COLONNES DE",0
TxtPr3L13:	dc.b	"SIGNATURE AU BAS D'UNE QUITTANCE.",0
TxtPr3L14:	dc.b	"",0
TxtPr3L15:	dc.b	"*ON NE SORT DE FAERGHAIL QU'ACQUITTÉ.",0
	even

; Les trois livres du greffe : titre, cote, lignes, long nul.
ArchiveBooks:
	dc.l	ArchBook0,ArchBook1,ArchBook2
ArchBook0:
	dc.l	TxtAr0T,TxtAr0C
	dc.l	TxtAr0L0,TxtAr0L1,TxtAr0L2,TxtAr0L3,TxtAr0L4
	dc.l	TxtAr0L5,TxtAr0L6,TxtAr0L7,TxtAr0L8,TxtAr0L9,0
ArchBook1:
	dc.l	TxtAr1T,TxtAr1C
	dc.l	TxtAr1L0,TxtAr1L1,TxtAr1L2,TxtAr1L3,TxtAr1L4
	dc.l	TxtAr1L5,TxtAr1L6,TxtAr1L7,TxtAr1L8,TxtAr1L9,0
ArchBook2:
	dc.l	TxtAr2T,TxtAr2C
	dc.l	TxtAr2L0,TxtAr2L1,TxtAr2L2,TxtAr2L3,TxtAr2L4
	dc.l	TxtAr2L5,TxtAr2L6,TxtAr2L7,TxtAr2L8,TxtAr2L9,0

TxtAr0T:	dc.b	"LES RECOUVREMENTS",0
TxtAr0C:	dc.b	"LIVRE DES DALLES",0
TxtAr0L0:	dc.b	"À CHAQUE LIGNE OUVERTE",0
TxtAr0L1:	dc.b	"SA DALLE, ET SOUS LA",0
TxtAr0L2:	dc.b	"DALLE UN RESSORT TENDU",0
TxtAr0L3:	dc.b	"COMME UN PIÈGE À LOUP.",0
TxtAr0L4:	dc.b	"",0
TxtAr0L5:	dc.b	"UN RESSORT NE SERT",0
TxtAr0L6:	dc.b	"QU'UNE FOIS : LA DETTE",0
TxtAr0L7:	dc.b	"EST SOLDÉE, LA PIERRE",0
TxtAr0L8:	dc.b	"REDEVIENT PIERRE.",0
TxtAr0L9:	dc.b	"*LA CROIX : À EXAMINER.",0
TxtAr1T:	dc.b	"LES PASSAGES",0
TxtAr1C:	dc.b	"LIVRE DES QUESTIONS",0
TxtAr1L0:	dc.b	"UNE CLÉ SE VOLE. UNE",0
TxtAr1L1:	dc.b	"RÉPONSE, ON NE LA SAIT",0
TxtAr1L2:	dc.b	"QUE SI ON VOUS L'A",0
TxtAr1L3:	dc.b	"DONNÉE EN VOUS",0
TxtAr1L4:	dc.b	"INSCRIVANT.",0
TxtAr1L5:	dc.b	"",0
TxtAr1L6:	dc.b	"TROIS RÉPONSES, PAS",0
TxtAr1L7:	dc.b	"UNE DE PLUS : LE LIVRE",0
TxtAr1L8:	dc.b	"A TROIS COLONNES.",0
TxtAr1L9:	dc.b	"*LA RUNE VOUS INSCRIT.",0
TxtAr2T:	dc.b	"LE GUICHET",0
TxtAr2C:	dc.b	"EMMUREMENT DE GARDE",0
TxtAr2L0:	dc.b	"OSSIAN VAUGRIS,",0
TxtAr2L1:	dc.b	"DERNIER GREFFIER, SANS",0
TxtAr2L2:	dc.b	"HÉRITIER, DEMANDE",0
TxtAr2L3:	dc.b	"L'EMMUREMENT. SIGNÉ",0
TxtAr2L4:	dc.b	"DE SA MAIN.",0
TxtAr2L5:	dc.b	"",0
TxtAr2L6:	dc.b	"IL RENDRA CONTRE OR CE",0
TxtAr2L7:	dc.b	"QUE LA MAISON DÉTIENT,",0
TxtAr2L8:	dc.b	"ET RACHÈTE À MOITIÉ :",0
TxtAr2L9:	dc.b	"*LE TAUX D'UN DÉPÔT.",0
	even

FloorLore:				; l'inscription de chaque etage
	dc.l	TxtFloor0,TxtFloor1,TxtFloor2

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
TxtCls1:	dc.b	"TRÈS ROBUSTE, BRUTAL",0
TxtCls2:	dc.b	"AGILE, FUIT PLUS VITE",0
TxtCls3:	dc.b	"ARC ET SORTS DES BOIS",0
TxtCls4:	dc.b	"LA LAME ET LA FOI",0
TxtCls5:	dc.b	"SOINS ET SORTS DIVINS",0
TxtCls6:	dc.b	"FRAGILE, MAGIE VASTE",0
TxtCls7:	dc.b	"MAGIE INNÉE ET CHARME",0
TxtCls8:	dc.b	"SAGESSE DES BOIS, SOINS",0
TxtCls9:	dc.b	"SANS ARMURE, RÉSISTE",0
TxtCls10:	dc.b	"ROBUSTE, RÉPARE LE FER",0
TxtRace0:	dc.b	"AUCUN BONUS NI MALUS",0
TxtRace1:	dc.b	"CON +2  CHA -2",0
TxtRace2:	dc.b	"DEX +2  CON -2",0
TxtRace3:	dc.b	"DEX +2  FOR -2",0
TxtRace4:	dc.b	"UN PEU DES DEUX PEUPLES",0
TxtRace5:	dc.b	"FOR +2  INT -2  CHA -2",0
TxtPickRace:	dc.b	"FLÈCHES PUIS ENTRÉE",0
TxtBanned:	dc.b	"CETTE RACE NE DONNE PAS CETTE CLASSE.",0
TxtFor:		dc.b	"FOR ",0
TxtDex:		dc.b	"DEX ",0
TxtCon:		dc.b	"CON ",0
TxtInt:		dc.b	"INT ",0
TxtSag:		dc.b	"SAG ",0
TxtCha:		dc.b	"CHA ",0

TxtIntro:	dc.b	"ON NE SORT DE FAERGHAIL QU'ACQUITTÉ.",0
TxtFloor0:	dc.b	"LE GREFFE. LES GAGES SONT RÉCENTS.",0
TxtFloor1:	dc.b	"PLUS BAS : LES VIEILLES ÉCHÉANCES.",0
TxtFloor2:	dc.b	"LE FOND. PLUS PERSONNE N'A PAYÉ.",0
TxtCreate1:	dc.b	"CRÉEZ VOS SIX AVENTURIERS.",0
TxtCreate2:	dc.b	"CHAQUE CLASSE A SES FORCES.",0
TxtCreateTitle:	dc.b	"CRÉATION DU GROUPE",0
TxtEmptySlot:	dc.b	"-----",0
TxtHero:	dc.b	"HÉROS ",0
TxtOn4:		dc.b	" SUR 6",0
TxtDash:	dc.b	" - ",0
TxtHyphen:	dc.b	"-",0
TxtNivShort:	dc.b	"N",0
TxtPickClass:	dc.b	"FLÈCHES PUIS ENTRÉE",0
TxtRoll:	dc.b	"R RELANCER  ENTRÉE OK",0
TxtName:	dc.b	"NOM : ",0
TxtNameHelp:	dc.b	"TAPEZ OU FLÈCHES",0
TxtAzerty:	dc.b	"TAB : AZERTY",0
TxtQwerty:	dc.b	"TAB : QWERTY",0
TxtWall:	dc.b	"UN MUR BLOQUE LE PASSAGE.",0
TxtDoorShut:	dc.b	"PORTE FERMÉE. ESPACE POUR OUVRIR.",0
TxtDoorOpen:	dc.b	"LA PORTE S'OUVRE EN GRINÇANT.",0
TxtLocked:	dc.b	"CETTE PORTE EST VERROUILLÉE.",0
TxtNeedKey:	dc.b	"IL VOUS FAUT UNE CLÉ.",0
TxtUnlock:	dc.b	"LA CLÉ TOURNE. LA PORTE CÈDE.",0
TxtNothing:	dc.b	"RIEN A FAIRE ICI.",0
TxtNiche:	dc.b	"DANS LA NICHE : ",0
TxtNicheEmpty:	dc.b	"LA NICHE EST VIDE.",0
TxtChest:	dc.b	"UN COFFRE ! ",0
TxtGoldSuffix:	dc.b	" OR.",0
TxtFound:	dc.b	"VOUS TROUVEZ ",0
TxtDrops:	dc.b	"VOUS JETEZ ",0
TxtBagFull:	dc.b	"LE SAC EST PLEIN.",0
TxtDescend:	dc.b	"UN ESCALIER. VOUS DESCENDEZ.",0
TxtAscend:	dc.b	"UN ESCALIER. VOUS REMONTEZ.",0
TxtNoWayUp:	dc.b	"AU-DESSUS, C'EST LE JOUR.",0
TxtWin:		dc.b	"ACQUITTÉS. VOUS REVOYEZ LE JOUR.",0
TxtAppears:	dc.b	"UN ",0
TxtBang:	dc.b	" SURGIT !",0
TxtNoSpells:	dc.b	" NE CONNAÎT AUCUN SORT.",0
TxtLostFocus:	dc.b	" PERD SA CONCENTRATION.",0
TxtRoundTitle:	dc.b	"RÉSULTAT DU ROUND ",0
TxtRoundFoes:	dc.b	"EUX : ",0
TxtRoundBlows:	dc.b	" COUPS, ",0
TxtRoundHp:	dc.b	" PV",0
TxtRoundGo:	dc.b	"UNE TOUCHE : LA SUITE",0
TxtOrderSep:	dc.b	" : ",0
TxtTimes:	dc.b	" X",0
TxtResNone:	dc.b	"-",0
TxtResHit:	dc.b	"FRAPPE",0
TxtResMiss:	dc.b	"MANQUE",0
TxtResGuard:	dc.b	"PARE",0
TxtResFar:	dc.b	"LOIN : PARE",0
TxtResSpell:	dc.b	"SORT",0
TxtResConc:	dc.b	"DÉCONCENTRÉ",0
TxtOrdAttack:	dc.b	"FRAPPER",0
TxtOrdGuard:	dc.b	"PARER",0
TxtOptCombat:	dc.b	"COMBAT        ",0
TxtOptDetail:	dc.b	"DÉTAILLÉ",0
TxtOptQuick:	dc.b	"RAPIDE",0
	even
ResTexts:
	dc.l	TxtResNone,TxtResHit,TxtResMiss,TxtResGuard,TxtResFar
	dc.l	TxtResSpell,TxtResConc
OrderNames:
	dc.l	TxtOrdAttack,TxtOrdGuard
TxtSurprised:	dc.b	"VOUS ÊTES SURPRIS !",0
TxtSeenComing:	dc.b	"VOUS LES VOYEZ VENIR.",0
TxtToArms:	dc.b	"AUX ARMES !",0
TxtDeaf:	dc.b	"ILS NE RÉPONDENT QU'AU FER.",0
TxtMenacing:	dc.b	"ILS AVANCENT, MENAÇANTS.",0
TxtGreetBack:	dc.b	"ILS RENDENT LE SALUT ET PASSENT.",0
TxtStare:	dc.b	"ILS VOUS FIXENT, SANS BOUGER.",0
TxtImpatient:	dc.b	"ILS PERDENT PATIENCE.",0
TxtNoTongue:	dc.b	"ILS NE PARLENT PAS.",0
TxtNobodySpeaks: dc.b	"PERSONNE NE PARLE ",0
TxtParleys:	dc.b	" PARLEMENTE.",0
TxtTalkFails:	dc.b	"ILS NE VEULENT RIEN ENTENDRE.",0
TxtLetPass:	dc.b	"ILS VOUS LAISSENT PASSER.",0
TxtTollAsk:	dc.b	"ILS DEMANDENT ",0
TxtTollAsk2:	dc.b	" PIÈCES. O OU N ?",0
TxtTollPaid:	dc.b	"VOUS PAYEZ ",0
TxtTollPaid2:	dc.b	" PIÈCES. ILS PASSENT.",0
TxtTollRefused:	dc.b	"ILS DÉGAINENT.",0
TxtTollPoor:	dc.b	"VOUS N'AVEZ PAS DE QUOI.",0
TxtTonguesLbl:	dc.b	"LANGUES",0
TxtMeetAsk:	dc.b	"QUE FAITES-VOUS ?",0
TxtTollTag:	dc.b	"PAYER LE PÉAGE ?",0
TxtHelpMeet:	dc.b	"S SALUE D PARLE F FUIT A ATTAQUE",0
TxtHelpToll:	dc.b	"O PAYER   N REFUSER",0
TxtToBack:	dc.b	" PASSE À L'ARRIÈRE.",0
TxtToFront:	dc.b	" PASSE À L'AVANT.",0
TxtNotAlone:	dc.b	"IL N'EST PAS SEUL : ILS SONT ",0
TxtNextOne:	dc.b	"UN AUTRE S'AVANCE. RESTENT : ",0
TxtYouHit:	dc.b	"LE GROUPE INFLIGE ",0
TxtDamage:	dc.b	" DÉGÂTS.",0
TxtAllMiss:	dc.b	"TOUS LES COUPS SE PERDENT.",0
TxtHits:	dc.b	" TOUCHE ",0
TxtFor2:	dc.b	" : ",0
TxtMissed:	dc.b	" MANQUE ",0
TxtFalls:	dc.b	" S'EFFONDRE !",0
TxtDies:	dc.b	" TOMBE ! +",0
TxtXpGold:	dc.b	" PX, ",0
TxtLevelUp:	dc.b	" PASSE UN NIVEAU !",0
TxtFlee:	dc.b	"VOUS PRENEZ LA FUITE.",0
TxtFleeFail:	dc.b	"LA FUITE ÉCHOUE !",0
TxtWiped:	dc.b	"LE GROUPE EST ANÉANTI.",0
TxtMonStunned:	dc.b	"LE MONSTRE RECULE, TERRIFIÉ.",0
TxtCasts:	dc.b	" LANCE ",0
TxtSpellHit:	dc.b	"LE SORT INFLIGE ",0
TxtHealed:	dc.b	" RÉCUPÈRE ",0
TxtPvSuffix:	dc.b	" PV.",0
TxtLedgerSeen:	dc.b	"UN PUPITRE. UN LIVRE ENCHAINE.",0
TxtLedgerOpen:	dc.b	"LE GRAND REGISTRE DE FAERGHAIL.",0
TxtLedgerTitle:	dc.b	"LE GRAND REGISTRE",0
TxtLedgerHouse:	dc.b	"MAISON DE GARDE",0
TxtLedgerFloor:	dc.b	"GREFFE DU FOND",0
TxtLedgerHead:	dc.b	"LIGNE NON RAYÉE :",0
TxtLedgerHeadOk: dc.b	"LIGNE RAYÉE :",0
TxtLedgerDot:	dc.b	". ",0
TxtLedgerQuill:	dc.b	"LA PLUME EST À PORTÉE.",0
TxtLedgerAsk:	dc.b	"ENTRÉE : RAYER LA LIGNE",0
TxtLedgerDone:	dc.b	"LA LIGNE EST RAYÉE.",0
TxtLedgerFree:	dc.b	"VOUS ÊTES ACQUITTÉS.",0
TxtLedgerStruck: dc.b	"LA PLUME RAYE LA LIGNE.",0
TxtLedgerOut:	dc.b	"LA MAISON NE VOUS DOIT PLUS RIEN.",0
TxtDoorHeld:	dc.b	"L'ESCALIER DESCEND SUR UNE PORTE.",0
TxtDoorHeld2:	dc.b	"ELLE NE CÈDE PAS : RIEN N'EST RAYÉ.",0
TxtHelpLedger:	dc.b	"ENTRÉE RAYE LA LIGNE   ESC REFERME",0
TxtProgress:	dc.b	" PROGRESSE : ",0
TxtSkillsOf:	dc.b	"COMPÉTENCES : ",0
TxtSkillsHelp:	dc.b	"TAB : LA FICHE",0
TxtHelpArchive:	dc.b	"ESC REFERME LE LIVRE",0
TxtArchiveSeen:	dc.b	"DES REGISTRES, DU SOL À LA VOÛTE.",0
TxtArchiveOpen:	dc.b	"VOUS OUVREZ UN LIVRE DU GREFFE.",0
TxtArchiveLearn: dc.b	"LE GROUPE COMPREND MIEUX LA MAISON.",0
TxtArchiveMute:	dc.b	"DES COMPTES. RIEN QUI VOUS REGARDE.",0
TxtShopSeen:	dc.b	"UNE ÉCHOPPE ! ESPACE POUR ENTRER.",0
TxtShopHello:	dc.b	"UNE VOIX DERRIÈRE LE MUR : BIENVENUE",0
TxtShopTitle:	dc.b	"ÉCHOPPE",0
TxtShopBuy:	dc.b	"ACHAT",0
TxtShopSell:	dc.b	"VENTE",0
TxtShopHelp:	dc.b	"TAB CHANGE DE CÔTÉ",0
TxtShopHelp2:	dc.b	"ENTRÉE CONCLUT ESC SORT",0
TxtShopGold:	dc.b	"OR ",0
TxtShopEmpty:	dc.b	"L'ÉTAL EST VIDE.",0
TxtShopNoSell:	dc.b	"VOTRE SAC EST VIDE.",0
TxtShopPoor:	dc.b	"PAS ASSEZ D'OR.",0
TxtShopFull:	dc.b	"LE SAC EST PLEIN.",0
TxtShopBought:	dc.b	"ACHETÉ : ",0
TxtShopSold:	dc.b	"VENDU : ",0
TxtShopFor:	dc.b	", ",0
TxtShopOr:	dc.b	" OR.",0
TxtTrapSpot:	dc.b	"PIÈGE REPÉRÉ : ",0
TxtTrapFires:	dc.b	" SE DÉCLENCHE !",0
TxtTrapHurt:	dc.b	"LE GROUPE PERD ",0
TxtTrapMiss:	dc.b	"LE GROUPE S'EN TIRE INDEMNE.",0
TxtTrapOff:	dc.b	" DÉSAMORCE LE PIÈGE.",0
TxtTrapSlip:	dc.b	"LA MAIN TREMBLE. RIEN N'EST FAIT.",0
TxtTrapDown:	dc.b	"CE HÉROS N'EST PLUS EN ÉTAT.",0
TxtShieldUp:	dc.b	"UNE AURA PROTÈGE LE GROUPE.",0
TxtFear:	dc.b	"LE MONSTRE EST TERRIFIÉ !",0
TxtUnknownSpell: dc.b	"CE SORT VOUS EST INCONNU.",0
TxtNoSlot:	dc.b	"PLUS D'EMPLACEMENT A CE NIVEAU.",0
TxtHalfSave:	dc.b	"IL ESQUIVE EN PARTIE !",0
TxtResisted:	dc.b	"LE MONSTRE RÉSISTE AU SORT.",0
TxtBlessed:	dc.b	"UNE BÉNÉDICTION GUIDE VOS COUPS.",0
TxtHeroDown:	dc.b	"CE HÉROS EST HORS DE COMBAT.",0
TxtEquips:	dc.b	" ÉQUIPE ",0
TxtCannotEquip:	dc.b	"CELA NE S'ÉQUIPE PAS.",0
TxtCannotUse:	dc.b	"CELA NE S'UTILISE PAS.",0
TxtLearns:	dc.b	" APPREND ",0
TxtAlreadyKnown: dc.b	"CE SORT EST DÉJÀ CONNU.",0
TxtNoMagic:	dc.b	"CE HÉROS N'EST PAS MAGICIEN.",0
TxtNoHero:	dc.b	"AUCUN HÉROS ICI.",0
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
TxtKeys:	dc.b	"   CLÉS ",0
TxtRuneDoor:	dc.b	"UNE PORTE COUVERTE DE RUNES.",0
TxtLeverSeen:	dc.b	"UN LEVIER SCELLÉ DANS LE MUR.",0
TxtGateShut:	dc.b	"UNE HERSE DE FER BARRE LE PASSAGE.",0
TxtLeverDown:	dc.b	"LE LEVIER CÈDE. UNE HERSE SE LÈVE.",0
TxtLeverUp:	dc.b	"LE LEVIER REMONTE. LA HERSE RETOMBE.",0
TxtRuneTitle:	dc.b	"LA PORTE VOUS INTERROGE",0	; 23 : la vue
TxtRuneAsk:	dc.b	"RÉPONDEZ : 1, 2 OU 3",0
TxtRuneOk:	dc.b	"LES RUNES S'EFFACENT. PASSAGE !",0
TxtRuneBad:	dc.b	"LA RUNE ROUGEOIT DE COLÈRE.",0
TxtRuneBurn:	dc.b	" EST BRÛLÉ, ",0
TxtR0Q1:	dc.b	"JE PARLE SANS BOUCHE",0
TxtR0Q2:	dc.b	"ET J'ENTENDS SANS",0
TxtR0Q3:	dc.b	"OREILLE. QUI SUIS-JE ?",0
TxtR0A1:	dc.b	"L'ÉCHO",0
TxtR0A2:	dc.b	"LE VENT",0
TxtR0A3:	dc.b	"LA PIERRE",0
TxtR1Q1:	dc.b	"PLUS ON EN PREND,",0
TxtR1Q2:	dc.b	"PLUS ON EN LAISSE",0
TxtR1Q3:	dc.b	"DERRIÈRE SOI. QUOI ?",0
TxtR1A1:	dc.b	"DES PIÈCES D'OR",0
TxtR1A2:	dc.b	"DES PAS",0
TxtR1A3:	dc.b	"DES ANNÉES",0
TxtR2Q1:	dc.b	"J'AI UN OEIL",0
TxtR2Q2:	dc.b	"MAIS JE NE VOIS RIEN.",0
TxtR2Q3:	dc.b	"QUI SUIS-JE ?",0
TxtR2A1:	dc.b	"LE BORGNE",0
TxtR2A2:	dc.b	"L'AIGUILLE",0
TxtR2A3:	dc.b	"LA TOUR DE GUET",0
TxtHelpRiddle:	dc.b	"1 2 OU 3 POUR RÉPONDRE  ESC",0
TxtHelpCreate:	dc.b	"1-9 CHOISIR  R DÉS  ENTRÉE OK  ESC",0
TxtHelpMove:	dc.b	"ESPACE C I M CARTE L LIVRE P RÉGLAGES",0
TxtRaised:	dc.b	" SE RELÈVE.",0
TxtRested:	dc.b	"LE GROUPE FAIT HALTE ET RÉCUPÈRE.",0
TxtNoTarget:	dc.b	"AUCUNE CIBLE ICI.",0
TxtMenuNew:	dc.b	"1   COMMENCER UNE NOUVELLE PARTIE",0
TxtMenuLoad:	dc.b	"2   REPRENDRE LA PARTIE SAUVÉE",0
TxtMenuStory:	dc.b	"3   CE QU'ÉTAIT CETTE CRYPTE",0
TxtMenuQuit:	dc.b	"ESC QUITTER",0
TxtPrologTitle:	dc.b	"LE SEUIL DU GAGE",0
TxtPrologPage:	dc.b	"PAGE ",0
TxtPrologOf:	dc.b	" SUR ",0
TxtPrologHelp:	dc.b	"UNE TOUCHE TOURNE LA PAGE   ESC SORT",0
TxtMenuHint:	dc.b	"LA PARTIE SE SAUVE A CHAQUE ÉTAGE",0
TxtResumed:	dc.b	"VOUS REPRENEZ VOTRE DESCENTE.",0
TxtSaved:	dc.b	"LA PARTIE EST SAUVÉE.",0
TxtOptTitle:	dc.b	"RÉGLAGES",0
TxtOptMusic:	dc.b	"MUSIQUE       ",0
TxtOptSfx:	dc.b	"BRUITAGES     ",0
TxtOptKb:	dc.b	"CLAVIER       ",0
TxtOptSave:	dc.b	"SAUVEGARDER MAINTENANT",0
TxtOptTitleBack:	dc.b	"RETOUR A L'ACCUEIL",0
TxtOptOn:	dc.b	"OUI",0
TxtOptOff:	dc.b	"NON",0
TxtOptAzerty:	dc.b	"AZERTY",0
TxtOptQwerty:	dc.b	"QWERTY",0
TxtHelpOpts:	dc.b	"FLÈCHES  ENTRÉE CHANGE  P OU ESC",0
TxtBookTitle:	dc.b	"GRIMOIRE DE ",0
TxtBookMark:	dc.b	">",0
TxtBookLevel:	dc.b	"NIV ",0
TxtBookSchool:	dc.b	" ",0
TxtBookPerLvl:	dc.b	" PAR NIV. ",0
TxtBookSave:	dc.b	"JET ",0
TxtBookHalf:	dc.b	", MOITIÉ",0
TxtBookNoSave:	dc.b	"SANS JET",0
TxtBookSlots:	dc.b	"  RESTE ",0
TxtSchoolArc:	dc.b	"PROFANE",0
TxtSchoolDiv:	dc.b	"DIVIN",0
TxtSchoolBoth:	dc.b	"MIXTE",0
TxtKindDmg:	dc.b	"DÉGÂTS ",0
TxtKindHeal:	dc.b	"SOINS ",0
TxtKindWard:	dc.b	"PROTECTION +",0
TxtKindFear:	dc.b	"TERREUR ",0
TxtKindBless:	dc.b	"BÉNÉDICTION +",0
TxtSaveFort:	dc.b	"VIGUEUR",0
TxtSaveRef:	dc.b	"RÉFLEXES",0
TxtSaveWill:	dc.b	"VOLONTÉ",0
TxtHelpBook:	dc.b	"FLÈCHES  1-6 HÉROS  L OU ESC FERMER",0
TxtMapTitle:	dc.b	"CARTE NIVEAU ",0
TxtDash2:	dc.b	" - ",0
TxtNord:	dc.b	"NORD",0
TxtEst:		dc.b	"EST",0
TxtSud:		dc.b	"SUD",0
TxtOuest:	dc.b	"OUEST",0
TxtLegDoor:	dc.b	"PORTE",0
TxtLegRune:	dc.b	"RUNE",0
TxtLegShut:	dc.b	"FERMÉE",0
TxtLegYou:	dc.b	"VOUS",0
TxtLegStairs:	dc.b	"ESCALIER",0
TxtLegMonster:	dc.b	"MONSTRE",0
TxtLegLedger:	dc.b	"GREFFE",0
TxtHelpMap:	dc.b	"M OU ESC POUR REFERMER LA CARTE",0
TxtConfirmQuit:	dc.b	"ESC A NOUVEAU POUR ABANDONNER.",0
TxtNoSpellKnown:	dc.b	"AUCUN SORT CONNU.",0
TxtHelpFight:	dc.b	"A FRAPPE D PARE S SORT F FUIT ENTRÉE",0
TxtHelpInv:	dc.b	"E ÉQUIPER U UTILISER D JETER 1-6",0
TxtHelpSpell:	dc.b	"CHIFFRE POUR LANCER   ESC ANNULE",0
TxtHelpSheet:	dc.b	"TAB COMPÉTENCES  1-6 HÉROS  I SAC",0
TxtHelpShop:	dc.b	"FLÈCHES  TAB COTE  ENTRÉE  ESC SORT",0
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
DgnMapPtr:	ds.l	1		; les cartes, dans le paquet du donjon
DgnBank:	ds.l	1		; son bestiaire, idem
OldView:	ds.l	1
OldCopper:	ds.l	1
ShowBuf:	ds.l	1
DrawBuf:	ds.l	1
CopBplPtrs:	ds.l	1
MonPtr:		ds.l	1
RngSeed:	ds.l	1
OldIntena:	ds.w	1
OldDmacon:	ds.w	1
VBI_Vbr:	ds.l	1
VBI_OldLvl3:	ds.l	1
VBI_Count:	ds.w	1
VBI_Flag:	ds.w	1
CIA_Vbr:	ds.l	1
CIA_OldLvl6:	ds.l	1
CIA_Count:	ds.w	1
CIA_Bpm:	ds.w	1
PosX:		ds.w	1
PosY:		ds.w	1
Dir:		ds.w	1
Level:		ds.w	1
Gold:		ds.w	1
KeyCount:	ds.w	1
Acquitted:	ds.w	1		; la ligne du registre est rayee
ArchiveBook:	ds.w	1		; le livre du greffe ouvert
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
OptMusic:	ds.w	1		; les trois reglages se suivent : ils
OptSfx:	ds.w	1		; partent ensemble dans la sauvegarde
KbLayout:	ds.w	1
OptQuick:	ds.w	1		; combat : 0 detaille, 1 rapide
CurMusic:	ds.w	1
CopSurf:	ds.l	1
SurfPhase:	ds.w	1
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
MonLastVbi:	ds.w	1		; VBI_Count au dernier passage de MonWalk
HitFlags:	ds.b	NHEROES		; ceux qui ont touche pendant le round
	even
SheetPage:	ds.w	1		; fiche : 0 le heros, 1 ses competences
MeetPhase:	ds.w	1		; 0 combat, 1 rencontre, 2 peage
MeetAmbush:	ds.w	1		; la creature est venue a nous
MeetGreeted:	ds.w	1		; on a deja salue
MeetToll:	ds.w	1		; le peage demande
Guarding:	ds.b	NHEROES		; ceux qui parent ce round
ResCode:	ds.b	NHEROES		; ce que chacun a fait, pour le panneau
ResVal:		ds.w	NHEROES		; et ses degats
OrderHero:	ds.w	1		; a qui c'est de donner son ordre
InResolve:	ds.w	1		; un round est en train de se jouer
RoundNo:	ds.w	1		; numero du round dans le combat
RoundDmg:	ds.w	1
RoundSfx:	ds.w	1		; le bruitage d'arme du round, plus un		; ce que le groupe a inflige au dernier
MonHits:	ds.w	1		; coups portes par les creatures, et
MonDmg:		ds.w	1		; leurs degats, au dernier round
Orders:		ds.b	NHEROES		; l'ordre de combat de chacun, retenu
	even				; d'un round et d'un combat a l'autre
GroupN:		ds.w	1		; creatures encore debout, celle de devant
GroupNext:	ds.w	1		; comprise, et la prochaine a s'avancer
GroupHp:	ds.w	GROUPMAX	; leurs points de vie, tires d'avance
StrikeTime:	ds.w	1		; trames de pose d'attaque restantes
FlameFrame:	ds.w	1		; la flamme de la lanterne du guichet
ShopInSight:	ds.w	1		; le guichet est dans la vue, a un pas
AnimCount:	ds.w	1
GameOver:	ds.w	1
Quit:		ds.w	1
NeedRedraw:	ds.w	1
PrologPage:	ds.w	1		; page lue du prologue
DrawReady:	ds.w	1
MonClock:	ds.w	1		; trames depuis le dernier pas
MonMoved:	ds.w	1		; quelque chose a bouge : on redessine
MonToX:		ds.w	1		; la case visee par le pas en cours
MonToY:		ds.w	1
MonX:		ds.w	1		; la case du monstre que l'on combat
MonY:		ds.w	1
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
CreRace:	ds.w	1		; la race choisie, dans RaceTable
CreHp:		ds.w	1
CreMp:		ds.w	1
CreNameLen:	ds.w	1
CreNameIdx:	ds.w	1
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
LevelStore:	ds.b	LVSTORE		; l'etat garde de chaque etage
LevelKnown:	ds.w	LEVELS		; celui-ci a-t-il deja ete visite
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

DgnPack:	ds.b	DGNPACKMAX	; le paquet du donjon, lu au demarrage
ScreenA:	ds.b	SCRSIZE
ScreenB:	ds.b	SCRSIZE
CopList:	ds.b	COPSIZE
