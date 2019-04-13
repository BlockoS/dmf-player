// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#include <cstdlib>
#include <cstdio>
#include <cstring>

#include "pce.h"
#include "pcewriter.h"

namespace PCE {

SongPacker::SongPacker()
{}

SongPacker::~SongPacker()
{}

void SongPacker::pack(DMF::Song const& song) {
    memcpy(&_infos, &song.infos, sizeof(DMF::Infos));
    
    _pattern.resize(song.patternMatrix.size());
    
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
    _matrix.resize(song.infos.systemChanCount);
    size_t delta = 0;
    for(size_t j=0; j<song.infos.systemChanCount; j++) {
        _matrix[j].dataOffset.clear();

        _matrix[j].packedOffset.resize(song.infos.totalRowsInPatternMatrix);
        std::fill(_matrix[j].packedOffset.begin(), _matrix[j].packedOffset.end(), -1);
        
        for(size_t i=0; i<song.infos.totalRowsInPatternMatrix; i++) {
            size_t offset  = i + (j*song.infos.totalRowsInPatternMatrix);
            size_t pattern = song.patternMatrix[offset];
            if(_matrix[j].packedOffset[pattern] < 0) {
                _matrix[j].packedOffset[pattern] = _matrix[j].dataOffset.size();
                _matrix[j].dataOffset.push_back(offset * song.infos.totalRowsPerPattern);
            }
            _pattern[offset] = _matrix[j].packedOffset[pattern] + delta;
        }
        delta += _matrix[j].dataOffset.size();
    }
}

void SongPacker::packPatternData(DMF::Song const& song) {
    _buffer.clear();
   
    std::vector<uint8_t> jump_offsets;

    for(size_t i=0; i<song.infos.systemChanCount; i++) {
        for(size_t j=0; j<_matrix[i].dataOffset.size(); j++) {
            jump_offsets.clear();
           
            size_t k;
            size_t l;
            for(k=0, l=_matrix[i].dataOffset[j]; k<song.infos.totalRowsPerPattern; k++, l++) {
                const DMF::PatternData &pattern_data = song.patternData[l];
                for(size_t t=0; t<DMF_MAX_EFFECT_COUNT; t++) {
                    if(pattern_data.effect[t].code == DMF::POSITION_JUMP) {
                        jump_offsets.push_back(k); 
                    }
                }
            }
            
            size_t rest = 0;
            _matrix[i].bufferOffset.push_back(_buffer.size());
            
            for(k=0, l=_matrix[i].dataOffset[j]; k<song.infos.totalRowsPerPattern; k++, l++) {
                bool jump_destination = false;
                for(size_t t=0; (t<jump_offsets.size()) && (!jump_destination); t++) {
                    jump_destination = (k == jump_offsets[t]);
                }
                
                const DMF::PatternData &pattern_data = song.patternData[l];
                if((!jump_destination) && DMF::isEmpty(pattern_data, song.effectCount[i])) {
                    rest++;
                    continue;
                }
                if(rest) {
                    if(rest >= 128) {
                        _buffer.push_back(PCE::RestEx);
                        _buffer.push_back(rest);
                    }
                    else {
                        _buffer.push_back(PCE::Rest | rest);
                    }
                    rest = 0;
                }
                   
                if(pattern_data.note == 100) {
                    _buffer.push_back(PCE::NoteOff);
                }
                else if(pattern_data.note && pattern_data.octave) {
                    uint8_t dummy;
                    // Let's fix octave and notes...
                    dummy  = (pattern_data.note % 12) & 0x0f;
                    dummy |= ((pattern_data.octave + (dummy ? 1 : 2)) & 0x0f) << 4;
                    _buffer.push_back(PCE::Note);
                    _buffer.push_back(dummy);
                }
                
                if(pattern_data.volume != 0xffff) {
                    _buffer.push_back(PCE::SetVolume);
                    _buffer.push_back(pattern_data.volume * 4);
                }
                
                if(pattern_data.instrument != 0xffff) {
                    _buffer.push_back(PCE::SetInstrument);
                    _buffer.push_back(pattern_data.instrument);
                }
                
                for(size_t m=0; m<song.effectCount[i]; m++) {
                    if((pattern_data.effect[m].code != 0xffff) && (pattern_data.effect[m].data != 0xffff)) {
					    uint8_t data;
					    data = pattern_data.effect[m].data;
					    // Preprocess / fix 
					    // [todo] make a shiny method to fix effects!
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
                        _buffer.push_back(pattern_data.effect[m].code);
                        _buffer.push_back(data);
                    }
                } // effects
            }    
            if(rest) {
                if(rest >= 128) {
                    _buffer.push_back(PCE::RestEx);
                    _buffer.push_back(rest);
                }
                else {
                    _buffer.push_back(PCE::Rest | rest);
                }
            }
        }
        _matrix[i].bufferOffset.push_back(_buffer.size());
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
    if(!writer.write(_infos, _pattern)) {
        // [todo] msg
        return false;
    }
    if(!writer.writePatterns(_infos, _matrix, _buffer)) {
        // [todo] msg
        return false;
    }
    return true;
}

} // PCE
