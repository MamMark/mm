module Lis3dhP {
  provides interface Init;
  provides interface SplitControl;
  provides interface Lis3dh;

  uses interface Resource as SpiResource;
  uses interface SpiBlock as SpiBlock;
  uses interface SpiByte as SpiByte;
  uses interface HplMsp430GeneralIO as CS;
  uses interface PwrReg;
}

#include "lis3dh.h"

implementation {
  uint8_t rx[16], tx[16];

  typedef enum {
    ACCEL_IDLE = 0,
    ACCEL_STOPPING,
    ACCEL_PWR_REQ,
    ACCEL_PWR_ON,
    ACCEL_RES_REQ,
    ACCEL_ACTIVE,
  } accel_state_t;

  accel_state_t m_accel_state;

  command error_t Init.init() {
    call CS.set();
    call CS.makeOutput();
    return SUCCESS;
  }

  command error_t SplitControl.start() {
    if (m_accel_state <= ACCEL_STOPPING) {
      error_t pwr_status = call PwrReg.pwrReq();
      if (pwr_status == EALREADY)
	m_accel_state = ACCEL_PWR_ON;
      else
	m_accel_state = ACCEL_PWR_REQ;
    }
    if (m_accel_state == ACCEL_PWR_ON) {
      m_accel_state = ACCEL_RES_REQ;
      return call SpiResource.request();
    }
    if (m_accel_state == ACCEL_ACTIVE) {
      return EALREADY;
    }
    return SUCCESS;
  }

  event void PwrReg.pwrAvail() {
    if (m_accel_state == ACCEL_PWR_REQ) {
      m_accel_state = ACCEL_PWR_ON;
    }
    if (m_accel_state == ACCEL_PWR_ON) {
      m_accel_state = ACCEL_RES_REQ;
      call SpiResource.request();
    }
  }

  task void accelStopTask() {
    if (m_accel_state == ACCEL_STOPPING) {
      signal SplitControl.stopDone(SUCCESS);
    }
  }

  command error_t SplitControl.stop() {
    if (m_accel_state == ACCEL_ACTIVE) {
      call SpiResource.release();
      m_accel_state = ACCEL_PWR_ON;
    }
    if (m_accel_state >= ACCEL_PWR_REQ) {
      call PwrReg.pwrRel();
    }
    m_accel_state = ACCEL_STOPPING;
    post accelStopTask();
    return SUCCESS;
  }

  event void SpiResource.granted() {
    if (call SpiResource.isOwner()) {
      if (m_accel_state == ACCEL_RES_REQ) {
	m_accel_state = ACCEL_ACTIVE;
	signal SplitControl.startDone(SUCCESS);
      } else {
	/* We're not waiting for a grant, so release it */
	call SpiResource.release();
      }
    }
  }

  command error_t Lis3dh.whoAmI(uint8_t *id) {
    if (m_accel_state != ACCEL_ACTIVE)
      return EOFF;
    call CS.clr();
    nop();
    nop();
    nop();
    tx[0] = READ_REG | WHO_AM_I;
    call SpiBlock.transfer(tx, rx, 2);
    *id = rx[1];
    call CS.set();
    return SUCCESS;
  }
}
