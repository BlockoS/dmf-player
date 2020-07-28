; Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. 
; See the accompanying LICENSE file for terms.
;;-------_----------------------------------------------------------------------------------

; VDC (Video Display Controller)
videoport    .equ $0000

video_reg    .equ  videoport
video_reg_l  .equ  video_reg
video_reg_h  .equ  video_reg+1

video_data   .equ  videoport+2
video_data_l .equ  video_data
video_data_h .equ  video_data+1

;;---------------------------------------------------------------------
; VCE
colorport = $0400
color_ctrl = colorport

color_reg = colorport+2
color_reg_lo = color_reg
color_reg_hi = color_reg+1

color_data = colorport+4
color_data_lo = color_data
color_data_hi = color_data+1

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
_bl         .ds 1
_si         .ds 2
_vdc_reg    .ds 1
_vdc_status .ds 1
_vdc_ctrl   .ds 1
_vsync_cnt  .ds 1

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

    .include "task_manager.asm"
    .include "player.asm"
    .include "frequency.inc"

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
    sta    <_vdc_status

    bbr2   <_vdc_status, @check_vsync
@hsync:
;        jsr    dmf_pcm_update

;        st0    #$06
;        lda    <player.rcr
;        clc
;        adc    #$40
;        sta    video_data_l
;        cla
;        adc    #$00
;        sta    video_data_h
        
        bra    @end
@check_vsync:
    bbr5   <_vdc_status, @end
@vsync:
    ; [todo] grab P
    task.irq_install

    st0    #$06
    st1    #$40
    st2    #$00

    inc    <_vsync_cnt	
@end:
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
    .db $09, $00, $00 ; background map size
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

    ; clear bat
    st0    #$00
    st1    #$00
    st2    #$00

    st0    #$02
    ldy    #$20
@bat.y;
    ldx    #$20
@bat.x:
    st1    #$00
    st2    #$02
    dex
    bne    @bat.x
    dey
    bne    @bat.y

    ; set vdc control register
    st0    #5
    ; enable bg, enable sprite, vertical blanking
    lda    #%1100_1100
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

    jsr    dmf_init

    lda    #bank(song)              ; Change this if the song label changes (and it will most likely).
    sta    dmf.song.bank
    lda    #low(song)
    sta    dmf.song.ptr
    lda    #high(song)
    sta    dmf.song.ptr+1
    jsr    dmf_load_song


    lda    #low(dmf_commit)
    sta    <_si
    lda    #high(dmf_commit)
    sta    <_si+1
    jsr    task.add

    lda    #low(dmf_update)
    sta    <_si
    lda    #high(dmf_update)
    sta    <_si+1
    jsr    task.add

    cli
    
.loop:
    stz    <_vsync_cnt
@wait_vsync:
    lda    <_vsync_cnt
    beq    @wait_vsync
    bra    .loop

DMF_DATA_ROM_BANK = 1
; [todo::begin] dummy song
    .include "song.asm"
; [todo::end] dummy song

