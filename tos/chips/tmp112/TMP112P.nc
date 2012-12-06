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

#include <TinyError.h>
#include "tmp112.h"

norace uint8_t xbuf[32];

module TMP112P {
  provides interface Read<uint16_t> as ReadTemp;
  uses {
    interface Resource;
    interface I2CReg;
    interface I2CPacket<TI2CBasicAddr> as I2C;
  }
}
implementation {
  norace uint8_t state;

#define DEVID	0x48	// use 0x48 = 1001000 for ADD0 connected to ground
			//     0x49 = 1001001 for ADD0 connected to V+
			//     0x4a = 1001010 for ADD0 connected to SDA
			//     0x4b = 1001011 for ADD0 connected to SCL

#define CONFIG (TMP112_CONFIG_RES_3 | TMP112_CONFIG_FAULT_1 \
	| TMP112_CONFIG_4HZ   | TMP112_CONFIG_EM)


  task void signalDone() {
    uint16_t d, *p;

    TOGGLE_TELL;
    TOGGLE_TELL;
    TOGGLE_TELL;
    TOGGLE_TELL;
    TOGGLE_TELL;
    p = (uint16_t *) xbuf;
    d = *p;
    signal ReadTemp.readDone(SUCCESS, d);
  }
    

  command error_t ReadTemp.read() {
    return call Resource.request();
  }


  void bunch_of_nops() __attribute__ ((noinline)) {
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 

    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 

    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 

    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 

    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); 
    nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop(); nop();
  }


  event void Resource.granted() {
    state = 0;
    xbuf[0] = 2;			/* T_low register */
    xbuf[1] = 0x1a;
    xbuf[2] = 0xa1;
    nop();
    TOGGLE_TELL;
    TOGGLE_TELL;
    call I2C.write(I2C_START, DEVID, 1, xbuf);
  }


  async event void I2C.writeDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data) {
    nop();
    switch (state) {
      case 0:
	state = 1;
	call I2C.read(I2C_RESTART | I2C_STOP, DEVID, 2, &xbuf[1]);
	break;

      case 2:
	state = 3;
	call I2C.read(I2C_RESTART | I2C_STOP, DEVID, 2, &xbuf[1]);
	break;

      case 4:
	state = 5;
	call I2C.read(I2C_START | I2C_STOP, DEVID, 2, xbuf);
	break;

      case 99:
	state = 99;
	post signalDone();
	break;

      case 1:
      case 3:
      case 5:
      case 6:
      case 7:
      case 8:
      default:
	break;
    }
  }


  async event void I2C.readDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data) {
    nop();
    switch (state) {
      case 1:
	state = 2;
	xbuf[0] = 0;
	call I2C.write(I2C_START, DEVID, 1, xbuf);
	break;

      case 3:
	state = 4;
	xbuf[0] = 2;
	call I2C.write(I2C_START | I2C_STOP, DEVID, 1, xbuf);
	break;

      case 5:
	state = 99;
	call I2C.read(I2C_START | I2C_STOP, DEVID, 2, xbuf);
	break;

      case 99:
	state = 99;
	post signalDone();
	break;

      case 0:
      case 2:
      case 4:
      case 7:
      default:
	break;
    }
  }


#ifdef notdef
  event void Resource.granted() {
    uint16_t d;

    xbuf[0] = 0x1a;
    xbuf[1] = 0x2a;
    xbuf[2] = 0x3a;
    xbuf[3] = 0x11;
    xbuf[4] = 0x22;
    xbuf[5] = 0x33;
    xbuf[0] = 1;
    call I2CReg.reg_writeBlock(DEVID, TMP112_TEMP, 0, xbuf);
    nop();
    xbuf[0] = 2;
    call I2CReg.reg_writeBlock(DEVID, TMP112_TEMP, 1, NULL);
    nop();
    xbuf[0] = 3;
    call I2CReg.reg_writeBlock(DEVID, TMP112_TEMP, 1, xbuf);
    nop();
    xbuf[0] = 4;
    call I2CReg.reg_writeBlock(DEVID, TMP112_TEMP, 2, xbuf);
    nop();
    xbuf[0] = 5;
    call I2CReg.reg_writeBlock(DEVID, TMP112_TEMP, 3, xbuf);
    nop();
    xbuf[0] = 6;
    call I2CReg.reg_writeBlock(DEVID, TMP112_TEMP, 4, xbuf);
    nop();
    xbuf[0] = 7;
    call I2CReg.reg_writeBlock(DEVID, TMP112_TEMP, 5, xbuf);
    nop();
    xbuf[0] = 8;
    call I2CReg.reg_writeBlock(DEVID, TMP112_TEMP, 6, xbuf);
    nop();

#ifdef notdef
    call I2CReg.reg_read16(DEVID,  TMP112_TEMP,   &d);
    call I2CReg.reg_read16(DEVID,  TMP112_CONFIG, &d);

    call I2CReg.reg_write16(DEVID, TMP112_CONFIG, CONFIG);
    call I2CReg.reg_read16(DEVID,  TMP112_CONFIG, &d);

    call I2CReg.reg_read16(DEVID, TMP112_TEMP, &d);
    nop();
#endif

    signal ReadTemp.readDone(SUCCESS, d);
  }
#endif

}
