;----------------------------------------------------------------------
; hardware.i - Equates des registres custom (offsets depuis $DFF000)
; Cible : Amiga 1200 / AGA (Alice, Lisa) - AmigaOS 3.1+
; Aucune dependance au NDK : tout est defini ici.
;----------------------------------------------------------------------

CUSTOM          = $dff000

; --- lecture ---
DMACONR         = $002
VPOSR           = $004
VHPOSR          = $006
JOY0DAT         = $00a
POTGOR          = $016
INTENAR         = $01c
INTREQR         = $01e

; --- copper ---
COP1LCH         = $080
COP1LCL         = $082
COP2LCH         = $084
COPJMP1         = $088
COPJMP2         = $08a

; --- fenetre d'affichage / DMA ---
DIWSTRT         = $08e
DIWSTOP         = $090
DDFSTRT         = $092
DDFSTOP         = $094
DMACON          = $096
INTENA          = $09a
INTREQ          = $09c

; --- bitplanes ---
BPLCON0         = $100
BPLCON1         = $102
BPLCON2         = $104
BPLCON3         = $106          ; AGA : BANK (15-13), LOCT (9), SPRES (7-6)
BPL1MOD         = $108
BPL2MOD         = $10a
BPLCON4         = $10c          ; AGA : BPLAM (15-8), ESPRM (7-4), OSPRM (3-0)
BPL1PTH         = $0e0

; --- sprites ---
SPR0PTH         = $120
SPR0PTL         = $122

; --- blitter ---
BLTCON0         = $040
BLTCON1         = $042
BLTAFWM         = $044
BLTALWM         = $046
BLTCPT          = $048
BLTBPT          = $04c
BLTAPT          = $050
BLTDPT          = $054
BLTSIZE         = $058
BLTCMOD         = $060
BLTBMOD         = $062
BLTAMOD         = $064
BLTDMOD         = $066
BLT_USEA        = $0800         ; canaux utilises, dans BLTCON0
BLT_USEB        = $0400
BLT_USEC        = $0200
BLT_USED        = $0100
BLT_A_OR_C      = $00fa         ; minterme D = A OR C
BLT_COOKIE      = $00ca         ; minterme D = (A AND B) OR (NOT A AND C)
BLT_COPY        = $00f0         ; minterme D = A

; --- audio (Paula) : AUD0 en $DFF0A0, un canal tous les $10 ---
AUD0LCH         = $0a0
AUDx_LC         = 0             ; long : adresse du sample (Chip RAM)
AUDx_LEN        = 4             ; word : longueur en mots
AUDx_PER        = 6             ; word : periode
AUDx_VOL        = 8             ; word : volume 0..64

; --- palette ---
COLOR00         = $180
COLOR01         = $182
COLOR15         = $19e
COLOR17         = $1a2
COLOR18         = $1a4
COLOR19         = $1a6

; --- AGA ---
FMODE           = $1fc          ; 0 = fetch 16 bits (compat OCS)

; --- bits MEMF (AllocMem) ---
MEMF_CHIP       = $00000002
MEMF_CLEAR      = $00010000

; --- bits DMACON ---
DMAF_SETCLR     = $8000
DMAF_BLITTER    = $0040
DMAF_COPPER     = $0080
DMAF_RASTER     = $0100
DMAF_SPRITE     = $0020
DMAF_MASTER     = $0200
DMAF_AUD0       = $0001
DMAF_AUDIO      = $000f

; --- CIA-A ---
CIAAPRA         = $bfe001       ; bit 6 = bouton gauche souris (0 = appuye)
CIAASDR         = $bfec01       ; port serie : code clavier
CIAAICR         = $bfed01       ; drapeaux d'interruption (lecture = effacement)
CIAACRA         = $bfee01       ; bit 6 : sens du port serie (poignee de main)

; --- LVO exec.library ---
_LVOForbid      = -132
_LVOAllocMem    = -198
_LVOFreeMem     = -210
_LVOPermit      = -138
_LVOOpenLibrary = -552
_LVOCloseLibrary = -414

; --- dos.library : sauvegarde de la partie ---
_LVOOpen        = -30
_LVOClose       = -36
_LVORead        = -42
_LVOWrite       = -48
MODE_OLDFILE    = 1005
MODE_NEWFILE    = 1006

; --- LVO graphics.library ---
_LVOLoadView    = -222
_LVOWaitBlit    = -228
_LVOWaitTOF     = -270
_LVORethinkDisplay = -390
_LVOOwnBlitter  = -456
_LVODisownBlitter = -462

; --- offsets GfxBase ---
gb_ActiView     = 34
gb_copinit      = 38

; --- CIA-B : le timer A cadence le replayer (niveau 6) ---
; Les registres sont espaces de 256 octets. L'horloge du CIA vaut
; 709379 Hz en PAL ; un module joue BPM x 2 / 5 tics par seconde, d'ou
; un compte de 709379 x 5 / (2 x BPM) = 1773447 / BPM.
CIABTALO        = $bfd400       ; compte du timer A, poids faible
CIABTAHI        = $bfd500       ; poids fort -- l'ecrire recharge le timer
CIABICR         = $bfdd00       ; masque d'interruption (lecture = efface)
CIABCRA         = $bfde00       ; commande du timer A
CIA_CLOCK5      = 1773447       ; 709379 x 5 / 2, a diviser par le BPM
CIACRA_RUN      = $11           ; demarre, continu, recharge tout de suite
CIAICR_CLEAR    = $7f           ; toutes les sources coupees
CIAICR_TA       = $81           ; interruption sur le timer A

; --- bits INTENA / INTREQ ---
INTF_SETCLR     = $8000
INTF_INTEN      = $4000         ; interrupteur general (maitre)
INTF_VERTB      = $0020         ; debut du retour trame -- niveau 3
INTB_VERTB      = 5
INTF_EXTER      = $2000         ; CIA-B et port d'extension -- niveau 6

; --- vecteurs d'exception (autovecteurs), depuis le VBR ---
LVL3_VECTOR     = $6c
LVL6_VECTOR     = $78

; --- exec.library : passage en mode superviseur, drapeaux processeur ---
_LVOSupervisor  = -30
AttnFlags       = 296           ; word : bit 0 = 68010 ou mieux (donc VBR)
AFB_68010       = 0
