/*
 * Pwr3V3 - control 3V3 regulator
 */

module Pwr3V3P {
  provides interface PwrReg;
  uses interface Leds as Enable;

  /* Timer to wait for Vout rise delay */
  uses interface Timer<TMilli> as VoutTimer;
}
implementation {
  typedef enum {
    P3V3_OFF = 0,
    P3V3_STARTING,
    P3V3_ON,
  } pwr3v3_state_t;

  pwr3v3_state_t m_pwr3v3_state;
  
  /* provision for up to 255 users */
  uint8_t m_refcount;

  command error_t PwrReg.pwrReq() {
    nop();
    nop();
    nop();
    m_refcount++;
    if (m_pwr3v3_state == P3V3_ON) {
      return EALREADY;
    }
    if (m_pwr3v3_state == P3V3_OFF) {
      m_pwr3v3_state = P3V3_STARTING;

      /*
       * turn led0 on to simulate enabling regulator
       * start a timer equal to Vout rise time delay
       */
      call Enable.led0On();
      call VoutTimer.startOneShot(3000);
    }
    return SUCCESS;
  }


  command void PwrReg.pwrRel() {
    if (m_refcount)
      m_refcount--;

    if (m_refcount == 0) {
      m_pwr3v3_state = P3V3_OFF;
      call Enable.led1Off();
      call VoutTimer.stop();
    }
  }


  event void VoutTimer.fired() {
    nop();
    nop();
    nop();
    if (m_pwr3v3_state == P3V3_STARTING) {
      m_pwr3v3_state = P3V3_ON;
      signal PwrReg.pwrAvail();
    }
  }
}
