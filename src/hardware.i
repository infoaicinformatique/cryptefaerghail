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

; --- palette ---
COLOR00         = $180
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

; --- CIA-A ---
CIAAPRA         = $bfe001       ; bit 6 = bouton gauche souris (0 = appuye)

; --- LVO exec.library ---
_LVOForbid      = -132
_LVOAllocMem    = -198
_LVOFreeMem     = -210
_LVOPermit      = -138
_LVOOpenLibrary = -552
_LVOCloseLibrary = -414

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
