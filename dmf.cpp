// Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#include "dmf.h"

#include <cstdio>

namespace DMF {
    
/// Check if a pattern element is empty. 
/// @param [in] src Pattern data.
/// @return true if the pattern element is empty, false otherwise.
bool isEmpty(PatternData const& src) {
    bool empty_fx = true;
    for(int i=0; i<DMF_MAX_EFFECT_COUNT; i++) {
        empty_fx =  empty_fx
                 && (src.effect[i].code == 0xffff)
                 && (src.effect[i].data == 0xffff);
    }
    
    return    (src.octave == 0)
           && (src.note == 0)
           && (src.instrument == 0xffff)
           && (src.volume == 0xffff)
           && empty_fx;           
}

void printInfos(Infos const& nfo) {
    const char* fmt = R"EOT(
Version: %02x
System: %02x
Name: %s
Author: %s
Rows highlighting: %02x/%02x
Time base: %02x
Tick time: %02x/%02x
Frames mode: %02x
Custom frequency flag: %02x
Custom frequency value: %02x%02x%02x
Number of rows per pattern: %d
Number of rows in the pattern matrix: %d
Arpeggio tick speed: %d
)EOT";

    fprintf(stdout, fmt
            , nfo.version
            , nfo.system
            , nfo.name.data
            , nfo.author.data
            , nfo.highlight[0], nfo.highlight[1]
            , nfo.timeBase
            , nfo.tickTime[0], nfo.tickTime[1]
            , nfo.framesMode
            , nfo.customFreqFlag
            , nfo.customFreqValue[0], nfo.customFreqValue[1], nfo.customFreqValue[2]
            , nfo.totalRowsPerPattern
            , nfo.totalRowsInPatternMatrix
            , nfo.arpeggioTickSpeed
    );
}

} // DMF
