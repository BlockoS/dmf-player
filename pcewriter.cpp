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

static void write_bytes(Context &ctx, const uint8_t* buffer, size_t size, size_t elements_per_line) {
    for(size_t i=0; i<size; ) {
        fprintf(ctx.stream, "    .db $%02x", *buffer++);
        i++;
        for(size_t j=1; (j<elements_per_line) && (i<size); j++, i++) {
            fprintf(ctx.stream,",$%02x", *buffer++);
        }
        fprintf(ctx.stream, "\n");
    }
}


static void write_ptr_tbl(Context &ctx, const char *prefix, const char* table, const char* element, const std::vector<int>& index, size_t elements_per_line, bool bank) {
    static char const* postfix[] = { "lo", "hi" };
    static char const* op[] = { "dwl", "dwh" };
    
    // Compute element char count and adjust elements per line.
    size_t element_char_len = strlen(prefix) + strlen(element) + 8;
    if((element_char_len*elements_per_line) >= MAX_CHAR_PER_LINE) {
		elements_per_line = MAX_CHAR_PER_LINE / element_char_len;
	}

    size_t count = index.size();

    if(bank) {
        fprintf(ctx.stream, "%s.%s.bank:\n", prefix, table);
        for(size_t i=0; i<count;) {
            size_t last = ((i+elements_per_line) < count) ? elements_per_line : (count-i);
            fprintf(ctx.stream, "    .db ");
            for(size_t j=0; j<last; j++, i++) {
                fprintf(ctx.stream, "bank(%s.%s%02x)%c", prefix, element, index[i], (j<(last-1))?',':'\n');
            }
        }
    }

    for(int p=0; p<2; p++) {
        fprintf(ctx.stream, "%s.%s.%s:\n", prefix, table, postfix[p]);
        for(size_t i=0; i<count;) {
            size_t last = ((i+elements_per_line) < count) ? elements_per_line : (count-i);
            fprintf(ctx.stream, "    .%s ", op[p]);
            for(size_t j=0; j<last; j++, i++) {
                fprintf(ctx.stream, "%s.%s%02x%c", prefix, element, index[i], (j<(last-1))?',':'\n');
            }
        }
    }
}

static void write_matrices(Context &ctx, Packer::Song const& in, const char *prefix) {
    char name[256];
    int index;
    std::vector<int> pattern_index;

    index = 0;
    for(size_t i=0; i<in.infos.systemChanCount; i++) {
        std::vector<PatternMatrix> const& matrix = in.matrix;

        pattern_index.resize(matrix[i].pattern.size());
        for(size_t j=0; j<matrix[i].pattern.size(); j++) {
            pattern_index[j] = index + matrix[i].pattern[j];
        }

        snprintf(name, 256, "mat%02x", static_cast<uint8_t>(i));
        write_ptr_tbl(ctx, prefix, name, "pat", pattern_index, ELEMENTS_PER_LINE, false);

        index += matrix[i].packed.size();
    }
}

static void write_pattern(Context &ctx, Packer::Song const& in, const char *prefix) {
    size_t index = 0;

    for(size_t i=0; i<in.infos.systemChanCount; i++) {
        PatternMatrix const& pattern = in.matrix[i];
        for(size_t j=0; j<pattern.buffer.size(); j++) {
            size_t next = ctx.output_bytes + pattern.buffer[j].size();
            if(next >= 8192) {
                fprintf(ctx.stream, "\n    .data\n    .bank DMF_DATA_ROM_BANK+%d\n    .org (DMF_DATA_MPR << 13)\n", ctx.bank);
                ctx.output_bytes = 0;
                ctx.bank++;
            }
            fprintf(ctx.stream, "%s.pat%02x:\n", prefix, static_cast<uint32_t>(index++));
            write_bytes(ctx, pattern.buffer[j].data(), pattern.buffer[j].size(), 16);
            ctx.output_bytes += pattern.buffer[j].size();
        }
    }
}

static void write_instruments(Context &ctx, const char *prefix, InstrumentList const& instruments) {
    const char* names[InstrumentList::EnvelopeCount] = {
        "vol",
        "arp",
        "wav"
    };
    char buffer[256];
    
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


static void write_samples(Context &ctx, const char* prefix, std::vector<Sample> const& samples) {
    for(size_t j=0; j<samples.size(); j++) {
        size_t start = 0;
        size_t end = samples[j].data.size();
        fprintf(ctx.stream, "%s.sample_%04x:\n", prefix, static_cast<uint32_t>(j));      
        while(start < end) {
            size_t count = ((start+16) > end) ? (end-start) : 16;
            size_t next = ctx.output_bytes + count;
            if(next >= 8192) {
                count = 8192 - ctx.output_bytes;
            }
            write_bytes(ctx, samples[j].data.data()+start, count, 16);
            if(next >= 8192) {
                fprintf(ctx.stream, "    .data\n    .bank DMF_DATA_ROM_BANK+%d\n    .org (DMF_DATA_MPR << 13)\n", ctx.bank);
                ctx.output_bytes = 0;
                ctx.bank++;
            }
            else {
                ctx.output_bytes += count;
            }
            start += count;
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
    print(song.matrix_rows, infos.totalRowsInPatternMatrix);
    print(song.instrument_count, instruments.count);
    print(song.sample_count, sample.size());
    write_ptr_tbl(ctx, "song" ,"sp", 0, in.song.size(), ELEMENTS_PER_LINE/4, true);
    write_ptr_tbl(ctx, "song" ,"mat", 0, in.song.size(), ELEMENTS_PER_LINE/2, false);
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

    for(size_t i=0; i<in.song.size(); i++) {
        char name[256];
        snprintf(name, 256, "song%02x", static_cast<uint8_t>(i));
        fprintf(ctx.stream, "%s.mat:\n", name);
        write_matrices(ctx, in.song[i], name);
    }
#undef print

    return true;
}

bool write(std::string const& filename, Packer const& in) {
    Context ctx;
    if(!open(filename, ctx)) {
        return false;
    }
    if(!write_header(ctx, in)) {
        return false;
    }

    ctx.output_bytes = 8192;
    ctx.bank = 1;
    for(size_t i=0; i<in.song.size(); i++) {
        char name[256];
        snprintf(name, 256, "song%02x", static_cast<uint8_t>(i));
        write_pattern(ctx, in.song[i], name);
    }

    write_samples(ctx, "song.sp", in.sample);

    close(ctx);
    return true;
}

} // PCE
