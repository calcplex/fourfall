; hl = seed
game_init:
    push hl
    ld hl, game
    ld de, game+1
    ld bc, game_size-1
    ld (hl), 0
    ldir
    pop hl
    call store_seed
    ld a, 1
    ld (game+start_level), a
    ld (game+dirty_ui), a
    ret

; Stores hl as the random seed. Zero would stick, so it is replaced.
store_seed:
    ld de, 0
    or a
    sbc hl, de
    jp nz, store_seed_nonzero
    ld hl, 0x725943
store_seed_nonzero:
    ld (game+seed), hl
    ret

; 24-bit xorshift; a = low byte of the new seed
random_value:
    ld hl, (game+seed)
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld (random_shift), hl
    ld hl, game+seed
    ld de, random_shift
    ld b, 3
random_xor:
    ld a, (de)
    xor (hl)
    ld (hl), a
    inc hl
    inc de
    djnz random_xor
    ld a, (game+seed+2)
    srl a
    ld b, a
    ld a, (game+seed+1)
    rra
    ld hl, game+seed
    xor (hl)
    ld (hl), a
    inc hl
    ld a, b
    xor (hl)
    ld (hl), a
    ld a, (game+seed+1)
    inc hl
    xor (hl)
    ld (hl), a
    ld a, (game+seed)
    dec hl
    xor (hl)
    ld (hl), a
    ld hl, (game+seed)
    call store_seed
    ld a, (game+seed)
    ret

; a = next piece from a shuffled bag of all seven
take_piece:
    ld a, (game+bagpos)
    cp 7
    jp c, take_from_bag
    ld hl, game+bag
    xor a
fill_bag:
    ld (hl), a
    inc hl
    inc a
    cp 7
    jp nz, fill_bag
    ld a, 6
shuffle_bag:
    ld (shuffle_index), a
    inc a
    ld (shuffle_span), a
    ld hl, 256
    ld bc, 0
    ld c, a
    call divide
    ld a, (shuffle_span)
    call multiply
    ld (shuffle_limit), hl
shuffle_draw:
    call random_value
    ld de, 0
    ld e, a
    ld hl, (shuffle_limit)
    or a
    sbc hl, de
    jp c, shuffle_draw
    jp z, shuffle_draw
    ld a, e
    ld hl, shuffle_span
shuffle_reduce:
    cp (hl)
    jp c, shuffle_swap
    sub (hl)
    jp shuffle_reduce
shuffle_swap:
    ld bc, 0
    ld c, a
    ld hl, game+bag
    add hl, bc
    ex de, hl
    ld a, (shuffle_index)
    ld c, a
    ld hl, game+bag
    add hl, bc
    ld a, (de)
    ld c, (hl)
    ld (hl), a
    ld a, c
    ld (de), a
    ld a, (shuffle_index)
    dec a
    jp nz, shuffle_bag
    ld (game+bagpos), a
take_from_bag:
    ld hl, game+bag
    ld de, 0
    ld e, a
    add hl, de
    inc a
    ld (game+bagpos), a
    ld a, (hl)
    ret

; a = rotation; hl = the four cells of the current piece
shape_address:
    push bc
    ld c, a
    ld a, (game+piece)
    add a, a
    add a, a
    add a, c
    add a, a
    add a, a
    ld hl, shapes
    ld bc, 0
    ld c, a
    add hl, bc
    pop bc
    ret

; d = x, e = y, c = rotation of the current piece.
; a = 1 and nz if every cell is inside the well and empty, else a = 0 and z.
fits:
    push bc
    push de
    push hl
    ld a, c
    call shape_address
    ld b, 4
fits_cell:
    ld a, (hl)
    and 15
    add a, d
    cp 10
    jp nc, fits_blocked
    ld c, a
    ld a, (hl)
    rrca
    rrca
    rrca
    rrca
    and 15
    add a, e
    cp 40
    jp nc, fits_blocked
    push hl
    ld h, 10
    ld l, a
    mlt hl
    ld a, l
    add a, c
    ld l, a
    jp nc, fits_address
    inc h
fits_address:
    push de
    ld de, game+board
    add hl, de
    pop de
    ld a, (hl)
    pop hl
    or a
    jp nz, fits_blocked
    inc hl
    djnz fits_cell
    pop hl
    pop de
    pop bc
    ld a, 1
    or a
    ret
fits_blocked:
    pop hl
    pop de
    pop bc
    xor a
    ret

; Can the current piece move down a row?
fits_below:
    ld a, (game+x)
    ld d, a
    ld a, (game+y)
    inc a
    ld e, a
    ld a, (game+rot)
    ld c, a
    jp fits

; a = the piece to put at the top of the well
spawn:
    ld (game+piece), a
    xor a
    ld (game+rot), a
    ld (game+resets), a
    ld (game+grounded), a
    ld (game+rotated), a
    ld (game+kick), a
    ld a, 3
    ld (game+x), a
    ld a, 19
    ld (game+y), a
    ld hl, (game+now)
    ld (game+fall_at), hl
    ld (game+lock_at), hl
    ld (game+soft_at), hl
    ld a, 1
    ld (game+dirty_ui), a
    ld de, 3*256+19
    ld c, 0
    call fits
    jp z, die
    inc e
    call fits
    ret z
    ld a, 20
    ld (game+y), a
    ret

die:
    ld a, state_dying
    ld (game+state), a
    ld hl, (game+now)
    ld (game+effect_at), hl
    ld a, 1
    ld (game+dirty_ui), a
    ret

next_piece:
    ld a, (game+next)
    push af
    ld a, (game+next+1)
    ld (game+next), a
    ld a, (game+next+2)
    ld (game+next+1), a
    call take_piece
    ld (game+next+2), a
    xor a
    ld (game+used_hold), a
    pop af
    jp spawn

new_game:
    ld hl, game+seed
    ld de, game+now
    ld b, 3
new_seed:
    ld a, (de)
    xor (hl)
    ld (hl), a
    inc hl
    inc de
    djnz new_seed
    ld hl, (game+seed)
    call store_seed
    ld hl, game+board
    ld de, game+board+1
    ld bc, 399
    ld (hl), 0
    ldir
    ld a, 7
    ld (game+bagpos), a
    ld hl, 0
    ld (game+score), hl
    ld (game+lines), hl
    ld (game+pieces), hl
    ld (game+horizontal), hl
    ld (game+buffered), hl
    ld a, (game+start_level)
    ld (game+level), a
    ld a, 255
    ld (game+hold), a
    xor a
    ld (game+used_hold), a
    ld (game+b2b), a
    ld (game+message), a
    ld (game+allclear), a
    ld (game+cleared), a
    ld hl, 0xFFFFFF
    ld (game+combo), hl
    ld a, state_play
    ld (game+state), a
    call take_piece
    ld (game+next), a
    call take_piece
    ld (game+next+1), a
    call take_piece
    ld (game+next+2), a
    jp next_piece

; a = nonzero if the piece was resting on something before it moved
reset_lock:
    or a
    ret z
    ld a, (game+resets)
    cp 15
    ret nc
    inc a
    ld (game+resets), a
    ld hl, (game+now)
    ld (game+lock_at), hl
    ret

; d = dx, e = dy; nz if the piece moved
move_piece:
    ld a, d
    ld (move_dx), a
    ld a, e
    ld (move_dy), a
    ld a, (game+x)
    add a, d
    ld d, a
    ld a, (game+y)
    add a, e
    ld e, a
    ld a, (game+rot)
    ld c, a
    call fits
    ret z
    call fits_below
    xor 1
    ld (move_grounded), a
    ld a, (move_dx)
    ld hl, game+x
    add a, (hl)
    ld (hl), a
    ld a, (move_dy)
    ld hl, game+y
    add a, (hl)
    ld (hl), a
    xor a
    ld (game+rotated), a
    ld a, (move_dx)
    or a
    jp z, move_vertical
    ld a, (move_grounded)
    call reset_lock
move_vertical:
    ld a, (move_dy)
    dec a
    cp 127
    jp c, move_airborne
    call fits_below
    jp z, move_done
move_airborne:
    xor a
    ld (game+grounded), a
move_done:
    ld a, 1
    or a
    ret

; a = 1 clockwise or -1 counterclockwise; nz if the piece turned
rotate_piece:
    ld b, a
    ld a, (game+piece)
    cp 1
    jp z, rotate_failed
    ld a, (game+rot)
    add a, b
    and 3
    ld (rotate_to), a
    ld a, b
    cp 1
    jp nz, rotate_left
    ld a, (game+rot)
    add a, a
    jp rotate_row
rotate_left:
    ld a, (rotate_to)
    add a, a
    inc a
    and 7
rotate_row:
    ld c, a
    ld a, (game+piece)
    or a
    jp nz, rotate_table
    ld a, c
    add a, 8
    ld c, a
rotate_table:
    ld b, 10
    mlt bc
    ld hl, kicks
    add hl, bc
    ld (rotate_tests), hl
    call fits_below
    xor 1
    ld (rotate_grounded), a
    xor a
    ld (rotate_kick), a
rotate_try:
    ld hl, (rotate_tests)
    ld a, (game+x)
    add a, (hl)
    ld d, a
    inc hl
    ld a, (game+y)
    add a, (hl)
    ld e, a
    inc hl
    ld (rotate_tests), hl
    ld a, (rotate_to)
    ld c, a
    call fits
    jp nz, rotate_found
    ld a, (rotate_kick)
    inc a
    ld (rotate_kick), a
    cp 5
    jp c, rotate_try
rotate_failed:
    xor a
    ret
rotate_found:
    ld a, d
    ld (game+x), a
    ld a, e
    ld (game+y), a
    ld a, c
    ld (game+rot), a
    ld a, 1
    ld (game+rotated), a
    ld a, (rotate_kick)
    ld (game+kick), a
    ld a, (rotate_grounded)
    call reset_lock
    call fits_below
    jp z, rotate_done
    xor a
    ld (game+grounded), a
rotate_done:
    ld a, 1
    or a
    ret

; a = lowest row the current piece can fall to
ghost_y:
    ld a, (game+x)
    ld d, a
    ld a, (game+rot)
    ld c, a
    ld a, (game+y)
    ld e, a
ghost_down:
    inc e
    call fits
    jp nz, ghost_down
    dec e
    ld a, e
    ret

hold_piece:
    ld a, (game+used_hold)
    or a
    ret nz
    ld a, (game+piece)
    push af
    ld a, (game+hold)
    cp 255
    jp nz, hold_swap
    call next_piece
    jp hold_store
hold_swap:
    call spawn
hold_store:
    pop af
    ld (game+hold), a
    ld a, 1
    ld (game+used_hold), a
    ld (game+dirty_ui), a
    ret

; d = x, e = y; a = 1 if outside the well or filled
occupied:
    ld a, d
    cp 10
    jp nc, occupied_yes
    ld a, e
    cp 40
    jp nc, occupied_yes
    ld h, 10
    ld l, e
    mlt hl
    ld bc, 0
    ld c, d
    add hl, bc
    ld bc, game+board
    add hl, bc
    ld a, (hl)
    or a
    ret z
occupied_yes:
    ld a, 1
    ret

; a = 2 for a T-spin, 1 for a mini, 0 for neither
t_spin:
    ld a, (game+piece)
    cp 2
    jp nz, t_spin_none
    ld a, (game+rotated)
    or a
    jp z, t_spin_none
    ld a, (game+x)
    ld d, a
    ld a, (game+y)
    ld e, a
    call occupied
    ld (corners), a
    inc d
    inc d
    call occupied
    ld (corners+1), a
    inc e
    inc e
    call occupied
    ld (corners+2), a
    dec d
    dec d
    call occupied
    ld (corners+3), a
    ld hl, corners
    ld a, (hl)
    inc hl
    add a, (hl)
    inc hl
    add a, (hl)
    inc hl
    add a, (hl)
    cp 3
    jp c, t_spin_none
    ld a, (game+kick)
    cp 4
    jp z, t_spin_full
    ld bc, 0
    ld a, (game+rot)
    ld c, a
    ld hl, corners
    add hl, bc
    ld a, (hl)
    or a
    jp z, t_spin_mini
    ld a, (game+rot)
    inc a
    and 3
    ld c, a
    ld hl, corners
    add hl, bc
    ld a, (hl)
    or a
    jp z, t_spin_mini
t_spin_full:
    ld a, 2
    ret
t_spin_mini:
    ld a, 1
    ret
t_spin_none:
    xor a
    ret

; a = the message number for the spin just scored
spin_message:
    ld a, (game+spin)
    cp 2
    ld a, 5
    ret z
    inc a
    ret

lock_piece:
    call t_spin
    ld (game+spin), a
    ld a, (game+rot)
    call shape_address
    ld a, (game+piece)
    inc a
    ld (lock_value), a
    xor a
    ld (lock_visible), a
    ld b, 4
lock_cell:
    ld a, (hl)
    and 15
    ld c, a
    ld a, (game+x)
    add a, c
    ld c, a
    ld a, (hl)
    rrca
    rrca
    rrca
    rrca
    and 15
    ld d, a
    ld a, (game+y)
    add a, d
    bit 7, a
    jp nz, lock_hidden
    cp 20
    jp c, lock_hidden
    ld d, a
    ld a, 1
    ld (lock_visible), a
    ld a, d
lock_hidden:
    push hl
    ld h, 10
    ld l, a
    mlt hl
    ld de, 0
    ld e, c
    add hl, de
    ld de, game+board
    add hl, de
    ld a, (lock_value)
    ld (hl), a
    pop hl
    inc hl
    djnz lock_cell
    ld hl, (game+pieces)
    inc hl
    ld (game+pieces), hl
    ld a, (lock_visible)
    or a
    jp z, die
    xor a
    ld (game+cleared), a
    ld hl, game+board
    ld de, game+rows
    ld c, 40
lock_row:
    ld a, 1
    ld (de), a
    ld b, 10
lock_column:
    ld a, (hl)
    or a
    jp nz, lock_filled
    ld (de), a
lock_filled:
    inc hl
    djnz lock_column
    ld a, (de)
    push hl
    ld hl, game+cleared
    add a, (hl)
    ld (hl), a
    pop hl
    inc de
    dec c
    jp nz, lock_row
    ld a, (game+spin)
    ld b, a
    ld c, 5
    mlt bc
    ld a, (game+cleared)
    add a, c
    ld c, a
    ld b, 3
    mlt bc
    ld hl, points
    add hl, bc
    ld hl, (hl)
    ld (points_base), hl
    ld a, (game+cleared)
    or a
    jp z, lock_no_lines
    ld a, (game+spin)
    or a
    jp nz, lock_difficult
    ld a, (game+cleared)
    cp 4
    jp z, lock_difficult
    xor a
    jp lock_chain
lock_difficult:
    ld a, 1
lock_chain:
    ld c, a
    ld a, (game+b2b)
    or a
    jp z, lock_chain_set
    ld a, c
lock_chain_set:
    ld (game+chain_bonus), a
    or a
    jp z, lock_b2b
    ld hl, (points_base)
    ld de, (points_base)
    srl d
    rr e
    add hl, de
    ld (points_base), hl
lock_b2b:
    ld a, c
    ld (game+b2b), a
    ld hl, (game+combo)
    inc hl
    ld (game+combo), hl
    ld a, 50
    call multiply
    ld de, (points_base)
    add hl, de
    ld a, (game+level)
    call multiply
    call add_score
    ld a, (game+cleared)
    ld b, a
    ld a, (game+spin)
    or a
    ld a, b
    call nz, spin_message
    ld (game+message), a
    ld hl, (game+now)
    ld (game+message_at), hl
    ld (game+effect_at), hl
    ld a, state_clearing
    ld (game+state), a
    jp lock_done
lock_no_lines:
    ld hl, (points_base)
    ld a, (game+level)
    call multiply
    call add_score
    ld hl, 0xFFFFFF
    ld (game+combo), hl
    ld a, (game+spin)
    or a
    jp z, lock_next
    call spin_message
    ld (game+message), a
    ld hl, (game+now)
    ld (game+message_at), hl
lock_next:
    call next_piece
lock_done:
    ld a, 1
    ld (game+dirty_ui), a
    ret

; hl = points; the score stops at 999999
add_score:
    ex de, hl
    ld hl, 999999
    ld bc, (game+score)
    or a
    sbc hl, bc
    or a
    sbc hl, de
    jp nc, add_score_room
    ld hl, 999999
    jp add_score_store
add_score_room:
    ld hl, (game+score)
    add hl, de
add_score_store:
    ld (game+score), hl
    ld de, (game+best)
    or a
    sbc hl, de
    jp c, add_score_done
    jp z, add_score_done
    ld hl, (game+score)
    ld (game+best), hl
add_score_done:
    ld a, 1
    ld (game+dirty_ui), a
    ret

; Drops the rows marked full, then scores an all clear and spawns.
finish_clear:
    ld hl, game+board+390
    ld de, game+board+390
    ld ix, game+rows+39
    ld a, 40
finish_row:
    push af
    ld a, (ix)
    or a
    jp nz, finish_skip
    push hl
    ld bc, 10
    ldir
    pop hl
    ex de, hl
    ld bc, 20
    or a
    sbc hl, bc
    ex de, hl
finish_skip:
    ld bc, 10
    or a
    sbc hl, bc
    dec ix
    pop af
    dec a
    jp nz, finish_row
    ex de, hl
    ld bc, game+board-10
    or a
    sbc hl, bc
    jp z, finish_scan
    push hl
    pop bc
    dec bc
    ld hl, game+board
    ld de, game+board+1
    ld (hl), 0
    ldir
finish_scan:
    ld a, 1
    ld (game+allclear), a
    ld hl, game+board
    ld bc, 400
finish_scan_cell:
    ld a, (hl)
    or a
    jp nz, finish_not_clear
    inc hl
    dec bc
    ld a, b
    or c
    jp nz, finish_scan_cell
    ld a, (game+cleared)
    ld b, a
    ld c, 3
    mlt bc
    ld hl, all_clear_bonus
    add hl, bc
    ld hl, (hl)
    ld a, (game+cleared)
    cp 4
    jp nz, finish_bonus
    ld a, (game+chain_bonus)
    or a
    jp z, finish_bonus
    ld hl, 3200
finish_bonus:
    ld a, (game+level)
    call multiply
    call add_score
    ld a, 7
    ld (game+message), a
    jp finish_lines
finish_not_clear:
    xor a
    ld (game+allclear), a
finish_lines:
    ld hl, (game+lines)
    ld de, 0
    ld a, (game+cleared)
    ld e, a
    add hl, de
    ld (game+lines), hl
    ld bc, 10
    call divide
    ld de, 0
    ld a, (game+start_level)
    ld e, a
    add hl, de
    ld de, 16
    or a
    sbc hl, de
    add hl, de
    jp c, finish_level
    ld hl, 15
finish_level:
    ld a, l
    ld (game+level), a
    ld a, state_play
    ld (game+state), a
    call next_piece
    ld hl, (game+buffered)
    ld de, 0
    ld (game+buffered), de
    or a
    sbc hl, de
    ret z
    ld de, (game+held)
    ld bc, (game+now)
    jp game_input

; c = keys just pressed, b = keys held (low bytes)
set_horizontal:
    ld a, (game+horizontal)
    bit key_left, c
    jp z, horizontal_right
    ld a, 0xFF
horizontal_right:
    bit key_right, c
    jp z, horizontal_left_up
    ld a, 1
horizontal_left_up:
    cp 0xFF
    jp nz, horizontal_right_up
    bit key_left, b
    jp nz, horizontal_right_up
    xor a
    bit key_right, b
    jp z, horizontal_right_up
    ld a, 1
horizontal_right_up:
    cp 1
    jp nz, horizontal_compare
    bit key_right, b
    jp nz, horizontal_compare
    xor a
    bit key_left, b
    jp z, horizontal_compare
    ld a, 0xFF
horizontal_compare:
    ld hl, game+horizontal
    cp (hl)
    jp nz, horizontal_change
    ld d, a
    ld a, c
    and 3
    ret z
    ld a, d
horizontal_change:
    ld hl, 0xFFFFFF
    cp 0xFF
    jp z, horizontal_store
    ld hl, 0
    ld l, a
horizontal_store:
    ld (game+horizontal), hl
    ld hl, (game+now)
    ld (game+repeat_at), hl
    or a
    ret z
    ld d, a
    ld e, 0
    jp move_piece

; hl = keys just pressed, de = keys held, bc = time
game_input:
    ld (game+now), bc
    ld (input_pressed), hl
    ld (input_held), de
    bit key_clear, h
    jp z, input_state
    ld a, state_title
    ld (game+state), a
    jp input_changed
input_state:
    ld a, (game+state)
    cp state_title
    jp z, input_title
    cp state_help
    jp z, input_help
    cp state_over
    jp z, input_over
    cp state_dying
    ret z
    cp state_pause
    jp nz, input_pause
    ld a, (input_pressed)
    and 0x90
    jp nz, input_resume
    ld a, (input_pressed+1)
    bit key_mode, a
    jp nz, input_resume
    jp input_held_keys
input_pause:
    ld a, (input_pressed+1)
    bit key_mode, a
    jp z, input_held_keys
    ld a, (game+state)
    ld (game+previous_state), a
    ld a, state_pause
    ld (game+state), a
    ld hl, (game+now)
    ld (game+pause_at), hl
    jp input_changed
input_resume:
    ld hl, (game+now)
    ld de, (game+pause_at)
    or a
    sbc hl, de
    ex de, hl
    ld hl, (game+fall_at)
    add hl, de
    ld (game+fall_at), hl
    ld hl, (game+lock_at)
    add hl, de
    ld (game+lock_at), hl
    ld hl, (game+effect_at)
    add hl, de
    ld (game+effect_at), hl
    ld hl, (game+message_at)
    add hl, de
    ld (game+message_at), hl
    ld a, (game+previous_state)
    ld (game+state), a
    ld hl, (game+now)
    ld (game+repeat_at), hl
    ld (game+soft_at), hl
input_changed:
    ld a, 1
    ld (game+dirty_ui), a
    ret
input_title:
    ld a, (input_pressed)
    bit key_left, a
    jp z, input_title_right
    ld a, (game+start_level)
    cp 10
    ld a, 5
    jp z, input_title_left_level
    ld a, 1
input_title_left_level:
    ld (game+start_level), a
    ld a, 1
    ld (game+dirty_ui), a
input_title_right:
    ld a, (input_pressed)
    bit key_right, a
    jp z, input_title_help
    ld a, (game+start_level)
    cp 1
    ld a, 5
    jp z, input_title_right_level
    ld a, 10
input_title_right_level:
    ld (game+start_level), a
    ld a, 1
    ld (game+dirty_ui), a
input_title_help:
    ld a, (input_pressed)
    and 0x0C
    jp z, input_title_start
    ld a, state_help
    ld (game+state), a
    jp input_changed
input_title_start:
    ld a, (input_pressed)
    and 0x90
    ret z
    jp new_game
input_help:
    ld a, (input_pressed)
    and 0x9C
    ret z
    ld a, state_title
    ld (game+state), a
    jp input_changed
input_over:
    ld a, (input_pressed)
    and 0x90
    ret z
    ld hl, (game+now)
    ld de, (game+effect_at)
    or a
    sbc hl, de
    ld de, retry_delay
    or a
    sbc hl, de
    ret c
    jp new_game
input_held_keys:
    ld hl, (input_held)
    ld (game+held), hl
    ld a, (game+state)
    cp state_clearing
    jp nz, input_play
    ld a, (input_pressed)
    and 0x78
    ld hl, game+buffered
    or (hl)
    ld (hl), a
    ret
input_play:
    cp state_play
    ret nz
    ld a, (input_pressed)
    ld c, a
    ld a, (input_held)
    ld b, a
    call set_horizontal
    ld a, (input_pressed)
    bit key_graph, a
    call nz, hold_piece
    ld a, (game+state)
    cp state_play
    ret nz
    ld a, (input_pressed)
    and 0x18
    ld a, 1
    call nz, rotate_piece
    ld a, (input_pressed)
    bit key_alpha, a
    ld a, 0xFF
    call nz, rotate_piece
    ld a, (input_pressed)
    bit key_enter, a
    jp nz, input_drop
    ld a, (input_pressed+1)
    bit key_xtn, a
    jp nz, input_drop
    ld a, (input_pressed)
    bit key_down, a
    ret z
    ld de, 1
    call move_piece
    jp z, input_soft_timed
    ld hl, 1
    call add_score
input_soft_timed:
    ld hl, (game+now)
    ld (game+soft_at), hl
    ld (game+fall_at), hl
    ret
input_drop:
    call ghost_y
    ld hl, game+y
    sub (hl)
    jp z, input_drop_score
    ld c, a
    add a, (hl)
    ld (hl), a
    xor a
    ld (game+rotated), a
    ld a, c
input_drop_score:
    ld hl, 0
    ld l, a
    add hl, hl
    call add_score
    jp lock_piece

; hl = time since the current effect began
effect_age:
    ld hl, (game+now)
    ld de, (game+effect_at)
    or a
    sbc hl, de
    ret

; hl = time since the piece last fell
fall_age:
    ld hl, (game+now)
    ld de, (game+fall_at)
    or a
    sbc hl, de
    ret

; de = keys held, bc = time
game_update:
    ld (game+now), bc
    ld (game+held), de
    ld a, (game+state)
    cp state_dying
    jp nz, update_clearing
    call effect_age
    ld de, death_time
    or a
    sbc hl, de
    ret c
    ld a, state_over
    ld (game+state), a
    ld a, 1
    ld (game+dirty_ui), a
    ret
update_clearing:
    cp state_clearing
    jp nz, update_play
    call effect_age
    ld de, clear_time
    or a
    sbc hl, de
    ret c
    jp finish_clear
update_play:
    cp state_play
    ret nz
    ld a, (game+held)
    ld b, a
    ld c, 0
    call set_horizontal
    ld a, (game+horizontal)
    or a
    jp z, update_gravity
    ld hl, (game+now)
    ld de, (game+repeat_at)
    or a
    sbc hl, de
    ld de, das_delay
    or a
    sbc hl, de
    jp c, update_gravity
    ld a, (game+horizontal)
    ld d, a
    ld e, 0
    call move_piece
    ld hl, (game+now)
    ld de, das_repeat_back
    or a
    sbc hl, de
    ld (game+repeat_at), hl
update_gravity:
    ld a, (game+level)
    dec a
    ld b, a
    ld c, 3
    mlt bc
    ld hl, gravity
    add hl, bc
    ld hl, (hl)
    ld a, (game+held)
    bit key_down, a
    jp z, update_interval
    ld de, soft_interval+1
    or a
    sbc hl, de
    add hl, de
    jp c, update_interval
    ld hl, soft_interval
update_interval:
    ld (fall_interval), hl
    call fall_age
    ld de, (fall_interval)
    or a
    sbc hl, de
    jp c, update_ground
    xor a
    ld (fall_count), a
update_fall:
    ld hl, (game+fall_at)
    ld de, (fall_interval)
    add hl, de
    ld (game+fall_at), hl
    ld de, 1
    call move_piece
    jp z, update_fall_next
    ld a, (game+held)
    bit key_down, a
    jp z, update_fall_next
    ld hl, 1
    call add_score
update_fall_next:
    call fall_age
    ld de, (fall_interval)
    or a
    sbc hl, de
    jp c, update_ground
    ld a, (fall_count)
    inc a
    ld (fall_count), a
    cp 20
    jp c, update_fall
update_ground:
    call fits_below
    jp z, update_landed
    xor a
    ld (game+grounded), a
    jp update_message
update_landed:
    ld a, (game+grounded)
    or a
    jp nz, update_lock
    inc a
    ld (game+grounded), a
    ld a, (game+resets)
    cp 15
    jp nc, update_lock
    ld hl, (game+now)
    ld (game+lock_at), hl
update_lock:
    ld hl, (game+now)
    ld de, (game+lock_at)
    or a
    sbc hl, de
    ld de, lock_delay
    or a
    sbc hl, de
    call nc, lock_piece
update_message:
    ld a, (game+message)
    or a
    ret z
    ld hl, (game+now)
    ld de, (game+message_at)
    or a
    sbc hl, de
    ld de, message_time+1
    or a
    sbc hl, de
    ret c
    xor a
    ld (game+message), a
    inc a
    ld (game+dirty_ui), a
    ret

; Each cell packs its row in the upper nibble and its column in the lower.
shapes:
    .db 0x10,0x11,0x12,0x13, 0x02,0x12,0x22,0x32, 0x20,0x21,0x22,0x23, 0x01,0x11,0x21,0x31
    .db 0x01,0x02,0x11,0x12, 0x01,0x02,0x11,0x12, 0x01,0x02,0x11,0x12, 0x01,0x02,0x11,0x12
    .db 0x01,0x10,0x11,0x12, 0x01,0x11,0x12,0x21, 0x10,0x11,0x12,0x21, 0x01,0x10,0x11,0x21
    .db 0x01,0x02,0x10,0x11, 0x01,0x11,0x12,0x22, 0x11,0x12,0x20,0x21, 0x00,0x10,0x11,0x21
    .db 0x00,0x01,0x11,0x12, 0x02,0x11,0x12,0x21, 0x10,0x11,0x21,0x22, 0x01,0x10,0x11,0x20
    .db 0x00,0x10,0x11,0x12, 0x01,0x02,0x11,0x21, 0x10,0x11,0x12,0x22, 0x01,0x11,0x20,0x21
    .db 0x02,0x10,0x11,0x12, 0x01,0x11,0x21,0x22, 0x10,0x11,0x12,0x20, 0x00,0x01,0x11,0x21

; Five (x, y) tests per turn, rows 0R R0 R2 2R 2L L2 L0 0L; y grows downwards.
; The first eight rows are for J L S T Z, the last eight for I.
kicks:
    .db 0,0, -1,0, -1,-1, 0,2, -1,2
    .db 0,0, 1,0, 1,1, 0,-2, 1,-2
    .db 0,0, 1,0, 1,1, 0,-2, 1,-2
    .db 0,0, -1,0, -1,-1, 0,2, -1,2
    .db 0,0, 1,0, 1,-1, 0,2, 1,2
    .db 0,0, -1,0, -1,1, 0,-2, -1,-2
    .db 0,0, -1,0, -1,1, 0,-2, -1,-2
    .db 0,0, 1,0, 1,-1, 0,2, 1,2
    .db 0,0, -2,0, 1,0, -2,1, 1,-2
    .db 0,0, 2,0, -1,0, 2,-1, -1,2
    .db 0,0, -1,0, 2,0, -1,-2, 2,1
    .db 0,0, 1,0, -2,0, 1,2, -2,-1
    .db 0,0, 2,0, -1,0, 2,-1, -1,2
    .db 0,0, -2,0, 1,0, -2,1, 1,-2
    .db 0,0, 1,0, -2,0, 1,2, -2,-1
    .db 0,0, -1,0, 2,0, -1,-2, 2,1

; Ticks per row for levels 1 to 15.
gravity:
    .d24 32768,25985,20244,15490,11639,8585,6215,4415,3076,2102,1408,925,595,375,231

; Line clear points by spin (none, mini, T-spin) and rows cleared.
points:
    .d24 0,100,300,500,800
    .d24 100,200,400,0,0
    .d24 400,800,1200,1600,0

all_clear_bonus:
    .d24 0,800,1200,1800,2000

.section .bss
game: .ds game_size
input_pressed: .ds 3
input_held: .ds 3
random_shift: .ds 3
shuffle_index: .ds 1
shuffle_span: .ds 1
shuffle_limit: .ds 3
move_dx: .ds 1
move_dy: .ds 1
move_grounded: .ds 1
rotate_to: .ds 1
rotate_kick: .ds 1
rotate_grounded: .ds 1
rotate_tests: .ds 3
corners: .ds 4
lock_value: .ds 1
lock_visible: .ds 1
points_base: .ds 3
fall_interval: .ds 3
fall_count: .ds 1
.section .text
