;;---------------------------------------------------------------------
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

    .zp
_si         .ds 2
_vdc_reg    .ds 1
_vdc_crl    .ds 1

; player specific variables
_current_row        .ds 1
_current_time_base  .ds 1
_current_time_tick  .ds 1
_time_base          .ds 1
_time_tick          .ds 2
_pattern_ptr.lo     .ds PSG_CHAN_COUNT
_pattern_ptr.hi     .ds PSG_CHAN_COUNT

;;---------------------------------------------------------------------
; Song effects.
Arpeggio           = $00
PortamentoUp       = $01
PortamentoDown     = $02
PortamentoToNote   = $03
Vibrato            = $04
PortToNoteVolSlide = $05
VibratoVolSlide    = $06
Tremolo            = $07
Panning            = $08
SetSpeedValue1     = $09
VolumeSlide        = $0a
PositionJump       = $0b
Retrig             = $0c
PatternBreak       = $0d
ExtendedCommands   = $0e
SetSpeedValue2     = $0f
SetWave            = $10
EnableNoiseChannel = $11
SetLFOMode         = $12
SetLFOSpeed        = $13
EnableSampleOutput = $17
SetVolume          = $1a
SetInstrument      = $1b
Note               = $20 ; Set note+octave
NoteOff            = $21
RestEx             = $79 ; For values >= 128
Rest               = $80 ; For values between 0 and 127

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

    .code
    .bank 0
        .org $E000

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

; base time = time base
; time even / time odd = tick time 1 / tick time 2


irq_2:
    rti

irq_1:
    lda    video_reg             ; get VDC status register
    and    #%0010_0000
    beq    .no_vsync
        jsr    update_song
.no_vsync:
    stz    video_reg
    rti

irq_timer:
    rti

irq_nmi:
    rti

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
    sta    <_vdc_crl
    sta    video_data_l
    st2    #$00


    lda    #$06
    sta    <_time_base
    lda    #$04
    sta    <_time_tick
    lda    #$08
    sta    <_time_tick+1
   
    lda    <_time_base
    sta    <_current_time_base
    lda    <_time_tick
    sta    <_current_time_tick
    lda    #$00
    sta    <_current_row
    
    cli

.loop:
    bra    .loop

    nop
    nop
    nop
    nop

;;---------------------------------------------------------------------
; name : update_song
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
update_song:
    lda    <_current_time_base
    beq    .update_time_base
        dec    <_current_time_base
        ; [todo] update states
        rts
.update_time_base:
    lda    <_time_base
    sta    <_current_time_base
    
    lda    <_current_time_tick
    beq    .update_internal
        dec    <_current_time_tick
        ; [todo] update states
        rts
.update_internal:
    inc    <_current_row
    lda    <_current_row
    and    #$01
    tax
    lda    <_time_tick, X
    sta    <_current_time_tick

    ; Load note, effects, delay for each channel
    ldx    #(PSG_CHAN_COUNT-1)
.load:
    lda    <_pattern_ptr.lo, X
    sta    <_si
    lda    <_pattern_ptr.hi, X
    sta    <_si+1
    
    ; Loop until we hit one of the rest effects
    cly
.load_loop:
    lda    [_si], Y
    
    ; [todo] load another byte if effect is not noteOff or rest
    
    iny
    cmp    RestEx
    bcc    .load_loop

    ; Move pattern pointer to the next entry
    tya
    clc
    adc    <_pattern_ptr.lo, X
    sta    <_pattern_ptr.lo, X
    lda    <_pattern_ptr.hi, X
    adc    #$00
    sta    <_pattern_ptr.hi, X

    dex
    bpl    .load

    ; [todo] update states
    rts

pattern_data_00:
    .db $20,$c2,$1a,$06,$1b,$01,$0a,$10,$10,$01,$8f,$20,$62,$1a,$15,$1b
    .db $00,$0a,$10,$10,$00,$8f

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
