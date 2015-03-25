module Lis3dhP {
  provides {
    interface Init;
    interface SplitControl;
    interface Lis3dh;
  }

  uses  {
    interface Resource as SpiResource;
    interface SpiBlock as SpiBlock;
    interface SpiByte as SpiByte;
    interface HplMsp430GeneralIO as CS;
    interface PwrReg;
    interface Panic;
  }
}

#include "lis3dh.h"

#define LIS3DH_TX_BUFSIZ 32
#define LIS3DH_RX_BUFSIZ 32

implementation {
  uint8_t rx[LIS3DH_RX_BUFSIZ + 1];
  uint8_t tx[LIS3DH_TX_BUFSIZ + 1];

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

  error_t spi_rx(uint8_t addr, uint8_t len, bool mult_addr) {
    nop();
    nop();
    nop();
    if (m_accel_state != ACCEL_ACTIVE)
      return EOFF;
    if (len > LIS3DH_RX_BUFSIZ)
      call Panic.panic(PANIC_SNS, 1, addr, len, 0, 0);
    call CS.clr();
    memset(&tx[1], 0, len);
    tx[0] = READ_REG | addr;
    if (mult_addr)
      tx[0] |= MULT_ADDR;
    call SpiBlock.transfer(tx, rx, len);
    call CS.set();
    return SUCCESS;
  }

  error_t spi_tx(uint8_t addr, uint8_t len, bool mult_addr) {
    nop();
    nop();
    nop();
    if (m_accel_state != ACCEL_ACTIVE)
      return EOFF;
    if (len > LIS3DH_TX_BUFSIZ)
      call Panic.panic(PANIC_SNS, 2, addr, len, 0, 0);
    call CS.clr();
    tx[0] = WRITE_REG | addr;
    if (mult_addr)
      tx[0] |= MULT_ADDR;
    call SpiBlock.transfer(tx, 0, len);
    call CS.set();
    return SUCCESS;
  }

  error_t read_reg(uint8_t addr, uint8_t *val) {
    error_t ret = spi_rx(addr, 1, FALSE);
    *val = rx[1];
    return ret;
  }

  error_t write_reg(uint8_t addr, uint8_t val) {
    tx[1] = val;
    return spi_tx(addr, 1, FALSE);
  }

  error_t modify_reg(uint8_t addr, uint8_t clear_bits, uint8_t set_bits) {
    uint8_t reg;
    error_t ret;
    ret = read_reg(addr, &reg);
    if (ret == SUCCESS) {
      reg &= ~clear_bits;
      reg |= set_bits;
      return write_reg(addr, reg);
    }
    return ret;
  }

  command error_t Lis3dh.whoAmI(uint8_t *id) {
    return read_reg(WHO_AM_I, id);
  }

  async event void Panic.hook() { }
}
