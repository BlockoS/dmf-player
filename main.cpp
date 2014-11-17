#include "dmf.h"
#include "datareader.h"
#include "pce.h"

int main(int argc, char** argv)
{
    DMF::Song song;
    DMF::DataReader reader;
    PCE::SongPacker packer;
    bool ok;

    if(argc != 2)
    {
        fprintf(stderr, "Usage: %s file.dmf\n", argv[0]);
        return 1;
    }
    
    ok = reader.load(argv[1], song);
    if(!ok)
    {
        fprintf(stderr, "An error occured while reading %s\n", argv[1]);
        return 1;
    }
    
    
    packer.pack(song);
    packer.output(stdout);
    
    return 0;
}
