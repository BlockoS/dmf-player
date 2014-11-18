#include <cstdlib>
#include <cstdio>
#include <cstring>

#include "pce.h"

namespace PCE {

SongPacker::SongPacker()
{}

SongPacker::~SongPacker()
{}

static void outputPointerTable(FILE *stream, char const* prefix, size_t count, size_t perLine=16)
{
    static char const* postfix[] = { "lo", "hi" };
    static char const* op[] = { "low", "high" };
    
    for(int p=0; p<2; p++)
    {
        fprintf(stream, "%s.%s:\n", prefix, postfix[p]);
        for(size_t i=0; i<count;)
        {
            size_t last = ((i+perLine) < count) ? perLine : (count-i);
            fprintf(stream, "\t.db ");
            for(size_t j=0; j<last; j++, i++)
            {
                fprintf(stream, "%s(%s_%04x)%c", op[p], prefix, static_cast<uint32_t>(i), (j<(last-1))?',':'\n');
            }
        }
    }
}

void SongPacker::outputPatternMatrix(FILE* stream)
{
    char const* name = "matrix";
    fprintf(stream, "%s:\n", name);
    for(size_t i=0; i<_infos.systemChanCount; i++)
    {
        size_t size = _infos.totalRowsInPatternMatrix;
        fprintf(stream, "%s_%04x:\n", name, static_cast<uint32_t>(i));
        for(size_t j=0; j<size;)
        {
            size_t last = ((16+j)<size) ? 16 : (size-j);
            fprintf(stream, "\t.db ");
            for(size_t k=0; k<last; k++, j++)
            {
                fprintf(stream, "$%02x%c", static_cast<uint32_t>( _pattern[(size*i)+j]), (k<(last-1))?',':'\n');
            }
        }
    }
}

void SongPacker::Envelope::output(FILE* stream, char const* prefix, char const* name, uint32_t index)
{
    fprintf(stream, "%s_%s_%04x:\n", prefix, name, index);
    fprintf(stream, "\t.db $%02x,$%02x ; size, loop\n", size, loop);
    for(uint8_t i=0; i<size;)
    {
        uint8_t last = ((16+i)<size) ? 16 : (size-i);
        fprintf(stream, "\t.db ");
        for(uint8_t j=0; j<last; j++, i++)
        {
            fprintf(stream, "$%02x%c", data[i], (j<(last-1))?',':'\n');
        }
    }
}

void SongPacker::Instrument::output(FILE *stream, char const* prefix, uint32_t index)
{
    // standard
    fprintf(stream, "%s_%04x:\n", prefix, index);
    fprintf(stream, "\t.db $%02x ; arpeggio mode\n", standard.arpeggioMode);
    
    standard.volume.output  (stream, prefix, "volume",   index);
    standard.arpeggio.output(stream, prefix, "arpeggio", index);
    standard.noise.output   (stream, prefix, "noise",    index);
    standard.wave.output    (stream, prefix, "wave",     index);
}

void SongPacker::outputWave(FILE *stream)
{
    for(size_t i=0; i<_waveTable.size(); i++)
    {
        fprintf(stream, "wave_%04x:\n", static_cast<uint32_t>(i));
        for(size_t j=0; j<_waveTable[i].size();)
        {
            size_t last = ((j+16) < _waveTable[i].size()) ? 16 : (_waveTable[i].size()-j);
            fprintf(stream, "\t.db ");
            for(size_t k=0; k<last; k++, j++)
            {
                fprintf(stream, "$%02x%c", _waveTable[i][j], (k<(last-1))?',':'\n');
            }
        }
    }
    outputPointerTable(stream, "wave", _waveTable.size(), 4);
}

void SongPacker::outputInstruments(FILE *stream)
{
    for(size_t i=0; i<_instruments.size(); i++)
    {
        _instruments[i].output(stream, "inst", i);
    }
    outputPointerTable(stream, "inst", _instruments.size(), 4);
}

void SongPacker::output(FILE *stream)
{
    outputPatternMatrix(stream);
    outputWave(stream);
    outputInstruments(stream);
}

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

void SongPacker::Envelope::pack(DMF::Envelope const& src)
{
    size = src.size;
    loop = src.loop;
    for(size_t i=0; i<size; i++)
    {
        data[i] = src.value[4*i];
    }
}

void SongPacker::Instrument::pack(DMF::Instrument const& src)
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
    // [todo] save buffer offset per matrix element
    for(size_t i=0; i<song.infos.systemChanCount; i++)
    {
        for(size_t j=0; j<_matrix[i].dataOffset.size(); j++)
        {
            size_t k = 0;
            size_t l = _matrix[i].dataOffset[j];
            
            size_t rest;
            
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
                    dummy = ((song.patternData[l].note & 0x0f) << 4) | (song.patternData[l].octave & 0x0f);
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
            }
        }
    }
}

} // PCE
