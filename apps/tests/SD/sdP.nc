/*
 * Copyright @ 2010 Carl W. Davis
 * @author Carl W. Davis
 *
 * sdP - Backdoor interface to SD functions for testing
 *
 */

#include "sd_cmd.h"

module sdP {
  uses {
    interface SDreset;
    interface SDread;
    interface Boot;
    interface Resource;
    interface SDraw;
    interface Boot as FS_OutBoot;
  }
}

implementation {

  sd_cmd_t *cmd;                // Command Structure
  sd_ctl_t *ctl;                // Control Structure
  //uint8_t  data_buf[514];       // 512 for data, 2 at end for CRC
  //uint32_t blk_id;              // Block ID

  event void Boot.booted() {
    call Resource.request();    // Request the arbiter to power and ready SD
  }


  event void Resource.granted() {
    //error_t err;

    call SDraw.get_ptrs(&cmd, &ctl);

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
    cmd->cmd     = SD_SEND_OCR;
    ctl->rsp_len = SD_SEND_OCR_R;
    call SDraw.send_cmd();
    nop();

    /* Setup for CMD10, Read the CID register,  Card Identification Register
     *  returns R1_LEN, 1 byte.  See Section 5.2
     * The CID register contains the Mfg specific info, 128 bits wide,
     *  contains Mfg, OEM, Prod Name, Rev, etc.
     */
    cmd->cmd     = SD_SEND_CID;
    ctl->rsp_len = SD_SEND_CID_R;
    call SDraw.send_cmd();
    nop();

    /* Setup for CMD9, read the CSD register, Card Specific Data register
     *  returns R1_LEN, 1 byte.  See Section 5.3
     * The CSD register contains data format, erro correction type, max
     *  data access time, etc.
     * Access this register to find read block size READ_BL_LEN, write block 
     *  size WRITE_BL_LEN, and erase sector size SECTOR_SIZE, etc.
     *
     */
    cmd->cmd     = SD_SEND_CSD;
    ctl->rsp_len = SD_SEND_CSD_R;
    call SDraw.send_cmd();
    nop();

    /* CMD8

     */







  }

  event void SDread.readDone(uint32_t blk_id, void *data_buf, error_t err) {
    nop();                  // Just a location for a break point
    call Resource.release();
  }

  event void SDreset.resetDone(error_t err) {}

  event void FS_OutBoot.booted() {
    nop();
  }
}
