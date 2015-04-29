#ifndef PCE_WRITER_H
#define PCE_WRITER_H

#include "pce.h"

namespace PCE
{
    class Writer
    {
        public:
            Writer(std::string const& filename);
            ~Writer();
            
            bool open();
            void close();
            
            bool write(DMF::Infos const& infos);
            bool write(PCE::PatternMatrix const& pattern, std::vector<uint8_t> const& buffer, size_t index);
            void writePointerTable(size_t count, size_t perLine=16);
            
            bool write(std::vector<WaveTable> const& wavetable);
            
        private:
            std::string _filename;
            std::string _prefix;
            FILE       *_output;
    };
}

#endif // PCE_WRITER_H
