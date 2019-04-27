#include <iostream>
#include <iomanip>
#include <fstream>
#include <vector>
#include <cstdint>

// PC Engine PSG register friendly names.
static const std::vector<const char*> g_psgReg = {
    "psg_ch",
    "psg_mainvol",
    "psg_freq.lo",
    "psg_freq.hi",
    "psg_ctrl",
    "psg_pan",
    "psg_wavebuf",
    "psg_noise",
    "psg_lfoctrl",
    "psg_lfofreq"
};

// Translate a LSB encoded 32 bytes word into a native 32 bytes unsigned
// int.
inline uint32_t u32(uint8_t b[4])
{
    return (b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24));
}

int main(int argc, char **argv)
{
    std::ifstream input;
    input.open(argv[1], std::ifstream::binary);
    
    if(!input)
    {
        std::cerr << "Failed to open " << argv[1] << " " << std::endl;
        return 1;
    }
    
    uint8_t buffer[4];
    uint32_t gd3Offset;
    uint32_t loopOffset;
    uint32_t dataOffset;
    
    // We first fetch the g3d, loop and data offset.
    input.seekg(0x14);
    input.read(reinterpret_cast<char*>(buffer), 4);
    gd3Offset = u32(buffer);

    input.seekg(0x1C);
    input.read(reinterpret_cast<char*>(buffer), 4);
    loopOffset = u32(buffer);

    input.seekg(0x34);
    input.read(reinterpret_cast<char*>(buffer), 4);
    dataOffset = u32(buffer);
    
    uint32_t dataSize = gd3Offset - dataOffset;
    loopOffset = (loopOffset + 0x1C) - dataOffset - 0x34;
    
    // Output register names
    for(size_t i=0; i<g_psgReg.size(); i++)
    {
        uint32_t reg = 0x0800 + i;
        std::cout << g_psgReg[i] << " = ";
        std::cout << std::setw(4) << std::setfill('0') << std::hex << reg << std::endl;
    }
    
    std::cout << "song:" << std::endl;
    
    // Now we jump to the beginning of data (header size + dataOffset)
    input.seekg(0x34+dataOffset);
    while(!input.eof())
    {
        input.read(reinterpret_cast<char*>(buffer), 1);
        if(0xb9 == buffer[0])
        {
            // data + register index
            input.read(reinterpret_cast<char*>(buffer), 2);
            std::cout << "    lda #$" << std::setw(2) << std::setfill('0') << std::hex << static_cast<unsigned int>(buffer[1]) << std::endl;
            std::cout << "    sta "   << g_psgReg[buffer[0]] << std::endl;
        }
        else if(0x62 == buffer[0])
        {
            // end of frame
            std::cout << "    jsr  wait_vsync" << std::endl;
        }
    }
    
    input.close();
    
    return 0;
}
