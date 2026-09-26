load_scores:
    call find_save
    ret z
    call validate_save
    ret nz
    inc hl
    inc hl
    inc hl
    inc hl
    ld de, saved_best
    ld bc, 3
    ldir
    ld a, (hl)
    cp 16
    ret nc
    ld (saved_level), a
    ret

find_save:
    ld iy, os_flags
    ld hl, save_archived
    push hl
    ld hl, save_name
    push hl
    call os_get_appvar
    pop bc
    pop bc
    ld de, 0
    or a
    sbc hl, de
    ret

validate_save:
    ld a, (hl)
    cp 8
    ret nz
    inc hl
    ld a, (hl)
    dec hl
    or a
    ret nz
    push hl
    inc hl
    inc hl
    ld de, save_magic
    ld b, 4
validate_magic:
    ld a, (de)
    cp (hl)
    jp nz, validate_failed
    inc hl
    inc de
    djnz validate_magic
    ld de, (hl)
    push hl
    ld hl, 1000000
    or a
    sbc hl, de
    pop hl
    jp c, validate_failed
    jp z, validate_failed
    pop hl
    inc hl
    inc hl
    xor a
    ret
validate_failed:
    pop hl
    ld a, 1
    or a
    ret

save_scores:
    call find_save
    jp z, create_save
    call validate_save
    ret nz
    ld a, (save_archived)
    or a
    jp z, write_save
    ld hl, 0
    push hl
    call os_memory_available
    pop bc
    ld de, 128
    or a
    sbc hl, de
    ret c
    ld hl, save_type
    call os_move_name_to_op1
    call os_archive_toggle
    call find_save
    ret z
    call validate_save
    ret nz
    jp write_save
create_save:
    ld hl, 8
    push hl
    ld hl, save_name
    push hl
    call os_create_appvar
    pop bc
    pop bc
    ld de, 0
    or a
    sbc hl, de
    ret z
    inc hl
    inc hl
write_save:
    ex de, hl
    ld hl, save_magic
    ld bc, 4
    ldir
    ld hl, saved_best
    ld bc, 3
    ldir
    ld a, (saved_level)
    ld (de), a
    ret

save_type: .db 0x15
save_name: .asciz "FOURDAT"
save_magic: .ascii "FOF1"
save_archived: .d24 0

saved_best: .d24 0
saved_level: .db 1
