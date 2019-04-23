// Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#ifndef DATA_READER_H
#define DATA_READER_H

#include "dmf.h"

namespace DMF {

/// DMF data reader.
class DataReader {
    public:
        /// Constructor.
        DataReader();
        /// Destructor.
        ~DataReader();
        /// Load song.
        /// @param [in] filename Song filename.
        /// @param [out] song Decoded song.
        /// @return true if song is successfully loaded.
        bool load(const std::string& filename, Song &song);
        /// Get song raw size.
        size_t size();
    private:
        /// Read a single unsigned byte from buffer.
        /// @param [out] v Unsigned byte read from buffer.
        /// @return false if there is no data left to be read.
        bool read(uint8_t& v);
        /// Read a single unsigned short (2 bytes) from buffer.
        /// @param [out] v Unsigned short read from buffer.
        /// @return false if there is no data left to be read.
        bool read(uint16_t& v);
        /// Read a single unsigned word (4 bytes) from buffer.
        /// @param [out] v Unsigned word read from buffer.
        /// @return false if there is no data left to be read.
        bool read(uint32_t& v);
        /// Read n bytes from buffer.
        /// @param [in][out] ptr Pointer to output buffer.
        /// @param [in]      nBytes Number of bytes to read.
        /// @return false if there is no data left to be read.
        bool read(void* ptr, size_t nBytes);
        /// Read string.
        /// @param [out] str String Output string.
        /// @return false if there is no data left to be read.
        bool read(String& str);
        /// Read song info.
        /// @param [out] nfo Song info.
        /// @return false if there is no data left to be read.
        bool read(Infos& nfo);
        /// Read envelope.
        /// @param [out] env Volume envelope.
        /// @return false if there is no data left to be read.
        bool read(Envelope& env);
        /// Read a single instrument.
        /// @param [out] inst Instrument.
        /// @return false if there is no data left to be read.
        bool read(Instrument& inst);
        /// Read a wave table.
        /// @param [out] wav Wave table.
        /// @return false if there is no data left to be read.
        bool read(WaveTable& wav);
        /// Read pattern data.
        /// @param [out] pat Pattern data.
        /// @param [in]  effectCount Number of effects per pattern entry.
        /// @return false if there is no data left to be read.
        bool read(PatternData& pat, uint8_t effectCount);
        /// Read sample.
        /// @param [in] nfo Song infos.
        /// @param [out] sample Sample.
        /// @return false if there is no data left to be read.
        bool read(Infos const& nfo, Sample &sample);
        /// Read song data.
        /// @param [out] song Song.
        /// @return false if there is no data left to be read.
        bool read(Song& song);
        
        /// Compare data and move offset if they matches.
        /// @param [in] src Source data.
        /// @param [in] len Number of bytes to check.
        /// @return true if the data matches.
        bool compare(const void* src, size_t len);

        /// Decompress input file.
        /// @param [in] source Source file.
        /// @return true if the file was successfully decompressed.
        bool decompress(FILE* stream);

        /// Reorganize pattern data in order to match matrix indices.
        void fixPatterns(Song &song);

    private:
        /// Input byte buffer.
        std::vector<uint8_t> _buffer;
        /// Current read offset in byte buffer.
        size_t _offset;
};

} // DMF

#endif // DATA_READER_H
