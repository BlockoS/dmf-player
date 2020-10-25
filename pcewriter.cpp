// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#include <regex>
#include <cstdio>
#include <cstring>
#include <cerrno>

#include "pcewriter.h"

namespace PCE {

struct Context {
    std::string filename;
    FILE       *stream;
    size_t      output_bytes;
    uint32_t    bank;
};


static bool open(const std::string &in, Context &ctx) {
    ctx.filename = in;
    ctx.stream = fopen(in.c_str(), "wb");
    if(!ctx.stream) {
        fprintf(stderr, "Failed to open %s: %s\n", in.c_str(), strerror(errno));
        return false;
    }
    ctx.bank = 0;
    ctx.output_bytes = 0;
    return true;
}

static void close(Context &ctx) {
    if(ctx.stream) {
        fclose(ctx.stream);
        ctx.stream = nullptr;
    }
}

#define ELEMENTS_PER_LINE 16

static void write_ptr_tbl(Context &ctx, const char* prefix, const char* suffix, size_t start, size_t count, size_t elements_per_line, bool bank) {
    static char const* postfix[] = { "lo", "hi" };
    static char const* op[] = { "dwl", "dwh" };
    
    if(bank) {
        fprintf(ctx.stream, "%s.%s.bank:\n", prefix, suffix);
        for(size_t i=0; i<count;) {
            fprintf(ctx.stream, "    .db bank(%s%02x.%s)", prefix, static_cast<uint32_t>(start+i), suffix);
            i++;
            for(size_t j=1; (j<elements_per_line) && (i<count); j++, i++) {
                fprintf(ctx.stream, ",bank(%s%02x.%s)", prefix, static_cast<uint32_t>(start+i), suffix);
            }
            fprintf(ctx.stream, "\n");
        }
    }
    
    for(int p=0; p<2; p++) {
        fprintf(ctx.stream, "%s.%s.%s:\n", prefix, suffix, postfix[p]);
        for(size_t i=0; i<count;) {
            fprintf(ctx.stream, "    .%s %s%02x.%s", op[p], prefix, static_cast<uint32_t>(start+i), suffix);
            i++;
            for(size_t j=1; (j<elements_per_line) && (i<count); j++, i++) {
                fprintf(ctx.stream, ",%s%02x.%s", prefix, static_cast<uint32_t>(start+i), suffix);
            }
            fprintf(ctx.stream, "\n");
        }
    }
}

static void write_ptr_tbl(Context &ctx, const char* name, size_t start, size_t count, size_t elements_per_line, bool bank) {
    static char const* postfix[] = { "lo", "hi" };
    static char const* op[] = { "dwl", "dwh" };
    
    if(bank) {
        fprintf(ctx.stream, "%s.bank:\n", name);
        for(size_t i=0; i<count;) {
            fprintf(ctx.stream, "    .db bank(%s%02x)", name, static_cast<uint32_t>(start+i));
            i++;
            for(size_t j=1; (j<elements_per_line) && (i<count); j++, i++) {
                fprintf(ctx.stream, ",bank(%s%02x)", name, static_cast<uint32_t>(start+i));
            }
            fprintf(ctx.stream, "\n");
        }
    }
    
    for(int p=0; p<2; p++) {
        fprintf(ctx.stream, "%s.%s:\n", name, postfix[p]);
        for(size_t i=0; i<count;) {
            fprintf(ctx.stream, "    .%s %s%02x", op[p], name, static_cast<uint32_t>(start+i));
            i++;
            for(size_t j=1; (j<elements_per_line) && (i<count); j++, i++) {
                fprintf(ctx.stream, ",%s%02x", name, static_cast<uint32_t>(start+i));
            }
            fprintf(ctx.stream, "\n");
        }
    }
}

template <typename T>
static void write_tbl(Context &ctx, std::vector<T> const& elmnt, size_t elements_per_line) {
    for(size_t i=0; i<elmnt.size();) {
        fprintf(ctx.stream, "    .db $%02x", static_cast<uint8_t>(elmnt[i++]));
        for(size_t j=1; (j<elements_per_line) && (i<elmnt.size()); j++, i++) {
            fprintf(ctx.stream, ",$%02x", static_cast<uint32_t>(elmnt[i]));
        }
        fprintf(ctx.stream, "\n");
    }
}

static bool write_bytes(Context &ctx, const uint8_t* buffer, size_t size, size_t elements_per_line) {
    for(size_t i=0; i<size; ) {
        fprintf(ctx.stream, "    .db $%02x", *buffer++);
        i++;
        for(size_t j=1; (j<elements_per_line) && (i<size); j++, i++) {
            fprintf(ctx.stream,",$%02x", *buffer++);
        }
        fprintf(ctx.stream, "\n");
    }
    return true;
}

static void write_instruments(Context &ctx, const char *prefix, InstrumentList const& instruments) {
    const char* names[InstrumentList::EnvelopeCount] = {
        "vol",
        "arp",
        "wav"
    };
    char buffer[64];
    
    fprintf(ctx.stream, "%s.it:\n", prefix);
    for(size_t i=0; i<InstrumentList::EnvelopeCount; i++) {
        sprintf(buffer, "it.%s", names[i]);
        fprintf(ctx.stream, "%s.%s.size:\n", prefix, buffer);
        write_bytes(ctx, &instruments.env[i].size[0], instruments.count, 16);
        fprintf(ctx.stream, "%s.%s.loop:\n", prefix, buffer);
        write_bytes(ctx, &instruments.env[i].loop[0], instruments.count, 16);
        
        sprintf(buffer, "%s.it.%s", prefix, names[i]);
        write_ptr_tbl(ctx, buffer, 0, instruments.count, 8, false);
    }
    fprintf(ctx.stream, "%s.it.flag:\n", prefix);
    write_bytes(ctx, &instruments.flag[0], instruments.count, 16);
    
    for(size_t i=0; i<InstrumentList::EnvelopeCount; i++) {
        for(unsigned int j=0; j<instruments.count; j++) {
            fprintf(ctx.stream, "%s.it.%s%02x:\n", prefix, names[i], static_cast<uint8_t>(j));
            if(instruments.env[i].size[j]) {
                write_bytes(ctx, &instruments.env[i].data[j][0], instruments.env[i].size[j], 16);
            }
        }
    }
}

static bool write_header(Context &ctx, Packer const &in) {
#define print(name, member) \
do { \
    fprintf(ctx.stream, #name":\n"); \
    for(size_t i=0; i<in.song.size(); ) { \
        fprintf(ctx.stream, "    .db %d", (int)in.song[i++].member); \
        for(size_t j=1; (j<ELEMENTS_PER_LINE) && (i < in.song.size()); j++, i++) { \
            fprintf(ctx.stream, ",%d", (int)in.song[i].member); \
        } \
        fprintf(ctx.stream,"\n"); \
    } \
} while(0)

    fprintf(ctx.stream, "    .data\n    .bank DMF_DATA_ROM_BANK+%d\n    .org (DMF_HEADER_MPR << 13)\n", ctx.bank);
    fprintf(ctx.stream, "song.count: .db %ld\n", in.song.size());

    print(song.time_base, infos.timeBase);
    print(song.time_tick_0, infos.tickTime[0]);
    print(song.time_tick_1, infos.tickTime[1]);
    print(song.pattern_rows, infos.totalRowsPerPattern);
//    write_ptr_tbl(ctx, "song", "ptr", 0, in.song.size(), ELEMENTS_PER_LINE/2, true);
    print(song.matrix_rows, infos.totalRowsInPatternMatrix);
//    write_ptr_tbl(ctx, "song", "mtx", 0, in.song.size(), ELEMENTS_PER_LINE/2, true);
    print(song.instrument_count, instruments.count);
    print(song.sample_count, sample.size());
    write_ptr_tbl(ctx, "song" ,"sp", 0, in.song.size(), ELEMENTS_PER_LINE/2, false);

    write_ptr_tbl(ctx, "song.wv", 0, in.wave.size(), ELEMENTS_PER_LINE/2, false);
    for(size_t i=0; i<in.wave.size(); i++) {
        fprintf(ctx.stream, "song.wv%02x:\n", static_cast<uint8_t>(i));
        write_bytes(ctx, in.wave[i].data(), in.wave[i].size(), ELEMENTS_PER_LINE);
    }

    for(size_t i=0; i<in.song.size(); i++) {
        fprintf(ctx.stream, "song%02x.sp:\n", static_cast<uint8_t>(i));
        write_tbl(ctx, in.song[i].sample, ELEMENTS_PER_LINE);
    }

    for(size_t i=0; i<in.song.size(); i++) {
        char prefix[256];
        snprintf(prefix, 256, "song%02x", static_cast<uint8_t>(i));
        write_instruments(ctx, prefix, in.song[i].instruments);
    }

// [todo] write matrices

#undef print

    return true;
}

// [todo] write samples
// [todo] write patterns

bool write(std::string const& filename, Packer const& in) {
    Context ctx;
    if(!open(filename, ctx)) {
        return false;
    }
    if(!write_header(ctx, in)) {
        return false;
    }
    close(ctx);
    return true;
}

} // PCE

#if 0

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

bool Writer::writeSamplesInfos(std::vector<Sample> const& samples, size_t elementsPerLine) {
    static char const* postfix[] = { "lo", "hi" };
    static char const* op[] = { "dwl", "dwh" };
    const size_t count = samples.size();

    bool ret = true;

    fprintf(_output, "%s.samples:\n", _prefix.c_str());    
    fprintf(_output, "%s.samples.count:\n    .db $%02x\n", _prefix.c_str(), static_cast<uint32_t>(count));    
    for(int p=0; p<2; p++) {
        fprintf(_output, "%s.samples.offset.%s:\n", _prefix.c_str(), postfix[p]);
        for(size_t i=0; i<count;) {
            size_t last = ((i+4) < count) ? 4 : (count-i);
            fprintf(_output, "    .%s ", op[p]);
            for(size_t j=0; j<last; j++, i++) {
                fprintf(_output, "%s.sample_%04x%c", _prefix.c_str(), static_cast<uint32_t>(i), (j<(last-1))?',':'\n');
            }
        }
    }
    fprintf(_output, "%s.samples.bank:\n", _prefix.c_str());
    for(size_t i=0; i<count;) {
        size_t last = ((i+4) < count) ? 4 : (count-i);
        fprintf(_output, "    .db ");
        for(size_t j=0; j<last; j++, i++) {
            fprintf(_output, "bank(%s.sample_%04x)%c", _prefix.c_str(), static_cast<uint32_t>(i), (j<(last-1))?',':'\n');
        }
    }

    return ret;
}

bool Writer::writeSamples(std::vector<Sample> const& samples) {
    bool ret = true;

    for(size_t j=0; ret && (j<samples.size()); j++) {
        size_t start = 0;
        size_t end = samples[j].data.size();
        fprintf(_output, "%s.sample_%04x:\n", _prefix.c_str(), static_cast<uint32_t>(j));      
        while(ret && (start < end)) {
            size_t count = ((start+16) > end) ? (end-start) : 16;
            size_t next = _output_bytes + count;
            if(next >= 8192) {
                count = 8192 - _output_bytes;
            }
            ret = writeBytes(samples[j].data.data()+start, count, 16);
            if(next >= 8192) {
                fprintf(_output, "    .data\n    .bank DMF_DATA_ROM_BANK+%d\n    .org (DMF_DATA_MPR << 13)\n", _bank);
                _bank++;
                _output_bytes = 0;
            }
            else {
                _output_bytes += count;
            }
            start += count;
        }
    }
    return ret;
}
#endif
