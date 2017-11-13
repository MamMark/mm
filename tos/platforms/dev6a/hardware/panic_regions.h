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
  {          PR_EOR, 0, 4 }
};

#endif /* __PANIC_REGIONS_H__ */
