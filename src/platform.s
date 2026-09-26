.equ vram, 0xD40000
.equ timer_count, 0xF20010
.equ keypad, 0xF50000
.equ arrows, 0xF5001E
.equ actions, 0xF5001C

platform_start:
    ld iy, os_flags
    call os_run_indicator_off
    call os_usb_timer_disable
    di
    ld a, (lcd_control)
    ld (saved_lcd), a
    ld hl, (lcd_base)
    ld (saved_base), hl
    ld hl, (timer_control)
    ld (saved_timers), hl
    ld hl, (keypad)
    ld (saved_keypad), hl
    ld hl, lcd_palette
    ld de, saved_palette
    ld bc, palette_bytes
    ldir
    ld hl, (timer_count)
    ld (saved_counter), hl
    ld a, (timer_count+3)
    ld (saved_counter+3), a
    ld hl, palette
    ld de, lcd_palette
    ld bc, palette_bytes
    ldir
    ld a, 0x27
    ld (lcd_control), a
    ld hl, vram
    ld (lcd_base), hl
    ld hl, 0
    ld (timer_count), hl
    ld a, l
    ld (timer_count+3), a
    ld hl, 0x418
    ld (timer_control), hl
    call scan_keys
    ld a, 3
    ld (keypad), a
    ret

platform_exit:
    call release_keys
    ld hl, 0
    ld (timer_control), hl
    ld hl, (saved_counter)
    ld (timer_count), hl
    ld a, (saved_counter+3)
    ld (timer_count+3), a
    ld hl, saved_palette
    ld de, lcd_palette
    ld bc, palette_bytes
    ldir
    ld hl, (saved_timers)
    ld (timer_control), hl
    ld hl, (saved_keypad)
    ld (keypad), hl
    ld a, (saved_lcd)
    ld (lcd_control), a
    ld hl, (saved_base)
    ld (lcd_base), hl
    ld iy, os_flags
    call os_usb_timer_reset
    set 0, (iy+3)
    set 1, (iy+0x0D)
    res 3, (iy+0x4A)
    res 5, (iy+0x4C)
    ld hl, vram
    ld de, vram+1
    ld bc, 153599
    ld (hl), 255
    ldir
    call os_clear_lcd
    call os_home
    call os_status_bar
    call save_scores
    ei
    ret

scan_keys:
    ld a, 2
    ld (keypad), a
scan_keys_wait:
    ld a, (keypad)
    and 3
    jp nz, scan_keys_wait
    ret

release_keys:
    call scan_keys
    ld a, (0xF50012)
    ld b, a
    ld a, (0xF50014)
    or b
    ld b, a
    ld a, (actions)
    or b
    ld b, a
    ld a, (arrows)
    or b
    jp nz, release_keys
    ret

; hl = ticks of the 32768 Hz timer. The count can change between the bytes
; of one read, so it is read twice until both reads agree.
read_timer:
    push de
read_timer_again:
    ld de, (timer_count)
    ld hl, (timer_count)
    or a
    sbc hl, de
    jp nz, read_timer_again
    ex de, hl
    pop de
    ret

; hl = keys held down, one bit each (see game.inc)
read_keys:
    ld hl, 0
    ld a, (arrows)
    bit 1, a
    jp z, read_right
    set key_left, l
read_right:
    bit 2, a
    jp z, read_down
    set key_right, l
read_down:
    bit 0, a
    jp z, read_up
    set key_down, l
read_up:
    bit 3, a
    jp z, read_second
    set key_up, l
read_second:
    ld a, (0xF50012)
    bit 5, a
    jp z, read_graph
    set key_2nd, l
read_graph:
    bit 0, a
    jp z, read_alpha
    set key_graph, l
read_alpha:
    ld a, (0xF50014)
    bit 7, a
    jp z, read_enter
    set key_alpha, l
read_enter:
    ld a, (actions)
    bit 0, a
    jp z, read_clear
    set key_enter, l
read_clear:
    bit 6, a
    jp z, read_mode
    set key_clear, h
read_mode:
    ld a, (0xF50012)
    bit 6, a
    jp z, read_xtn
    set key_mode, h
read_xtn:
    ld a, (0xF50016)
    bit 7, a
    ret z
    set key_xtn, h
    ret

saved_lcd: .db 0
saved_base: .ds 3
saved_timers: .ds 3
saved_keypad: .ds 3
saved_palette: .ds palette_bytes
saved_counter: .ds 4
