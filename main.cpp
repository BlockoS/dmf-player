#include "dmf.h"
#include "datareader.h"
#include "pce.h"

int main(int argc, char** argv)
{
    DMF::Song song;
    DMF::DataReader reader;
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
    
    printf("version: %d\nsystem: %d\nname: %s\nauthor: %s\n"
        ,song.infos.version
        ,song.infos.system
        ,song.infos.name.data
        ,song.infos.author.data);
    
    ////
    for(size_t i=0; i<song.instrument.size(); i++)
    {
        printf("%ld %d:\n", i, song.instrument[i].std.noise.size);
        for(size_t j=0; j<song.instrument[i].std.noise.size; j++)
        {
            printf("%02x%02x%02x%02x ",
                    song.instrument[i].std.noise.value[4*j  ],
                    song.instrument[i].std.noise.value[4*j+1],
                    song.instrument[i].std.noise.value[4*j+2],
                    song.instrument[i].std.noise.value[4*j+3]);
            if(((j+1)%8) == 0) printf("\n");
        }
        printf("\n\n");
    }
    
    return 0;
}
