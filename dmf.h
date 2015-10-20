// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#ifndef DMF_H
#define DMF_H

#include <stdlib.h>
#include <stdint.h>
#include <string>
#include <vector>

#define MAX_STRING_BUFFER_LEN 255
#define DMF_MAX_EFFECT_COUNT 4

namespace DMF {

/// Supported systems.
enum System
{
    /// Yamaha YMU759
    SYSTEM_YMU759   = 1,
    /// Sega Genesis
    ///     Yamaha YM2612
    ///     Texas Instruments SN76489
    SYSTEM_GENESIS  = 2,
    /// Sega Master System
    ///     Texas Instruments SN76489
    SYSTEM_SMS      = 3,
    /// Nintendo Gameboy
    ///      Z80 Variant
    SYSTEM_GAMEBOY  = 4,
    /// NEC PC-Engine
    ///      Hudson Soft HuC6280
    SYSTEM_PCENGINE = 5,
    /// Nintendo Famicom
    ///      Ricoh 2A03 
    SYSTEM_NES      = 6,
    /// Commodore 64
    ///       MOS Technology SID
    SYSTEM_C64      = 7
};

/// Number of channels for each supported system.
enum Channels
{
    CHAN_COUNT_YMU759   = 17,
    CHAN_COUNT_GENESIS  = 10,
    CHAN_COUNT_SMS      = 4,
    CHAN_COUNT_GAMEBOY  = 4,
    CHAN_COUNT_PCENGINE = 6,
    CHAN_COUNT_NES      = 5,
    CHAN_COUNT_C64      = 3
};

/// Frames mode.
enum FramesMode
{
    PAL  = 0,
    NTSC = 1
};

/// Effect list.
enum Effect
{
    // Standard Commands
    ARPEGGIO                            = 0x00,
    PORTAMENTO_UP                       = 0x01,
    PORTAMENTO_DOWN                     = 0x02,
    PORTAMENTO_TO_NOTE                  = 0x03,
    VIBRATO                             = 0x04,
    PORTAMENTO_TO_NOTE_VOLUME_SLIDE     = 0x05,
    VIBRATO_VOLUME_SIDE                 = 0x06,
    TREMOLO                             = 0x07,
    PANNING                             = 0x08,
    SET_SPEED_VALUE_1                   = 0x09,
    VOLUME_SLIDE                        = 0x0A,
    GO_TO_PATTERN                       = 0x0B,
    RETRIG                              = 0x0C,
    PATTERN_BREAK                       = 0x0D,
    SET_SPEED_VALUE_2                   = 0x0F,
    // Extended Commands
    NOTE_SLIDE_UP    = 0xE1,
    NOTE_SLIDE_DOWN  = 0xE2,
    FINE_TUNE        = 0xE5,
    SET_SAMPLES_BANK = 0xEB,
    NOTE_CUT         = 0xEC,
    NOTE_DELAY       = 0xED,
    GLOBAL_FINE_TUNE = 0xEF,
    // PC Engine Commands
    SET_WAVE        = 0x10,
    SET_NOISE       = 0x11,
    SET_LFO_MODE    = 0x12,
    SET_LFO_SPEED   = 0x13,
    SET_SAMPLES     = 0x17
};

struct String
{
    uint8_t length;
    char    data[MAX_STRING_BUFFER_LEN];
}; 

struct Infos
{
    uint8_t version;
    uint8_t system;
    String  name;
    String  author;
    uint8_t highlight[2];
    uint8_t timeBase;
    uint8_t tickTime[2];
    uint8_t framesMode;
    uint8_t customFreqFlag;
    uint8_t customFreqValue[3];
    uint8_t totalRowsPerPattern;
    uint8_t totalRowsInPatternMatrix;
    uint8_t arpeggioTickSpeed;
    uint8_t systemChanCount;
};

struct Envelope
{
    uint8_t size;
    uint8_t loop;
    uint8_t value[4*128];
};

struct Instrument
{
    struct Standard
    {   
        Envelope volume;
        Envelope arpeggio;
        uint8_t  arpeggioMode;
        Envelope noise;
        Envelope wave;
    };

    String   name;
    uint8_t  mode;
    Standard std; 
};

typedef std::vector<uint32_t> WaveTable;

struct PatternData
{
    uint16_t note;
    uint16_t octave;
    uint16_t volume;
    struct
    {
        uint16_t code;
        uint16_t data;
    } effect[DMF_MAX_EFFECT_COUNT];
    uint16_t instrument;
};

bool isEmpty(PatternData const& src);

struct Sample
{
    uint8_t  rate;
    uint8_t  pitch;
    uint8_t  amp;
    std::vector<uint16_t> data;
};

struct Song
{
    Infos  infos;
    std::vector<uint8_t> patternMatrix;
    std::vector<Instrument> instrument;
    std::vector<WaveTable> waveTable;
    std::vector<uint8_t> effectCount;
    std::vector<PatternData> patternData;
    std::vector<Sample> sample;
};

} // DMF

#endif // DMF_H
