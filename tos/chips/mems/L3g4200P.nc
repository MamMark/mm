module L3g4200P {
  provides interface Init;
  provides interface SplitControl;
  provides interface L3g4200;
  //provides interface Msp430UsciConfigure;

  uses interface Resource as SpiResource;
  //uses interface SpiBlock as SpiBlock;
  uses interface SpiByte as SpiByte;
  uses interface HplMsp430GeneralIO as CS;
  uses interface PwrReg;
}

#include "l3g4200.h"

implementation {
  typedef enum {
    GYRO_IDLE = 0,
    GYRO_STOPPING,
    GYRO_PWR_REQ,
    GYRO_PWR_ON,
    GYRO_RES_REQ,
    GYRO_ACTIVE,
  } gyro_state_t;

  gyro_state_t m_gyro_state;

  command error_t Init.init() {
    call CS.set();
    call CS.makeOutput();
    return SUCCESS;
  }

  command error_t SplitControl.start() {
    if (m_gyro_state <= GYRO_STOPPING) {
      error_t pwr_status = call PwrReg.pwrReq();
      if (pwr_status == EALREADY)
	m_gyro_state = GYRO_PWR_ON;
      else
	m_gyro_state = GYRO_PWR_REQ;
    }
    if (m_gyro_state == GYRO_PWR_ON) {
      m_gyro_state = GYRO_RES_REQ;
      return call SpiResource.request();
    }
    if (m_gyro_state == GYRO_ACTIVE) {
      return EALREADY;
    }
    return SUCCESS;
  }

  event void PwrReg.pwrAvail() {
    if (m_gyro_state == GYRO_PWR_REQ) {
      m_gyro_state = GYRO_PWR_ON;
    }
    if (m_gyro_state == GYRO_PWR_ON) {
      m_gyro_state = GYRO_RES_REQ;
      call SpiResource.request();
    }
  }

  task void gyroStopTask() {
    if (m_gyro_state == GYRO_STOPPING) {
      signal SplitControl.stopDone(SUCCESS);
    }
  }

  command error_t SplitControl.stop() {
    if (m_gyro_state == GYRO_ACTIVE) {
      call SpiResource.release();
      m_gyro_state = GYRO_PWR_ON;
    }
    if (m_gyro_state >= GYRO_PWR_REQ) {
      call PwrReg.pwrRel();
    }
    m_gyro_state = GYRO_STOPPING;
    post gyroStopTask();
    return SUCCESS;
  }

  event void SpiResource.granted() {
    if (call SpiResource.isOwner()) {
      if (m_gyro_state == GYRO_RES_REQ) {
	m_gyro_state = GYRO_ACTIVE;
	signal SplitControl.startDone(SUCCESS);
      } else {
	/* We're not waiting for a grant, so release it */
	call SpiResource.release();
      }
    }
  }

  command error_t L3g4200.whoAmI(uint8_t *id) {
    if (m_gyro_state != GYRO_ACTIVE)
      return EOFF;
    call CS.clr();
    *id = call SpiByte.write(DIR_READ | WHO_AM_I);
    call CS.set();
    return SUCCESS;
  }
}
