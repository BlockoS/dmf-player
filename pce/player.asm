; Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. 
; See the accompanying LICENSE file for terms.
;;-------_----------------------------------------------------------------------------------

;;
;; Title: VDC Functions.
;;
    .zp
mul8.lo .ds 4
mul8.hi .ds 4

song.name   .ds 2
song.author .ds 2

player.chn                      .ds 1
player.pattern_pos              .ds 1
player.ptr                      .ds 2
player.rest                     .ds PSG_CHAN_COUNT 
player.flag                     .ds 1
player.current_time_tick        .ds 2
player.chn_flag                 .ds PSG_CHAN_COUNT
player.current_arpeggio_tick    .ds PSG_CHAN_COUNT
player.ax:
player.al                       .ds 1
player.ah                       .ds 1
player.si                       .ds 2
player.r0                       .ds 2
player.r1                       .ds 2
player.wave_upload.src          .ds 2
player.psg_ctrl                 .ds PSG_CHAN_COUNT 
player.delay                    .ds PSG_CHAN_COUNT 

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
player.volume.orig        .ds PSG_CHAN_COUNT
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

    .code
;;
;; function: mul8
;; 8 bits unsigned multiplication 16 bits result.
;;
;; Parameters:
;;  A - first operand
;;  Y - second operand
;;
;; Return:
;;  A - result MSB
;;  X - result LSB
;;
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

;;
;; function: wave_upload
;;
;; Parameters:
;;
;; Return:
;;
wave_upload:
    phy
    cly
    lda    player.volume, X
    lsr    A
    lsr    A
    ora    #$80
    pha
    sta    psg_ctrl

    stz    psg_ctrl
@l0:
    lda    [player.wave_upload.src], Y
    iny
    sta    psg_wavebuf
    cpy    #$20
    bne    @l0
    
    pla
    sta    psg_ctrl
    ply

    rts

;;
;; function: load_song
;; Initialize player and load song.
;;
;; Parameters:
;;  <_si - Pointer to song data
;;
;; Return:
;;
load_song:
    ; read song header
    cly
@copy_header:
    lda    [_si], Y
    sta    player.infos, Y
    iny
    cpy    #12
    bne    @copy_header

    tya
    clc
    adc    <_si
    sta    <song.name
    cla
    adc    <_si+1
    sta    <song.name+1

    lda    [_si], Y
    inc    A
    clc
    adc    <song.name
    sta    <song.author
    cla
    adc    <song.name+1
    sta    <song.author+1

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
    stz    <player.psg_ctrl, X

    stz    player.wave.id, X
    lda    player.wave
    sta    <player.wave_upload.src
    lda    player.wave+1
    sta    <player.wave_upload.src+1
    jsr    wave_upload

    lda    #$7c
    sta    player.volume, X
    sta    player.volume.orig, X
    stz    player.volume.delta, X

    inx
    cpx    #PSG_CHAN_COUNT
    bne    @psg_init

    rts

;;---------------------------------------------------------------------
; name : update_matrix
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
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
; name : fetch_pattern
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

;;---------------------------------------------------------------------
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

;;---------------------------------------------------------------------
; name : update_chan
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
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

;;---------------------------------------------------------------------
; name : update_song
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
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


;;---------------------------------------------------------------------
; name : update_psg
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
update_psg:
    ; Updating the psg control register for each channel seems to fix the wavetable gap/latency.
    ; This is at least how it seems to have been fixed in After Burner 2.
    clx
    stx    psg_ch
    lda    <player.psg_ctrl, X
    sta    psg_ctrl
    
    inx
    stx    psg_ch
    lda    <player.psg_ctrl, X
    sta    psg_ctrl
    
    inx
    stx    psg_ch
    lda    <player.psg_ctrl, X
    sta    psg_ctrl
    
    inx
    stx    psg_ch
    lda    <player.psg_ctrl, X
    sta    psg_ctrl
    
    inx
    stx    psg_ch
    lda    <player.psg_ctrl, X
    sta    psg_ctrl

    clx
    jsr    update_psg.ch
    ldx    #$01
    jsr    update_psg.ch
    ldx    #$02
    jsr    update_psg.ch
    ldx    #$03
    jsr    update_psg.ch
    ldx    #$04
    jsr    update_psg.ch
    ldx    #$05
    jmp    update_psg.ch

;;---------------------------------------------------------------------
; name : update_psg.ch
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
update_psg.ch:
    lda    <player.delay, X
    beq    @no_delay
        dec    <player.delay, X
        rts
@no_delay:
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
        ;smb1   <player.al
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
    bit    #%1000_0000 
    bne    @std.arp
@fixed.arp:
        ; [todo] We'll find a clever implementation later.
        ldy    player.instrument.arp.index, X
        lda    player.instrument.arp.lo, X
        sta    <player.si
        lda    player.instrument.arp.hi, X
        sta    <player.si+1
        lda    [player.si], Y        
        bra    @arp.store
@std.arp:
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
@arp.store:
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
    smb2   <player.al
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
        ldy    player.volume.orig, X
        phx
        jsr    mul8
        asl    A
        sta    <_volume
        plx
        sta    player.volume, X

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
                rmb2   <player.ah
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
            cmp    #$0c
            bcc    @freq.set
                lda    #$0c
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
            lsr    A
            lsr    A
            ora    #%10_0_00000
@skip:
        sta    <player.psg_ctrl, X
        sta    psg_ctrl
@l1:
   
    ; -- volume slide
    bbr3   <player.al, @no_volume_slide
        smb1   <player.al
        lda    player.volume, X
        clc
        adc    player.volume.delta, X
        bpl    @vol.plus
            cla
            rmb3   <player.al
            bra    @set_volume
@vol.plus:
        cmp    #$7c
        bcc    @set_volume
            lda    #$7c
            rmb3   <player.al
@set_volume:
        sta    player.volume, X
@no_volume_slide:
    
    lda     <player.al
    sta     <player.chn_flag, X

    rts

;;---------------------------------------------------------------------
; name : update_vibrato
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
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

;;---------------------------------------------------------------------
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
sync_signal:
fine_tune:
global_fine_tune:
set_sample_bank:
    lda    [player.ptr], Y
    iny
    rts

;;---------------------------------------------------------------------
; name : note_delay
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
note_delay:
    lda    <player.pattern_pos
    and    #$01
    tax
    
    lda    [player.ptr], Y
    iny

    cmp    player.time_tick, X
    bcs    @reset_delay
        ldx    <player.chn
        sta    <player.delay, X
        rts
@reset_delay:
        ldx    <player.chn
        stz    <player.delay, X
        rts

;;---------------------------------------------------------------------
; name : vibrato
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
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

;;---------------------------------------------------------------------
; name : volume_slide
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
volume_slide:
    ldx    <player.chn
    lda    [player.ptr], Y 
    sta    player.volume.delta, X
    bne    @l0
        lda    <player.chn_flag, X
        and    #%1111_0111
        sta    <player.chn_flag, X
        iny
        rts
@l0:
    lda    player.instrument.flag, X
    and    #%1111_1110
    sta    player.instrument.flag, X

    lda    <player.chn_flag, X
    ora    #%0000_1000
    sta    <player.chn_flag, X
    iny
    rts

;;---------------------------------------------------------------------
; name : set_instrument
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
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

    lda    [player.si]
    
    stz    player.instrument.vol.index, X
    stz    player.instrument.arp.index, X
    stz    player.instrument.wave.index, X

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

;;---------------------------------------------------------------------
; name : portamento_down
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
portamento_down:
    ldx    <player.chn
    lda    [player.ptr], Y
    sta    player.frequency.speed, X 
    beq    @l0
        lda    player.frequency.flag, X
        and    #%1111_1100
        ora    #%0000_0001
        sta    player.frequency.flag, X
        iny
        rts
@l0:
        lda    player.frequency.flag, X
        and    #%1111_1100
        sta    player.frequency.flag, X
        stz    player.frequency.delta.lo, X
        stz    player.frequency.delta.hi, X
        iny
        rts

;;---------------------------------------------------------------------
; name : portamento_up
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
portamento_up:
    ldx    <player.chn
    lda    [player.ptr], Y
    sta    player.frequency.speed, X 
    beq    @l0
        lda    player.frequency.flag, X
        and    #%1111_1100
        ora    #%0000_0010
        sta    player.frequency.flag, X
        iny
        rts
@l0:
        lda    player.frequency.flag, X
        and    #%1111_1100
        sta    player.frequency.flag, X
        stz    player.frequency.delta.lo, X
        stz    player.frequency.delta.hi, X
        iny
        rts

;;---------------------------------------------------------------------
; name : portamento_to_note
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
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

;;---------------------------------------------------------------------
; name : arpeggio_speed
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
arpeggio_speed:
    lda    [player.ptr], Y
    iny
    ldx    <player.chn
    sta    player.arpeggio_speed, X
    rts

;;---------------------------------------------------------------------
; name : arpeggio
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
arpeggio:
    lda    [player.ptr], Y
    iny
    ldx    <player.chn
    sta    player.arpeggio, X
    lda    player.arpeggio_speed, X
    sta    player.arpeggio_tick, X
    stz    <player.current_arpeggio_tick, X
    rts

;;---------------------------------------------------------------------
; name : enable_noise_channel
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
enable_noise_channel:
    ldx    <player.chn
    lda    <player.chn_flag, X
    and    #%1111_1110 
    ora    [player.ptr], Y
    sta    <player.chn_flag, X 
    bit    #$01
    bne    @end
        stz    psg_noise
@end:
    iny
    rts

;;---------------------------------------------------------------------
; name : panning
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
panning:
    lda    [player.ptr], Y
    sta    psg_pan
    iny
    rts

;;---------------------------------------------------------------------
; name : set_volume
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
set_volume:
    ldx    <player.chn
    lda    <player.chn_flag, X
    ora    #%0000_0110
    sta    <player.chn_flag, X 
    
    lda    [player.ptr], Y
    pha
    iny
    sta    player.volume.orig, X
    sta    player.volume, X
    
    pla
;    beq    note_off.2
    rts

;;---------------------------------------------------------------------
; name : note_off
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
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
    stz    <player.psg_ctrl, X
    stz    psg_ctrl 
    
    rts

;;---------------------------------------------------------------------
; name : set_wave
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
set_wave:
    ldx    <player.chn
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
        lda    player.volume, X
        lsr    A
        lsr    A
        ora    #%10_0_00000
        sta    <player.psg_ctrl, X
        sta    psg_ctrl
        rts
@mute:
    stz    <player.psg_ctrl, X
    stz    psg_ctrl
    rts

;;---------------------------------------------------------------------
; name : load_wave
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
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
    sta    <player.wave_upload.src
    lda    player.wave+1
    adc    <player.si+1
    sta    <player.wave_upload.src+1

    jsr    wave_upload
        
    rts

;;---------------------------------------------------------------------
; name : note_on
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
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

;;---------------------------------------------------------------------
; name : pattern_break
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
pattern_break:
    ;  data is ignored for now
    iny

    smb0   <player.flag
    rts

;;---------------------------------------------------------------------
; name : position_jump
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
position_jump:
    lda    [player.ptr], Y
    iny
    sta    player.matrix_pos
    smb0   <player.flag
    rts

;;---------------------------------------------------------------------
    ; Align to 256
    .org (* + $ff) & $ff00
    .include "mul.inc"
    .include "sin.inc"
player_end:
