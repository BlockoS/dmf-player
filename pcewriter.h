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
            bool write(PCE::PatternMatrix const& pattern);
            
        private:
            std::string _filename;
            std::string _prefix;
            FILE       *_output;
    };
}

#endif // PCE_WRITER_H
