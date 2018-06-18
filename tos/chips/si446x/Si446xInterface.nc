/*
 * Copyright (c) 2015, 2017-2018 Eric B. Decker
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
 * Define the interface to the Silicon Labs si446x family of radios.
 *
 *  si446x_irqn: access to interrupt pin.  Also needs to be wired into
 *      an interrupt service routine as well.
 *
 *  si446x_cts: access to clear to send mechanism.  Either via a gpio h/w
 *      pin (ie. gp1, defaults to CTS) or using the CTS READ_CMD_BUFF.
 *      The routine si446x_cts() encapsulates the access mechanism.
 *
 *  si446x_csn  (aka nsel): Chip select.  Must be pulled low via
 *      si446x_set_cs() and cleared via si446x_clr_cs().  The data sheets
 *      refer to this as NSEL (select, low true).
 *
 *  si446x_sdn: shutdown.  When 1, the chip is completely shutdown.  30nA
 *      loses all registers/configuration.
 *
 *  SPI interface:
 *    si446x_sclk
 *    si446x_miso
 *    si446x_mosi
 *
 *  High TX power vs. Low TX power.  The si446x family of radio chips
 *  can operate between 1.8V and 3.8V.  1.8V is used in low power systems
 *  but maximum tx current can't be realized unless the radio is powered
 *  by 3.3 volts or higher.
 *
 *  The routines, si446x_set_high_tx_pwr and si446x_set_low_tx_pwr are
 *  used to control what the radio chip can do when transmitting.
 *
 *
 * Interrupts:  There are platform dependent routines for enabling and
 * disabling interrupts on the radio h/w.  This is because there may
 * be platform dependent behaviours needed when turning interrupts on and
 * off.  In particular if timestamping requires h/w support, the platform
 * would need to do additional activities when turning interrupts on and
 * off.
 *
 * @author Eric B. Decker <cire831@gmail.com>
 * December, 2015
 */

interface Si446xInterface {

  /**
   * si446x_cts: return current CTS status of the radio chip
   *
   * When a command is sent, the radio will go busy and a new command should
   * not be sent until a CTS condition occurs.  This routine will return
   * the current CTS status.
   *
   * This routine assumes the use of a gpio h/w pin.  Doing the cts check
   * via bus accesses requires access to the SPI bus which for a seperate module
   * would need to know about what SPI bus and the h/w associated with it.
   * This make more sense to be done from with in the driver itself because
   * the driver knows all this stuff.
   **/
  async command uint8_t si446x_cts();


  /**
   * si446x_irqn: return current status of radio interrupt pin.
   *
   * Note: Low true to stay true to the h/w definition.
   **/
  async command uint8_t si446x_irqn();


  /*
   * si446x_sdn: return the value of the corresponding pin
   * si446x_csn:
   */
  async command uint8_t si446x_sdn();
  async command uint8_t si446x_csn();

  /**
   * si446x_shutdown: full powerdown of the radio.
   **/
  async command void si446x_shutdown();


  /**
   * si446x_unshutdown: turn radio back on.
   **/
  async command void si446x_unshutdown();


  /**
   * si446x_set_cs: set chip select
   **/
  async command void si446x_set_cs();


  /**
   * si446x_clr_cs: clear chip select
   **/
  async command void si446x_clr_cs();


  /**
   * si446x_set_low_tx_pwr:
   *
   * put chip in low power transmit mode.
   **/
  async command void si446x_set_low_tx_pwr();


  /**
   * si446x_set_high_tx_pwr:
   *
   * put chip in high power transmit mode.
   **/
  async command void si446x_set_high_tx_pwr();


  /**
   * cap_val:     get register of capture hardware
   * cap_control: get control value for capture
   */
  async command uint16_t si446x_cap_val();
  async command uint16_t si446x_cap_control();


  /**
   * si446x_interrupt
   *
   * signalled when an interrupt has occurred on the
   * interrupt pin NIRQ.
   */
  async event void si446x_interrupt();


  /**
   * si446x_enableInterrupt
   * si446x_disableInterrupt
   * si446x_isInterruptEnabled
   *
   * enable any h/w interrupt associated with the radio
   * isInterruptEnabled returns TRUE if the interrupt is enabled.
   */
  async command void si446x_enableInterrupt();
  async command void si446x_disableInterrupt();
  async command bool si446x_isInterruptEnabled();
}
