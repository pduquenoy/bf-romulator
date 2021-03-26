; ROMULATOR_PET_RAMTEST v2
; Tests full memory map using a memory test adapted from
; Jim Butterfield's 1977 article:
; http://archive.6502.org/publications/dr_dobbs_journal_selected_articles/high_speed_memory_test_for_6502.pdf
; The basic method is:
; 1. Value FF is stored in every location to be tested.
; 2. Value 00 is stored in every third location, giving a pattern of FF FF 00 FF FF 00 ...
; 3. Memory is checked for all values.
; repeat 3 times, shifting the position of the 00 each time.
; then repeat entire sequence, flipping FF and 00 values.
; Do this process once per memory page (256 bytes)

; this version uses ROMulator's memory mapped over the PET IO space
; during the test to hold results.

; set up addresses to hold test results

;test_address_start = $E800
;test_address_start = $8100
test_address_start = $8100
zero_page_compare_value                 =   test_address_start
alternating_counter                     =   test_address_start + 1
pass_count                              =   test_address_start + 2
flag_position_count                     =   test_address_start + 3
expected_value                          =   test_address_start + 4
read_value                              =   test_address_start + 5
page_counter                            =   test_address_start + 6
byte_counter                            =   test_address_start + 7
fault_indicator_address                 =   test_address_start + 8
done_indicator_address                  =   test_address_start + 9
temp_value                              =   test_address_start + 10
temp_value_2                            =   test_address_start + 11
text_table_start                        =   test_address_start + 12

read_address_low_byte                   =   $FB
read_address_high_byte                  =   $FC

ram_space_start                         =   $01
ram_space_end                           =   $7F

ram_test_mismatch_marker                =   $BB
ram_test_complete_marker                =   $CC
done_marker                             =   $DD

.segment    "CODE"

; check from 0x0000 to 0x8000
; standard RAM

createtexttable:
    ldy     #0
    lda     #$30    ; '0' character

storedigit:
    sta     text_table_start,Y
    tax
    inx
    txa
    iny
    cpy     #10
    beq     hexdigit
    cpy     #16
    beq     start
    jmp     storedigit

hexdigit:
    lda     #$41
    jmp     storedigit

start:
    ldy     #$00    ; load index
    sty     page_counter

clear_video_ram_page:
    lda     #$20
video_loop:
    sta     $8000,Y
    iny
    bne     video_loop

startpage:
    lda     #$FF    ; load flag value
    sta     zero_page_compare_value

init_flag_position:
    ; initialize flag position
    ; iterate through 3 offsets
    ldx     #$03
    stx     flag_position_count

begintestiteration:
    ldx     #$01
    stx     pass_count
    stx     alternating_counter

; write one page of memory
zeropagewrite:
    dex
    bne     zpcontinue  ; if not the right position, skip

    ; check what page we are on
    ; to determine addressing method
    ldx     page_counter
    bne     pagewriteflag

zpwriteflag:
    sta     $0000,Y
    jmp     writeflagend

pagewriteflag:
    sta     (read_address_low_byte),Y

writeflagend:
    ldx     alternating_counter

zpcontinue:
    iny
    bne     zeropagewrite

    ldx     pass_count
    beq     zeropagecomparestart
    dex
    stx     pass_count

    ; set up the flag position
    ldx     #$03
    stx     alternating_counter
    ldx     flag_position_count
    eor     #$FF
    jmp     zeropagewrite

zeropagecomparestart:
    lda     zero_page_compare_value     ; load the current value for comparison
    ldx     flag_position_count

zeropagecompare:
    ; compare each value
    dex                                 ; decrement alternating
    bne     no_flip
    eor     #$FF                        ;flip the flag
    
no_flip:
    sta     temp_value
    lda     page_counter
    beq     zpcompare

compare:
    lda     temp_value
    cmp     (read_address_low_byte),Y
    bne     fault
    jmp     donecompare

zpcompare:
    lda     temp_value
    cmp     $0000,Y
    bne     fault

donecompare:
    cpx     #$00
    bne     no_flip_2
    eor     #$FF
    ldx     alternating_counter

no_flip_2:
    jmp     nextzeropagecompare

nextzeropagecompare:
    iny
    bne     zeropagecompare

shiftflagposition:
    ldx     flag_position_count ; load current flag position
    dex
    beq     invert_flag
    stx     flag_position_count
    jmp     begintestiteration

invert_flag:
    lda     zero_page_compare_value
    beq     done_page ; if flag value is 0, we are done
    eor     #$FF
    sta     zero_page_compare_value
    jmp     init_flag_position

done_page:
    lda     page_counter
    cmp     #$02
    bcs     display_page
    
ready_next_page:
    ldx     page_counter
    cpx     #ram_space_end
    beq     done                ; done testing ram
    inx     ; increment page
    stx     page_counter
    stx     read_address_high_byte
    jmp     startpage

; printhex
; store value in A
; store offset in Y
display_page:
    ldy     #$00
    jsr     printhex
    ldy     #$00
    jmp     ready_next_page

done:
    lda     #done_marker
    sta     done_indicator_address
    sta     $8010

doneloop:
    nop
    jmp     doneloop    ; wait here

fault:
    sta     expected_value
    lda     page_counter
    beq     zpfault
pagefault:
    lda     (read_address_low_byte),Y
    jmp     showfault
zpfault:
    lda     $0000,Y
showfault:
    sty     temp_value_2
    ldy     #4
    jsr     printhex

    sta     read_value
    lda     #ram_test_mismatch_marker
    sta     fault_indicator_address

    ldy     temp_value_2
    sty     byte_counter

    tya
    ldy     #8
    jsr     printhex
    jmp     done

printhex:
    sty     temp_value
    tax
    lsr
    lsr
    lsr
    lsr
    tay
    lda     text_table_start,Y
    ldy     temp_value
    sta     $8000,Y
    inc     temp_value
    txa
    and     #$0F
    tay
    lda     text_table_start,Y
    ldy     temp_value
    sta     $8000,Y
    rts