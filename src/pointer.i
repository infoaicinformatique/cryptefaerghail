;---------------------------------------------------------
; pointer.i - GENERE PAR tools/gen_dungeon.py
; Sprite 0 : le pointeur de souris. Deux mots de controle,
; puis deux mots par ligne, puis deux zeros de fin.
;---------------------------------------------------------

MousePointer:
	dc.w	$0000,$0000		; SPR0POS / SPR0CTL, poses par le jeu
	dc.w	$8000,$0000
	dc.w	$8000,$4000
	dc.w	$c000,$6000
	dc.w	$e000,$7000
	dc.w	$f000,$7800
	dc.w	$f800,$7c00
	dc.w	$fc00,$7e00
	dc.w	$fe00,$7f00
	dc.w	$ff00,$7f80
	dc.w	$ff80,$7fc0
	dc.w	$f800,$7fe0
	dc.w	$ec00,$7e00
	dc.w	$ce00,$6700
	dc.w	$8e00,$4700
	dc.w	$8700,$0380
	dc.w	$0200,$0180
	dc.w	$0000,$0000		; fin du sprite
POINTER_H	= 16
