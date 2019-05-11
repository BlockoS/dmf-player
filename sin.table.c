#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

void print(const char *name, uint8_t* tbl, int count) {
    printf("%s:\n", name);
    for(int i=0; i<count; ) {
        printf("    .db ");
        for(int j=0; (j<16) && (i<count); j++, i++) {
            char c = ((j < 15) && (i < (count-1))) ? ',' : '\n';
            printf("$%02x%c", tbl[i], c);
        }
    }
}

int main() {
    uint8_t sin_table[256];
    for(int i=0; i<256; i++) {
        sin_table[i] = (0.5 + 0.5 * sin(i * 2.f * M_PI / 256.f)) * 32.f;
    }
    print("sin_table", sin_table, 256);
    return EXIT_SUCCESS;
}

