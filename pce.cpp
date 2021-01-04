// Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <cmath>

#include <samplerate.h>

#include "pce.h"
#include "pcewriter.h"

namespace PCE {

static Effect DMF2PCE(DMF::Effect fx) {
    switch(fx) {
        case DMF::ARPEGGIO:
            return Arpeggio;
        case DMF::PORTAMENTO_UP:
            return PortamentoUp;
        case DMF::PORTAMENTO_DOWN:
            return PortamentoDown;
        case DMF::PORTAMENTO_TO_NOTE:
            return PortamentoToNote;
        case DMF::VIBRATO:
            return Vibrato;
        case DMF::PORTAMENTO_TO_NOTE_VOLUME_SLIDE:
            return PortToNoteVolSlide;
        case DMF::VIBRATO_VOLUME_SIDE:
            return VibratoVolSlide;
        case DMF::TREMOLO:
            return Tremolo;
        case DMF::PANNING:
            return Panning;
        case DMF::SET_SPEED_VALUE_1:
            return SetSpeedValue1;
        case DMF::VOLUME_SLIDE:
            return VolumeSlide;
        case DMF::POSITION_JUMP:
            return PositionJump;
        case DMF::RETRIG:
            return Retrig;
        case DMF::PATTERN_BREAK:
            return PatternBreak;
        case DMF::SET_SPEED_VALUE_2:
            return SetSpeedValue2;
        case DMF::ARPEGGIO_SPEED:
            return ArpeggioSpeed;
        case DMF::NOTE_SLIDE_UP:
            return NoteSlideUp;
        case DMF::NOTE_SLIDE_DOWN:
            return NoteslideDown;
        case DMF::VIBRATO_MODE:
            return VibratoMode;
        case DMF::VIBRATO_DEPTH:
            return VibratoDepth;
        case DMF::FINE_TUNE:
            return FineTune;
        case DMF::SET_SAMPLES_BANK:
            return SetSampleBank;
        case DMF::NOTE_CUT:
            return NoteCut;
        case DMF::NOTE_DELAY:
            return NoteDelay;
        case DMF::SYNC_SIGNAL:
            return SyncSignal;
        case DMF::GLOBAL_FINE_TUNE:
            return GlobalFineTune;
        case DMF::SET_WAVE:
            return SetWave;
        case DMF::SET_NOISE:
            return EnableNoiseChannel;
        case DMF::SET_LFO_MODE:
            return SetLFOMode;
        case DMF::SET_LFO_SPEED:
            return SetLFOSpeed;
        case DMF::SET_SAMPLES:
            return SetSamples;
        default:
            return Rest;
    }
}

bool operator==(Envelope const& e0, Envelope const& e1) {
    if(e0.size != e1.size) {
        return false;
    }    
    else if(e0.loop != e1.loop) {
        for(size_t i=0; i<e0.size.size(); i++) {
            if(e0.data[i] != e1.data[i]) {
                return false;
            }
        }
        return true;
    }
    return false;
}

bool operator!=(Envelope const& e0, Envelope const& e1) {
    return !(e0 == e1);
}

bool operator==(InstrumentList const& i0, InstrumentList const& i1) {
    if(i0.flag != i1.flag) {
        return false;
    }
    else if (i0.count != i1.count) {
        return false;
    }
    for(size_t i=0; i<i0.count; i++) {
        if(i0.env[i] != i1.env[i]) {
            return false;
        }
    }
    return true;
}

bool operator!=(InstrumentList const& i0, InstrumentList const& i1) {
    return !(i0 == i1);
}

bool operator==(Sample const& s0, Sample const& s1) {
    return (s0.rate == s1.rate) && (s0.data == s1.data);
}

bool operator!=(Sample const& s0, Sample const& s1) {
    return (s0.rate != s1.rate) || (s0.data != s1.data);
}

static inline void flush_rest(std::vector<uint8_t> &buffer, size_t &rest) {
    for(; rest >= 64; rest -= (rest >= 256) ? 256 : rest) {
        buffer.push_back(PCE::RestEx);
        buffer.push_back(rest % 256);
    }
    if(rest) {
        buffer.push_back(PCE::Rest | rest);
    }
    rest = 0;
}

static void pack(Packer::Song &out, DMF::Song &song) {
    std::vector<PatternMatrix> &matrix = out.matrix;

    std::vector<int> offsets;
    offsets.resize(song.infos.totalRowsInPatternMatrix);
    matrix.resize(song.infos.systemChanCount);
    for(size_t j=0; j<song.infos.systemChanCount; j++) {
        std::fill(offsets.begin(), offsets.end(), -1);
    
        for(size_t i=0; i<song.infos.totalRowsInPatternMatrix; i++) {
            size_t k  = i + (j*song.infos.totalRowsInPatternMatrix);
            size_t pattern = song.patternMatrix[k];
            if(offsets[pattern] < 0) {
                offsets[pattern] = matrix[j].packed.size();
                matrix[j].packed.push_back(pattern);
            }
            matrix[j].pattern.push_back(offsets[pattern]); 
        }
    }

    // Process patterns
    for(size_t i=0; i<song.infos.systemChanCount; i++) {
        matrix[i].buffer.resize(matrix[i].packed.size());
        for(size_t j=0; j<matrix[i].packed.size(); j++) {
            size_t k, l;
            size_t start = (i * song.infos.totalRowsInPatternMatrix + matrix[i].packed[j]) * song.infos.totalRowsPerPattern;
            size_t rest = 0;
            size_t last = 0;
            for(k=0, l=start; k<song.infos.totalRowsPerPattern; k++, l++) {
                const DMF::PatternData &pattern_data = song.patternData[l];
                if(DMF::isEmpty(pattern_data, song.effectCount[i])) {
                    rest++;
                    continue;
                }
                flush_rest(matrix[i].buffer[j], rest);
                
                last = matrix[i].buffer[j].size();
                if(pattern_data.note == 100) {
                    matrix[i].buffer[j].push_back(PCE::NoteOff);
                }
                else if(pattern_data.note || pattern_data.octave) {
                    uint8_t dummy;
                    // Let's fix octave and notes...
                    dummy  = pattern_data.note % 12;
                    dummy += (pattern_data.octave + (dummy ? 1 : 2)) * 12;
                    matrix[i].buffer[j].push_back(PCE::Note);
                    matrix[i].buffer[j].push_back(dummy);
                }
                
                if(pattern_data.volume != 0xffff) {
                    last = matrix[i].buffer[j].size();
                    matrix[i].buffer[j].push_back(PCE::SetVolume);
                    matrix[i].buffer[j].push_back(pattern_data.volume * 4);
                }
                
                if(pattern_data.instrument != 0xffff) {
                    last = matrix[i].buffer[j].size();
                    matrix[i].buffer[j].push_back(PCE::SetInstrument);
                    matrix[i].buffer[j].push_back(pattern_data.instrument);
                }
                
                for(size_t m=0; m<song.effectCount[i]; m++) {
                    if(pattern_data.effect[m].code != 0xffff) {
                        last = matrix[i].buffer[j].size();
                        matrix[i].buffer[j].push_back(DMF2PCE(static_cast<DMF::Effect>(pattern_data.effect[m].code)));
                   
                        uint8_t data;
                        data = (pattern_data.effect[m].data != 0xffff) ? pattern_data.effect[m].data : 0x00;

                        // Preprocess / fix
                        // - Global fine tune
                        if(pattern_data.effect[m].code == DMF::GLOBAL_FINE_TUNE) {
                            if(data > 0x80) {
                                data -= 0x80;
                            }
                            else {
                                data = (data ^ 0xff) + 1;
                            }
                        }
                        // - Volume slide
                        else if(pattern_data.effect[m].code == DMF::VOLUME_SLIDE) {
                            if(data > 0x0f) {	
                                // Positive delta.
                                data >>= 4;
                            }
                            else {
                                // Negative delta.
                                data = ((data & 0x0f) ^ 0xff) + 1;
                            }
                        }
                        // - Note cut
                        else if(pattern_data.effect[m].code == DMF::NOTE_CUT) {
                            // Nothing atm...
                        }
                        // - Set wav
                        else if(pattern_data.effect[m].code == DMF::SET_WAVE) {
                            data = out.wave[data % out.wave.size()];
                        }
                        matrix[i].buffer[j].push_back(data);
                    }
                } // effects
                matrix[i].buffer[j][last] |= 0x80;
            }
            flush_rest(matrix[i].buffer[j], rest);   
            matrix[i].buffer[j].push_back(PCE::EndOfTrack);
        }
    } 
}

static void pack(WaveTable &out, DMF::WaveTable &in) {
    out.resize(in.size());
    for(size_t i=0; i<in.size(); i++) {
        out[i] = static_cast<uint8_t>(in[i] & 0x1f); // [todo] clamp or normalize?
    }
}

static void pack(Packer::Song &out, std::vector<DMF::Instrument> const& in) {
    InstrumentList &inst = out.instruments;
    inst.count = in.size();
    
    inst.flag.resize(inst.count);

    inst.env[InstrumentList::Volume].size.resize(inst.count);
    inst.env[InstrumentList::Volume].loop.resize(inst.count);
    inst.env[InstrumentList::Volume].data.resize(inst.count);

    inst.env[InstrumentList::Arpeggio].size.resize(inst.count);
    inst.env[InstrumentList::Arpeggio].loop.resize(inst.count);
    inst.env[InstrumentList::Arpeggio].data.resize(inst.count);

    inst.env[InstrumentList::Wave].size.resize(inst.count);
    inst.env[InstrumentList::Wave].loop.resize(inst.count);
    inst.env[InstrumentList::Wave].data.resize(inst.count);
                
    for(size_t i=0; i<in.size(); i++) {
        inst.flag[i] = in[i].std.arpeggioMode ? 0x80 : 0x00; // [todo] add more ?

        inst.env[InstrumentList::Volume].size[i] = in[i].std.volume.size;
        inst.env[InstrumentList::Volume].loop[i] = in[i].std.volume.loop;
        for(size_t j=0; j<inst.env[InstrumentList::Volume].size[i]; j++) {
            inst.env[InstrumentList::Volume].data[i][j] = in[i].std.volume.value[4*j] * 4;
        }
        
        inst.env[InstrumentList::Arpeggio].size[i] = in[i].std.arpeggio.size;
        inst.env[InstrumentList::Arpeggio].loop[i] = in[i].std.arpeggio.loop;
        for(size_t j=0; j<inst.env[InstrumentList::Arpeggio].size[i]; j++) {
            inst.env[InstrumentList::Arpeggio].data[i][j] = in[i].std.arpeggio.value[4*j];
        }
        
        inst.env[InstrumentList::Wave].size[i] = in[i].std.wave.size;
        inst.env[InstrumentList::Wave].loop[i] = in[i].std.wave.loop;
        for(size_t j=0; j<inst.env[InstrumentList::Wave].size[i]; j++) {
            uint8_t wav_id = out.wave[in[i].std.wave.value[4*j] % out.wave.size()];
            inst.env[InstrumentList::Wave].data[i][j] = wav_id;
        }
    }
}

#define PCM_BLOCK_SIZE 1024

// NOTE: amplitude and pitch are ignored
static void pack(Sample &out, DMF::Sample const &in) {
    static const uint32_t freq[5] = {
        8000,
        11025,
        16000,
        22050,
        32000
    };

    size_t j = (in.rate <= 5) ? (in.rate-1) : 4;
    float scale = static_cast<float>(1 << in.bits);

    int error;
    SRC_DATA data;
    SRC_STATE *state = src_new(SRC_SINC_BEST_QUALITY, 1, &error) ;
    src_reset(state);

    out.rate = 7159090 / 1024;
    data.src_ratio = 7159090.f / 1024.f / (float)freq[j];
    
    float *dummy = new float[in.data.size()];
    data.data_in = dummy;
    data.data_out = new float[PCM_BLOCK_SIZE];

/*
    float s_min = in.data[0];
    float s_max = in.data[0];
    for(j=1; j<in.data.size(); j++) {
        if(in.data[j] < s_min) {
            s_min = in.data[j];
        }
        if(in.data[j] > s_max) {
            s_max = in.data[j];
        }
    }
*/
    for(j=0; j<in.data.size(); j++) {
//            float v = 2.f * ((current.data[j] - s_min) / (s_max - s_min)) - 1.f;
        float v = 2.f * (in.data[j] / scale) - 1.f;
        dummy[j] = (v < -1.f) ? -1.f : ((v > 1.f) ? 1.f : v);
    }

    long n = 0;
    data.input_frames_used = 0;
    do {
        data.data_in += data.input_frames_used;
        data.input_frames =  dummy + in.data.size() - data.data_in;

        if(data.input_frames > PCM_BLOCK_SIZE) {
            data.input_frames = PCM_BLOCK_SIZE;
            data.end_of_input = 0;
        }
        else {
            data.end_of_input = 1;
        }
        data.output_frames	= PCM_BLOCK_SIZE;
        data.input_frames_used = 0;
        data.output_frames_gen = 0;
        
        error = src_process(state, &data);

        n += data.input_frames_used;


        for(j=0; j<data.output_frames_gen; j++) {
            float u = data.data_out[j];
            u = (u < -1.f) ? -1.f : ((u > 1.f) ? 1.f : u);
            uint8_t v = (0.5f * u + 0.5f) * 31.f;
            out.data.push_back(v);
        }
    } while(!data.end_of_input);

    out.data.push_back(0xff);

    src_delete(state);

    delete [] dummy;
    delete [] data.data_out;
}

void add(Packer &p, DMF::Song &in) {
    p.song.push_back({});

    Packer::Song &song = p.song.back();
    song.infos = in.infos;
    
    for(size_t i=0; i<in.waveTable.size(); i++) {
        WaveTable wav;
        pack(wav, in.waveTable[i]);
        add(p.wave, song.wave, wav);
    }

    pack(song, in);
    pack(song, in.instrument);

    for(size_t i=0; i<in.sample.size(); i++) {
        Sample sample;
        pack(sample, in.sample[i]);
        add(p.sample, song.sample, sample);
    }
}

} // PCE
