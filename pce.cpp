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
    std::copy(song.patternMatrix.begin(), song.patternMatrix.end(), _pattern.begin());
    
    _instruments.resize(song.instrument.size());
    for(size_t i=0; i<_instruments.size(); i++)
    {
        _instruments[i].pack(song.instrument[i]);
    }
    
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

void Envelope::pack(DMF::Envelope const& src)
{
    size = src.size;
    loop = src.loop;
    for(size_t i=0; i<size; i++)
    {
        data[i] = src.value[4*i];
    }
}

void Instrument::pack(DMF::Instrument const& src)
{
    mode = src.mode;
    standard.arpeggioMode = src.std.arpeggioMode;
    standard.volume.pack(src.std.volume);
    standard.arpeggio.pack(src.std.arpeggio);
    standard.noise.pack(src.std.noise);
    standard.wave.pack(src.std.wave);
}

void SongPacker::packPatternMatrix(DMF::Song const& song)
{
    _matrix.resize(song.infos.systemChanCount);
    
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
        }
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
                        _buffer.push_back(song.patternData[l].effect[m].code);
                        _buffer.push_back(song.patternData[l].effect[m].data);
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
    
    ret = writer.write(_infos);
    
    ret = writer.write(_waveTable);
    
    ret = writer.write(_infos, _pattern);
    
    ret = writer.writePatterns(_infos, _matrix, _buffer);
    
    return ret;
}

} // PCE
