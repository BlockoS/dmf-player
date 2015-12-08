// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
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
    if(infos.name.length)
    {
        _prefix.assign(infos.name.data, infos.name.length);
        // Replace any invalid char by '_'.
        std::regex reg("([^[:alnum:]._])");
        _prefix = regex_replace(_prefix, reg, std::string("_"));
    }
    else
    {
        _prefix = "song";
    }
    
    fprintf(_output, "%s.timeBase:      .db $%02x\n"
                     "%s.timeTick:      .db $%02x, $%02x\n"
                     "%s.patternRows:   .db $%02x\n"
                     "%s.matrixRows:    .db $%02x\n"
                     "%s.arpeggioSpeed: .db $%02x\n"
                     "%s.pointers:\n"
                     "    .dw %s.wav.lo\n"
                     "    .dw %s.wav.hi\n"
                     "    .dw %s.pattern.lo\n"
                     "    .dw %s.pattern.hi\n",
                     _prefix.c_str(), infos.timeBase,
                     _prefix.c_str(), infos.tickTime[0], infos.tickTime[1],
                     _prefix.c_str(), infos.totalRowsPerPattern,
                     _prefix.c_str(), infos.totalRowsInPatternMatrix,
                     _prefix.c_str(), infos.arpeggioTickSpeed,
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str());
                     
    for(unsigned int i=0; i<infos.systemChanCount; i++)
    {
        fprintf(_output, "    .dw %s.matrix_%04x\n", _prefix.c_str(), i);
    }
    
    fprintf(_output, "%s.name:          .db \"%s\"\n"
                     "%s.author:        .db \"%s\"\n",
                     _prefix.c_str(), infos.name.data,
                     _prefix.c_str(), infos.author.data);
    
    return true;
}

bool Writer::writeBytes(const uint8_t* buffer, size_t size, size_t elementsPerLine)
{
    for(size_t i=0; i<size; )
    {
        size_t last = ((elementsPerLine+i)<size) ? elementsPerLine : (size-i);
        fprintf(_output, "    .db ");
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
    
    // Compute element char count and adjust elements per line.
    size_t elementCharLen = _prefix.size() + strlen(pointerBasename) + 8;
    if((elementCharLen*elementsPerLine) >= MAX_CHAR_PER_LINE)
    {
		elementsPerLine = MAX_CHAR_PER_LINE / elementCharLen;
	}
    
    for(int p=0; p<2; p++)
    {
        fprintf(_output, "%s.%s.%s:\n", _prefix.c_str(), pointerBasename, postfix[p]);
        for(size_t i=0; i<count;)
        {
            size_t last = ((i+elementsPerLine) < count) ? elementsPerLine : (count-i);
            fprintf(_output, "    .%s ", op[p]);
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

    for(unsigned int j=0; ret && (j<infos.systemChanCount); j++)
    {
        fprintf(_output, "%s.matrix_%04x:\n", _prefix.c_str(), j);
        ret = writeBytes(&pattern[j*infos.totalRowsInPatternMatrix], infos.totalRowsInPatternMatrix, 16);
    }
    return ret;
}

bool Writer::writeInstruments(InstrumentList const& instruments)
{
    bool   ret  = true;
    const char* names[InstrumentList::EnvelopeCount] =
    {
        "volume",
        "arpeggio"
    };
    char buffer[64];
    
    fprintf(_output, "%s.instruments:\n", _prefix.c_str());
    for(size_t i=0; ret && (i<InstrumentList::EnvelopeCount); i++)
    {
        sprintf(buffer, "instruments.%s", names[i]);
        fprintf(_output, "%s.%s.size:\n", _prefix.c_str(), buffer);
        ret = writeBytes(&instruments.env[i].size[0], instruments.count, 16);
        fprintf(_output, "%s.%s.loop:\n", _prefix.c_str(), buffer);
        ret = writeBytes(&instruments.env[i].loop[0], instruments.count, 16);
        ret = writePointerTable(buffer, instruments.count, 8);
    }
    
    for(size_t i=0; ret && (i<InstrumentList::EnvelopeCount); i++)
    {
        for(unsigned int j=0; j<instruments.count; j++)
        {
            fprintf(_output, "%s.instruments.%s_%04x:\n", _prefix.c_str(), names[i], j);
            if(instruments.env[i].size[j])
            {
                ret = writeBytes(&instruments.env[i].data[j][0], instruments.env[i].size[j], 16);
            }
        }
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

} // PCE
