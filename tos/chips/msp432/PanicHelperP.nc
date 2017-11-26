/*
 * Copyright (c) 2017 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/* MSP432 assembly helper routines for Panic. */

module PanicHelperP { }
implementation {

  /*
   * linkage back to __panic_panic_entry
   * switch to new stack and preserve state
   *
   * r0 (new_stack): is the address we want for the crash stack
   *    this is a workaround to set the stack to a fixed location.
   *
   * we want to make the crash_stack hold the same stuff as what an
   * panic_exec_entry does.  Namely:
   *
   *  top of crash_stack:
   *    axLR    <- we need to fake this.  See below.
   *    r11
   *    r10
   *    r9
   *    r8
   *    r7
   *    r6
   *    r5
   *    r4
   *    msp
   *    psp
   *    axPSR   <- from current xPSR.
   *
   * the axLR is set to indicate 8 words, handler, MSP.  0x00000011
   * we do NOT pretend to be an EXC_RTN that would be ugly.
   */

  void __launch_panic_panic(void *new_stack)
      __attribute__((naked, noinline)) @C() @spontaneous() {

    __asm__ volatile (
      "mov  r1, sp       \n"            /* save old_stack           */
      "mov  sp, r0       \n"            /* switch to new stack      */
      "mov  r0, r1       \n"            /* arg0 for panic_entry     */
      "mrs  r1, XPSR     \n"            /* save the axPSR           */
      "mrs  r2, PSP      \n"
      "mrs  r3, MSP      \n"
      "mov  lr, %[flr]   \n"
      "push {r1-r11, lr} \n"            /* save remaining registers */
      "mov  r1, sp       \n"            /* cur crash_stack          */
      "b    __panic_panic_entry \n"
      : : [flr]"I"(0x11) : "cc", "memory", "sp");
  }


  /*
   * Panic.panic: something really bad happened.
   * switch to crash_stack
   *
   * this routine is used by Panic to handle entry to the main panic
   * code.  We want to save enough of the machine state and switch onto
   * a more reliable stack (the crash_stack).
   *
   * We push a few items on to the stack to first get scratch registers
   * we can use to save state.  Also we do it so the old_stack looks like
   * what an exception lays down.  This makes the extraction code
   * similar.
   *
   * The panic_panic extraction code has to know where all the Panic
   * parameters live.  We also have to do a dance to grab the xPSR.
   *
   * We also nab the special registers, PRIMASK, BASEPRI, FAULTMASK, and
   * CONTROL.
   *
   * we then use __launch_panic_panic with the address of the stack pointer.
   * This is to work around problems with setting the SP directly.
   * (compiler/assembler ate my code).
   *
   * Hopefully, this preserves the stack linkage and gdb doesn't get lost.
   * This sometimes works.  And other times doesn't depends on the
   * optimization and how much gdb knows from the ELF file.
   *
   * __panic_entry is the main entry point for use by Panic.panic.
   *
   * signature of Panic.panic is:
   *
   * void Panic.panic(uint8_t pcode, uint8_t where,
   *         parg_t arg0, parg_t arg1, parg_t arg2, parg_t arg3)
   *     __attribute__ ((naked, noinline));
   *
   * parameters are passed in r0-r3 and two parameters on the stack.
   */
  void __panic_entry() __attribute__ ((naked, noinline))
        @C() @spontaneous() {

    __asm__ volatile (
      /*
       * we want the following which will eventually look like an
       * exception frame.
       *
       * offset from SP (after we save)
       *  28    bxPSR           need space for this
       *  24    bxPC            need space for this
       *  20    bxLR
       *  16    bxR12
       *  12    bxR3
       *   8    bxR2
       *   4    bxR1
       *   0    bxR0
       *
       * space for the xPSR and save r0-r3, r12, lr, pc which
       * is what an exception frame looks like.
       */
      "push  {r0-r1}          \n"       /* need space for xPSR and PC */
      "push  {r0-r3, r12, lr} \n"       /* first save and get scratch */

      "mrs   r0, primask      \n"       /* get int enable             */
      "cpsid i                \n"       /* disable normal interrupts  */

      "mov   lr, pc           \n"       /* capture a reasonable PC    */
      "sub   lr, lr, #16      \n"       /* adjust to pnt at start     */
      "mrs   r1, XPSR         \n"       /* nab XPSR and put it where  */
      "str   r1, [SP, #28]    \n"       /* it belongs                 */
      "str   lr, [SP, #24]    \n"       /* stash PC where it belongs  */

      "mrs   r1, basepri      \n"       /* get basepri                */
      "mrs   r2, faultmask    \n"       /* fault mask                 */
      "mrs   r3, control      \n"       /* and finally the CONTROL    */
      "push  {r0-r3}          \n"       /* and save on old stack      */
      : : : "cc", "memory");
    __launch_panic_panic(&__crash_stack_top__);
  }


  /*
   * __panic_exception_entry, hook back into mainline of panic code.
   *
   * input: old_sp      stack pointer from originator side of the fault
   *        crash_sp    crash stack for handling the fault
   */
  extern void __panic_exception_entry(uint32_t *old_sp,
                              uint32_t *crash_sp) @C();

  /* debug code in startup.c (platform) */
  extern void handler_debug(uint32_t exception) @C();

  void __launch_panic_exception(void *new_stack, uint32_t cur_lr)
      __attribute__((naked, noinline)) @C() @spontaneous() {

    __asm__ volatile (
      "mov  lr, r1       \n"            /* restore axLR             */
      "mov  r1, sp       \n"            /* save old_stack           */
      "mov  sp, r0       \n"            /* switch to new stack      */
      "mov  r0, r1       \n"            /* arg0 for panic_entry     */
      "mrs  r1, XPSR     \n"            /* save the axPSR           */
      "mrs  r2, PSP      \n"
      "mrs  r3, MSP      \n"
      "push {r1-r11, lr} \n"            /* save remaining registers */
      "mov  r1, sp       \n"            /* cur crash_stack          */
      : : : "cc", "memory", "sp");

    __asm__ volatile (
      "push {r0-r3, lr}     \n"         /* save for call, debug     */
      "mrs  r0, XPSR        \n"         /* get the exception again  */
      "ubfx r0, r0, #0, #9  \n"         /* extract exception        */
      "bl   handler_debug   \n"         /* debug                    */
      "pop  {r0-r3, lr}     \n"
      : : : "cc", "memory");

    __asm__ volatile (
      "b    __panic_exception_entry \n"
      : : : "cc", "memory");
  }
}
