#ifndef DATA_READER_H
#define DATA_READER_H

#include "dmf.h"

namespace DMF {

class DataReader
{
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
        /// @param [out] String Output string.
        /// @return false if there is no data left to be read.
        bool read(String& str);
        bool read(Infos& nfo);
        bool read(Envelope& env);
        bool read(Instrument& inst);
        bool read(WaveTable& wav);
        bool read(PatternData& pat, uint8_t effectCount);
        bool read(Sample& sample);
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

    private:
        std::vector<uint8_t> _buffer;
        size_t _offset;
};

} // DMF

#endif // DATA_READER_H
