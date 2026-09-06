;----------------------------------------------------------------------
; sprite.i - GENERE PAR tools/gen_data.py - ne pas editer a la main
;----------------------------------------------------------------------

; Donnees pixels : 16 lignes de (plan0, plan1), puis mot de fin.
; A placer immediatement apres les mots SPRxPOS / SPRxCTL.
	dc.w	$0180,$0000
	dc.w	$0f80,$0070
	dc.w	$1f80,$0078
	dc.w	$3f8c,$007c
	dc.w	$7f8e,$007e
	dc.w	$7f8e,$007e
	dc.w	$7f1e,$00fe
	dc.w	$ff1f,$00ff
	dc.w	$fc3f,$03ff
	dc.w	$003e,$7ffe
	dc.w	$00fe,$7ffe
	dc.w	$03fe,$7ffe
	dc.w	$1ffc,$3ffc
	dc.w	$1ff8,$1ff8
	dc.w	$0ff0,$0ff0
	dc.w	$0180,$0180
	dc.w	$0000,$0000		; fin du sprite
