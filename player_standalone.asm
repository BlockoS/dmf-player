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
_pattern_index      .ds 1
_tone               .ds PSG_CHAN_COUNT
_frequency.lo       .ds PSG_CHAN_COUNT
_frequency.hi       .ds PSG_CHAN_COUNT
_pattern_ptr.lo     .ds PSG_CHAN_COUNT
_pattern_ptr.hi     .ds PSG_CHAN_COUNT
_rest               .ds PSG_CHAN_COUNT
_wave_table_ptr.lo  .ds 2
_wave_table_ptr.hi  .ds 2

; [todo] move to .bss ?
_wave_copy          .ds 1 ; tin
_wave_copy_src      .ds 2
_wave_copy_dst      .ds 2
_wave_copy_len      .ds 2
_wave_copy_rts      .ds 1 ; rts

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

    lda    #$00
    sta    <_time_base
    lda    #$05
    sta    <_time_tick
    lda    #$03
    sta    <_time_tick+1
   
    lda    <_time_base
    sta    <_current_time_base
    lda    <_time_tick
    sta    <_current_time_tick
    lda    #$00
    sta    <_current_row

    clx
.l1:
    lda    #low(song.pattern_0006)
    sta    <_pattern_ptr.lo, X
    lda    #high(song.pattern_0006)
    sta    <_pattern_ptr.hi, X

    stx    psg_ch
    lda    #$ff
    sta    psg_mainvol
    sta    psg_pan

    inx
    cpx    #PSG_CHAN_COUNT
    bne    .l1
    
    lda    #low(song.wav.lo)
    sta    <_wave_table_ptr.lo
    lda    #high(song.wav.lo)
    sta    <_wave_table_ptr.lo+1
    
    lda    #low(song.wav.hi)
    sta    <_wave_table_ptr.hi
    lda    #high(song.wav.hi)
    sta    <_wave_table_ptr.hi+1

    lda    song.patternRows
    sta    <_pattern_index

    jsr    init_player

    cli

.loop:
    bra    .loop

    nop
    nop
    nop
    nop

;;---------------------------------------------------------------------
; name : init_player
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
init_player:
    ; [todo] song index and setup pointers

    ; setup wave copy
    lda    #$d3                 ; tin
    sta    <_wave_copy
    lda    #32
    sta    <_wave_copy_len
    stz    <_wave_copy_len+1
    lda    #$60                 ; rts
    sta    <_wave_copy_rts
    lda    #low(psg_wavebuf)
    sta    <_wave_copy_dst
    lda    #high(psg_wavebuf)
    sta    <_wave_copy_dst+1
    
    clx
.loop:
    ; reset rest
    stz    <_rest, X
    ; enable channel
    stx    psg_ch
    lda    #%10_0_11111
    sta    psg_ctrl
    inx
    cpx    #PSG_CHAN_COUNT
    bne    .loop

    rts

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
    
    dec    <_current_time_tick
    beq    .update_internal
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
_update_song_load:
    lda    <_rest, X
    beq    _update_song_load_start
        dec    <_rest, X
        bra    _update_song_next_chan
_update_song_load_start:
    stx    psg_ch

    lda    <_pattern_ptr.lo, X
    sta    <_si
    lda    <_pattern_ptr.hi, X
    sta    <_si+1
    
    ; Loop until we hit one of the rest effects
    cly
_update_song_load_loop:
    lda    [_si], Y
    iny
    cmp    #RestEx
    bcs    .rest
        asl    A
        phx
        sax
        jmp    [fx_load_table, X]
.rest:
    beq    .extended_rest
        and    #$7f
        bra    .store_rest
.extended_rest:
        lda    [_si], Y
        iny
.store_rest:
    sta    <_rest, X
    
    ; Move pattern pointer to the next entry
    tya
    clc
    adc    <_pattern_ptr.lo, X
    sta    <_pattern_ptr.lo, X
    lda    <_pattern_ptr.hi, X
    adc    #$00
    sta    <_pattern_ptr.hi, X

_update_song_next_chan:
    dex
    bpl    _update_song_load

_update_song_pattern_index:
    dec    <_pattern_index
    bne    .continue
.fetch_next_pattern:
        lda    song.patternRows     ;       [todo]
        sta    <_pattern_index
        ; [todo] load next pattern
        lda    #low(song.pattern_0006)  ; [todo]
        sta    <_pattern_ptr.lo         ; [todo]
        sta    <_pattern_ptr.lo+1       ; [todo]
        sta    <_pattern_ptr.lo+2       ; [todo]
        sta    <_pattern_ptr.lo+3       ; [todo]
        sta    <_pattern_ptr.lo+4       ; [todo]
        sta    <_pattern_ptr.lo+5       ; [todo]
        lda    #high(song.pattern_0006) ; [todo]
        sta    <_pattern_ptr.hi         ; [todo]
        sta    <_pattern_ptr.hi+1       ; [todo]
        sta    <_pattern_ptr.hi+2       ; [todo]
        sta    <_pattern_ptr.hi+3       ; [todo]
        sta    <_pattern_ptr.hi+4       ; [todo]
        sta    <_pattern_ptr.hi+5       ; [todo]
.continue:

    ; [todo] update states
    rts

load_arpeggio:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_portamento_up:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_portamento_down:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_portamento_to_note:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_vibrato:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_port_to_note_vol_slide:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_vibrato_vol_slide:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_tremolo:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_panning:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_set_speed_value1:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_volume_slide:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_position_jump:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_retrig:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_pattern_break:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_extended_commands:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_set_speed_value2:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

;;---------------------------------------------------------------------
; name : load_set_wave
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
load_set_wave:
    ; Load wave index.
    lda    [_si], Y
    iny
    phy
    
    ; A contains the index of the wave table to be loaded.
    tay
    lda    [_wave_table_ptr.lo], Y
    sta    <_wave_copy_src
    lda    [_wave_table_ptr.hi], Y
    sta    <_wave_copy_src+1
    
    ; Reset write index
    lda    #%01_0_00000
    sta    psg_ctrl

    ; Enable write buffer
    stz    psg_ctrl
    
    ; Copy wave buffer
    jsr    _wave_copy
    
    ; [todo] restore psg_ctrl
    lda    #%10_0_11111
    sta    psg_ctrl

    ply
    plx
    jmp    _update_song_load_loop

load_enable_noise_channel:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_set_LFO_mode:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_set_LFO_speed:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_enable_sample_output:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_set_volume:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_set_instrument:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

;;---------------------------------------------------------------------
; name : load_note
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
load_note:
    ; Load octave+note
    lda    [_si], Y
    iny
    
    ; Retrieve channel index.
    plx

    phy
    
    ; Save octave+note and retrieve frequency
    sta    <_tone, X
    tay

    lda    freq_table.lo, Y
    sta    <_frequency.lo, X
    sta    psg_freq.lo

    lda    freq_table.hi, Y
    sta    <_frequency.hi, X
    sta    psg_freq.hi

    ply

    jmp    _update_song_load_loop

load_undefined:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

load_note_off:
    lda    #%00_0_00000
    sta    psg_ctrl
    plx
    jmp    _update_song_load_loop

fx_load_table:
    .dw load_arpeggio
    .dw load_portamento_up
    .dw load_portamento_down
    .dw load_portamento_to_note
    .dw load_vibrato
    .dw load_port_to_note_vol_slide
    .dw load_vibrato_vol_slide
    .dw load_tremolo
    .dw load_panning
    .dw load_set_speed_value1
    .dw load_volume_slide
    .dw load_position_jump
    .dw load_retrig
    .dw load_pattern_break
    .dw load_extended_commands
    .dw load_set_speed_value2
    .dw load_set_wave
    .dw load_enable_noise_channel
    .dw load_set_LFO_mode
    .dw load_set_LFO_speed
    .dw load_undefined
    .dw load_undefined
    .dw load_undefined
    .dw load_enable_sample_output
    .dw load_undefined
    .dw load_undefined
    .dw load_set_volume
    .dw load_set_instrument
    .dw load_undefined
    .dw load_undefined
    .dw load_undefined
    .dw load_undefined
    .dw load_note
    .dw load_note_off

; [todo::begin] dummy song
song.pattern_0000:
    .db $20,$22,$1a,$1f,$1b,$00,$10,$00,$0a,$0c,$81,$20,$22,$1a,$1f,$81
    .db $20,$32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20
    .db $32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22
    .db $1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22,$1a
    .db $1f,$81,$20,$32,$1a,$1f,$81,$20,$25,$1a,$1f,$81,$20,$29,$1a,$1f
    .db $81,$20,$30,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$22,$1a,$1f,$81
    .db $20,$32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20
    .db $32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22
    .db $1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22,$1a
    .db $1f,$81,$20,$32,$1a,$1f,$81,$20,$25,$1a,$1f,$81,$20,$29,$1a,$1f
    .db $81,$20,$30,$1a,$1f,$81
song.pattern_0001:
    .db $20,$22,$1a,$1f,$1b,$00,$10,$00,$0a,$0c,$81,$20,$22,$1a,$1f,$81
    .db $20,$32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20
    .db $32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22
    .db $1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22,$1a
    .db $1f,$81,$20,$32,$1a,$1f,$81,$20,$25,$1a,$1f,$81,$20,$29,$1a,$1f
    .db $81,$20,$30,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$22,$1a,$1f,$81
    .db $20,$32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20
    .db $32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22
    .db $1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22,$1a
    .db $1f,$81,$20,$32,$1a,$1f,$87
song.pattern_0002:
    .db $20,$22,$1a,$1f,$1b,$00,$10,$01,$0a,$05,$81,$20,$22,$1a,$1f,$81
    .db $20,$32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20
    .db $32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22
    .db $1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22,$1a
    .db $1f,$81,$20,$32,$1a,$1f,$81,$20,$25,$1a,$1f,$81,$20,$29,$1a,$1f
    .db $81,$20,$30,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$22,$1a,$1f,$81
    .db $20,$32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20
    .db $32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22
    .db $1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22,$1a
    .db $1f,$81,$20,$32,$1a,$1f,$81,$20,$25,$1a,$1f,$81,$20,$29,$1a,$1f
    .db $81,$20,$30,$1a,$1f,$81
song.pattern_0003:
    .db $20,$22,$1a,$1f,$1b,$00,$10,$01,$0a,$05,$81,$20,$22,$1a,$1f,$81
    .db $20,$32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20
    .db $32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22
    .db $1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22,$1a
    .db $1f,$81,$20,$32,$1a,$1f,$81,$20,$25,$1a,$1f,$81,$20,$29,$1a,$1f
    .db $81,$20,$30,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$22,$1a,$1f,$81
    .db $20,$32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20
    .db $32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22
    .db $1a,$1f,$8f
song.pattern_0004:
    .db $20,$29,$1a,$1f,$1b,$00,$0a,$08,$10,$01,$81,$20,$29,$1a,$1f,$1b
    .db $00,$81,$20,$29,$1a,$1f,$1b,$00,$81,$20,$29,$1a,$1f,$1b,$00,$81
    .db $20,$29,$1a,$1f,$1b,$00,$81,$20,$39,$1a,$1f,$1b,$00,$81,$20,$29
    .db $1a,$1f,$1b,$00,$81,$20,$39,$1a,$1f,$1b,$00,$81,$20,$29,$1a,$1f
    .db $1b,$00,$81,$20,$29,$1a,$1f,$1b,$00,$81,$20,$29,$1a,$1f,$1b,$00
    .db $81,$20,$29,$1a,$1f,$1b,$00,$81,$20,$29,$1a,$1f,$1b,$00,$81,$20
    .db $39,$1a,$1f,$1b,$00,$81,$20,$29,$1a,$1f,$1b,$00,$81,$20,$39,$1a
    .db $1f,$1b,$00,$81,$20,$30,$1a,$1f,$1b,$00,$81,$20,$30,$1a,$1f,$1b
    .db $00,$81,$20,$30,$1a,$1f,$1b,$00,$81,$20,$30,$1a,$1f,$1b,$00,$81
    .db $20,$30,$1a,$1f,$1b,$00,$81,$20,$40,$1a,$1f,$1b,$00,$81,$20,$30
    .db $1a,$1f,$1b,$00,$81,$20,$40,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f
    .db $1b,$00,$81,$20,$25,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f,$1b,$00
    .db $81,$20,$25,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f,$1b,$00,$81,$20
    .db $35,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f,$1b,$00,$81,$20,$35,$1a
    .db $1f,$1b,$00,$81
song.pattern_0005:
    .db $20,$22,$1a,$1f,$1b,$00,$10,$01,$0a,$05,$81,$20,$22,$1a,$1f,$81
    .db $20,$32,$1a,$1f,$81,$20,$22,$1a,$1f,$81,$20,$22,$1a,$1f,$1b,$00
    .db $10,$01,$0a,$05,$81,$20,$22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20
    .db $22,$1a,$1f,$81,$20,$22,$1a,$1f,$1b,$00,$10,$01,$0a,$05,$81,$20
    .db $22,$1a,$1f,$81,$20,$32,$1a,$1f,$81,$20,$22,$1a,$1f,$a9
song.pattern_0006:
    .db $20,$25,$1a,$1f,$1b,$00,$10,$01,$0a,$05,$81,$20,$25,$1a,$1f,$1b
    .db $00,$81,$20,$35,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f,$1b,$00,$81
    .db $20,$35,$1a,$1f,$1b,$00,$81,$20,$35,$1a,$1f,$1b,$00,$81,$20,$25
    .db $1a,$1f,$1b,$00,$81,$20,$35,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f
    .db $1b,$00,$81,$20,$25,$1a,$1f,$1b,$00,$81,$20,$35,$1a,$1f,$1b,$00
    .db $81,$20,$25,$1a,$1f,$1b,$00,$81,$20,$35,$1a,$1f,$1b,$00,$81,$20
    .db $35,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f,$1b,$00,$81,$20,$35,$1a
    .db $1f,$1b,$00,$81,$20,$25,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f,$1b
    .db $00,$81,$20,$35,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f,$1b,$00,$81
    .db $20,$35,$1a,$1f,$1b,$00,$81,$20,$35,$1a,$1f,$1b,$00,$81,$20,$25
    .db $1a,$1f,$1b,$00,$81,$20,$35,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f
    .db $1b,$00,$81,$20,$25,$1a,$1f,$1b,$00,$81,$20,$35,$1a,$1f,$1b,$00
    .db $81,$20,$25,$1a,$1f,$1b,$00,$81,$20,$35,$1a,$1f,$1b,$00,$81,$20
    .db $35,$1a,$1f,$1b,$00,$81,$20,$25,$1a,$1f,$1b,$00,$81,$20,$35,$1a
    .db $1f,$1b,$00,$81
    
song.patternRows: .db $40

song.wav.lo:
    .dwl song.wav_0000,song.wav_0001,song.wav_0002
song.wav.hi:
    .dwh song.wav_0000,song.wav_0001,song.wav_0002
song.wav_0000:
    .db $18,$18,$18,$19,$19,$19,$19,$19,$19,$19,$19,$19,$18,$18,$18,$16
    .db $16,$15,$17,$14,$13,$12,$11,$0f,$0e,$0d,$0c,$0d,$0b,$08,$04,$02
song.wav_0001:
    .db $1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
song.wav_0002:
    .db $00,$00,$04,$04,$08,$08,$0c,$0c,$10,$10,$14,$14,$18,$18,$1c,$1c
    .db $1c,$1c,$18,$18,$14,$14,$10,$10,$0c,$0c,$08,$08,$04,$04,$00,$00
; [todo::end] dummy song

    .include "frequency.inc"

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
