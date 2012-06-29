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

#define CLIENT_ADDRESS 0x48   // use 0x48 = 1001000 for ADD0 connected to ground
                              //     0x49 = 1001001 for ADD0 connected to V+
                              //          = 1001010 for ADD0 connected to SDA
                              //          = 1001011 for ADD0 connected to SCL

// possible values for the Pointer Register (Datasheet, p. 7)
#define TEMP_REGISTER    0   
#define CONFIG_REGISTER  1
#define TLOW_REGISTER    2
#define THIGH_REGISTER   3

uint8_t pointerReg;
uint8_t tempData[2];

module TMP112P {
  provides interface Read<uint16_t> as ReadTemp;
  uses {
    interface Resource;
    interface I2CPacket<TI2CBasicAddr> as I2C;        
  }
}

implementation {  

  command error_t ReadTemp.read(){
    return call Resource.request();  // see granted()
  }


  /*
     Signal an unsuccesful read.  Using tasks to call readDone avoids using
     nested interrupts and a compile time warning.
  */
  task void readError() {
    //TEP114 says this MUST be a 0
    signal ReadTemp.readDone(FAIL, 0);
  }


  /* 
     Signal a successful read and pass readDone the data.  Depending on how the
     TMP112 is configured, the first 12 or 13 bits of the data word will contain
     a reading.   See the README for more.
  */
  task void readSuccess() {
    uint16_t temp;
    temp = tempData[0];
    temp <<= 8;
    temp |=  tempData[1];
    signal ReadTemp.readDone(SUCCESS, temp);
  }


  event void Resource.granted(){
    pointerReg = TEMP_REGISTER;

    if (call I2C.write((I2C_START | I2C_STOP), CLIENT_ADDRESS, 1, &pointerReg)) {
      call Resource.release();
      nop();
      post readError();
    }
  }


  /*
    Called when the write to the I2C completes.  This reads the temperature data.
  */
  async event void I2C.writeDone(error_t error, uint16_t addr, uint8_t length, uint8_t *data) {
    if (error) {
      /*
       * oops
       */
      nop();
    }
    if (call I2C.read((I2C_START | I2C_STOP),  CLIENT_ADDRESS, 2, tempData)) {
      /* whoops */
      call Resource.release();
      nop();
      post readError();  
    } 
  }   


  async event void I2C.readDone(error_t error, uint16_t addr, uint8_t length, uint8_t *data){
     call Resource.release();
     if(error) {
       nop();
       post readError();
       return;
     }
     post readSuccess();
  }
}
