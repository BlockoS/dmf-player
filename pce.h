// Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors.
// All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying
// LICENSE file for terms.
#ifndef PCE_H
#define PCE_H

#include <array>
#include "dmf.h"

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
        ExtendedCommands,
        SetSpeedValue2,
        SetWave,
        EnableNoiseChannel,
        SetLFOMode,
        SetLFOSpeed,
        EnableSampleOutput,
        SetVolume,
        SetInstrument,
        Note,                       // Set note+octave
        NoteOff,
        RestEx             = 0x79, // For values >= 128
        Rest               = 0x80  // For values between 0 and 127
    };
    
    struct PatternMatrix {
        std::vector<int> pattern;
        std::vector<int> packed;
        std::vector<int> bufferOffset;
        std::vector<uint8_t> buffer;
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
            EnvelopeCount
        };
        // [todo] arpeggio mode
        Envelope env[EnvelopeCount];
        size_t   count;
        void pack(std::vector<DMF::Instrument> const& src);
    };

    typedef std::vector<uint8_t> WaveTable;

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

        private:
            DMF::Infos _infos;
            std::vector<WaveTable>     _waveTable;
            InstrumentList             _instruments;
            std::vector<PatternMatrix> _matrix;
    };
}

#endif // PCE_H
