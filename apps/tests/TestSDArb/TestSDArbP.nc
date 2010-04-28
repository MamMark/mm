/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

module TestSDArbP {
  uses {
    interface Boot;
    interface Resource;
    interface SDread;
    interface Boot as FS_OutBoot;
  }
}

implementation {

  uint8_t buff[514];

  event void Boot.booted() {
    call Resource.request();
  }

  event void Resource.granted() {
    error_t err;

    if ((err = call SDread.read(0, buff)))
      nop();
  }

  event void SDread.readDone(uint32_t blk_id, void *buf, error_t error) {
    nop();
    call Resource.release();
  }

  event void FS_OutBoot.booted() {
    nop();
  }

}
