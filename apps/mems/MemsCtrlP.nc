generic module MemsCtrlP () {
  provides {
    interface Init;
    interface SplitControl;
    interface MemsCtrl;
  }
  uses  {
    interface Resource as SpiResource;
    interface SpiBlock as SpiBlock;
    interface HplMsp430GeneralIO as CSN;
    interface PwrReg;
    interface Panic;
  }
}

#include "mems_bus.h"

#define MEMSCTRL_RX_BUFSIZ 32
#define MEMSCTRL_TX_BUFSIZ 32

implementation {
  uint8_t rxBuf[MEMSCTRL_RX_BUFSIZ + 1];
  uint8_t txBuf[MEMSCTRL_TX_BUFSIZ + 1];

  typedef enum {
    MEMSCTRL_IDLE = 0,
    MEMSCTRL_STOPPING,
    MEMSCTRL_PWR_REQ,
    MEMSCTRL_PWR_ON,
    MEMSCTRL_RES_REQ,
    MEMSCTRL_ACTIVE,
  } memsctrl_state_t;

  memsctrl_state_t m_memsctrl_state;

  command error_t Init.init() {
    call CSN.set();
    call CSN.makeOutput();
    return SUCCESS;
  }

  command error_t SplitControl.start() {
    if (m_memsctrl_state <= MEMSCTRL_STOPPING) {
      error_t pwr_status = call PwrReg.pwrReq();
      if (pwr_status == EALREADY)
	m_memsctrl_state = MEMSCTRL_PWR_ON;
      else
	m_memsctrl_state = MEMSCTRL_PWR_REQ;
    }
    if (m_memsctrl_state == MEMSCTRL_PWR_ON) {
      m_memsctrl_state = MEMSCTRL_RES_REQ;
      return call SpiResource.request();
    }
    if (m_memsctrl_state == MEMSCTRL_ACTIVE) {
      return EALREADY;
    }
    return SUCCESS;
  }

  event void PwrReg.pwrAvail() {
    if (m_memsctrl_state == MEMSCTRL_PWR_REQ) {
      m_memsctrl_state = MEMSCTRL_PWR_ON;
    }
    if (m_memsctrl_state == MEMSCTRL_PWR_ON) {
      m_memsctrl_state = MEMSCTRL_RES_REQ;
      call SpiResource.request();
    }
  }

  task void memsctrlStopTask() {
    if (m_memsctrl_state == MEMSCTRL_STOPPING) {
      signal SplitControl.stopDone(SUCCESS);
    }
  }

  command error_t SplitControl.stop() {
    if (m_memsctrl_state == MEMSCTRL_ACTIVE) {
      call SpiResource.release();
      m_memsctrl_state = MEMSCTRL_PWR_ON;
    }
    if (m_memsctrl_state >= MEMSCTRL_PWR_REQ) {
      call PwrReg.pwrRel();
    }
    m_memsctrl_state = MEMSCTRL_STOPPING;
    post memsctrlStopTask();
    return SUCCESS;
  }

  event void SpiResource.granted() {
    if (call SpiResource.isOwner()) {
      if (m_memsctrl_state == MEMSCTRL_RES_REQ) {
	m_memsctrl_state = MEMSCTRL_ACTIVE;
	signal SplitControl.startDone(SUCCESS);
      } else {
	/* We're not waiting for a grant, so release it */
	call SpiResource.release();
      }
    }
  }

  command error_t MemsCtrl.spiRx(uint8_t addr, uint8_t *buf,
				 uint8_t len, bool mult_addr) {
    nop();
    nop();
    nop();
    if (m_memsctrl_state != MEMSCTRL_ACTIVE)
      return EOFF;
    if (len > MEMSCTRL_RX_BUFSIZ)
      call Panic.panic(PANIC_SNS, 1, addr, len, 0, 0);
    call CSN.clr();
    memset(&txBuf[1], 0, len);
    txBuf[0] = READ_REG | addr;
    if (mult_addr)
      txBuf[0] |= MULT_ADDR;
    call SpiBlock.transfer(txBuf, rxBuf, len+1);
    memcpy(buf, &rxBuf[1], len);
    call CSN.set();
    return SUCCESS;
  }

  command error_t MemsCtrl.spiTx(uint8_t addr, uint8_t *buf, uint8_t len,
				 bool mult_addr) {
    nop();
    nop();
    nop();
    if (m_memsctrl_state != MEMSCTRL_ACTIVE)
      return EOFF;
    if (len > MEMSCTRL_TX_BUFSIZ)
      call Panic.panic(PANIC_SNS, 2, addr, len, 0, 0);
    call CSN.clr();
    txBuf[0] = WRITE_REG | addr;
    if (mult_addr)
      txBuf[0] |= MULT_ADDR;
    memcpy(&txBuf[1], buf, len);
    call SpiBlock.transfer(txBuf, 0, len+1);
    call CSN.set();
    return SUCCESS;
  }

  command error_t MemsCtrl.readReg(uint8_t addr, uint8_t *val) {
    error_t ret;
    nop();
    nop();
    nop();
    ret = call MemsCtrl.spiRx(addr, val, 1, FALSE);
    return ret;
  }

  command error_t MemsCtrl.writeReg(uint8_t addr, uint8_t val) {
    nop();
    nop();
    nop();
    return call MemsCtrl.spiTx(addr, &val, 1, FALSE);
  }

  command error_t MemsCtrl.modifyReg(uint8_t addr, uint8_t clear_bits,
				     uint8_t set_bits) {
    uint8_t reg;
    error_t ret;
    nop();
    nop();
    nop();
    ret = call MemsCtrl.readReg(addr, &reg);
    if (ret == SUCCESS) {
      reg &= ~clear_bits;
      reg |= set_bits;
      return call MemsCtrl.writeReg(addr, reg);
    }
    return ret;
  }

  async event void Panic.hook() { }
}
