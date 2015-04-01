#include <cstdio>
#include <cstring>
#include <cerrno>
#include "pcewriter.h"

namespace PCE
{
    
Writer::Writer(std::string const& filename)
    : _filename(filename)
    , _prefix("")
    , _output(nullptr)
{}

Writer::~Writer()
{
    close();
}

bool Writer::open()
{
    close();
    
    _output = fopen(_filename.c_str(), "wb");
    if(nullptr == _output)
    {
        fprintf(stderr, "Failed to open %s: %s\n", _filename.c_str(), strerror(errno));
    }
    return true;
}

void Writer::close()
{
    if(nullptr != _output)
    {
        fclose(_output);
        _output = nullptr;
    }
}

bool Writer::write(DMF::Infos const& infos)
{
    _prefix.assign(infos.name.data, infos.name.length);
    
    fprintf(_output, "%s_name:          .ds \"%s\"\n"
                     "%s_author:        .ds \"%s\"\n"
                     "%s_timeBase:      .db %02x\n"
                     "%s_timeTick:      .db %02x, %02x\n"
                     "%s_patternRows:   .db %02x\n"
                     "%s_matrixRows:    .db %02x\n"
                     "%s_arpeggioSpeed: .db %02x\n",
                     _prefix.c_str(), infos.name.data,
                     _prefix.c_str(), infos.author.data,
                     _prefix.c_str(), infos.timeBase,
                     _prefix.c_str(), infos.tickTime[0], infos.tickTime[1],
                     _prefix.c_str(), infos.totalRowsPerPattern,
                     _prefix.c_str(), infos.totalRowsInPatternMatrix,
                     _prefix.c_str(), infos.arpeggioTickSpeed);
    return true;
}

bool Writer::write(PCE::PatternMatrix const& pattern)
{
    // [todo]
    return true;
}

#if 0
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

void SongPacker::outputTracks(FILE *stream)
{
    fprintf(stream, "pattern:\n");
    size_t count = 0;
    for(size_t i=0; i<_infos.systemChanCount; i++)
    {
        for(size_t j=0; j<_matrix[i].dataOffset.size(); j++, count++)
        {
            fprintf(stream, "pattern_%04x:\n", static_cast<uint32_t>((i*_matrix[i].dataOffset.size())+j));
            int offset = _matrix[i].bufferOffset[j];
            size_t size = _matrix[i].bufferOffset[j+1] - _matrix[i].bufferOffset[j];
            for(size_t k=0; k<size; )
            {
                size_t last = ((16+k)<size) ? 16 : (size-k);
                fprintf(stream, "\t.db ");
                for(size_t l=0; l<last; l++, k++)
                {
                    fprintf(stream,"$%02x%c", _buffer[offset++], ((l+1) < last) ? ',' : '\n');
                }
            }
            
        }
    }
    outputPointerTable(stream, "pattern", count, 4);
}

void SongPacker::output(FILE *stream)
{
    outputPatternMatrix(stream);
    outputWave(stream);
    outputInstruments(stream);
    outputTracks(stream);
}
#endif

} // PCE
