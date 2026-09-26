; Reads the keypad and queues every new press with the keys held at that
; moment. Called often, even in the middle of drawing. Keeps all registers.
poll_keys:
    push af
    push bc
    push de
    push hl
    call read_timer
    push hl
    ld de, (last_poll)
    or a
    sbc hl, de
    ex de, hl
    ld hl, (last_poll)
    ld bc, 0
    or a
    sbc hl, bc
    jp z, poll_gap_done
    ld hl, (max_poll_gap)
    or a
    sbc hl, de
    jp nc, poll_gap_done
    ld (max_poll_gap), de
poll_gap_done:
    pop hl
    ld (last_poll), hl
    call read_keys
    ld (held_keys), hl
    ex de, hl
    ld hl, (previous)
    ld (previous), de
    ld a, l
    cpl
    and e
    ld c, a
    ld a, h
    cpl
    and d
    ld b, a
    or c
    jp z, poll_done
    ld hl, (input_count)
    inc hl
    ld (input_count), hl
    ld a, (head)
    inc a
    and 31
    ld l, a
    ld a, (tail)
    cp l
    jp nz, poll_queue
    ld hl, (input_overflow)
    inc hl
    ld (input_overflow), hl
    jp poll_done
poll_queue:
    ld a, (head)
    push hl
    ld l, a
    ld h, 6
    mlt hl
    push de
    ld de, events
    add hl, de
    pop de
    ld (hl), c
    inc hl
    ld (hl), b
    inc hl
    ld (hl), 0
    inc hl
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    ld (hl), 0
    pop hl
    ld a, l
    ld (head), a
poll_done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; nz with hl = keys pressed and de = keys held, or z if the queue is empty
next_event:
    ld a, (tail)
    ld l, a
    ld a, (head)
    cp l
    ret z
    ld a, l
    ld h, 6
    mlt hl
    ld de, events
    add hl, de
    push hl
    ld hl, (hl)
    ex (sp), hl
    inc hl
    inc hl
    inc hl
    ld de, (hl)
    ld a, (tail)
    inc a
    and 31
    ld (tail), a
    pop hl
    or 1
    ret

run_loop:
    call poll_keys
run_events:
    call next_event
    jp z, run_frame
    ld a, (game+state)
    cp state_title
    jp nz, run_input
    bit key_clear, h
    jp nz, run_quit
run_input:
    push hl
    call read_timer
    push hl
    pop bc
    pop hl
    call game_input
    jp run_events
run_frame:
    call read_timer
    push hl
    pop bc
    ld de, (held_keys)
    call game_update
    call read_timer
    ld (render_began), hl
    call render
    call present
    call read_timer
    ld de, (render_began)
    or a
    sbc hl, de
    ld (last_render), hl
    ld de, (max_render)
    or a
    sbc hl, de
    jp c, run_counted
    jp z, run_counted
    ld hl, (last_render)
    ld (max_render), hl
run_counted:
    ld hl, (frames)
    inc hl
    ld (frames), hl
    jp run_loop
run_quit:
    ld hl, (game+best)
    ld (saved_best), hl
    ld a, (game+start_level)
    ld (saved_level), a
    ret

app:
    call read_timer
    call game_init
    ld hl, (saved_best)
    ld (game+best), hl
    ld a, (saved_level)
    cp 1
    jp z, app_level
    cp 5
    jp z, app_level
    cp 10
    jp nz, app_ready
app_level:
    ld (game+start_level), a
app_ready:
    call poll_keys
    ld hl, (held_keys)
    ld (previous), hl
    ld a, (head)
    ld (tail), a
    call invalidate
    jp run_loop

.section .bss
held_keys: .ds 3
previous: .ds 3
input_count: .ds 3
input_overflow: .ds 3
last_poll: .ds 3
max_poll_gap: .ds 3
render_began: .ds 3
last_render: .ds 3
max_render: .ds 3
frames: .ds 3
head: .ds 1
tail: .ds 1
events: .ds 32*6
.section .text
