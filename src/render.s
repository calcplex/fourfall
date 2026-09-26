; Two screen buffers: the LCD shows front_buffer while draw_buffer is painted.
; The board is kept as 200 tiles, and only tiles that changed are drawn.

.equ canvas, 32
.equ panel, 33
.equ title_colors, 34

; hl = top-left address, bc = width, d = height, e = colour
rect:
    dec bc
    ld (rect_span), bc
    ld a, e
    ld (rect_color), a
    ld a, d
    ld (rect_rows), a
    ld b, d
rect_row:
    push bc
    push hl
    ld a, (rect_color)
    ld (hl), a
    ld bc, (rect_span)
    ld a, b
    or c
    jp z, rect_row_done
    push hl
    pop de
    inc de
    ldir
rect_row_done:
    pop hl
    ld de, 320
    add hl, de
    pop bc
    ld a, (rect_rows)
    cp 16
    jp c, rect_next
    ld a, b
    and 3
    call z, poll_keys
rect_next:
    djnz rect_row
    ret

; hl = address, a = tile number
tile:
    ex de, hl
    ld b, a
    ld c, 3
    mlt bc
    ld hl, tile_table
    add hl, bc
    ld hl, (hl)
    ld a, 10
tile_row:
    ld bc, 10
    ldir
    ex de, hl
    ld bc, 310
    add hl, bc
    ex de, hl
    dec a
    jp nz, tile_row
    ret

; a = board cell 0-199; hl = offset of its tile on the screen
cell_offset:
    ld hl, 22*320+110
    ld de, 3200
cell_offset_row:
    cp 10
    jp c, cell_offset_column
    sub 10
    add hl, de
    jp cell_offset_row
cell_offset_column:
    ld e, a
    ld d, 10
    mlt de
    add hl, de
    ret

; hl = address, de = string, ix = font; text_color and text_scale are set
text:
    ld a, (de)
    or a
    ret z
    inc de
    push de
    cp 32
    jp c, text_space
    cp 91
    jp c, text_glyph
text_space:
    ld a, 32
text_glyph:
    sub 32
    ld (text_cursor), hl
    ld e, a
    ld d, (ix+1)
    mlt de
    push hl
    ld hl, (ix+3)
    add hl, de
    ld (glyph_pointer), hl
    ld a, (text_scale)
    ld d, a
    ld e, 160
    mlt de
    ex de, hl
    add hl, hl
    ld (text_line), hl
    pop hl
    ld a, (ix+1)
    ld (glyph_rows), a
text_row:
    push hl
    ld de, (glyph_pointer)
    ld a, (de)
    inc de
    ld (glyph_pointer), de
    ld c, a
    ld b, (ix)
text_column:
    sla c
    jp nc, text_next
    ld a, (text_scale)
    dec a
    jp nz, text_block
    ld a, (text_color)
    ld (hl), a
    jp text_next
text_block:
    call text_pixel
text_next:
    ld de, 0
    ld a, (text_scale)
    ld e, a
    add hl, de
    djnz text_column
    pop hl
    ld de, (text_line)
    add hl, de
    ld a, (glyph_rows)
    dec a
    ld (glyph_rows), a
    jp nz, text_row
    ld hl, (text_cursor)
    ld d, (ix+2)
    ld a, (text_scale)
    ld e, a
    mlt de
    add hl, de
    call poll_keys
    pop de
    jp text

; A scaled-up font pixel at hl.
text_pixel:
    push bc
    push hl
    ld a, (text_scale)
    ld c, a
text_pixel_row:
    push hl
    ld a, (text_scale)
    ld b, a
    ld a, (text_color)
text_pixel_dot:
    ld (hl), a
    inc hl
    djnz text_pixel_dot
    pop hl
    ld de, 320
    add hl, de
    dec c
    jp nz, text_pixel_row
    pop hl
    pop bc
    ret

; As text, with hl at the centre of the line.
text_center:
    push hl
    push de
    ld bc, 0
text_count:
    ld a, (de)
    or a
    jp z, text_counted
    inc de
    inc c
    jp text_count
text_counted:
    ld b, (ix+2)
    mlt bc
    dec bc
    ld a, (text_scale)
    ld hl, 0
text_width:
    add hl, bc
    dec a
    jp nz, text_width
    srl h
    rr l
    push hl
    pop bc
    pop de
    pop hl
    or a
    sbc hl, bc
    jp text

; hl = address, bc = value; prints it in decimal without leading zeros
number:
    push hl
    push bc
    pop hl
    ld de, number_text
    ld iy, places
    xor a
    ld (number_started), a
    ld c, 6
number_place:
    ld b, 0
number_subtract:
    push de
    ld de, (iy)
    or a
    sbc hl, de
    pop de
    jp c, number_digit
    inc b
    jp number_subtract
number_digit:
    push de
    ld de, (iy)
    add hl, de
    pop de
    ld a, b
    or a
    jp nz, number_emit
    ld a, (number_started)
    or a
    jp nz, number_emit
    ld a, c
    dec a
    jp nz, number_skip
number_emit:
    ld a, b
    add a, 48
    ld (de), a
    inc de
    ld a, 1
    ld (number_started), a
number_skip:
    lea iy, iy+3
    dec c
    jp nz, number_place
    xor a
    ld (de), a
    pop hl
    ld de, number_text
    jp text

; As number, with hl at the centre (medium font).
center_number:
    push hl
    push bc
    push bc
    pop hl
    ld a, 1
center_number_digits:
    ld de, 10
    or a
    sbc hl, de
    add hl, de
    jp c, center_number_counted
    push af
    ld bc, 10
    call divide
    pop af
    inc a
    jp center_number_digits
center_number_counted:
    add a, a
    add a, a
    add a, a
    dec a
    srl a
    ld de, 0
    ld e, a
    pop bc
    pop hl
    or a
    sbc hl, de
    jp number

; a = piece, hl = address of the top centre of its box
preview:
    cp 7
    ret nc
    ld (preview_piece), a
    ld de, 15
    cp 2
    jp nc, preview_shift
    ld de, 20
    or a
    jp nz, preview_shift
    ld de, 20+3200
preview_shift:
    or a
    sbc hl, de
    ld (preview_base), hl
    xor a
    call shape_address_of
    ld b, 4
preview_cell:
    push bc
    push hl
    ld a, (hl)
    ld c, a
    and 15
    ld e, a
    ld d, 10
    mlt de
    ld hl, (preview_base)
    add hl, de
    ld a, c
    rrca
    rrca
    rrca
    rrca
    and 15
    jp z, preview_draw
    ld de, 3200
preview_row:
    add hl, de
    dec a
    jp nz, preview_row
preview_draw:
    ld a, (preview_piece)
    add a, 17
    call tile
    pop hl
    inc hl
    pop bc
    djnz preview_cell
    ret

; a = rotation; hl = the cells of preview_piece
shape_address_of:
    ld c, a
    ld a, (preview_piece)
    add a, a
    add a, a
    add a, c
    add a, a
    add a, a
    ld hl, shapes
    ld bc, 0
    ld c, a
    add hl, bc
    ret

draw_panels:
    RECT 8,20,94,204,canvas
    RECT 218,20,94,204,canvas
    LABEL 20,24,hold_label,4,font_medium
    ld hl, (draw_buffer)
    ld de, 44*320+54
    add hl, de
    ld a, (game+hold)
    call preview
    LABEL 20,78,score_label,4
    ld bc, (game+score)
    NUMBER 20,91,6
    LABEL 20,122,level_label,4
    ld bc, 0
    ld a, (game+level)
    ld c, a
    NUMBER 20,135,6
    LABEL 20,166,lines_label,4
    ld bc, (game+lines)
    NUMBER 20,179,6
    CENTER 264,24,next_label,4,font_medium
    ld hl, (draw_buffer)
    ld de, 44*320+264
    add hl, de
    ld b, 0
draw_panels_next:
    push bc
    push hl
    ld hl, game+next
    ld c, b
    ld b, 0
    add hl, bc
    ld a, (hl)
    pop hl
    push hl
    call preview
    pop hl
    ld de, 34*320
    add hl, de
    pop bc
    inc b
    ld a, b
    cp 3
    jp nz, draw_panels_next
    CENTER 264,155,best_label,4
    PEN 264,168,5,font_medium,1
    ld bc, (game+best)
    call center_number
    ld a, (game+message)
    or a
    jp z, draw_panels_done
    PEN 263,194,7,font_small,1
    ld a, (game+message)
    ld b, a
    ld c, 3
    mlt bc
    push hl
    ld hl, messages
    add hl, bc
    ld de, (hl)
    pop hl
    call text_center
    ld hl, (game+combo)
    ld de, 0
    or a
    sbc hl, de
    jp z, draw_panels_done
    ld a, (game+combo+2)
    bit 7, a
    jp nz, draw_panels_done
    LABEL 232,209,combo_label,4
    ld bc, (game+combo)
    NUMBER 271,207,5
draw_panels_done:
    ld a, 1
    ld (panels), a
    ret

draw_frame:
    RECT 0,0,320,240,canvas
    CENTER 160,5,game_name,5,font_medium
    RECT 108,20,104,204,3
    RECT 110,22,100,200,0
    CENTER 160,230,frame_hint,4
    call draw_panels
    ld hl, cache
    ld de, cache+1
    ld bc, 199
    ld (hl), 255
    ldir
    ld a, 1
    ld (full), a
    ret

draw_title:
    RECT 0,0,320,240,canvas
    RECT 18,18,284,204,panel
    RECT 18,18,284,2,3
    PEN 43,43,title_colors,font_small,5
    ld de, title_letters
    ld a, 8
    ld (title_count), a
draw_title_letter:
    push hl
    call text
    pop hl
    inc de
    ld bc, 30
    add hl, bc
    ld a, (text_color)
    inc a
    cp title_colors+7
    jp nz, title_color_ok
    ld a, title_colors
title_color_ok:
    ld (text_color), a
    ld a, (title_count)
    dec a
    ld (title_count), a
    jp nz, draw_title_letter
    CENTER 160,95,marathon_label,4,font_medium
    RECT 74,119,172,28,2
    ld a, (game+start_level)
    ld de, level_1_label
    cp 1
    jp z, draw_title_level
    ld de, level_5_label
    cp 5
    jp z, draw_title_level
    ld de, level_10_label
draw_title_level:
    push de
    PEN 160,128,5,font_medium,1
    pop de
    call text_center
    CENTER 160,165,play_hint,6,font_medium
    CENTER 160,188,title_hint,4
    CENTER 160,208,brand_label,4,font_medium
    ld a, 1
    ld (full), a
    ret

draw_help:
    RECT 0,0,320,240,canvas
    CENTER 160,21,help_title,6,font_small,2
    CENTER 160,50,help_intro,4,font_medium
    ld hl, (draw_buffer)
    ld de, 76*320+24
    add hl, de
    ld de, help_lines
    ld ix, font_medium
    ld a, 1
    ld (text_scale), a
    ld b, 8
draw_help_line:
    push bc
    push hl
    ld a, 7
    ld (text_color), a
    call text
    inc de
    pop hl
    push hl
    ld bc, 112
    add hl, bc
    ld a, 5
    ld (text_color), a
    call text
    inc de
    pop hl
    ld bc, 17*320
    add hl, bc
    pop bc
    djnz draw_help_line
    CENTER 160,225,help_hint,4
    ld a, 1
    ld (full), a
    ret

draw_overlay:
    RECT 76,74,168,104,3
    RECT 78,76,164,100,panel
    ld a, (game+state)
    cp state_pause
    jp nz, draw_overlay_over
    CENTER 160,92,paused_label,6,font_small,2
    CENTER 160,127,resume_hint,5,font_medium
    CENTER 160,151,menu_hint,4
    jp draw_overlay_done
draw_overlay_over:
    CENTER 160,89,over_label,6,font_small,2
    LABEL 98,116,score_label,4,font_medium
    ld bc, (game+score)
    NUMBER 154,116,7
    CENTER 160,140,retry_hint,5,font_medium
    CENTER 160,159,menu_hint,4
draw_overlay_done:
    ld a, 1
    ld (full), a
    ret

invalidate:
    ld a, 255
    ld (last_state), a
    ld a, 1
    ld (game+dirty_ui), a
    ret

; a = flash colour of the clear and death animations, else 0
effect_phase:
    ld a, (game+state)
    cp state_clearing
    jp z, effect_phase_clear
    cp state_dying
    jp z, effect_phase_death
    xor a
    ret
effect_phase_clear:
    call effect_age
    ld de, clear_flash
    or a
    sbc hl, de
    ld a, 31
    ret c
    ld a, 29
    ret
effect_phase_death:
    call effect_age
    ld de, death_flash
    or a
    sbc hl, de
    ld a, 30
    ret c
    ld a, 29
    ret

render:
    ld a, (game+state)
    ld (render_state), a
    call effect_phase
    ld (render_phase), a
    ld a, (render_state)
    ld hl, last_state
    sub (hl)
    ld (render_changed), a
    jp nz, render_draw
    ld a, (game+dirty_ui)
    or a
    jp nz, render_draw
    ld a, (game+x)
    ld hl, last_x
    cp (hl)
    jp nz, render_draw
    ld a, (game+y)
    ld hl, last_y
    cp (hl)
    jp nz, render_draw
    ld a, (game+rot)
    ld hl, last_rot
    cp (hl)
    jp nz, render_draw
    ld a, (game+piece)
    ld hl, last_piece
    cp (hl)
    jp nz, render_draw
    ld hl, (game+pieces)
    ld de, (last_pieces)
    or a
    sbc hl, de
    jp nz, render_draw
    ld a, (render_phase)
    ld hl, last_phase
    cp (hl)
    ret z
render_draw:
    ld a, (render_state)
    cp state_title
    jp nz, render_help
    ld a, (game+dirty_ui)
    ld hl, render_changed
    or (hl)
    call nz, draw_title
    jp render_done
render_help:
    cp state_help
    jp nz, render_game
    ld a, (render_changed)
    or a
    call nz, draw_help
    jp render_done
render_game:
    ld a, (render_changed)
    or a
    jp z, render_same
    ld a, (last_state)
    cp state_title
    jp z, render_frame
    cp state_help
    jp z, render_frame
    cp state_pause
    jp z, render_frame
    cp state_over
    jp z, render_frame
    cp 255
    jp nz, render_same
render_frame:
    call draw_frame
render_same:
    ld a, (render_state)
    cp state_pause
    jp z, render_overlay
    cp state_over
    jp nz, render_board
render_overlay:
    ld a, (render_changed)
    or a
    call nz, draw_overlay
    jp render_done
render_board:
    ld a, (game+dirty_ui)
    or a
    call nz, draw_panels
    ld hl, game+board+200
    ld de, scene
    ld bc, 200
    ldir
    ld a, (render_state)
    cp state_clearing
    jp z, scene_clearing
    cp state_dying
    jp z, scene_dying
    cp state_play
    jp nz, scene_ready
    call ghost_y
    ld c, 64
    call scene_mark
    ld a, (game+y)
    ld c, 32
    call scene_mark
    jp scene_ready
scene_clearing:
    ld hl, game+rows+20
    ld de, scene
    ld b, 20
scene_clearing_row:
    ld a, (hl)
    or a
    jp z, scene_clearing_next
    push bc
    push hl
    ld a, (render_phase)
    ld b, 10
    ex de, hl
scene_clearing_cell:
    ld (hl), a
    inc hl
    djnz scene_clearing_cell
    ex de, hl
    pop hl
    pop bc
    jp scene_clearing_skip
scene_clearing_next:
    push hl
    ld hl, 10
    add hl, de
    ex de, hl
    pop hl
scene_clearing_skip:
    inc hl
    djnz scene_clearing_row
    jp scene_ready
scene_dying:
    ld a, (render_phase)
    ld c, a
    ld hl, scene
    ld b, 200
scene_dying_cell:
    ld a, (hl)
    or a
    jp z, scene_dying_next
    ld (hl), c
scene_dying_next:
    inc hl
    djnz scene_dying_cell
scene_ready:
    ld hl, scene
    ld de, cache
    ld c, 0
render_cell:
    ld a, (de)
    cp (hl)
    jp z, render_cell_next
    ld a, (hl)
    ld (de), a
    push bc
    push de
    push hl
    push af
    ld a, c
    call cell_offset
    ld de, (draw_buffer)
    add hl, de
    pop af
    call tile
    pop hl
    pop de
    pop bc
    ld a, (dirty_count)
    push hl
    ld hl, dirty
    push de
    ld de, 0
    ld e, a
    add hl, de
    pop de
    ld (hl), c
    pop hl
    inc a
    ld (dirty_count), a
    and 3
    call z, poll_keys
render_cell_next:
    inc hl
    inc de
    inc c
    ld a, c
    cp 200
    jp c, render_cell
render_done:
    ld a, (render_state)
    ld (last_state), a
    xor a
    ld (game+dirty_ui), a
    ld a, (game+x)
    ld (last_x), a
    ld a, (game+y)
    ld (last_y), a
    ld a, (game+rot)
    ld (last_rot), a
    ld a, (game+piece)
    ld (last_piece), a
    ld hl, (game+pieces)
    ld (last_pieces), hl
    ld a, (render_phase)
    ld (last_phase), a
    ret

; a = the row of the piece or its ghost, c = 32 for the piece, 64 for the ghost
scene_mark:
    sub 20
    ld e, a
    ld a, (game+x)
    ld d, a
    ld a, (game+piece)
    inc a
    or c
    ld (mark_value), a
    ld a, (game+rot)
    call shape_address
    ld b, 4
scene_mark_cell:
    ld a, (hl)
    ld c, a
    rrca
    rrca
    rrca
    rrca
    and 15
    add a, e
    cp 20
    jp nc, scene_mark_next
    push hl
    push de
    ld h, 10
    ld l, a
    mlt hl
    ld a, c
    and 15
    add a, d
    ld de, 0
    ld e, a
    add hl, de
    ld de, scene
    add hl, de
    ld a, (mark_value)
    ld (hl), a
    pop de
    pop hl
scene_mark_next:
    inc hl
    djnz scene_mark_cell
    ret

; Shows draw_buffer at the next LCD refresh, then brings the other buffer
; up to date by copying only what was drawn.
present:
    ld a, (full)
    ld hl, panels
    or (hl)
    ld hl, dirty_count
    or (hl)
    ret z
    ld hl, (draw_buffer)
    ld (lcd_base), hl
    ld a, 4
    ld (lcd_acknowledge), a
present_wait:
    ld a, (lcd_status)
    and 4
    jp nz, present_flip
    call poll_keys
    jp present_wait
present_flip:
    ld hl, (front_buffer)
    ld de, (draw_buffer)
    ld (front_buffer), de
    ld (draw_buffer), hl
    ld a, (full)
    or a
    jp z, present_panels
    ld hl, (front_buffer)
    ld de, (draw_buffer)
    ld a, 60
present_full:
    ld bc, 1280
    ldir
    call poll_keys
    dec a
    jp nz, present_full
    jp present_done
present_panels:
    ld a, (panels)
    or a
    jp z, present_tiles
    ld hl, (draw_buffer)
    ld de, 20*320+8
    add hl, de
    ex de, hl
    ld hl, (front_buffer)
    ld bc, 20*320+8
    add hl, bc
    ld a, 20
present_panel_row:
    push af
    push de
    push hl
    ld bc, 94
    ldir
    ld bc, 116
    add hl, bc
    ex de, hl
    add hl, bc
    ex de, hl
    ld bc, 94
    ldir
    pop hl
    pop de
    ld bc, 320
    add hl, bc
    ex de, hl
    add hl, bc
    ex de, hl
    pop af
    ld b, a
    and 3
    cp 3
    call z, poll_keys
    ld a, b
    inc a
    cp 224
    jp c, present_panel_row
present_tiles:
    ld a, (dirty_count)
    or a
    jp z, present_done
    ld b, a
    ld hl, dirty
present_tile:
    push bc
    push hl
    ld a, (hl)
    call cell_offset
    push hl
    ld de, (draw_buffer)
    add hl, de
    ex de, hl
    pop hl
    ld bc, (front_buffer)
    add hl, bc
    ld a, 10
present_tile_row:
    ld bc, 10
    ldir
    ld bc, 310
    add hl, bc
    ex de, hl
    add hl, bc
    ex de, hl
    dec a
    jp nz, present_tile_row
    call poll_keys
    pop hl
    inc hl
    pop bc
    djnz present_tile
present_done:
    xor a
    ld (full), a
    ld (panels), a
    ld (dirty_count), a
    ret

places: .d24 100000,10000,1000,100,10,1
messages: .d24 0,single_label,double_label,triple_label,quad_label,spin_label,mini_label,all_clear_label
front_buffer: .d24 0xD40000
draw_buffer: .d24 0xD52C00
last_state: .db 255

title_count: .db 0
game_name: .asciz "FOURFALL"
title_letters: .asciz "F", "O", "U", "R", "F", "A", "L", "L"
frame_hint: .asciz "MODE PAUSE    CLEAR MENU"
hold_label: .asciz "HOLD"
score_label: .asciz "SCORE"
level_label: .asciz "LEVEL"
lines_label: .asciz "LINES"
next_label: .asciz "NEXT"
best_label: .asciz "BEST"
combo_label: .asciz "COMBO"
single_label: .asciz "SINGLE"
double_label: .asciz "DOUBLE"
triple_label: .asciz "TRIPLE"
quad_label: .asciz "QUAD"
spin_label: .asciz "T-SPIN"
mini_label: .asciz "MINI"
all_clear_label: .asciz "ALL CLEAR"
marathon_label: .asciz "MARATHON"
level_1_label: .asciz "< LEVEL 1 >"
level_5_label: .asciz "< LEVEL 5 >"
level_10_label: .asciz "< LEVEL 10 >"
play_hint: .asciz "ENTER TO PLAY"
title_hint: .asciz "UP OR DOWN CONTROLS    CLEAR QUIT"
brand_label: .asciz "CALCPLEX"
help_title: .asciz "HOW TO PLAY"
help_intro: .asciz "FILL ROWS TO CLEAR THEM"
help_lines:
    .asciz "LEFT RIGHT", "MOVE"
    .asciz "DOWN", "SOFT DROP"
    .asciz "UP OR 2ND", "ROTATE RIGHT"
    .asciz "ALPHA", "ROTATE LEFT"
    .asciz "ENTER", "HARD DROP"
    .asciz "GRAPH", "HOLD PIECE"
    .asciz "MODE", "PAUSE"
    .asciz "CLEAR", "BACK TO MENU"
help_hint: .asciz "ENTER TO RETURN"
paused_label: .asciz "PAUSED"
resume_hint: .asciz "ENTER TO RESUME"
menu_hint: .asciz "CLEAR TO MENU"
over_label: .asciz "GAME OVER"
retry_hint: .asciz "ENTER TO RETRY"

.section .bss
cache: .ds 200
scene: .ds 200
dirty: .ds 200
dirty_count: .ds 1
full: .ds 1
panels: .ds 1
last_x: .ds 1
last_y: .ds 1
last_rot: .ds 1
last_piece: .ds 1
last_phase: .ds 1
last_pieces: .ds 3
render_state: .ds 1
render_phase: .ds 1
render_changed: .ds 1
rect_span: .ds 3
rect_color: .ds 1
rect_rows: .ds 1
text_scale: .ds 1
text_color: .ds 1
text_cursor: .ds 3
text_line: .ds 3
glyph_pointer: .ds 3
glyph_rows: .ds 1
number_text: .ds 8
number_started: .ds 1
preview_piece: .ds 1
preview_base: .ds 3
mark_value: .ds 1
.section .text
