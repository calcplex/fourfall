; hl = hl / bc, de = remainder (24-bit, unsigned)
divide:
    ex de, hl
    or a
    sbc hl, hl
    ld a, 24
divide_bit:
    ex de, hl
    add hl, hl
    ex de, hl
    adc hl, hl
    jp c, divide_overflow
    sbc hl, bc
    jp nc, divide_set
    add hl, bc
    jp divide_next
divide_overflow:
    or a
    sbc hl, bc
divide_set:
    inc de
divide_next:
    dec a
    jp nz, divide_bit
    ex de, hl
    ret

; hl = hl * a, keeping the low 24 bits
multiply:
    ex de, hl
    or a
    sbc hl, hl
    ld b, 8
multiply_bit:
    add hl, hl
    add a, a
    jp nc, multiply_next
    add hl, de
multiply_next:
    djnz multiply_bit
    ret
