/**
 * Copyright (c) 2010 Carl W. Davis
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
 *
 * @author Carl W. Davis
 * @author Eric B. Decker <cire831@gmail.com>
 *
 * Controlling defines:
 *
 * SD_TEST_STANDALONE   use standalong (SDsa) interface
 */

/**
 * sdP - Backdoor interface to SD functions for testing
 */

#include "sd_cmd.h"
#include "sd.h"
#include <platform_pin_defs.h>
#include "typed_data.h"


uint8_t d[514] __attribute__ ((aligned (4)));
volatile bool sd_wait = 1;


module sdP {
  uses {
    interface Boot;
    interface SDraw;
    interface SDsa;
    interface SDread;
    interface SDwrite;
    interface Resource as SDResource;

    interface Collect;
    interface Timer<TMilli>;
  }
}

implementation {

  typedef enum {
    READ0,
    WRITE1,
    READ1,
    READ2,
    READ3,
    READ4,
    COLLECT
  } sd_state_t;

  uint8_t   rsp;
  sd_state_t sd_state;

  /* Setup for CMD58, Read the OCR register.  Operation Condition Register
   *  returns R3_LEN, 5 bytes (including the response byte (R1)).  See
   *  Section 7.3.2.4 The OCR register contains the suppored operating
   *  voltages for the current card. Look at bits 15 - 23.  Newer cards,
   *  SDHC has a different implementation, check the HCS bit.  See Section
   *  7.2.1 Mode Selection and Init, and Table 7-3.
   */
  void get_ocr() {
    volatile uint32_t ocr;

    ocr = call SDraw.ocr();

    /* At a very minimum, we must allow 3.3V. */
    if ((ocr & OCR_33) != OCR_33) {
      ROM_DEBUG_BREAK(0);
      return;
    }
  }


  /*
   * Setup for CMD10, Read the CID register, Card Identification Register
   *
   * register contains 128 bits.  See Section 5.2 The CID register contains
   * the Mfg specific info, 128 bits wide, contains Mfg, OEM, Prod Name,
   * Rev, etc.
   */
  void get_cid() {
    volatile uint8_t   cid_data[SD_CID_LEN];
    volatile sd_cid_t *cidp;

    call SDraw.cid((uint8_t *)cid_data);
    cidp = (sd_cid_t *) cid_data;
  }


  /* Setup for CMD9, read the CSD register, Card Specific Data register
   *
   * response is R1_LEN, 1 byte, register contains 128 bits.  See Section 5.3
   * The CSD register contains data format, error correction type, max
   * data access time, etc.
   *
   * Access this register to find read block size READ_BL_LEN, write block 
   * size WRITE_BL_LEN, and erase sector size SECTOR_SIZE, etc.
   */
  void get_csd() {
    uint8_t csd_data[SD_CSD_LEN];
    sd_csd_V1_t *csd1p;
    sd_csd_V2_t *csd2p;

    call SDraw.csd(csd_data);
    csd1p = (sd_csd_V1_t *) csd_data;
    csd2p = (sd_csd_V2_t *) csd_data;
  }



  /* Setup for CMD13, send status of the card
   * returns R2_LEN, 2 bytes, no data block.  See Section 7.3.1.3
   *
   * also ask for SD_STATUS, a 512 bit block.  + 16 for CRC16
   * We see first the CMD55, ACMD13, R2, response, then takes about
   * 350us before we see the start token for the start of the data
   * packet with 528 bits of the SD_STATUS data.
   */
  void get_status() {
    volatile uint8_t      status_data[2];
    volatile uint8_t      sd_status[SD_STATUS_LEN];
    sd_status_t *sdp;
    unsigned int indx;

    call SDraw.start_op();                 // Chip Select Low
    status_data[0] = call SDraw.raw_cmd(SD_SEND_STATUS, 0);
    status_data[1] = call SDraw.get();     // Rest of R2 response
    call SDraw.end_op();                   // Chip Select High
    sdp = (sd_status_t *) status_data;

    call SDraw.start_op();                 // Chip Select Low
    status_data[0] = call SDraw.raw_acmd(SD_SEND_SD_STATUS, 0);
    status_data[1] = call SDraw.get();     // Rest of R2 response
    while (1) {
      rsp = call SDraw.get();
      if (rsp == SD_START_TOK)
	break;
    }
    for (indx = 0; indx < SD_STATUS_LEN; indx++)
      sd_status[indx] = call SDraw.get();
    call SDraw.end_op();
  }


  /* Setup for ACMD51, read the SD Configuration Register,
   *  returns R1_LEN, 1 byte, register contains 64 bits.  See Section 5.6
   *
   * The SCR register contains SCR structure, Spec Version, security support, etc.
   */
  void get_scr() {
    uint8_t scr_data[SD_SCR_LEN];
    sd_scr_t *scrp;

    call SDraw.scr(scr_data);
    scrp = (sd_scr_t *) scr_data;
  }


  /* Returns bit 0-7 of the data
   */
   uint8_t getbit(uint8_t in_data, uint8_t bit) {
     return(in_data >> bit) & 1;
   }


  /* Calculate the CRC7 value for the given command
   *
   */
  uint8_t calc_crc7(uint8_t past_crc, uint8_t data) {
    uint8_t new_crc, cnt, bit_shift;

    new_crc = past_crc;
    for(cnt = 7; cnt >= 0; cnt--) {
      new_crc <<= 1;
      new_crc |= getbit(data, cnt);
      if (getbit(new_crc, 7) == 1)
        new_crc ^= 0x89;
    }
    return(new_crc);
  }


  /* Send CMD8, default voltage argument to 0x01, and echo to 0xAA
   *
   */
  uint8_t send_cmd8() {
    volatile uint8_t cond[4], crc7;

    call SDraw.start_op();                // Chip Select Low
    rsp = call SDraw.raw_cmd(SD_SEND_IF_CONDITION, 0x1aa);
    if (rsp == 0) {
      cond[0] = call SDraw.get();
      cond[1] = call SDraw.get();
      cond[2] = call SDraw.get();
      cond[3] = call SDraw.get();
    }

    call SDraw.end_op();

    if ((cond[2] && 0xf) != 0x01 || (cond[3] != 0xaa))
      return(FAIL);
    return SUCCESS;
  }


  void set(uint8_t val) {
    uint16_t i;
    uint32_t *dp, val32;

    val32 = (val << 24 | val << 16 | val << 8 | val);
    dp = (uint32_t *) &d;
    for (i = 0; i < 514/4; i++)
      dp[i] = val32;
    d[512] = d[513] = val;
  }


  event void Boot.booted() {
    nop();
    nop();

#ifdef SD_TEST_STANDALONE
    call SDsa.reset();
    get_ocr();
    get_cid();
    get_csd();
    get_status();
    get_scr();
    call SDsa.reset();
    nop();
    call SDsa.read(0, d);
    call SDsa.read(0x10000, d);
    call SDsa.write(0x10000, d);
    call SDsa.off();
    while(1) ;
#endif

    set(0xff);
    call SDResource.request();
  }


  event void SDResource.granted() {
    nop();
    nop();
    sd_state = READ0;
    call SDread.read(0x00000, d);
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t* buf, error_t error) {
    uint16_t i;

    nop();
    nop();
    switch(sd_state) {
      case READ0:
        call SDwrite.write(0x08000, d);
        sd_state = WRITE1;
        break;

      case READ1:
        call SDread.read(0x10000, d);
        sd_state = READ2;
        break;

      case READ2:
        call SDread.read(0x20000, d);
        sd_state = READ3;
        break;

      case READ3:
        call SDread.read(0x40000, d);
        sd_state = READ4;
        break;

      case READ4:
        call SDResource.release();
        nop();
        call SDsa.reset();

        nop();
        call SDsa.read(0, d);
        call SDsa.read(0, d);
        set(0xff);
        nop();
        call SDsa.read(0x00000, d);
        call SDsa.read(0x08000, d);
        call SDsa.read(0x10000, d);
        call SDsa.read(0x20000, d);
        call SDsa.read(0x40000, d);
        for (i = 0; i < 514; i++)
          d[i] = i + 1;
        nop();
        call SDsa.write(0x5000, d);
        set(0);
        nop();
        call SDsa.read(0x5000, d);
        nop();
        send_cmd8();
        get_ocr();				// CMD58
        get_cid();				// CMD10
        get_csd();				// CMD9
        get_status();                           // CMD13
        get_scr();				// ACMD51
        call Timer.startPeriodic(2048);
        sd_state = COLLECT;
        break;

      case WRITE1:
      case COLLECT: break;
    }
  }

  event void SDwrite.writeDone(uint32_t blk_id, uint8_t* buf, error_t error) {
    nop();
    nop();
    call SDread.read(0x08000, d);
    sd_state = READ1;
  }

  event void Timer.fired() {
    dt_header_t t;

    nop();
    t.len   = sizeof(dt_header_t) + 256;
    t.dtype = DT_TEST;
    call Collect.collect((void *) &t, sizeof(t), dxx, 256);
  }
}
