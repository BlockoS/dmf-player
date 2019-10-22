// Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors.
// All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying
// LICENSE file for terms.
#ifndef PCE_WRITER_H
#define PCE_WRITER_H

#include "pce.h"

#define MAX_CHAR_PER_LINE 92

namespace PCE {
    class Writer {
        public:
            Writer(std::string const& filename);
            ~Writer();
            
            bool open();
            void close();
            
            // [todo] rename
            bool write(DMF::Infos const& infos, size_t instrument_count);
            bool write(DMF::Infos const& infos, std::vector<uint8_t> const& pattern);
            bool write(std::vector<WaveTable> const& wavetable);

            bool writePatterns(DMF::Infos const& infos, std::vector<PatternMatrix> const& matrix);
            bool writeInstruments(InstrumentList const& instruments);

            bool writeBinary(DMF::Infos const& infos, std::vector<WaveTable> const& wavetable, InstrumentList const& instruments, std::vector<PatternMatrix> const& matrix);

        private:
            bool writeBytes(const uint8_t* buffer, size_t size, size_t elementsPerLine);
            bool writePointerTable(const char* pointerBasename, size_t start, size_t count, size_t elementsPerLine, bool bank=false);
            bool writePointerTable(const char* table, const char* element, const std::vector<int>& index, size_t elementsPerLine, bool bank=false);

            bool writePatternData(PCE::PatternMatrix const& pattern, size_t& index);
            template <typename T>
            void writeBuffer(std::vector<T> const& buffer, size_t elementsPerLine);
        
        private:
            std::string _filename;
            std::string _prefix;
            FILE       *_output;
    };

    template <typename T>
    void Writer::writeBuffer(std::vector<T> const& buffer, size_t elementsPerLine) {
        for(size_t i=0; i<buffer.size(); ) {
            size_t last = ((elementsPerLine+i)<buffer.size()) ? elementsPerLine : (buffer.size()-i);
            fprintf(_output, "    .db ");
            for(size_t j=0; j<last; j++, i++) {
                fprintf(_output,"$%02x%c", buffer[i], ((j+1) < last) ? ',' : '\n');
            }
        }
    }

}
#endif // PCE_WRITER_H
