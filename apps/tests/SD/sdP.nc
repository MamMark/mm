/*
 * Copyright @ 2010 Carl W. Davis
 * @author Carl W. Davis
 *
 * sdP - Backdoor interface to SD functions for testing
 *
 */

#include "sd_cmd.h"
#include "sd.h"


module sdP {
  uses {
    interface Boot;
    interface SDraw;
    interface SDsa;
    interface Boot as FS_OutBoot;
  }
}

implementation {

#include "platform_sd_spi.h"

  sd_cmd_t    *cmd;                // Command Structure
  uint8_t      rsp;
    

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

    call SDraw.start_op();
    cmd->cmd = SD_SEND_CID;
    rsp      = call SDraw.raw_cmd();
    while (1) {
      tmp = call SDraw.get();
      if (tmp == SD_START_TOK)
	break;
    }
    for (indx = 0; indx < SD_CID_LEN; indx++)
      cid_data[indx] = call SDraw.get();
    call SDraw.end_op();
    cidp = (sd_cid_t *) cid_data;
  }


  /* Setup for CMD9, read the CSD register, Card Specific Data register
   *  returns R1_LEN, 1 byte.  See Section 5.3
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
   *  returns R2_LEN, 2 bytes.  See Section 7.3.1.3
   */
  void get_status() {
    uint8_t      status_data[2];
    sd_status_t *sdp;

    call SDraw.start_op();
    cmd->cmd = SD_SEND_STATUS;
    status_data[0] = call SDraw.raw_cmd();
    status_data[1] = call SDraw.get();
    call SDraw.end_op();
    sdp = (sd_status_t *) status_data;
  }


  /* Setup for ACMD51, read the SD Configuration Register,
   *  returns R1_LEN, 1 byte.
   */
  void get_scr() {
    uint8_t scr_data[SD_SCR_LEN];
    sd_scr_t *scrp;
    uint8_t  indx;

    call SDraw.start_op();
    cmd->cmd = SD_SEND_SCR;
    rsp = call SDraw.raw_acmd();
    for (indx = 0; indx < SD_SCR_LEN; indx++)
      scr_data[indx] = call SDraw.get();
    call SDraw.end_op();
    scrp = (sd_scr_t *) scr_data;
  }


  event void Boot.booted() {
    call SDsa.reset();
    cmd = call SDraw.cmd_ptr();

    get_ocr();				// CMD58
    get_cid();				// CMD10
    get_csd();				// CMD9
    get_status();			// CMD13
    get_scr();				// ACMD51
  }


  event void FS_OutBoot.booted() { }
}
