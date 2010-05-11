/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

uint16_t doit, erase;

module TestSDArbP {
  uses {
    interface SDread;
    interface SDwrite;
    interface SDerase;
    interface Boot;
    interface Resource;
    interface Boot as FS_OutBoot;
  }
}

implementation {

  typedef enum {
    SDArb_0,
    SDArb_1,
    SDArb_2,
  } sd_arb_state_t;

  uint8_t buff[514];
  sd_arb_state_t sd_arb_state;


  event void Boot.booted() {
    while (!doit)
      ;

    call Resource.request();
  }


  event void Resource.granted() {
    error_t err;

    if (erase)
      call SDerase.erase(0x5000, 0x5000);

    sd_arb_state = SDArb_0;
    if ((err = call SDread.read(0, buff)))
      nop();
  }


  event void SDread.readDone(uint32_t blk_id, void *buf, error_t error) {
    uint16_t i;
    uint8_t *d;

    switch (sd_arb_state) {
      case SDArb_0:
	sd_arb_state = SDArb_1;
	call SDread.read(0x5000, buff);
	return;

      case SDArb_1:
	d = buf;
	for (i = 0; i < 512; i++)
	  d[i] = i + 1;

	call SDwrite.write(0x5000, buf);
	return;

      default:
      case SDArb_2:
	call Resource.release();
	return;
    }
  }


  event void SDwrite.writeDone(uint32_t blk_id, void *buf, error_t error) {
    uint16_t i;
    uint8_t *d;

    d = buf;
    for (i = 0; i < 512; i++)
      d[i] = 0;
    sd_arb_state = SDArb_2;
    call SDread.read(0x5000, buf);
    return;
  }


  event void FS_OutBoot.booted() {
    nop();
  }

}
