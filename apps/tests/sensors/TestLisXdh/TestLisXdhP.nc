/*
 * Copyright (c) 2012, 2015, 2019 Eric B. Decker
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
 
#include <stdio.h>
#include "Timer.h"
#include "lisxdh.h"

char abuf[80];
char bufx[80];  // for  debugging messages
char bufy[80];
char bufz[80];

module TestLisXdhP {
  uses {
    interface Boot;
    interface Init           as InitAccel;
    interface SplitControl   as ControlAccel;
    interface LisXdh         as Accel;
    interface Hpl_MM_hw as HW;
    interface Timer<TMilli>  as PeriodTimer;
  }
}

implementation {  

  void whoAmI() {
    call Accel.getReg(WHO_AM_I);
  }

  event void Boot.booted() {
    nop();
    call HW.pwr_3v3_on();
    call InitAccel.init();
    call ControlAccel.start();
  }
  
  event void ControlAccel.startDone(error_t error) {
    whoAmI();
    call ControlAccel.stop();
  }  

  event void ControlAccel.stopDone(error_t error) {
    //todo
  }  

  async event void Accel.getRegDone( error_t error, uint8_t regAddr, uint8_t val) {
    sprintf(abuf, "getRegDone  error=%x regAddr=%x val=%x (expecting 0x33)", error, regAddr, val);
  }  

  async event void Accel.alertThreshold() {
    //todo
  }  

  async event void Accel.setRegDone( error_t error , uint8_t regAddr, uint8_t val) {
    //todo
  }

  event void PeriodTimer.fired(){
    nop();
  }

}
