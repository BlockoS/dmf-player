; Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. 
; See the accompanying LICENSE file for terms.
;;------------------------------------------------------------------------------------------

; [todo]
; dmf.portamento_up
; dmf.portamento_down
; dmf.portamento_to_note

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
dmf.player.al .ds 1
dmf.player.ah .ds 1
dmf.player.bl .ds 1
dmf.player.bh .ds 1
dmf.player.cl .ds 1
dmf.player.ch .ds 1
dmf.player.dl .ds 1
dmf.player.dh .ds 1
dmf.player.r0 .ds 2
dmf.player.r1 .ds 2

dmf.player.ptr .ds 2

dmf.player.psg.main    .ds 1
dmf.player.psg.ctrl    .ds DMF_CHAN_COUNT 
dmf.player.psg.freq.lo .ds DMF_CHAN_COUNT
dmf.player.psg.freq.hi .ds DMF_CHAN_COUNT
dmf.player.psg.pan     .ds DMF_CHAN_COUNT

dmf.player.flag   .ds 1
dmf.player.note   .ds DMF_CHAN_COUNT            ; [todo] move to bss?
dmf.player.volume .ds DMF_CHAN_COUNT            ; [todo] move to bss?
dmf.player.rest   .ds DMF_CHAN_COUNT            ; [todo] move to bss?

dmf.player.delay  .ds DMF_CHAN_COUNT

                                    ; 0: backup of header mpr
dmf.player.mpr_backup .ds 2         ; 1: backup of data mpr
dmf.player.chn .ds 1                ; current psg channel
dmf.player.chn.flag .ds DMF_CHAN_COUNT

dmf.player.matrix.row .ds 1         ; current matrix row
dmf.player.tick .ds 2               ; current time tick (fine/coarse kinda sort off)

dmf.player.pattern.pos  .ds 1       ; current pattern position

dmf.player.detune .ds 1             ; global detune

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

; [todo] next note for delay ?
dmf.player.volume.orig   .ds DMF_CHAN_COUNT
dmf.player.volume.offset .ds DMF_CHAN_COUNT
dmf.player.volume.delta  .ds DMF_CHAN_COUNT

dmf.player.freq.delta.lo .ds DMF_CHAN_COUNT
dmf.player.freq.delta.hi .ds DMF_CHAN_COUNT

dmf.instrument.flag .ds PSG_CHAN_COUNT

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

dmf.fx.arp.data    .ds PSG_CHAN_COUNT
dmf.fx.arp.current .ds PSG_CHAN_COUNT
dmf.fx.arp.tick    .ds PSG_CHAN_COUNT
dmf.fx.arp.speed   .ds PSG_CHAN_COUNT

dmf.fx.vib.data .ds PSG_CHAN_COUNT
dmf.fx.vib.tick .ds PSG_CHAN_COUNT

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
    tma    #DMF_HEADER_MPR
    pha
    
    lda    dmf.song.bank
    tam    #DMF_HEADER_MPR

    clx
    stx    psg_ch                                 ; update PSG control register
    lda    <dmf.player.psg.ctrl+0
    sta    psg_ctrl

    ldx    #$01
    stx    psg_ch
    lda    <dmf.player.psg.ctrl+1
    sta    psg_ctrl

    ldx    #$02
    stx    psg_ch
    lda    <dmf.player.psg.ctrl+2
    sta    psg_ctrl

    ldx    #$03
    stx    psg_ch
    lda    <dmf.player.psg.ctrl+3
    sta    psg_ctrl

    ldx    #$04
    stx    psg_ch
    lda    <dmf.player.psg.ctrl+4
    sta    psg_ctrl

    ldx    #$05
    stx    psg_ch
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
        lda    <dmf.player.psg.ctrl+\1
        sta    psg_ctrl
        rmb6   <dmf.player.chn.flag+\1
@pan\1:
    bbr5   <dmf.player.chn.flag+\1, @freq\1
        lda    <dmf.player.psg.pan+\1
        sta    psg_pan
        rmb5   <dmf.player.chn.flag+\1
@freq\1:
    bbr4   <dmf.player.chn.flag+\1, @next\1
.if \1 > 3
        bbr0   <dmf.player.chn.flag+\1, @no_noise\1
            lda    <dmf.player.psg.freq.lo+\1
            sta    psg_noise
            bra    @next\1
@no_noise\1:
            stz    psg_noise
.endif
        lda    <dmf.player.psg.freq.lo+\1
        sta    psg_freq.lo
        lda    <dmf.player.psg.freq.hi+\1
        sta    psg_freq.hi
        rmb4   <dmf.player.chn.flag+\1
@next\1:
  .endm

    clx
    stx    psg_ch
    dmf.update_psg 0
    ldx    #$01
    stx    psg_ch
    dmf.update_psg 1
    ldx    #$02
    stx    psg_ch
    dmf.update_psg 2
    ldx    #$03
    stx    psg_ch
    dmf.update_psg 3
    ldx    #$04
    stx    psg_ch
    dmf.update_psg 4
    ldx    #$05
    stx    psg_ch
    dmf.update_psg 5

    pla
    tam    #DMF_HEADER_MPR

    rts

@load_wav:
    stz    <dmf.player.si

    lsr    A
    ror    <dmf.player.si

    lsr    A
    ror    <dmf.player.si

    lsr    A
    ror    <dmf.player.si

    say

    lda    dmf.song.wav
    clc
    adc    <dmf.player.si
    sta    <dmf.player.si

    say
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

    lda    #$7c
    sta    dmf.player.volume, X
    sta    dmf.player.volume.orig, X

    ; set default player sate
    stz    dmf.player.note.previous, X
    stz    dmf.player.note, X
    stz    dmf.player.delay, X
    stz    dmf.player.volume.offset, X
    stz    dmf.player.volume.delta, X

    stz    dmf.instrument.flag, X
    
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

    jsr    update_song
    
    clx
    jsr    update_state
    ldx    #$01
    jsr    update_state
    ldx    #$02
    jsr    update_state
    ldx    #$03
    jsr    update_state
    ldx    #$04
    jsr    update_state
    ldx    #$05
    jsr    update_state

    pla
    tam    #DMF_DATA_MPR
    pla
    tam    #DMF_HEADER_MPR
    
    rts

update_state:                                 ; [todo] find a better name
    lda    <dmf.player.chn.flag, X
    sta    <dmf.player.al

    ; -- instrument wav
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
        sta    dmf.player.wav.id, X
        smb6   <dmf.player.al
@load_wav.skip:
    inc    dmf.instrument.wav.index, X
    lda    dmf.instrument.wav.index, X
    cmp    dmf.instrument.wav.size, X
    bcc    @no_wav
        lda    dmf.instrument.wav.loop, X
        cmp    #$ff
        bne    @wav.reset
            lda    dmf.instrument.flag, X
            and    #~INST_WAV
            sta    dmf.instrument.flag, X
            cla
@wav.reset:
        sta    dmf.instrument.wav.index, X
@no_wav:
    
    ; -- global detune fx
    lda    dmf.player.note, X
    clc
    adc    <dmf.player.detune
    sta    <dmf.player.cl

    ; -- instrument arpeggio
    lda    dmf.instrument.flag, X
    bit    #INST_ARP 
    beq    @no_arp
    bit    #%1000_0000                                          ; [todo] what is it for ? 
    beq    @std.arp
@fixed.arp:
        ldy    dmf.instrument.arp.index, X                      ; [todo] We'll find a clever implementation later.
        lda    dmf.instrument.arp.lo, X
        sta    <dmf.player.si
        lda    dmf.instrument.arp.hi, X
        sta    <dmf.player.si+1
        lda    [dmf.player.si], Y        
        bra    @arp.store
@std.arp:
    ldy    dmf.instrument.arp.index, X
    lda    dmf.instrument.arp.lo, X
    sta    <dmf.player.si
    lda    dmf.instrument.arp.hi, X
    sta    <dmf.player.si+1
    lda    [dmf.player.si], Y
    sec
    sbc    #$0c                                                 ; add an octacve
    clc
    adc    <dmf.player.cl
@arp.store:
    sta    <dmf.player.cl

    inc    dmf.instrument.arp.index, X
    lda    dmf.instrument.arp.index, X
    cmp    dmf.instrument.arp.size, X
    bcc    @no_arp.reset
        lda    dmf.instrument.arp.loop, X
        cmp    #$ff
        bne    @arp.reset
            lda    dmf.instrument.flag, X
            and    #~INST_ARP
            sta    dmf.instrument.flag, X
            cla
@arp.reset:
        sta    dmf.instrument.arp.index, X
@no_arp.reset:
    smb4   <dmf.player.al                                      ; we'll need to update frequency
@no_arp:

    ; -- effect arpeggio
    ldy    dmf.fx.arp.data, X
    beq    @no_arpeggio
    dec    dmf.fx.arp.tick, X
    bne    @no_arpeggio
        lda    dmf.fx.arp.speed, X
        sta    dmf.fx.arp.tick, X

        tya

        smb4   <dmf.player.al                                   ; we'll need to update frequency
        ldy    dmf.fx.arp.current, X
        beq    @arpeggio.0
        
        cpy    #1
        beq    @arpeggio.1
@arpeggio.2:
            ldy    #$ff
            lsr    A
            lsr    A
            lsr    A
            lsr    A
@arpeggio.1:
        and    #$0f
        clc
        adc    <dmf.player.cl
        sta    <dmf.player.cl
@arpeggio.0:
        iny
        tya
        sta    dmf.fx.arp.current, X
@no_arpeggio:

    ; As the PSG control register is updated every frame, we can
    ; "waste" some cycle rebuilding it every time.
    lda    dmf.player.volume, X
    clc
    adc    dmf.player.volume.offset, X
    bpl    @vol.plus
        cla
    bra    @set_volume
@vol.plus:
    cmp    #$7c
    bcc    @set_volume
        lda    #$7c
@set_volume:
    sta    <dmf.player.ch

    ; -- instrument volume
    lda    dmf.instrument.flag, X
    bit    #INST_VOL 
    beq    @no_volume
        ldy    dmf.instrument.vol.index, X                  ; fetch envelope value
        lda    dmf.instrument.vol.lo, X
        sta    <dmf.player.si
        lda    dmf.instrument.vol.hi, X
        sta    <dmf.player.si+1
        lda    [dmf.player.si], Y
        inc    A
        ldy    dmf.player.volume.orig, X                    ; compute envelope * volume
        phx
        jsr    mul8
        asl    A
        sta    <dmf.player.ch
        plx
        sta    dmf.player.volume, X

        inc    dmf.instrument.vol.index, X                  ; increment index
        lda    dmf.instrument.vol.index, X
        cmp    dmf.instrument.vol.size, X
        bcc    @no_volume
            lda    dmf.instrument.vol.loop, X
            cmp    #$ff
            bne    @volume.reset                            ; and reset it to its loop position if needed
                lda    dmf.instrument.flag, X
                and    #~INST_VOL
                sta    dmf.instrument.flag, X
                cla
@volume.reset:
            sta    dmf.instrument.vol.index, X
@no_volume:

    ; -- fx volume slide
    lda    dmf.player.volume.delta, X
    beq    @no_volume_slide
        clc
        adc    dmf.player.volume.offset, X
        sta    dmf.player.volume.offset, X
@no_volume_slide:

    ; [todo]    8. portamento
    lda    dmf.player.freq.delta.lo, X
    sta    <dmf.player.dl
    lda    dmf.player.freq.delta.hi, X
    sta    <dmf.player.dh
    ; [todo]       no portamento

    ; -- vibrato
    lda    dmf.fx.vib.data, X
    beq    @no_vibrato
        jsr    dmf.update_vibrato
@no_vibrato:

    ; rebuild PSG control register
    lda    <dmf.player.psg.ctrl, X
    and    #%11_0_00000
    sta    <dmf.player.psg.ctrl, X
    
    lda    <dmf.player.ch
    beq    @skip
        lsr    A
        lsr    A
@skip:
    ora    <dmf.player.psg.ctrl, X
    sta    <dmf.player.psg.ctrl, X

    bbr4   <dmf.player.al, @no_freq_update
        bbs0   <dmf.player.al, @noise_update 
            ldy    <dmf.player.cl
            lda    freq_table.lo, Y
            clc
            adc    <dmf.player.dl
            sta    <dmf.player.psg.freq.lo, X
            lda    freq_table.hi, Y
            adc    <dmf.player.dh
            sta    <dmf.player.psg.freq.hi, X 

            bra    @no_freq_update
@noise_update:
            ldy    <dmf.player.cl
            lda    noise_table, Y
            sta    <dmf.player.psg.freq.lo, X
@no_freq_update:

    lda    <dmf.player.al
    sta    <dmf.player.chn.flag, X

    rts

;;------------------------------------------------------------------------------------------
dmf.update_vibrato:
    smb4   <dmf.player.al

    lda    dmf.fx.vib.data, X
    and    #$0f
    pha

    lda    dmf.fx.vib.tick, X
    asl    A
    asl    A
    tay

    lda    sin_table, Y
    sec
    sbc    #$10
    sta    <dmf.player.r1+1
    bpl    @plus
@neg:
    eor    #$ff
    inc    A
    pha

    ldy    <dmf.player.cl
    lda    freq_table.lo-1, Y
    sec
    sbc    freq_table.lo, Y
    sta    <dmf.player.r0
    lda    freq_table.hi-1, Y
    sbc    freq_table.hi, Y
    sta    <dmf.player.r0+1
    bra    @go
@plus:
    pha

    ldy    <dmf.player.cl
    lda    freq_table.lo, Y
    sec
    sbc    freq_table.lo+1, Y
    sta    <dmf.player.r0
    lda    freq_table.hi, Y
    sbc    freq_table.hi+1, Y
    sta    <dmf.player.r0+1
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

    ldy    <dmf.player.r0
    sec
    ;    lda    [mul8.lo  ], Y
    ;    sbc    [mul8.lo+2], Y           ; [todo] keep it?
    ;    tax
    lda    [mul8.hi  ], Y
    sbc    [mul8.hi+2], Y
    sta    <dmf.player.r0

    ldy    <dmf.player.r0+1
    sec
    lda    [mul8.lo  ], Y
    sbc    [mul8.lo+2], Y
    tax
    lda    [mul8.hi  ], Y
    sbc    [mul8.hi+2], Y
    
    sax
    clc
    adc    <dmf.player.r0
    sta    <dmf.player.r0
    sax
    adc    #0
    sta    <dmf.player.r0+1
    
    ldy    <dmf.player.r1+1
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
    ldy    <dmf.player.chn
    clc
    adc    <dmf.player.dl
    sta    <dmf.player.dl
    sax
    adc    <dmf.player.dh
    sta    <dmf.player.dh
       
    lda    dmf.fx.vib.data, Y
    lsr    A
    lsr    A
    lsr    A
    lsr    A
    clc
    adc    dmf.fx.vib.tick, Y
    sta    dmf.fx.vib.tick, Y
    
    sxy

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
;dmf.arpeggio:
;dmf.arpeggio_speed:
dmf.portamento_up:
dmf.portamento_down:
dmf.portamento_to_note:
;dmf.vibrato:
dmf.vibrato_mode:
dmf.vibrato_depth:
dmf.port_to_note_vol_slide:
dmf.vibrato_vol_slide:
dmf.tremolo:
dmf.panning:
dmf.set_speed_value1:
    lda    [dmf.player.ptr], Y
    iny
    rts

;dmf.volume_slide:
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
;dmf.global_fine_tune:
dmf.set_sample_bank:
;dmf.set_volume:
;dmf.set_instrument:
;dmf.note_on:
dmf.set_samples:
    lda    [dmf.player.ptr], Y
    iny
    rts

;;------------------------------------------------------------------------------------------
dmf.set_volume:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny

    sta    dmf.player.volume, X
    sta    dmf.player.volume.orig, X

    stz    dmf.player.volume.offset, X

    rts

;;------------------------------------------------------------------------------------------
dmf.global_fine_tune:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny

    clc
    adc    <dmf.player.detune
    sta    <dmf.player.detune

    lda    dmf.player.chn.flag, X
    ora    #FRQ_UPDATE
    sta    dmf.player.chn.flag, X

    rts

;;------------------------------------------------------------------------------------------
dmf.note_delay:             ; [todo] rework
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
    ldx    <dmf.player.chn
    stz    dmf.fx.arp.data, X
    stz    dmf.fx.vib.data, X
    stz    dmf.instrument.flag, X
    stz    dmf.player.freq.delta.lo
    stz    dmf.player.freq.delta.hi
    stz    dmf.player.chn.flag, X
    
    lda    <dmf.player.psg.ctrl, X
    and    #%00_0_11111
    sta    <dmf.player.psg.ctrl, X

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

    lda    <dmf.player.chn.flag, X
    ora    #FRQ_UPDATE
    sta    <dmf.player.chn.flag, X

    lda    <dmf.player.psg.ctrl, X
    and    #%00_0_11111
    ora    #%10_0_00000
    sta    <dmf.player.psg.ctrl, X

    stz    dmf.player.freq.delta.lo                     ; [todo] portamento
    stz    dmf.player.freq.delta.hi

    stz    dmf.instrument.vol.index, X
    stz    dmf.instrument.arp.index, X
    stz    dmf.instrument.wav.index, X
    
    rts
@pcm_reset:
    ; [todo]
    rts

;;------------------------------------------------------------------------------------------
dmf.set_wav:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny

    cmp    dmf.player.wav.id, X
    beq    @skip
        sta    dmf.player.wav.id, X
        lda    <dmf.player.chn.flag, X
        ora    #WAV_UPDATE
        sta    <dmf.player.chn.flag, X
        rts
@skip:
    lda    <dmf.player.chn.flag, X
    and    #~WAV_UPDATE
    sta    <dmf.player.chn.flag, X
    rts

;;------------------------------------------------------------------------------------------
dmf.enable_noise_channel:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    beq    @disable_noise_channel
        lda    <dmf.player.chn.flag, X
        ora    #NOI_UPDATE
        sta    <dmf.player.chn.flag, X

        iny
        rts

@disable_noise_channel:
        lda    <dmf.player.chn.flag, X
        and    #(~NOI_UPDATE)
        sta    <dmf.player.chn.flag, X
        
        iny
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
dmf.arpeggio_speed:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny
    sta    dmf.fx.arp.speed, X
    rts

;;------------------------------------------------------------------------------------------
dmf.arpeggio:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny
    sta    dmf.fx.arp.data, X
    lda    dmf.fx.arp.speed, X
    sta    dmf.fx.arp.tick, X
    stz    dmf.fx.arp.current, X
    rts

;;------------------------------------------------------------------------------------------
dmf.volume_slide:
    ldx    <dmf.player.chn
    lda    [dmf.player.ptr], Y
    sta    dmf.player.volume.delta, X
    iny
    rts

;;------------------------------------------------------------------------------------------
dmf.vibrato: 
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny
    sta    dmf.fx.vib.data, X
    stz    dmf.fx.vib.tick, X
    rts

;;------------------------------------------------------------------------------------------
    ; Align to 256
    .org (* + $ff) & $ff00
    .include "mul.inc"
    .include "sin.inc"
dmf.player.end:
