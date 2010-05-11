/*
 * Copyright @ 2010 Carl W. Davis
 * @author Carl W. Davis
 *
 * sdP - Backdoor interface to SD functions for testing
 *
 */

#include "sd_cmd.h"

module sdP {
  provides {
    interface ResourceDefaultOwner as PwrMgr;
  }
  uses {
    interface SDread;
    //interface SDreset;
    interface Boot;
    interface Boot as FS_OutBoot;
    interface SDraw;
  }
}

implementation {

  event void Boot.booted() {

    signal PwrMgr.requested();
  }

  uint8_t d[514];

  async command error_t PwrMgr.release() {
    sd_cmd_t *cmd;
    sd_ctl_t *ctl;
    uint8_t  rtn;

    //blkaddr = 0x0300;
    //call SDread.read(blkaddr, d);


    call SDraw.get_ptrs(&cmd, &ctl);

    /* Read the OCR (SPI mode only), Operation Condition Register
       #define CMD58 (58 | 0x40)
       #define SD_SEND_OCR CMD58
       #define SD_SEND_OCR_R R3_LEN
    */

    cmd->cmd     = SD_SEND_OCR;
    ctl->rsp_len = SD_SEND_OCR_R;    // Set to 5

    //cmd->arg = (blk_start << SD_BLOCKSIZE_NBITS); No arguments for OCR



    if ((rtn = call SDraw.send_cmd()) == 0)
      return FAIL;
    else
      return SUCCESS;
  }

  event void SDread.readDone(uint32_t backdoorblk, void *databuf, error_t err) {
    signal PwrMgr.granted();
  }

  async command bool PwrMgr.isOwner() { return TRUE; }
  //event void SDreset.resetDone(error_t err) {}
  event void FS_OutBoot.booted() {}
}
