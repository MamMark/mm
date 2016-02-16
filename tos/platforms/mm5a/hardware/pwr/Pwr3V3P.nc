/*
 * Pwr3V3 - control 3V3 regulator
 */

module Pwr3V3P {
  provides interface PwrReg;
  uses interface GeneralIO as Pwr3V3Enable;

  /* Timer to wait for Vout rise delay */
  uses interface Timer<TMilli> as VoutTimer;
}
implementation {

/*
 * tps78233 output rise delay in msec
 * 10ms to allow chips to boot.  Probably should
 * be done differently.  ie.  time for Vout to
 * stablize and additional time for a chip to boot.
 *
 * Do all mems chips
 */
#define PWR3V3_VOUT_RISETIME 10

  typedef enum {
    P3V3_OFF = 0,
    P3V3_STARTING,
    P3V3_ON,
  } pwr3v3_state_t;

  pwr3v3_state_t m_pwr3v3_state;
  
  /* provision for up to 255 users */
  uint8_t m_refcount;

  command error_t PwrReg.pwrReq() {
    m_refcount++;
    if (m_pwr3v3_state == P3V3_ON) {
      return EALREADY;
    }
    if (m_pwr3v3_state == P3V3_OFF) {
      m_pwr3v3_state = P3V3_STARTING;
      call Pwr3V3Enable.set();
      call VoutTimer.startOneShot(PWR3V3_VOUT_RISETIME);
    }
    return SUCCESS;
  }


  command void PwrReg.pwrRel() {
    if (m_refcount)
      m_refcount--;

    if (m_refcount == 0) {
      m_pwr3v3_state = P3V3_OFF;
      call Pwr3V3Enable.clr();
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
