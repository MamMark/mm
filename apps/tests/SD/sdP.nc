/**
 * Copyright @ 2010 Carl W. Davis
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
 *
 */

/**
 * sdP - Backdoor interface to SD functions for testing
 */

#include "sd_cmd.h"
#include "sd.h"


uint8_t d[514];
bool wait = 1;


module sdP {
  uses {
    interface Boot;
    interface SDraw;
    interface SDsa;
    interface Resource as SDResource;
    interface Boot as FS_OutBoot;
  }
}

implementation {

#include "platform_spi_sd.h"

  sd_cmd_t *cmd;			// Command Structure
  uint8_t   rsp;

  /* CMD8 with voltage selelcted, aa as the echo back, and crc of 87 */
  //const uint8_t cmd8[] = {
  //  SD_GET_VOLTAGE, 0, 0, 0x01, 0xaa, 0x87,
  //};
    

  /* Setup for CMD58, Read the OCR register.  Operation Condition Register
   *  returns R3_LEN, 5 bytes.  See Section 5.1
   * The OCR register contains the suppored operating voltages for the 
   *  current card. Look at bits 15 - 23.
   *  Newer cards, SDHC has a different implementation, check the HCS bit.
   *  See Section 7.2.1 Mode Selection and Init, and Table 7-3.
   */
  void get_ocr() {
    uint8_t ocr_data[4];

    call SDraw.start_op();
    cmd->cmd    = SD_SEND_OCR;
    rsp         = call SDraw.raw_cmd();
    ocr_data[0] = call SDraw.get();
    ocr_data[1] = call SDraw.get();
    ocr_data[2] = call SDraw.get();
    ocr_data[3] = call SDraw.get();
    rsp         = call SDraw.get();
    rsp         = call SDraw.get();
    rsp         = call SDraw.get();
    rsp         = call SDraw.get();
    call SDraw.end_op();

#ifdef notdef
    /* At a very minimum, we must allow 3.3V. */
    if ((cmd->rsp[2] & MSK_OCR_33) != MSK_OCR_33) {
      sd_panic_idle(35, cmd->rsp[2]);
      return;
    }
#endif
  }


  /*
   * Setup for CMD10, Read the CID register,  Card Identification Register
   * response is R1_LEN, 1 byte, register contains 128 bits.  See Section 5.2
   * The CID register contains the Mfg specific info, 128 bits wide,
   *  contains Mfg, OEM, Prod Name, Rev, etc.
   */
  void get_cid() {
    uint8_t   cid_data[SD_CID_LEN];
    sd_cid_t *cidp;
    uint8_t   indx, tmp;

    call SDraw.start_op();               // Chip Select Low
    cmd->cmd = SD_SEND_CID;
    rsp      = call SDraw.raw_cmd();     // Sends command and waits for response
    while (1) {
      tmp = call SDraw.get();            // Check for start token in prefix
      if (tmp == SD_START_TOK)
	break;
    }
    for (indx = 0; indx < SD_CID_LEN; indx++)  // Read in CID register
      cid_data[indx] = call SDraw.get();
    call SDraw.end_op();                       // Chip Select High
    cidp = (sd_cid_t *) cid_data;
  }


  /* Setup for CMD9, read the CSD register, Card Specific Data register
   *  response is R1_LEN, 1 byte, register contains 128 bits.  See Section 5.3
   * The CSD register contains data format, erro correction type, max
   *  data access time, etc.
   *
   * Access this register to find read block size READ_BL_LEN, write block 
   *  size WRITE_BL_LEN, and erase sector size SECTOR_SIZE, etc.
   */
  void get_csd() {
    uint8_t csd_data[SD_CSD_LEN];
    sd_csd_V1_t *csd1p;
    sd_csd_V2_t *csd2p;
    uint8_t indx;
    uint8_t r;
                                // Reading CSD is same as CID above
    call SDraw.start_op();
    cmd->cmd = SD_SEND_CSD;
    r = call SDraw.raw_cmd();
    while (1) {
      r = call SDraw.get();
      if (r == SD_START_TOK)
	break;
    }
    for (indx = 0; indx < SD_CSD_LEN; indx++)
      csd_data[indx] = call SDraw.get();
    call SDraw.end_op();
    csd1p = (sd_csd_V1_t *) csd_data;
    csd2p = (sd_csd_V2_t *) csd_data;
  }



  /* Setup for CMD13, send status of the card
   *  returns R2_LEN, 2 bytes, no data block.  See Section 7.3.1.3
   */
  void get_status() {
    uint8_t      status_data[2];
    sd_status_t *sdp;

    call SDraw.start_op();                 // Chip Select Low
    cmd->cmd = SD_SEND_STATUS;
    status_data[0] = call SDraw.raw_cmd(); // Send and wait for response
    status_data[1] = call SDraw.get();     // Reset of R2 response
    call SDraw.end_op();                   // Chip Select High
    sdp = (sd_status_t *) status_data;
  }


  /* Setup for ACMD51, read the SD Configuration Register,
   *  returns R1_LEN, 1 byte, register contains 64 bits.  See Section 5.6
   *
   * The SCR register contains SCR structure, Spec Version, security support, etc.
   */
  void get_scr() {
    uint8_t scr_data[SD_SCR_LEN];
    sd_scr_t *scrp;
    uint8_t  indx;

    call SDraw.start_op();                    // Chip Select Low
    cmd->cmd = SD_SEND_SCR;
    rsp = call SDraw.raw_acmd();              // CMD55 then send and get response

    /* Determine if this acts like a data block, if so, look for a token
     *  in the prefix.
     */

    for (indx = 0; indx < SD_SCR_LEN; indx++)
      scr_data[indx] = call SDraw.get();
    call SDraw.end_op();
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
    uint8_t cond[4], crc7;

    call SDraw.start_op();                // Chip Select Low

    cmd->cmd = SD_SEND_IF_CONDITION;
    cmd->arg = 0x000001aa;
    cmd->crc = 0x87;
 
    rsp = call SDraw.raw_cmd();
    if (rsp == 0) {
      cond[0] = call SDraw.get();
      cond[1] = call SDraw.get();
      cond[2] = call SDraw.get();
      cond[3] = call SDraw.get();
    }

    call SDraw.end_op();

    if (cond[3] != 0xaa)                   // Check echo and voltage
      return(FAIL);
    if ((cond[2] && 0xf) != 0x01)
      return(FAIL);
    return SUCCESS;
  }


  void set(uint8_t val) {
    uint16_t i;

    for (i = 0; i < 514; i++)
      d[i] = val;
  }


  event void Boot.booted() {
    while (wait)
      ;
//    signal SDResource.granted();
    call SDResource.request();
  }


  event void SDResource.granted() {
    uint16_t i;

    call SDResource.release();
    call SDsa.reset();
    cmd = call SDraw.cmd_ptr();

    call SDsa.read(0, d);
    set(0xff);
    call SDsa.read(0x5000, d);
    for (i = 0; i < 514; i++)
      d[i] = i + 1;
    call SDsa.write(0x5000, d);
    set(0);
    call SDsa.read(0x5000, d);
    send_cmd8();
    get_ocr();				// CMD58
    get_cid();				// CMD10
    get_csd();				// CMD9
    get_status();			// CMD13
    get_scr();				// ACMD51
  }


  event void FS_OutBoot.booted() { }
}
