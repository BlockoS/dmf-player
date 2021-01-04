; Copyright (c) 2015-2020, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. 
; See the accompanying LICENSE file for terms.
;;------------------------------------------------------------------------------------------

; [todo]
; porta to note borken?
; pattern_break
; position_jump
; fine_tune

;;------------------------------------------------------------------------------------------

;;
;; Title: DMF player.
;;

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
FX_PRT_UP        = %0000_0001
FX_PRT_DOWN      = %0000_0010
FX_PRT_NOTE_UP   = %0000_0100
FX_PRT_NOTE_DOWN = %0000_1000
FX_VIBRATO       = %0001_0000
FX_NOTE          = %1000_0000

;;------------------------------------------------------------------------------------------
    .zp
mul8.lo .ds 4
mul8.hi .ds 4

dmf.zp.begin:

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

dmf.player.status .ds 1
dmf.player.samples.offset .ds 2 ; PCM samples index

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

                                    ; 0: backup of header mpr
dmf.player.mpr_backup .ds 2         ; 1: backup of data mpr
dmf.player.chn .ds 1                ; current psg channel
dmf.player.chn.flag .ds DMF_CHAN_COUNT

dmf.player.matrix.row .ds 1         ; current matrix row
dmf.player.tick .ds 2               ; current time tick (fine/coarse kinda sort off)

dmf.player.pattern.pos  .ds 1       ; current pattern position

dmf.player.detune .ds 1             ; global detune

dmf.player.pcm.bank      .ds PSG_CHAN_COUNT
dmf.player.pcm.ptr       .ds PSG_CHAN_COUNT*2
dmf.player.pcm.state     .ds 1

dmf.player.note_on      .ds 1 ; [todo] rename new_note

dmf.zp.end:

;;------------------------------------------------------------------------------------------
    .bss
dmf.bss.begin:

dmf.song.bank .ds 1
dmf.song.id   .ds 1
dmf.song.infos:
dmf.song.time.base .ds 1
dmf.song.time.tick .ds 2
dmf.song.pattern.rows .ds 1
dmf.song.matrix.rows  .ds 1
dmf.song.instrument_count  .ds 1
dmf.song.instruments       .ds 2
dmf.song.wav               .ds 2
dmf.song.matrix            .ds 2

dmf.player.pattern.bank .ds DMF_CHAN_COUNT
dmf.player.pattern.lo   .ds DMF_CHAN_COUNT
dmf.player.pattern.hi   .ds DMF_CHAN_COUNT

dmf.player.wav.id .ds DMF_CHAN_COUNT

dmf.player.delay .ds DMF_CHAN_COUNT
dmf.player.cut   .ds DMF_CHAN_COUNT

dmf.player.note.previous .ds DMF_CHAN_COUNT

dmf.player.volume.orig   .ds DMF_CHAN_COUNT
dmf.player.volume.offset .ds DMF_CHAN_COUNT
dmf.player.volume.delta  .ds DMF_CHAN_COUNT

dmf.player.freq.delta.lo .ds DMF_CHAN_COUNT
dmf.player.freq.delta.hi .ds DMF_CHAN_COUNT

dmf.instrument.flag      .ds PSG_CHAN_COUNT
dmf.instrument.flag.orig .ds PSG_CHAN_COUNT

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

dmf.fx.flag .ds PSG_CHAN_COUNT

dmf.fx.arp.data    .ds PSG_CHAN_COUNT
dmf.fx.arp.current .ds PSG_CHAN_COUNT
dmf.fx.arp.tick    .ds PSG_CHAN_COUNT
dmf.fx.arp.speed   .ds PSG_CHAN_COUNT

dmf.fx.vib.data .ds PSG_CHAN_COUNT
dmf.fx.vib.tick .ds PSG_CHAN_COUNT

dmf.fx.prt.speed .ds PSG_CHAN_COUNT ; portamento speed

dmf.pcm.bank     .ds PSG_CHAN_COUNT
dmf.pcm.src.bank .ds PSG_CHAN_COUNT
dmf.pcm.src.ptr  .ds PSG_CHAN_COUNT*2

dmf.bss.end:

;;------------------------------------------------------------------------------------------
    .code

    ; Align to 256
    .org (* + $ff) & $ff00
    .include "mul.inc"
    .include "sin.inc"

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
dmf_update:
    bbr7   <dmf.player.status, @go
        rts
@go:
    tma    #DMF_HEADER_MPR
    pha

    tma    #DMF_MATRIX_MPR
    pha

    tma    #DMF_DATA_MPR
    pha
    
    lda    dmf.song.bank
    tam    #DMF_HEADER_MPR

    inc    A
    tam    #DMF_MATRIX_MPR

    sei

    clx
    stx    psg_chn                                 ; update PSG control register
    lda    <dmf.player.psg.ctrl+0
    sta    psg_ctrl

    ldx    #$01
    stx    psg_chn
    lda    <dmf.player.psg.ctrl+1
    sta    psg_ctrl

    ldx    #$02
    stx    psg_chn
    lda    <dmf.player.psg.ctrl+2
    sta    psg_ctrl

    ldx    #$03
    stx    psg_chn
    lda    <dmf.player.psg.ctrl+3
    sta    psg_ctrl

    ldx    #$04
    stx    psg_chn
    lda    <dmf.player.psg.ctrl+4
    sta    psg_ctrl

    ldx    #$05
    stx    psg_chn
    lda    <dmf.player.psg.ctrl+5
    sta    psg_ctrl
    
    cli

  .macro dmf.update_psg
@ch\1:
    bbr7   <dmf.player.chn.flag+\1, @wav\1
        bbr\1   <dmf.player.note_on, @pcm\1
            lda    dmf.pcm.src.ptr+(2*\1)
            sta    <dmf.player.pcm.ptr+(2*\1)
            lda    dmf.pcm.src.ptr+(1+2*\1)
            sta    <dmf.player.pcm.ptr+(1+2*\1)
            lda    dmf.pcm.src.bank+\1
            sta    <dmf.player.pcm.bank+\1
            
            rmb\1  <dmf.player.note_on
@pcm\1:
        smb\1  <dmf.player.pcm.state
@wav\1:
    bbr6   <dmf.player.chn.flag+\1, @pan\1
        lda    dmf.player.wav.id+\1
        jsr    dmf_wav_upload.ex
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
            bra    @freq.end\1
@no_noise\1:
            stz    psg_noise
.endif
        lda    <dmf.player.psg.freq.lo+\1
        sta    psg_freq_lo
        lda    <dmf.player.psg.freq.hi+\1
        sta    psg_freq_hi
@freq.end\1:
        rmb4   <dmf.player.chn.flag+\1
@next\1:
  .endm

    stz    timer_ctrl

    clx
    stx    <dmf.player.chn
    stx    psg_chn
    dmf.update_psg 0
    ldx    #$01
    stx    <dmf.player.chn
    stx    psg_chn
    dmf.update_psg 1
    ldx    #$02
    stx    <dmf.player.chn
    stx    psg_chn
    dmf.update_psg 2
    ldx    #$03
    stx    <dmf.player.chn
    stx    psg_chn
    dmf.update_psg 3
    ldx    #$04
    stx    <dmf.player.chn
    stx    psg_chn
    dmf.update_psg 4
    ldx    #$05
    stx    <dmf.player.chn
    stx    psg_chn
    dmf.update_psg 5

    lda    #1
    sta    timer_ctrl
    stz    irq_status

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
    tam    #DMF_MATRIX_MPR

    pla
    tam    #DMF_HEADER_MPR
    
    rts

dmf_wav_upload.ex:
    tay
    lda    song.wv.lo, Y
    sta    <dmf.player.si
    lda    song.wv.hi, Y
    sta    <dmf.player.si+1

;;
;; Function: dmf_wav_upload
;;
;; Parameters:
;;
;; Return:
;;
dmf_wav_upload:
    lda    #$01
    sta    psg_ctrl
    stz    psg_ctrl
    cly
@l0:                                ; [todo] unroll?
    lda    [dmf.player.si], Y
    iny
    sta    psg_wavebuf
    cpy    #$20
    bne    @l0

    lda    #$02
    sta    psg_ctrl

    rts

;;
;; Function: dmf_stop_song
;; Stop song.
;;
;; Parameters:
;;
;; Return:
;;
dmf_stop_song:
    ; stop timer
;    lda    #(INT_IRQ2 | INT_TIMER | INT_NMI)
;    sta    irq_disable
    stz    timer_ctrl
    ;  set dmf play disable flag
    smb7   <dmf.player.status
    ; set main volume to 0
    stz    psg_mainvol
    rts

;;
;; Function: dmf_resume_song
;; Resume song.
;;
;; Parameters:
;;
;; Return:
;;
dmf_resume_song:
    ; restart timer
    lda    #$01
    sta    timer_ctrl
    ; reset disable flag
    rmb7   <dmf.player.status
    ; set main volume to max
    lda    #$ff
    sta    psg_mainvol
    rts

;;
;; Function: dmf_load_song
;; Initialize player and load song.
;;
;; Parameters:
;;  Y - Song index.
;;
;; Return:
;;
dmf_load_song:
    jsr    dmf_stop_song

    lda    #%1000_0010
    trb    <dmf.player.status

    ; reset PSG
    clx
@psg_reset:
        stx    psg_chn
        lda    #$ff
        sta    psg_mainvol
        sta    psg_pan
        stz    psg_freq_lo
        stz    psg_freq_hi
        lda    #%01_0_00000
        sta    psg_ctrl
        lda    #%10_0_00000
        sta    psg_ctrl
        stz    psg_noise
        inx
        cpx    #PSG_CHAN_COUNT
        bne    @psg_reset

    tma    #DMF_HEADER_MPR
    pha

    tma    #DMF_MATRIX_MPR
    pha
    
    tma    #DMF_DATA_MPR
    pha
    
    lda    #bank(songs)
    sta    dmf.song.bank
    tam    #DMF_HEADER_MPR
    
    inc    A
    tam    #DMF_MATRIX_MPR

    lda    #low(songs)
    sta    <dmf.player.si

    lda    #high(songs)
    and    #$1f
    ora    #DMF_HEADER_MPR<<5
    sta    <dmf.player.si+1

    bsr    @load_song

    pla
    tam    #DMF_DATA_MPR

    pla
    tam    #DMF_MATRIX_MPR
    
    pla
    tam    #DMF_HEADER_MPR

    rts

;;
;; Function: @load_song
;; Initialize player and load song.
;; The song data rom is assumed to have already been mapped.
;;
;; Parameters:
;;  Y - Song index
;;  player.si - Pointer to songs infos
;;
;; Return:
;;
@load_song:

    sty    dmf.song.id

    lda    song.time_base, Y
    sta    dmf.song.time.base
    lda    song.time_tick_0, Y
    sta    dmf.song.time.tick
    lda    song.time_tick_1, Y
    sta    dmf.song.time.tick+1
    lda    song.pattern_rows, Y
    sta    dmf.song.pattern.rows
    lda    song.matrix_rows, Y
    sta    dmf.song.matrix.rows
    lda    song.instrument_count, Y
    sta    dmf.song.instrument_count
    lda    song.mat.lo, Y
    sta    dmf.song.matrix
    lda    song.mat.hi, Y
    sta    dmf.song.matrix+1
    lda    song.wv.lo, Y
    sta    dmf.song.wav
    lda    song.wv.hi, Y
    sta    dmf.song.wav+1
    lda    song.it.lo, Y
    sta    dmf.song.instruments
    lda    song.it.hi, Y
    sta    dmf.song.instruments+1
    lda    song.sp.lo, Y
    sta    <dmf.player.samples.offset
    lda    song.sp.hi, Y
    sta    <dmf.player.samples.offset+1

    ; initializes player
dmf_reset:
    stz    <dmf.player.ptr
    tii    dmf.player.ptr, dmf.player.ptr+1, dmf.zp.end-dmf.player.ptr-1
    tai    dmf.player.ptr, dmf.player.pattern.bank, dmf.bss.end-dmf.player.pattern.bank ; [todo] cut it if it takes too long

    lda    #$ff
    sta    <dmf.player.psg.main

    sta    <dmf.player.psg.pan
    sta    <dmf.player.psg.pan+1
    sta    <dmf.player.psg.pan+2
    sta    <dmf.player.psg.pan+3
    sta    <dmf.player.psg.pan+4
    sta    <dmf.player.psg.pan+5

    lda    #$7c
    sta    <dmf.player.volume
    sta    <dmf.player.volume+1
    sta    <dmf.player.volume+2
    sta    <dmf.player.volume+3
    sta    <dmf.player.volume+4
    sta    <dmf.player.volume+5

    sta    dmf.player.volume.orig
    sta    dmf.player.volume.orig+1
    sta    dmf.player.volume.orig+2
    sta    dmf.player.volume.orig+3
    sta    dmf.player.volume.orig+4
    sta    dmf.player.volume.orig+5

    lda    #1
    sta    dmf.fx.arp.speed
    sta    dmf.fx.arp.speed+1
    sta    dmf.fx.arp.speed+2
    sta    dmf.fx.arp.speed+3
    sta    dmf.fx.arp.speed+4
    sta    dmf.fx.arp.speed+5

    sta    dmf.fx.arp.tick
    sta    dmf.fx.arp.tick+1
    sta    dmf.fx.arp.tick+2
    sta    dmf.fx.arp.tick+3
    sta    dmf.fx.arp.tick+4
    sta    dmf.fx.arp.tick+5

    ldy    dmf.song.id
    lda    song.wv.first, Y
    tay
    lda    song.wv.lo, Y
    sta    <dmf.player.si
    lda    song.wv.hi, Y
    sta    <dmf.player.si+1

    ; preload wav buffers
    clx
    stx    psg_chn
    jsr    dmf_wav_upload
    inx
    stx    psg_chn
    jsr    dmf_wav_upload
    inx
    stx    psg_chn
    jsr    dmf_wav_upload
    inx
    stx    psg_chn
    jsr    dmf_wav_upload
    inx
    stx    psg_chn
    jsr    dmf_wav_upload
    inx
    stx    psg_chn
    jsr    dmf_wav_upload

    stz    dmf.player.matrix.row

;; Function: dmf_update_matrix
;;
;; Parameters:
;;
;; Return:
;;
dmf_update_matrix:
    lda    <dmf.player.matrix.row
    cmp    dmf.song.matrix.rows
    bcc    @l0
        bbs0    <dmf.player.status, @loop
            smb1   <dmf.player.status
            jmp    dmf_stop_song
@loop:
            jmp    dmf_reset
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

        inx
        cpx    #DMF_CHAN_COUNT
        bne    @set_pattern_ptr

    lda    #1
    sta    <dmf.player.tick
    sta    <dmf.player.tick+1

    inc    <dmf.player.matrix.row

    rts

update_state:                                 ; [todo] find a better name
    stx    <dmf.player.chn

    lda    dmf.player.cut, X
    beq    @delay
        cmp    #$80
        bne    @cut
            stz    dmf.player.cut, X
            jsr    dmf.note_off
            bra    @delay
@cut:
        dec    dmf.player.cut, X
@delay:

    lda    dmf.player.delay, X
    beq    @run
        dec    dmf.player.delay, X
        rts
@run:

    lda    <dmf.player.chn.flag, X
    sta    <dmf.player.al

    ; -- instrument wav
    lda    <dmf.player.chn.flag, X
    bit    #NOI_UPDATE
    bne    @no_wav
      
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

    ; -- fx portamento
    lda    dmf.fx.flag, X
    sta    <dmf.player.ah
    bit    #(FX_PRT_DOWN | FX_PRT_UP | FX_PRT_NOTE_UP | FX_PRT_NOTE_DOWN)
    beq    @no_portamento
        smb4   <dmf.player.al                               ; we'll need to update frequency
        bbr0    <dmf.player.ah, @portamento.1
            sec                                             ; portamento up
            lda    dmf.player.freq.delta.lo, X
            sbc    dmf.fx.prt.speed, X 
            sta    dmf.player.freq.delta.lo, X
            lda    dmf.player.freq.delta.hi, X
            sbc    #$00
            sta    dmf.player.freq.delta.hi, X
            bra    @no_portamento
@portamento.1:
        bbr1    <dmf.player.ah, @portamento.2
            clc                                             ; portamento down
            lda    dmf.player.freq.delta.lo, X
            adc    dmf.fx.prt.speed, X 
            sta    dmf.player.freq.delta.lo, X
            lda    dmf.player.freq.delta.hi, X
            adc    #$00
            sta    dmf.player.freq.delta.hi, X
            bra    @no_portamento
@portamento.2:
        bbr2    <dmf.player.ah, @portamento.3
            sec                                            ; portamento to note (up)
            lda    dmf.player.freq.delta.lo, X
            sbc    dmf.fx.prt.speed, X 
            sta    dmf.player.freq.delta.lo, X
            lda    dmf.player.freq.delta.hi, X
            sbc    #$00
            sta    dmf.player.freq.delta.hi, X
            bpl    @no_portamento
                stz    dmf.player.freq.delta.lo, X
                stz    dmf.player.freq.delta.hi, X
                rmb2   <dmf.player.ah
                bra    @no_portamento
@portamento.3:
            clc                                            ; portamento to note (down)
            lda    dmf.player.freq.delta.lo, X
            adc    dmf.fx.prt.speed, X 
            sta    dmf.player.freq.delta.lo, X
            lda    dmf.player.freq.delta.hi, X
            adc    #$00
            sta    dmf.player.freq.delta.hi, X
            bmi    @no_portamento
                stz    dmf.player.freq.delta.lo, X
                stz    dmf.player.freq.delta.hi, X
                rmb3   <dmf.player.ah
@no_portamento:
    lda    <dmf.player.ah
    sta    dmf.fx.flag, X

    lda    dmf.player.freq.delta.lo, X
    sta    <dmf.player.dl
    lda    dmf.player.freq.delta.hi, X
    sta    <dmf.player.dh

    ; -- vibrato
    bbr4    <dmf.player.ah, @no_vibrato
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
            bne    @freq.check.lo
@freq.check.hi:
            lda    <dmf.player.psg.freq.lo, X
            cmp    #$16
            bcs    @no_freq_update
                lda    #$16
                sta    <dmf.player.psg.freq.lo, X
                bra    @freq.delta.reset
@freq.check.lo:
            cmp    #$0c
            bcc    @no_freq_update
                lda    #$0c
                sta    <dmf.player.psg.freq.hi, X
                lda    #$ba
                sta    <dmf.player.psg.freq.lo, X
@freq.delta.reset:
            sec
            sbc    freq_table.lo, Y
            sta    dmf.player.freq.delta.lo, X
            lda    <dmf.player.psg.freq.hi, X
            sbc    freq_table.hi, Y
            sta    dmf.player.freq.delta.hi, X 
            bra    @no_freq_update
@noise_update:
            ldy    <dmf.player.cl
            lda    noise_table, Y
            sta    <dmf.player.psg.freq.lo, X
@no_freq_update:

    lda    <dmf.player.al
    sta    <dmf.player.chn.flag, X

    lda    dmf.fx.flag, X
    and    #~FX_NOTE
    sta    dmf.fx.flag, X

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
    .dw dmf.note_cut
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
;dmf.portamento_up:
;dmf.portamento_down:
;dmf.portamento_to_note:
;dmf.vibrato:
dmf.vibrato_mode:
dmf.vibrato_depth:
dmf.port_to_note_vol_slide:
dmf.vibrato_vol_slide:
dmf.tremolo:
dmf.set_speed_value1:
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
;dmf.note_cut:
;dmf.note_delay:
dmf.sync_signal:
dmf.fine_tune:
;dmf.global_fine_tune:
;dmf.set_sample_bank:
;dmf.set_volume:
;dmf.set_instrument:
;dmf.note_on:
;dmf.set_samples:
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
dmf.note_cut:
    lda    <dmf.player.pattern.pos
    and    #$01
    tax
    
    lda    [dmf.player.ptr], Y
    iny

    cmp    dmf.song.time.tick, X
    bcs    @note_cut.reset
@note_cut.set:
        ldx    <dmf.player.chn
        ora    #$80
        sta    dmf.player.cut, X
        rts
@note_cut.reset:
    ldx    <dmf.player.chn
    stz    dmf.player.cut, X
    rts

;;------------------------------------------------------------------------------------------
dmf.note_delay:
    lda    <dmf.player.pattern.pos
    and    #$01
    tax
    
    lda    [dmf.player.ptr], Y
    iny

    cmp    dmf.song.time.tick, X
    bcs    @note_delay.reset
@note_delay.set:
        ldx    <dmf.player.chn        
        sta    dmf.player.delay, X
        rts
@note_delay.reset:
    ldx    <dmf.player.chn
    stz    dmf.player.delay, X
    rts

;;------------------------------------------------------------------------------------------
dmf.note_off:
    ldx    <dmf.player.chn
    stz    dmf.fx.flag, X
    stz    dmf.fx.arp.data, X
    stz    dmf.fx.vib.data, X
    stz    dmf.instrument.flag, X
    stz    dmf.player.freq.delta.lo, X
    stz    dmf.player.freq.delta.hi, X
    lda    dmf.player.chn.flag, X
    and    #NOI_UPDATE
    sta    dmf.player.chn.flag, X
    
    lda    dmf.bit, X
    trb    <dmf.player.note_on
    

    lda    <dmf.player.psg.ctrl, X
    and    #%00_0_11111
    sta    <dmf.player.psg.ctrl, X

    rts

dmf.bit:
    .db %0000_0001
    .db %0000_0010
    .db %0000_0100
    .db %0000_1000
    .db %0001_0000
    .db %0010_0000
    .db %0100_0000
    .db %1000_0000
    
;;------------------------------------------------------------------------------------------
dmf.note_on:
    ldx    <dmf.player.chn
    lda    dmf.player.note, X
    sta    dmf.player.note.previous, X

    lda    dmf.bit, X
    tsb    <dmf.player.note_on
    
    lda    [dmf.player.ptr], Y
    sta    dmf.player.note, X
    iny
    
    lda    <dmf.player.chn.flag, X
    bmi    @pcm_reset

    lda    <dmf.player.chn.flag, X
    ora    #FRQ_UPDATE
    sta    <dmf.player.chn.flag, X

    lda    dmf.fx.flag, X
    ora    #FX_NOTE
    sta    dmf.fx.flag, X
    bit    #(FX_PRT_NOTE_UP | FX_PRT_NOTE_DOWN)
    bne    @end
        stz    dmf.player.freq.delta.lo, X
        stz    dmf.player.freq.delta.hi, X
@end:

    stz    dmf.instrument.vol.index, X
    stz    dmf.instrument.arp.index, X
    stz    dmf.instrument.wav.index, X
 
    lda    <dmf.player.psg.ctrl, X
    and    #%00_0_11111
    ora    #%10_0_00000
    sta    <dmf.player.psg.ctrl, X

    lda    dmf.instrument.flag.orig, X
    sta    dmf.instrument.flag, X

    rts

@pcm_reset:
; [todo] hackish
    stz    dmf.instrument.vol.index, X

    lda    #(PSG_CTRL_DDA_ON | PSG_CTRL_FULL_VOLUME)    
    sta    <dmf.player.psg.ctrl, X
    dey
    jmp    dmf.set_samples.ex

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
        ora    #(FRQ_UPDATE | NOI_UPDATE)
        sta    <dmf.player.chn.flag, X

        iny
        rts

@disable_noise_channel:
        lda    <dmf.player.chn.flag, X
        and    #~NOI_UPDATE
        ora    #FRQ_UPDATE
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
    sta    dmf.instrument.flag.orig, X
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

    stz    dmf.fx.vib.tick, X

    lda    [dmf.player.ptr], Y
    sta    dmf.fx.vib.data, X
    beq    @none
        lda    dmf.fx.flag, X
        ora    #FX_VIBRATO
        sta    dmf.fx.flag, X
    
        iny
        rts
@none:
        lda    dmf.fx.flag, X
        and    #~FX_VIBRATO
        sta    dmf.fx.flag, X

        iny
        rts

;;------------------------------------------------------------------------------------------
dmf.portamento_up:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y    
    sta    dmf.fx.prt.speed, X
    beq    @stop
        lda    dmf.fx.flag, X
        and    #~(FX_PRT_UP|FX_PRT_DOWN)
        ora    #FX_PRT_UP
        sta    dmf.fx.flag, X

        iny
        rts
@stop:
    lda    dmf.fx.flag, X
    and    #~(FX_PRT_UP|FX_PRT_DOWN)
    sta    dmf.fx.flag, X

    stz    dmf.player.freq.delta.lo, X
    stz    dmf.player.freq.delta.hi, X

    iny
    rts

;;------------------------------------------------------------------------------------------
dmf.portamento_down:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y    
    sta    dmf.fx.prt.speed, X
    beq    @stop
        lda    dmf.fx.flag, X
        and    #~(FX_PRT_UP|FX_PRT_DOWN)
        ora    #FX_PRT_DOWN
        sta    dmf.fx.flag, X

        iny
        rts
@stop:
    lda    dmf.fx.flag, X
    and    #~(FX_PRT_UP|FX_PRT_DOWN)
    sta    dmf.fx.flag, X

    stz    dmf.player.freq.delta.lo, X
    stz    dmf.player.freq.delta.hi, X

    iny
    rts

;;------------------------------------------------------------------------------------------
dmf.portamento_to_note:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    sta    dmf.fx.prt.speed, X
    beq    @portamento_to_note.skip
        ; check if we had a new note was triggered
        lda    dmf.fx.flag, X
        bpl    @portamento_to_note.skip
            lda    dmf.player.note.previous, X
            cmp    dmf.player.note, X
            beq    @portamento_to_note.skip
            iny
            phy
            pha

            lda    dmf.player.psg.freq.lo, X
            sta    <dmf.player.al
            lda    dmf.player.psg.freq.hi, X
            sta    <dmf.player.ah
            ora    <dmf.player.al
            bne    @portamento_to_note.compute
                ldy    dmf.player.note.previous, X
                lda    freq_table.lo, Y
                sta    <dmf.player.al
                lda    freq_table.hi, Y
                sta    <dmf.player.ah
@portamento_to_note.compute:
            ldy    dmf.player.note, X
            sec
            lda    <dmf.player.al
            sbc    freq_table.lo, Y
            sta    dmf.player.freq.delta.lo, X
            lda    <dmf.player.ah
            sbc    freq_table.hi, Y
            sta    dmf.player.freq.delta.hi, X

            pla 
            cmp    dmf.player.note, X
            bcc    @portamento_to_note.up
@portamento_to_note.down:
                lda    dmf.fx.flag, X
                and    #~(FX_PRT_NOTE_UP|FX_PRT_NOTE_DOWN)
                ora    #FX_PRT_NOTE_DOWN
                sta    dmf.fx.flag, X

                ply
                rts
@portamento_to_note.up:
                lda    dmf.fx.flag, X
                and    #~(FX_PRT_NOTE_UP|FX_PRT_NOTE_DOWN)
                ora    #FX_PRT_NOTE_UP
                sta    dmf.fx.flag, X

                ply
                rts 
@portamento_to_note.skip:
    lda    dmf.fx.flag, X
    and    #~(FX_PRT_NOTE_UP|FX_PRT_NOTE_DOWN)
    sta    dmf.fx.flag, X

    stz    dmf.player.freq.delta.lo, X
    stz    dmf.player.freq.delta.hi, X

    iny
    rts

;;------------------------------------------------------------------------------------------
dmf.panning:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    iny
    sta    <dmf.player.psg.pan, X


    lda    <dmf.player.chn.flag, X 
    ora    #PAN_UPDATE
    sta    <dmf.player.chn.flag, X

    rts

;;------------------------------------------------------------------------------------------
dmf.set_sample_bank:
    ldx    <dmf.player.chn
    lda    [dmf.player.ptr], Y

    ; mul 12
    sta    dmf.pcm.bank, X
    asl    A
    clc
    adc    dmf.pcm.bank, X
    asl    A
    asl    A
    sta    dmf.pcm.bank, X

    lda    <dmf.player.chn.flag, X
    bit    #PCM_UPDATE
    bne    dmf.set_samples.ex

    iny
    rts

;;------------------------------------------------------------------------------------------
dmf.set_samples:
    ldx    <dmf.player.chn

    lda    [dmf.player.ptr], Y
    beq    dmf.pcm.disable
@pcm.enable:
        lda    <dmf.player.chn.flag, X
        and    #PAN_UPDATE
        ora    #PCM_UPDATE
        sta    <dmf.player.chn.flag, X      ; deactivate frequency effects

        stz    dmf.instrument.flag, X       ; only use instrument volume

        lda    dmf.fx.flag, X               ; only use volume slide and vibrato
        and    #FX_VIBRATO
        sta    dmf.fx.flag, X

        ; enable dda
        ; [todo] volume
        lda    #$7f
        sta    dmf.player.volume, X
;        lsr    A
;        lsr    A
;        ora    #PSG_CTRL_DDA_ON
        lda    #(PSG_CTRL_DDA_ON | PSG_CTRL_FULL_VOLUME)    
        sta    <dmf.player.psg.ctrl, X

        lda    dmf.bit, X
        bit    <dmf.player.note_on
        bne    dmf.set_samples.ex
            iny
            rts
dmf.set_samples.ex:
        lda    dmf.player.note, X
        phy
        tay
        lda    modulo_12, Y
        clc
        adc    dmf.pcm.bank, X
        tay

        lda    [dmf.player.samples.offset], Y
        tay
        lda    song.sp.data.bank, Y
        sta    dmf.pcm.src.bank, X

        txa
        asl    A
        tax

        lda    song.sp.data.lo, Y
        sta    dmf.pcm.src.ptr, X
        lda    song.sp.data.hi, Y
        sta    dmf.pcm.src.ptr+1, X

        ply

        iny
        rts

dmf.pcm.disable:
    lda    <dmf.player.chn.flag, X
    and    #$7f
    sta    <dmf.player.chn.flag, X

    lda    dmf.bit, X
    trb    <dmf.player.note_on

    iny
    rts

;;------------------------------------------------------------------------------------------
    .macro dmf_pcm_update.ch
@pcm.ch\1:
    bbr\1   <dmf.player.pcm.state,  @pcm.ch\1.end
        lda    <dmf.player.pcm.bank+\1
        tam    #DMF_DATA_MPR

        lda    [dmf.player.pcm.ptr+(2*\1)]
        cmp    #$ff
        bne    @pcm.ch\1.update
            bra    @pcm.ch\1.end
@pcm.ch\1.update:
        ldx    #\1
        stx    psg_chn

        sta    psg_wavebuf

        inc    <dmf.player.pcm.ptr+(2*\1)
        bne    @l\1
            inc    <dmf.player.pcm.ptr+(1+2*\1)
            lda    <dmf.player.pcm.ptr+(1+2*\1)
            and    #%111_00000
            cmp    #(DMF_DATA_MPR << 5)
            bcc    @l\1
            beq    @l\1
                lda    <dmf.player.pcm.ptr+(1+2*\1)
                and    #$1f
                ora    #(DMF_DATA_MPR << 5)
                sta    <dmf.player.pcm.ptr+(1+2*\1)
                inc    <dmf.player.pcm.bank+\1
@l\1: 
@pcm.ch\1.end:
    .endm

;;------------------------------------------------------------------------------------------
dmf_pcm_update:
    tma    #DMF_DATA_MPR
    pha
    
    dmf_pcm_update.ch 0
    dmf_pcm_update.ch 1
    dmf_pcm_update.ch 2
    dmf_pcm_update.ch 3
    dmf_pcm_update.ch 4
    dmf_pcm_update.ch 5

    pla
    tam    #DMF_DATA_MPR

    lda    <dmf.player.chn
    sta    psg_chn

    rts
;;------------------------------------------------------------------------------------------
modulo_12:
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b
    .db $00,$01,$02,$03
    
dmf.player.end:
