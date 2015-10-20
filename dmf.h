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
enum Effect : uint8_t
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

/// DMF fixed size string.
struct String
{
    /// String length.
    uint8_t length;
    /// String data.
    char data[MAX_STRING_BUFFER_LEN];
}; 

/// DMG song infos.
struct Infos
{
    /// DMF version.
    uint8_t version;
    /// Target system.
    uint8_t system;
    /// Song name.
    String  name;
    /// Author.
    String  author;
    /// Rows lines highlighting.
    uint8_t highlight[2];
    /// The base time value multiplies the tick time value.
    uint8_t timeBase;
    /// Tick time.
    uint8_t tickTime[2];
    /// Frames mode.
    uint8_t framesMode;
    /// Custom frequency flag.
    uint8_t customFreqFlag;
    /// Custom frequency value.
    uint8_t customFreqValue[3];
    /// Number of rows per pattern.
    uint8_t totalRowsPerPattern;
    /// Total number of rows in the pattern matrix.
    uint8_t totalRowsInPatternMatrix;
    /// Speed of the arpeggio command.
    uint8_t arpeggioTickSpeed;
    /// Number of channels.
    uint8_t systemChanCount;
};

/// Envelope.
struct Envelope
{
    /// Length.
    uint8_t size;
    /// Loop index.
    uint8_t loop;
    /// Data.
    uint8_t value[4*128];
};

/// Instrument.
/// @note Only standard instruments are supported for the moment.
struct Instrument
{
    /// Standard instrument.
    struct Standard
    {
        /// Volume envelope.
        Envelope volume;
        /// Arpeggio (tone envelope).
        Envelope arpeggio;
        /// Arpeggio mode.
        ///   * normal = 0
        ///   * fixed = 1
        uint8_t  arpeggioMode;
        /// Noise envelope.
        Envelope noise;
        /// Wavetable macro.
        Envelope wave;
    };
    /// Name.
    String   name;
    /// Mode.
    ///    * standard = 0
    ///    * FM = 1
    uint8_t  mode;
    /// Standard instrument data.
    Standard std; 
};

/// Wavetable.
typedef std::vector<uint32_t> WaveTable;

/// Pattern data.
struct PatternData
{
    /// Effect.
    struct Effect
    {
        /// Code.
        uint16_t code;
        /// Data.
        uint16_t data;
    };
    /// Note. 
    ///   * [1,12] = {C#,D ,D#,E ,F ,F#,G ,G#,A ,A#,B ,C }.
    ///   * 0x100 = note off.
    uint16_t note;
    /// Octave.
    uint16_t octave;
    /// Volume.
    uint16_t volume;
    /// Effects.
    Effect effect[DMF_MAX_EFFECT_COUNT];
    /// Instrument index.
    uint16_t instrument;
};

/// Check if a pattern element is empty. 
/// @param [in] src Pattern data.
/// @return true if the pattern element is empty, false otherwise.
bool isEmpty(PatternData const& src);

/// PCM sample.
struct Sample
{
    /// Sample rate.
    uint8_t  rate;
    /// Pitch.
    uint8_t  pitch;
    /// Amp.
    uint8_t  amp;
    /// Sample data.
    std::vector<uint16_t> data;
};

/// DMF Song.
struct Song
{
    /// Infos.
    Infos  infos;
    /// Pattern matrix.
    std::vector<uint8_t> patternMatrix;
    /// Instruments.
    std::vector<Instrument> instrument;
    /// Wave tables.
    std::vector<WaveTable> waveTable;
    /// Number of effects per pattern.
    std::vector<uint8_t> effectCount;
    /// Patterns.
    std::vector<PatternData> patternData;
    /// Samples.
    std::vector<Sample> sample;
};

} // DMF

#endif // DMF_H
