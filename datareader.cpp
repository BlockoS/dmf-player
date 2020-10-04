// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#include <array>
#include <zlib.h>
#include <cstring>
#include <algorithm>

#include "datareader.h"

namespace DMF {

static const char* FormatString = ".DelekDefleMask.";
#define CHUNK_SIZE 16384

/// Constructor
DataReader::DataReader()
    : _buffer()
    , _offset(0)
{}
/// Destructor
DataReader::~DataReader()
{}
/// Decompress input file.
/// @param [in] source Source file.
/// @return true if the file was successfully decompressed.
bool DataReader::decompress(FILE* source) {
    z_stream stream;
    int ret;
    size_t nBytes, offset;

    std::array<uint8_t, CHUNK_SIZE> in, out;

    stream.zalloc   = Z_NULL;
    stream.zfree    = Z_NULL;
    stream.opaque   = Z_NULL;
    stream.avail_in = 0;
    stream.next_in  = Z_NULL;
    
    ret = inflateInit(&stream);
    if(ret != Z_OK) {
        return false;
    }

    bool ok  = true;
    do {
        stream.avail_in = fread(&in[0], 1, in.size(), source);
        if(ferror(source)) {
            ret = Z_ERRNO;
            break;
        }
        if(!stream.avail_in) {
            ok = false;
            break;
        }
        stream.next_in = &in[0];

        do {
            stream.avail_out = out.size();
            stream.next_out  = &out[0];

            ret = inflate(&stream, Z_NO_FLUSH);
            if((ret == Z_STREAM_ERROR) ||
               (ret == Z_DATA_ERROR)   ||
               (ret == Z_MEM_ERROR)) {
                ok = false;
            }
            else {
                nBytes = out.size() - stream.avail_out;
                offset = _buffer.size();
                _buffer.resize(offset + nBytes);
                memcpy(&_buffer[offset], &out[0], nBytes);
            }
        }while(!stream.avail_out && ok);

    }while((ret != Z_STREAM_END) && ok);

    inflateEnd(&stream);
    return (ok && (Z_STREAM_END == ret));
}

/// Load song.
/// @param [in] filename Song filename.
/// @param [out] song Decoded song.
/// @return true if song is successfully loaded.
bool DataReader::load(const std::string& filename, Song &song) {
    FILE *source = fopen(filename.c_str(), "rb");
    if(!source) {
        return false;
    }

    bool ok = decompress(source);
    if(ok) {
        ok = read(song);
    }

    fclose(source);
    return ok;
}
/// Get song raw size.
size_t DataReader::size() {
    return _buffer.size();
}
/// Read a single unsigned byte from buffer.
/// @param [out] v Unsigned byte read from buffer.
/// @return false if there is no data left to be read.
bool DataReader::read(uint8_t& v) {
    if((_buffer.size() - _offset) < 1) {
        return false;
    }
    v = _buffer[_offset++];
    return true;
}
/// Read a single unsigned short (2 bytes) from buffer.
/// @param [out] v Unsigned short read from buffer.
/// @return false if there is no data left to be read.
bool DataReader::read(uint16_t& v) {
    if((_buffer.size() - _offset) < 2) {
        return false;
    }
    v  = _buffer[_offset++];
    v |= _buffer[_offset++] << 8;
    return true;
}
/// Read a single unsigned word (4 bytes) from buffer.
/// @param [out] v Unsigned word read from buffer.
/// @return false if there is no data left to be read.
bool DataReader::read(uint32_t& v) {
    if((_buffer.size() - _offset) < 4) {
        return false;
    }
    v  = _buffer[_offset++];
    v |= _buffer[_offset++] << 8;
    v |= _buffer[_offset++] << 16;
    v |= _buffer[_offset++] << 24;
    return true;
}
/// Read n bytes from buffer.
/// @param [in][out] ptr Pointer to output buffer.
/// @param [in]      nBytes Number of bytes to read.
/// @return false if there is no data left to be read.
bool DataReader::read(void* ptr, size_t nBytes) {
    if((_buffer.size() - _offset) < nBytes) {
        return false;
    }
    memcpy(ptr, &_buffer[_offset], nBytes);
    _offset+= nBytes;
    return true;
}
/// Read string.
/// @param [out] String Output string.
/// @return false if there is no data left to be read.
bool DataReader::read(String& str) {
    bool ok = read(str.length);
    if(ok) {
        ok = read(str.data, str.length);
    }
    return ok;
}
/// Read envelope.
/// @param [out] env Volume envelope.
/// @return false if there is no data left to be read.
bool DataReader::read(Envelope& env) {
    bool ok = read(env.size);
    if(ok && env.size) {
        ok = read(env.value, 4*env.size);
        if(ok) {
            ok = read(env.loop);
        }
    }
    return ok;
}
/// Read a single instrument.
/// @param [out] inst Instrument.
/// @return false if there is no data left to be read.
bool DataReader::read(Instrument& inst) {
    bool ok = read(inst.name);
    if(ok) { 
        ok = read(inst.mode);
    }
    if(!inst.mode) {
        if(ok) { ok = read(inst.std.volume); }
        if(ok) { ok = read(inst.std.arpeggio); }
        if(ok) { ok = read(inst.std.arpeggioMode); }
        if(ok) { ok = read(inst.std.noise); }
        if(ok) { ok = read(inst.std.wave); }
    }
    else {
        fprintf(stderr, "FM instruments are not yet supported!\n");
        ok = false;
    }
    return ok;
}
/// Read a wave table.
/// @param [out] wav Wave table.
/// @return false if there is no data left to be read.
bool DataReader::read(WaveTable& tbl) {
    bool ok;
    uint32_t size;

    ok = read(size);

    if(!size) {
        return true;
    }
    if(!ok) {
        return false;
    }

    tbl.resize(size);
    ok = read(&tbl[0], size*4);
    if(!ok) {
        tbl.clear();
    }
    return ok;
}
/// Read song info.
/// @param [out] Song info.
/// @return false if there is no data left to be read.
bool DataReader::read(Infos& nfo) {
    bool ok;
    ok = read(nfo.version);
    if(ok) {
        ok = read(nfo.system);
    }
    if(ok) {
        switch(nfo.system) {
            case SYSTEM_YMU759:
                nfo.systemChanCount = CHAN_COUNT_YMU759;
                break;
            case SYSTEM_GENESIS:
                nfo.systemChanCount = CHAN_COUNT_GENESIS;
                break;
            case SYSTEM_GENESIS_EXT_CH3:
                nfo.systemChanCount = CHAN_COUNT_GENESIS_EXT_CH3;
                break;
            case SYSTEM_SMS:
                nfo.systemChanCount = CHAN_COUNT_SMS;
                break;
            case SYSTEM_GAMEBOY:
                nfo.systemChanCount = CHAN_COUNT_GAMEBOY;
                break;
            case SYSTEM_PCENGINE:
                nfo.systemChanCount = CHAN_COUNT_PCENGINE;
                break;
            case SYSTEM_NES:
                nfo.systemChanCount = CHAN_COUNT_NES;
                break;
            case SYSTEM_C64_8580:
            case SYSTEM_C64_6581:
                nfo.systemChanCount = CHAN_COUNT_C64;
                break;
            case SYSTEM_YM2151:
                nfo.systemChanCount = CHAN_COUNT_YM2151;
                break;
            default:
                return false;
        };

        ok = read(nfo.name);
    }
    if(ok) { ok = read(nfo.author); }
    if(ok) { ok = read(nfo.highlight, 2); }
    if(ok) { ok = read(nfo.timeBase); }
    if(ok) { ok = read(nfo.tickTime, 2); }
    if(ok) { ok = read(nfo.framesMode); }
    if(ok) { ok = read(nfo.customFreqFlag); }
    if(ok) { ok = read(nfo.customFreqValue, 3); }
    if(ok) { 
        if(nfo.version > 21 ) {
            ok = read(nfo.totalRowsPerPattern);
        }
        else {
            uint8_t dummy;
            ok = read(dummy);
            nfo.totalRowsPerPattern = dummy;
        }
    }
    if(ok) { ok = read(nfo.totalRowsInPatternMatrix); }
    if(ok) {
        if(nfo.version < 21) {
            ok = read(nfo.arpeggioTickSpeed);
        }
    }
    return ok;
}
/// Read pattern data.
/// @param [out] pat Pattern data.
/// @param [in]  effectCount Number of effects per pattern entry.
/// @return false if there is no data left to be read.
bool DataReader::read(PatternData& data, uint8_t effectCount) {
    bool ok;
    ok = read(data.note);
    if(ok) { ok = read(data.octave); }
    if(ok) { ok = read(data.volume); }
    for(size_t i=0; i<DMF_MAX_EFFECT_COUNT; i++) {
        data.effect[i].code = data.effect[i].data = 0xffff;
    }
    for(size_t i=0; ok && (i<effectCount); i++) {
        ok = read(data.effect[i].code);
        if(ok) {
            ok = read(data.effect[i].data);
        }
    }
    if(ok) {
        ok = read(data.instrument);
    }
    return ok;
}
/// Read sample.
/// @param [in] nfo Song infos.
/// @param [out] sample Sample.
/// @return false if there is no data left to be read.
bool DataReader::read(Infos const& nfo, Sample& sample) {
    bool ok;
    uint32_t size;
    ok = read(size);
    if(ok && (nfo.version > 21)) {
        ok = read(sample.name); 
    }
    if(ok) { ok = read(sample.rate); }
    if(ok) { ok = read(sample.pitch); }
    if(ok) { ok = read(sample.amp); }
    if(ok) { ok = read(sample.bits); }
    if(ok && size) {
        sample.data.resize(size);
        for(size_t i=0; ok && (i<size); i++) {
            ok = read(sample.data[i]);
        }
        if(!ok) {
            sample.data.clear();
        }
    }
    return ok;
}
/// Read song data.
/// @param [out] song Song.
/// @return false if there is no data left to be read.
bool DataReader::read(Song &song) {
    size_t formatStringLen;
    bool ok;

    formatStringLen = strlen(DMF::FormatString);
    memset(&song.infos, 0, sizeof(DMF::Infos));

    ok = compare(DMF::FormatString, formatStringLen);
    if(!ok) {
        return false;
    }
    
    ok = read(song.infos);
    if(!ok) {
        return false;
    }
    
    // Load pattern matrix data
    size_t dataSize = song.infos.systemChanCount * song.infos.totalRowsInPatternMatrix;
    song.patternMatrix.resize(dataSize);
    ok = read(&song.patternMatrix[0], dataSize);
    if(!ok) { 
        song.patternMatrix.clear();
        return false;
    }
    
    // Load instruments
    uint8_t count;
    ok = read(count);
    if(!ok) { 
        return false;
    }
    
    song.instrument.resize(count);
    for(uint8_t i=0; i<count; i++) {
        ok = read(song.instrument[i]);
        if(!ok) { 
            return false;
        }
    }    
    
    // Load wave tables
    uint8_t size;
    ok = read(size);
    if(!ok) {
        return false;
    }
    
    if(size) {
        song.waveTable.resize(size);
        for(size_t i=0; i<size; i++) {
            ok = read(song.waveTable[i]);
            if(!ok) {
                return false;
            }
        }
    }

    // Load patterns
    song.effectCount.resize(song.infos.systemChanCount);
    song.patternData.resize(song.infos.systemChanCount * song.infos.totalRowsInPatternMatrix * song.infos.totalRowsPerPattern);
    size_t i, l;
    for(i=0, l=0; ok && (i<song.infos.systemChanCount); i++) {
        ok = read(song.effectCount[i]);
        for(size_t j=0; ok && (j<song.infos.totalRowsInPatternMatrix); j++) {
            for(size_t k=0; ok && (k<song.infos.totalRowsPerPattern); k++, l++) {
                ok = read(song.patternData[l], song.effectCount[i]);
            }
        }
    }
    if(!ok) {
        song.effectCount.clear();
        song.patternData.clear();
        return false;
    }
   
    // Load samples
    ok = read(size);
    if(!ok) {
        return false;
    }
    if(size) {
        song.sample.resize(size);
        for(i=0; ok && (i<size); i++) {
            ok = read(song.infos, song.sample[i]);
        }
        if(!ok) {
            song.sample.clear();
            return false;
        }
    }
    
    // Reorganize patter data...
    fixPatterns(song);
    // Clamp instrument values...
    fixInstruments(song);

    return true;
}
/// Compare data and move offset if they matches.
/// @param [in] src Source data.
/// @param [in] len Number of bytes to check.
/// @return true if the data matches.
bool DataReader::compare(const void* src, size_t len) {
    // Sanity checks
    if(!src || !len || ((_offset+len) > _buffer.size())) {
        return false;
    }
    int ret;
    ret = memcmp(&_buffer[_offset], src, len);
    if(ret) {
        return false;
    }
    _offset += len;
    return true;
}

bool operator==(const PatternData &d0, const PatternData &d1) {
    for(int i=0; i<DMF_MAX_EFFECT_COUNT; i++) {
        if((d0.effect[i].code != d1.effect[i].code) || 
           (d0.effect[i].data != d1.effect[i].data)) {
            return false;
        }
    }
    return (d0.note == d1.note) &&
           (d0.octave == d1.octave) &&
           (d0.volume == d1.volume) && 
           (d0.instrument == d1.instrument);
}

/// Reorganize pattern data in order to match matrix indices.
void DataReader::fixPatterns(Song &song) {
    static const size_t unknown = static_cast<size_t>(-1);
    std::vector<PatternData> data;
    std::vector<int> source;
    data.resize(song.infos.systemChanCount * song.infos.totalRowsInPatternMatrix * song.infos.totalRowsPerPattern);
    for(size_t i=0; i<song.infos.systemChanCount; i++)  {
        size_t last = 0;
        std::vector<size_t> mapping;
        for(size_t j=0; j<song.infos.totalRowsInPatternMatrix; j++) {
            size_t pattern_index = song.patternMatrix[(i*song.infos.totalRowsInPatternMatrix) + j];
            if(pattern_index >= mapping.size()) {
                mapping.resize(pattern_index + 1, unknown);
            }
            if(mapping[pattern_index] == unknown) {
                size_t start = ((i * song.infos.totalRowsInPatternMatrix) + j) * song.infos.totalRowsPerPattern;
                size_t end   = start + song.infos.totalRowsPerPattern;
                size_t dest  = ((i * song.infos.totalRowsInPatternMatrix) + last) * song.infos.totalRowsPerPattern;
                std::copy(&song.patternData[start], &song.patternData[end], &data[dest]);

                mapping[pattern_index] = last++;
            }
            
            song.patternMatrix[(i*song.infos.totalRowsInPatternMatrix) + j] = mapping[pattern_index];
        }
    }
    song.patternData = std::move(data);
}

void DataReader::fixInstruments(Song &song) {
    for(size_t i=0; i<song.instrument.size(); i++) {
        Instrument::Standard &std = song.instrument[i].std;
        for(size_t j=0; j<std.wave.size; j++) {
            uint8_t v = std.wave.value[j];
            std.wave.value[j] = (v < song.waveTable.size()) ? v : 0;
        }
    }
}

} // DMF
