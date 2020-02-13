// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#include <regex>
#include <cstdio>
#include <cstring>
#include <cerrno>

#include "pcewriter.h"

#define MAX_SONG_PREFIX 32

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
        if(_prefix.size() > MAX_SONG_PREFIX) {
            _prefix.resize(MAX_SONG_PREFIX);
        }
    }
    else {
        _prefix = "song";
    }

    _bank = 0;

    fprintf(_output, "    .data\n    .bank DMF_DATA_ROM_BANK+%d\n    .org (DMF_HEADER_MPR << 13)\n", _bank);
    _bank++;

    fprintf(_output, "%s:\n"
                     "%s.timeBase:        .db $%02x\n"
                     "%s.timeTick:        .db $%02x, $%02x\n"
                     "%s.patternRows:     .db $%02x\n"
                     "%s.matrixRows:      .db $%02x\n"
                     "%s.instrumentCount: .db $%02x\n"
                     "%s.pointers:\n"
                     "    .dw %s.wave\n"
                     "    .dw %s.instruments\n"
                     "    .dw %s.matrix\n",
                     _prefix.c_str(),
                     _prefix.c_str(), infos.timeBase,
                     _prefix.c_str(), infos.tickTime[0], infos.tickTime[1],
                     _prefix.c_str(), infos.totalRowsPerPattern,
                     _prefix.c_str(), infos.totalRowsInPatternMatrix,
                     _prefix.c_str(), (uint8_t)instrument_count,
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str(),
                     _prefix.c_str());
                    
    fprintf(_output, "%s.name:\n"
                     "  .db %d\n"
                     "  .db \"%s\"\n"
                     "%s.author:\n"
                     "  .db %d\n"
                     "  .db \"%s\"\n",
                     _prefix.c_str(), (int)strlen(infos.name.data), infos.name.data,
                     _prefix.c_str(), (int)strlen(infos.author.data), infos.author.data);
    
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

bool Writer::writePointerTable(const char* pointerBasename, size_t start, size_t count, size_t elementsPerLine, bool bank) {
    static char const* postfix[] = { "lo", "hi" };
    static char const* op[] = { "dwl", "dwh" };
    
    // Compute element char count and adjust elements per line.
    size_t elementCharLen = _prefix.size() + strlen(pointerBasename) + 8;
    if((elementCharLen*elementsPerLine) >= MAX_CHAR_PER_LINE) {
		elementsPerLine = MAX_CHAR_PER_LINE / elementCharLen;
	}

    if(bank) {
        fprintf(_output, "%s.%s.bank:\n", _prefix.c_str(), pointerBasename);
        for(size_t i=0; i<count;) {
            size_t last = ((i+elementsPerLine) < count) ? elementsPerLine : (count-i);
            fprintf(_output, "    .db ");
            for(size_t j=0; j<last; j++, i++) {
                fprintf(_output, "bank(%s.%s_%04x)%c", _prefix.c_str(), pointerBasename, static_cast<uint32_t>(start+i), (j<(last-1))?',':'\n');
            }            
        }
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

bool Writer::writePointerTable(const char* table, const char* element, const std::vector<int>& index, size_t elementsPerLine, bool bank) {
    static char const* postfix[] = { "lo", "hi" };
    static char const* op[] = { "dwl", "dwh" };
    
    // Compute element char count and adjust elements per line.
    size_t elementCharLen = _prefix.size() + strlen(element) + 8;
    if((elementCharLen*elementsPerLine) >= MAX_CHAR_PER_LINE) {
		elementsPerLine = MAX_CHAR_PER_LINE / elementCharLen;
	}

    size_t count = index.size();

    if(bank) {
        fprintf(_output, "%s.%s.bank:\n", _prefix.c_str(), table);
        for(size_t i=0; i<count;) {
            size_t last = ((i+elementsPerLine) < count) ? elementsPerLine : (count-i);
            fprintf(_output, "    .db ");
            for(size_t j=0; j<last; j++, i++) {
                fprintf(_output, "bank(%s.%s_%04x)%c", _prefix.c_str(), element, index[i], (j<(last-1))?',':'\n');
            }
        }
    }

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
        "arpeggio",
        "wave"
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
    if(ret) {
        fprintf(_output, "%s.instruments.flag:\n", _prefix.c_str());
        ret = writeBytes(&instruments.flag[0], instruments.count, 16);
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
        snprintf(name, 256, "matrix_%04x", static_cast<uint32_t>(i));
        if(!writePointerTable(name, "pattern", pattern_index, 16, true)) {
            return false;
        }
        index += matrix[i].packed.size();
    }

    _output_bytes = 8192;
    index = 0;
    for(size_t i=0; ret && (i<infos.systemChanCount); i++) {
        ret = writePatternData(matrix[i], index);
    } 
    return ret;
}

bool Writer::writePatternData(PCE::PatternMatrix const& pattern, size_t& index) {
    bool ret = true;
    for(size_t j=0; ret && (j<pattern.buffer.size()); j++) {
        size_t next = _output_bytes + pattern.buffer[j].size();
        if(next >= 8192) {
            fprintf(_output, "    .data\n    .bank DMF_DATA_ROM_BANK+%d\n    .org (DMF_DATA_MPR << 13)\n", _bank);
            _bank++;
            _output_bytes = 0;
        }
        fprintf(_output, "%s.pattern_%04x:\n", _prefix.c_str(), static_cast<uint32_t>(index++));
        ret = writeBytes(pattern.buffer[j].data(), pattern.buffer[j].size(), 16);
        _output_bytes += pattern.buffer[j].size();
    }
    return ret;
}

bool Writer::writeBinary(DMF::Infos const& infos, std::vector<WaveTable> const& wavetable, InstrumentList const& instruments, std::vector<PatternMatrix> const& matrix) {
    bool ret = true;
    char filename[256];
    int index = 0;

    std::vector<uint8_t> buffer;

    for(size_t i=0; i<wavetable.size(); i++) {
        buffer.insert(buffer.end(), wavetable[i].begin(), wavetable[i].end());
    }

    uint32_t offset = InstrumentList::EnvelopeCount * (instruments.count*4);
    for(size_t i=0; i<InstrumentList::EnvelopeCount; i++) {
        buffer.insert(buffer.end(), instruments.env[i].size.begin(), instruments.env[i].size.begin()+instruments.count);
        buffer.insert(buffer.end(), instruments.env[i].loop.begin(), instruments.env[i].loop.begin()+instruments.count);

        size_t start = buffer.size();
        size_t n = instruments.count;
        buffer.resize(start + 2*n);
        for(size_t j=0; j<instruments.count; j++) {
            buffer[j  ] = offset & 0xff;
            buffer[j+n] = (offset >> 8) & 0xff;
            offset+= instruments.env[i].size[j];
        } 
    }
    buffer.insert(buffer.end(), instruments.flag.begin(), instruments.flag.begin()+instruments.count);

    for(size_t i=0; i<InstrumentList::EnvelopeCount; i++) {
        for(unsigned int j=0; ret && (j<instruments.count); j++) {
            if(instruments.env[i].size[j]) {
                buffer.insert(buffer.end(), instruments.env[i].data[j].begin(), instruments.env[i].data[j].begin()+instruments.env[i].size[j]);
            }
        }
    }

    offset = 0;
    for(size_t i=0; i<infos.systemChanCount; i++) {
        size_t start = buffer.size();
        size_t n = matrix[i].pattern.size();
        buffer.resize(start + 2*n);
        for(size_t j=0; j<n; j++) {
            size_t k = matrix[i].pattern[j];
            buffer[j  ] = offset & 0xff;
            buffer[j+n] = (offset >> 8) & 0xff;
            offset += matrix[i].buffer[k].size();
        }
    }

    for(size_t i=0; i<infos.systemChanCount; i++) {
        for(size_t j=0; j<matrix[i].buffer.size(); j++) {
            buffer.insert(buffer.end(), matrix[i].buffer[j].begin(), matrix[i].buffer[j].end());
        }
    }

    index=0;
    for(size_t i=0; i<buffer.size(); index++, i+=8192) {
        FILE *out;
        size_t len = (buffer.size() - i);
        if(len > 8192) len = 8192;
        snprintf(filename, 256, "%s_%04x.bin", _prefix.c_str(), index);
        out = fopen(filename, "wb");
        fwrite(&buffer[i], 1, len, out);
        fclose(out);
    }
    return ret;
}

bool Writer::write(std::vector<WaveTable> const& wavetable) {
    bool ret = true;
    fprintf(_output, "%s.wave:\n", _prefix.c_str());
    for(size_t i=0; ret && (i<wavetable.size()); i++) {
        fprintf(_output, "%s.wave_%04lx:\n", _prefix.c_str(), i);
        ret = writeBytes(&wavetable[i][0], wavetable[i].size(), 16);
    }
    return ret;
}

} // PCE
