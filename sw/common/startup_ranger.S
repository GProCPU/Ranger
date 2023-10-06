
.file "startup_ranger.S"
.section .text.startup
.balign 4
.global _start
.global __startup_entry
.global __startup_main_exit

_start:
__startup_entry:
.cfi_startproc
.cfi_undefined ra

//csrrwi  zero, mstatus, 0 // clear mstatus; disable machine-level interrupts


// Setup CPU CSRs
__startup_csr_init:
    csrw    mie, zero                       // disable all interrupt sources
    la      x1, __startup_trap_handler      // configure early-boot trap handler
    csrw    mtvec, x1


// Initialize stack pointer
__startup_pointer_init:
    .option push
    .option norelax
    la      sp, __Ranger_stack_begin  // stack pointer
    .option pop


// Copy initialized data from ROM to RAM
__startup_copy_data:
    la      x11, __Ranger_copy_data_src_begin
    la      x12, __Ranger_copy_data_dest_begin
    la      x13, __Ranger_copy_data_dest_end
    beq     x11, x12, __startup_copy_data_loop_end  // do nothing if source and destination are same
__startup_copy_data_loop:
    bge     x12, x13, __startup_copy_data_loop_end
    lw      x14, 0(x11)
    sw      x14, 0(x12)
    addi    x11, x11, 4
    addi    x12, x12, 4
    j       __startup_copy_data_loop
__startup_copy_data_loop_end:


// Clear .bss sections
__startup_clear_bss:
    la      x14, __Ranger_bss_start
    la      x15, __Ranger_bss_end
__startup_clear_bss_loop:
    bge     x14, x15, __startup_clear_bss_loop_end
    sw      zero, 0(x14)
    addi    x14, x14, 4
    j       __startup_clear_bss_loop
__startup_clear_bss_loop_end:


// Call constructors
__startup_call_constructors:
    la      x8, __init_array_start
    la      x9, __init_array_end
__startup_call_constructors_loop:
    bge     x8, x9, __startup_call_constructors_loop_end
    lw      x1, 0(x8)
    jalr    x1, 0(x1)
    addi    x8, x8, 4
    j       __startup_call_constructors_loop
__startup_call_constructors_loop_end:


// Call main function
__startup_main_entry:
    addi    x10, zero, 0    // x10 = a0 = argc = 0
    addi    x11, zero, 0    // x11 = a1 = argv = 0
    jal     x1, main        // call application main
__startup_main_exit:
    // return or exit from main goes here
    csrw    mie, zero       // disable all interrupts
    csrw    mscratch, a0    // backup main's return code for debugger


// Call destructors
__startup_call_destructors:
    la      x8, __fini_array_start
    la      x9, __fini_array_end
__startup_call_destructors_loop:
    bge     x8, x9, __startup_call_destructors_loop_end
    lw      x1, 0(x8)
    jalr    x1, 0(x1)
    addi    x8, x8, 4
    j       __startup_call_destructors_loop
__startup_call_destructors_loop_end:


// Endless sleep
__startup_shutdown:
    wfi
    j       __startup_shutdown


// Dummy trap handler for startup stage. Try to move to next instruction
.balign 4
__startup_trap_handler:
    addi    sp, sp, -8
    sw      x8, 0(sp)
    sw      x9, 4(sp)
    csrr    x8, mcause
    blt     x8, zero, __startup_trap_handler_end  // skip mepc modification if interrupt
    // increment mepc
    csrr    x8, mepc
    addi    x8, x8, +4
    csrw    mepc, x8
__startup_trap_handler_end:
    lw      x8, 0(sp)
    lw      x9, 4(sp)
    addi    sp, sp, +8
    mret


.cfi_endproc
.end
