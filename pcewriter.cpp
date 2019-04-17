// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#include <regex>
#include <cstdio>
#include <cstring>
#include <cerrno>

#include <iostream>

#include "pcewriter.h"

namespace PCE {

Writer::Writer(std::string const& filename)
    : _filename(filename)
    , _prefix("")
    , _output(nullptr)
{}

Writer::~Writer() {
    close();
}

bool Writer::open() {
    close();
    
    _output = fopen(_filename.c_str(), "wb");
    if(!_output) {
        fprintf(stderr, "Failed to open %s: %s\n", _filename.c_str(), strerror(errno));
        return false;
    }
    return true;
}

void Writer::close() {
    if(_output) {
        fclose(_output);
        _output = nullptr;
    }
}

bool Writer::write(DMF::Infos const& infos, size_t instrument_count) {
    if(infos.name.length) {
        _prefix.assign(infos.name.data, infos.name.length);
        // Replace any invalid char by '_'.
        std::regex reg("([^[:alnum:]._])");
        _prefix = regex_replace(_prefix, reg, std::string("_"));
    }
    else {
        _prefix = "song";
    }
    
    fprintf(_output, "%s.timeBase:        .db $%02x\n"
                     "%s.timeTick:        .db $%02x, $%02x\n"
                     "%s.patternRows:     .db $%02x\n"
                     "%s.matrixRows:      .db $%02x\n"
                     "%s.instrumentCount: .db $%02x\n"
                     "%s.pointers:\n"
                     "    .dw %s.wav\n"
                     "    .dw %s.instruments\n"
                     "    .dw %s.matrix\n",
                     _prefix.c_str(), infos.timeBase,
                     _prefix.c_str(), infos.tickTime[0], infos.tickTime[1],
                     _prefix.c_str(), infos.totalRowsPerPattern,
                     _prefix.c_str(), infos.totalRowsInPatternMatrix,
                     _prefix.c_str(), (uint8_t)instrument_count,
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str());
                    
    fprintf(_output, "%s.name:          .db \"%s\"\n"
                     "%s.author:        .db \"%s\"\n",
                     _prefix.c_str(), infos.name.data,
                     _prefix.c_str(), infos.author.data);
    
    return true;
}

bool Writer::writeBytes(const uint8_t* buffer, size_t size, size_t elementsPerLine) {
    for(size_t i=0; i<size; ) {
        size_t last = ((elementsPerLine+i)<size) ? elementsPerLine : (size-i);
        fprintf(_output, "    .db ");
        for(size_t j=0; j<last; j++, i++) {
            fprintf(_output,"$%02x%c", *buffer++, ((j+1) < last) ? ',' : '\n');
        }
    }
    return true;
}

bool Writer::writePointerTable(const char* pointerBasename, size_t start, size_t count, size_t elementsPerLine) {
    static char const* postfix[] = { "lo", "hi" };
    static char const* op[] = { "dwl", "dwh" };
    
    // Compute element char count and adjust elements per line.
    size_t elementCharLen = _prefix.size() + strlen(pointerBasename) + 8;
    if((elementCharLen*elementsPerLine) >= MAX_CHAR_PER_LINE) {
		elementsPerLine = MAX_CHAR_PER_LINE / elementCharLen;
	}
    
    for(int p=0; p<2; p++) {
        fprintf(_output, "%s.%s.%s:\n", _prefix.c_str(), pointerBasename, postfix[p]);
        for(size_t i=0; i<count;) {
            size_t last = ((i+elementsPerLine) < count) ? elementsPerLine : (count-i);
            fprintf(_output, "    .%s ", op[p]);
            for(size_t j=0; j<last; j++, i++) {
                fprintf(_output, "%s.%s_%04x%c", _prefix.c_str(), pointerBasename, static_cast<uint32_t>(start+i), (j<(last-1))?',':'\n');
            }
        }
    }
    return true;
}

bool Writer::writePointerTable(const char* table, const char* element, const std::vector<int>& index, size_t elementsPerLine) {
    static char const* postfix[] = { "lo", "hi" };
    static char const* op[] = { "dwl", "dwh" };
    
    // Compute element char count and adjust elements per line.
    size_t elementCharLen = _prefix.size() + strlen(element) + 8;
    if((elementCharLen*elementsPerLine) >= MAX_CHAR_PER_LINE) {
		elementsPerLine = MAX_CHAR_PER_LINE / elementCharLen;
	}
    
    size_t count = index.size();

    for(int p=0; p<2; p++) {
        fprintf(_output, "%s.%s.%s:\n", _prefix.c_str(), table, postfix[p]);
        for(size_t i=0; i<count;) {
            size_t last = ((i+elementsPerLine) < count) ? elementsPerLine : (count-i);
            fprintf(_output, "    .%s ", op[p]);
            for(size_t j=0; j<last; j++, i++) {
                fprintf(_output, "%s.%s_%04x%c", _prefix.c_str(), element, index[i], (j<(last-1))?',':'\n');
            }
        }
    }
    return true;
}

bool Writer::write(DMF::Infos const& infos, std::vector<uint8_t> const& pattern) {
    bool ret = true;
    fprintf(_output, "%s.matrix:\n", _prefix.c_str());
    for(unsigned int j=0; ret && (j<infos.systemChanCount); j++) {
        fprintf(_output, "%s.matrix_%04x:\n", _prefix.c_str(), j);
        ret = writeBytes(&pattern[j*infos.totalRowsInPatternMatrix], infos.totalRowsInPatternMatrix, 16);
    }
    return ret;
}

bool Writer::writeInstruments(InstrumentList const& instruments) {
    bool ret  = true;
    const char* names[InstrumentList::EnvelopeCount] = {
        "volume",
        "arpeggio"
    };
    char buffer[64];
    
    fprintf(_output, "%s.instruments:\n", _prefix.c_str());
    for(size_t i=0; ret && (i<InstrumentList::EnvelopeCount); i++) {
        sprintf(buffer, "instruments.%s", names[i]);
        fprintf(_output, "%s.%s.size:\n", _prefix.c_str(), buffer);
        if(ret) {
            ret = writeBytes(&instruments.env[i].size[0], instruments.count, 16);
            if(ret) {
                fprintf(_output, "%s.%s.loop:\n", _prefix.c_str(), buffer);
                ret = ret && writeBytes(&instruments.env[i].loop[0], instruments.count, 16);
                ret = ret && writePointerTable(buffer, 0, instruments.count, 8);
            }
        }
    }
    
    for(size_t i=0; ret && (i<InstrumentList::EnvelopeCount); i++) {
        for(unsigned int j=0; ret && (j<instruments.count); j++) {
            fprintf(_output, "%s.instruments.%s_%04x:\n", _prefix.c_str(), names[i], j);
            if(instruments.env[i].size[j]) {
                ret = writeBytes(&instruments.env[i].data[j][0], instruments.env[i].size[j], 16);
            }
        }
    }
    
    return ret;
}

bool Writer::writePatterns(DMF::Infos const& infos, std::vector<PatternMatrix> const& matrix) {
    bool ret = true;
    size_t index;    
    fprintf(_output, "%s.matrix:\n", _prefix.c_str());
    index = 0;

    char name[256];

    std::vector<int> pattern_index;
    for(size_t i=0; ret && (i<infos.systemChanCount); i++) {
        pattern_index.resize(matrix[i].pattern.size());
        for(size_t j=0; j<matrix[i].pattern.size(); j++) {
            pattern_index[j] = index + matrix[i].pattern[j];
        }
        snprintf(name, 256, "%s.matrix_%04x", _prefix.c_str(), static_cast<uint32_t>(i));
        if(!writePointerTable(name, "pattern", pattern_index, 16)) {
            return false;
        }
        index += matrix[i].packed.size();
    }

    index = 0;
    for(size_t i=0; ret && (i<infos.systemChanCount); i++) {
        ret = writePatternData(matrix[i], index);
    } 
    return ret;
}

bool Writer::writePatternData(PCE::PatternMatrix const& pattern, size_t& index) {
    bool ret = true;
    for(size_t j=0; ret && (j<pattern.bufferOffset.size()-1); j++) {
        fprintf(_output, "%s.pattern_%04x:\n", _prefix.c_str(), static_cast<uint32_t>(index++));
        int offset  = pattern.bufferOffset[j];
        size_t size = pattern.bufferOffset[j+1] - offset;
        ret = writeBytes(&pattern.buffer[offset], size, 16);
    }
    return ret;
}

bool Writer::write(std::vector<WaveTable> const& wavetable) {
    bool ret = true;
    fprintf(_output, "%s.wav:\n", _prefix.c_str());
    for(size_t i=0; ret && (i<wavetable.size()); i++) {
        fprintf(_output, "%s.wav_%04lx:\n", _prefix.c_str(), i);
        ret = writeBytes(&wavetable[i][0], wavetable[i].size(), 16);
    }
    return ret;
}

} // PCE
