.macro RECT x,y,w,h,color
    ld hl, (draw_buffer)
    ld de, (\y)*320 + (\x)
    add hl, de
    ld bc, \w
    ld d, \h
    ld e, \color
    call rect
.endm

; Sets up text drawing at (x, y): hl = address, ix = font.
.macro PEN x,y,color,face,scale
    ld a, \scale
    ld (text_scale), a
    ld a, \color
    ld (text_color), a
    ld hl, (draw_buffer)
    ld de, (\y)*320 + (\x)
    add hl, de
    ld ix, \face
.endm

.macro LABEL x,y,label,color,face=font_small,scale=1
    PEN \x,\y,\color,\face,\scale
    ld de, \label
    call text
.endm

.macro CENTER x,y,label,color,face=font_small,scale=1
    PEN \x,\y,\color,\face,\scale
    ld de, \label
    call text_center
.endm

; bc = value
.macro NUMBER x,y,color
    PEN \x,\y,\color,font_medium,1
    call number
.endm
