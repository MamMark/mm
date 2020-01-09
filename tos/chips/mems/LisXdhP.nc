/* tos/chips/mems/LisXdhP.nc
 *
 * Copyright (c) 2019 Eric B. Decker
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

/*
 * low level driver for the ST lisXdh accelometer.
 *
 * Supports either direct access or pipelined using the fifo onboard
 * the chip.
 *
 * See platform initialization for appropriate startup code.
 * see <platform>/hardware/mems/Mems<n>HardwareP.
 */

#include "lisxdh.h"


module LisXdhP {
  provides interface MemsStHardware  as Accel;
  uses {
    interface SpiReg;
    interface MemsStInterrupt as AccelInt1;
  }
}
implementation {

  command uint8_t Accel.whoAmI() {
    return call SpiReg.readOne(LISX_WHO_AM_I);
  }


  command bool Accel.dataAvail() {
    lisx_status_reg_t status;

    status.bits = call SpiReg.readOne(LISX_STATUS_REG);
    return status.x.zyxda;
  }


  /* must read in groups of 6 */
  command void Accel.read(uint8_t *buf, uint8_t buflen) {
    while (buflen) {
      if (buflen >= 6) {
        call SpiReg.readMultiple(LISX_OUT_X_L, buf, 6);
        buf    += 6;
        buflen -= 6;
      } else {
        call SpiReg.readMultiple(LISX_OUT_X_L, buf, buflen);
        buf    += buflen;
        buflen -= buflen;
      }
    }
  }


  command uint16_t Accel.getStatus() {
    uint16_t result;

    result  = call SpiReg.readOne(LISX_FIFO_SRC_REG) << 8;
    result |= call SpiReg.readOne(LISX_STATUS_REG);
    return result;
  }


  command uint8_t Accel.getRegister(uint8_t reg) {
    return call SpiReg.readOne(reg);
  }


  command void Accel.setRegister(uint8_t reg, uint8_t val) {
    call SpiReg.writeOne(reg, val);
  }


  void kick_accel(uint8_t odr) {
    lisx_ctrl_reg1_t reg1;

    reg1.x.odr  = odr;
    reg1.x.lpen = 1;
    reg1.x.zen  = 1;
    reg1.x.yen  = 1;
    reg1.x.xen  = 1;
    call SpiReg.writeOne(LISX_CTRL_REG1, reg1.bits);
  }


  void enable_fifo() {
    lisx_ctrl_reg5_t     reg5;
    lisx_fifo_ctrl_reg_t fifo_ctrl;

    reg5.bits      = 0;
    reg5.x.fifo_en = 1;
    call SpiReg.writeOne(LISX_CTRL_REG5, reg5.bits);

    fifo_ctrl.bits = 0;   fifo_ctrl.x.fth = 0x1f;
    fifo_ctrl.x.fm = LISX_FIFO_MODE;
    call SpiReg.writeOne(LISX_FIFO_CTRL_REG, fifo_ctrl.bits);
  }


  void disable_fifo() {
    lisx_ctrl_reg5_t     reg5;
    lisx_fifo_ctrl_reg_t fifo_ctrl;

    reg5.bits      = 0;
    reg5.x.fifo_en = 0;
    call SpiReg.writeOne(LISX_CTRL_REG5, reg5.bits);

    fifo_ctrl.bits = 0;
    fifo_ctrl.x.fm = LISX_FIFO_BYPASS;
    call SpiReg.writeOne(LISX_FIFO_CTRL_REG, fifo_ctrl.bits);
  }


  command void Accel.start(uint16_t datarate) {
    uint8_t odr;

    switch (datarate) {
      case 1:       odr = LISX_ODR_1HZ;     break;
      case 10:      odr = LISX_ODR_10HZ;    break;
      case 25:      odr = LISX_ODR_25HZ;    break;
      case 100:     odr = LISX_ODR_100HZ;   break;
      case 200:     odr = LISX_ODR_200HZ;   break;
      case 400:     odr = LISX_ODR_400HZ;   break;
      case 1600:    odr = LISX_ODR_1K600HZ; break;
      case 1250:    odr = LISX_ODR_1K250HZ; break;
      case 5000:    odr = LISX_ODR_5KHZ;    break;
      default:      return;
    }
    kick_accel(odr);
  }


  command void Accel.stop() {
    kick_accel(0);                      /* turn accel off    */
    disable_fifo();                     /* and kill the fifo */
  }


  command void Accel.startFifo(uint16_t datarate) {
    enable_fifo();
    call Accel.start(datarate);
  }


  command void Accel.restartFifo() {
    lisx_fifo_ctrl_reg_t fifo_ctrl;

    fifo_ctrl.bits = 0;
    fifo_ctrl.x.fm = LISX_FIFO_BYPASS;
    call SpiReg.writeOne(LISX_FIFO_CTRL_REG, fifo_ctrl.bits);
    fifo_ctrl.x.fm = LISX_FIFO_MODE;
    call SpiReg.writeOne(LISX_FIFO_CTRL_REG, fifo_ctrl.bits);
  }


  command bool Accel.fifoOverflowed() {
    lisx_fifo_src_reg_t fifo_src;

    fifo_src.bits = call SpiReg.readOne(LISX_FIFO_SRC_REG);
    if (fifo_src.x.ovrn_fifo)
      return TRUE;
    return FALSE;
  }


  /**
   * fifoLen: return length of the Fifo
   *
   * The fifo consists of the output register and the Fifo itself.
   * If the Empty bit is set then nothing is in the fifo/output.
   *
   * Fss goes from 0 to 31.  So if we have one element filled.  Then
   * output has the single element, Empty will be off, and fss will
   * 0.  When the fifo is full, then fss will be 1f, and OVRN_FIFO will
   * be set and the Fifo will be shut down.  Accel.restartFifo() will
   * need to be called to restart the Fifo after emptying the data.
   */
  command bool Accel.fifoLen() {
    lisx_fifo_src_reg_t fifo_src;

    fifo_src.bits = call SpiReg.readOne(LISX_FIFO_SRC_REG);
    if (fifo_src.x.empty)
      return 0;
    return fifo_src.x.fss + 1;
  }


  /* place holder */
  async event void AccelInt1.interrupt() { }
}
