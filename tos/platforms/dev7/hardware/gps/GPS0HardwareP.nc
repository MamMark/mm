/*
 * Copyright (c) 2020 Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

#include <hardware.h>
#include <panic.h>
#include <platform_panic.h>
#include <msp432.h>
#include <platform.h>
#include <typed_data.h>
#include <gpsproto.h>
#include <ublox_msg.h>
#include <ublox_driver.h>

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif

/*
 * The eUSCI for the SPI is always clocked by SMCLK which is DCOCLK/2.  So
 * if MSP432_CLK is 16777216 (16MiHz) the SMCLK is 8MiHz, 8388608 Hz.  We
 * further divide this by MSP432_UBLOX_DIV to clock the SPI at 2 MiHz.
 */

#if (MSP432_CLK != 16777216)
#warning MSP432_CLK other than 16777216
#endif

module GPS0HardwareP {
  provides {
    interface Init as GPS0PeriphInit;
    interface ubloxHardware as HW;
  }
  uses {
    interface HplMsp432Usci     as Usci;
    interface HplMsp432PortInt  as TxRdyIRQ;
    interface Panic;
    interface Platform;
  }
}
implementation {

#define gps_panic(where, arg, arg1) do {                 \
    call Panic.panic(PANIC_GPS, where, arg, arg1, 0, 0); \
  } while (0)

#define  gps_warn(where, arg)      do { \
    call  Panic.warn(PANIC_GPS, where, arg, 0, 0, 0); \
  } while (0)


  uint8_t  *m_tx_buf;                   /* current transmit pointer */
  uint16_t  m_tx_idx;                   /* where in the buffer. */
  uint16_t  m_tx_len;                   /* NULL if inactive. */

  const msp432_usci_config_t ublox_spi_config = {
    ctlw0 :(EUSCI_A_CTLW0_CKPH        | EUSCI_A_CTLW0_MSB  |
            EUSCI_A_CTLW0_MST         | EUSCI_A_CTLW0_SYNC |
            EUSCI_A_CTLW0_SSEL__SMCLK),
    brw   : MSP432_UBLOX_DIV,     /* see platform_clk_defs */
                                  /* 2 MiHz */
    mctlw : 0,                    /* Always 0 in SPI mode */
    i2coa : 0
  };


  command error_t GPS0PeriphInit.init() {
    atomic {
      call Usci.configure(&ublox_spi_config, FALSE);
      call HW.gps_pwr_on();
      return SUCCESS;
    }
  }

  command void HW.gps_set_cs()    { UBX_CSN   = 0; }
  command void HW.gps_clr_cs()    { UBX_CSN   = 1; }
  command void HW.gps_set_reset() { UBX_RESET = 1; }
  command void HW.gps_clr_reset() { UBX_RESET = 0; }
  command bool HW.gps_powered()   { return TRUE; }

  command void HW.gps_pwr_on()    {
    /* always on, just make sure the pins are set correctly */

    /* power on */

    /* now switch pins and connect to the gps */
    UBX_PINS_PWR_ON;
  }

  command void HW.gps_pwr_off()   {
    /* always on, just pretend by switching the pins. */

    /* switch pins, then kill power */
    UBX_PINS_PWR_OFF;
    /* power off */
  }


  command void HW.spi_clr_port() {
    call Usci.enterResetMode_();
    call Usci.leaveResetMode_();
  }


  /*
   * spi_put: wait for space and throw the byte out
   * equivilent to FastSpiByte.splitWrite()
   */
  command void HW.spi_put(uint8_t byte) {
    uint32_t t0;

    t0 = call Platform.usecsRaw();
    while (!call Usci.isTxIntrPending()) {
      if (call Platform.usecsExpired(t0, 150))
        gps_panic(0, 0, 0);
    }
    call Usci.setTxbuf(byte);
  }

  /*
   * spi_get: wait for incoming and grab the byte
   * equivilent to FastSpiByte.splitRead()
   */
  command uint8_t HW.spi_get() {
    uint32_t t0;
    uint8_t  data;

    t0 = call Platform.usecsRaw();
    while (!(call Usci.isRxIntrPending())) {
      if (call Platform.usecsExpired(t0, 150))
        gps_panic(0, 0, 0);
    }
    data = call Usci.getRxbuf();
    return data;
  }


  /*
   * spi_getput: wait for incoming and grab the byte
   * equivilent to FastSpiByte.splitReadWrite(byte)
   */
  command uint8_t HW.spi_getput(uint8_t byte) {
    uint8_t  data;

    data = call HW.spi_get();
    call HW.spi_put(byte);
    return data;
  }


  command void HW.gps_sw_reset(uint16_t bbr_mask, uint8_t reset_mode) {
    uint32_t      t0, t1, len;
    ubx_cfg_rst_t rstmsg;
    uint16_t      chk;
    uint8_t      *outp;

    /* first hold CS up for at least 1 ms, then reassert */
    t0 = call Platform.usecsRaw();
    call HW.gps_clr_cs();
    call HW.spi_clr_port();
    do {
      t1 = call Platform.usecsRaw();
    } while ((t1 - t0) < 1200);
    call HW.gps_set_cs();
    rstmsg.sync1        = UBX_SYNC1;
    rstmsg.sync2        = UBX_SYNC2;
    rstmsg.class        = UBX_CLASS_CFG;
    rstmsg.id           = UBX_CFG_RST;
    rstmsg.len          = 4;
    rstmsg.navBbrMask   = bbr_mask;
    rstmsg.resetMode    = reset_mode;
    rstmsg.reserved1    = 0;
    chk = call ubxProto.fletcher8((void *) &rstmsg.class, rstmsg.len + UBX_CHKSUM_ADJUST);
    rstmsg.chkA = chk >> 8;
    rstmsg.chkB = chk & 0xff;
    outp = (void *) &rstmsg;
    len  = sizeof(rstmsg);
    signal HW.gps_raw_collect(outp, len, GPS_DIR_TX);
    call HW.spi_put(0xff);
    while (len) {
      call HW.spi_getput(*outp++);
      len--;
    }
    call HW.spi_getput(0xff);           /* make sure last byte gets out */
    call HW.spi_get();
  }


  /*
   * driver_task: handle transmit and receive from the SPI pipe.
   *
   * o handles outgoing transmits
   * o handles incoming bytes, gives to protocol engine
   *
   * outgoing byte is either an IDLE or the byte from the m_tx_buf
   */

  uint8_t next_out() {
    uint8_t out;

    out = 0xff;
    if (m_tx_buf) {
      out = m_tx_buf[m_tx_idx++];
      if (m_tx_idx >= m_tx_len)
        m_tx_buf = NULL;
    }
    return out;
  }


  task void driver_task() {
    uint8_t  data;
    uint32_t byte_count, hang_count;

    hang_count = 64;
    call HW.gps_txrdy_int_disable();
    do {
      WIGGLE_EXC; WIGGLE_TELL; WIGGLE_EXC; WIGGLE_TELL;
      if (!m_tx_buf && !UBX_TXRDY_P) {
        /*
         * If m_tx_buf is empty (no transmit in progress) and TXRDY is
         * deasserted (no data available coming from the gps), there there
         * no work for driver_task to do.  How can this happen?
         *
         * Once driver_task is invoked (executing or posted to execute), it
         * will complete the transmit and/or any incoming receive.
         *
         * There is a window during which if the TXRDY interrupt occurs, it
         * can cause driver_task to be reposted.  This window opens when
         * the scheduler has removed driver_task from the taskq.  The window
         * closed above when the txrdy_int is disabled.  If we take a TXRDY
         * interrupt during that window, it will repost driver_task.
         *
         * The currently running/activated driver_task will empty the pipe
         * until TXRDY becomes deasserted.  When driver_task runs again it
         * will see no work because the current invokation will have
         * handled everything.
         *
         * That is what the above check guards agains.
         *
         * We also check to see if the pipeline has gone to sleep.  We
         * detect this when TXRDY stays up but we keep reading idle bytes
         * (0xFF).  If we see hang_count bytes of IDLE we will reset the
         * pipe by toggling CS.
         *
         * Error handling still needs to be sorted out.
         */
        break;
      }
      byte_count = 2;
      call HW.spi_put(next_out());
      while (TRUE) {
        data = call HW.spi_getput(next_out());
        signal HW.gps_byte_avail(data);
        if (m_tx_buf)                   /* more to transmit */
          continue;
        if (m_tx_len) {
          /* we were transmitting, last sent, tell upstairs */
          m_tx_len = 0;
          signal HW.gps_send_done(SUCCESS);
        }
        if (data != 0xff) {
          byte_count = 8;
          hang_count = 64;
          continue;
        }
        if (UBX_TXRDY_P) {
          byte_count = 8;
          hang_count--;
          if (hang_count)
            continue;

          signal HW.spi_pipe_stall();

          /*
           * note spi_pipe_stall will have fixed the pipe.  It completely
           * resets the pipe so we really need to bail out.  But first
           * reenable the txrdy interrupt.
           */
          call HW.gps_txrdy_int_enable();
          return;
        }

        byte_count--;
        if (byte_count == 0)
          break;
      }
      data = call HW.spi_get();
      signal HW.gps_byte_avail(data);
    } while (UBX_TXRDY_P);
    call HW.gps_txrdy_int_enable();
    /*
     * The txrdy_int_enable() clears out any pending txrdy int.  But it
     * also checks for TXRDY asserted and posts driver_task if present.
     */
  }


  command void HW.spi_pipe_restart() {
    WIGGLE_TELL; WIGGLE_EXC; WIGGLE_TELL;
    post driver_task();
  }

  command bool HW.gps_txrdy() {
    return UBX_TXRDY_P;
  }


  command bool HW.gps_txrdy_int_enabled() {
    return call TxRdyIRQ.isEnabled();
  }


  command void HW.gps_txrdy_int_enable()  {
    atomic {
      call TxRdyIRQ.disable();
      call TxRdyIRQ.edgeRising();
      call TxRdyIRQ.clear();
      call TxRdyIRQ.enable();
    }
    if (UBX_TXRDY_P)
      post driver_task();
  }

  command void HW.gps_txrdy_int_disable() {
    call TxRdyIRQ.disable();
  }


  command void HW.gps_send(uint8_t *ptr, uint16_t len) {
    if (!len || !ptr || m_tx_buf)
      gps_panic(0, 0, 0);

    m_tx_buf = ptr;
    m_tx_len = len;
    m_tx_idx = 0;
    post driver_task();
  }


  async event void TxRdyIRQ.fired() {
    post driver_task();
  }

  async event void Panic.hook() { }
}
