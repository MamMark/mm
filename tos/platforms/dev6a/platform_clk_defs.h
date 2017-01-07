/*
 * The following defines control low level hw init.
 *
 * MSP432_DCOCLK       16777216 | 33554432 | 48000000   dcoclk
 * MSP432_VCORE:       0 or 1                           core voltage
 * MSP432_FLASH_WAIT:  number of wait states, [0-3]     needed wait states
 * MSP432_T32_PS       (1 | 16 | 32)                    prescale divisor for t32
 * MSP432_T32_USEC_DIV (1 | 3)                          convert raw Tx to us or uis
 * MSP432_T32_ONE_SEC  1048576 | 2097152 | 3000000      ticks for one sec (t32)
 * MSP432_TA_ID        TIMER_A_CTL_ID__<n>              n is the divider
 * MSP432_TA_EX        TIMER_A_EX0_IDEX__<n>            extra ta divisor <n>
 *
 * SMCLK is always DCOCLK/2.  SMCLK/(TA_ID * TA_EX) should be around 1MHz/1MiHz.
 */

#define T32_DIV_1  TIMER32_CONTROL_PRESCALE_0
#define T32_DIV_16 TIMER32_CONTROL_PRESCALE_1
#define T32_DIV_32 TIMER32_CONTROL_PRESCALE_2

#define MSP432_DCOCLK      48000000UL
#define MSP432_VCORE       1
#define MSP432_FLASH_WAIT  1
#define MSP432_T32_PS      T32_DIV_16
#define MSP432_T32_USEC_DIV 3
#define MSP432_T32_ONE_SEC 3000000UL
#define MSP432_TA_ID   TIMER_A_CTL_ID__ ## 8
#define MSP432_TA_EX TIMER_A_EX0_IDEX__ ## 3

#ifdef notdef
#define MSP432_DCOCLK      33554432UL
#define MSP432_VCORE       1
#define MSP432_FLASH_WAIT  1
#define MSP432_T32_PS      T32_DIV_16
#define MSP432_T32_USEC_DIV 2
#define MSP432_T32_ONE_SEC 2097152
#define MSP432_TA_ID   TIMER_A_CTL_ID__ ## 8
#define MSP432_TA_EX TIMER_A_EX0_IDEX__ ## 2
#endif

#ifdef notdef
#define MSP432_DCOCLK      24000000UL
#define MSP432_VCORE       1
#define MSP432_FLASH_WAIT  0
#define MSP432_T32_PS      T32_DIV_1
#define MSP432_T32_USEC_DIV 24
#define MSP432_T32_ONE_SEC 24000000UL
#define MSP432_TA_ID   TIMER_A_CTL_ID__ ## 4
#define MSP432_TA_EX TIMER_A_EX0_IDEX__ ## 3
#endif

#ifdef notdef
/* default 16MiHz */
#define MSP432_DCOCLK      16777216UL
#define MSP432_VCORE       0
#define MSP432_FLASH_WAIT  1
#define MSP432_T32_PS      T32_DIV_16
#define MSP432_T32_USEC_DIV 1
#define MSP432_T32_ONE_SEC 1048576UL
#define MSP432_TA_ID   TIMER_A_CTL_ID__ ## 8
#define MSP432_TA_EX TIMER_A_EX0_IDEX__ ## 1
#endif

#ifdef notdef
#define MSP432_DCOCLK      10000000UL
#define MSP432_VCORE       0
#define MSP432_FLASH_WAIT  0
#define MSP432_T32_PS      T32_DIV_1
#define MSP432_T32_USEC_DIV 10
#define MSP432_T32_ONE_SEC 10000000UL
#define MSP432_TA_ID   TIMER_A_CTL_ID__ ## 1
#define MSP432_TA_EX TIMER_A_EX0_IDEX__ ## 5
#endif
