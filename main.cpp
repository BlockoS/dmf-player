#include "dmf.h"
#include "datareader.h"

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
    
    struct PatternMatrix
    {
        std::vector<int> dataOffset;
        std::vector<int> packedOffset;
    };
    
    std::vector<PatternMatrix> matrix;
    matrix.resize(song.infos.systemChanCount);
    
    printf("pattern_matrix_rows:\n\t.db %d\n", song.infos.totalRowsInPatternMatrix);

    for(size_t j=0; j<song.infos.systemChanCount; j++)
    {
        matrix[j].dataOffset.clear();

        matrix[j].packedOffset.resize(song.infos.totalRowsInPatternMatrix);
        std::fill(matrix[j].packedOffset.begin(), matrix[j].packedOffset.end(), -1);
        
        printf("pattern_matrix_ch%lx:", j);
        for(size_t i=0; i<song.infos.totalRowsInPatternMatrix; i++)
        {
            if(((i%16) == 0) && ((i+1)<song.infos.totalRowsInPatternMatrix))
            {
                printf("\n\t.db ");
            }

            size_t offset  = i + (j*song.infos.totalRowsInPatternMatrix);
            size_t pattern = song.patternMatrix[offset];
            if(matrix[j].packedOffset[pattern] < 0)
            {
                matrix[j].packedOffset[pattern] = matrix[j].dataOffset.size();
                matrix[j].dataOffset.push_back(offset * song.infos.totalRowsPerPattern);
            }
            
            printf("%02x", matrix[j].packedOffset[pattern]);
            if(((i%16) != 15) && ((i+1)<song.infos.totalRowsInPatternMatrix))
            {
                printf(", ");
            }
        }
        printf("\n");
    }
    
    std::vector<uint8_t> buffer;
    
    // PCE encoding:
    //      00 - Arpeggio
    //      01 - Portamento up
    //      02 - Portamento down
    //      03 - Portamento to note
    //      04 - Vibrato
    //      05 - Portamento to note and volume slide
    //      06 - Vibrato and volume slide
    //      07 - Tremolo
    //      08 - Panning
    //      09 - Set Speed Value 1
    //      0A - Volume Slide
    //      0B - Position Jump
    //      0C - Retrig
    //      0D - Pattern Break
    //      0E - Extended Commands
    //      0F - Set Speed Value 2
    //      10 - Set Wave
    //      11 - Enable Noise Channel
    //      12 - Set LFO Mode
    //      13 - Set LFO Speed
    //      17 - Enable Sample Output
    //      1A - Set Volume
    //      1B - Set Instrument
    //      20 - Note
    //      21 - Note off
    //      79 - Rest X if X >= 128
    //      8X - Rest X if X <  128 

    for(size_t i=0; i<song.infos.systemChanCount; i++)
    {
        for(size_t j=0; j<matrix[i].dataOffset.size(); j++)
        {
            size_t k = 0;
            size_t l = matrix[i].dataOffset[j];
            
            size_t rest = 0;
            printf("%02ld:%04lx=%lx\n", i, j, l);
            for(k=0; (k<song.infos.totalRowsPerPattern) && isEmpty(song.patternData[l]); k++, l++)
            {
                rest++;
            }

            if(rest)
            {
                if(rest >= 128)
                {
                    buffer.push_back(0x79);
                    buffer.push_back(rest);
                }
                else
                {
                    buffer.push_back(0x80 | rest);
                }
                
                printf("\n    REST %4ld\n", rest);
            }
            
            while(k<song.infos.totalRowsPerPattern)
            {
                printf("%03ld ", k);

                if(100 == song.patternData[l].note)
                {
                    buffer.push_back(0x21);
                    printf("OFF      ");
                }
                else if((0 != song.patternData[l].note) && (0 != song.patternData[l].octave))
                {
                    uint8_t dummy;
                    dummy = ((song.patternData[l].note & 0x0f) << 4) | (song.patternData[l].octave & 0x0f);
                    buffer.push_back(0x20);
                    buffer.push_back(dummy);

                    printf("%4x %4x ", song.patternData[l].note, song.patternData[l].octave);
                }
                else
                {
                    printf("---- ---- ");
                }
                
                if(0xffff != song.patternData[l].volume)
                {
                    buffer.push_back(0x1A);
                    buffer.push_back(song.patternData[l].volume);
                    
                    printf("%4x ", song.patternData[l].volume);
                }
                else
                {
                    printf("---- ");
                }
                
                if(0xffff != song.patternData[l].instrument)
                {
                    buffer.push_back(0x1B);
                    buffer.push_back(song.patternData[l].instrument);
                
                    printf("%4x ", song.patternData[l].instrument);
                }
                else
                {
                    printf("---- ");
                }
                
                for(size_t m=0; m<song.effectCount[i]; m++)
                {
                    if((0xffff != song.patternData[l].effect[m].code) && (0xffff != song.patternData[l].effect[m].data))
                    {
                        buffer.push_back(song.patternData[l].effect[m].code);
                        buffer.push_back(song.patternData[l].effect[m].data);
                        
                        printf("%4x %4x ", song.patternData[l].effect[m].code, song.patternData[l].effect[m].data);
                    }
                    else
                    {
                        printf("---- ---- ");
                    }
                }
                
                printf("\n");

                k++;
                l++;

                for(rest=0; (k<song.infos.totalRowsPerPattern) && isEmpty(song.patternData[l]); k++, l++, rest++)
                {}
                if(rest)
                {
                    if(rest >= 128)
                    {
                        buffer.push_back(0x79);
                        buffer.push_back(rest);
                    }
                    else
                    {
                        buffer.push_back(0x80 | rest);
                    }
                    
                    printf("    REST %4ld\n", rest);
                }
            }
            printf("\n");
        }
    }
    
    printf("%ld %ld\n", reader.size(), buffer.size());

    return 0;
}
