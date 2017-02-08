/*
 * Copyright (c) 2015, 2017 Eric B. Decker
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
 * @author Eric B. Decker <cire831@gmail.com>
 */

#include <RadioConfig.h>

configuration HplSi446xC {
  provides {
    interface Si446xInterface;

    interface SpiByte;
    interface FastSpiByte;
    interface SpiPacket;
    interface SpiBlock;

    interface Resource as SpiResource;

    interface Alarm<TRadio, uint16_t> as Alarm;
  }
}
implementation {

  components Si446xPinsP;
  components HplMsp430InterruptC;
  components new Msp430InterruptC() as RadioInterruptC;
  Si446xInterface = Si446xPinsP;
  RadioInterruptC.HplInterrupt -> HplMsp430InterruptC.Port14;
  Si446xPinsP.RadioNIRQ -> RadioInterruptC;


  /* see exp5438_gps/hardware/usci/PlatformUsciMapC.nc for pin mappage */

  components new Msp430UsciSpiA3C() as SpiC;
  SpiResource = SpiC;
  SpiByte     = SpiC;
  FastSpiByte = SpiC;
  SpiPacket   = SpiC;
  SpiBlock    = SpiC;

  components Si446xSpiConfigP;
  Si446xSpiConfigP.Msp430UsciConfigure <- SpiC;

  /*
   * The default configuration for timers on x5 processors is
   * TA0 -> 32KiHz and TA1 -> TMicro (1uis).  But we want to
   * use TA0 for uS timestamping of the SFD signal.   So we
   * swap the usage.
   *
   * If the clock being used for SFDcapture goes to sleep, then when
   * we receive a packet there is no clock source for the capture.
   * This makes the capture unreliable.   However, if we are actively
   * using the 1us clock (like for a timer) it doesn't go to sleep and
   * should remain reasonable.
   *
   * We should use Msp430TimerMicro for this except that TimerMicroC
   * doesn't export Capture.
   *
   * ie. component new Msp430TimerMicroC as TM;
   *     SfdCaptureC.Msp430TimerControl = TM.Msp430TimerControl;
   *     SfdCaptureC.Msp430Capture      = TM.Msp430Capture;
   *
   * The SFD pin (gpio0) on the 2520EM module for the 5438A eval board is
   * configured to use P1.4/TA0.3 on the cpu.   This connects to the capture
   * module for TA0 via TA0.CCI3A which requires using TA0CCTL3.   The capture
   * will show up in TA0CCR3 and will set CCIFG in TA0CCTL3.  Units in TA0CCR3
   * will be TMicro ticks.
   *
   * This also requires a modification to Msp430TimerMicroMap so control
   * cells for T0A3 aren't exposed for use by other users.  A custom
   * version is present in tos/platforms/exp5438_2520/hardware/timer.  This
   * directory is also were which timer block is used for what function
   * (TMicro vs. TMilli) live.
   */

#ifdef notdef
  /*
   * uses GenericCapture and Msp430CaptureV2, which export capture overwrite
   * (overflow).
   */
  components new GpioCaptureC() as SfdCaptureC;
  components Msp430TimerC;
  SfdCapture = SfdCaptureC;

  SfdCaptureC.Msp430TimerControl -> Msp430TimerC.Control0_A3;
  SfdCaptureC.MCap2              -> Msp430TimerC.Capture0_A3;
  SfdCaptureC.CaptureBit         -> P_IOC.Port14;

  components HplMsp430InterruptC;
  components new Msp430InterruptC() as InterruptNIRQC;
  NIRQInterrupt = InterruptNIRQC.Interrupt;
  InterruptNIRQC.HplInterrupt -> HplMsp430InterruptC.Port14;
#endif

  components new AlarmMicro16C() as AlarmC;
  Alarm = AlarmC;
}
