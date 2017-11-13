     .text
     .syntax unified
     .arch armv7-m
     .global Panic_SaveRegisters
     .type Panic_SaveRegisters, %function
     .thumb_func
Panic_SaveRegisters:
     ldr     r0, =(crash_regs)
     stm     r0, {r0-r12,lr}
     // Return to caller.
     bx          lr

     .pool
     .size Panic_SaveRegisters, .-Panic_SaveRegisters
