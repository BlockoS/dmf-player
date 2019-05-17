; Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. 
; See the accompanying LICENSE file for terms.
;;-------_----------------------------------------------------------------------------------

; [todo] noise for "claude" : 83 84 BB BD BF

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

mul8.lo .ds 4
mul8.hi .ds 4

player.chn                      .ds 1
player.pattern_pos              .ds 1
player.ptr                      .ds 2
player.rest                     .ds PSG_CHAN_COUNT 
player.flag                     .ds 1
player.current_time_tick        .ds 2
player.chn_flag                 .ds PSG_CHAN_COUNT
player.current_arpeggio_tick    .ds PSG_CHAN_COUNT
player.ax:
player.ah                       .ds 1
player.al                       .ds 1
player.si                       .ds 2
player.r0                       .ds 2
player.r1                       .ds 2

_note   .ds 1
_volume .ds 1
_freq   .ds 2
    
    .bss
player.infos:
player.time_base         .ds 1
player.time_tick         .ds 2
player.pattern_rows      .ds 1
player.matrix_rows       .ds 1
player.instrument_count  .ds 1
player.wave              .ds 2
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
player.volume.delta       .ds PSG_CHAN_COUNT
player.arpeggio           .ds PSG_CHAN_COUNT
player.frequency.lo       .ds PSG_CHAN_COUNT
player.frequency.hi       .ds PSG_CHAN_COUNT
player.frequency.delta.lo .ds PSG_CHAN_COUNT
player.frequency.delta.hi .ds PSG_CHAN_COUNT
player.frequency.flag     .ds PSG_CHAN_COUNT   ; [todo] rename to player.fx.flag ?
player.frequency.speed    .ds PSG_CHAN_COUNT
player.vibrato            .ds PSG_CHAN_COUNT
player.vibrato.tick       .ds PSG_CHAN_COUNT

player.instrument.flag .ds PSG_CHAN_COUNT 

player.instrument.vol.size  .ds PSG_CHAN_COUNT
player.instrument.vol.loop  .ds PSG_CHAN_COUNT
player.instrument.vol.lo    .ds PSG_CHAN_COUNT
player.instrument.vol.hi    .ds PSG_CHAN_COUNT
player.instrument.vol.index .ds PSG_CHAN_COUNT

player.instrument.arp.size  .ds PSG_CHAN_COUNT
player.instrument.arp.loop  .ds PSG_CHAN_COUNT
player.instrument.arp.lo    .ds PSG_CHAN_COUNT
player.instrument.arp.hi    .ds PSG_CHAN_COUNT
player.instrument.arp.index .ds PSG_CHAN_COUNT

player.instrument.wave.size  .ds PSG_CHAN_COUNT
player.instrument.wave.loop  .ds PSG_CHAN_COUNT
player.instrument.wave.lo    .ds PSG_CHAN_COUNT
player.instrument.wave.hi    .ds PSG_CHAN_COUNT
player.instrument.wave.index .ds PSG_CHAN_COUNT

player.wave.id    .ds PSG_CHAN_COUNT

player.wave_upload       .ds 1 ; tin
player.wave_upload.src   .ds 2
player.wave_upload.dst   .ds 2
player.wave_upload.len   .ds 2
player.wave_upload.rts   .ds 1 ; rts

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

    lda    #high(sqr0.lo)
    sta    <mul8.lo+1
    lda    #high(sqr1.lo)
    sta    <mul8.lo+3
    lda    #high(sqr0.hi)
    sta    <mul8.hi+1
    lda    #high(sqr1.hi)
    sta    <mul8.hi+3

    lda    #bank(song)
    tam    #page(song)
    inc    A
    tam    #(page(song)+1)
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

mul8:
    sta    <mul8.lo
    sta    <mul8.hi
    eor    #$ff
    sta    <mul8.lo+2
    sta    <mul8.hi+2

    sec
    lda    [mul8.lo  ], Y
    sbc    [mul8.lo+2], Y
    tax
    lda    [mul8.hi  ], Y
    sbc    [mul8.hi+2], Y
    rts

;;---------------------------------------------------------------------
; name : load_song
; desc : Initialize player and load song
; in   : <_si Pointer to song data
; out  : 
;;---------------------------------------------------------------------
load_song:
    lda    #$d3                 ; tin
    sta    player.wave_upload
    lda    #32
    sta    player.wave_upload.len
    stz    player.wave_upload.len+1
    lda    #$60                 ; rts
    sta    player.wave_upload.rts
    lda    #low(psg_wavebuf)
    sta    player.wave_upload.dst
    lda    #high(psg_wavebuf)
    sta    player.wave_upload.dst+1

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
    
    stz    player.wave.id, X
    lda    player.wave
    sta    player.wave_upload.src
    lda    player.wave+1
    sta    player.wave_upload.src+1
    jsr    player.wave_upload

    lda    #$7c
    sta    player.volume, X
    stz    player.volume.delta, X

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
    sta    <player.si
    
    lda    player.matrix+1
    sta    <player.si+1
    
    stz    player.pattern_pos

    ldy    player.matrix_pos
    clx
@set_pattern_ptr:
    lda    [player.si], Y
    sta    player.pattern.lo, X

    lda    <player.si
    clc
    adc    player.matrix_rows
    sta    <player.si
    lda    <player.si+1
    adc    #$00
    sta    <player.si+1

    lda    [player.si], Y
    sta    player.pattern.hi, X

    lda    <player.si
    clc
    adc    player.matrix_rows
    sta    <player.si
    lda    <player.si+1
    adc    #$00
    sta    <player.si+1
    
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
    .dw set_wave
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
    sta    <player.al

    lda    player.note, X
    sta    <_note

    ; -- instrument wave
    lda    player.instrument.flag, X
    bit    #%0000_0100 
    beq    @no_wave

    ldy    player.instrument.wave.index, X
    lda    player.instrument.wave.lo, X
    sta    <player.si
    lda    player.instrument.wave.hi, X
    sta    <player.si+1
    lda    [player.si], Y
    
    cmp    player.wave.id, X
    beq    @load_wave.skip
        jsr    load_wave
@load_wave.skip:
    inc    player.instrument.wave.index, X
    lda    player.instrument.wave.index, X
    cmp    player.instrument.wave.size, X
    bcc    @no_wave.reset
        lda    player.instrument.wave.loop, X
        cmp    #$ff
        bne    @wave.reset
            lda    player.instrument.flag, X
            and    #%1111_1011
            sta    player.instrument.flag, X
            cla
@wave.reset:
        sta    player.instrument.wave.index, X
@no_wave.reset:
    ;smb2   <player.al
@no_wave:
    
    ; -- instrument arpeggio
    lda    player.instrument.flag, X
    bit    #%0000_0010 
    beq    @no_arp

    ldy    player.instrument.arp.index, X
    lda    player.instrument.arp.lo, X
    sta    <player.si
    lda    player.instrument.arp.hi, X
    sta    <player.si+1
    lda    [player.si], Y
    sec
    sbc    #$0C
    clc
    adc    <_note
    sta    <_note

    inc    player.instrument.arp.index, X
    lda    player.instrument.arp.index, X
    cmp    player.instrument.arp.size, X
    bcc    @no_arp.reset
        lda    player.instrument.arp.loop, X
        cmp    #$ff
        bne    @arp.reset
            lda    player.instrument.flag, X
            and    #%1111_1101
            sta    player.instrument.flag, X
            cla
@arp.reset:
        sta    player.instrument.arp.index, X
@no_arp.reset:
    ;smb2   <player.al
@no_arp:
    
    ; -- arpeggio
    ldy    player.arpeggio, X
    beq    @no_arpeggio
        dec    player.arpeggio_tick, X
        bne    @no_arpeggio

        lda    player.arpeggio_speed, X
        sta    player.arpeggio_tick, X

        tya

        smb2   <player.al
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
        adc    player.note, X
        sta    <_note
@arpeggio.0
        inc    <player.current_arpeggio_tick, X
@no_arpeggio:

    ; -- instrument volume
    lda    player.instrument.flag, X
    bit    #%0000_0001 
    beq    @std_volume
        ldy    player.instrument.vol.index, X
        lda    player.instrument.vol.lo, X
        sta    <player.si
        lda    player.instrument.vol.hi, X
        sta    <player.si+1
        lda    [player.si], Y
        inc    A
        ldy    player.volume, X
        phx
        jsr    mul8
        lsr    A
        sta    <_volume
        plx

        inc    player.instrument.vol.index, X
        lda    player.instrument.vol.index, X
        cmp    player.instrument.vol.size, X
        bcc    @no_volume.reset
            lda    player.instrument.vol.loop, X
            cmp    #$ff
            bne    @volume.reset
                lda    player.instrument.flag, X
                and    #%1111_1110
                sta    player.instrument.flag, X
                cla
@volume.reset:
            sta    player.instrument.vol.index, X
@no_volume.reset:
        smb1   <player.al
        bra    @no_volume
@std_volume:
    bbr1   <player.al, @no_volume
    lda    player.volume, X
    lsr    A
    lsr    A
    sta    <_volume
@no_volume:

    ; -- portamento
    lda    player.frequency.flag, X
    sta    <player.ah
    beq    @no_portamento
        smb2   <player.al

        bbr0   <player.ah, @portamento.1
            clc
            lda    player.frequency.delta.lo, X
            adc    player.frequency.speed, X 
            sta    player.frequency.delta.lo, X
            lda    player.frequency.delta.hi, X
            adc    #$00
            sta    player.frequency.delta.hi, X
            bra    @no_portamento
@portamento.1:
        bbr1   <player.ah, @portamento.2
            sec
            lda    player.frequency.delta.lo, X
            sbc    player.frequency.speed, X 
            sta    player.frequency.delta.lo, X
            lda    player.frequency.delta.hi, X
            sbc    #$00
            sta    player.frequency.delta.hi, X
            bra    @no_portamento
@portamento.2:
    bbr2   <player.ah, @portamento.3
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
                rmb2   <player.ah
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
                rmb3   <player.ah
@no_portamento:
    lda    <player.ah
    sta    player.frequency.flag, X
    
    lda    player.frequency.delta.lo, X
    sta    <_freq
    lda    player.frequency.delta.hi, X
    sta    <_freq+1

    ; -- vibrato
    bbr4   <player.al, @no_vibrato
        jsr    update_vibrato
@no_vibrato:

    ; -- set frequency
    bbr2   <player.al, @l0
        rmb2   <player.al
        bbs0   <player.al, @noise
            ldy    <_note
            lda    freq_table.lo, Y
            clc
            adc    <_freq
            sta    player.frequency.lo, X
            lda    freq_table.hi, Y
            adc    <_freq+1
            sta    player.frequency.hi, X
            bne    @check.lo
@check.hi:
            lda    player.frequency.lo, X
            cmp    #$16
            bcs    @freq.set
                lda    #$16
                sta    player.frequency.lo, X
                bra    @freq.delta.reset
@check.lo:
            cmp    #$1b
            bcc    @freq.set
                lda    #$1a
                sta    player.frequency.hi, X
                lda    #$ba
                sta    player.frequency.lo, X
@freq.delta.reset:
                sec
                sbc    freq_table.lo, Y
                sta    player.frequency.delta.lo, X
                lda    player.frequency.hi, X
                sbc    freq_table.hi, Y
                sta    player.frequency.delta.hi, X
@freq.set:
            lda    player.frequency.lo, X
            sta    psg_freq.lo
            lda    player.frequency.hi, X
            sta    psg_freq.hi
            bra    @l0
@noise:
            lda    <_note
            tay
            lda    noise_table, Y 
            sta    psg_noise
@l0:
    ; -- volume
    bbr1   <player.al, @l1
        rmb1    <player.al
        lda    <_volume
        beq    @skip
            ora    #%10_0_00000
@skip:
        sta    psg_ctrl
@l1:
    
    ; -- volume slide
    lda    player.volume, X
    bbr3   <player.al, @no_volume_slide
        smb1   <player.al
        clc
        adc    player.volume.delta, X
        bpl    @vol.plus
            cla
            rmb3   <player.al
            bra    @no_volume_slide
@vol.plus:
        cmp    #$7c
        bcc    @no_volume_slide
            lda    #$7c
            rmb3   <player.al
@no_volume_slide:
    sta    player.volume, X
    
    lda     <player.al
    sta     <player.chn_flag, X

    rts

update_vibrato:
    smb2   <player.al
    
    lda    player.vibrato, X
    and    #$0f
    pha
        
    lda    player.vibrato.tick, X
    asl    A
    asl    A
    tay
    
    lda    sin_table, Y
    sec
    sbc    #$10
    sta    <player.r1+1
    bpl    @plus
@neg:
    eor    #$ff
    inc    A
    pha 

    ldy    <_note
    lda    freq_table.lo-1, Y
    sec
    sbc    freq_table.lo, Y
    sta    <player.r0
    lda    freq_table.hi-1, Y
    sbc    freq_table.hi, Y
    sta    <player.r0+1
    bra    @go
@plus:
    pha

    ldy    <_note
    lda    freq_table.lo, Y
    sec
    sbc    freq_table.lo+1, Y
    sta    <player.r0
    lda    freq_table.hi, Y
    sbc    freq_table.hi+1, Y
    sta    <player.r0+1
@go:
    pla
    sta    <mul8.lo
    eor    #$ff
    sta    <mul8.lo+2

    ply
    sec
    lda    [mul8.lo  ], Y
    sbc    [mul8.lo+2], Y

    sta    <mul8.lo
    sta    <mul8.hi
    eor    #$ff
    sta    <mul8.lo+2
    sta    <mul8.hi+2

    ldy    <player.r0
    sec
    ;    lda    [mul8.lo  ], Y
    ;    sbc    [mul8.lo+2], Y           ; [todo] keep it?
    ;    tax
    lda    [mul8.hi  ], Y
    sbc    [mul8.hi+2], Y
    sta    <player.r0

    ldy    <player.r0+1
    sec
    lda    [mul8.lo  ], Y
    sbc    [mul8.lo+2], Y
    tax
    lda    [mul8.hi  ], Y
    sbc    [mul8.hi+2], Y
    
    sax
    clc
    adc    <player.r0
    sta    <player.r0
    sax
    adc    #0
    sta    <player.r0+1
    
    ldy    <player.r1+1
    bpl    @l0
@sub:
        eor    #$ff
        sax
        eor    #$ff
        sax
        inx
        bne    @l0
            inc   A
@l0:

    clc
    sax
    ldy    <player.chn
    clc
    adc    <_freq
    sta    <_freq
    sax
    adc    <_freq+1
    sta    <_freq+1
       
    lda    player.vibrato, Y
    lsr    A
    lsr    A
    lsr    A
    lsr    A
    clc
    adc    player.vibrato.tick, Y
    sta    player.vibrato.tick, Y
    
    sxy

    rts

; [todo] load data
vibrato_mode:
vibrato_depth:
port_to_note_vol_slide:
vibrato_vol_slide:
tremolo:
set_speed_value1:
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
    lda    [player.ptr], Y
    iny
    rts

vibrato:
    lda    [player.ptr], Y
    bne    @l0
        lda    <player.chn_flag, X
        and    #%1110_1111
        sta    <player.chn_flag, X

        iny
        rts
@l0:
    ldx    <player.chn
    sta    player.vibrato, X

    stz    player.vibrato.tick, X

    lda    <player.chn_flag, X
    ora    #%0001_0000
    sta    <player.chn_flag, X

    iny
    rts

volume_slide:
    lda    [player.ptr], Y
    iny
    
    ldx    <player.chn
    sta    player.volume.delta, X
    bne    @l0
        lda    <player.chn_flag, X
        and    #%1111_0111
        sta    <player.chn_flag, X
        rts
@l0:
    lda    player.instrument.flag, X
    and    #%1111_1110
    sta    player.instrument.flag, X

    lda    <player.chn_flag, X
    ora    #%0000_1000
    sta    <player.chn_flag, X
    rts

set_instrument:
    lda    [player.ptr], Y
    iny

    clc
    adc    player.instruments
    sta    <player.si
    cla
    adc    player.instruments+1
    sta    <player.si+1

    ldx    <player.chn
    
    lda    [player.si]
    sta    player.instrument.vol.size, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1

    lda    [player.si]
    sta    player.instrument.vol.loop, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1
    
    lda    [player.si]
    sta    player.instrument.vol.lo, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1
    
    lda    [player.si]
    sta    player.instrument.vol.hi, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1

    lda    [player.si]
    sta    player.instrument.arp.size, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1

    lda    [player.si]
    sta    player.instrument.arp.loop, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1
    
    lda    [player.si]
    sta    player.instrument.arp.lo, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1
    
    lda    [player.si]
    sta    player.instrument.arp.hi, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1
    
    lda    [player.si]
    sta    player.instrument.wave.size, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1

    lda    [player.si]
    sta    player.instrument.wave.loop, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1
    
    lda    [player.si]
    sta    player.instrument.wave.lo, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1
    
    lda    [player.si]
    sta    player.instrument.wave.hi, X
    lda    <player.si
    clc
    adc    player.instrument_count
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1

    stz    player.instrument.vol.index, X
    stz    player.instrument.arp.index, X
    stz    player.instrument.wave.index, X

    cla
    phy
    ldy    player.instrument.vol.size, X
    beq    @no_vol
        ora    #%0000_0001
@no_vol:
    ldy    player.instrument.arp.size, X
    beq    @no_arp
        ora    #%0000_0010
@no_arp:
    ldy    player.instrument.wave.size, X
    beq    @no_wave
        ora    #%0000_0100
@no_wave:
    sta    player.instrument.flag, X
    ply
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
            sta    <player.al
            lda    player.frequency.hi, X
            sta    <player.ah
            ora    <player.al
            bne    @compute
                ldy    player.note.previous, X
                lda    freq_table.lo, Y
                sta    <player.al
                lda    freq_table.hi, Y
                sta    <player.ah
@compute:
            ldy    player.note, X
            sec
            lda    <player.al
            sbc    freq_table.lo, Y
            sta    player.frequency.delta.lo, X
            lda    <player.ah
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
    ldx    <player.chn
    lda    <player.chn_flag, X
    ora    #%0000_0110
    sta    <player.chn_flag, X 
    
    lda    [player.ptr], Y
    pha
    iny
    sta    player.volume, X
    
    pla
    beq    note_off.2
    rts

note_off:
    ldx    <player.chn
    stz    player.arpeggio, X
    stz    player.vibrato, X
note_off.2:
    stz    <player.chn_flag, X
    stz    player.frequency.flag, X
    stz    player.instrument.vol.index, X
    stz    player.instrument.arp.index, X
    stz    player.frequency.delta.lo, X
    stz    player.frequency.delta.hi, X
    stz    psg_ctrl 
    
    rts

set_wave:
    ; Copy wave buffer
    lda    [player.ptr], Y
    iny

    cmp    player.wave.id, X
    beq    @skip
        jsr    load_wave
@skip:
    ; Restore channel volume
    lda    <player.chn_flag, X
    beq    @mute
        ldx    <player.chn
        lda    player.volume, X
        lsr    A
        lsr    A
        ora    #%10_0_00000
        sta    psg_ctrl
        rts
@mute:
    stz    psg_ctrl
    rts

load_wave:
    sta    player.wave.id, X
    stz    <player.si
    
    lsr    A
    ror    <player.si
    
    lsr    A
    ror    <player.si
    
    lsr    A
    ror    <player.si
    sta    <player.si+1
    
    lda    player.wave
    clc
    adc    <player.si
    sta    player.wave_upload.src
    lda    player.wave+1
    adc    <player.si+1
    sta    player.wave_upload.src+1

    ; Reset write index
    lda    #%01_0_00000

    sta    psg_ctrl

    ; Enable write buffer
    stz    psg_ctrl
    
    jsr    player.wave_upload

    lda    #%01_0_00000
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
    ora    #%0000_0110
    sta    <player.chn_flag, X 
  
    lda    player.frequency.flag, X
    bit    #%0000_1100
    bne    @l0
        stz    player.frequency.delta.lo, X
        stz    player.frequency.delta.hi, X
@l0:
    stz    player.instrument.vol.index, X
    stz    player.instrument.arp.index, X
    rts

pattern_break:
    ;  data is ignored for now
    iny

    smb0   <player.flag
    rts

position_jump:
    lda    [player.ptr], Y
    iny
    sta    player.matrix_pos
    smb0   <player.flag
    rts

    ; Align to 256
    .org (* + $ff) & $ff00
    .include "mul.inc"
    .include "sin.inc"
player_end:

    .data
    .bank 1
	.org $4000

; [todo::begin] dummy song
song:
    .include "song.asm"
song.size = * - song
; [todo::end] dummy song
    .include "frequency.inc"
