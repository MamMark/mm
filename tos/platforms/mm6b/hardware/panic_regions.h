/*
 * Copyright (c) 2017-2018 Eric B. Decker
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
 * define which memory/io regions panic is interested in dumping.
 */

#ifndef __PANIC_REGIONS_H__
#define __PANIC_REGIONS_H__

/* end of regions */
#define PR_EOR ((void *) 0xffffffff)

typedef struct {
  void    *base_addr;
  uint32_t len;
  uint32_t element_size;
} panic_region_t;

#define SRAM_LEN (64 * 1024)
const panic_region_t ram_region = { (void *) SRAM_BASE, SRAM_LEN, 1 };


/*
 * NVIC registers...
 *
 * ISER         Enabled Ints bit array x2 words
 * ISPR         Pending Ints bit array x2 words
 * IABR         Active  Ints bit array x2 words
 *
 * many gaps.
 */

/* ICSR and VTOR */
#define ICSR_VTOR           (&SCB->ICSR)
#define ICSR_VTOR_COUNT     2
#define ICSR_VTOR_SIZE      4

/* Fault registers: SHCSR, CFSR, HFSR, DFSR, MMFAR, BFAR, AFSR */
#define FAULT_REGS_BASE     (&SCB->SHCSR)
#define FAULT_REGS_COUNT    7
#define FAULT_REGS_SIZE     4

const panic_region_t io_regions[] = {
  { (void *) TIMER_A0_BASE, 48, 2 },
  { (void *) TIMER_A1_BASE, 48, 2 },
  { (void *) EUSCI_A0_BASE, 32, 2 },
  { (void *) EUSCI_A1_BASE, 32, 2 },
  { (void *) EUSCI_A2_BASE, 32, 2 },
  { (void *) EUSCI_B0_BASE, 32, 2 },
  { (void *) EUSCI_B1_BASE, 32, 2 },
  { (void *) EUSCI_B2_BASE, 32, 2 },
  { (void *) EUSCI_B3_BASE, 32, 2 },
  { (void *) RTC_C_BASE,    32, 2 },
  { (void *) &(WDT_A->CTL),  2, 1 },
  { (void *) &(PMAP->CTL),   2, 1 },
  { (void *) &(P2MAP->PMAP_REG[0]), 8, 2 },
  { (void *) &(P3MAP->PMAP_REG[0]), 8, 2 },
  { (void *) &(P7MAP->PMAP_REG[0]), 8, 2 },
  { (void *) &(TIMER32_1->LOAD), 28, 4 },
  { (void *) &(TIMER32_2->LOAD), 28, 4 },
  { (void *) &(DMA_Channel->DEVICE_CFG), sizeof(DMA_Channel_Type), 4 },
  { (void *) &(DMA_Control->STAT), sizeof(DMA_Control_Type), 4 },

  { (void *) &(NVIC->ISER[0]), 8, 4 },  /*  2 words, bit array */
  { (void *) &(NVIC->ISPR[0]), 8, 4 },  /*  2 words, bit array */
  { (void *) &(NVIC->IABR[0]), 8, 4 },  /*  2 words, bit array */

  { (void *) ICSR_VTOR, (ICSR_VTOR_COUNT * ICSR_VTOR_SIZE),
                ICSR_VTOR_SIZE },
  { (void *) FAULT_REGS_BASE, (FAULT_REGS_COUNT * FAULT_REGS_SIZE),
                FAULT_REGS_SIZE },
  {          PR_EOR, 0, 4 }
};

#endif /* __PANIC_REGIONS_H__ */
