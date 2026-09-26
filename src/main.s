.assume adl=1
.include "macros.inc"
.include "platform.inc"
.include "game.inc"
.section .text
.db 0xEF, 0x7B
    jp start
.include "icon.inc"
.include "assets.inc"
.global start
start:
    ld hl, bss_start
    ld de, bss_start+1
    ld bc, bss_size-1
    ld (hl), 0
    ldir
    call load_scores
    call platform_start
    call app
    jp platform_exit
.include "game.s"
.include "platform.s"
.include "save.s"
.include "input.s"
.include "math.s"
.include "render.s"
