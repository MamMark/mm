/*
 * Copyright (c) 2016 Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

/*
 * This file is used to build an object that contains various types that
 * can be imported into GDB for messing with hardware on the msp432.
 *
 * To use from within gdb type "add-symbol-file <path/to/symbols.o> 0"
 *
 */

#include <stdint.h>
#include <msp432.h>

/*
 * msp432.h find the right chip header (msp432p401r.h) which also pulls in
 * the correct cmsis header (core_cm4.h).
 *
 * If __MSP432_DVRLIB_ROM__ is defined driverlib calls will be made to
 * the ROM copy on board the msp432 chip.
 */


/*
 * dma control block
 */
typedef struct {
  volatile void *src_end;
  volatile void *dest_end;
  volatile uint32_t control;
  volatile uint32_t pad;
} dma_cb_t;


/* pull in the type definitions.  allocates 4 bytes per (pointers) */
SCB_Type                    *__scb;
SCnSCB_Type                 *__scnscb;
SysTick_Type                *__systick;
NVIC_Type                   *__nvic;
ITM_Type                    *__itm;
DWT_Type                    *__dwt;
TPI_Type                    *__tpi;
CoreDebug_Type              *__cd;
MPU_Type                    *__mpu;
FPU_Type                    *__fpu;

RSTCTL_Type                 *__rstctl;
SYSCTL_Type                 *__sysctl;
SYSCTL_Boot_Type            *__sysboot;
CS_Type                     *__cs;
DIO_PORT_Odd_Interruptable_Type  *__p_odd;
DIO_PORT_Even_Interruptable_Type *__p_even;
PSS_Type                    *__pss;
PCM_Type                    *__pcm;
FLCTL_Type                  *__flctl;
DMA_Channel_Type            *__dmachn;
DMA_Control_Type            *__dmactl;
PMAP_COMMON_Type            *__pmap;
PMAP_REGISTER_Type          *__p1map;
CRC32_Type                  *__crc32;
AES256_Type                 *__aes256;
WDT_A_Type                  *__wdt;
Timer32_Type                *__t32;
Timer_A_Type                *__ta0;
RTC_C_Type                  *__rtc;
REF_A_Type                  *__ref;
ADC14_Type                  *__adc14;
EUSCI_A_Type                *_uca0;
EUSCI_B_Type                *_ucb0;
FL_BOOTOVER_MAILBOX_Type    *__bomb;
TLV_Type                    *__tlv;
dma_cb_t                    *__dma_cb;
