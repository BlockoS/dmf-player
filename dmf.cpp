// Copyright (c) 2015, Vincent "MooZ" Cruz and other contributors. All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.
#include "dmf.h"

namespace DMF {
    
/// Check if a pattern element is empty. 
/// @param [in] src Pattern data.
/// @return true if the pattern element is empty, false otherwise.
bool isEmpty(PatternData const& src)
{
    return    (src.octave == 0)
           && (src.note == 0)
           && (src.instrument == 0xffff)
           && (src.volume == 0xffff)
           && (src.effect[0].code == 0xffff)
           && (src.effect[0].data == 0xffff);
}

} // DMF
