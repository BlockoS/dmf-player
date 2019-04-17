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

void SongPacker::packPatternData(DMF::Song const& song) {
    for(size_t i=0; i<song.infos.systemChanCount; i++) {
        _matrix[i].buffer.clear();
        for(size_t j=0; j<_matrix[i].packed.size(); j++) {
           
            size_t k, l;
            size_t start = (i * song.infos.totalRowsInPatternMatrix + _matrix[i].packed[j]) * song.infos.totalRowsPerPattern;
            size_t rest = 0;
            _matrix[i].bufferOffset.push_back(_matrix[i].buffer.size());
            
            for(k=0, l=start; k<song.infos.totalRowsPerPattern; k++, l++) {
                const DMF::PatternData &pattern_data = song.patternData[l];
                if(DMF::isEmpty(pattern_data, song.effectCount[i])) {
                    rest++;
                    continue;
                }
                if(rest) {
                    if(rest >= 128) {
                        _matrix[i].buffer.push_back(PCE::RestEx);
                        _matrix[i].buffer.push_back(rest);
                    }
                    else {
                        _matrix[i].buffer.push_back(PCE::Rest | rest);
                    }
                    rest = 0;
                }
                   
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
                    _matrix[i].buffer.push_back(PCE::SetVolume);
                    _matrix[i].buffer.push_back(pattern_data.volume * 4);
                }
                
                if(pattern_data.instrument != 0xffff) {
                    _matrix[i].buffer.push_back(PCE::SetInstrument);
                    _matrix[i].buffer.push_back(pattern_data.instrument);
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
                        _matrix[i].buffer.push_back(pattern_data.effect[m].code);
                        _matrix[i].buffer.push_back(data);
                    }
                } // effects
            }    
            if(rest) {
                if(rest >= 128) {
                    _matrix[i].buffer.push_back(PCE::RestEx);
                    _matrix[i].buffer.push_back(rest);
                }
                else {
                    _matrix[i].buffer.push_back(PCE::Rest | rest);
                }
            }
        }
        _matrix[i].bufferOffset.push_back(_matrix[i].buffer.size());
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
