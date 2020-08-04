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
SetWav             = $13
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
PCM_UPDATE = %1000_0000
WAV_UPDATE = %0100_0000
PAN_UPDATE = %0010_0000
FRQ_UPDATE = %0001_0000
NOI_UPDATE = %0000_0001

;;------------------------------------------------------------------------------------------
INST_VOL = %0000_0001
INST_ARP = %0000_0010
INST_WAV = %0000_0100

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

dmf.player.delay  .ds DMF_CHAN_COUNT

; [todo] arpeggio, vibrato, etc...

                                    ; 0: backup of header mpr
dmf.player.mpr_backup .ds 2         ; 1: backup of data mpr
dmf.player.chn .ds 1                ; current psg channel
dmf.player.chn.flag .ds DMF_CHAN_COUNT

dmf.player.matrix.row .ds 1         ; current matrix row
dmf.player.tick .ds 2               ; current time tick (fine/coarse kinda sort off)

dmf.player.pattern.pos  .ds 1       ; current pattern position

; [todo] do we need this in zp?
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
dmf.song.wav               .ds 2
dmf.song.instruments       .ds 2
dmf.song.matrix            .ds 2

dmf.player.pattern.bank .ds DMF_CHAN_COUNT
dmf.player.pattern.lo   .ds DMF_CHAN_COUNT
dmf.player.pattern.hi   .ds DMF_CHAN_COUNT

dmf.player.wav.id .ds DMF_CHAN_COUNT

dmf.player.note.previous .ds DMF_CHAN_COUNT

dmf.instrument.flag .ds PSG_CHAN_COUNT              ; [todo] enum and all

dmf.instrument.vol.size  .ds PSG_CHAN_COUNT
dmf.instrument.vol.loop  .ds PSG_CHAN_COUNT
dmf.instrument.vol.lo    .ds PSG_CHAN_COUNT
dmf.instrument.vol.hi    .ds PSG_CHAN_COUNT
dmf.instrument.vol.index .ds PSG_CHAN_COUNT

dmf.instrument.arp.size  .ds PSG_CHAN_COUNT
dmf.instrument.arp.loop  .ds PSG_CHAN_COUNT
dmf.instrument.arp.lo    .ds PSG_CHAN_COUNT
dmf.instrument.arp.hi    .ds PSG_CHAN_COUNT
dmf.instrument.arp.index .ds PSG_CHAN_COUNT

dmf.instrument.wav.size  .ds PSG_CHAN_COUNT
dmf.instrument.wav.loop  .ds PSG_CHAN_COUNT
dmf.instrument.wav.lo    .ds PSG_CHAN_COUNT
dmf.instrument.wav.hi    .ds PSG_CHAN_COUNT
dmf.instrument.wav.index .ds PSG_CHAN_COUNT

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
        lda    dmf.player.wav.id+\1
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

    lda    dmf.song.wav
    clc
    adc    <dmf.player.si
    sta    <dmf.player.si

    sax
    adc    dmf.song.wav+1
    sta    <dmf.player.si+1

;;
;; Function: dmf_wav_upload
;;
;; Parameters:
;;
;; Return:
;;
dmf_wav_upload:
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
    stz    dmf.player.note.previous, X
    stz    dmf.player.note, X
    stz    dmf.player.delay, X

    ; [todo] reset dmf.player.chn.flag

    ; preload wav buffers
    stx    psg_ch
    lda    dmf.song.wav
    sta    <dmf.player.si
    lda    dmf.song.wav+1
    sta    <dmf.player.si+1
    jsr    dmf_wav_upload

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
    
    clx
    bsr    update_state
; [todo]        1. update states according to instruments
; [todo]        2. update states according to effects
; [todo]        3. prepare next psg reg values?

    pla
    tam    #DMF_DATA_MPR
    pla
    tam    #DMF_HEADER_MPR
    
    rts

update_state:                                 ; [todo] find a better name
    ; -- instrument wav                       ; [todo] make a routine?
    lda    dmf.instrument.flag, X
    bit    #INST_WAV
    beq    @no_wav

    ldy    dmf.instrument.wav.index, X
    lda    dmf.instrument.wav.lo, X
    sta    <dmf.player.si
    lda    dmf.instrument.wav.hi, X
    sta    <dmf.player.si+1
    lda    [dmf.player.si], Y
    
    cmp    dmf.player.wav.id, X
    beq    @load_wav.skip
        jsr    dmf.set_wav.ex
@load_wav.skip:
    inc    dmf.instrument.wav.index, X
    lda    dmf.instrument.wav.index, X
    cmp    dmf.instrument.wav.size, X
    bcc    @no_wav.reset
        lda    dmf.instrument.wav.loop, X
        cmp    #$ff
        bne    @wav.reset
            lda    dmf.instrument.flag, X
            and    #~INST_WAV
            sta    dmf.instrument.flag, X
            cla
@wav.reset:
        sta    dmf.instrument.wav.index, X
@no_wav.reset:

@no_wav:
    
    ; [todo]    2. instrument arpeggio
    ; [todo]    3. effect arpegio
    ; [todo]    4. instrument volume
    ; [todo]    5. volume slide
    ; [todo]    6. set volume
    ; [todo]    8. portamento
    ; [todo]    9. vibrato
    ; [todo]    A. set frequency  
    ; [todo] regroup volume / note / frequency updates
    
    rts


;;
;; Function: update_song
;;
;; Parameters:
;;
;; Return:
;;
update_song:
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
    jmp   update_song

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
    .dw dmf.arpeggio
    .dw dmf.arpeggio_speed
    .dw dmf.portamento_up
    .dw dmf.portamento_down
    .dw dmf.portamento_to_note
    .dw dmf.vibrato
    .dw dmf.vibrato_mode
    .dw dmf.vibrato_depth
    .dw dmf.port_to_note_vol_slide
    .dw dmf.vibrato_vol_slide
    .dw dmf.tremolo
    .dw dmf.panning
    .dw dmf.set_speed_value1
    .dw dmf.volume_slide
    .dw dmf.position_jump
    .dw dmf.retrig
    .dw dmf.pattern_break
    .dw dmf.set_speed_value2
    .dw dmf.set_wav
    .dw dmf.enable_noise_channel
    .dw dmf.set_LFO_mode
    .dw dmf.set_LFO_speed
    .dw dmf.note_slide_up
    .dw dmf.note_slide_down
    .dw dmf.note_delay
    .dw dmf.sync_signal
    .dw dmf.fine_tune
    .dw dmf.global_fine_tune
    .dw dmf.set_sample_bank
    .dw dmf.set_volume
    .dw dmf.set_instrument
    .dw dmf.note_on
    .dw dmf.note_off
    .dw dmf.set_samples

; [todo]
;       dmf.vibrato_mode
;       dmf.vibrato_depth
;       dmf.port_to_note_vol_slide
;       dmf.vibrato_vol_slide
;       dmf.tremolo
;       dmf.set_speed_value1
;       dmf.retrig
;       dmf.set_speed_value2
;       dmf.set_LFO_mode
;       dmf.set_LFO_speed
;       dmf.note_slide_up
;       dmf.note_slide_down
;       dmf.sync_signal

;;------------------------------------------------------------------------------------------
dmf.arpeggio:
dmf.arpeggio_speed:
dmf.portamento_up:
dmf.portamento_down:
dmf.portamento_to_note:
dmf.vibrato:
dmf.vibrato_mode:
dmf.vibrato_depth:
dmf.port_to_note_vol_slide:
dmf.vibrato_vol_slide:
dmf.tremolo:
dmf.panning:
dmf.set_speed_value1:
dmf.volume_slide:
dmf.position_jump:
dmf.retrig:
dmf.pattern_break:
dmf.set_speed_value2:
;dmf.set_wav:
;dmf.enable_noise_channel:
dmf.set_LFO_mode:
dmf.set_LFO_speed:
dmf.note_slide_up:
dmf.note_slide_down:
;dmf.note_delay:
dmf.sync_signal:
dmf.fine_tune:
dmf.global_fine_tune:
dmf.set_sample_bank:
dmf.set_volume:
;dmf.set_instrument:
;dmf.note_on:
dmf.set_samples:
    lda    [dmf.player.ptr], Y
    iny
    rts

;;------------------------------------------------------------------------------------------
dmf.note_delay:
    lda    <dmf.player.pattern.pos
    and    #$01
    tax
    
    lda    [dmf.player.ptr], Y
    iny

    cmp    dmf.player.tick, X
    bcs    @note_delay.reset
@note_delay.set:
        ldx    <dmf.player.chn

        ; [todo] trigger note update

        lda    dmf.player.chn.flag, X
        and    #~FRQ_UPDATE
        sta    dmf.player.chn.flag, X
        
        sta    <dmf.player.delay, X
        rts
@note_delay.reset:
        ldx    <dmf.player.chn
        stz    <dmf.player.delay, X
        rts

;;------------------------------------------------------------------------------------------
dmf.note_off:
    ; [todo] reset flags
    rts

;;------------------------------------------------------------------------------------------
dmf.note_on:
    ldx    <dmf.player.chn
    lda    dmf.player.note, X
    sta    dmf.player.note.previous, X

    lda    [dmf.player.ptr], Y
    sta    dmf.player.note, X
    iny
    
    lda    <dmf.player.chn.flag, X
    bmi    @pcm_reset

    ; [todo] flag to trigger note update    
    ; [todo] reinit volume
    ; [todo] tring note/freq update

    ; reset instrument indices
    stz    dmf.instrument.vol.index, X
    stz    dmf.instrument.arp.index, X
    
    rts
@pcm_reset:
    ; [todo]
    rts

;;------------------------------------------------------------------------------------------
dmf.set_wav:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny
dmf.set_wav.ex:
    cmp    dmf.player.wav.id, X
    beq    @skip
        sta    dmf.player.wav.id, X
        lda    <dmf.player.chn.flag, X
        ora    #WAV_UPDATE
        sta    <dmf.player.chn.flag, X
        rts
@skip:
    lda    <dmf.player.chn.flag, X
    and    #WAV_UPDATE
    sta    <dmf.player.chn.flag, X
    rts

;;------------------------------------------------------------------------------------------
dmf.enable_noise_channel:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny

    and    #(~NOI_UPDATE)
    ora    <dmf.player.chn.flag, X
    sta    <dmf.player.chn.flag, X
    beq    @enable_noise_channel.end
        lda    <dmf.player.note, X
        ora    #$80
        sta    <dmf.player.note, X
@enable_noise_channel.end:
    rts

;;------------------------------------------------------------------------------------------
dmf.set_instrument:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny

    clc
    adc    dmf.song.instruments
    sta    <dmf.player.si
    cla
    adc    dmf.song.instruments+1
    sta    <dmf.player.si+1
    
    lda    [dmf.player.si]
    sta    dmf.instrument.vol.size, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1

    lda    [dmf.player.si]
    sta    dmf.instrument.vol.loop, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1
    
    lda    [dmf.player.si]
    sta    dmf.instrument.vol.lo, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1
    
    lda    [dmf.player.si]
    sta    dmf.instrument.vol.hi, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1

    lda    [dmf.player.si]
    sta    dmf.instrument.arp.size, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1

    lda    [dmf.player.si]
    sta    dmf.instrument.arp.loop, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1
    
    lda    [dmf.player.si]
    sta    dmf.instrument.arp.lo, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1
    
    lda    [dmf.player.si]
    sta    dmf.instrument.arp.hi, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1
    
    lda    [dmf.player.si]
    sta    dmf.instrument.wav.size, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1

    lda    [dmf.player.si]
    sta    dmf.instrument.wav.loop, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1
    
    lda    [dmf.player.si]
    sta    dmf.instrument.wav.lo, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1
    
    lda    [dmf.player.si]
    sta    dmf.instrument.wav.hi, X
    lda    <dmf.player.si
    clc
    adc    dmf.song.instrument_count
    sta    <dmf.player.si
    cla
    adc    <dmf.player.si+1
    sta    <dmf.player.si+1

    lda    [dmf.player.si]
    
    stz    dmf.instrument.vol.index, X
    stz    dmf.instrument.arp.index, X
    stz    dmf.instrument.wav.index, X

    phy
    ldy    dmf.instrument.vol.size, X
    beq    @no_vol
        ora    #INST_VOL
@no_vol:
    ldy    dmf.instrument.arp.size, X
    beq    @no_arp
        ora    #INST_ARP
@no_arp:
    ldy    dmf.instrument.wav.size, X
    beq    @no_wav
        ora    #INST_WAV
@no_wav:
    sta    dmf.instrument.flag, X
    ply

    rts

;;------------------------------------------------------------------------------------------
    ; Align to 256
    .org (* + $ff) & $ff00
    .include "mul.inc"
    .include "sin.inc"
dmf.player.end:
