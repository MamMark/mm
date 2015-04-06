module Lis3mdlP {
  provides interface Init;
  provides interface SplitControl;
  provides interface Lis3mdl;

  uses interface Resource as SpiResource;
  uses interface SpiBlock as SpiBlock;
  uses interface SpiByte as SpiByte;
  uses interface HplMsp430GeneralIO as CS;
  uses interface PwrReg;
}

#include "lis3mdl.h"

implementation {
  uint8_t rx[16], tx[16];
  
  typedef enum {
    MAG_IDLE = 0,
    MAG_STOPPING,
    MAG_PWR_REQ,
    MAG_PWR_ON,
    MAG_RES_REQ,
    MAG_ACTIVE,
  } mag_state_t;

  mag_state_t m_mag_state;

  command error_t Init.init() {
    call CS.set();
    call CS.makeOutput();
    return SUCCESS;
  }

  command error_t SplitControl.start() {
    if (m_mag_state <= MAG_STOPPING) {
      error_t pwr_status = call PwrReg.pwrReq();
      if (pwr_status == EALREADY)
	m_mag_state = MAG_PWR_ON;
      else
	m_mag_state = MAG_PWR_REQ;
    }
    if (m_mag_state == MAG_PWR_ON) {
      m_mag_state = MAG_RES_REQ;
      return call SpiResource.request();
    }
    if (m_mag_state == MAG_ACTIVE) {
      return EALREADY;
    }
    return SUCCESS;
  }

  event void PwrReg.pwrAvail() {
    if (m_mag_state == MAG_PWR_REQ) {
      m_mag_state = MAG_PWR_ON;
    }
    if (m_mag_state == MAG_PWR_ON) {
      m_mag_state = MAG_RES_REQ;
      call SpiResource.request();
    }
  }

  task void magStopTask() {
    if (m_mag_state == MAG_STOPPING) {
      signal SplitControl.stopDone(SUCCESS);
    }
  }

  command error_t SplitControl.stop() {
    if (m_mag_state == MAG_ACTIVE) {
      call SpiResource.release();
      m_mag_state = MAG_PWR_ON;
    }
    if (m_mag_state >= MAG_PWR_REQ) {
      call PwrReg.pwrRel();
    }
    m_mag_state = MAG_STOPPING;
    post magStopTask();
    return SUCCESS;
  }

  event void SpiResource.granted() {
    if (call SpiResource.isOwner()) {
      if (m_mag_state == MAG_RES_REQ) {
	m_mag_state = MAG_ACTIVE;
	signal SplitControl.startDone(SUCCESS);
      } else {
	/* We're not waiting for a grant, so release it */
	call SpiResource.release();
      }
    }
  }

  command error_t Lis3mdl.whoAmI(uint8_t *id) {
    if (m_mag_state != MAG_ACTIVE)
      return EOFF;
    nop();
    nop();
    nop();
    call CS.clr();
    tx[0] = READ_REG | WHO_AM_I;
    call SpiBlock.transfer(tx, rx, 2);
    *id = rx[1];
    call CS.set();
    return SUCCESS;
  }
}
