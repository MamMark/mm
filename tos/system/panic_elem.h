/*
 * Copyright 2010 (c) Carl W. Davis, Eric B. Decker
 * All rights reserved.
 *
 * @author Carl W. Davis
 * @author Eric B. Decker
 *
 * A panic element (panic_elem) contains a dump of the 
 * machine state after something goes wrong and is detected.
 *
 * It contains cpu state, i/o state, and ram state.  And
 * any auxillary information necessary to be able to decode
 * what is going on, ie. being able to decode stack frames,
 * etc.
 *
 * There are significant differences between different
 * msp430 processors.  Currently we support the msp430F2618
 * and the msp430F5438a.
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
 */


/*
 * Specific definition platform MSP430F2618 for Panic
 * element
 */

typedef struct {
  uint16_t r1;				/* sp */
  uint16_t r2;				/* status */
  uint16_t r3;				/* constant gen */
  uint16_t r4;
  uint16_t r5;
  uint16_t r6;
  uint16_t r7;
  uint16_t r8;
  uint16_t r9;
  uint16_t r10;
  uint16_t r11;
  uint16_t r12;
  uint16_t r13;
  uint16_t r14;
  uint16_t r15;
} panic_regs16_t;

panic_regs16_t pregs16;                   //Registers for Panic


typedef struct {
  uint16_t panic_majik;
  uint16_t cpu_type;
  uint16_t flags;
  uint32_t ver;
  uint32_t sys_time;
  uint16_t boot_count;
  dt_panic_nt panic_info;
  panic_regs16_t panic_regs;
  uint32_t reserved;
} panic_elemhdr_16_t;


/*
 * special function registers from 0h to Fh
 * 8 bit peripherals, from 10h to FFh
 * 16 bit peripherals, from 100h to 1FFh
 */

const typedef struct {
  uint16_t mach_type;
  uint16_t io_start;
  uint16_t io_bytes;
  uint16_t ram_start;
  uint16_t ram_bytes;
} panic_mach_t;

panic_mach_t panic_mach;

panic_mach->io_start  = 0x0;
panic_mach->io_bytes  = 512;
panic_mach->ram_start = 0x1100;
panic_mach->ram_bytes = 8192;

uint16_t panic_blk_id;
panic_blk_id = 300;

//Save General Purpose Registers
#define SAVE_PANIC_REGS16				\
  __asm__("mov.w r1,%0"  : "=m" (pregs16->r1));    	\
  __asm__("mov.w r2,%0"  : "=m" (pregs16->r2));    	\
  __asm__("mov.w r3,%0"  : "=m" (pregs16->r3));    	\
  __asm__("mov.w r4,%0"  : "=m" (pregs16->r4));    	\
  __asm__("mov.w r5,%0"  : "=m" (pregs16->r5));    	\
  __asm__("mov.w r6,%0"  : "=m" (pregs16->r6));    	\
  __asm__("mov.w r7,%0"  : "=m" (pregs16->r7));    	\
  __asm__("mov.w r8,%0"  : "=m" (pregs16->r8));    	\
  __asm__("mov.w r9,%0"  : "=m" (pregs16->r9));    	\
  __asm__("mov.w r10,%0" : "=m" (pregs16->r10));  	\
  __asm__("mov.w r11,%0" : "=m" (pregs16->r11));  	\
  __asm__("mov.w r12,%0" : "=m" (pregs16->r12));  	\
  __asm__("mov.w r13,%0" : "=m" (pregs16->r13));  	\
  __asm__("mov.w r14,%0" : "=m" (pregs16->r14));  	\
  __asm__("mov.w r15,%0" : "=m" (pregs16->r15));




/* Specific definition platform MSP430F5438A for Panic
 * element


typedef struct panic_regsA {
  uint32_t status;
  uint32_t r3;
  uint32_t r4;
  uint32_t r5;
  uint32_t r6;
  uint32_t r7;
  uint32_t r8;
  uint32_t r9;
  uint32_t r10;
  uint32_t r11;
  uint32_t r12;
  uint32_t r13;
  uint32_t r14;
  uint32_t r15;
} panic_regsA_t;

typedef uint32_t* stack_ptrA_t;

panic_regsA_t pregsA;                   //Registers for Panic

//Who called the offending routine
#define SAVE_STACK_PTRA(t)            		  		\
  __asm__("mova r1,%0" : "=m" ((t)->stack_ptr))

//Save 20 bit status register
#define SAVE_STATUSA(t)                   	  		\
  __asm__("mova r2,%0" : "=r" ((t)->pregs.status))

//Save 20 bit General Purpose Registers
#define SAVE_GPRA(t)                        			\
  __asm__("mova r3,%0" : "=m" ((t)->pregs.r3));    	\
  __asm__("mova r4,%0" : "=m" ((t)->pregs.r4));    	\
  __asm__("mova r5,%0" : "=m" ((t)->pregs.r5));    	\
  __asm__("mova r6,%0" : "=m" ((t)->pregs.r6));    	\
  __asm__("mova r7,%0" : "=m" ((t)->pregs.r7));    	\
  __asm__("mova r8,%0" : "=m" ((t)->pregs.r8));    	\
  __asm__("mova r9,%0" : "=m" ((t)->pregs.r9));    	\
  __asm__("mova r10,%0" : "=m" ((t)->pregs.r10));  	\
  __asm__("mova r11,%0" : "=m" ((t)->pregs.r11));  	\
  __asm__("mova r12,%0" : "=m" ((t)->pregs.r12));  	\
  __asm__("mova r13,%0" : "=m" ((t)->pregs.r13));  	\
  __asm__("mova r14,%0" : "=m" ((t)->pregs.r14));  	\
  __asm__("mova r15,%0" : "=m" ((t)->pregs.r15))
*/
