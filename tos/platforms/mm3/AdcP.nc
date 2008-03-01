/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "hardware.h"
#include "sensors.h"


module AdcP {
  provides {
    interface Adc as AdcClient[uint8_t client_id];
    interface Init;
  }
  uses {
    interface AdcConfigure<const mm3_sensor_config_t*> as Config[uint8_t client_id];
    interface StdControl as SensorPowerControl[uint8_t id];
    interface ResourceQueue as Queue;
    interface HplMM3Adc as HW;
#ifdef USE_TIMERS
    interface Timer<TMilli> as PowerTimer;
#else
    interface Alarm<T32khz, uint16_t> as PowerAlarm;
#endif
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
  const mm3_sensor_config_t *m_config;
  uint16_t value;

  command error_t Init.init() {
    value = 0;
    adc_owner  = SNS_ID_NONE;
    req_client = SNS_ID_NONE;
    adc_state  = ADC_IDLE;
    vref_state = VREF_OFF;
    vdiff_state = VDIFF_OFF;
    m_config = NULL;
    call HW.power_vref(VREF_TURN_OFF);
    call HW.power_vdiff(VDIFF_TURN_OFF);
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
    const mm3_sensor_config_t *config;

    if (adc_state != ADC_POWERING_DOWN &&
        adc_state != ADC_GRANTING) {
      /*
       * not what we expected.  bitch.  Shouldn't be here.
       */
    }

    if (adc_state == ADC_POWERING_DOWN) {
      if (call Queue.isEmpty()) {
        /*
         * since queue is empty we can safely power down
         */
        vref_state = VREF_OFF;
        vdiff_state = VDIFF_OFF;
        call HW.power_vref(VREF_TURN_OFF);
        call HW.power_vdiff(VDIFF_TURN_OFF); 
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
      if (!req_client || req_client >= MM3_NUM_SENSORS) {
        /*
         * bad, bad sensor.  bitch
         */
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
      do {
        if (vref_state == VREF_ON)
          break;
        if (vref_state == VREF_OFF) {
          call HW.power_vref(VREF_TURN_ON);
          vref_state = VREF_POWER_WAIT;
          delay = VREF_POWERUP_DELAY;
          break;
        }
        /*
         * bad state.  bitch
         */
      } while(0);

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
        call HW.power_vdiff(VDIFF_TURN_OFF);
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
        do {
          if (vdiff_state == VDIFF_OFF) {
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
          }
          if (vdiff_state == VDIFF_ON) {
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
          /*
           * bad state.  bitch
           */
        } while(0);
        call HW.power_vdiff(VDIFF_TURN_ON);
        call HW.set_smux(SMUX_DIFF);
        call HW.set_dmux(VDIFF_SWING_DMUX);
        call HW.set_gmux(VDIFF_SWING_GAIN);
      }

      call SensorPowerControl.start[adc_owner]();
#ifdef USE_TIMERS
      call PowerTimer.startOneShot(delay);
#else
      call PowerAlarm.start(delay);
#endif
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
    const mm3_sensor_config_t *config;

    if (vref_state == VREF_POWER_WAIT)
      vref_state = VREF_ON;
    if (vdiff_state == VDIFF_SETTLING)
      vdiff_state = VDIFF_ON;
    if (vdiff_state == VDIFF_POWER_SWING ||
        vdiff_state == VDIFF_SWING) {
      /*
       * swinging finished.  set to correct dmux and gain for
       * the actual sensor path and allow the diff system to
       * settle.  Smux has already been set to SMUX_DMUX earlier.
       */
//      config = m_config;
      m_config = config = call Config.getConfiguration[adc_owner]();
      call HW.set_dmux(config->mux);
      call HW.set_gmux(config->gmux);
      vdiff_state = VDIFF_SETTLING;
#ifdef USE_TIMERS
      call PowerTimer.startOneShot(config->t_settle);
#else
      call PowerAlarm.start(config->t_settle);
#endif
      return;
    }
    adc_state = ADC_BUSY;
    signal AdcClient.configured[adc_owner]();
  }


#ifdef USE_TIMERS
  event void PowerTimer.fired() {
#else
  async event void PowerAlarm.fired() {
#endif
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
	adc_state = ADC_GRANTING;
	req_client = client_id;
      } else {
        rtn = call Queue.enqueue(client_id);
        if (rtn != SUCCESS) {
          /* check for ebusy.  shouldn't happen */
        }
	return rtn;
      }
    }
    post adcPower_Up_Down();
    return SUCCESS;
  }


  command void AdcClient.reconfigure[uint8_t client_id](const mm3_sensor_config_t *config) {
    uint16_t delay;

    if (adc_owner != client_id || adc_state != ADC_BUSY) {
      /*
       * bitch.  shouldn't be calling
       */
      return;
    }
    m_config = config = call Config.getConfiguration[adc_owner]();
//    m_config = config;
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
      call HW.power_vdiff(VDIFF_TURN_ON);
      call HW.set_smux(SMUX_DIFF);
      call HW.set_dmux(VDIFF_SWING_DMUX);
      call HW.set_gmux(VDIFF_SWING_GAIN);
    }
    if (config->t_settle > delay)
      delay = config->t_settle;
    call SensorPowerControl.start[adc_owner]();
#ifdef USE_TIMERS
    call PowerTimer.startOneShot(delay);
#else
    call PowerAlarm.start(delay);
#endif
    return;
  }


  command error_t AdcClient.release[uint8_t client_id]() {
    /*
     * if not the owner, its something weird.  bitch
     * could be a regime change so don't what to do anything
     * to weird.  But the clients really should check before
     * releasing.
     */
    if (adc_owner != client_id || adc_state != ADC_BUSY) {
      /*
       * bitch bitch bitch
       */
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


  command uint16_t AdcClient.readAdc[uint8_t client_id]() {
    return ++value;
  }


  default event void AdcClient.configured[uint8_t id]() {}

  const mm3_sensor_config_t defaultConfig = {SNS_ID_NONE, 0, 0, 0};
  default async command const mm3_sensor_config_t *
    Config.getConfiguration[uint8_t id]() { 
      return &defaultConfig;
  }
  default command error_t SensorPowerControl.start[uint8_t id]() { return SUCCESS; }
  default command error_t SensorPowerControl.stop[uint8_t id]() { return SUCCESS; }
}
