#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
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
        fprintf(stderr, "usage: mul.tables out\n");
        return EXIT_FAILURE;
    }
    out = fopen(argv[1], "wb");
    if(out == NULL) {
        fprintf(stderr, "failed to open %s: %s\n", argv[1], strerror(errno));
        return EXIT_FAILURE;
    }
    int i;
    uint8_t sqr_lo[512], sqr_hi[512];
    for(i=0; i<512; i++) {
        uint16_t m = (i*i) / 4;
        sqr_lo[i] = m & 0xff;
        sqr_hi[i] = m >> 8;
    }
    print("sqr0.lo", sqr_lo, 512);
    print("sqr0.hi", sqr_hi, 512);
    for(i=0; i<512; i++) {
        uint16_t m = (255-i) * (255-i) / 4;
        sqr_lo[i] = m & 0xff;
        sqr_hi[i] = m >> 8;
    }
    print("sqr1.lo", sqr_lo, 512);
    print("sqr1.hi", sqr_hi, 512);
    fclose(out);
    return EXIT_SUCCESS;
}
