/*
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * ARCHED ROCK OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 */

/**
 * HPL implementation of general-purpose I/O for the ChipCon CC2420
 * radio connected to a TI MSP430 processor.   Pin definitions for the
 * MM3 Tag.  See ./hardware.h for details of assignments.
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

configuration HplCC2420PinsC {
  provides {
    interface GeneralIO as CCA;
    interface GeneralIO as CSN;
    interface GeneralIO as FIFO;
    interface GeneralIO as FIFOP;
    interface GeneralIO as RSTN;
    interface GeneralIO as SFD;
    interface GeneralIO as VREN;
  }
}

implementation {
  components HplMsp430GeneralIOC as GeneralIOC;
  components new Msp430GpioC() as CCAM;
  components new Msp430GpioC() as CSNM;
  components new Msp430GpioC() as FIFOM;
  components new Msp430GpioC() as FIFOPM;
  components new Msp430GpioC() as RSTNM;
  components new Msp430GpioC() as SFDM;
  components new Msp430GpioC() as VRENM;

  CCAM   -> GeneralIOC.Port63;
  CSNM   -> GeneralIOC.Port30;
  FIFOM  -> GeneralIOC.Port62;
  FIFOPM -> GeneralIOC.Port60;
  RSTNM  -> GeneralIOC.Port57;
  SFDM   -> GeneralIOC.Port61;
  VRENM  -> GeneralIOC.Port66;

  CCA   = CCAM;
  CSN   = CSNM;
  FIFO  = FIFOM;
  FIFOP = FIFOPM;
  RSTN  = RSTNM;
  SFD   = SFDM;
  VREN  = VRENM;
}
