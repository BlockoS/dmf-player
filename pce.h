#ifndef PCE_H
#define PCE_H

#include "dmf.h"

namespace PCE
{
    enum Effect
    {
        Arpeggio           = 0x00,
        PortamentoUp       = 0x01,
        PortamentoDown     = 0x02,
        PortamentoToNote   = 0x03,
        Vibrato            = 0x04,
        PortToNoteVolSlide = 0x05,
        VibratoVolSlide    = 0x06,
        Tremolo            = 0x07,
        Panning            = 0x08,
        SetSpeedValue1     = 0x09,
        VolumeSlide        = 0x0a,
        PositionJump       = 0x0b,
        Retrig             = 0x0c,
        PatternBreak       = 0x0d,
        ExtendedCommands   = 0x0e,
        SetSpeedValue2     = 0x0f,
        SetWave            = 0x10,
        EnableNoiseChannel = 0x11,
        SetLFOMode         = 0x12,
        SetLFOSpeed        = 0x13,
        EnableSampleOutput = 0x17,
        SetVolume          = 0x1a,
        SetInstrument      = 0x1b,
        Note               = 0x20, // Set note+octave
        NoteOff            = 0x21,
        RestEx             = 0x79, // For values >= 128
        Rest               = 0x80  // For values between 0 and 127
    };
    
    struct PatternMatrix
    {
        std::vector<int> dataOffset;
        std::vector<int> packedOffset;
        std::vector<int> bufferOffset;
    };

    struct Envelope
    {
        uint8_t data[128];
        uint8_t size;
        uint8_t loop;
        
        void pack(DMF::Envelope const& src);
        void output(FILE* stream, char const* prefix, char const* name, uint32_t index);
    };

    struct Instrument
    {
        uint8_t mode;
        struct
        {   
            Envelope volume;
            Envelope arpeggio;
            Envelope noise;
            Envelope wave;
            uint8_t  arpeggioMode;
        } standard;
        
        void pack(DMF::Instrument const& src);
        void output(FILE *stream, char const* prefix, uint32_t index);
    };

    typedef std::vector<uint8_t> WaveTable;

    class Writer;
    
    class SongPacker
    {
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
            std::vector<Instrument>    _instruments;
            std::vector<uint8_t>       _buffer;
            std::vector<PatternMatrix> _matrix;
            std::vector<uint8_t>       _pattern;
    };
}

#endif // PCE_H
