// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors.
// All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying
// LICENSE file for terms.
#ifndef PCE_WRITER_H
#define PCE_WRITER_H

#include "pce.h"

#define MAX_CHAR_PER_LINE 92

namespace PCE
{
    class Writer
    {
        public:
            Writer(std::string const& filename);
            ~Writer();
            
            bool open();
            void close();
            
            // [todo] rename
            bool write(DMF::Infos const& infos);
            bool write(DMF::Infos const& infos, std::vector<uint8_t> const& pattern);
            bool write(std::vector<WaveTable> const& wavetable);

            bool writePatterns(DMF::Infos const& infos, std::vector<PatternMatrix> const& matrix, std::vector<uint8_t> const& buffer);
            bool writeInstruments(InstrumentList const& instruments);

        private:
            bool writeBytes(const uint8_t* buffer, size_t size, size_t elementsPerLine);
            bool writePointerTable(const char* pointerBasename, size_t count, size_t elementsPerLine);

            bool writePatternData(PCE::PatternMatrix const& pattern, std::vector<uint8_t> const& buffer, size_t index);
            
        private:
            std::string _filename;
            std::string _prefix;
            FILE       *_output;
    };
}

#endif // PCE_WRITER_H
