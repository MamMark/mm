/*
 * Copyright (c) 2017-2018 Eric B. Decker
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
#include <gpsproto.h>

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif

/*
 * The eUSCI for the UART is always clocked by SMCLK which is DCOCLK/2.  So
 * if MSP432_CLK is 16777216 (16MiHz) the SMCLK is 8MiHz, 8388608 Hz.
 *
 * The eUSCI config block values depend on getting the divisor correct so this
 * matters.  The divisor and mctlw value are not easy (if at all possible) to
 * calculate from the SMCLK frequency so it is at best very difficult to
 * do this calculation in an automated fashion.  So we don't.
 */

#if (MSP432_CLK != 16777216)
#warning MSP432_CLK other than 16777216
#endif

/*
 * Platform configuration:
 *
 * Which msp432 Usci port assigned to the GPS is determined by the wiring in
 * HplGPS0C.  This will autoselect the port and the port IRQn.  The port
 * interrupt priority is defined in platform.h (GPS_IRQ_PRIORITY).
 */

typedef enum {
  GPSI_NONE = 0,
  GPSI_RX_INT_ON,
  GPSI_RX_INT_OFF,
  GPSI_RX_ERR,
  GPSI_RX,
  GPSI_TX_INT_ON,
  GPSI_TX_INT_OFF,
  GPSI_TX,
  GPSI_TX_RESTART,
  GPSI_CAPTURE,
} gps_int_ev_t;

typedef struct {
  uint32_t     ts;
  uint16_t     arg;
  gps_int_ev_t ev;
  uint8_t      count;
  uint8_t      stat;
  uint8_t      tx_rx;
} gps_int_rec_t;

#define GPS_INT_RECS_MAX 32

module GPS0HardwareP {
  provides {
    interface Init as GPS0PeripheralInit;
    interface Gsd4eUHardware as HW;
  }
  uses {
    interface HplMsp432Usci    as Usci;
    interface HplMsp432UsciInt as Interrupt;
    interface PwrReg;
    interface Panic;
    interface Platform;
  }
}
implementation {

  gps_int_rec_t   gps_int_recs[GPS_INT_RECS_MAX];
  norace uint32_t gps_int_rec_idx;

  enum {
    UART_MAX_BUSY_WAIT = 10000,                 /* 10ms max busy wait time */
  };


#define gps_panic(where, arg, arg1) do {                 \
    call Panic.panic(PANIC_GPS, where, arg, arg1, 0, 0); \
  } while (0)

#define  gps_warn(where, arg)      do { \
    call  Panic.warn(PANIC_GPS, where, arg, 0, 0, 0); \
  } while (0)


  norace uint8_t *m_tx_buf;
  norace uint16_t m_tx_len;

  norace bool     m_rx_active;          /* true if really receiving */
  norace uint8_t *m_rx_buf;
  norace uint16_t m_rx_len;
  norace uint32_t m_tx_idx, m_rx_idx;


  void gps_log_int(gps_int_ev_t ev, uint8_t stat, uint16_t arg) {
    gps_int_rec_t *gp;

    gp = &gps_int_recs[gps_int_rec_idx];
    if (gp->ev == ev && (ev == GPSI_RX || ev == GPSI_TX)) {
      gp->ts = call Platform.usecsRaw();
      gp->count++;
      return;
    }
    gps_int_rec_idx++;
    if (gps_int_rec_idx >= GPS_INT_RECS_MAX)
      gps_int_rec_idx = 0;
    gp = &gps_int_recs[gps_int_rec_idx];
    gp->ev = ev;
    gp->count = 1;
    gp->stat = stat;
    gp->arg = arg;
    if (m_tx_buf)    gp->tx_rx = 2;
    else             gp->tx_rx = 0;
    if (m_rx_active) gp->tx_rx |= 1;
    gp->ts = call Platform.usecsRaw();
  }


  /* Baud rate divisor equations
   *
   * N.Frac = BRCLK / bps
   * brw = N
   * BRCLK = 8Mi (8388608)
   * EUSCI_A_MCTLW_BRS_OFS = lookup[Frac]
   *
   * (see table on page 736 of SLAU356E - Revised Dec 2016)
   */

  const msp432_usci_config_t gps_4800_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK | EUSCI_A_CTLW0_RXEIE,
    brw   : 1747,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xb5 << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_9600_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK | EUSCI_A_CTLW0_RXEIE,
    brw   : 873,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xee << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_38400_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK | EUSCI_A_CTLW0_RXEIE,
    brw   : 218,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0x55 << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_115200_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK | EUSCI_A_CTLW0_RXEIE,
    brw   : 72,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xee << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


#ifdef notdef
  const msp432_usci_config_t gps_19200_config = { /* kill */
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK | EUSCI_A_CTLW0_RXEIE,
    brw   : 436,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xfb << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_57600_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK | EUSCI_A_CTLW0_RXEIE,
    brw   : 145,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xb5 << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_307200_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK | EUSCI_A_CTLW0_RXEIE,
    brw   : 27,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0x25 << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_921600_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK | EUSCI_A_CTLW0_RXEIE,
    brw   : 9,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0x08 << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };


  const msp432_usci_config_t gps_1228800_config = {
    ctlw0 : EUSCI_A_CTLW0_SSEL__SMCLK | EUSCI_A_CTLW0_RXEIE,
    brw   : 6,
    mctlw : (0 << EUSCI_A_MCTLW_BRF_OFS) |
            (0xbf << EUSCI_A_MCTLW_BRS_OFS),
    i2coa : 0
  };
#endif


  command error_t GPS0PeripheralInit.init() {
    GSD4E_PINS_MODULE;			/* connect pins to the UART */
    call Usci.enableModuleInt();
    return SUCCESS;
  }


  async command void HW.gps_set_on_off() {
    GSD4E_ONOFF = 1;
  }

  async command void HW.gps_clr_on_off() {
    GSD4E_ONOFF = 0;
  }

  async command void HW.gps_set_reset() {
    GSD4E_CTS = 1;              /* say we want UART mode */
    GSD4E_RESETN_OUTPUT;
    GSD4E_RESETN = 0;
  }

  async command void HW.gps_clr_reset() {
    GSD4E_RESETN = 1;
    GSD4E_RESETN_FLOAT;
  }

  async command bool HW.gps_awake() {
    return GSD4E_AWAKE_P;
  }

  async command void HW.gps_pwr_on() {
    call PwrReg.pwrReq();               /* will signal PwrReg.pwrOn() */
  }

  async command void HW.gps_pwr_off() {
    call PwrReg.forceOff();
  }

  async event void PwrReg.pwrOn() {
    /* power always on */
    GSD4E_PINS_MODULE;                  /* connect to the UART */
  }

  async event void PwrReg.pwrOff() {
    GSD4E_PINS_PORT;                    /* disconnect from the UART */
  }

  /*
   * gps_tx_finnish: wait for tx to finish
   *
   * input: byte_delay (in us) for last byte to leave
   *
   * tx_finnish first makes sure that the TXBUF is empty.  ie. that the
   * byte in TXBUF has actually been transferred into the shift register
   * and is on its way out.
   *
   * Then if byte_delay is set it will delay some more.  byte_delay is
   * a value used to let the last byte actually leave the shift register.
   * This is used prior to changing communications configurations.
   */
  async command void HW.gps_tx_finnish(uint32_t byte_delay) {
    uint32_t t0, t1;

    t0 = call Platform.usecsRaw();
    while (!call Usci.isTxIntrPending()) {
      t1 = call Platform.usecsRaw();
      if (t1 - t0 > UART_MAX_BUSY_WAIT) {
	gps_panic(1, t1, t0);
	return;
      }
    }
    t0 = call Platform.usecsRaw();
    while (1) {
      t1 = call Platform.usecsRaw();
      if (t1 - t0 > byte_delay)
        return;
    }
  }

  async command void HW.gps_speed_di(uint32_t speed) {
    const msp432_usci_config_t *config = NULL;

    switch(speed) {
      case    4800:     config =    &gps_4800_config;    break;
      case    9600:     config =    &gps_9600_config;    break;
      case   38400:     config =   &gps_38400_config;    break;
      case  115200:     config =  &gps_115200_config;    break;
      default:          gps_panic(2, speed, 0);          break;

#ifdef notdef
      case   19200:     config =   &gps_19200_config;    break;
      case   57600:     config =   &gps_57600_config;    break;
      case  307200:     config =  &gps_307200_config;    break;
      case  921600:     config =  &gps_921600_config;    break;
      case 1228800:     config = &gps_1228800_config;    break;
#endif
    }
    if (!config)
	gps_panic(3, speed, 0);
    call Usci.configure(config, FALSE);

    /* Usci.configure (via reset) turns off all interrupts and
     * cleans all IFGs out.
     */

  }

  /*
   * enable the rx interrupt.
   * prior to enabling check for any rx errors and clear them if present
   */
  async command void HW.gps_rx_int_enable() {
    uint16_t stat_word;

    atomic {
      stat_word = call Usci.getStat();
      if (stat_word & EUSCI_A_STATW_RXERR)
        call Usci.getRxbuf();
      gps_log_int(GPSI_RX_INT_ON, stat_word, call Usci.getIe());
      m_rx_active = TRUE;               /* really interested. */
      call Usci.enableRxIntr();         /* always turn on */
    }
  }

  async command void HW.gps_rx_int_disable() {
    uint16_t stat_word;

    atomic {
      stat_word = call Usci.getStat();
      m_rx_active = FALSE;
      if ((call Usci.getIe() & EUSCI_A_IE_TXIE) == 0) {   /* tx off? */
        call Usci.disableRxIntr();                        /* yes, turn rx off too */
        gps_log_int(GPSI_RX_INT_OFF, stat_word, call Usci.getIe());
        return;
      }
      /* leave rx intr on for the tx side. */
      gps_log_int(GPSI_RX_INT_OFF, stat_word, 0xff00 | call Usci.getIe());
    }
  }

  async command void HW.gps_clear_rx_errs() {
    call Usci.getRxbuf();
  }

  async command error_t HW.gps_receive_block(uint8_t *ptr, uint16_t len) {
    if (!len || !ptr)
      return FAIL;

    if (m_rx_buf)
      return EBUSY;

    m_rx_len = len;
    m_rx_idx = 0;
    m_rx_buf = ptr;
    call HW.gps_rx_int_enable();
    return SUCCESS;
  }

  async command void    HW.gps_receive_block_stop() {
    m_rx_buf = NULL;
  }

  async command void    HW.gps_rx_off() { }
  async command void    HW.gps_rx_on()  { }

  async command error_t HW.gps_send_block(uint8_t *ptr, uint16_t len) {
    uint16_t stat_word;

    if (!len || !ptr)
      return FAIL;

    if (m_tx_buf)
      return EBUSY;

    m_tx_len = len;
    m_tx_idx = 0;
    m_tx_buf = ptr;
    /*
     * There may be a pending send still in progress, the tail end.
     * If that is the case then TXIFG won't be asserted.  It will assert
     * when TXBUF goes empty and then we can start up this send.
     *
     * So just enable the interrupt and let it fly.
     */
    atomic {
      stat_word = call Usci.getStat();
      if (stat_word & EUSCI_A_STATW_RXERR)
        call Usci.getRxbuf();
      gps_log_int(GPSI_TX_INT_ON, stat_word, call Usci.getIe());
      if (!m_rx_active) {
        gps_log_int(GPSI_RX_INT_ON, stat_word, 0xff00 | call Usci.getIe());
        call Usci.enableRxIntr();
      }
      call Usci.enableTxIntr();
    }
    return SUCCESS;
  }

  async command void    HW.gps_send_block_stop() {
    uint16_t stat_word;

    stat_word = call Usci.getStat();
    gps_log_int(GPSI_TX_INT_OFF, stat_word, call Usci.getIe());
    call Usci.disableTxIntr();
    m_tx_buf = NULL;
  }


  /*
   * capture current GPS USCI state.
   *
   * DESTRUCTIVE.  It pulls IV which modifies h/w state.
   */
  async command void    HW.gps_hw_capture() {
    atomic {
      gps_log_int(GPSI_CAPTURE, call Usci.getStat(), call Usci.getIe());
      gps_log_int(GPSI_CAPTURE, call Usci.getIfg(),  call Usci.getIv());
    }
  }

  /*
   * We need the following conditions to be true to restart the gps
   * tx hw:
   *
   * o in the middle of doing a transmit (m_tx_buf active)
   * o gps_usci->IE says TX is enabled.
   *
   * we clear TXIFG and reassert it.  We we exit we should restart
   * the interrupt stream.
   */
  async command bool    HW.gps_restart_tx() {
    atomic {
      if (m_tx_buf == NULL)
        return FALSE;
      if (m_tx_idx >= m_tx_len)
        return FALSE;
      if ((call Usci.getIe() & EUSCI_A_IE_TXIE) == 0)
        return FALSE;

      /*
       * replace the interrupt by clearing TXIFG and reasserting
       */
      gps_log_int(GPSI_TX_RESTART, call Usci.getStat(), call Usci.getIfg());
      call Usci.disableTxIntr();
      call Usci.clrTxIntr();
      call Usci.setTxIntr();
      call Usci.enableTxIntr();
      gps_log_int(GPSI_TX_RESTART, call Usci.getStat(), call Usci.getIfg());
      return TRUE;
    }
  }

  /*
   * convert a h/w rx err into a gps_rx_err for the upper layers
   */
  uint16_t rx_err2gps_err(uint16_t hw_rx_err) {
    uint16_t gps_err;

    gps_err = 0;
    if (hw_rx_err & EUSCI_A_STATW_FE)
      gps_err |= GPSPROTO_RXERR_FRAMING;
    if (hw_rx_err & EUSCI_A_STATW_OE)
      gps_err |= GPSPROTO_RXERR_OVERRUN;
    if (hw_rx_err & EUSCI_A_STATW_PE)
      gps_err |= GPSPROTO_RXERR_PARITY;
    return gps_err;
  }


  /*
   * WARNING: there is a nasty interaction between the Interrupt system
   * and how the TXIFG works on the eUSCI.  On the way in via interrupt
   * reading the eUSCI->IV register to get the IV clears the highest
   * IFG as well as generates the IV value.  This clears the TXIFG.
   *
   * So if this is the last byte that we are transmitting and we want
   * to turn off the TX interrupt driven system, we now have no TXIFG
   * indicating that the TXBUF is empty.  So how does one start the system
   * back up on the next transmit?  You can try to replace it by
   * writing IFG but that has implications on other parts of the eUSCI
   * race conditions etc.  So we turn off interrupts when the last byte
   * is written to the TXBUF (TXIFG goes down) and signal completion.
   *
   * If we then need to reconfigure and need to make sure that all the
   * bytes have been transmitted, one may need to take up to 2 byte
   * times before complete, one for the byte in the shift register and
   * one for the last byte written.
   */
  async event void Interrupt.interrupted(uint8_t iv) {
    uint16_t stat_word;
    uint8_t data;
    uint8_t *buf;

    switch(iv) {
      case MSP432U_IV_RXIFG:
        /*
         * if m_rx_active is FALSE we are only using the RX interrupt
         * to catch overruns etc.  There seems to be a nasty bit of nonsense
         * where overruns etc. are crashing the tx side.  We are losing
         * tx interrupts.  We are only interested in logging at this point.
         *
         * throw any received characters away.
         */

        /*
         * first check for any rx errors.  If an rx error has messsed with
         * the stream we want to tell the protocol engine and blow things
         * up.
         */
        stat_word = call Usci.getStat();
        if (stat_word & EUSCI_A_STATW_RXERR) {
          /* clear the error and we don't care about the data */
          data = call Usci.getRxbuf();
          gps_log_int(GPSI_RX_ERR, stat_word, call Usci.getIe());
          if (m_rx_active)
            signal HW.gps_rx_err(rx_err2gps_err(stat_word), stat_word);
          return;
        }
        data = call Usci.getRxbuf();

        /*
         * there is an overrun race condition that can occur.
         * the window is between the read of Stat and the read
         * of Rxbuf.  If another byte arrives the serializer can
         * overrun the byte presented in RxBuf.  To detect this
         * we have to read Stat again.
         */
        stat_word = call Usci.getStat();
        if (stat_word & EUSCI_A_STATW_RXERR) {
          data = call Usci.getRxbuf();
          gps_log_int(GPSI_RX_ERR, stat_word, call Usci.getIe());
          if (m_rx_active)
            signal HW.gps_rx_err(rx_err2gps_err(stat_word), stat_word);
          return;
        }

        if (!m_rx_active)
          return;

        if (m_rx_buf) {
          m_rx_buf[m_rx_idx++] = data;
          if (m_rx_idx >= m_rx_len) {
            buf = m_rx_buf;
            m_rx_buf = NULL;
            signal HW.gps_receive_block_done(buf, m_rx_len, SUCCESS);
          }
        } else
          signal HW.gps_byte_avail(data);
        return;

      case MSP432U_IV_TXIFG:
        if (m_tx_buf == NULL) {
          /*
           * this will have the problem of TXIFG being down.
           * just panic to call attention to the issue.
           */
          stat_word = call Usci.getStat();
          gps_log_int(GPSI_TX_INT_OFF, stat_word, call Usci.getIe());
          call Usci.disableTxIntr();
          if (!m_rx_active) {
            gps_log_int(GPSI_RX_INT_OFF, stat_word,
                        0xff00 | call Usci.getIe());
            call Usci.disableRxIntr();
          }
          gps_panic(4, iv, 0);
          return;
        }

        data = m_tx_buf[m_tx_idx++];
        stat_word = call Usci.getStat();
        gps_log_int(GPSI_TX, stat_word, call Usci.getIe());
        call Usci.setTxbuf(data);
        if (m_tx_idx >= m_tx_len) {
          buf = m_tx_buf;
          stat_word = call Usci.getStat();
          gps_log_int(GPSI_TX_INT_OFF, stat_word, call Usci.getIe());
          call Usci.disableTxIntr();
          m_tx_buf = NULL;
          if (!m_rx_active) {
            gps_log_int(GPSI_RX_INT_OFF, stat_word,
                        0xff00 | call Usci.getIe());
            call Usci.disableRxIntr();
          }
          signal HW.gps_send_block_done(buf, m_tx_len, SUCCESS);
        }
        return;

      case MSP432U_IV_NONE:
        break;

      default:
        gps_panic(5, iv, 0);
        break;
    }
  }

  async event void Panic.hook() { }
}
