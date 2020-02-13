
#asm
.include "player.asm"

_dmf_load_song = load_song
#endasm

void __fast_call dmf_init() {
#asm
    lda    #high(sqr0.lo)
    sta    <mul8.lo+1
    lda    #high(sqr1.lo)
    sta    <mul8.lo+3
    lda    #high(sqr0.hi)
    sta    <mul8.hi+1
    lda    #high(sqr1.hi)
    sta    <mul8.hi+3
#endasm
}

void __fast_call dmf_load_song(char far *song<__bl:__si>);