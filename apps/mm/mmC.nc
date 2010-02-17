/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "regime.h"
#include "panic.h"

/*
 * 1 min * 60 sec/min * 1024 ticks/sec  (binary millisecs, mis)
 */
#define SYNC_PERIOD (1UL * 60 * 1024)

//noinit uint8_t use_regime;
//uint8_t use_regime = 14;
uint8_t use_regime = 2;

module mmC {
  uses {
    interface Regime;
    interface Leds;
    interface Boot;
    interface Panic;
    interface Collect;
    interface StreamStorageFull;

    interface Adc;

    interface StreamStorageRead as SSR;
#ifdef notdef
    interface HplMMAdc as HW;
#endif
  }
}

implementation {
  uint8_t temp_buf[512];

  event void Boot.booted() {

#ifdef TEST_READER
    call SSR.read_block(0, temp_buf);
#endif

    /*
     * set the initial regime.  This will also
     * signal all the sensors and start them off.
     */
//    call Regime.setRegime(SNS_DEFAULT_REGIME);
    if (use_regime > SNS_MAX_REGIME)
      use_regime = SNS_DEFAULT_REGIME;
    call Regime.setRegime(use_regime);

//    call Leds.led0Off();
//    call Leds.led1Off();
//    call Leds.led2Off();

#ifdef notdef
    call HW.vdiff_on();
    call HW.vref_on();
    call HW.accel_on();
    call HW.set_smux(SMUX_ACCEL_X);
    uwait(1000);
    while(1) {
      uint16_t i;

      for (i = 0; i < NUM_RES; i++)
	res[i] = call Adc.readAdc();
      nop();
    }
#endif

  }

  event void SSR.read_block_done(uint32_t blk, uint8_t *buf, error_t err) {
    use_regime++;
    use_regime--;
  }

  event void StreamStorageFull.dblk_stream_full () {
    call Regime.setRegime(SNS_ALL_OFF_REGIME);
  }

  event void Adc.configured() {
    call Panic.panic(PANIC_MISC, 1, 0, 0, 0, 0);
  }

  event void Regime.regimeChange() {} // do nothing.  that's okay.
}
