// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#include <cstdlib>
#include <cstdio>
#include <cstring>

#include "pce.h"
#include "pcewriter.h"

// [todo] : put infos and pointer tables at the beginning !
// [todo] : put wav, instruments, pattern matrix into buffer

namespace PCE {

SongPacker::SongPacker()
{}

SongPacker::~SongPacker()
{}

void SongPacker::pack(DMF::Song const& song)
{
    memcpy(&_infos, &song.infos, sizeof(DMF::Infos));
    
    _pattern.resize(song.patternMatrix.size());
    
    _instruments.pack(song.instrument);
    
    _waveTable.resize(song.waveTable.size());
    for(size_t i=0; i<song.waveTable.size(); i++)
    {
        _waveTable[i].resize(song.waveTable[i].size());
        for(size_t j=0; j<song.waveTable[i].size(); j++)
        {
            _waveTable[i][j] = static_cast<uint8_t>(song.waveTable[i][j] & 0x1f);
        }
    }
    
    // [todo] samples!
    
    packPatternMatrix(song);
    packPatternData(song);
}

void InstrumentList::pack(std::vector<DMF::Instrument> const& src)
{
    count = src.size();
    
    env[Volume].size.resize(count);
    env[Volume].loop.resize(count);
    env[Volume].data.resize(count);

    env[Arpeggio].size.resize(count);
    env[Arpeggio].loop.resize(count);
    env[Arpeggio].data.resize(count);

    for(size_t i=0; i<src.size(); i++)
    {
        env[Volume].size[i] = src[i].std.volume.size;
        env[Volume].loop[i] = src[i].std.volume.loop;
        for(size_t j=0; j<env[Volume].size[i]; j++)
        {
            env[Volume].data[i][j] = src[i].std.volume.value[4*j];
        }
        
        env[Arpeggio].size[i] = src[i].std.arpeggio.size;
        env[Arpeggio].loop[i] = src[i].std.arpeggio.loop;
        for(size_t j=0; j<env[Arpeggio].size[i]; j++)
        {
            env[Arpeggio].data[i][j] = src[i].std.arpeggio.value[4*j];
        }
    }
}

void SongPacker::packPatternMatrix(DMF::Song const& song)
{
    _matrix.resize(song.infos.systemChanCount);
    size_t delta = 0;
    for(size_t j=0; j<song.infos.systemChanCount; j++)
    {
        _matrix[j].dataOffset.clear();

        _matrix[j].packedOffset.resize(song.infos.totalRowsInPatternMatrix);
        std::fill(_matrix[j].packedOffset.begin(), _matrix[j].packedOffset.end(), -1);
        
        for(size_t i=0; i<song.infos.totalRowsInPatternMatrix; i++)
        {
            size_t offset  = i + (j*song.infos.totalRowsInPatternMatrix);
            size_t pattern = song.patternMatrix[offset];
            if(_matrix[j].packedOffset[pattern] < 0)
            {
                _matrix[j].packedOffset[pattern] = _matrix[j].dataOffset.size();
                _matrix[j].dataOffset.push_back(offset * song.infos.totalRowsPerPattern);
            }
            _pattern[offset] = _matrix[j].packedOffset[pattern] + delta;
        }
        delta += _matrix[j].dataOffset.size();
    }
}

void SongPacker::packPatternData(DMF::Song const& song)
{
    _buffer.clear();
    
    for(size_t i=0; i<song.infos.systemChanCount; i++)
    {
        for(size_t j=0; j<_matrix[i].dataOffset.size(); j++)
        {
            size_t k = 0;
            size_t l = _matrix[i].dataOffset[j];
            
            size_t rest;
            
            _matrix[i].bufferOffset.push_back(_buffer.size());
            
            for(rest=0; (k<song.infos.totalRowsPerPattern) && isEmpty(song.patternData[l]); k++, l++, rest++)
            {}
            if(rest)
            {
                if(rest >= 128)
                {
                    _buffer.push_back(PCE::RestEx);
                    _buffer.push_back(rest);
                }
                else
                {
                    _buffer.push_back(PCE::Rest | rest);
                }
            }
            
            while(k<song.infos.totalRowsPerPattern)
            {
                if(100 == song.patternData[l].note)
                {
                    _buffer.push_back(PCE::NoteOff);
                }
                else if((0 != song.patternData[l].note) && (0 != song.patternData[l].octave))
                {
                    uint8_t dummy;
                    // Let's fix octave and notes...
                    dummy  = (song.patternData[l].note % 12) & 0x0f;
                    dummy |= ((song.patternData[l].octave + (dummy ? 1 : 2)) & 0x0f) << 4;
                    _buffer.push_back(PCE::Note);
                    _buffer.push_back(dummy);
                }
                
                if(0xffff != song.patternData[l].volume)
                {
                    _buffer.push_back(PCE::SetVolume);
                    _buffer.push_back(song.patternData[l].volume);
                }
                
                if(0xffff != song.patternData[l].instrument)
                {
                    _buffer.push_back(PCE::SetInstrument);
                    _buffer.push_back(song.patternData[l].instrument);
                }
                
                for(size_t m=0; m<song.effectCount[i]; m++)
                {
                    if((0xffff != song.patternData[l].effect[m].code) && (0xffff != song.patternData[l].effect[m].data))
                    {
						uint8_t data;
						data = song.patternData[l].effect[m].data;
						// Preprocess / fix 
						// [todo] make a shiny method to fix effects!
						// - Volume slide
                        if(0x0A == song.patternData[l].effect[m].code)
                        {
							if(data > 0x0f)
							{	// Positive delta.
								data >>= 4;
							}
							else
							{	// Negative delta.
								data = ((data & 0x0f) ^ 0xff) + 1;
							}
						}
                        _buffer.push_back(song.patternData[l].effect[m].code);
                        _buffer.push_back(data);
                    }
                }

                k++;
                l++;

                for(rest=0; (k<song.infos.totalRowsPerPattern) && isEmpty(song.patternData[l]); k++, l++, rest++)
                {}
                if(rest >= 128)
                {
                    _buffer.push_back(PCE::RestEx);
                    _buffer.push_back(rest);
                }
                else
                {
                    _buffer.push_back(PCE::Rest | rest);
                }
            }
        }
        _matrix[i].bufferOffset.push_back(_buffer.size());
    }
}

bool SongPacker::output(Writer& writer)
{
    bool ret;
    // [todo] more serious error handling.
    ret = writer.write(_infos);
    
    ret = writer.write(_waveTable);
    
    ret = writer.writeInstruments(_instruments);
    
    ret = writer.write(_infos, _pattern);
    
    ret = writer.writePatterns(_infos, _matrix, _buffer);
    
    return ret;
}

} // PCE
