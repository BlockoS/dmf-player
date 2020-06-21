// Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors.
// All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying
// LICENSE file for terms.
#ifndef PCE_H
#define PCE_H

#include <array>
#include "dmf.h"

#define PCE_CHAN_COUNT 6

namespace PCE {
    enum Effect {
        Arpeggio,
        ArpeggioSpeed,
        PortamentoUp,
        PortamentoDown,
        PortamentoToNote,
        Vibrato,
        VibratoMode,
        VibratoDepth,
        PortToNoteVolSlide,
        VibratoVolSlide,
        Tremolo,
        Panning,
        SetSpeedValue1,
        VolumeSlide,
        PositionJump,
        Retrig,
        PatternBreak,
        SetSpeedValue2,
        SetWave,
        EnableNoiseChannel,
        SetLFOMode,
        SetLFOSpeed,
        NoteSlideUp,
        NoteslideDown,
        NoteDelay,
        SyncSignal,
        FineTune,
        GlobalFineTune,
        SetSampleBank,
        SetVolume,
        SetInstrument,
        Note,                      // Set note+octave
        NoteOff,
        RestEx             = 0x3f, // For values >= 64
        Rest               = 0x40, // For values between 0 and 63
        EndOfTrack         = 0xff
    };
    
    struct PatternMatrix {
        std::vector<int> pattern;
        std::vector<int> packed;
        std::vector<std::vector<uint8_t>> buffer;
    };

    struct Envelope {
        typedef std::array<uint8_t, 128> Data_t;
        
        std::vector<uint8_t> size;
        std::vector<uint8_t> loop;
        std::vector<Data_t>  data;
    };

    struct InstrumentList {
		// Wave macros seems to be ignored.
        enum EnvelopeType {
            Volume = 0,
            Arpeggio,
            Wave,
            EnvelopeCount
        };
        std::vector<uint8_t> flag; 
        Envelope env[EnvelopeCount];
        size_t   count;
        void pack(std::vector<DMF::Instrument> const& src);
    };

    typedef std::vector<uint8_t> WaveTable;

    struct Sample {
        uint32_t rate;
        std::vector<uint8_t> data;
    };

    class Writer;
    
    class SongPacker {
        public:
            SongPacker();
            ~SongPacker();
            
            void pack(DMF::Song const& song);
            bool output(Writer& writer);

        private:
            void packPatternMatrix(DMF::Song const& song);
            void packPatternData(DMF::Song const& song);
            void packSamples(DMF::Song const& song);

        private:
            DMF::Infos _infos;
            std::vector<WaveTable>     _waveTable;
            InstrumentList             _instruments;
            std::vector<PatternMatrix> _matrix;
            std::vector<Sample>        _samples;
    };
}

#endif // PCE_H
