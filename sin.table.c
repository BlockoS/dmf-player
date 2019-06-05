#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <errno.h>

FILE *out;

void print(const char *name, uint8_t* tbl, int count) {
    fprintf(out, "%s:\n", name);
    for(int i=0; i<count; ) {
        fprintf(out, "    .db ");
        for(int j=0; (j<16) && (i<count); j++, i++) {
            char c = ((j < 15) && (i < (count-1))) ? ',' : '\n';
            fprintf(out, "$%02x%c", tbl[i], c);
        }
    }
}

int main(int argc, char **argv) {
    if(argc != 2) {
        fprintf(stderr, "usage: sin.table out\n");
        return EXIT_FAILURE;
    }
    out = fopen(argv[1], "wb");
    if(out == NULL) {
        fprintf(stderr, "failed to open %s: %s\n", argv[1], strerror(errno));
        return EXIT_FAILURE;
    }
    uint8_t sin_table[256];
    for(int i=0; i<256; i++) {
        sin_table[i] = (0.5 + 0.5 * sin(i * 2.f * M_PI / 256.f)) * 32.f;
    }
    print("sin_table", sin_table, 256);
    fclose(out);
    return EXIT_SUCCESS;
}

