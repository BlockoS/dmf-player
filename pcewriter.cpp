#include <regex>
#include <cstdio>
#include <cstring>
#include <cerrno>

#include <iostream>

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
    // Replace any invalid char by '_'.
    std::regex reg("([^[:alnum:]._])");
    _prefix = regex_replace(_prefix, reg, "_");
    
    fprintf(_output, "%s.name:          .db \"%s\"\n"
                     "%s.author:        .db \"%s\"\n"
                     "%s.timeBase:      .db $%02x\n"
                     "%s.timeTick:      .db $%02x, $%02x\n"
                     "%s.patternRows:   .db $%02x\n"
                     "%s.matrixRows:    .db $%02x\n"
                     "%s.arpeggioSpeed: .db $%02x\n"
                     "%s.pointers:\n"
                     "    .dw %s.wav.lo\n"
                     "    .dw %s.wav.hi\n"
                     "    .dw %s.matrix.lo\n"
                     "    .dw %s.matrix.hi\n"
                     "    .dw %s.pattern.hi\n"
                     "    .dw %s.pattern.lo\n",
                     _prefix.c_str(), infos.name.data,
                     _prefix.c_str(), infos.author.data,
                     _prefix.c_str(), infos.timeBase,
                     _prefix.c_str(), infos.tickTime[0], infos.tickTime[1],
                     _prefix.c_str(), infos.totalRowsPerPattern,
                     _prefix.c_str(), infos.totalRowsInPatternMatrix,
                     _prefix.c_str(), infos.arpeggioTickSpeed,
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str());
    return true;
}

bool Writer::writeBytes(const uint8_t* buffer, size_t size, size_t elementsPerLine)
{
    for(size_t i=0; i<size; )
    {
        size_t last = ((elementsPerLine+i)<size) ? elementsPerLine : (size-i);
        fprintf(_output, "\t.db ");
        for(size_t j=0; j<last; j++, i++)
        {
            fprintf(_output,"$%02x%c", *buffer++, ((j+1) < last) ? ',' : '\n');
        }
    }
    return true;
}

bool Writer::writePointerTable(const char* pointerBasename, size_t count, size_t elementsPerLine)
{
    static char const* postfix[] = { "lo", "hi" };
    static char const* op[] = { "dwl", "dwh" };
    
    for(int p=0; p<2; p++)
    {
        fprintf(_output, "%s.%s.%s:\n", _prefix.c_str(), pointerBasename, postfix[p]);
        for(size_t i=0; i<count;)
        {
            size_t last = ((i+elementsPerLine) < count) ? elementsPerLine : (count-i);
            fprintf(_output, "\t.%s ", op[p]);
            for(size_t j=0; j<last; j++, i++)
            {
                fprintf(_output, "%s.%s_%04x%c", _prefix.c_str(), pointerBasename, static_cast<uint32_t>(i), (j<(last-1))?',':'\n');
            }
        }
    }
    
    return true;
}

bool Writer::write(DMF::Infos const& infos, std::vector<uint8_t> const& pattern)
{
    bool ret = true;

    ret = writePointerTable("matrix", infos.systemChanCount, 4);

    for(unsigned int j=0; ret && (j<infos.systemChanCount); j++)
    {
        fprintf(_output, "%s.matrix_%04x:\n", _prefix.c_str(), j);
        ret = writeBytes(&pattern[j*infos.totalRowsInPatternMatrix], infos.totalRowsInPatternMatrix, 16);
    }
    return ret;
}

bool Writer::writePatterns(DMF::Infos const& infos, std::vector<PatternMatrix> const& matrix, std::vector<uint8_t> const& buffer)
{
    bool ret = true;
    size_t count = 0;

    for(size_t i=0; ret && (i<infos.systemChanCount); i++)
    {
        ret = writePatternData(matrix[i], buffer, count);
        count += matrix[i].dataOffset.size();
    }
    
    if(ret)
    {
        ret = writePointerTable("pattern", count, 4);
    }

    return ret;
}

bool Writer::writePatternData(PCE::PatternMatrix const& pattern, std::vector<uint8_t> const& buffer, size_t index)
{
    bool ret = true;

    for(size_t j=0; ret && (j<pattern.dataOffset.size()); j++)
    {
        fprintf(_output, "%s.pattern_%04x:\n", _prefix.c_str(), static_cast<uint32_t>(index++));
        int offset  = pattern.bufferOffset[j];
        size_t size = pattern.bufferOffset[j+1] - pattern.bufferOffset[j];
        ret = writeBytes(&buffer[offset], size, 16);
    }
    return ret;
}

bool Writer::write(std::vector<WaveTable> const& wavetable)
{
    bool ret;
    ret = writePointerTable("wav", wavetable.size(), 4);
    
    for(size_t i=0; ret && (i<wavetable.size()); i++)
    {
        fprintf(_output, "%s.wav_%04lx:\n", _prefix.c_str(), i);
        ret = writeBytes(&wavetable[i][0], wavetable[i].size(), 16);
    }
    return ret;
}

#if 0
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
    outputTracks(stream);
}
#endif

} // PCE
