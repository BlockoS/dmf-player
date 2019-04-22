// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#include <cstdlib>
#include <cstdio>
#include <cstring>

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
            return NoteOff;
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
        default:
            return Rest;
    }
}

SongPacker::SongPacker()
{}

SongPacker::~SongPacker()
{}

void SongPacker::pack(DMF::Song const& song) {
    memcpy(&_infos, &song.infos, sizeof(DMF::Infos));
    
    _instruments.pack(song.instrument);
    
    _waveTable.resize(song.waveTable.size());
    for(size_t i=0; i<song.waveTable.size(); i++) {
        _waveTable[i].resize(song.waveTable[i].size());
        for(size_t j=0; j<song.waveTable[i].size(); j++) {
            _waveTable[i][j] = static_cast<uint8_t>(song.waveTable[i][j] & 0x1f);
        }
    }
    
    // [todo] samples!
    
    packPatternMatrix(song);
    packPatternData(song);
}

void InstrumentList::pack(std::vector<DMF::Instrument> const& src) {
    count = src.size();
    
    env[Volume].size.resize(count);
    env[Volume].loop.resize(count);
    env[Volume].data.resize(count);

    env[Arpeggio].size.resize(count);
    env[Arpeggio].loop.resize(count);
    env[Arpeggio].data.resize(count);

    for(size_t i=0; i<src.size(); i++) {
        env[Volume].size[i] = src[i].std.volume.size;
        env[Volume].loop[i] = src[i].std.volume.loop;
        for(size_t j=0; j<env[Volume].size[i]; j++) {
            env[Volume].data[i][j] = src[i].std.volume.value[4*j] * 4;
        }
        
        env[Arpeggio].size[i] = src[i].std.arpeggio.size;
        env[Arpeggio].loop[i] = src[i].std.arpeggio.loop;
        for(size_t j=0; j<env[Arpeggio].size[i]; j++) {
            env[Arpeggio].data[i][j] = src[i].std.arpeggio.value[4*j];
        }
    }
}

void SongPacker::packPatternMatrix(DMF::Song const& song) {
    std::vector<int> offsets;
    _matrix.resize(song.infos.systemChanCount);
    for(size_t j=0; j<song.infos.systemChanCount; j++) {
        offsets.resize(song.infos.totalRowsInPatternMatrix * song.infos.totalRowsPerPattern);
        std::fill(offsets.begin(), offsets.end(), -1);
    
        for(size_t i=0; i<song.infos.totalRowsInPatternMatrix; i++) {
            size_t k  = i + (j*song.infos.totalRowsInPatternMatrix);
            size_t pattern = song.patternMatrix[k];
            if(offsets[pattern] < 0) {
                offsets[pattern] = _matrix[j].packed.size();
                _matrix[j].packed.push_back(pattern);
            }
            _matrix[j].pattern.push_back(offsets[pattern]); 
        }
    }
}

static inline void FlushRest(std::vector<uint8_t> &buffer, size_t &rest) {
    for(; rest >= 64; rest -= (rest >= 256) ? 256 : rest) {
        buffer.push_back(PCE::RestEx);
        buffer.push_back(rest % 256);
    }
    if(rest) {
        buffer.push_back(PCE::Rest | rest);
    }
    rest = 0;
}

void SongPacker::packPatternData(DMF::Song const& song) {
    std::vector<std::vector<size_t>> parent;
    parent.resize(song.infos.systemChanCount * song.infos.totalRowsInPatternMatrix * song.infos.totalRowsPerPattern);
    
    // We record the pattern break destination offsets for each pattern.
    for(size_t i=0; i<song.infos.systemChanCount; i++) {
        for(size_t j=0; j<song.infos.totalRowsInPatternMatrix; j++) {
            size_t pattern = song.patternMatrix[j + (i*song.infos.totalRowsInPatternMatrix)];
            size_t k = (i * song.infos.totalRowsInPatternMatrix + pattern) * song.infos.totalRowsPerPattern;
            
            for(size_t l=0; l<song.infos.totalRowsPerPattern; l++, k++) {
                const DMF::PatternData &pattern_data = song.patternData[k];
                if(DMF::isEmpty(pattern_data, song.effectCount[i])) {
                    continue;
                }
                for(size_t m=0; m<song.effectCount[i]; m++) {
                    if(pattern_data.effect[m].code == DMF::PATTERN_BREAK) {
                        if((j+1) < song.infos.totalRowsInPatternMatrix) {
                            size_t next_pattern = song.patternMatrix[j+1];
                            size_t offset = pattern_data.effect[m].data;
                            size_t jump = (i * song.infos.totalRowsInPatternMatrix + next_pattern) * song.infos.totalRowsPerPattern + offset;
                            parent[jump].push_back(k);
                        }
                    }
                }
            }
        }
    }

    // Process patterns
    std::vector<size_t> jump_source, jump_destination;
    jump_source.resize(song.infos.systemChanCount * song.infos.totalRowsInPatternMatrix * song.infos.totalRowsPerPattern);
    jump_destination.resize(song.infos.systemChanCount * song.infos.totalRowsInPatternMatrix * song.infos.totalRowsPerPattern);
   
    const size_t none = (size_t)-1;

    std::fill(jump_source.begin(), jump_source.end(), none);
    std::fill(jump_destination.begin(), jump_destination.end(), none);

    for(size_t i=0; i<song.infos.systemChanCount; i++) {
        _matrix[i].buffer.clear();
        for(size_t j=0; j<_matrix[i].packed.size(); j++) {
            size_t k, l;
            size_t start = (i * song.infos.totalRowsInPatternMatrix + _matrix[i].packed[j]) * song.infos.totalRowsPerPattern;
            size_t rest = 0;
            _matrix[i].bufferOffset.push_back(_matrix[i].buffer.size());
           
            size_t last = 0;
            for(k=0, l=start; k<song.infos.totalRowsPerPattern; k++, l++) {
                const DMF::PatternData &pattern_data = song.patternData[l];
                
                if(parent[l].size()) {
                    FlushRest(_matrix[i].buffer, rest);   
                    jump_destination[l] = _matrix[i].buffer.size(); 
                }
                
                if(DMF::isEmpty(pattern_data, song.effectCount[i])) {
                    rest++;
                    continue;
                }
                last = _matrix[i].buffer.size();
                FlushRest(_matrix[i].buffer, rest);   
                
                last = _matrix[i].buffer.size();
                if(pattern_data.note == 100) {
                    _matrix[i].buffer.push_back(PCE::NoteOff);
                }
                else if(pattern_data.note && pattern_data.octave) {
                    uint8_t dummy;
                    // Let's fix octave and notes...
                    dummy  = (pattern_data.note % 12) & 0x0f;
                    dummy |= ((pattern_data.octave + (dummy ? 1 : 2)) & 0x0f) << 4;
                    _matrix[i].buffer.push_back(PCE::Note);
                    _matrix[i].buffer.push_back(dummy);
                }
                
                if(pattern_data.volume != 0xffff) {
                    last = _matrix[i].buffer.size();
                    _matrix[i].buffer.push_back(PCE::SetVolume);
                    _matrix[i].buffer.push_back(pattern_data.volume * 4);
                }
                
                if(pattern_data.instrument != 0xffff) {
                    last = _matrix[i].buffer.size();
                    _matrix[i].buffer.push_back(PCE::SetInstrument);
                    _matrix[i].buffer.push_back(pattern_data.instrument);
                }
                
                for(size_t m=0; m<song.effectCount[i]; m++) {
                    if((pattern_data.effect[m].code != 0xffff) && (pattern_data.effect[m].data != 0xffff)) {
                        uint8_t data;
                        data = pattern_data.effect[m].data;
                        // Preprocess / fix 
                        // - Volume slide
                        if(pattern_data.effect[m].code == 0x0A) {
                            if(data > 0x0f) {	
                                // Positive delta.
                                data >>= 4;
                            }
                            else {
                                // Negative delta.
                                data = ((data & 0x0f) ^ 0xff) + 1;
                            }
                        }
                        last = _matrix[i].buffer.size();
                        _matrix[i].buffer.push_back(DMF2PCE(static_cast<DMF::Effect>(pattern_data.effect[m].code)));
                        _matrix[i].buffer.push_back(data);
                    
                        if(pattern_data.effect[m].code == DMF::PATTERN_BREAK) {
                            jump_source[l] = _matrix[i].buffer.size() - 1;
                        }
                    }
                } // effects
                _matrix[i].buffer[last] |= 0x80;
            }
            FlushRest(_matrix[i].buffer, rest);   
            _matrix[i].buffer.push_back(PCE::EndOfTrack);
        }
        _matrix[i].bufferOffset.push_back(_matrix[i].buffer.size());
    } 

    // Fix pattern break offsets
    for(size_t i=0; i<song.infos.systemChanCount; i++) {
        for(size_t j=0; j<_matrix[i].packed.size(); j++) {
            size_t k, l;
            size_t start = (i * song.infos.totalRowsInPatternMatrix + _matrix[i].packed[j]) * song.infos.totalRowsPerPattern;
            for(k=0, l=start; k<song.infos.totalRowsPerPattern; k++, l++) {
                for(auto index: parent[l]) {
                    size_t src = jump_source[index];
                    _matrix[i].buffer[src] = jump_destination[l];
                }
            }
        }
    }
}

bool SongPacker::output(Writer& writer)
{
    if(!writer.write(_infos, _instruments.count)) {
        // [todo] msg
        return false;
    }
    if(!writer.write(_waveTable)) {
        // [todo] msg
        return false;
    }
    if(!writer.writeInstruments(_instruments)) {
        // [todo] msg
        return false;
    }
    if(!writer.writePatterns(_infos, _matrix)) {
        // [todo] msg
        return false;
    }
    return true;
}

} // PCE
