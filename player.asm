; Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
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

;;---------------------------------------------------------------------
; name : psg_set_chn
; desc : set psg channel
; in   : \1 channel
;;---------------------------------------------------------------------
    .macro psg_set_chn 
    lda    \1
    sta    psg_ch
    .endm

;;---------------------------------------------------------------------
; name : psg_set_master_vol
; desc : Set global volume.
; in   : \1 volume
;;---------------------------------------------------------------------
    .macro set_master_vol
    lda    \1
    sta    psg_mainvol
    .endm

;;---------------------------------------------------------------------
; name : psg_set_chn_vol
; desc : Set channel volume and activate it.
; in   : \1 channel
;        \2 volume
;;---------------------------------------------------------------------
    .macro psg_set_chn_vol
    lda    \1
    sta    psg_ctrl
.if (\?1 = ARG_IMMED)
    lda    #(PSG_CTRL_CHAN_ON | \2)
.else
    lda    \2
    ora    #PSG_CTRL_CHAN_ON
.endif
    sta    psg_ch
    .endm

;;---------------------------------------------------------------------
; name : psg_cpy_wav
; desc : Copy data to psg waveform buffer.
; in   : _si source address
; out  : nothing
;;---------------------------------------------------------------------
psg_cpy_wav:
    ; Enable write buffer
    stz    psg_ctrl
    ; Copy 32 bytes
    ; [todo] maybe completly unroll it
    cly
.copy_0:
    lda    [_si], Y
    sta    psg_wavebuf
    iny
    lda    [_si], Y
    sta    psg_wavebuf
    iny
    lda    [_si], Y
    sta    psg_wavebuf
    iny
    lda    [_si], Y
    sta    psg_wavebuf
    iny
    lda    [_si], Y
    sta    psg_wavebuf
    iny
    lda    [_si], Y
    sta    psg_wavebuf
    iny
    lda    [_si], Y
    sta    psg_wavebuf
    iny
    lda    [_si], Y
    sta    psg_wavebuf
    iny
    cpy    #32
    bne    .copy_0
    rts

play:
    lda    <_current_time_tick
    beq    .update_time_base:
        dec    <_current_time_tick
        rts
.update_time_base:
    lda    <_current_time_base
    beq    .update_internal
        dec    <_current_time_base
    ldx    <_time_tick_offset
    lda    <_time_tick, X
    sta    <_current_time_tick
.update_internal:
    lda    <_time_base
    sta    <_current_time_base

    lda    <_current_row
    and    #$01
    sta    <_time_tick_offset
    tax
    lda    <_time_tick, X
    sta    <_current_time_tick

    ldx    #PSG_CHAN_COUNT
    stx    <_current_chan
    
.chan_loop:
    lda    <_delay, X
    beq    .fetch
        dec    <_delay, X
        dex
        bne    .chan_loop
.fetch:
    inc    <_buffer.lo, X
    bne    .no_inc
        inc    <_buffer.hi, X
.no_inc:
    lda    <_buffer.lo, X
    sta    <_ptr
    lda    <_buffer.hi, X
    sta    <_ptr+1

    lda    [_ptr]
    pha
    
        ; Compute effect
    
    pla
    cmp    #$79
    bcs    .fetch
    
    and    #$7f
    sta    <_delay
    
    dex
    bne    .chan_loop
    
    rts

; base time = time base
; time even / time odd = tick time 1 / tick time 2

;-----------------------------------------------------------------------
; later...
; if vol slide, vol env = ignored
;       vol = note vol + (t/speed)*vol.slide
