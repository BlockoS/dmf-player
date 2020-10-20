// Copyright (c) 2015-2020, Vincent "MooZ" Cruz and other contributors.
// All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying
// LICENSE file for terms.
#include <cstdlib>

#include "dmf.h"
#include "datareader.h"
#include "pce.h"
#include "pcewriter.h"

int main(int argc, char** argv) {
    if(argc < 3) {
        fprintf(stderr, "Usage: %s out.asm file0.dmf file1.dmf ... \n", argv[0]);
        return EXIT_FAILURE;
    }

    PCE::Packer packer;

    for(int i=2; i<argc; i++) {
        DMF::DataReader reader;
        DMF::Song song;
        bool ok;

        ok = reader.load(argv[i], song);
        if(!ok) {
            fprintf(stderr, "An error occured while reading %s\n", argv[i]);
            return EXIT_FAILURE;
        }

        add(packer, song);
    }

#if 0    
    ok = reader.load(argv[1], song);
    if(!ok) {
        fprintf(stderr, "An error occured while reading %s\n", argv[1]);
        return 1;
    }
    
    packer.pack(song);
    
    PCE::Writer writer(argv[2]);
    
    writer.open();
        packer.output(writer);
    writer.close();
#endif
    return EXIT_SUCCESS;
}
