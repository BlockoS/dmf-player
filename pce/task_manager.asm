MAX_TASK_COUNT = 4

    .zp
task.count   .ds 1
task.dummy   .ds 2

    .bss
task .ds MAX_TASK_COUNT*2

    .code
task.add:
    lda    <task.count
    cmp    #MAX_TASK_COUNT
    beq    @err
        asl    A
        tax
        lda    <_si
        sta    task, X
        lda    <_si+1
        sta    task+1, X
        inc    <task.count
    rts
@err:
    sec
    rts

task.remove:
    asl    A
    tax
    lda    <task.count
    beq    @end
    dec    <task.count
@loop:
        lda    task+2, X
        sta    task, X
        lda    task+3, X
        sta    task+1, X
        inx
        inx
        cpx    #(MAX_TASK_COUNT*2)
        bne    @loop
@end:
    rts

task.update:
    cla
@loop:
    cmp    <task.count
    beq    @end
        pha
        asl    A
        tax
        bsr    @run
        pla
        inc    A
        bra    @loop
@end:
    rts
@run:
    jmp    [task, X]
    rts

; must be called prior pushing anything onto the stack in the irq handler.
  .macro task.irq_install
    stx    <task.dummy
    sta    <task.dummy+1
    plx                             ; retrieve P register
    lda    #high(task.update)       ; push task update routine
    pha
    lda    #low(task.update)
    pha
    phx                             ; push P register back
    ldx    <task.dummy
    lda    <task.dummy+1
  .endm
