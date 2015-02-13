/*
 * Copyright (c) 2012 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * This module is the driver component for the LIS3DH
 * accelerometer in 3 wire SPI mode. It requires the SPI Block
 * interface and assumes the ability to manually toggle the chip select
 * via a GPIO. It provides the HplLIS3DH HPL interface.
 *
 * LIS3DHC.nc is  HplLIS3L02DQLogicSPIP.nc (2006-12-12 18:23:06) with changes.
 * @author Tod Landis
 */

#include "LIS3DHRegisters.h"

module LIS3DHP {
  provides interface Init;
  provides interface SplitControl;
  provides interface LIS3DH;

  uses interface Resource as AccelResource;
  uses interface SpiBlock;
  uses interface HplMsp430GeneralIO as CSN;
}
implementation {

  uint8_t rx[16], tx[16];

  typedef enum {
    STATE_STOPPED = 0,
    STATE_IDLE,
    STATE_STARTING,
    STATE_STOPPING,
    STATE_GETREG,
    STATE_SETREG,
    STATE_ERROR
  } lis3dh_state_t;

  lis3dh_state_t mState;
  bool    m_Initialized = FALSE;
  norace error_t mSSError;

  task void StopDone() {
    signal SplitControl.stopDone(mSSError);
    return;
  }

  command error_t Init.init() {
    if (!m_Initialized) {
      m_Initialized = TRUE;
      mState = STATE_STOPPED;
    }

    // Control CS pin manually
    call CSN.set();			/* first turn CS off */
    call CSN.makeOutput();		/* then make it an output */
    return SUCCESS;
  }

  command error_t SplitControl.start() {
    if (mState != STATE_STOPPED)
      return EBUSY;
    mState = STATE_STARTING;

    call AccelResource.request();
    return SUCCESS;

#ifdef notdef
    //old
    //    mSPITxBuf[0] = LIS3L02DQ_CTRL_REG1;
    //mSPITxBuf[1] = 0;
    //mSPITxBuf[1] = (LIS3L01DQ_CTRL_REG1_PD(1) | LIS3L01DQ_CTRL_REG1_XEN | LIS3L01DQ_CTRL_REG1_YEN | LIS3L01DQ_CTRL_REG1_ZEN);

    // new
    //    tx[0] = (CTRL_REG1 << 2);  // datasheet, p. 23  (careful:  not the same as the LIS3L02)                          
    //  tx[1] = XEN | YEN | ZEN;

    //call CSN.clr(); // CS LOW
    //error = call SpiBlock.transfer(tx, rx, 2);
#endif
  }


  event void AccelResource.granted() {
    mState = STATE_IDLE;
    signal SplitControl.startDone(SUCCESS);
    return;
  }


  command error_t SplitControl.stop() {
    if (mState != STATE_IDLE)
      return EBUSY;
    mState = STATE_STOPPING;

    tx[0] = CTRL_REG1;
    // old
//    mSPITxBuf[1] = 0;
//    mSPITxBuf[1] = (LIS3L01DQ_CTRL_REG1_PD(0));

    // new
    tx[1] = 0;        // power done mode, datasheet p. 30

    call CSN.clr();			/* assert CS */
    call SpiBlock.transfer(tx, rx, 2);
    call CSN.set();			/* deassert */
    return SUCCESS;
  }
  
  command error_t LIS3DH.getReg(uint8_t regAddr) {
    if((regAddr < 0x07) || (regAddr > 0x3D))
      return EINVAL;

    tx[0] = L3DH_READ | regAddr;
    rx[0] = 0;

#ifdef notdef
    tx[0] = 0x55;
    tx[1] = 0x55;

    while (1) {
      call SpiBlock.transfer(tx, rx, 2);
    }
#endif

    nop();
    mState = STATE_GETREG;
    call CSN.clr();		// assert CS
    call SpiBlock.transfer(tx, rx, 8);
    call CSN.set();		// deassert CS

    tx[0] = L3DH_READ | L3DH_MULT | 0x1f;
    call CSN.clr();		// assert CS
    call SpiBlock.transfer(tx, rx, 8);
    call CSN.set();		// deassert CS

    tx[0] = L3DH_READ | L3DH_MULT | 0x27;
    call CSN.clr();		// assert CS
    call SpiBlock.transfer(tx, rx, 9);
    call CSN.set();		// deassert CS
    return SUCCESS;

#ifdef notdef 
    P10OUT &= ~(0x80);
    i = 0;
    while (!(UCA3IFG & UCTXIFG)) ;
    UCA3TXBUF = tx[0];
    while (!(UCA3IFG & UCRXIFG)) ;
    rx[i++] = UCA3RXBUF;
    while (i < 8) {
      while (!(UCA3IFG & UCTXIFG)) ;
      UCA3TXBUF = i;
      while (!(UCA3IFG & UCRXIFG)) ;
      rx[i++] = UCA3RXBUF;
    }
    P10OUT |= 0x80;
#endif
  }

  command error_t LIS3DH.setReg(uint8_t regAddr, uint8_t val) {
    error_t error = SUCCESS;

    if((regAddr < 0x07) || (regAddr > 0x3D))
      return EINVAL;
    tx[0] = regAddr;
    tx[1] = val;
    mState = STATE_SETREG;
    call SpiBlock.transfer(tx, rx, 2);
    return SUCCESS;
  }

#ifdef notdef
  async event void SpiPacket.sendDone(uint8_t* txBuf, uint8_t* rxBuf, uint16_t len, error_t spi_error ) {
    error_t error = spi_error;

    atomic {
    switch (mState) {
    case STATE_GETREG:
      mState = STATE_IDLE;
  
      sprintf(abuf, "txBuf[0] = %x  rxBuf[0] = %x  len=%d error=%d", txBuf[0], rxBuf[0], len, error);


      call CSN.set(); // CS HIGH
      signal LIS3DH.getRegDone(error, (txBuf[0] & 0x7F) , rxBuf[1]);   // clears the read bit?
      break;
    case STATE_SETREG:
      mState = STATE_IDLE;
      signal LIS3DH.setRegDone(error, (txBuf[0] & 0x7F), txBuf[1]);
      break;
    case STATE_STARTING:
      mState = STATE_IDLE;
      call CSN.set();
//      post StartDone();
      break;
    case STATE_STOPPING:
      mState = STATE_STOPPED;
      post StopDone();
    default:
      mState = STATE_IDLE;
      break;
    }
    }
    return;
  }
#endif

  //  async event void InterruptAlert.fired() {
  //    signal LIS3DH.alertThreshold();
  //    return;
  //  }

  default event void SplitControl.startDone( error_t error ) { return; }
  default event void SplitControl.stopDone( error_t error ) { return; }

  default async event void LIS3DH.alertThreshold(){ return; }
}
