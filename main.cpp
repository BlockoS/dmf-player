// Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors.
// All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying
// LICENSE file for terms.
#include "dmf.h"
#include "datareader.h"
#include "pce.h"
#include "pcewriter.h"

int main(int argc, char** argv) {
    DMF::Song song;
    DMF::DataReader reader;
    PCE::SongPacker packer;
    bool ok;

    if(argc != 3) {
        fprintf(stderr, "Usage: %s file.dmf out.asm\n", argv[0]);
        return 1;
    }
    
    ok = reader.load(argv[1], song);
    if(!ok) {
        fprintf(stderr, "An error occured while reading %s\n", argv[1]);
        return 1;
    }
    printInfos(song.infos); 
    packer.pack(song);
    
    PCE::Writer writer(argv[2]);
    
    writer.open();
        packer.output(writer);
    writer.close();
    
    return 0;
}
