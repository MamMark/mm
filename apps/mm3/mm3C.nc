/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "regime.h"
#include "panic.h"

#include "stream_storage.h"

#ifdef notdef
#define NUM_RES 16
uint16_t res[NUM_RES];
#endif

uint8_t use_regime = 2;

#ifdef notdef
#define SSIZE 1024
uint8_t sbuf[SSIZE];
uint32_t start_t0;
uint32_t end_time;
uint32_t diff;
#endif

module mm3C {
  provides {
    interface Init;
  }
  uses {
    interface Regime;
    interface Leds;
    interface Boot;
    interface Panic;

    interface HplMM3Adc as HW;
    interface Adc;

#ifdef USE_SD
    interface HplMsp430Usart as Usart;
    interface StreamStorage as SS;
#endif

//    interface StdControl as GPSControl;
    interface LocalTime<TMilli>;
  }
}

implementation {
  uint8_t dbuf[SS_BLOCK_SIZE + 2];

#ifdef USE_SD
  msp430_spi_union_config_t config = {
    {
      ubr : 0x0002,
      ssel : 0x02,
      clen : 1,
      listen : 0,
      mm : 1,
      ckph : 1,
      ckpl : 0,
      stc : 1
    }
  };
#endif

  command error_t Init.init() {
//    call Panic.brk();
    return SUCCESS;
  }


  event void Boot.booted() {
#ifdef notdef
    uint16_t i;
    bool timing;

    IE2 = 0;
    timing = 1;
    mmP5out.ser_sel = SER_SEL_GPS;
    start_t0 = call LocalTime.get();
    call HW.gps_on();
//    uwait(1000);
    for (i = 0; i < SSIZE; i++) {
      while ((IFG2 & URXIFG1) == 0) ;
      sbuf[i] = U1RXBUF;
      if (timing) {
	timing = 0;
	end_time = call LocalTime.get();
	diff = end_time - start_t0;
      }
    }
    call HW.gps_off();
    mmP5out.ser_sel = SER_SEL_CRADLE;
    i = U1RXBUF;
    nop();
#endif

    /*
     * set the initial regime.  This will also
     * signal all the sensors and start them off.
     */
//    call Regime.setRegime(SNS_DEFAULT_REGIME);
    if (use_regime == 0 || use_regime > SNS_MAX_REGIME)
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

#ifdef notdef
    call GPSControl.start();
    uwait(1000);
    call GPSControl.stop();
#endif

#ifdef USE_SD
    call HW.sd_on();
    call Usart.setModeSpi(&config);
    call SD.reset();
    call SD.read_nodma(0, dbuf);
#endif
  }

#ifdef USE_SD
#endif

  event void Adc.configured() {
    call Panic.panic(PANIC_MISC, 1, 0, 0, 0, 0);
  }

  event void Regime.regimeChange() {} // do nothing.  that's okay.
}
