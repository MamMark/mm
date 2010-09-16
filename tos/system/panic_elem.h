/* 
 *
 * Copyright 2010 (c) Carl W. Davis, Eric B. Decker
 * All rights reserved.
 *
 * @author Carl W. Davis
 * @author Eric B. Decker
 *
 * For now the 2618 and 5438A will be placed here.
 *  16 bit operations will have a 16 suffix, 
 *  20 bit operations will have a 20 suffix.
 */



/* Specific definition platform MSP430F2618 for Panic
 * element
 */
typedef struct {
  uint16_t status;
  uint16_t r3;
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

typedef uint16_t* stack_ptr16_t;

panic_regs16_t pregs16;                   //Registers for Panic

//Who called the offending routine
#define SAVE_PANIC_SP16(t)            		  	\
  __asm__("mov.w r1,%0" : "=m" ((t)->stack_ptr));

//Save status register
#define SAVE_PANIC_SR16(t)                   	  	\
  __asm__("mov.w r2,%0" : "=r" ((t)->pregs16.status));

//Save General Purpose Registers
#define SAVE_PANIC_REGS16(t)                    	\
  __asm__("mov.w r3,%0" : "=m" ((t)->pregs16.r3));    	\
  __asm__("mov.w r4,%0" : "=m" ((t)->pregs16.r4));    	\
  __asm__("mov.w r5,%0" : "=m" ((t)->pregs16.r5));    	\
  __asm__("mov.w r6,%0" : "=m" ((t)->pregs16.r6));    	\
  __asm__("mov.w r7,%0" : "=m" ((t)->pregs16.r7));    	\
  __asm__("mov.w r8,%0" : "=m" ((t)->pregs16.r8));    	\
  __asm__("mov.w r9,%0" : "=m" ((t)->pregs16.r9));    	\
  __asm__("mov.w r10,%0" : "=m" ((t)->preg16s.r10));  	\
  __asm__("mov.w r11,%0" : "=m" ((t)->pregs16.r11));  	\
  __asm__("mov.w r12,%0" : "=m" ((t)->pregs16.r12));  	\
  __asm__("mov.w r13,%0" : "=m" ((t)->pregs16.r13));  	\
  __asm__("mov.w r14,%0" : "=m" ((t)->pregs16.r14));  	\
  __asm__("mov.w r15,%0" : "=m" ((t)->pregs16.r15));


typedef struct {
  uint16_t panic_majic;
  uint16_t cpu_type;
  uint16_t flags;
  uint32_t ver;
  uint32_t sys_time;
  uint16_t boot_count;
  dt_panic_nt panic_info;
  panic_regs16_t panic_regs;
  uint32_t what_is_this;
} panic_elemhdr_16_t;



/* special function registers from 0h to Fh
 * 8 bit peripherals, from 10h to FFh
 * 16 bit peripherals, from 100h to 1FFh
 */
typedef struct panic_io_16 {
  uint16_t* sfregs_prt;
  uint16_t* byteio_prt;
  uint16_t* wordio_prt;
} panic_io_16_t;

const uint16_t io_start  = 0x0;
const uint16_t io_end    = 0x1FF;
const uint16_t ram_start = 0x1100;
const uint16_t ram_end   = 0x30FF;


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
