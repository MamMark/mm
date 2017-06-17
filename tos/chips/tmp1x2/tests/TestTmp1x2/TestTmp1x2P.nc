/*
 * Copyright (c) 2012, 2017 Eric B. Decker
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

uint32_t state;

module TestTmp1x2P {
  uses {
    interface Boot;
    interface SimpleSensor<uint16_t> as P;
    interface SimpleSensor<uint16_t> as X;
    interface Timer<TMilli> as  TestTimer;
    interface PowerManager;
    interface Resource;
  }
}
implementation {
  event void Boot.booted() {
    call TestTimer.startPeriodic(1024);         /* about 1/min */
  }

  event void TestTimer.fired() {
    nop();
    call PowerManager.battery_connected();
    call Resource.immediateRequest();
    call PowerManager.battery_connected();
    call Resource.release();
    if ((state & 1) == 0) {
      call P.isPresent();
      call P.read();
    } else {
      call X.isPresent();
      call X.read();
    }
    state++;
  }

  event void P.readDone(error_t error, uint16_t data) {
    nop();
  }

  event void X.readDone(error_t error, uint16_t data) {
    nop();
  }

  event void Resource.granted() { }
}
