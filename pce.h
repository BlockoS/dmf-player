// Copyright (c) 2015-2020, Vincent "MooZ" Cruz and other contributors.
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
    NoteCut,
    NoteDelay,
    SyncSignal,
    FineTune,
    GlobalFineTune,
    SetSampleBank,
    SetVolume,
    SetInstrument,
    Note,                      // Set note+octave
    NoteOff,
    SetSamples,
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

bool operator==(Envelope const& e0, Envelope const& e1);
bool operator!=(Envelope const& e0, Envelope const& e1);

struct InstrumentList {
    enum EnvelopeType {
        Volume = 0,
        Arpeggio,
        Wave,
        EnvelopeCount
    };
    std::vector<uint8_t> flag; 
    Envelope env[EnvelopeCount];
    size_t   count;
};

bool operator==(InstrumentList const& i0, InstrumentList const& i1);
bool operator!=(InstrumentList const& i0, InstrumentList const& i1);

typedef std::vector<uint8_t> WaveTable;

struct Sample {
    uint32_t rate;
    std::vector<uint8_t> data;
};

bool operator==(Sample const& s0, Sample const& s1) ;
bool operator!=(Sample const& s0, Sample const& s1);

template <class T>
void add(std::vector<T> &data, std::vector<size_t> &index, T const& elmnt) {
    size_t i;
    for(i=0; (i<data.size()) && (data[i] != elmnt); i++) {
    }
    if(i == data.size()) {
        data.push_back(elmnt);
    }
    index.push_back(i);
}

struct Packer {
    struct Song {
        DMF::Infos infos;
        std::vector<PatternMatrix> matrix;
        std::vector<size_t> wave;
        InstrumentList instruments;
        std::vector<size_t> sample;
    };

    std::vector<Song> song;
    std::vector<WaveTable> wave;
    std::vector<Sample> sample;
};

void add(Packer &p, DMF::Song &song);
    
} // PCE

#endif // PCE_H
