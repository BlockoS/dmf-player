; Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. 
; See the accompanying LICENSE file for terms.
;;------------------------------------------------------------------------------------------

;;
;; Title: DMF player.
;;

; The song data will be mapped on banks 5 and 6
DMF_HEADER_MPR = 4
DMF_DATA_MPR = 5

DMF_HEADER_SIZE = 12

DMF_CHAN_COUNT = 6

;;------------------------------------------------------------------------------------------
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

;;------------------------------------------------------------------------------------------
    .zp
dmf.zp.begin:

mul8.lo .ds 4
mul8.hi .ds 4

                                                        ; [todo] player => dmf.player

player.si .ds 2
player.ax:
player.al .ds 1
player.ah .ds 1

player.ptr .ds 2

player.psg.main    .ds 1
player.psg.ctrl    .ds DMF_CHAN_COUNT 
player.psg.freq.lo .ds DMF_CHAN_COUNT
player.psg.freq.hi .ds DMF_CHAN_COUNT
player.psg.pan     .ds DMF_CHAN_COUNT

player.flag   .ds 1
player.note   .ds DMF_CHAN_COUNT
player.volume .ds DMF_CHAN_COUNT
player.rest   .ds DMF_CHAN_COUNT

; [todo] arpeggio, vibrato, etc...
; [todo] instrument states (volume, arpeggio, wave)

                                ; 0: backup of header mpr
player.mpr_backup .ds 2         ; 1: backup of data mpr
player.chn .ds 1                ; current psg channel

player.matrix.row .ds 1         ; current matrix row
player.tick .ds 2               ; current time tick (fine/coarse kinda sort off)

player.pattern.pos  .ds 1       ; current pattern position

player.samples.rate.lo       .ds 2 ; PCM sample rate (RCR offset LSB) 
player.samples.rate.hi       .ds 2 ; PCM sample rate (RCR offset MSB)
player.samples.offset.lo     .ds 2 ; PCM samples ROM offset (LSB)
player.samples.offset.hi     .ds 2 ; PCM samples ROM offset (MSB)
player.samples.bank          .ds 2 ; PCM samples ROM bank

dmf.zp.end:

;;------------------------------------------------------------------------------------------
    .bss
dmf.bss.begin:

dmf.song.bank   .ds 1
dmf.song.ptr    .ds 2
dmf.song.name   .ds 2
dmf.song.author .ds 2
dmf.song.infos:
dmf.song.time.base .ds 1
dmf.song.time.tick .ds 2
dmf.song.pattern.rows .ds 1
dmf.song.matrix.rows  .ds 1
dmf.song.instrument_count  .ds 1
dmf.song.wave              .ds 2
dmf.song.instruments       .ds 2
dmf.song.matrix            .ds 2

player.pattern.bank .ds DMF_CHAN_COUNT
player.pattern.lo   .ds DMF_CHAN_COUNT
player.pattern.hi   .ds DMF_CHAN_COUNT

dmf.bss.end:

;;------------------------------------------------------------------------------------------
    .code
;;
;; Function: dmf_init
;;   Initializes player internals.
;;
dmf_init:
    lda    #high(sqr0.lo)
    sta    <mul8.lo+1
    lda    #high(sqr1.lo)
    sta    <mul8.lo+3
    lda    #high(sqr0.hi)
    sta    <mul8.hi+1
    lda    #high(sqr1.hi)
    sta    <mul8.hi+3
    rts

;;
;; Function: mul8
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
;; Function: dmf_load_song
;; Initialize player and load song.
;;
;; Parameters:
;;  dmf.song.bank - Song data first bank
;;  dmf.song.ptr  - Pointer to song data
;;
;; Return:
;;
dmf_load_song:
    tma    #DMF_HEADER_MPR
    pha
    tma    #DMF_DATA_MPR
    pha
    
    lda    dmf.song.bank
    tam    #DMF_HEADER_MPR

    lda    dmf.song.ptr
    sta    <player.si

    lda    dmf.song.ptr+1
    and    #$1f
    ora    #DMF_HEADER_MPR<<5
    sta    <player.si+1

    bsr    @load_song

    pla
    tam    #DMF_DATA_MPR
    pla
    tam    #DMF_HEADER_MPR

    rts

;;
;; Function: @load_song
;; Initialize player and load song.
;; The song data rom is assumed to have already been mapped.
;;
;; Parameters:
;;  player.si - Pointer to song data
;;
;; Return:
;;
@load_song:
    ; read song header
    cly
@copy_header:
    lda    [player.si], Y
    sta    dmf.song.infos, Y
    iny
    cpy    #DMF_HEADER_SIZE
    bne    @copy_header

    ; save address to song name
    tya
    clc
    adc    <player.si
    sta    <player.si
    sta    dmf.song.name
    cla
    adc    <player.si+1
    sta    <player.si
    sta    dmf.song.name+1

    ; move to the song author
    lda    [player.si]          ; string length
    inc    A
    clc
    adc    <player.si
    sta    dmf.song.author
    cla
    adc    <player.si+1
    sta    dmf.song.author+1

    ; move to samples
    lda    [player.si]          ; string length
    inc    A
    clc
    adc    <player.si
    sta    <player.si
    cla
    adc    <player.si+1
    sta    <player.si+1

    lda    [player.si]          ; sample count
    sta    <player.al

    clc                         ; save pointer to sample rates (LSB)
    lda    <player.si
    adc    #$01
    sta    <player.samples.rate.lo
    tax
    lda    player.si+1
    adc    #$00
    sta    <player.samples.rate.lo+1

    clc                         ; samples ROM offset (LSB)
    sax
    adc    <player.al
    sta    <player.samples.offset.lo
    sax
    adc    #$00
    sta    <player.samples.offset.lo+1

    clc                         ; sample rate (MSB)
    sax
    adc    <player.al
    sta    <player.samples.rate.hi
    sax
    adc    #$00
    sta    <player.samples.rate.hi+1

    clc                         ; samples ROM offset (MSB)
    sax
    adc    <player.al
    sta    <player.samples.offset.hi
    sax
    adc    #$00
    sta    <player.samples.offset.hi+1

    clc                         ; samples ROM bank
    sax
    adc    <player.al
    sta    <player.samples.bank
    sax
    adc    #$00
    sta    <player.samples.bank+1

    ; initializes player
    stz    player.matrix.row
    jsr    dmf_update_matrix

    lda    #$ff
    sta    <player.psg.main

    clx
@player_init:
    stz    <player.psg.ctrl, X
    stz    <player.psg.freq.lo, X
    stz    <player.psg.freq.hi, X

    lda    #$ff
    sta    <player.psg.pan, X
    
    ; [todo] default player sate
    inx
    cpx    #DMF_CHAN_COUNT
    bne    @player_init

    rts

;;
;; Function: dmf_update_matrix
;;
;; Parameters:
;;
;; Return:
;;
dmf_update_matrix:
    lda    <player.matrix.row
    cmp    dmf.song.matrix.rows
    bne    @l0
        stz    <player.matrix.row
@l0:

    lda    dmf.song.matrix
    sta    <player.si    
    lda    dmf.song.matrix+1
    sta    <player.si+1
    
    stz    <player.pattern.pos

    ldy    <player.matrix.row
    clx
@set_pattern_ptr:
        lda    [player.si], Y
        sta    player.pattern.bank, X       ; pattern ROM bank

        clc
        lda    <player.si
        adc    dmf.song.matrix.rows
        sta    <player.si
        lda    <player.si+1
        adc    #$00
        sta    <player.si+1

        lda    [player.si], Y
        sta    player.pattern.lo, X         ; pattern ROM offset (LSB)

        clc
        lda    <player.si
        adc    dmf.song.matrix.rows
        sta    <player.si
        lda    <player.si+1
        adc    #$00
        sta    <player.si+1

        lda    [player.si], Y
        sta    player.pattern.hi, X         ; pattern ROM offset (MSB)

        lda    <player.si
        clc
        adc    dmf.song.matrix.rows
        sta    <player.si
        lda    <player.si+1
        adc    #$00
        sta    <player.si+1

        stz    <player.rest, X

; [todo] reset player state

        inx
        cpx    #DMF_CHAN_COUNT
        bne    @set_pattern_ptr

    lda    #1
    sta    <player.tick
    sta    <player.tick+1

    inc    <player.matrix.row

    rts

;;
;; Function: dmf_update
;; Song update.
;;
dmf_update:
    tma    #DMF_HEADER_MPR
    pha
    tma    #DMF_DATA_MPR
    pha
    
    lda    dmf.song.bank
    tam    #DMF_HEADER_MPR

    bsr    update_song
; [todo]    jsr    update_psg

    pla
    tam    #DMF_DATA_MPR
    pla
    tam    #DMF_HEADER_MPR
    
    rts

;;
;; Function: update_song
;;
;; Parameters:
;;
;; Return:
;;
update_song:                                        ; [todo] rename
    stz   <player.flag
    
    dec    <player.tick
    beq    @l0
    bmi    @l0
        ; Nothing to do here.
        ; Just go on and update player state.
        rts
@l0:
    ; Reset base tick.
    lda    dmf.song.time.base
    sta    <player.tick
    
    dec    <player.tick+1
    beq    @l1
    bmi    @l1
        ; Nothing to do here.
        rts
@l1:
    ; Fetch next pattern entry.
    inc    <player.pattern.pos
   
    ; 1. reset coarse timer tick.
    lda    <player.pattern.pos
    and    #$01
    tax
    lda    dmf.song.time.tick, X
    sta    <player.tick+1

    clx
@loop:
    stx    <player.chn
    bsr    update_chan                              ; [todo] name
    bcc    @l2
        smb0    <player.flag
@l2:
    inx
    cpx    #DMF_CHAN_COUNT
    bne    @loop

    bbs0   <player.flag, @l3
        rts
@l3:
    jsr   dmf_update_matrix
    jmp   update_song                               ; [todo] name

;;
;; Function: update_chan
;;
;; Parameters:
;;
;; Return:
;;
update_chan:                                        ; [todo] name
    ldx    <player.chn
    lda    <player.rest, X
    bne    @dec_rest
        lda    player.pattern.bank, X
        tam    #DMF_DATA_MPR
        lda    player.pattern.lo, X
        sta    <player.ptr
        lda    player.pattern.hi, X 
        sta    <player.ptr+1
        bsr    fetch_pattern                        ; [todo] name
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

;;
;; Function: fetch_pattern
;;
;; Parameters:
;;
;; Return:
;;
fetch_pattern:                                      ; [todo] name
    cly
@loop:    
    lda   [player.ptr], Y
    iny

    cmp   #$ff                      ; [todo] magic value
    bne   @check_rest
        sec
        rts
@check_rest:
    pha
    and    #$7f                     ; [todo] magic value
    cmp    #$3f                     ; [todo] magic value
    bcc    @fetch
    beq    @rest_ex
@rest_std:
        and    #$3f                 ; [todo] magic value
        bra    @rest_store
@rest_ex:
        lda    [player.ptr], Y
        iny
@rest_store:
        ldx    <player.chn
        dec    a
        sta    <player.rest, X
        pla
        bra    @inc_ptr
@fetch
    asl   A
    tax

    bsr   @fetch_pattern_data                ; [todo] make it local (if it's supported)

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

@fetch_pattern_data:
    jmp    [@pattern_data_func, X]

;;------------------------------------------------------------------------------------------
@pattern_data_func:
    .dw @arpeggio
    .dw @arpeggio_speed
    .dw @portamento_up
    .dw @portamento_down
    .dw @portamento_to_note
    .dw @vibrato
    .dw @vibrato_mode
    .dw @vibrato_depth
    .dw @port_to_note_vol_slide
    .dw @vibrato_vol_slide
    .dw @tremolo
    .dw @panning
    .dw @set_speed_value1
    .dw @volume_slide
    .dw @position_jump
    .dw @retrig
    .dw @pattern_break
    .dw @set_speed_value2
    .dw @set_wave
    .dw @enable_noise_channel
    .dw @set_LFO_mode
    .dw @set_LFO_speed
    .dw @note_slide_up
    .dw @note_slide_down
    .dw @note_delay
    .dw @sync_signal
    .dw @fine_tune
    .dw @global_fine_tune
    .dw @set_sample_bank
    .dw @set_volume
    .dw @set_instrument
    .dw @note_on
    .dw @note_off
    .dw @set_samples
;;------------------------------------------------------------------------------------------
@arpeggio:
@arpeggio_speed:
@portamento_up:
@portamento_down:
@portamento_to_note:
@vibrato:
@vibrato_mode:
@vibrato_depth:
@port_to_note_vol_slide:
@vibrato_vol_slide:
@tremolo:
@panning:
@set_speed_value1:
@volume_slide:
@position_jump:
@retrig:
@pattern_break:
@set_speed_value2:
@set_wave:
@enable_noise_channel:
@set_LFO_mode:
@set_LFO_speed:
@note_slide_up:
@note_slide_down:
@note_delay:
@sync_signal:
@fine_tune:
@global_fine_tune:
@set_sample_bank:
@set_volume:
@set_instrument:
@note_on:
@set_samples:
    lda    [player.ptr], Y
    iny
@note_off:
    rts

;;------------------------------------------------------------------------------------------
    ; Align to 256
    .org (* + $ff) & $ff00
    .include "mul.inc"
    .include "sin.inc"
player_end:
