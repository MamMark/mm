/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 *
 * adc7685.h - Analog/Digital converter interface
 *
 * Modified to interface to the SPI via the usci/Hpl routines
 *
 * Analog Devices AD7685.
 *
 * The ADC interface consists of 5 pins.
 *
 * P/I    = port function, input.
 * P/O    = port function, output.
 * SPI0/O = assigned to SPI0 as an output.
 * SPI0/I = SPI0 input.
 *
 * P2.6    CNV	(P/O).  Convert.  low to high starts the conversion
 *			Also other functions (see the data sheet).
 *
 * P2.7    CNV_complete  (P/I) (same as SOMI0) normally high (when SDO is high-Z)
 *			but goes low when a conversion completes (.7 to 3.2 us)
 *
 * P3.2    SOMI0	(SPI0/I) output from the ADC to the SPI module.  data clocks on
 *			falling edge of SCK.
 *
 * P3.3    SCK	(P/O and SPI0/O) clock to the ADC.  Initially configured as P/O so the
 *			start bit can be clocked out.  Then switched to SPI0/O
 *			and the SPI runs the rest of the data (16 bits).
 *
 * P3.5    SDI	(P/O, set to 1) set high and left there.  Controls ADC mode (selected on
 *			rising edge of CNV.
 *
 * Interfaces using HplMsp430UsciXXC routines.  Wiring in AdcC determines which
 * port.  The ADC assumes sole ownership of the underlying port and h/w associated with
 * it.  No arbritration is done.
 */

#include "hardware.h"
#include "sensors.h"


#ifdef notdef
/*
 * Originally we initilized the spi ourselves including what we wanted
 * to use as the divider.  Now we use the Hpl interface and its default
 * which uses smclk/2.  If we want to use something else then we should
 * use our own initilization structure.
 */

/*
 * Fix me.  This can go down to 2.  check it out later.
 */
#define ADC_DIV 4
#endif

/*
 * ADC_SPI_MAX_WAIT is the number of microsecs that the
 * readAdc code will wait looking for bytes that should
 * be coming from the ADC.  We dont want to lock up and
 * stop things from working.
 *
 * Initially we panic.  But this will be replaced by making
 * the code recover.
 */

#define ADC_SPI_MAX_WAIT 100

  volatile uint16_t num_reads;
  int8_t ifg2[5];

module AdcP {
  provides {
    interface Adc as AdcClient[uint8_t client_id];
    interface Init;
  }
  uses {
    interface AdcConfigure<const mm_sensor_config_t*> as Config[uint8_t client_id];
    interface StdControl as SensorPowerControl[uint8_t id];
    interface ResourceQueue as Queue;
    interface Hpl_MM_hw as HW;
    interface Alarm<T32khz, uint16_t> as PowerAlarm;
    interface Panic;
    interface HplMsp430UsciB as Usci;
    interface HplMsp430UsciInterrupts as UsciInterrupts;
  }
}

implementation {

  enum { ADC_POWERING_DOWN = 0x10,
         ADC_IDLE,
	 ADC_GRANTING,
	 ADC_POWER_WAIT,
	 ADC_BUSY,
  };
  enum { VREF_POWERING_OFF = 0x20,
         VREF_OFF,
	 VREF_POWER_WAIT,
	 VREF_ON
  };
  enum { VDIFF_POWERING_OFF = 0x30,
         VDIFF_OFF,
	 VDIFF_POWER_SWING,     /* swinging but with powerup delay */
         VDIFF_SWING,           /* going to midpoint with swing delay */
         VDIFF_SETTLING,        /* set to diff sensor, wait to settle */
	 VDIFF_ON
  };

  uint8_t adc_owner;
  uint8_t req_client;
  uint8_t adc_state;
  uint8_t vref_state;
  uint8_t vdiff_state;
  const mm_sensor_config_t *m_config;


  /*
   * Adc Initilization.  (See above for pin definitions).
   *
   * Put the ADC into the initial state.  The ADC subsystem should
   * always be in this state prior to a conversion.
   *
   * According to the data sheet, if conversion data isn't available then
   * SDO will be in high-Z.  CNV_cmplt should be a 1.  but we only look
   * at it after we start a conversion.  If interrupts are being used
   * they should not be enabled until after a conversion is started.
   * CNV_cmplt should then be a 1 and the interrupt is generated when
   * CNV_cmplt goes low.
   *
   * But this cpu is too slow to use this mode.
   *
   * o CNV low.
   *
   * o ADC_SDI (as seen at the ADC) high.  This stays high and isn't changed.
   *
   * o ADC_SCK low.  Also ADC_SCK is initially assigned to the port rather
   *   than the SPI module.  After a conversion is completed, the first
   *   thing we want to do is clock out the start bit.  Then we hand
   *   ADC_SCK back over to the SPI and let it do its thing.
   *
   * o SOMI0 (SDO) is assigned to the SPI.
   *
   * o The SPI0 module is initialized and left running, it is idle.
   *
   * Does it make sense to keep the spi h/w in reset and only let it run
   * when we want to do a conversion.  Initilization of the spi consists
   * of register writes and takes only the time for those instructions.
   * What state does the spi put itself in, ie. does it consume power
   * if it isn't doing anything?
   */

  void init_adc_hw() {
    /*
     * set ADC_CNV to 0.  Dir and FuncSel are set once by platform init
     * ADC_SDO, ADC_CLK assigned dir and sel by platform init.
     */
    ADC_CNV = 0;

    /*
     * The default Hpl SPI configuration set the spi up for
     * smclk/2, 3pin, no ste, master, 8 bit, msb first.
     *
     * On return, interrupts for the spi will be off and the device
     * will be running (taken out of reset).
     */
    call Usci.setModeSpi((msp430_spi_union_config_t *) &msp430_spi_default_config);
  }


  command error_t Init.init() {
    adc_owner  = SNS_ID_NONE;
    req_client = SNS_ID_NONE;
    adc_state  = ADC_IDLE;
    vref_state = VREF_OFF;
    vdiff_state = VDIFF_OFF;
    m_config = NULL;
    call HW.vref_off();
    call HW.vdiff_off();
    init_adc_hw();
    return SUCCESS;
  }


  /*
   * adcPower_Up_Down
   *
   * Handle powering up or down the ADC and a sensor as
   * requested.
   *
   * Granting (Powering up).  Figure out what needs to be
   * powered on and what delay is needed before signalling
   * the sensor driver that it can commence reading.
   *
   * Turn on Vref
   * Turn on Vdiff.  Also set the dmux and gmux to slew
   *   the differential system.  (If vdiff also set smux
   *   to SMUX_DIFF).
   * Power up the sensor and use sensor powerup delay if larger.
   *   Set smux appropriately (for the single ended sensor
   *   or SMUX_DIFF if differential).
   *
   * Note.  After Vdiff is swung another settling time is
   * needed after setting Dmux/Gmux to the proper values.
   *
   * Power Down.  Pretty straight forward but does need to
   * check for any requests that might have been queued up
   * while we were waiting for the task to run.
   */
  task void adcPower_Up_Down() {
    uint16_t delay;
    const mm_sensor_config_t *config;

    if (adc_state != ADC_POWERING_DOWN && adc_state != ADC_GRANTING) {
      call Panic.panic(PANIC_ADC, 1, adc_state, 0, 0, 0);
    }

    if (adc_state == ADC_POWERING_DOWN) {
      if (call Queue.isEmpty()) {
        /*
         * since queue is empty we can safely power down
         */
        vref_state = VREF_OFF;
        vdiff_state = VDIFF_OFF;
        call HW.vref_off();
        call HW.vdiff_off(); 
	adc_state = ADC_IDLE;
	adc_owner = SNS_ID_NONE;
	m_config = NULL;
        return;
      } else {
        /*
         * queue not empty.  So pull first entry and
         * feed it as if granted.  This could happen
         * if timing works out that the release happens
         * just before an expired timer runs and makes
         * the request.
         */
        req_client = call Queue.dequeue();
        adc_state = ADC_GRANTING;
      }
    }

    if (adc_state == ADC_GRANTING) {
      if (!req_client || req_client >= MM_NUM_SENSORS) {
	call Panic.panic(PANIC_ADC, 2, req_client, 0, 0, 0);
      }

      adc_owner = req_client;
      adc_state = ADC_POWER_WAIT;
      m_config = config = call Config.getConfiguration[adc_owner]();

      /*
       * Vref and Vdiff power state should either
       * be off or on.  Shouldn't ever get into adcPower_Up_Down
       * with either Vref_state or Vdiff_state being POWERING.
       * Might want to check for that at some point.
       */

      delay = 0;

      /*
       * All sensors need Vref unless it is already on.
       */
      switch(vref_state) {
	default:
	  call Panic.panic(PANIC_ADC, 3, vref_state, 0, 0, 0);
	  vref_state = VREF_ON;
	  /*
	   * fall through
	   */
	case VREF_ON:
          break;

	case VREF_OFF:
          call HW.vref_on();
          vref_state = VREF_POWER_WAIT;
          delay = VREF_POWERUP_DELAY;
          break;
      }

      if (adc_owner < SNS_DIFF_START) {
        /*
         * single ended.  Set smux to appropriate
         * value.  Always turn Vdiff off.
         *
         * Need to get sensor power up delay.  Pick
         * the longest of the potentially three values
         * and delay for that amount of time.
         */
        call HW.set_smux(config->mux);
        call HW.vdiff_off();
	vdiff_state = VDIFF_OFF;
        if (config->t_settle > delay)
          delay = config->t_settle;
      } else {
        /*
         * Differential.  Must power up or swing the amps
         *
	 * If the sensor is a differential then make
	 * sure Vdiff is on as well.  We could be
	 * powering the sensor up or just swinging it
	 * from a previous setting.  Different timing
	 * could be used.
	 *
         * sensor delay for diff sensors is handled
         * in PowerAlarm code after swing.
         */
	switch(vdiff_state) {
	  default:
	    /*
	     * bad state.  bitch bitch bitch
	     * then fall through
	     */
	  case VDIFF_OFF:
            /*
             * If powering up, use a different delay.
             * VDIFF_POWER_SWING and VDIFF_SWING could
             * be combined.  But this way we can see when
             * the different behaviours are invoked.
             */
            vdiff_state = VDIFF_POWER_SWING;
            if (VDIFF_POWERUP_DELAY > delay)
              delay = VDIFF_POWERUP_DELAY;
            break;

	  case VDIFF_ON:
            /*
             * already on.  Swing the diff system back to
             * midline.  Use different delay for the
             * swing wrt powering up.
             */
            vdiff_state = VDIFF_SWING;
            if (VDIFF_SWING_DELAY > delay)
              delay = VDIFF_SWING_DELAY;
            break;
	}
        call HW.vdiff_on();
        call HW.set_smux(SMUX_DIFF);
        call HW.set_dmux(VDIFF_SWING_DMUX);
        call HW.set_gmux(VDIFF_SWING_GAIN);
      }

      call SensorPowerControl.start[adc_owner]();
      call PowerAlarm.start(delay);
      return;
    }

    /*
     * shouldn't have gotten here.  be paranoid.
     */

    /* bitch bitch bitch */
  }


  /*
   * Possible two step process.  If Vdiff is being
   * used, we first power it up (or swing it).  Then
   * we have to switch to the actual gain and dmux
   * setting and let the whole thing settle.
   */
  task void PowerAlarm_task() {
    const mm_sensor_config_t *config;

    if (vref_state == VREF_POWER_WAIT)
      vref_state = VREF_ON;
    if (vdiff_state == VDIFF_SETTLING)
      vdiff_state = VDIFF_ON;
    else if (vdiff_state == VDIFF_POWER_SWING ||
        vdiff_state == VDIFF_SWING) {
      /*
       * swinging finished.  set to correct dmux and gain for
       * the actual sensor path and allow the diff system to
       * settle.  Smux has already been set to SMUX_DMUX earlier.
       */
      config = m_config;
      call HW.set_dmux(config->mux);
      call HW.set_gmux(config->gmux);
      vdiff_state = VDIFF_SETTLING;
      call PowerAlarm.start(config->t_settle);
      return;
    }
    adc_state = ADC_BUSY;
    signal AdcClient.configured[adc_owner]();
  }


  async event void PowerAlarm.fired() {
    post PowerAlarm_task();
  }


  /*
   * reqConfigure
   *
   * This is the only mechanism for a sensor driver to request
   * access to the ADC.  It arbitrates access and when granted
   * sets up the requested configuration.  This configuration is
   * obtained by an upcall via Adc.Configure.
   */
  command error_t AdcClient.reqConfigure[uint8_t client_id]() {
    error_t rtn;

    atomic {
      if (adc_state == ADC_IDLE) {
	if (call Queue.isEmpty() == FALSE) {
	  /*
	   * Queue should be empty when ADC is IDLE
	   * bitch bitch bitch
	   */
	  call Panic.panic(PANIC_ADC, 4, adc_state, 0, 0, 0);
	}

	/*
	 * since we know the queue is empty.  The enqueue
	 * can never fail.
	 *
	 * We enqueue the client first.  Then immediately pull it back
	 * off.  We insist on running everything through the queue to
	 * make sure the round robin order is honored.  This effects what
	 * order following enqueues get pulled.  Basically, it updates last.
	 *
	 * FIXME.  Check out this enqueue/dequeue thing.
	 */
	call Queue.enqueue(client_id);
	req_client = call Queue.dequeue();
	adc_state = ADC_GRANTING;
	req_client = client_id;
      } else {
        rtn = call Queue.enqueue(client_id);
	if (rtn == SUCCESS) {
	  /*
	   * success is cool.  ebusy says we are already in the queue.
	   * Shouldn't happen.  So only success should get through.
	   */
	  return rtn;
	}
	/*
	 * weird error. * bitch bitch bitch
	 */
	call Panic.warn(PANIC_ADC, 5, rtn, 0, 0, 0);
	return rtn;
      }
    }
    post adcPower_Up_Down();
    return SUCCESS;
  }


  command void AdcClient.reconfigure[uint8_t client_id](const mm_sensor_config_t *config) {
    uint16_t delay;

    if (adc_owner != client_id || adc_state != ADC_BUSY) {
      /*
       * bitch.  shouldn't be calling
       */
      call Panic.panic(PANIC_ADC, 6, adc_owner, client_id, adc_state, 0);
      return;
    }
    m_config = config;
    delay = 0;
    if (client_id < SNS_DIFF_START)
      call HW.set_smux(config->mux);
    else {
      if (vdiff_state == VDIFF_ON) {
	vdiff_state = VDIFF_SWING;
	delay = VDIFF_SWING_DELAY;
      } else {
	vdiff_state = VDIFF_POWER_SWING;
	delay = VDIFF_POWERUP_DELAY;
      }
      call HW.vdiff_on();
      call HW.set_smux(SMUX_DIFF);
      call HW.set_dmux(VDIFF_SWING_DMUX);
      call HW.set_gmux(VDIFF_SWING_GAIN);
    }
    if (config->t_settle > delay)
      delay = config->t_settle;
    call SensorPowerControl.start[adc_owner]();
    call PowerAlarm.start(delay);
    return;
  }


  command error_t AdcClient.release[uint8_t client_id]() {
    /*
     * if not the owner, its something weird.  bitch
     * could be a regime change so don't what to do anything
     * too weird.  But the clients really should check before
     * releasing.
     */
    if (adc_owner != client_id || adc_state != ADC_BUSY) {
      /*
       * bitch bitch bitch
       */
      call Panic.panic(PANIC_ADC, 7, adc_owner, client_id, adc_state, 0);
      return FAIL;
    }

    call SensorPowerControl.stop[client_id]();
    adc_owner = SNS_ID_NONE;
    if (call Queue.isEmpty())
      adc_state = ADC_POWERING_DOWN;
    else {
      req_client = call Queue.dequeue();
      adc_state = ADC_GRANTING;
    }
    post adcPower_Up_Down();
    return SUCCESS;
  }


  command bool AdcClient.isOwner[uint8_t client_id]() {
    return (adc_owner == client_id);
  }


  /*
   * readAdc
   *
   * put the external ADC through its paces.
   *
   * uses HplMspUsciB interfacee to access the spi.
   */

  command uint16_t AdcClient.readAdc[uint8_t client_id]() {
    uint16_t result;
    uint16_t t0;

    ifg2[0] = IFG2;
    result = 0;
    /*
     * first do a sanity check.  If (tx is busy, not empty) or
     * (rx has a chr, should be empty) or (hw thinks its busy)
     * then panic.
     */
    if (  (call Usci.isTxIntrPending() == 0) ||
	  (call Usci.isRxIntrPending()) ||
	  (call Usci.isBusy())) {
      /*
       * no space in transmitter (huh?)
       * receiver not empty
       * transmitter should be completely empty
       *
       * bitch bitch bitch and reset the h/w.
       */
      call Panic.warn(PANIC_ADC, 8, IFG2, UCB0STAT, 0, 0);
      init_adc_hw();
    }

    ADC_CNV = 1;			/* launch a conversion */
//    TELL = 1;
    for (result = 0; result < 3; result++) {
      nop();
    }
//    TELL = 0;
    ADC_CNV = 0;

    /*
     * go get the data via the SPI.  Send to receive
     * send first byte to receive 1st byte.
     */

    call Usci.tx(0x1a);		/* data doesn't matter */
    ifg2[1] = IFG2;
    t0 = TAR;
    while (1) {
      if (call Usci.isRxIntrPending())
	break;
      if ((TAR - t0) > ADC_SPI_MAX_WAIT) {
	/*
	 * FIXME.  we choke.  Figure out why.
	 */
//	call Panic.warn(PANIC_ADC, 9, 1, IFG2, TAR, t0);
//	break;
      }
    }
    result = ((uint16_t) call Usci.rx()) << 8;

    ifg2[2] = IFG2;
    if (call Usci.isTxIntrPending() == 0) { /* space to send? */
      /* FIXME
       * no space to send.  that's strange, panic/warn
       */
//      call Panic.warn(PANIC_ADC, 9, 2, IFG2, 0, 0);
    }

    /*
     * send 2nd and wait for the rx to come back
     */
    call Usci.tx(0x25);		/* send next to get next */
    t0 = TAR;
    while (1) {
      if (call Usci.isRxIntrPending())
	break;
      if ((TAR - t0) > ADC_SPI_MAX_WAIT) {
	/*
	 * FIXME.  we choke.  Figure out why.
	 */
//	call Panic.warn(PANIC_ADC, 9, 3, IFG2, 0, 0);
//	break;
      }
    }
    result |= ((uint16_t) call Usci.rx());

    /*
     * Transmitter and Recevier should both be empty
     */
    ifg2[3] = IFG2;
    ifg2[4] = UCB0STAT;
    if (  (call Usci.isTxIntrPending() == 0) ||
	  (call Usci.isRxIntrPending()) ||
	  (call Usci.isBusy())) {
      /* FIXME */
//      call Panic.warn(PANIC_ADC, 10, IFG2, UCB0STAT, 0, 0);
    }
    return(result);
  }

  async event void UsciInterrupts.txDone() {
    /*
     * shouldn't ever get here, we never turn intrrupts on for the ADC spi
     *
     * eventually put a panic in here.
     */
  };

  async event void UsciInterrupts.rxDone(uint8_t data) {
    /*
     * shouldn't ever get here, we never turn intrrupts on for the ADC spi
     *
     * eventually put a panic in here.
     */
  };


  default event void AdcClient.configured[uint8_t id]() {} // fix me.  add call to panic

  const mm_sensor_config_t defaultConfig = {SNS_ID_NONE, 0, 0, 0};

  default async command const mm_sensor_config_t *Config.getConfiguration[uint8_t id]() { 
      return &defaultConfig;
  }

  default command error_t SensorPowerControl.start[uint8_t id]() { return SUCCESS; } // fix me.  panic

  default command error_t SensorPowerControl.stop[uint8_t id]() { return SUCCESS; } //  fix me.  panic
}
