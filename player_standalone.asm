; Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. 
; See the accompanying LICENSE file for terms.
;;---------------------------------------------------------------------


; [todo] instruments


; VDC (Video Display Controller)
videoport    .equ $0000

video_reg    .equ  videoport
video_reg_l  .equ  video_reg
video_reg_h  .equ  video_reg+1

video_data   .equ  videoport+2
video_data_l .equ  video_data
video_data_h .equ  video_data+1

;;---------------------------------------------------------------------
; TIMER
timerport    .equ  $0C00
timer_cnt    .equ  timerport
timer_ctrl   .equ  timerport+1

;;---------------------------------------------------------------------
; IRQ ports
irqport      .equ  $1400
irq_disable  .equ  irqport+2
irq_status   .equ  irqport+3

;;---------------------------------------------------------------------
; PSG informations
psgport      .equ  $0800
psg_ch       .equ  psgport
psg_mainvol  .equ  psgport+1
psg_freq.lo  .equ  psgport+2
psg_freq.hi  .equ  psgport+3
psg_ctrl     .equ  psgport+4
psg_pan      .equ  psgport+5
psg_wavebuf  .equ  psgport+6
psg_noise    .equ  psgport+7
psg_lfoctrl  .equ  psgport+9
psg_lfofreq  .equ  psgport+8

PSG_CHAN_COUNT  .equ $06 ; channel count

;;---------------------------------------------------------------------
; PSG control register bit masks
PSG_CTRL_CHAN_ON        .equ %1000_0000 ; channel on (1), off(0)
PSG_CTRL_CHAN_OFF       .equ %0000_0000 ; channel on (1), off(0)
PSG_CTRL_WRITE_RESET    .equ %0100_0000 ; reset waveform write index to 0
PSG_CTRL_DDA_ON         .equ %1100_0000 ; dda output on(1), off(0)
PSG_CTRL_VOL_MASK       .equ %0001_1111 ; channel volume
PSG_CTRL_FULL_VOLUME    .equ %0011_1111 ; channel maximum volume (bit 5 is unused)

PSG_VOLUME_MAX = $1f ; Maximum volume value

    .zp
_al         .ds 1           ; [todo] add _al and _ah to player zp vars
_ah         .ds 1
_si         .ds 2
_vdc_reg    .ds 1
_vdc_ctrl   .ds 1
_vsync_cnt  .ds 1

player.chn                      .ds 1
player.pattern_pos              .ds 1
player.ptr                      .ds 2
player.rest                     .ds PSG_CHAN_COUNT 
player.flag                     .ds 1
player.current_time_tick        .ds 2
player.chn_flag                 .ds PSG_CHAN_COUNT
player.current_arpeggio_tick    .ds PSG_CHAN_COUNT

_note .ds 1

    .bss
player.infos:
player.time_base         .ds 1
player.time_tick         .ds 2
player.pattern_rows      .ds 1
player.matrix_rows       .ds 1
player.instrument_count  .ds 1
player.wav               .ds 2
player.instruments       .ds 2
player.matrix            .ds 2
player.matrix_pos        .ds 1
player.pattern.lo        .ds PSG_CHAN_COUNT
player.pattern.hi        .ds PSG_CHAN_COUNT
player.arpeggio_tick     .ds PSG_CHAN_COUNT
player.arpeggio_speed    .ds PSG_CHAN_COUNT

player.note.previous      .ds PSG_CHAN_COUNT
player.note               .ds PSG_CHAN_COUNT
player.volume             .ds PSG_CHAN_COUNT
player.arpeggio           .ds PSG_CHAN_COUNT
player.frequency.lo       .ds PSG_CHAN_COUNT
player.frequency.hi       .ds PSG_CHAN_COUNT
player.frequency.delta.lo .ds PSG_CHAN_COUNT
player.frequency.delta.hi .ds PSG_CHAN_COUNT
player.frequency.flag     .ds PSG_CHAN_COUNT   ; [todo] rename to player.fx.flag ?
player.frequency.speed    .ds PSG_CHAN_COUNT

player.wav_upload       .ds 1 ; tin
player.wav_upload.src   .ds 2
player.wav_upload.dst   .ds 2
player.wav_upload.len   .ds 2
player.wav_upload.rts   .ds 1 ; rts

;;---------------------------------------------------------------------
; Song effects.
Arpeggio           = $00
ArpeggioSpeed      = $01
PortamentoUp       = $02
PortamentoDown     = $03
PortamentoToNote   = $04
Vibrato            = $05
VibratoMode        = $06
VibratoDepth       = $07
PortToNoteVolSlide = $08
VibratoVolSlide    = $09
Tremolo            = $0a
Panning            = $0b
SetSpeedValue1     = $0c
VolumeSlide        = $0d
PositionJump       = $0e
Retrig             = $0f
PatternBreak       = $10
ExtendedCommands   = $11
SetSpeedValue2     = $12
SetWave            = $13
EnableNoiseChannel = $14
SetLFOMode         = $15
SetLFOSpeed        = $16
EnableSampleOutput = $17
SetVolume          = $18
SetInstrument      = $19
Note               = $1a ; Set note+octave
NoteOff            = $1b
RestEx             = $3f ; For values >= 64
Rest               = $40 ; For values between 0 and 63
;;---------------------------------------------------------------------

;----------------------------------------------------------------------
; Vector table
;----------------------------------------------------------------------
    .data
    .bank 0
    .org $FFF6

    .dw irq_2                    ; irq 2
    .dw irq_1                    ; irq 1
    .dw irq_timer                ; timer
    .dw irq_nmi                  ; nmi
    .dw irq_reset                ; reset

;----------------------------------------------------------------------
; IRQ Vectors
;----------------------------------------------------------------------
    .code
    .bank 0
	.org $E000

;----------------------------------------------------------------------
; IRQ 2
;----------------------------------------------------------------------
irq_2:
    rti

;----------------------------------------------------------------------
; IRQ 1
; HSync/VSync/VRAM DMA/etc...
;----------------------------------------------------------------------
irq_1:
    lda    video_reg             ; get VDC status register
    and    #%0010_0000
    beq    .no_vsync
	    inc    <_vsync_cnt	
.no_vsync:
    stz    video_reg
    rti

;----------------------------------------------------------------------
; CPU Timer.
;----------------------------------------------------------------------
irq_timer:
    rti

;----------------------------------------------------------------------
; NMI.
;----------------------------------------------------------------------
irq_nmi:
    rti

;----------------------------------------------------------------------
; Default VDC registers value.
;----------------------------------------------------------------------
vdcInitTable:
;       reg  low  hi
    .db $07, $00, $00 ; background x-scroll register
    .db $08, $00, $00 ; background y-scroll register
    .db $09, $10, $00 ; background map size
    .db $0A, $02, $02 ; horizontal period register
    .db $0B, $1F, $04 ; horizontal display register
    .db $0C, $02, $17 ; vertical sync register
    .db $0D, $DF, $00 ; vertical display register
    .db $0E, $0C, $00 ; vertical display position end register

;----------------------------------------------------------------------
; Reset.
; This routine is called when the console is powered on.
;----------------------------------------------------------------------
irq_reset:
    sei                         ; disable interrupts
    csh                         ; select the 7.16 MHz clock
    cld                         ; clear the decimal flag
    ldx    #$FF                 ; initialize the stack pointer
    txs
    lda    #$FF                 ; map the I/O bank in the first page
    tam    #0
    lda    #$F8                 ; and the RAM bank in the second page
    tam    #1
    stz    $2000                ; clear all the RAM
    tii    $2000,$2001,$1FFF

    lda    #%11111101
    sta    irq_disable
    stz    irq_status

    stz    timer_ctrl           ; disable timer

    st0    #$05                 ; set vdc control register
    st1    #$00                 ; disable vdc interupts
    st2    #$00                 ; sprite and bg are disabled

    lda    #low(vdcInitTable)   ; setup vdc
    sta    <_si
    lda    #high(vdcInitTable)
    sta    <_si+1

    cly
.l0:
        lda    [_si],Y
        sta    videoport
        iny
        lda    [_si],Y
        sta    video_data_l
        iny
        lda    [_si],Y
        sta    video_data_h
        iny
        cpy    #24
        bne    .l0

    lda    #%11111001
    sta    irq_disable
    stz    irq_status

    ; set vdc control register
    st0    #5
    ; enable bg, enable sprite, vertical blanking and scanline interrupt
    lda    #%11001100
    sta    <_vdc_ctrl
    sta    video_data_l
    st2    #$00

    clx
.l1:
    stx    psg_ch
    lda    #$ff
    sta    psg_mainvol
    sta    psg_pan

    inx
    cpx    #PSG_CHAN_COUNT
    bne    .l1

    lda    #bank(song)
    tam    #page(song)
    lda    #low(song)
    sta    <_si
    lda    #high(song)
    sta    <_si+1
    jsr    load_song

    cli

.loop:
    stz    <_vsync_cnt
@wait_vsync:
    lda    <_vsync_cnt
    beq    @wait_vsync

    jsr    update_song

    clx
@l0:
    stx    <player.chn
    jsr    update_psg

    inx
    cpx    #PSG_CHAN_COUNT
    bne    @l0

    bra    .loop


;;---------------------------------------------------------------------
; name : load_song
; desc : Initialize player and load song
; in   : <_si Pointer to song data
; out  : 
;;---------------------------------------------------------------------
load_song:
    lda    #$d3                 ; tin
    sta    player.wav_upload
    lda    #32
    sta    player.wav_upload.len
    stz    player.wav_upload.len+1
    lda    #$60                 ; rts
    sta    player.wav_upload.rts
    lda    #low(psg_wavebuf)
    sta    player.wav_upload.dst
    lda    #high(psg_wavebuf)
    sta    player.wav_upload.dst+1

    ; read song header
    cly
@copy_header:
    lda    [_si], Y
    sta    player.infos, Y
    iny
    cpy    #12
    bne    @copy_header
    
    stz    player.matrix_pos
    jsr    update_matrix

    ; setup PSG
    lda    #$ff
    sta psg_mainvol

    clx
@psg_init:
    stx    psg_ch
    cpx    #4
    bcc    @no_noise
        stz    psg_noise
@no_noise:

    lda    #$ff
    sta    psg_pan

    lda    #%01_0_00000
    sta    psg_ctrl

    stz    psg_ctrl
    
    lda    player.wav
    sta    player.wav_upload.src
    lda    player.wav+1
    sta    player.wav_upload.src+1
    jsr    player.wav_upload

    lda    #$1f
    sta    player.volume, X

    inx
    cpx    #PSG_CHAN_COUNT
    bne    @psg_init

    rts

update_matrix:
    lda    player.matrix_pos
    cmp    player.matrix_rows
    bne    @l0
        stz    player.matrix_pos
@l0:
    lda    player.matrix
    sta    <_si
    
    lda    player.matrix+1
    sta    <_si+1
    
    stz    player.pattern_pos

    ldy    player.matrix_pos
    clx
@set_pattern_ptr:
    lda    [_si], Y
    sta    player.pattern.lo, X

    lda    <_si
    clc
    adc    player.matrix_rows
    sta    <_si
    lda    <_si+1
    adc    #$00
    sta    <_si+1

    lda    [_si], Y
    sta    player.pattern.hi, X

    lda    <_si
    clc
    adc    player.matrix_rows
    sta    <_si
    lda    <_si+1
    adc    #$00
    sta    <_si+1
    
    stz    <player.rest, X
    
    lda    #1
    sta    player.arpeggio_speed, X
    sta    player.arpeggio_tick, X
    sta    <player.current_arpeggio_tick, X

    inx
    cpx    #PSG_CHAN_COUNT
    bne    @set_pattern_ptr

    lda    #1
    sta    <player.current_time_tick
    sta    <player.current_time_tick+1

    inc    player.matrix_pos

    rts

;;---------------------------------------------------------------------
; name : 
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
fetch_pattern:
    cly
@loop:    
    lda   [player.ptr], Y
    iny

    cmp   #$ff
    bne   @check_rest
        sec
        rts
@check_rest:
    cmp    #$80
    bcs    @fetch
    cmp    #$3f
    bcc    @fetch
    beq    @rest_ex
@rest_std:
        and    #$3f
        bra    @rest_store
@rest_ex:
        lda    [player.ptr], Y
        iny
@rest_store:
        ldx    <player.chn
        dec    a
        sta    <player.rest, X
        bra    @inc_ptr

@fetch
    pha 
    
    and   #$7f
    asl   A
    tax

    jsr   fetch_pattern_data

    pla 
    bpl    @loop

@inc_ptr:
    tya
    clc
    adc    <player.ptr
    sta    <player.ptr
    cla
    adc    <player.ptr+1
    sta    <player.ptr+1
    
    clc
    rts

fetch_pattern_data:
    jmp    [pattern_data_func, X]

pattern_data_func:
    .dw arpeggio
    .dw arpeggio_speed
    .dw portamento_up
    .dw portamento_down
    .dw portamento_to_note
    .dw vibrato
    .dw vibrato_mode
    .dw vibrato_depth
    .dw port_to_note_vol_slide
    .dw vibrato_vol_slide
    .dw tremolo
    .dw panning
    .dw set_speed_value1
    .dw volume_slide
    .dw position_jump
    .dw retrig
    .dw pattern_break
    .dw set_speed_value2
    .dw set_wav
    .dw enable_noise_channel
    .dw set_LFO_mode
    .dw set_LFO_speed
    .dw note_slide_up
    .dw note_slide_down
    .dw note_delay
    .dw sync_signal
    .dw fine_tune
    .dw global_fine_tune
    .dw set_sample_bank
    .dw set_volume
    .dw set_instrument
    .dw note_on
    .dw note_off

; [todo] params 
update_chan:
    ldx    <player.chn
    lda    <player.rest, X
    bne    @dec_rest
        lda    player.pattern.lo, X
        sta    <player.ptr
        lda    player.pattern.hi, X 
        sta    <player.ptr+1
        jsr    fetch_pattern
        bcc    @continue
            rts
@continue:
        ldx    <player.chn
        lda    <player.ptr
        sta    player.pattern.lo, X
        lda    <player.ptr+1
        sta    player.pattern.hi, X 
        rts
@dec_rest:
    dec    <player.rest, X
@end:
    clc
    rts

update_song:
    stz   <player.flag
    
    ;lda    <player.current_time_tick
    dec    <player.current_time_tick
    beq    @l0
    bmi    @l0
        ;dec    <player.current_time_tick
        rts
@l0:
    lda    player.time_base
    sta    <player.current_time_tick
    
    ;lda    <player.current_time_tick+1
    dec    <player.current_time_tick+1
    beq    @l1
    bmi    @l1
        ;dec    <player.current_time_tick+1
        rts
@l1:
    inc    <player.pattern_pos
   
    lda    <player.pattern_pos
    and    #$01
    tax
    lda    player.time_tick, X
    sta    <player.current_time_tick+1

    clx
@loop:
    stx    <player.chn
    stx    psg_ch
    jsr    update_chan
    bcc    @l2
        smb0    <player.flag
@l2:
    ldx    <player.chn
    inx
    cpx    #PSG_CHAN_COUNT
    bne    @loop

    bbr0   <player.flag, @l3
        jsr   update_matrix
        jsr   update_song
@l3:
    rts

update_psg:
    stx    <player.chn
    stx    psg_ch
    lda    <player.chn_flag, X
    sta    <_al

    lda    player.note, X
    sta    <_note

    lda    player.frequency.flag, X
    sta    <_ah
    beq    @no_portamento
        smb2   <_al

        bbr0   <_ah, @portamento.1
            clc
            lda    player.frequency.delta.lo, X
            adc    player.frequency.speed, X 
            sta    player.frequency.delta.lo, X
            lda    player.frequency.delta.hi, X
            adc    #$00
            sta    player.frequency.delta.hi, X
            bra    @no_portamento
@portamento.1:
        bbr1   <_ah, @portamento.2
            sec
            lda    player.frequency.delta.lo, X
            sbc    player.frequency.speed, X 
            sta    player.frequency.delta.lo, X
            lda    player.frequency.delta.hi, X
            sbc    #$00
            sta    player.frequency.delta.hi, X
            bra    @no_portamento
@portamento.2:
    bbr2   <_ah, @portamento.3
            clc
            lda    player.frequency.delta.lo, X
            adc    player.frequency.speed, X 
            sta    player.frequency.delta.lo, X
            lda    player.frequency.delta.hi, X
            adc    #$00
            sta    player.frequency.delta.hi, X
            bmi    @no_portamento
                stz    player.frequency.delta.lo, X
                stz    player.frequency.delta.hi, X
                rmb2   <_ah
            bra    @no_portamento
@portamento.3:
            sec
            lda    player.frequency.delta.lo, X
            sbc    player.frequency.speed, X 
            sta    player.frequency.delta.lo, X
            lda    player.frequency.delta.hi, X
            sbc    #$00
            sta    player.frequency.delta.hi, X
            bpl    @no_portamento
                stz    player.frequency.delta.lo, X
                stz    player.frequency.delta.hi, X
                rmb3   <_ah
@no_portamento:
    lda    <_ah
    sta    player.frequency.flag, X

    ldy    player.arpeggio, X
    beq    @no_arpeggio
        dec    player.arpeggio_tick, X
        bne    @no_arpeggio

        lda    player.arpeggio_speed, X
        sta    player.arpeggio_tick, X

        tya

        smb2   <_al
        ldy    <player.current_arpeggio_tick, X
        beq    @arpeggio.0
        dey
        beq   @arpeggio.1
@arpeggio.2:
            ldy    #$ff
            sty    <player.current_arpeggio_tick, X
            lsr    A
            lsr    A
            lsr    A
            lsr    A
@arpeggio.1:
        and    #$0f
        clc
        adc    <_note
        sta    <_note
; [todo] inc octave
@arpeggio.0
        inc    <player.current_arpeggio_tick, X
@no_arpeggio:

    bbr2   <_al, @l0
        rmb2   <_al
        bbs0   <_al, @noise
            ldy    <_note
            lda    freq_table.lo, Y
            clc
            adc    player.frequency.delta.lo, X
            sta    player.frequency.lo, X
            sta    psg_freq.lo
            lda    freq_table.hi, Y
            adc    player.frequency.delta.hi, X
            sta    player.frequency.hi, X
            sta    psg_freq.hi
            bra    @l0
@noise:
            lda    <_note
            and    #$0f
            tay
            lda    noise_table, Y 
            sta    psg_noise
@l0:
    bbr1   <_al, @l1
        rmb1    <_al
        lda    player.volume, X
        lsr    A
        lsr    A
        ora    #%10_0_00000
        sta    psg_ctrl
@l1:
    lda     <_al
    sta     <player.chn_flag, X

    rts

; [todo] load data
vibrato:
vibrato_mode:
vibrato_depth:
port_to_note_vol_slide:
vibrato_vol_slide:
tremolo:
set_speed_value1:
volume_slide:
retrig:
set_speed_value2:
set_LFO_mode:
set_LFO_speed:
note_slide_up:
note_slide_down:
note_delay:
sync_signal:
fine_tune:
global_fine_tune:
set_sample_bank:
set_instrument:
    lda    [player.ptr], Y
    iny
    rts

portamento_down:
    ldx    <player.chn
    lda    [player.ptr], Y
    sta    player.frequency.speed, X 
    beq    @l0
        lda    player.frequency.flag, X
        ora    #%0000_0001
        sta    player.frequency.flag, X
        iny
        rts
@l0:
        lda    player.frequency.flag, X
        and    #%1111_1110
        sta    player.frequency.flag, X
        iny
        rts

portamento_up:
    ldx    <player.chn
    lda    [player.ptr], Y
    sta    player.frequency.speed, X 
    beq    @l0
        lda    player.frequency.flag, X
        ora    #%0000_0010
        sta    player.frequency.flag, X
        iny
        rts
@l0:
        lda    player.frequency.flag, X
        and    #%1111_1101
        sta    player.frequency.flag, X
        iny
        rts

portamento_to_note:
    ldx    <player.chn
    lda    [player.ptr], Y
    sta    player.frequency.speed, X 
    beq    @skip
        ; check if we had a new note was triggered
        lda    <player.chn_flag, X
        bit    #%0000_0100
        beq    @skip
            iny
            phy

            lda    player.note.previous, X
            pha
            cmp    player.note, X
            beq    @skip
            
            lda    player.frequency.lo, X
            sta    <_al
            lda    player.frequency.hi, X
            sta    <_ah
            ora    <_al
            bne    @compute
                ldy    player.note.previous, X
                lda    freq_table.lo, Y
                sta    <_al
                lda    freq_table.hi, Y
                sta    <_ah
@compute:
            ldy    player.note, X
            sec
            lda    <_al
            sbc    freq_table.lo, Y
            sta    player.frequency.delta.lo, X
            lda    <_ah
            sbc    freq_table.hi, Y
            sta    player.frequency.delta.hi, X

            pla 
            cmp    player.note, X
            bcc    @l0
                lda    player.frequency.flag, X
                and    #%1111_0011
                ora    #%0000_0100
                sta    player.frequency.flag, X
            
                ply
                rts
@l0:
                lda    player.frequency.flag, X
                and    #%1111_0011
                ora    #%0000_1000
                sta    player.frequency.flag, X
                
                ply
                rts 
@skip:
    stz    player.frequency.lo, X
    stz    player.frequency.hi, X
    
    lda    player.frequency.flag, X
    and    #%1111_0011
    sta    player.frequency.flag, X
    
    iny
    rts

arpeggio_speed:
    lda    [player.ptr], Y
    iny
    ldx    <player.chn
    sta    player.arpeggio_speed, X
    rts

arpeggio:
    lda    [player.ptr], Y
    iny
    ldx    <player.chn
    sta    player.arpeggio, X
    lda    player.arpeggio_speed, X
    sta    player.arpeggio_tick, X
    stz    <player.current_arpeggio_tick, X
    rts

enable_noise_channel:
    ldx    <player.chn
    lda    <player.chn_flag, X
    and    #%1111_1110 
    ora    [player.ptr], Y
    iny

    sta    <player.chn_flag, X 
    rts

panning:
    lda    [player.ptr], Y
    sta    psg_pan
    iny
    rts

set_volume:
    lda    [player.ptr], Y
    iny
    ldx    <player.chn
    sta    player.volume, X
    
    lda    <player.chn_flag, X
    ora    #%0000_0010
    sta    <player.chn_flag, X 
    
    rts

set_wav:
    ; Reset write index
    lda    #%01_0_00000
    sta    psg_ctrl

    ; Enable write buffer
    stz    psg_ctrl
    
    ; Copy wave buffer
    lda    [player.ptr], Y
    iny
    
    stz    <_si
    
    lsr    A
    ror    <_si
    
    lsr    A
    ror    <_si
    
    lsr    A
    ror    <_si
    sta    <_si+1
    
    lda    player.wav
    clc
    adc    <_si
    sta    player.wav_upload.src
    lda    player.wav+1
    adc    <_si+1
    sta    player.wav_upload.src+1

    jsr    player.wav_upload

    lda    #%01_0_00000
    sta    psg_ctrl

    ; Restore channel volume
    ldx    <player.chn
    lda    player.volume, X
    lsr    A
    lsr    A
    ora    #%10_0_00000
    sta    psg_ctrl
    
    rts

note_on:
    ldx    <player.chn
    lda    player.note, X
    sta    player.note.previous, X

    lda    [player.ptr], Y
    sta    player.note, X
    iny
    
    lda    <player.chn_flag, X
    ora    #%0000_0100
    sta    <player.chn_flag, X 
   
    lda    player.frequency.flag, X
    bit    #%0000_1100
    bne    @l0
        stz    player.frequency.delta.lo, X
        stz    player.frequency.delta.hi, X
@l0:
    rts

note_off:
    stz    psg_ctrl
    rts

pattern_break:
    ;  ignored for now
    iny
    rts

position_jump:
    lda    [player.ptr], Y
    iny
    sta    player.matrix_pos
    smb0   <player.flag
    rts

    .data
    .bank 1
	.org $4000

; [todo::begin] dummy song
song:
    .include "song.asm"
song.size = * - song
; [todo::end] dummy song
    .include "frequency.inc"
