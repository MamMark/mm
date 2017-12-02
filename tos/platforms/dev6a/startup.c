/*
 * Copyright (c) 2016-2017 Eric B. Decker
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
 *
 * @author Eric B. Decker <cire831@gmail.com>
 *
 * Vector table for msp432 cortex-m4f processor.
 * Startup code and interrupt/trap handlers for the msp432 processors.
 * initial h/w initilization.  In particular clocks and first stage
 * of timer h/w.  See below for h/w initilization.
 */

#include <stdint.h>
#include <msp432.h>
#include <platform.h>
#include <platform_clk_defs.h>
#include <platform_pin_defs.h>
#include <platform_reset_defs.h>
#include <platform_version.h>
#include <image_info.h>
#include <overwatch.h>
#include <cpu_stack.h>

/*
 * all DriverLib calls go to ROM.  Any Flash calls absolutely must
 * go to the ROM copy of DriverLib.  Flash timing in the Flash
 * DriverLib calls don't work correctly when executing out of Flash.
 */
#define __MSP432_DVRLIB_ROM__
#include <rom.h>
#include <rom_map.h>
#include "flash.h"


#ifndef nop
#define nop() __asm volatile("nop")
#endif

#ifndef bkpt
#define bkpt(val) __asm volatile ("bkpt "#val)
#endif

/*
 * msp432.h finds the right chip header (msp432p401r.h) which also pulls in
 * the correct cmsis header (core_cm4.h).  The variables DEVICE and
 * __MSP432P401R__ result in pulling in the appropriate files.
.* See <TINYOS_ROOT_DIR>/support/make/msp432/msp432.rules.
 *
 * If __MSP432_DVRLIB_ROM__ is defined driverlib calls will be made to
 * the ROM copy on board the msp432 chip.
 *
 * use "add-symbol-file symbols_hw 0" in GDB to add various h/w register
 * structure definitions.
 */

extern uint32_t __data_load__;
extern uint32_t __data_start__;
extern uint32_t __data_end__;
extern uint32_t __bss_start__;
extern uint32_t __bss_end__;
extern uint32_t __crash_stack_start__;
extern uint32_t __crash_stack_top__;
extern uint32_t __stack_start__;
extern uint32_t __StackTop__;

extern uint32_t __image_start__;
extern uint32_t __image_length__;


/*
 * image_chk is over the whole image, including the vector_chk field.
 * first calculate the vector sum, modify the binary with the result.
 * then calculate the image sum.
 */
const image_info_t image_info __attribute__ ((section(".image_meta"))) = {
  .ii_sig       = IMAGE_INFO_SIG,
  .image_start  = (uint32_t) &__image_start__,  /* 32 bit load address of binary         */
  .image_length = (uint32_t) &__image_length__, /* how big in bytes                      */
  .vector_chk   = 0,                            /* 32 bit checksum over the vector table */
  .image_chk    = 0,                            /* 32 bit checksum over full image size. */
  .ver_id       = { .major = MAJOR, .minor = MINOR, .build = _BUILD },
  .descriptor0  = { 0 },
  .descriptor1  = { 0 },
  .stamp_date   = { 0 },
  .hw_ver       = { .hw_model = HW_MODEL, .hw_rev = HW_REV }
};

/* see OverWatchP.nc for details */
ow_control_block_t ow_control_block __attribute__ ((section(".overwatch_data")));

/* Crash stack is used by unhandled Exception/Fault and Panic */
uint32_t crash_stack[CRASH_STACK_WORDS] __attribute__ ((section(".crash_stack")));

int  main();                    /* main() symbol defined in RealMainP */
void __Reset();                 /* start up entry point */
void __system_init(bool disable_dcor);

/* see tos/mm/OverWatch/OverWatchP.nc */
extern void owl_strange2gold(uint32_t loc);
extern void owl_startup();


#ifdef MEMINIT_STOP
#define MEMINIT_MAGIC0 0x1061
#define MEMINIT_MAGIC1 0x1062

typedef struct {
  uint16_t mi_magic0;
  uint16_t mi_stop;
  uint16_t mi_magic1;
} meminit_stop_t;

volatile noinit meminit_stop_t meminit_stop;

#endif          /* MEMINIT_STOP */

#ifdef HANDLER_FAULT_WAIT
volatile uint32_t handler_fault_wait;   /* set to deadbeaf to continue */
#endif

void handler_debug(uint32_t exception) {
  uint32_t t0, i;

  WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC;      /* 5 */
  t0 = USECS_VAL;
  while ((USECS_VAL - t0) < WIGGLE_DELAY) ;

  for (i = 0; i < exception; i++)
    WIGGLE_EXC;

  t0 = USECS_VAL;
  while ((USECS_VAL - t0) < WIGGLE_DELAY) ;
  WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC;      /* 5 */

  t0 = USECS_VAL;
  while ((USECS_VAL - t0) < WIGGLE_DELAY) ;

  ROM_DEBUG_BREAK(0xE0);

#ifdef HANDLER_FAULT_WAIT
  while (handler_fault_wait != 0xdeadbeaf) {
    nop();
  };
  handler_fault_wait = 0;
#endif

}


#ifdef notdef
/*
 * If we ever go to an independent HardFault_Handler this is the
 * start.
 */
void HardFault_Handler() __attribute__((interrupt));
void HardFault_Handler() {
  __default_handler();
  /* If set, make sure to clear:
   *
   * CFSR.MMARVALID, BFARVALID
   */
}
#endif


/* see tos/system/panic/PanicP.nc */
extern void __launch_panic_exception(void *new_stack, uint32_t cur_lr);

void __default_handler()  __attribute__((interrupt, naked));
void __default_handler()  {
  register uint32_t cur_lr asm("lr");

  __asm__ volatile (
    "mrs   r0, primask      \n"       /* get int enable             */
    "cpsid i                \n"       /* disable normal interrupts  */
    "mrs   r1, basepri      \n"       /* get basepri                */
    "mrs   r2, faultmask    \n"       /* fault mask                 */
    "mrs   r3, control      \n"       /* and finally the CONTROL    */
    "push  {r0-r3}          \n"       /* and save on old stack      */
    : : : "cc", "memory");
  __launch_panic_exception(&__crash_stack_top__, cur_lr);
}


/*
 * Unless overridded, most handlers get aliased to __default_handler.
 */

#ifdef notdef
/*
 * we no longer let others override system exception handlers
 */
void Nmi_Handler()        __attribute__((weak));
void HardFault_Handler()  __attribute__((weak));
void MpuFault_Handler()   __attribute__((weak));
void BusFault_Handler()   __attribute__((weak));
void UsageFault_Handler() __attribute__((weak));
void SVCall_Handler()     __attribute__((weak));
void Debug_Handler()      __attribute__((weak));
void PendSV_Handler()     __attribute__((weak));
void SysTick_Handler()    __attribute__((weak));
#endif

void Nmi_Handler()        __attribute__((alias("__default_handler")));
void HardFault_Handler()  __attribute__((alias("__default_handler")));
void MpuFault_Handler()   __attribute__((alias("__default_handler")));
void BusFault_Handler()   __attribute__((alias("__default_handler")));
void UsageFault_Handler() __attribute__((alias("__default_handler")));
void SVCall_Handler()     __attribute__((alias("__default_handler")));
void Debug_Handler()      __attribute__((alias("__default_handler")));
void PendSV_Handler()     __attribute__((alias("__default_handler")));
void SysTick_Handler()    __attribute__((alias("__default_handler")));

void PSS_Handler()        __attribute__((weak, alias("__default_handler")));
void CS_Handler()         __attribute__((weak, alias("__default_handler")));
void PCM_Handler()        __attribute__((weak, alias("__default_handler")));
void WDT_Handler()        __attribute__((weak, alias("__default_handler")));
void FPU_Handler()        __attribute__((weak, alias("__default_handler")));
void FLCTL_Handler()      __attribute__((weak, alias("__default_handler")));
void COMP0_Handler()      __attribute__((weak, alias("__default_handler")));
void COMP1_Handler()      __attribute__((weak, alias("__default_handler")));
void TA0_0_Handler()      __attribute__((weak, alias("__default_handler")));
void TA0_N_Handler()      __attribute__((weak, alias("__default_handler")));
void TA1_0_Handler()      __attribute__((weak, alias("__default_handler")));
void TA1_N_Handler()      __attribute__((weak, alias("__default_handler")));
void TA2_0_Handler()      __attribute__((weak, alias("__default_handler")));
void TA2_N_Handler()      __attribute__((weak, alias("__default_handler")));
void TA3_0_Handler()      __attribute__((weak, alias("__default_handler")));
void TA3_N_Handler()      __attribute__((weak, alias("__default_handler")));
void EUSCIA0_Handler()    __attribute__((weak, alias("__default_handler")));
void EUSCIA1_Handler()    __attribute__((weak, alias("__default_handler")));
void EUSCIA2_Handler()    __attribute__((weak, alias("__default_handler")));
void EUSCIA3_Handler()    __attribute__((weak, alias("__default_handler")));
void EUSCIB0_Handler()    __attribute__((weak, alias("__default_handler")));
void EUSCIB1_Handler()    __attribute__((weak, alias("__default_handler")));
void EUSCIB2_Handler()    __attribute__((weak, alias("__default_handler")));
void EUSCIB3_Handler()    __attribute__((weak, alias("__default_handler")));
void ADC14_Handler()      __attribute__((weak, alias("__default_handler")));
void T32_INT1_Handler()   __attribute__((weak, alias("__default_handler")));
void T32_INT2_Handler()   __attribute__((weak, alias("__default_handler")));
void T32_INTC_Handler()   __attribute__((weak, alias("__default_handler")));
void AES_Handler()        __attribute__((weak, alias("__default_handler")));
void RTC_Handler()        __attribute__((weak, alias("__default_handler")));
void DMA_ERR_Handler()    __attribute__((weak, alias("__default_handler")));
void DMA_INT3_Handler()   __attribute__((weak, alias("__default_handler")));
void DMA_INT2_Handler()   __attribute__((weak, alias("__default_handler")));
void DMA_INT1_Handler()   __attribute__((weak, alias("__default_handler")));
void DMA_INT0_Handler()   __attribute__((weak, alias("__default_handler")));
void PORT1_Handler()      __attribute__((weak, alias("__default_handler")));
void PORT2_Handler()      __attribute__((weak, alias("__default_handler")));
void PORT3_Handler()      __attribute__((weak, alias("__default_handler")));
void PORT4_Handler()      __attribute__((weak, alias("__default_handler")));
void PORT5_Handler()      __attribute__((weak, alias("__default_handler")));
void PORT6_Handler()      __attribute__((weak, alias("__default_handler")));


void (* const __vectors[])(void) __attribute__ ((section (".vectors"))) = {
//    handler                              IRQn      exceptionN     priority
  (void (*)(void))(&__StackTop__),      // -16          0
  __Reset,                              // -15          1           -3

  Nmi_Handler,                          // -14          2           -2
  HardFault_Handler,                    // -13          3           -1
  MpuFault_Handler,                     // -12          4
  BusFault_Handler,                     // -11          5
  UsageFault_Handler,                   // -10          6
  0,                                    // -9           7
  0,                                    // -8           8
  0,                                    // -7           9
  0,                                    // -6           10
  SVCall_Handler,                       // -5           11
  Debug_Handler,                        // -4           12
  0,                                    // -3           13
  PendSV_Handler,                       // -2           14
  SysTick_Handler,                      // -1           15
  PSS_Handler,                          //  0           16
  CS_Handler,                           //  1           17
  PCM_Handler,                          //  2           18
  WDT_Handler,                          //  3           19
  FPU_Handler,                          //  4           20
  FLCTL_Handler,                        //  5           21
  COMP0_Handler,                        //  6           22
  COMP1_Handler,                        //  7           23
  TA0_0_Handler,                        //  8           24
  TA0_N_Handler,                        //  9           25
  TA1_0_Handler,                        // 10           26
  TA1_N_Handler,                        // 11           27
  TA2_0_Handler,                        // 12           28
  TA2_N_Handler,                        // 13           29
  TA3_0_Handler,                        // 14           30
  TA3_N_Handler,                        // 15           31
  EUSCIA0_Handler,                      // 16           32
  EUSCIA1_Handler,                      // 17           33
  EUSCIA2_Handler,                      // 18           34
  EUSCIA3_Handler,                      // 19           35
  EUSCIB0_Handler,                      // 20           36
  EUSCIB1_Handler,                      // 21           37
  EUSCIB2_Handler,                      // 22           38
  EUSCIB3_Handler,                      // 23           39
  ADC14_Handler,                        // 24           40
  T32_INT1_Handler,                     // 25           41
  T32_INT2_Handler,                     // 26           42          5 (a0)
  T32_INTC_Handler,                     // 27           43
  AES_Handler,                          // 28           44
  RTC_Handler,                          // 29           45
  DMA_ERR_Handler,                      // 30           46
  DMA_INT3_Handler,                     // 31           47
  DMA_INT2_Handler,                     // 32           48
  DMA_INT1_Handler,                     // 33           49
  DMA_INT0_Handler,                     // 34           50
  PORT1_Handler,                        // 35           51
  PORT2_Handler,                        // 36           52
  PORT3_Handler,                        // 37           53
  PORT4_Handler,                        // 38           54
  PORT5_Handler,                        // 39           55
  PORT6_Handler,                        // 40           56
  __default_handler,                    // 41           57
  __default_handler,                    // 42           58
  __default_handler,                    // 43           59
  __default_handler,                    // 44           60
  __default_handler,                    // 45           61
  __default_handler,                    // 46           62
  __default_handler,                    // 47           63
  __default_handler,                    // 48           64
  __default_handler,                    // 49           65
  __default_handler,                    // 50           66
  __default_handler,                    // 51           67
  __default_handler,                    // 52           68
  __default_handler,                    // 53           69
  __default_handler,                    // 54           70
  __default_handler,                    // 55           71
  __default_handler,                    // 56           72
  __default_handler,                    // 57           73
  __default_handler,                    // 58           74
  __default_handler,                    // 59           75
  __default_handler,                    // 60           76
  __default_handler,                    // 61           77
  __default_handler,                    // 62           78
  __default_handler                     // 63           79
};


/*
 * __map_ports: change port mapping as needed.
 *
 * we only get one shot at this, unless we set PMAPRECFG.
 *
 * Note: map_ports doesn't actually effect anything until a given
 * port's bit is mapped to a module function.  This is actually
 * a function mapper.  One of the reasons it is initially confusing.
 */
void __map_ports() {
  PMAP->KEYID = PMAP_KEYID_VAL;
  P2MAP->PMAP_REG[5] = PMAP_SMCLK;
  P7MAP->PMAP_REG[0] = PMAP_UCA1CLK;
  P7MAP->PMAP_REG[1] = PMAP_UCA1SOMI;
  P7MAP->PMAP_REG[2] = PMAP_UCA1SIMO;
  P7MAP->PMAP_REG[3] = PMAP_TA1CCR1A;
  PMAP->KEYID = 0;              /* lock port mapper */
}


/*
 * Exception/Interrupt system initilization
 *
 * o enable all faults to go to their respective handlers
 * o handlers by default do handler_debug and __panic_exception_entry
 *   which then kicks Panic.
 *
 * Potential issue with PendSV.
 * http://embeddedgurus.com/state-space/2011/09/whats-the-state-of-your-cortex/
 */

#define DIV0_TRAP       SCB_CCR_DIV_0_TRP_Msk
#define UNALIGN_TRAP    SCB_CCR_UNALIGN_TRP_Msk
#define USGFAULT_ENA    SCB_SHCSR_USGFAULTENA_Msk
#define BUSFAULT_ENA    SCB_SHCSR_BUSFAULTENA_Msk
#define MPUFAULT_ENA    SCB_SHCSR_MEMFAULTENA_Msk

void __exception_init() {
  SCB->CCR |= (DIV0_TRAP | UNALIGN_TRAP);
  SCB->SHCSR |= (USGFAULT_ENA | BUSFAULT_ENA | MPUFAULT_ENA);
}


void __watchdog_init() {
  WDT_A->CTL = WDT_A_CTL_PW | WDT_A_CTL_HOLD;         // Halt the WDT
}


void __pins_init() {

  /*
   * see hardware.h for initial values and changed mappings
   */
//  __map_ports();              /* done early for now */

  PA->OUT = 0;                  /* zero all 10 port registers */
  PB->OUT = 0;                  /* P4/P3 */
  PC->OUT = 0;                  /* P6/P5 */
  PD->OUT = 0;                  /* P8/P7 */
  PE->OUT = 0;                  /* P10/P9 */

  P1->OUT = 0x12;               /* P1.1/P1.4 need pull up */
  P1->DIR = 0x01;
  P1->REN = 0x12;

  /* smclk and LED2 pieces */
  P2->DIR  = 0x27;
  P2->SEL0 = 0x20;
  P2->SEL1 = 0x00;

  /* gps is on P3, P4, and P6 */
  P3->OUT = 0x08;
  P3->DIR = 0x68;
  P3->REN = 0x80;

  /*
   * We bring the clocks out so we can watch them.
   *
   * gps_on_off is here too.
   *
   * P4.0 gps_on_off
   * P4.2 ACLK
   * P4.3 MCLK
   *      RTCCLK
   * P4.4 HSMCLK
   *
   * 7 6 5 4 3 2 1 0
   * 0 0 0 1 1 1 0 0
   */
  P4->DIR  = 0x1D;
  P4->SEL0 = 0x1C;
  P4->SEL1 = 0x00;

  /* si446x_sdn = 1, si446x_csn = 1 */
  P5->OUT  = 0x05;
  P5->DIR  = 0x05;

  /*
   * gps_resetn and gps_awake are here.
   *
   * on boot, leave reset as an input, let it float.
   * this lets the gps continue to do what it is doing.
   * If we need to reset it, the gps driver will do it.
   */
  P6->OUT = 0x01;               /* gps_resetn deasserted */
  P6->DIR = 0x01;               /* and make resetn an output */

  /*
   * SD1 is on P7.{0,1,2} and sd1_csn is P9.4
   * Initial state is "powered off" so make all pins be pull ups
   */
  P9->OUT = 0x10;               /* deassert SD1_CSN */
  P9->REN = 0x10;               /* pull up */

  P7->OUT = 0x07;               /* clk, somi, simo, pull up */
  P7->REN = 0x07;               /* pull up */

  /*
   * tell is P8.6  0pO, TA1.0 (TA1OUT0) is P8.0, 0m2O
   * t_exc is 8.5 (0pO).
   */
  P8->DIR = 0x61;               /* tell/t_exc are outputs */
  P8->SEL1 = 1;

  /*
   * SD0 is on P10.0 - P10.3  see hardware.h
   * on reset all pins set to xpI (port, input)
   *
   * pull all lines up and leave as inputs.
   */
  P10->OUT = 0x0F;
  P10->REN = 0x0F;              /* csn, clk, simo, somi pull up */
}


inline void __fpu_on() {
  SCB->CPACR |=  ((3UL << 10 * 2) | (3UL << 11 * 2));
}

inline void __fpu_off() {
  SCB->CPACR &= ~((3UL << 10 * 2) | (3UL << 11 * 2));
}


/*
 * Debug Init
 *
 * o turn various clocks to periphs when debug halt
 * o enable various fault system handlers to trip.
 * o turn on div0 and unaligned traps
 *
 * SCB->CCR(STKALIGN) is already set (from RESET)
 *
 * Do we want (SCnSCB->ACTLR) disfold, disdefwbuf, dismcycint?
 * disdefwbuf, we set for precise busfaults
 *
 * what about cd->demcr (vc_bits) vector catch
 * see dhcsr for access.
 */

void __debug_init() {
  CoreDebug->DHCSR |= CoreDebug_DHCSR_C_MASKINTS_Msk;
  CoreDebug->DEMCR |= (
    CoreDebug_DEMCR_VC_HARDERR_Msk      |
    CoreDebug_DEMCR_VC_INTERR_Msk       |
    CoreDebug_DEMCR_VC_BUSERR_Msk       |
    CoreDebug_DEMCR_VC_STATERR_Msk      |
    CoreDebug_DEMCR_VC_CHKERR_Msk       |
    CoreDebug_DEMCR_VC_NOCPERR_Msk      |
    CoreDebug_DEMCR_VC_MMERR_Msk        |
    CoreDebug_DEMCR_VC_CORERESET_Msk);

  /*
   * disable out of order floating point, no intermixing with integer instructions
   * disable default write buffering.  change all busfaults into precise
   */
  SCnSCB->ACTLR |= SCnSCB_ACTLR_DISOOFP_Pos |
    SCnSCB_ACTLR_DISDEFWBUF_Msk;

  /*
   * By default we stop all the clocks we can to the peripherals
   * when in the debugger.  This helps to avoid inadvertant timeouts
   * when debugging.
   */

  SYSCTL->PERIHALT_CTL =
    SYSCTL_PERIHALT_CTL_HALT_T16_0      |       /* TA0 TMicro */
    SYSCTL_PERIHALT_CTL_HALT_T16_1      |       /* TA1 TMilli */
    SYSCTL_PERIHALT_CTL_HALT_T16_2      |
    SYSCTL_PERIHALT_CTL_HALT_T16_3      |
    SYSCTL_PERIHALT_CTL_HALT_T32_0      |       /* raw usecs */
    SYSCTL_PERIHALT_CTL_HALT_EUA0       |
    SYSCTL_PERIHALT_CTL_HALT_EUA1       |
    SYSCTL_PERIHALT_CTL_HALT_EUA2       |
    SYSCTL_PERIHALT_CTL_HALT_EUA3       |
    SYSCTL_PERIHALT_CTL_HALT_EUB0       |
    SYSCTL_PERIHALT_CTL_HALT_EUB1       |
    SYSCTL_PERIHALT_CTL_HALT_EUB2       |
    SYSCTL_PERIHALT_CTL_HALT_EUB3       |
    SYSCTL_PERIHALT_CTL_HALT_ADC        |
    SYSCTL_PERIHALT_CTL_HALT_WDT        |
    SYSCTL_PERIHALT_CTL_HALT_DMA
    ;

}

void __ram_init() {
  SYSCTL->SRAM_BANKEN = SYSCTL_SRAM_BANKEN_BNK7_EN;   // Enable all SRAM banks
}


#define AMR_AM_LDO_VCORE0 PCM_CTL0_AMR_0
#define AMR_AM_LDO_VCORE1 PCM_CTL0_AMR_1

#ifndef MSP432_VCORE
#warning MSP432_VCORE not defined, defaulting to 0
#define AMR_VCORE AMR_AM_LDO_VCORE0
#elif (MSP432_VCORE == 0)
#define AMR_VCORE AMR_AM_LDO_VCORE0
#elif (MSP432_VCORE == 1)
#define AMR_VCORE AMR_AM_LDO_VCORE1
#else
#warning MSP432_VCORE bad value, defaulting to 0
#define AMR_VCORE AMR_AM_LDO_VCORE0
#endif

void __pwr_init() {
  /*
   * we measured this at about 16us.  Basically the final
   * loop waiting for the power system to come back doesn't
   * take any time.
   */
  while (PCM->CTL1 & PCM_CTL1_PMR_BUSY);
  PCM->CTL0 = PCM_CTL0_KEY_VAL | AMR_VCORE;
  while (PCM->CTL1 & PCM_CTL1_PMR_BUSY);
}


/*
 * BANK0_WAIT_n and BANK1_WAIT_n are the same.
 */
#define __FW_0 FLCTL_BANK0_RDCTL_WAIT_0
#define __FW_1 FLCTL_BANK0_RDCTL_WAIT_1
#define __FW_2 FLCTL_BANK0_RDCTL_WAIT_2
#define __FW_3 FLCTL_BANK0_RDCTL_WAIT_3

#ifndef MSP432_FLASH_WAIT
#warning MSP432_FLASH_WAIT not defined, defaulting to 2
#define __FW __FW_2
#elif (MSP432_FLASH_WAIT == 0)
#define __FW __FW_0
#elif (MSP432_FLASH_WAIT == 1)
#define __FW __FW_1
#elif (MSP432_FLASH_WAIT == 2)
#define __FW __FW_2
#elif (MSP432_FLASH_WAIT == 3)
#define __FW __FW_3
#else
#warning MSP432_FLASH_WAIT bad value, defaulting to 2
#define __FW __FW_2
#endif

void __flash_init() {
  /*
   * For now turn off buffering, (FIXME) check to see if buffering makes
   * a difference when running at 16MiHz
   */
  FLCTL->BANK0_RDCTL &= ~(FLCTL_BANK0_RDCTL_BUFD | FLCTL_BANK0_RDCTL_BUFI);
  FLCTL->BANK1_RDCTL &= ~(FLCTL_BANK1_RDCTL_BUFD | FLCTL_BANK1_RDCTL_BUFI);
  FLCTL->BANK0_RDCTL = (FLCTL->BANK0_RDCTL & ~FLCTL_BANK0_RDCTL_WAIT_MASK) | __FW;
  FLCTL->BANK1_RDCTL = (FLCTL->BANK1_RDCTL & ~FLCTL_BANK1_RDCTL_WAIT_MASK) | __FW;
}


#define T32_ENABLE TIMER32_CONTROL_ENABLE
#define T32_32BITS TIMER32_CONTROL_SIZE
#define T32_PERIODIC TIMER32_CONTROL_MODE

void __t32_init() {
  Timer32_Type *tp = TIMER32_1;

  /*
   * Tx (Timer32_1) is used for a 32 bit running count that is supposed to
   * be 1 uis (1 binary us).  However, depending on what clock is being
   * used it may not be possible to get binary, it can be decimal us.
   * Further, the T32 h/w can only divide by 1, 16, and 32, so again it
   * becomes difficult to get 1us or 1uis.  So platform_clk_defs.h defines
   * various controls that gets us close.  The Prescaler (divider),
   * MSP432_T32_PS gets us as close a possible and a correction is then
   * applied by dividing further.  The correction divisior is
   * MSP432_T32_USEC_DIV.
   *
   * The MSP432_T32_USEC_DIV correction is applied in Platform.usecsRaw, see
   * PlatformP.nc.
   */
  tp->LOAD = 0xffffffff;
  tp->CONTROL = MSP432_T32_PS | T32_ENABLE | T32_32BITS;

  /*
   * Using Ty as a 1 second ticker.
   */
  tp = TIMER32_2;
  tp->LOAD = MSP432_T32_ONE_SEC;        /* ticks in a seconds */
  tp->CONTROL = MSP432_T32_PS | T32_ENABLE | T32_32BITS | T32_PERIODIC;
}


/*
 * DCOSEL_3:    center 12MHz (~8 < 12 < 16, but is actually larger)
 * DCORES:      external resistor
 * DCOTUNE:     +152 (0x98), moves us up to 16MiHz.
 * ACLK:        LFXTCLK/1       32768
 * BCLK:        LFXTCLK/1       32768
 * SMCLK:       DCO/2           8MiHz
 * HSMCLK:      DCO/2           8MiHz
 * MCLK:        DCO/1           16MiHz
 *
 * technically, Vcore0 is only good up to 16MHz with 0 flash wait
 * states.  We have seen it work but it is ~5% overclocked and it
 * isn't a good idea.  If you want 16MiHz you need 1 flash wait
 * state or run with Vcore1.  We do Vcore0 and the 1 flash wait
 * state.  That is 1 memory bus clock extra.  The main cpu does
 * instruction fetchs in lines of 16 bytes and the extra wait state
 * probably overlaps in the pipeline.
 *
 * Flash wait states and power manipulation happens before core_clk_init.
 *
 * LFXTDRIVE:   3 max (default).
 *
 * CLKEN:       SMCLK/HSMCLK/MCLK/ACLK enabled (default)
 *
 * PJ.0/PJ.1    LFXIN/LFXOUT need to be in crystal mode (Sel01)
 *
 * DO NOT MESS with PJ.4 and PJ.5 (JTAG pins, TDO and TDI)
 *
 * Research Fault counts and mechanisms for oscillators.
 * Research stabilization
 * Research CS->DCOERCAL{0,1}
 */

/*
 * CLK_DCOTUNE was determined by running CS_setDCOFrequency(TARGET_FREQ)
 * and seeing what it produced.  This was from driverlib.  We have observed
 * with a scope clocking at 16MiHz.  No idea of the tolerance or variation.
 *
 * DCO tuning is discussed in AppReport SLAA658A, Multi-Frequency Range
 * and Tunable DCO on MSP432P4xx Microcontrollers.
 * (http://www.ti.com/lit/an/slaa658a/slaa658a.pdf).
 *
 * According to https://e2e.ti.com/support/microcontrollers/msp430/f/166/t/411030
 * and page 52 of datasheet (SLAS826E) the DCO with external resistor has a
 * tolerance of worst case +/- 0.6%.  Which gives us a frequency range of
 * 16676553 to 16877879 Hz.  Desired frequency is 16777216Hz.  16MiHz.
 *
 * We have observed LFXT (crystal) taking ~1.5s to stabilize.  This was
 * timed using TX (Timer32_1) clocking DCOCLK/16 to get 1uis ticks.  This
 * assumes the DCOCLK comes right up and is stable.  According to the
 * datasheet (SLAS826E, msp432p401), DCO settling time when changing
 * DCORSEL is 10us and t_start is 5 us so we should be good.
 */

#ifndef MSP432_DCOCLK
#warning MSP432_DCOCLK not defined, defaulting to 16777216
#define MSP432_DCOCLK 16777216
#endif

#if MSP432_DCOCLK == 10000000
#define CLK_DCORSEL CS_CTL0_DCORSEL_3
#define CLK_DCOTUNE (-107 & 0x3ff)

#elif MSP432_DCOCLK == 16777216
#define CLK_DCORSEL CS_CTL0_DCORSEL_3
#define CLK_DCOTUNE 158
//#define CLK_DCOTUNE 168
//#define CLK_DCOTUNE 134

#elif MSP432_DCOCLK == 24000000
#define CLK_DCORSEL CS_CTL0_DCORSEL_4
#define CLK_DCOTUNE 0

#elif MSP432_DCOCLK == 33554432
#define CLK_DCORSEL CS_CTL0_DCORSEL_4
#define CLK_DCOTUNE 155

#elif MSP432_DCOCLK == 48000000
#define CLK_DCORSEL CS_CTL0_DCORSEL_5
#define CLK_DCOTUNE 0

#else
#warning MSP432_DCOCLK illegal value, defaulting to 16777216
#define CLK_DCORSEL CS_CTL0_DCORSEL_3
#define CLK_DCOTUNE 152
#endif


uint32_t lfxt_startup_time;

void __core_clk_init(bool disable_dcor) {
  uint32_t timeout;
  uint32_t control;

  /*
   * only change from internal res to external when dco in dcorsel_1.
   * When first out of POR, DCORSEL will be 1, once we've set DCORES
   * it stays set and we no longer care about changing it (because
   * it always stays 1).
   *
   * hitting the clocks here looks like it takes 8.5us to switch.
   */
  control  = CLK_DCORSEL | CLK_DCOTUNE;
  if (!disable_dcor) control |= CS_CTL0_DCORES;

  CS->KEY  = CS_KEY_VAL;
  CS->CTL0 = control;
  CS->CTL1 = CS_CTL1_SELS__DCOCLK  | CS_CTL1_DIVS__2 | CS_CTL1_DIVHS__2 |
             CS_CTL1_SELA__LFXTCLK | CS_CTL1_DIVA__1 |
             CS_CTL1_SELM__DCOCLK  | CS_CTL1_DIVM__1;
  /*
   * turn on the t32s running off MCLK (mclk/16 -> (1MiHz | 3MHz) so we can
   * time the turn on of the remainder of the system.
   */
  __t32_init();                   /* rawUsecs */

  /*
   * turn on the 32Ki LFXT system by enabling the LFXIN LFXOUT pins
   * Do not tweak the SELs on PJ.4/PJ.5, they are reset to the proper
   * values for JTAG access.  If you tweak them the debug connection goes
   * south.
   */
  BITBAND_PERI(PJ->SEL0, 0) = 1;
  BITBAND_PERI(PJ->SEL0, 1) = 1;
  BITBAND_PERI(PJ->SEL1, 0) = 0;
  BITBAND_PERI(PJ->SEL1, 1) = 0;

  /* turn on LFXT and wait for the fault to go away */
  timeout = 0;
  BITBAND_PERI(CS->CTL2, CS_CTL2_LFXT_EN_OFS) = 1;
  while (BITBAND_PERI(CS->IFG, CS_IFG_LFXTIFG_OFS)) {
    if (--timeout == 0) {
      CS->IFG;
      CS->STAT;
      ROM_DEBUG_BREAK(0xFF);
      owl_strange2gold(0x1000);
    }
    BITBAND_PERI(CS->CLRIFG,CS_CLRIFG_CLR_LFXTIFG_OFS) = 1;
  }
  CS->KEY = 0;                  /* lock module */
  lfxt_startup_time = (1-(TIMER32_1->VALUE))/MSP432_T32_USEC_DIV;
}


#define TA_FREERUN      TIMER_A_CTL_MC__CONTINUOUS
#define TA_CLR          TIMER_A_CTL_CLR
#define TA_ACLK1        (TIMER_A_CTL_SSEL__ACLK  | TIMER_A_CTL_ID__1)
#define TA_SMCLK_ID     (TIMER_A_CTL_SSEL__SMCLK | MSP432_TA_ID)

void __ta_init(Timer_A_Type * tap, uint32_t clkdiv, uint32_t ex_div) {
  tap->EX0 = ex_div;
  tap->CTL = TA_FREERUN | TA_CLR | clkdiv;
  tap->R = 0;
}


void __rtc_init() {
  RTC_C_Type *rtc = RTC_C;

  /* write the key, and nuke any interrupt enables */
  rtc->CTL0 = RTC_C_KEY;
  rtc->CTL13 = RTC_C_CTL13_HOLD;
  rtc->PS = 0;
  rtc->TIM0 = 0;
  rtc->TIM1 = 0;
  rtc->DATE = 0;
  rtc->YEAR = 0;
  rtc->CTL0 = 0;                /* close the lock */
}


void __start_timers() {
  /* let the RTC go */
  RTC_C->CTL0 = RTC_C_KEY;
  BITBAND_PERI(RTC_C->CTL13, RTC_C_CTL13_HOLD_OFS) = 0;
  RTC_C->CTL0 = 0;                /* close the lock */

  /* restart the 32 bit 1MiHz tickers */
  TIMER32_1->LOAD = 0xffffffff;
  TIMER32_2->LOAD = MSP432_T32_ONE_SEC;
}


/**
 * Initialize the system
 *
 * Comment about initial CPU state
 *
 * Desired configuration:
 *
 * LFXTCLK -> ACLK, BCLK
 * HFXTCLK off
 * MCLK (Main Clock) - 16MiHz, <- DCOCLK/1
 * HSMCLK (high speed submain) <- DCOCLK/1 16MiHz (can be faster than 12 MHz)
 *     only can drive ADC14.
 * SMCLK (low speed submain)   DCOCLK/2, 8MiHz (dont exceed 12MHz)
 * SMCLK/8 -> TA0 (1us) -> TMicro
 * ACLK/1 (32KiHz) -> TA1 (1/32768) -> TMilli
 * BCLK/1 (32KiHz) -> RTC
 *
 * Timers:
 *
 * RTCCLK <- BCLK/1 (32Ki)
 * TMicro <-  TA0 <- SMCLK/8 <- DCO/2 (1MiHz)
 * TMilli <-  TA1 <- ACLK/1 (32KiHz)
 * rawUsecs<- T32_1 <- MCLK/16 <- DCO/1 32 bit raw usecs
 * rawJiffies<- TA1 <- ACLK/1 (32KiHz) 16 bits wide
 */

void __system_init(bool disable_dcor) {
  __exception_init();
  __debug_init();
  __ram_init();
  __pwr_init();
  __flash_init();

  BITBAND_PERI(P1->OUT, 0) = 1;
  __core_clk_init(disable_dcor);
  BITBAND_PERI(P1->OUT, 0) = 0;

  __ta_init(TIMER_A0, TA_SMCLK_ID, MSP432_TA_EX);         /* Tmicro */
  __ta_init(TIMER_A1, TA_ACLK1,    TIMER_A_EX0_IDEX__1);  /* Tmilli */
  __rtc_init();
  __start_timers();
}


/*
 * Start-up code
 *
 * Performs the following:
 *   o turns off interrupts (primask)
 *   o copy _data (preinitilized data) into RAM
 *   o zero BSS segment
 *   o move the interrupt vectors if required.
 *   o call __system_init() to bring up required system modules
 *   o call main()
 *   o handle exit from main() (shouldn't happen)
 *
 * leaves interrupts off
 *
 * experiment with configurable/permanent ROM_DEBUG_BREAK:
 *      https://answers.launchpad.net/gcc-arm-embedded/+question/248410
 */

#ifdef notdef

uint32_t deltas[256];
uint32_t next_delta;

void timer_check() {
  uint32_t t0, t1, dt;

  TIMER_A1->CCR[0] = 31;
  TIMER_A1->CTL = 0x116;
  TIMER_A1->CCTL[0] = TIMER_A_CCTLN_OUTMOD_4; /* toggle */

  TIMER32_2->CONTROL = 0;
  TIMER32_2->INTCLR = 0;
  TIMER32_2->LOAD = 1024;

  TIMER_A1->R = 0;
  while (TIMER_A1->R == 0) ;
  TIMER_A1->CTL = 0x116;
  TIMER32_2->CONTROL = 0xc6;

  while(1) {
    if (TIMER32_2->RIS) {
      TIMER32_2->INTCLR = 0;
      TELL_PORT->OUT ^= TELL_BIT;
    }
  }

  /*
   * TA1 is ticking at 32KiHz (1/32768 -> 30.5+ us/tick, jiffy)
   * 32768 in one sec.  32 jiffies in 1mis.  1mis is .9765625 ms.
   * 33 jiffies is 1.00708007829 us (.7% error).  It counts one
   * more than what is in CCR0.
   *
   * 320 jiffies is 9.765625.  327 is 9.97924804851 (.2% error),
   * 328 is 10.00976562664 (.1% error).
   */
  nop();
  next_delta = 0;
  t0 = (1-(TIMER32_1->VALUE))/MSP432_T32_USEC_DIV;
  while (1) {
    t1 = (1-(TIMER32_1->VALUE))/MSP432_T32_USEC_DIV;
    if (TIMER_A1->CTL & TIMER_A_CTL_IFG) {
      dt = t1 - t0;
      deltas[next_delta++] = dt;
      if (next_delta >= 256) next_delta = 0;
      t0 = t1;
      TELL_PORT->OUT ^= TELL_BIT;
//    TIMER_A1->CCTL[0] ^= TIMER_A_CCTLN_OUT;
      TIMER_A1->IV;
    }
  }
}

#endif


void start() __attribute__((alias("__Reset")));
void __Reset() {
  uint32_t *from;
  uint32_t *to;
  bool      disable_dcor;
  register void *stkptr asm("sp");

  /* make sure interrupts are disabled */
  __disable_irq();

  /* and make sure we have an appropriate VTOR.  GoldenOW uses 0x0000000
   * while NIB images use 0x00020000.  __vectors should always have the
   * correct value.
   */
  __DSB(); __ISB();
  SCB->VTOR = (uint32_t) &__vectors;
  __DSB(); __ISB();

  /* we do this early because of SMCLK.  Later can move into pins_init */
  __map_ports();                /* change P2, P3, P7 mapping */

  /*
   * send clocks out for debugging.
   *
   * 4.2 ACLK
   * 4.3 MCLK
   * 4.4 HSMCLK
   * 7.0 SMCLK
   */
  P4->OUT  = 0;                 /* make sure gps_on_off doesn't wiggle */
  P4->SEL0 = 0x1C;
  P4->SEL1 = 0x00;
  P4->DIR  = 0x1D;

  P2->OUT  = 0;
  P2->SEL0 = 0x20;              /* smclk */
  P2->SEL1 = 0x00;
  P2->DIR  = 0x27;

  /*
   * tell is P8.6  0pO, TA1.0 (TA1OUT0) is P8.0, 0m2O
   * t_exc (tell_exeception) is 8.5 0pO
   */
  P8->OUT = 0;                  /* set tell and exc up */
  P8->DIR = 0x61;
  P8->SEL1 = 1;                 /* TA1.0 (OUT0) */

  __watchdog_init();
  __pins_init();

  /*
   * invoke overwatch low level to see how we should proceed.  this gets
   * invoked regardless of Gold or Nib space.
   *
   * Will return if we should continue the normal boot.
   *
   * owl (overwatch lowlevel) is responsible for management of the
   * ow_control_block.  Included is retrieving the current status of the
   * reset system.  This is also where information about a possible DCO
   * short shows up.
   *
   * owl_startup() will clean out any pending reset status bits so we
   * need to look to see if the DCOR is shorted first.  If it is shorted
   * it will reset the processor.
   *
   * If the short bit is set, disable the DCOR.
   */
  disable_dcor = RSTCTL->CSRESET_STAT & RSTCTL_CSRESET_STAT_DCOR_SHT;
  ROM_DEBUG_BREAK(0);
  owl_startup();

  __system_init(disable_dcor);

//  timer_check();

#ifdef MEMINIT_STOP
  /*
   * when debugging weird shit, we sometimes need to take a look at
   * what was left over from a previous fault or crash.
   *
   * meminit_stop_flag when set will stop the system from coming up and
   * initializing memory.
   */

  if (meminit_stop.mi_magic0 != MEMINIT_MAGIC0 ||
      meminit_stop.mi_magic1 != MEMINIT_MAGIC1) {
    meminit_stop.mi_magic0 = MEMINIT_MAGIC0;
    meminit_stop.mi_stop   = 0;
    meminit_stop.mi_magic1 = MEMINIT_MAGIC1;
  }
  while (meminit_stop.mi_stop) {
    nop();
  }
#endif

  /*
   * initialize both the crash_stack and normal stack.
   *
   * we set the entire areas to STACK_UNUSED and the last word of the stack
   * to be STACK_GUARD.  This is actually the first word of the area since
   * the stacks grow downward.
   *
   * If GUARD ever gets written on that is bad.
   */

  to    = &__crash_stack_start__;
  *to++ = STACK_GUARD;
  while (to < &__crash_stack_top__)
    *to++ = STACK_UNUSED;

  to    = &__stack_start__;
  *to++ = STACK_GUARD;
  while (to < (uint32_t *) stkptr)
    *to++ = STACK_UNUSED;

  from = &__data_load__;
  to   = &__data_start__;;
  while (to < &__data_end__)
    *to++ = *from++;

  // Fill BSS data with 0
  to = &__bss_start__;
  while (to < &__bss_end__)
    *to++ = 0;

  main();
  while (1) {
    ROM_DEBUG_BREAK(0);
  }
}


/*
 * Flash access routines.
 *
 * All Flash must run out of RAM or out of ROM.  Running out of Flash
 * causes timing problems.
 */

bool __flash_performMassErase() {
  return ROM_FlashCtl_performMassErase();
}


bool __flash_programMemory(void* src, void* dest, uint32_t length) {
  return ROM_FlashCtl_programMemory(src, dest, length);
}
