/*
 * Copyright @ 2010 Carl W. Davis
 * @author Carl W. Davis
 *
 * sdP - Backdoor interface to SD functions for testing
 *
 */

#include "sd_cmd.h"
#include "msp430usci.h"

module sdP {
  uses {
    interface SDreset;
    interface Boot;
    interface SDraw;
    interface Boot as FS_OutBoot;
    interface Hpl_MM_hw as HW;
    interface HplMsp430UsciB as Usci;
    interface SDsa;
  }
}

implementation {

#include "platform_sd_spi.h"

  sd_cmd_t *cmd;                // Command Structure

  event void Boot.booted() {
    uint8_t ocr_data[4], rsp, tmp;
    int i;

    call SDsa.reset();
    cmd = call SDraw.cmd_ptr();

    /* The following information for the SD card registers references the
     *  "Physical Layer Simplified Specification Version 2.00, Sept, 25 2006"
     */


    /* Setup for CMD58, Read the OCR register.  Operation Condition Register
     *  returns R3_LEN, 5 bytes.  See Section 5.1
     * The OCR register contains the suppored operating voltages for the 
     *  current card. Look at bits 15 - 23.
     *  Newer cards, SDHC has a different implementation, check the HCS bit.
     *  See Section 7.2.1 Mode Selection and Init, and Table 7-3.
     */
    call SDraw.start_op();
    cmd->cmd     = SD_SEND_OCR;
    rsp = call SDraw.raw_cmd();
    ocr_data[0] = call SDraw.get();
    ocr_data[1] = call SDraw.get();
    ocr_data[2] = call SDraw.get();
    ocr_data[3] = call SDraw.get();
    rsp         = call SDraw.get();
    call SDraw.end_op();

#ifdef notdef
    /* At a very minimum, we must allow 3.3V. */
    if ((cmd->rsp[2] & MSK_OCR_33) != MSK_OCR_33) {
      sd_panic_idle(35, cmd->rsp[2]);
      return;
    }
#endif


    /* Setup for CMD10, Read the CID register,  Card Identification Register
     *  returns R1_LEN, 1 byte.  See Section 5.2
     * The CID register contains the Mfg specific info, 128 bits wide,
     *  contains Mfg, OEM, Prod Name, Rev, etc.
     */
    call SDraw.start_op();
    cmd->cmd     = SD_SEND_CID;
    rsp = call SDraw.raw_cmd();
    while (1) {
      tmp = call SDraw.get();
      if (tmp == 0xfe)
	break;
    }
    for (i = 0; i < 20; i++)
      tmp = call SDraw.get();
    nop();
    call SDraw.end_op();

    /* Setup for CMD9, read the CSD register, Card Specific Data register
     *  returns R1_LEN, 1 byte.  See Section 5.3
     * The CSD register contains data format, erro correction type, max
     *  data access time, etc.
     * Access this register to find read block size READ_BL_LEN, write block 
     *  size WRITE_BL_LEN, and erase sector size SECTOR_SIZE, etc.
     *
     */
    call SDraw.start_op();
    cmd->cmd     = SD_SEND_CSD;
    rsp = call SDraw.raw_cmd();
    while (1) {
      tmp = call SDraw.get();
      if (tmp == 0xfe)
	break;
    }
    for (i = 0; i < 20; i++)
      tmp = call SDraw.get();
    nop();
    call SDraw.end_op();


    /* CMD8

     */


  }

#ifdef notdef
  event void SDread.readDone(uint32_t blk_id, void *data_buf, error_t err) {
    nop();                  // Just a location for a break point
    call Resource.release();
  }
#endif

  event void FS_OutBoot.booted() {
    nop();
  }
}
