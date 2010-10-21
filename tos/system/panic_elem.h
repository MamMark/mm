/*
 * Copyright 2010 (c) Carl W. Davis, Eric B. Decker
 * All rights reserved.
 *
 * @author Carl W. Davis
 * @author Eric B. Decker
 *
 * A panic element (panic_elem) contains a dump of the 
 * machine state after something goes horribly wrong.
 *
 * It contains cpu state, i/o state, and ram state.  And
 * any auxillary information necessary to be able to decode
 * what is going on, ie. being able to decode stack frames,
 * etc.
 *
 * There are significant differences between msp430 processors.
 * Currently we support the msp430F2618 and msp430F5438a.
 *
 * 2618		early i/o	8K ram.
 * 5438a	larger i/o	16K ram.
 *
 * We also support near and far models for data/code.  This
 * needs to be reflected in the header so we know how to
 * interpret register sizes and pointers in registers,
 * on the stack, and stored in ram.
 *
 * All registers are stored as 32 bits even if we are only
 * doing near pointers (16 bits, 64K).
 *
 * Initially we force everything to 16 bit pointers.
 *
 * Structure of Panic Element.
 *
 * A panic element contains multiple blocks in the Panic area that
 * contain one complete dump of machine state (CPU only, regs, i/o memory,
 * and RAM).
 *
 * Block 0 is the panic_elem_hdr:
 *
 * block 1-n: I/O memory space
 * block n+1-(n+m): RAM
 *
 * The size of I/O and RAM spaces are machine dependent.
 *
 * Panic_Elem:
 *
 *	panic_elem_hdr:		1 blk
 *	panic_io:		n blks (2618, 1 blk)
 *	panic_ram:		m blks (2618, 16 blks)
 */


#ifndef __PANIC_ELEM_H__
#define __PANIC_ELEM_H__

/*
 * Specific definition platform MSP430F2618 for Panic
 * element
 * special function registers from 0x0 to 0xF
 * 8 bit peripherals, from 0x10 to 0xFF
 * 16 bit peripherals, from 0x100 to 0x1FF
 * RAM from 0x1100 to 0x30FF
 */

#define IO_START  0x0000
#define IO_BYTES  0x0200
#define RAM_START 0x1100
#define RAM_BYTES 0x2000
#define BUF_SIZE  0x0200


#define PANIC_REG_TYPE uint16_t

typedef struct {
  PANIC_REG_TYPE r1;				/* sp */
  PANIC_REG_TYPE r2;				/* status */
  PANIC_REG_TYPE r3;				/* constant gen */
  PANIC_REG_TYPE r4;
  PANIC_REG_TYPE r5;
  PANIC_REG_TYPE r6;
  PANIC_REG_TYPE r7;
  PANIC_REG_TYPE r8;
  PANIC_REG_TYPE r9;
  PANIC_REG_TYPE r10;
  PANIC_REG_TYPE r11;
  PANIC_REG_TYPE r12;
  PANIC_REG_TYPE r13;
  PANIC_REG_TYPE r14;
  PANIC_REG_TYPE r15;
} panic_regs_t;


typedef struct {
  uint8_t  pcode;
  uint8_t  where;
  uint16_t arg0, arg1, arg2, arg3;
} panic_arg_t;


typedef struct {
  uint32_t	panic_majik_a;
  uint32_t	sys_time;
  uint16_t	cpu_type;
  uint16_t	platform_type;
  uint16_t	boot_count;
  uint32_t	reserved;
  uint16_t	flags;
  uint8_t	ver_major;
  uint8_t	ver_minor;
  uint8_t	ver_build;
  uint8_t	ver_pad;
  panic_regs_t	panic_regs;
  panic_arg_t	args;
  uint32_t	panic_majik_b;
} panic_elem_hdr_t;


#define PANIC_SAVE_REGS16(rp)			\
  do {						\
  __asm__("mov.w r1,%0"  : "=m" ((rp)->r1));	\
  __asm__("mov.w r2,%0"  : "=m" ((rp)->r2));  	\
  __asm__("mov.w r3,%0"  : "=m" ((rp)->r3));  	\
  __asm__("mov.w r4,%0"  : "=m" ((rp)->r4));  	\
  __asm__("mov.w r5,%0"  : "=m" ((rp)->r5));  	\
  __asm__("mov.w r6,%0"  : "=m" ((rp)->r6));  	\
  __asm__("mov.w r7,%0"  : "=m" ((rp)->r7));  	\
  __asm__("mov.w r8,%0"  : "=m" ((rp)->r8));  	\
  __asm__("mov.w r9,%0"  : "=m" ((rp)->r9));  	\
  __asm__("mov.w r10,%0" : "=m" ((rp)->r10));	\
  __asm__("mov.w r11,%0" : "=m" ((rp)->r11)); 	\
  __asm__("mov.w r12,%0" : "=m" ((rp)->r12)); 	\
  __asm__("mov.w r13,%0" : "=m" ((rp)->r13)); 	\
  __asm__("mov.w r14,%0" : "=m" ((rp)->r14)); 	\
  __asm__("mov.w r15,%0" : "=m" ((rp)->r15));	\
  } while (0)

#endif
