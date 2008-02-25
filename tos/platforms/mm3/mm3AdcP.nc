/* -*- mode:c; indent-tabs-mode:nil; c-basic-offset: 2 -*-
 *
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 *
 * Based loosely on ArbiterP.nc (Kevin Klues & Phil Levis)
 * Copyright (c) 2004, Technische Universitat Berlin
 * All rights reserved.
 */

#include "hardware.h"
#include "sensors.h"


module mm3AdcP {
  provides {
    interface mm3Adc as AdcClient[uint8_t client_id];
    interface Init;
  }
  uses {
    interface AdcConfigure<const mm3_sensor_config_t*> as Config[uint8_t client_id];
    interface ResourceQueue as Queue;
    interface HplMM3Adc as HW;
    interface Timer<TMilli> as PowerTimer;
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

  command error_t Init.init() {
    adc_owner  = SNS_ID_NONE;
    req_client = SNS_ID_NONE;
    adc_state  = ADC_IDLE;
    vref_state = VREF_OFF;
    vdiff_state = VDIFF_OFF;
    call PowerTimer.stop();	/* if still running make sure off */
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
    uint32_t delay;
    const mm3_sensor_config_t *config;

    if (adc_state != ADC_POWERING_DOWN &&
        adc_state != ADC_GRANTING) {
      /*
       * not what we expected.  bitch
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
      if (!req_client || req_client >= SENSOR_SENTINEL) {
        /*
         * bad, bad sensor.  bitch
         */
      }

      adc_owner = req_client;
      adc_state = ADC_POWER_WAIT;
      config = call Config.getConfiguration[adc_owner]();

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

      /*
       * If the sensor is a differential then make
       * sure Vdiff is on as well.  We could be
       * powering the sensor up or just swinging it
       * from a previous setting.  Different timing
       * could be used.
       */
      if (adc_owner < SNS_DIFF_START) {
        /*
         * single ended.  Set smux to appropriate
         * value.  Turn Vdiff off if appropriate.
         *
         * Need to get sensor power up delay.  Pick
         * the longest of the potentially three values
         * and delay for that amount of time.
         *
         * sensor delay for diff sensors is handled
         * in PowerTimer code after swing.
         *
         * Do we need uSec granularity?  Probably.
         */
        call HW.set_smux(config->mux);
        if (config->t_powerup > delay)
          delay = config->t_powerup;
      } else {
        /*
         * Differential.  Must power up or swing the amps
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

      call HW.power_up_sensor(adc_owner, 0);
      call PowerTimer.startOneShot(delay);
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
  event void PowerTimer.fired() {
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
      config = call Config.getConfiguration[adc_owner]();
      call HW.set_dmux(config->mux);
      call HW.set_gmux(config->gmux);
      vdiff_state = VDIFF_SETTLING;
      call PowerTimer.startOneShot(config->t_powerup);
      return;
    }
    adc_state = ADC_BUSY;
    signal AdcClient.granted[adc_owner]();
  }


  command error_t AdcClient.request[uint8_t client_id]() {
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

  command error_t AdcClient.release[uint8_t client_id]() {
    /*
     * if not the owner, its something weird.  bitch
     */
    if (adc_owner != client_id) {
      /*
       * bitch bitch bitch
       */
    }

    call HW.power_down_sensor(client_id, 0);
    atomic {
      if (adc_state == ADC_BUSY && adc_owner == client_id) {
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
    }
    return FAIL;
  }

//  command bool AdcClient.isOwner[uint8_t client_id]() {
//    return FALSE;
//  }

  command uint16_t AdcClient.readAdc[uint8_t client_id]() {
    return 0;
  }

  default event void AdcClient.granted[uint8_t id]() {}

  const mm3_sensor_config_t defaultConfig = {SNS_ID_NONE, 0, 0, 0, 0};
  default async command const mm3_sensor_config_t *
    Config.getConfiguration[uint8_t id]() { 
      return &defaultConfig;
  }
}
