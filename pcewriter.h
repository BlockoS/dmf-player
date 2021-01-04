// Copyright (c) 2015-2019, Vincent "MooZ" Cruz and other contributors.
// All rights reserved.
// Copyrights licensed under the New BSD License. See the accompanying
// LICENSE file for terms.
#ifndef PCE_WRITER_H
#define PCE_WRITER_H

#include "pce.h"

#define MAX_CHAR_PER_LINE 92

namespace PCE {

bool write(std::string const& filename, Packer const& in);

} // PCE

#endif // PCE_WRITER_H
