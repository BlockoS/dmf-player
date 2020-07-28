; Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. 
; See the accompanying LICENSE file for terms.
;;------------------------------------------------------------------------------------------

; [todo]
;    fx callback : don't set psg reg
;    fx callback : bring back code
;    commit psg reg / upload wav / start pcm in irq1

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

dmf.player.si .ds 2
dmf.player.ax:
dmf.player.al .ds 1
dmf.player.ah .ds 1

dmf.player.ptr .ds 2

dmf.player.psg.main    .ds 1
dmf.player.psg.ctrl    .ds DMF_CHAN_COUNT 
dmf.player.psg.freq.lo .ds DMF_CHAN_COUNT
dmf.player.psg.freq.hi .ds DMF_CHAN_COUNT
dmf.player.psg.pan     .ds DMF_CHAN_COUNT

dmf.player.flag   .ds 1
dmf.player.note   .ds DMF_CHAN_COUNT
dmf.player.volume .ds DMF_CHAN_COUNT
dmf.player.rest   .ds DMF_CHAN_COUNT

; [todo] arpeggio, vibrato, etc...
; [todo] instrument states (volume, arpeggio, wave)

                                    ; 0: backup of header mpr
dmf.player.mpr_backup .ds 2         ; 1: backup of data mpr
dmf.player.chn .ds 1                ; current psg channel
dmf.player.chn.flag .ds DMF_CHAN_COUNT

dmf.player.matrix.row .ds 1         ; current matrix row
dmf.player.tick .ds 2               ; current time tick (fine/coarse kinda sort off)

dmf.player.pattern.pos  .ds 1       ; current pattern position

dmf.player.samples.rate.lo       .ds 2 ; PCM sample rate (RCR offset LSB) 
dmf.player.samples.rate.hi       .ds 2 ; PCM sample rate (RCR offset MSB)
dmf.player.samples.offset.lo     .ds 2 ; PCM samples ROM offset (LSB)
dmf.player.samples.offset.hi     .ds 2 ; PCM samples ROM offset (MSB)
dmf.player.samples.bank          .ds 2 ; PCM samples ROM bank

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

dmf.player.pattern.bank .ds DMF_CHAN_COUNT
dmf.player.pattern.lo   .ds DMF_CHAN_COUNT
dmf.player.pattern.hi   .ds DMF_CHAN_COUNT

dmf.player.wave.id .ds DMF_CHAN_COUNT

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
dmf_commit:
    stz    psg_ch                                 ; update PSG control register
    lda    <dmf.player.psg.ctrl+0
    sta    psg_ctrl

    inc    psg_ch
    lda    <dmf.player.psg.ctrl+1
    sta    psg_ctrl

    inc    psg_ch
    lda    <dmf.player.psg.ctrl+2
    sta    psg_ctrl

    inc    psg_ch
    lda    <dmf.player.psg.ctrl+3
    sta    psg_ctrl

    inc    psg_ch
    lda    <dmf.player.psg.ctrl+4
    sta    psg_ctrl

    inc    psg_ch
    lda    <dmf.player.psg.ctrl+5
    sta    psg_ctrl

  .macro dmf.update_psg
@ch\1:    
    bbr7   <dmf.player.chn.flag+\1, @wav\1
        ; [todo] pcm
@wav\1:
    bbr6   <dmf.player.chn.flag+\1, @pan\1
        lda    dmf.player.wave.id+\1
        jsr    @load_wav
@pan\1:
    bbr5   <dmf.player.chn.flag+\1, @freq\1
        lda    <dmf.player.psg.pan+\1
        sta    psg_pan
@freq\1:
    bbr4   <dmf.player.chn.flag+\1, @next\1
        lda    <dmf.player.psg.freq.lo+\1
        sta    psg_freq.lo
        lda    <dmf.player.psg.freq.hi+\1
        sta    psg_freq.hi
@next\1:
  .endm

    stz    psg_ch
    dmf.update_psg 0
    inc    psg_ch
    dmf.update_psg 1
    inc    psg_ch
    dmf.update_psg 2
    inc    psg_ch
    dmf.update_psg 3
    inc    psg_ch
    dmf.update_psg 4
    bbr0   <dmf.player.chn.flag+4, @no_noise0
        cla
        ldy    <dmf.player.note+4
        bpl    @set_noise0
            lda    noise_table, Y 
@set_noise0:
        sta    psg_noise
@no_noise0:
    inc    psg_ch
    dmf.update_psg 5
    bbr0   <dmf.player.chn.flag+5, @no_noise1
        cla
        ldy    <dmf.player.note+5
        bpl    @set_noise1
            lda    noise_table, Y
@set_noise1:
        sta    psg_noise
@no_noise1:

    stz    <dmf.player.chn.flag+0
    stz    <dmf.player.chn.flag+1
    stz    <dmf.player.chn.flag+2
    stz    <dmf.player.chn.flag+3
    stz    <dmf.player.chn.flag+4
    stz    <dmf.player.chn.flag+5

    rts

@load_wav:
    stz    <dmf.player.si

    lsr    A
    ror    <dmf.player.si

    lsr    A
    ror    <dmf.player.si

    lsr    A
    ror    <dmf.player.si

    sax

    lda    dmf.song.wave
    clc
    adc    <dmf.player.si
    sta    <dmf.player.si

    sax
    adc    dmf.song.wave+1
    sta    <dmf.player.si+1

;;
;; Function: dmf_wave_upload
;;
;; Parameters:
;;
;; Return:
;;
dmf_wave_upload:
    stz    psg_ctrl
    cly
@l0:                                ; [todo] unroll?
    lda    [dmf.player.si], Y
    iny
    sta    psg_wavebuf
    cpy    #$20
    bne    @l0
    
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
    sta    <dmf.player.si

    lda    dmf.song.ptr+1
    and    #$1f
    ora    #DMF_HEADER_MPR<<5
    sta    <dmf.player.si+1

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
    lda    [dmf.player.si], Y
    sta    dmf.song.infos, Y
    iny
    cpy    #DMF_HEADER_SIZE
    bne    @copy_header

    ; save address to song name
    tya
    clc
    adc    <dmf.player.si
    sta    <dmf.player.si
    sta    dmf.song.name
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si
    sta    dmf.song.name+1

    ; move to the song author
    lda    [dmf.player.si]          ; string length
    inc    A
    clc
    adc    <dmf.player.si
    sta    dmf.song.author
    cla
    adc    <dmf.player.si+1
    sta    dmf.song.author+1

    ; move to samples
    lda    [dmf.player.si]          ; string length
    inc    A
    clc
    adc    <dmf.player.si
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1

    lda    [dmf.player.si]          ; sample count
    sta    <dmf.player.al

    clc                             ; save pointer to sample rates (LSB)
    lda    <dmf.player.si
    adc    #$01
    sta    <dmf.player.samples.rate.lo
    tax
    lda    dmf.player.si+1
    adc    #$00
    sta    <dmf.player.samples.rate.lo+1

    clc                             ; samples ROM offset (LSB)
    sax
    adc    <dmf.player.al
    sta    <dmf.player.samples.offset.lo
    sax
    adc    #$00
    sta    <dmf.player.samples.offset.lo+1

    clc                             ; sample rate (MSB)
    sax
    adc    <dmf.player.al
    sta    <dmf.player.samples.rate.hi
    sax
    adc    #$00
    sta    <dmf.player.samples.rate.hi+1

    clc                             ; samples ROM offset (MSB)
    sax
    adc    <dmf.player.al
    sta    <dmf.player.samples.offset.hi
    sax
    adc    #$00
    sta    <dmf.player.samples.offset.hi+1

    clc                             ; samples ROM bank
    sax
    adc    <dmf.player.al
    sta    <dmf.player.samples.bank
    sax
    adc    #$00
    sta    <dmf.player.samples.bank+1

    ; initializes player
    stz    dmf.player.matrix.row
    jsr    dmf_update_matrix

    lda    #$ff
    sta    <dmf.player.psg.main

    clx
@player_init:
    stz    <dmf.player.psg.ctrl, X
    stz    <dmf.player.psg.freq.lo, X
    stz    <dmf.player.psg.freq.hi, X

    lda    #$ff
    sta    <dmf.player.psg.pan, X
    
    ; [todo] default player sate
    ; [todo] reset dmf.player.chn.flag

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
    lda    <dmf.player.matrix.row
    cmp    dmf.song.matrix.rows
    bne    @l0
        stz    <dmf.player.matrix.row
@l0:

    lda    dmf.song.matrix
    sta    <dmf.player.si    
    lda    dmf.song.matrix+1
    sta    <dmf.player.si+1
    
    stz    <dmf.player.pattern.pos

    ldy    <dmf.player.matrix.row
    clx
@set_pattern_ptr:
        lda    [dmf.player.si], Y
        sta    dmf.player.pattern.bank, X       ; pattern ROM bank

        clc
        lda    <dmf.player.si
        adc    dmf.song.matrix.rows
        sta    <dmf.player.si
        lda    <dmf.player.si+1
        adc    #$00
        sta    <dmf.player.si+1

        lda    [dmf.player.si], Y
        sta    dmf.player.pattern.lo, X         ; pattern ROM offset (LSB)

        clc
        lda    <dmf.player.si
        adc    dmf.song.matrix.rows
        sta    <dmf.player.si
        lda    <dmf.player.si+1
        adc    #$00
        sta    <dmf.player.si+1

        lda    [dmf.player.si], Y
        sta    dmf.player.pattern.hi, X         ; pattern ROM offset (MSB)

        lda    <dmf.player.si
        clc
        adc    dmf.song.matrix.rows
        sta    <dmf.player.si
        lda    <dmf.player.si+1
        adc    #$00
        sta    <dmf.player.si+1

        stz    <dmf.player.rest, X

; [todo] reset player state

        inx
        cpx    #DMF_CHAN_COUNT
        bne    @set_pattern_ptr

    lda    #1
    sta    <dmf.player.tick
    sta    <dmf.player.tick+1

    inc    <dmf.player.matrix.row

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
    stz    <dmf.player.flag
    
    dec    <dmf.player.tick
    beq    @l0
    bmi    @l0
        ; Nothing to do here.
        ; Just go on and update player state.
        rts
@l0:
    ; Reset base tick.
    lda    dmf.song.time.base
    sta    <dmf.player.tick
    
    dec    <dmf.player.tick+1
    beq    @l1
    bmi    @l1
        ; Nothing to do here.
        rts
@l1:
    ; Fetch next pattern entry.
    inc    <dmf.player.pattern.pos
   
    ; 1. reset coarse timer tick.
    lda    <dmf.player.pattern.pos
    and    #$01
    tax
    lda    dmf.song.time.tick, X
    sta    <dmf.player.tick+1

    clx
@loop:
    stx    <dmf.player.chn
    bsr    update_chan                              ; [todo] name
    bcc    @l2
        smb0    <dmf.player.flag
@l2:
    inx
    cpx    #DMF_CHAN_COUNT
    bne    @loop

    bbs0   <dmf.player.flag, @l3
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
    ldx    <dmf.player.chn
    lda    <dmf.player.rest, X
    bne    @dec_rest
        lda    dmf.player.pattern.bank, X
        tam    #DMF_DATA_MPR
        lda    dmf.player.pattern.lo, X
        sta    <dmf.player.ptr
        lda    dmf.player.pattern.hi, X 
        sta    <dmf.player.ptr+1
        bsr    fetch_pattern                        ; [todo] name
        bcc    @continue
            rts
@continue:
        ldx    <dmf.player.chn
        lda    <dmf.player.ptr
        sta    dmf.player.pattern.lo, X
        lda    <dmf.player.ptr+1
        sta    dmf.player.pattern.hi, X 
        rts
@dec_rest:
    dec    <dmf.player.rest, X
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
    lda   [dmf.player.ptr], Y
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
        lda    [dmf.player.ptr], Y
        iny
@rest_store:
        ldx    <dmf.player.chn
        dec    a
        sta    <dmf.player.rest, X
        pla
        bra    @inc_ptr
@fetch
    asl   A
    tax

    bsr   @fetch_pattern_data

    pla 
    bpl    @loop
@inc_ptr:
    tya
    clc
    adc    <dmf.player.ptr
    sta    <dmf.player.ptr
    cla
    adc    <dmf.player.ptr+1
    sta    <dmf.player.ptr+1
    
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
;@set_wave:
;@enable_noise_channel:
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
;@set_instrument:
@note_on:
@set_samples:
    lda    [dmf.player.ptr], Y
    iny
@note_off:
    rts

;;------------------------------------------------------------------------------------------
@set_wave:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny

    cmp    dmf.player.wave.id, X
    beq    @skip
        sta    dmf.player.wave.id, X
        lda    <dmf.player.chn.flag, X
        ora    #%0100_0000
        sta    <dmf.player.chn.flag, X
        rts
@skip:
    lda    <dmf.player.chn.flag, X
    and    #%0100_0000
    sta    <dmf.player.chn.flag, X
    rts

;;------------------------------------------------------------------------------------------
@enable_noise_channel:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny

    and    #%1111_1110
    ora    <dmf.player.chn.flag, X
    sta    <dmf.player.chn.flag, X
    beq    @enable_noise_channel.end
        lda    <dmf.player.note, X
        ora    #$80
        sta    <dmf.player.note, X
@enable_noise_channel.end:
    rts

;;------------------------------------------------------------------------------------------
@set_instrument:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny

    ; [todo] 

    lda    #%0100_0000                              ; [dummy]
    sta    <dmf.player.chn.flag, X                  ; [dummy]
    txa                                             ; [dummy]
    sta    dmf.player.wave.id, X                    ; [dummy]

    rts

;;------------------------------------------------------------------------------------------
    ; Align to 256
    .org (* + $ff) & $ff00
    .include "mul.inc"
    .include "sin.inc"
dmf.player.end:
