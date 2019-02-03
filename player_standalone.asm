; Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
; Copyrights licensed under the New BSD License. 
; See the accompanying LICENSE file for terms.
;;---------------------------------------------------------------------


; base time = time base
; time even / time odd = tick time 1 / tick time 2


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
_si         .ds 2               ; [todo] review usage
_vdc_reg    .ds 1
_vdc_crl    .ds 1

; player specific variables
_tmp                .ds 1
_ptr                .ds 2
_current_row        .ds 1
_current_time_base  .ds 1
_current_time_tick  .ds 1

_pattern_rows       .ds 1
_matrix_index       .ds 1
_matrix_rows        .ds 1
_arpeggio_speed     .ds 1

_tone               .ds PSG_CHAN_COUNT
_volume             .ds PSG_CHAN_COUNT
_frequency.lo       .ds PSG_CHAN_COUNT
_frequency.hi       .ds PSG_CHAN_COUNT
_state              .ds PSG_CHAN_COUNT
_update             .ds 1

_wave_table_ptr.lo  .ds 2
_wave_table_ptr.hi  .ds 2

_pattern_ptr_table.lo .ds 2
_pattern_ptr_table.hi .ds 2

_matrix_ptr:
_matrix_ptr_ch0     .ds 2
_matrix_ptr_ch1     .ds 2
_matrix_ptr_ch2     .ds 2
_matrix_ptr_ch3     .ds 2
_matrix_ptr_ch4     .ds 2
_matrix_ptr_ch5     .ds 2

_fx_volume_delta    .ds PSG_CHAN_COUNT
_fx_tone_delta      .ds PSG_CHAN_COUNT

_arpeggio_ptr.lo    .ds PSG_CHAN_COUNT
_arpeggio_ptr.hi    .ds PSG_CHAN_COUNT

	.bss
_time_base          .ds 1
_time_tick          .ds 2

_pattern_ptr.lo     .ds PSG_CHAN_COUNT
_pattern_ptr.hi     .ds PSG_CHAN_COUNT

_delay              .ds PSG_CHAN_COUNT

_volume.base        .ds PSG_CHAN_COUNT

_inst.arpeggio.index .ds PSG_CHAN_COUNT
_inst.arpeggio.lo    .ds PSG_CHAN_COUNT
_inst.arpeggio.hi    .ds PSG_CHAN_COUNT
_inst.arpeggio.size  .ds PSG_CHAN_COUNT
_inst.arpeggio.loop  .ds PSG_CHAN_COUNT
; [todo] instrument arpeggio mode

_inst.volume.index  .ds PSG_CHAN_COUNT
_inst.volume.lo     .ds PSG_CHAN_COUNT
_inst.volume.hi     .ds PSG_CHAN_COUNT
_inst.volume.size   .ds PSG_CHAN_COUNT
_inst.volume.loop   .ds PSG_CHAN_COUNT

; [todo] instrument wave

_wave_copy          .ds 1 ; tin
_wave_copy_src      .ds 2
_wave_copy_dst      .ds 2
_wave_copy_len      .ds 2
_wave_copy_rts      .ds 1 ; rts


_fixed_arpeggio     .ds PSG_CHAN_COUNT*4

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
;
;;---------------------------------------------------------------------
PlayerStateInactive        = %00000000
PlayerStateUpdateNote      = %00000001
PlayerStateUpdateFrequency = %00000010
PlayerStateVolume          = %00000100

;;---------------------------------------------------------------------
; name : get_next_pattern
; desc : Get pattern index from matrix and setup pattern pointer.
; in   : \1 Channel index
;;---------------------------------------------------------------------
    .macro get_next_pattern
    ldy    _matrix_index
    lda    [_matrix_ptr+(\1<<1)], Y
    tay
    lda    [_pattern_ptr_table.lo], Y
    sta    _pattern_ptr.lo+\1
    lda    [_pattern_ptr_table.hi], Y
    sta    _pattern_ptr.hi+\1
    .endm

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
        jsr    update_song
		
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
    sta    <_vdc_crl
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

    lda    #$01
    tam    #2

    lda    #low(song)
    sta    <_si
    lda    #high(song)
    sta    <_si+1
    jsr    load_song

    cli

.loop:
    bra    .loop

    nop
    nop
    nop
    nop

;;---------------------------------------------------------------------
; name : load_song
; desc : Initialize player and load song
; in   : <_si Pointer to song data
; out  : 
;;---------------------------------------------------------------------
load_song:
    ; setup wave copy
    lda    #$d3                 ; tin
    sta    _wave_copy
    lda    #32
    sta    _wave_copy_len
    stz    _wave_copy_len+1
    lda    #$60                 ; rts
    sta    _wave_copy_rts
    lda    #low(psg_wavebuf)
    sta    _wave_copy_dst
    lda    #high(psg_wavebuf)
    sta    _wave_copy_dst+1
    
    ; load time infos and reset current time base and tick
    cly
    lda    [_si], Y
    iny
    sta    _time_base
    sta    <_current_time_base

    lda    [_si], Y
    iny
    sta    _time_tick
    sta    <_current_time_tick
    lda    [_si], Y
    iny
    sta    _time_tick+1
    
    
    ; load pattern and matrix row count
    lda    [_si], Y
    iny
    sta    _pattern_rows
    stz    _current_row
    lda    [_si], Y
    iny
    sta    _matrix_rows
    stz    _matrix_index
    
    ; load arpeggio speed
    lda    [_si], Y
    iny
    sta    _arpeggio_speed

    ; setup pointers
    lda    [_si], Y
    iny
    sta    <_wave_table_ptr.lo
    lda    [_si], Y
    iny
    sta    <_wave_table_ptr.lo+1
    lda    [_si], Y
    iny
    sta    <_wave_table_ptr.hi
    lda    [_si], Y
    iny
    sta    <_wave_table_ptr.hi+1

    ; load pattern table pointer
    lda    [_si], Y
    iny
    sta    <_pattern_ptr_table.lo
    lda    [_si], Y
    iny
    sta    <_pattern_ptr_table.lo+1
    lda    [_si], Y
    iny
    sta    <_pattern_ptr_table.hi
    lda    [_si], Y
    iny
    sta    <_pattern_ptr_table.hi+1

    ; load matrix pointers
    clx
.l0:
    lda    [_si],Y
    iny
    sta    _matrix_ptr,X
    inx
    cpx    #(PSG_CHAN_COUNT*2)
    bne    .l0
    
    lda #$ff
    sta psg_mainvol
 
    clx
.l1:
    ; reset delay
    stz    _delay, X

    stx    psg_ch
    stz    psg_ctrl

    lda    #$ff
    sta    psg_pan

    lda    #$7c    
    sta    _volume.base, X
    
    inx
    cpx    #PSG_CHAN_COUNT
    bne    .l1

    get_next_pattern 0
    get_next_pattern 1
    get_next_pattern 2
    get_next_pattern 3
    get_next_pattern 4
    get_next_pattern 5

    rts

;;---------------------------------------------------------------------
; name : update_song
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
update_song:
    dec    <_current_time_base
    bmi    .reset_time_base
        jmp    update_states
        
.reset_time_base:
    lda    _time_base
    sta    <_current_time_base
    
    dec    <_current_time_tick
    beq    .update_internal
        jmp    update_states
        
.update_internal:
    lda    <_current_row
    inc    <_current_row
    and    #$01
    tax
    lda    _time_tick, X
    sta    <_current_time_tick

    ; Load note, effects, delay for each channel
    clx
_update_song_load:
    lda    _delay, X
    beq    _update_song_load_start
        dec    _delay, X
        bra    _update_song_next_chan
        
_update_song_load_start:
    stx    psg_ch

    lda    _pattern_ptr.lo, X
    sta    <_si
    lda    _pattern_ptr.hi, X
    sta    <_si+1
    
    ; Loop until we hit one of the rest effects
    cly
_update_song_load_loop:
    lda    [_si], Y
    iny
    cmp    #RestEx
    bcs    .delay
        asl    A
        phx
        sax
        jmp    [fx_load_table, X]
.delay:
    beq    .extended_delay
        and    #$7f
        bra    .store_delay
.extended_delay:
        lda    [_si], Y
        iny
.store_delay:
    sta    _delay, X
    
    ; Move pattern pointer to the next entry
    tya
    clc
    adc    _pattern_ptr.lo, X
    sta    _pattern_ptr.lo, X
	bcc    .l2
        inc    _pattern_ptr.hi, X
.l2:

_update_song_next_chan:
    inx
    cpx    #PSG_CHAN_COUNT
    bne    _update_song_load

_update_song_pattern_index:
    lda    <_current_row
    cmp    _pattern_rows
    bne    .continue
.fetch_next_pattern:
        stz    <_current_row

        inc    _matrix_index
        lda    _matrix_index
        cmp    _matrix_rows
        bne    .update_patterns
            ; [todo] reset stuffs just as load_song
            stz    _matrix_index
.update_patterns:
        get_next_pattern 0
        get_next_pattern 1
        get_next_pattern 2
        get_next_pattern 3
        get_next_pattern 4
        get_next_pattern 5
.continue:

update_states:

    ldx    #(PSG_CHAN_COUNT-1)
.start:
    lda    <_state, X
    sta    <_tmp

    bbr0   <_tmp, .todo
.inst_volume:
    lda    _inst.volume.index, X
    cmp    _inst.volume.size, X
    bne    @l1
        lda    _inst.volume.loop, X
        cmp    #$ff
        bne    @l2
            rmb0   <_tmp
            stz    <_volume, X
            bra    .todo
@l2:
        sta    _inst.volume.index, X
@l1:
    tay
    
    lda    _inst.volume.lo, X
    sta    <_ptr
    lda    _inst.volume.hi, X
    sta    <_ptr+1
    
    lda    [_ptr], Y
    cmp    _volume.base, X
    bcs    @skip
        lda    _volume.base, X    
@skip:
    sta    <_volume, X
    inc    _inst.volume.index, X    
.todo:

    lda    <_tmp
    sta    <_state, X

    stx    psg_ch
    
.volume:
	lda    <_fx_volume_delta, X
	clc
	adc    <_volume, X
	bpl    .no_reset.0
		cla
.no_reset.0:
	cmp    #$7c
	bcc    .no_clamp.0
		lda    #$7c
.no_clamp.0:
    sta    <_volume, X
    lsr    A
    lsr    A
	ora    #%10_0_00000
	sta    psg_ctrl
    
.end:

    dex
    bpl    .start
    ; [todo]
    
    rts

;;---------------------------------------------------------------------
; name : load_arpeggio
; desc : .
; in   : 
; out  : 
;;---------------------------------------------------------------------
load_arpeggio:
    pla
	pha
	asl    A
    asl    A
	tax

    lda    [_si], Y
	and    #$0f
	sta    _fixed_arpeggio+1, X
	
    lda    [_si], Y
	iny
	lsr    A
	lsr    A
	lsr    A
	lsr    A
	sta    _fixed_arpeggio+2, X

	txa
	clc
	adc    #low(_fixed_arpeggio)
	plx
	sta    <_arpeggio_ptr.lo, X
	lda    #high(_fixed_arpeggio)
	adc    #$00
	sta    <_arpeggio_ptr.hi, X 

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
    
	sta    psg_pan
	; [todo] save copy

    plx
    jmp    _update_song_load_loop

load_set_speed_value1:
    lda    [_si], Y
    iny
    ; [todo]
    plx
    jmp    _update_song_load_loop

;;---------------------------------------------------------------------
; name : load_volume_slide
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
load_volume_slide:
    lda    [_si], Y
    iny	
    plx
    sta    <_fx_volume_delta, X  
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

;;---------------------------------------------------------------------
; name : load_pattern_break
; desc : 
; in   : 
; out  : 
;;---------------------------------------------------------------------
load_pattern_break:
    lda    [_si], Y
    iny
    plx

    ; [todo] add a flag that'll perform break at the end of the update

    sta    <_current_row

    lda    #$01
    sta    <_current_time_tick
    

    ldx    #(PSG_CHAN_COUNT-1)
@l0:
    stz    _delay, X
    dex
    bpl    @l0
    
    inc    _matrix_index
    lda    _matrix_index
    cmp    _matrix_rows
    bne    .update_patterns
        ; [todo] reset stuffs just as load_song
        stz    _matrix_index
.update_patterns:
    get_next_pattern 0
    get_next_pattern 1
    get_next_pattern 2
    get_next_pattern 3
    get_next_pattern 4
    get_next_pattern 5

    jmp    update_song

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
; desc : Load waveform buffer.
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
    sta    _wave_copy_src
    lda    [_wave_table_ptr.hi], Y
    sta    _wave_copy_src+1
    
    ; Reset write index
    lda    #%01_0_00000
    sta    psg_ctrl

    ; Enable write buffer
    stz    psg_ctrl
    
    ; Copy wave buffer
    jsr    _wave_copy

    lda    #%01_0_00000
    sta    psg_ctrl

    ply
    plx

    ; Restore channel volume
    lda    <_volume, X
    lsr    A
    lsr    A
    ora    #%10_0_00000
    sta    psg_ctrl
    
    jmp    _update_song_load_loop

;;---------------------------------------------------------------------
; name : load_enable_noise_channel
; desc :
; in   : 
; out  : 
;;---------------------------------------------------------------------
load_enable_noise_channel:
    lda    [_si], Y
    and    #$1f
    beq    @l0
        lda    #$bf                                 ; [todo] compute frequency
@l0:
    iny
    plx

    cpx    #$04 
    bcc    @l1
        sta    psg_noise

        lda    <_volume, X
        lsr    A
        lsr    A
        ora    #%10_0_00000
        sta    psg_ctrl

        bne    @l1
        
@l1:
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

;;---------------------------------------------------------------------
; name : load_set_volume
; desc : Reset current volume.
; in   : 
; out  : 
;;---------------------------------------------------------------------
load_set_volume:
	; Load byte.
    lda    [_si], Y
    iny

    plx
    sta    <_volume, X    
    sta    _volume.base, X
    
    jmp    _update_song_load_loop

;;---------------------------------------------------------------------
; name : load_set_instrument
; desc : Set current instrument.
; in   : 
; out  : 
;;---------------------------------------------------------------------
load_set_instrument:
    ; Load instrument index
    lda    [_si], Y
    iny
    
    plx
    phy
    
    tay

    lda    <_state, X
    and    #%111111_00                                                 ; [todo] bitmask
    sta    <_tmp

    stz   _inst.volume.index, X
    stz   _inst.arpeggio.index, X

    ; Setup volume and arpeggio pointers
    lda    song.instruments.volume.size, Y
    sta    _inst.volume.size, X
    bne    .l0
        rmb0   <_tmp
        bra    .load_arpeggio    
.l0:
    smb0   <_tmp
    lda    song.instruments.volume.loop, Y
    sta    _inst.volume.loop, X
    lda    song.instruments.volume.lo, Y
    sta    _inst.volume.lo, X
    lda    song.instruments.volume.hi, Y
    sta    _inst.volume.hi, X

.load_arpeggio
    lda    song.instruments.arpeggio.size, Y
    sta    _inst.arpeggio.size, X
    bne    .l1
        rmb1   <_tmp
        bra    .load_wav
.l1:
    smb1   <_tmp
    lda    song.instruments.arpeggio.loop, Y
    sta    _inst.arpeggio.loop, X
    lda    song.instruments.arpeggio.lo, Y
    sta    _inst.arpeggio.lo, X
    lda    song.instruments.arpeggio.hi, Y
    sta    _inst.arpeggio.hi, X

.load_wav:
    ; [todo]
    
    lda    <_tmp
    sta    <_state, X
    
    ply
    jmp    _update_song_load_loop

;;---------------------------------------------------------------------
; name : load_note
; desc : Reset current note / frequency.
; in   : 
; out  : 
;;---------------------------------------------------------------------
load_note:
    ; Load octave+note
    lda    [_si], Y
    iny    
    ; Retrieve channel index.
    plx
    ; Save octave+note
    sta    <_tone, X
	phy
	tay

	lda    freq_table.lo, Y
	sta    <_frequency.lo, X
	sta    psg_freq.lo
	lda    freq_table.hi, Y
	sta    <_frequency.hi, X
	sta    psg_freq.hi

    lda    _volume.base, X
    sta    <_volume, X

	ply

    jmp    _update_song_load_loop

;;---------------------------------------------------------------------
; name : load_undefined
; desc : Handle undefined command.
; in   : 
; out  : 
;;---------------------------------------------------------------------
load_undefined:
	; Do nothing.
    iny
    plx
    jmp    _update_song_load_loop
;;---------------------------------------------------------------------
; name : load_note_off
; desc : Mute channel.
; in   : 
; out  : 
;;---------------------------------------------------------------------
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

	.data
    .bank 1
	.org $4000

; [todo::begin] dummy song
song:
    .include "song2.asm"
; [todo::end] dummy song
    .include "frequency.inc"
