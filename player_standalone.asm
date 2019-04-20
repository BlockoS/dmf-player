; Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. 
; See the accompanying LICENSE file for terms.
;;---------------------------------------------------------------------


; base time = time base
; time even / time odd = tick time 1 / tick time 2


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
_si         .ds 2
_vdc_reg    .ds 1
_vdc_ctrl   .ds 1
_vsync_cnt  .ds 1

player:
player.time_base         .ds 1
player.time_tick         .ds 2
player.pattern_rows      .ds 1
player.matrix_rows       .ds 1
player.instrument_count  .ds 1
player.wav               .ds 2
player.instruments       .ds 2
player.matrix            .ds 2
player.matrix_pos        .ds 1
player.chn               .ds 1
player.pattern.lo        .ds PSG_CHAN_COUNT
player.pattern.hi        .ds PSG_CHAN_COUNT
player.pattern_pos       .ds 1
player.ptr               .ds 2
player.current_time_tick .ds 2
player.rest              .ds PSG_CHAN_COUNT 

	.bss
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
RestEx             = $79 ; For values >= 128
Rest               = $80 ; For values between 0 and 127
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

    bra    .loop


;;---------------------------------------------------------------------
; name : load_song
; desc : Initialize player and load song
; in   : <_si Pointer to song data
; out  : 
;;---------------------------------------------------------------------
load_song:
    cly
@copy_header:
    lda    [_si], Y
    sta    player, Y
    iny
    cpy    #12
    bne    @copy_header
    
    lda    <player.matrix
    sta    <_si
    
    lda    <player.matrix+1
    sta    <_si+1

    clx
@set_pattern_ptr:
    lda    [_si] 
    sta    <player.pattern.lo, X

    lda    <_si
    clc
    adc    <player.matrix_rows
    sta    <_si
    lda    <_si+1
    adc    #$00
    sta    <_si+1

    lda    [_si] 
    sta    <player.pattern.hi, X

    lda    <_si
    clc
    adc    <player.matrix_rows
    sta    <_si
    lda    <_si+1
    adc    #$00
    sta    <_si+1

    stz    <player.pattern_pos
    
    inx
    cpx    #PSG_CHAN_COUNT
    bne    @set_pattern_ptr

    stz    <player.current_time_tick
    stz    <player.current_time_tick+1

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
    cmp   #$3f
    bcc  @fetch_pattern_data
    beq  @rest_ex
@rest_std:
        and    #$3f
        bra    @rest_store
@rest_ex:
        lda    [player.ptr], Y
        iny
@rest_store:
        ldx    <player.chn
        sta    <player.rest, X
        bra    @inc_ptr

@fetch_pattern_data
    pha 
    
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
    .dw extended_commands
    .dw set_speed_value2
    .dw set_wav
    .dw enable_noise_channel
    .dw set_LFO_mode
    .dw set_LFO_speed
    .dw enable_sample_output
    .dw set_volume
    .dw set_instrument
    .dw note_on
    .dw note_off

; [todo] params 
update_chan:
    lda    <player.current_time_tick
    beq    @l0
        dec    <player.current_time_tick
        rts
@l0:
    lda    <player.time_base
    sta    <player.current_time_tick

    inc    <player.pattern_pos
    
    lda    <player.current_time_tick+1
    beq    @l1
        dec    <player.current_time_tick+1
        rts
@l1:
    lda    <player.pattern_pos
    and    #$01
    tax
    lda    <player.time_tick, X
    sta    <player.current_time_tick+1

    ldx    <player.chn
    lda    <player.rest, X
    bne    @dec_rest
        lda    <player.pattern.lo, X
        sta    <player.ptr
        lda    <player.pattern.hi, X 
        sta    <player.ptr+1
        jsr    fetch_pattern
        ; [todo] carry set => inc matrix_index, fetch pattern pointer
        bcc    @test_todo
@l2:        bra    @l2
@test_todo:

        lda    <player.ptr
        sta    <player.pattern.lo, X
        lda    <player.ptr+1
        sta    <player.pattern.hi, X 
        rts
@dec_rest:
    dec    <player.rest, X
@end:
    rts

update_song:
    clx
@loop:
    phx
    stx    <player.chn
    jsr    update_chan
;[todo] update_chan
;[todo] update_note_fx
    plx
    inx
    cpx    #PSG_CHAN_COUNT
    bne    @loop

    rts

; [todo] load data
arpeggio:
arpeggio_speed:
portamento_up:
portamento_down:
portamento_to_note:
vibrato:
vibrato_mode:
vibrato_depth:
port_to_note_vol_slide:
vibrato_vol_slide:
tremolo:
panning:
set_speed_value1:
volume_slide:
position_jump:
retrig:
pattern_break:
extended_commands:
set_speed_value2:
set_wav:
enable_noise_channel:
set_LFO_mode:
set_LFO_speed:
enable_sample_output:
set_volume:
set_instrument:
note_on:
    lda    [player.ptr], Y
    iny
    ; [todo]
    rts
note_off:
    ; [todo]
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
