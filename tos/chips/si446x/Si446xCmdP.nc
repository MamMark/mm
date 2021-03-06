/**
 * Copyright (c) 2015, 2016-2018 Eric B. Decker, Dan J. Maltbie
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
 * Author: Eric B. Decker <cire831@gmail.com>
 *         December 2015.
 * Author: Daniel J. Maltbie <dmaltbie@daloma.org>
 *         May 2017.
 */

/****************************************************************************
 *
 * Si446xCmd should only be called when protected from Radio tasklets.
 * mutual exclusion is provided by code either running at Task level or
 * from within a Tasklet.  Multiple interrupts are protected because they
 * invoke tasklets.  So we must make sure that interrupt code and task
 * level code don't interfer with each other.  See below.
 *
 * The Radio runs its interrupts at tasklet level.  Configuration and
 * other maintanence activities run at Task level.  Task level access
 * should only happen in a protected RadioState which locks out tasklets.
 *
 * The Radio interrupt tasklet lockout happens because there won't be a fsm
 * transition for interrupt events and this will cause a panic.
 *
 * Interrupts are enabled in S_RX_ON, S_RX_ACTIVE, S_TX_ACTIVE, S_CRC_FLUSH
 */


#include <trace.h>
#include <panic.h>
#include <si446x.h>
#include <RadioConfig.h>
#include <wds_configs.h>

#ifndef PANIC_RADIO
enum {
  __pcode_radio = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_RADIO __pcode_radio
#endif


/**************************************************************************/
/*
 * chip debugging
 */

/* radio pending state trace array
 */
#define  RPS_MAX 64
norace uint16_t rps_next, rps_prev;
norace rps_t    rps[RPS_MAX];

/* SPI trace buffer
 */
#define SPI_TRACE_MAX 200
norace   uint16_t           g_radio_spi_trace_next,
                            g_radio_spi_trace_prev,
                            g_radio_spi_trace_count;
norace   spi_trace_desc_t   g_radio_spi_trace[SPI_TRACE_MAX];
const    uint16_t           g_radio_spi_trace_max = SPI_TRACE_MAX;

/* radio configuration/status dump
 */
norace radio_dump_t g_radio_dump;


/* specify which radio property groups to dump
 */
const dump_prop_desc_t g_dump_group_list[] = {
  { 0x0000, (void *) &g_radio_dump.GLOBAL,         SI446X_GROUP00_SIZE },
  { 0x0100, (void *) &g_radio_dump.INT_CTL,        SI446X_GROUP01_SIZE },
  { 0x0200, (void *) &g_radio_dump.FRR_CTL,        SI446X_GROUP02_SIZE },
  { 0x1000, (void *) &g_radio_dump.PREAMBLE,       SI446X_GROUP10_SIZE },
  { 0x1100, (void *) &g_radio_dump.SYNC,           SI446X_GROUP11_SIZE },
  { 0x1200, (void *) &g_radio_dump.PKT,            SI446X_GROUP12_SIZE },
#ifdef SI446X_GROUP12a_SIZE
  { 0x1221, (void *) &g_radio_dump.gr12a_pkt,      SI446X_GROUP12a_SIZE },
#endif
  { 0x2000, (void *) &g_radio_dump.MODEM,          SI446X_GROUP20_SIZE },
  { 0x2100, (void *) &g_radio_dump.MODEM_CHFLT,    SI446X_GROUP21_SIZE },
  { 0x2200, (void *) &g_radio_dump.PAx,            SI446X_GROUP22_SIZE },
  { 0x2300, (void *) &g_radio_dump.SYNTH,          SI446X_GROUP23_SIZE },
  { 0x3000, (void *) &g_radio_dump.MATCH,          SI446X_GROUP30_SIZE },
  { 0x4000, (void *) &g_radio_dump.FREQ_CONTROL,   SI446X_GROUP40_SIZE },
  { 0x5000, (void *) &g_radio_dump.RX_HOP,         SI446X_GROUP50_SIZE },
//  { 0xF000, (void *) &g_radio_dump.grF0_pti,      SI446X_GROUPF0_SIZE },
  { 0, NULL, 0 },
};


/* temporary buffer for reading chip state
 */
volatile norace si446x_chip_all_t  chip_debug;


/* rf_frr_ctl_a_mode_4 defines what the four FRR registers return
 * and how they show up in radio_pend
 */
norace uint8_t radio_pend[4];
norace uint8_t radio_pend1[4];

/* temporary buffer for response to send.cmd()
 */
norace uint8_t      radio_rsp[16];

/* array of timing measurements for each possible chip command and property.
 * contains the value measured when last used
 */
norace cmd_timing_t  cmd_timings[256];
norace cmd_timing_t prop_timings[256];


/**************************************************************************/
/*
 * Radio Commands
 */

const uint8_t si446x_part_info[]     = { SI446X_CMD_PART_INFO };    /* 01 */
const uint8_t si446x_func_info[]     = { SI446X_CMD_FUNC_INFO };    /* 10 */
const uint8_t si446x_gpio_cfg_nc[]   = { SI446X_CMD_GPIO_PIN_CFG,   /* 13 */
  SI446X_GPIO_NO_CHANGE, SI446X_GPIO_NO_CHANGE,
  SI446X_GPIO_NO_CHANGE, SI446X_GPIO_NO_CHANGE,
  SI446X_GPIO_NO_CHANGE,                /* nirq, no change */
  SI446X_GPIO_NO_CHANGE,                /* sdo, no change */
  0                                     /* gen_config */
};

const uint8_t si446x_fifo_info_nc[]  = { SI446X_CMD_FIFO_INFO, 0 }; /* 15 */

const uint8_t si446x_packet_info_nc[]= { SI446X_CMD_PACKET_INFO };  /* 16 */

const uint8_t si446x_int_status_nc[] = { SI446X_CMD_GET_INT_STATUS, /* 20 */
  SI446X_INT_NO_CLEAR, SI446X_INT_NO_CLEAR, SI446X_INT_NO_CLEAR };

const uint8_t si446x_int_clr[] = { SI446X_CMD_GET_INT_STATUS };     /* 20 */

const uint8_t si446x_ph_status_nc[] = {                             /* 21 */
  SI446X_CMD_GET_PH_STATUS, SI446X_INT_NO_CLEAR };

const uint8_t si446x_ph_clr[] = { SI446X_CMD_GET_PH_STATUS};        /* 21 */

const uint8_t si446x_modem_status_nc[] = {                          /* 22 */
  SI446X_CMD_GET_MODEM_STATUS, SI446X_INT_NO_CLEAR };

const uint8_t si446x_modem_clr[] = { SI446X_CMD_GET_MODEM_STATUS }; /* 22 */

const uint8_t si446x_chip_status_nc[] = {                           /* 23 */
  SI446X_CMD_GET_CHIP_STATUS, SI446X_INT_NO_CLEAR };

const uint8_t si446x_chip_clr[] = { SI446X_CMD_GET_CHIP_STATUS };   /* 23 */

const uint8_t si446x_chip_clr_cmd_err[] = { SI446X_CMD_GET_CHIP_STATUS, 0xf7 };

const uint8_t si446x_device_state[] = { SI446X_CMD_REQUEST_DEVICE_STATE }; /* 33 */

const uint8_t start_rx_short_cmd[] = {  SI446X_CMD_START_RX };

/*
 * len: 0, use variable length in packet
 * rxtimeout_state: 10, idle state is used by preamble sense mode
 * rxvalid_state:    6, goto ready state.
 * rxinvalid_state:  6, goto ready state.
 */
const uint8_t start_rx_cmd[] = {
  SI446X_CMD_START_RX,
  0,                                  /* channel */
  0,                                  /* start immediate */
  0, 0,                               /* len, use variable length */
//  RC_NO_CHANGE,                       /* rxtimeout, stay, good boy */
  RC_IDLE,                            /* rxtimeout, stay, Preamble Sense */
  RC_READY,                           /* rxvalid */
  RC_READY,                           /* rxinvalid */
};

/*
 * FRR_CTL_A_MODE (p0200)
 *
 * frr is set manually right after POWER_UP, will not be changed by any
 * subsequent radio configuration.
 *
 * A: device state
 * B: PH_PEND
 * C: MODEM_PEND
 * D: Latched_RSSI
 *
 * We use LR (Latched_RSSI) when receiving a packet.  The RSSI value is
 * attached to the last RX packet.  The Latched_RSSI value may (depending on
 * configuration, be associated with some number of bit times once RX is enabled
 * or when SYNC is detected.
 */
const uint8_t si446x_frr_config[] = { 0x11, 0x02, 0x04, 0x00,
                                      SI446X_FRR_MODE_CURRENT_STATE,
                                      SI446X_FRR_MODE_PACKET_HANDLER_INTERRUPT_PENDING,
                                      SI446X_FRR_MODE_MODEM_INTERRUPT_PENDING,
                                      SI446X_FRR_MODE_LATCHED_RSSI
                                    };

/**************************************************************************/

module Si446xCmdP {
  provides {
    interface Si446xCmd;
  }
  uses {
    interface FastSpiByte;
    interface SpiByte;
    interface SpiBlock;

    interface Si446xInterface as HW;

    interface Platform;
    interface Trace;
    interface Panic;
  }
}
implementation {
#define __PANIC_RADIO(where, w, x, y, z) do {             \
    call Panic.panic(PANIC_RADIO, where, w, x, y, z);     \
  } while (0);

  /**************************************************************************/
  /*
   * CCA: note!  The SiLabs folks flip the sense of CCA.  CCA for them
   * is true if the channel is busy.  Other folks (the reasonable ones)
   * consider CCA TRUE if the channel is clear.  We handle this in check_CCA().
   *
   * si446x_cca_threshold is where we hold the value we program the h/w
   * RSSI_THRESHOLD.  We use it to compare received RSSI values to determine
   * whether the channel is busy.
   */
  uint8_t si446x_cca_threshold = SI446X_INITIAL_RSSI_THRESH;


  /**************************************************************************/
  /*
   * Trace Radio SPI bus transfer event
   */
  void ll_si446x_spi_trace(spi_trace_record_t op, uint8_t id, uint8_t *b, uint16_t l) {
    spi_trace_desc_t    *rspi;
    uint16_t            x;

    if ((op == SPI_REC_UNDEFINED) || (op >= SPI_REC_LAST)) {
      __PANIC_RADIO(20, op, id, l, 0);
    }
    rspi = &g_radio_spi_trace[g_radio_spi_trace_next];
    rspi->timestamp = call Platform.usecsRaw();
    rspi->op = op;
    rspi->struct_id = id;
    rspi->length = l;
    if (l > SPI_TRACE_BUF_MAX) l = SPI_TRACE_BUF_MAX;
    for (x = 0; x < l; x++)
      rspi->buf[x] = b[x];
    g_radio_spi_trace_prev = g_radio_spi_trace_next;
    if (++g_radio_spi_trace_next >= g_radio_spi_trace_max) {
      g_radio_spi_trace_next = 0;
    }
    g_radio_spi_trace_count++;
    rspi = &g_radio_spi_trace[g_radio_spi_trace_next];
    rspi->timestamp = 0;
    rspi->op = SPI_REC_UNDEFINED;
  }


  /**************************************************************************/
  /*
   * ll_si446x_trace
   */
  uint8_t trace_predicate = 0x10;       /* no tracing */

#define TRACE_MUMBLE   1
#define TRACE_WHISPER  2
#define TRACE_TALK     4
#define TRACE_SHOUT    8

  void ll_si446x_trace(trace_where_t where, uint32_t r0, uint32_t r1) {
    uint8_t    level;

    switch (where) {
      case T_RC_SHUTDOWN:
      case T_RC_UNSHUTDOWN:
      case T_RC_CHECK_CCA:
      case T_DL_TRANS_ST:
      case T_RC_WAIT_CTS_F:
      default:
        level = TRACE_MUMBLE;
        break;

      case T_RC_CHG_STATE:
      case T_DL_INTERRUPT:
      case T_RC_INTERRUPT:
        level = TRACE_WHISPER;
        break;

      case T_RC_FIFO_INFO:
      case T_RC_GET_PKT_INF:
      case T_RC_READ_PROP:
      case T_RC_SET_PROP:
      case T_RC_READ_RX_FF:
      case T_RC_WRITE_TX_FF:
      case T_RC_SEND_CMD:
      case T_RC_CMD_REPLY:
      case T_RC_GET_REPLY:
      case T_RC_WAIT_CTS:
        level = TRACE_TALK;
        break;

      case T_RC_DIS_INTR:
      case T_RC_DRF_ALL:
      case T_RC_ENABLE_INT:
      case T_RC_DUMP_PROPS:
      case T_RC_DUMP_RADIO:
      case T_RC_DUMP_FIFO:
        level = TRACE_SHOUT;
        break;
    }
    if ((!trace_predicate) || (level & trace_predicate))
      call Trace.trace(where, r0, r1);
  }


  /**************************************************************************/
  /*
   * ll_si446x_get_sw_cts
   *
   * get the status of the chip CTS by SPI command rather than hardware pin
   *
   */
  uint8_t ll_si446x_get_sw_cts() {
    uint8_t res;

    /* clear cs on entry prior to set,  make sure a reasonable state */
    call HW.si446x_clr_cs();
    call HW.si446x_set_cs();
    call FastSpiByte.splitWrite(SI446X_CMD_READ_CMD_BUFF);
    call FastSpiByte.splitReadWrite(0);
    res = call FastSpiByte.splitRead();
    call HW.si446x_clr_cs();
    return res;
  }

  /**************************************************************************/
  /*
   * ll_si446x_get_cts
   *
   * encapsulate obtaining the current CTS value.
   *
   * CTS can be on a h/w pin or can be obtained via the SPI
   * bus.  This routine hides how it is obtained.
   */
  bool ll_si446x_get_cts() {
    bool    cts_s;

    if (call Si446xCmd.is_hw_cts_enabled())
      cts_s = call HW.si446x_cts();
    else
      cts_s = ll_si446x_get_sw_cts();
    return cts_s;
  }


  /**************************************************************************/
  /*
   * ll_si446x_read_frr             (low level)
   *
   * read Fast Response Register.
   * input parameter selects one of four.
   */
  uint8_t ll_si446x_read_frr(uint8_t which) {
    uint8_t result;

    call HW.si446x_clr_cs();             // make sure reasonable state
    call HW.si446x_set_cs();
    call FastSpiByte.splitWrite(which);  // which one is the input parameter
    result = call FastSpiByte.splitReadWrite(0);
    result = call FastSpiByte.splitRead();
    call HW.si446x_clr_cs();
    ll_si446x_spi_trace(SPI_REC_READ_FRR, 0, &result, 1);
    return result;
  }


  /**************************************************************************/
  /*
   * ll_si446x_trace_radio_pend     {low level)
   *
   * trace current radio interrupt status and hardware related pin state
   */
  void ll_si446x_trace_radio_pend(uint8_t *pend) {
    rps_t *rpp;
    rps_t *ppp;
    uint8_t cts, irqn, csn;
    uint8_t state, ph, modem, rssi, pmodem;

    rpp  = &rps[rps_next];
    ppp  = &rps[rps_prev];

    cts  = ll_si446x_get_cts();
    irqn = call HW.si446x_irqn();
    csn  = call HW.si446x_csn();

    /* we don't care about modem:invalid preamble
     */
    state = pend[0];
    ph    = pend[1];
    rssi  = pend[3];
    modem  = pend[2] & 0xfb;
    pmodem = ppp->modem & 0xfb;

    if ((cts == ppp->cts) && (irqn == ppp->irqn) && (csn == ppp->csn) &&
        (state == ppp->ds) && (ph == ppp->ph) &&
        (modem == pmodem) && (rssi == ppp->rssi)) {
      return;
    }

    modem = pend[2];                    /* trace actual values */
    rssi  = pend[3];
    rpp->ts = call Platform.usecsRaw();
    rpp->cts   = cts;
    rpp->irqn  = irqn;
    rpp->csn   = csn;
    rpp->ds    = state;
    rpp->ph    = ph;
    rpp->modem = modem;
    rpp->rssi  = rssi;

    rps_prev = rps_next;
    if (++rps_next >= RPS_MAX)
      rps_next = 0;
  }


  /**************************************************************************/
  /*
   * ll_si446x_read_fast_status    (low level)
   *
   * reads status of important chip information via the FRR mechanism.
   * input is a pointer to uint8_t xyz[4] buffer
   *
   * CTS does not need to be true.
   */
  void ll_si446x_read_fast_status(void *s) {
    uint8_t *p;

    p = (uint8_t *) s;
    call HW.si446x_set_cs();
    call FastSpiByte.splitWrite(SI446X_CMD_FRR_A);
    call FastSpiByte.splitReadWrite(0);
    p[0] = call FastSpiByte.splitReadWrite(0);
    p[1] = call FastSpiByte.splitReadWrite(0);
    p[2] = call FastSpiByte.splitReadWrite(0);
    p[3] = call FastSpiByte.splitRead();
    call HW.si446x_clr_cs();
    ll_si446x_spi_trace(SPI_REC_READ_FRR, 0, p, 4);
  }


  /**************************************************************************/
  /*
   * ll_si446x_send_cmd      (low level)
   *
   * send a command to the radio chip
   *
   * c:         pointer to buffer to send
   * response:  pointer to response bytes if any
   * cl:        length of cmd (buffer)
   *
   */
  void ll_si446x_send_cmd(const uint8_t *c, uint16_t cl) {
    uint32_t      t0, t1;
    cmd_timing_t *ctp;
    uint8_t       cmd;
    bool          done;

    cmd = c[0];
    ctp = &cmd_timings[cmd];
    ctp->cmd = cmd;
    done = 0;
    while (1) {
      ctp->t_started = call Platform.usecsRaw();
      t0 = t1 = ctp->t_started;
      while (!ll_si446x_get_cts()) {
        t1 = call Platform.usecsRaw();
        if ((t1-t0) > SI446X_CTS_TIMEOUT) {
          done = ll_si446x_get_sw_cts();
          __PANIC_RADIO(2, t1, t0, t1-t0, done);
        }
      }
      /*
       * first make sure we still have CTS.  It is possible that
       * someone (mr. interupt) got in and did something that made
       * us busy.  Truely paranoid code but if we ever hit this
       * window the failure is truely nasty.  And it is possible.
       * close to 0 but not zero.
       */
      if (ll_si446x_get_cts()) {
        t1 = call Platform.usecsRaw();
        ctp->t_cts0 = t1 - t0;
        t0 = t1;
        call HW.si446x_set_cs();
        call SpiBlock.transfer((void *) c, radio_rsp, cl);
        call HW.si446x_clr_cs();
        t1 = call Platform.usecsRaw();
        done = TRUE;
      }
      if (done) {
        ll_si446x_spi_trace(SPI_REC_SEND_CMD, c[0], (void *)c, cl);
        break;
      }

      /*
       * oops.  if we get here someone grabbed the channel (mr. interrupt)
       * so go try again to make sure the radio is okay to take another big one.
       */
    }
    ctp->t_cmd0 = t1 - t0;
    ctp->d_len0 = cl;
    ll_si446x_trace(T_RC_SEND_CMD, cmd, t1-t0);
  }


  /**************************************************************************/
  /*
   * ll_si446x_get_reply        (low level)
   *
   * get chip data returned in response to last command.
   */
  void ll_si446x_get_reply(uint8_t *r, uint16_t l, uint8_t cmd) {
    uint8_t rcts;
    uint32_t t0, t1;
    cmd_timing_t *ctp;

    ctp = &cmd_timings[cmd];
    t0 = call Platform.usecsRaw();
    while (!ll_si446x_get_cts()) {
      t1 = call Platform.usecsRaw();
      if ((t1-t0) > SI446X_CTS_TIMEOUT) {
        __PANIC_RADIO(4, t1, t0, t1-t0, 0);
      }
    }
    t1 = call Platform.usecsRaw();
    ctp->t_cts_r = t1 - t0;
    t0 = t1;
    call HW.si446x_set_cs();
    call FastSpiByte.splitWrite(SI446X_CMD_READ_CMD_BUFF);
    call FastSpiByte.splitReadWrite(0);
    rcts = call FastSpiByte.splitRead();
    if (rcts != 0xff) {
      __PANIC_RADIO(5, rcts, 0, 0, 0);
    }
    call SpiBlock.transfer(NULL, r, l);
    call HW.si446x_clr_cs();
    t1 = call Platform.usecsRaw();
    ctp->t_reply = t1 - t0;
    ctp->d_reply_len = l + 2;
    ctp->t_elapsed = t1 - ctp->t_started;
    ll_si446x_spi_trace(SPI_REC_GET_REPLY, cmd, r, l);
    ll_si446x_trace(T_RC_GET_REPLY, cmd, t1-t0);
  }


  /**************************************************************************/
  /*
   * ll_si446x_cmd_reply        (low level)
   *
   * perform combined send_cmd and get_reply operations.
   */
  void ll_si446x_cmd_reply(const uint8_t *cp, uint16_t cl, uint8_t *rp, uint16_t rl) {
    cmd_timing_t *ctp;

    ctp = &cmd_timings[cp[0]];
    ll_si446x_send_cmd(cp, cl);
    ll_si446x_get_reply(rp, rl, cp[0]);
    ll_si446x_read_fast_status(ctp->frr);
    ll_si446x_trace(T_RC_CMD_REPLY, cp[0], ctp->t_elapsed);
  }


  /**************************************************************************/
  /*
   * get current chip state -> *allp
   *
   * This is debug code for observing most of the chip state.
   */
  void ll_si446x_get_all_state(volatile si446x_chip_all_t *allp) {
    uint8_t pends[4];

    ll_si446x_cmd_reply(si446x_ph_status_nc, sizeof(si446x_ph_status_nc),
                        (void *) &allp->ph, SI446X_PH_STATUS_REPLY_SIZE);
    ll_si446x_cmd_reply(si446x_modem_status_nc, sizeof(si446x_modem_status_nc),
                        (void *) &allp->modem, SI446X_MODEM_STATUS_REPLY_SIZE);
    ll_si446x_cmd_reply(si446x_chip_status_nc, sizeof(si446x_chip_status_nc),
                        (void *) &allp->chip, SI446X_CHIP_STATUS_REPLY_SIZE);
    ll_si446x_cmd_reply(si446x_int_status_nc, sizeof(si446x_int_status_nc),
                        (void *) &allp->ints, SI446X_INT_STATUS_REPLY_SIZE);
    pends[DEVICE_STATE] = ll_si446x_read_frr(SI446X_GET_DEVICE_STATE);
    pends[PH_STATUS]    = allp->ph.pend;
    pends[MODEM_STATUS] = allp->modem.pend;
    pends[LATCHED_RSSI] = allp->modem.latched_rssi;
    ll_si446x_trace_radio_pend(pends);
  }


  /**************************************************************************/
  /*
   * ll_si446x_check_weird
   *
   * check for abnormal conditions when performing radio chip operations.
   */
  void ll_si446x_check_weird(uint8_t *status) {
    if ((status[PH_STATUS]    & 0xC0) ||
        (status[MODEM_STATUS] & 0x40)) {
      //        (status[MODEM_STATUS] & 0x50)) {
      ll_si446x_get_all_state(&chip_debug);
      __PANIC_RADIO(98, status[DEVICE_STATE], status[PH_STATUS],
                    status[MODEM_STATUS], 0);
      ll_si446x_get_all_state(&chip_debug);
    }
  }


  /**************************************************************************/
  /*
   * readBlock
   * pullBlock
   * writeBlock
   *
   * Basic SPI Access Routines
   */

  /* read from the SPI, putting bytes in buf
   */
  void readBlock(uint8_t *buf, uint8_t count) {
    uint8_t i;

    for (i = 0; i < count-1; i++)
      buf[i] = call FastSpiByte.splitReadWrite(0);
    buf[i] = call FastSpiByte.splitRead();
  }

  /* pull bytes from the SPI, throwing them away
   */
  void pullBlock(uint8_t count) {
    uint8_t i;

    for (i = 1; i < count; i++)
      call FastSpiByte.splitReadWrite(0);
    call FastSpiByte.splitRead();
  }

  /* write bytes from buf to the SPI
   */
  void writeBlock(uint8_t *buf, uint8_t count) {
    uint8_t i;

    for (i = 0; i < count; i++)
      call FastSpiByte.splitReadWrite(buf[i]);
    call FastSpiByte.splitRead();
  }


  /**************************************************************************/
  /*
   * ll_446x_dump_radio_fifo
   *
   * It is unclear if dumping the FIFO is a) possible or b) useful.
   */
  void ll_i446x_dump_radio_fifo() {
    uint8_t cts, rx_count, tx_count;
    uint32_t t0;

    /*
     * CSn (NSEL), needs to be held high (deasserted, cleared) for 80ns.
     *
     * We used to use a nop to make sure we hold this up long enough,
     * however nop is dangerous.  cpu dependent and may or maynot do
     * anything.
     *
     * A better solution is to use Platform.usecsRaw which is required
     * to be correct for each platform if implemented (required for us).
     * We use 2 because we don't know where in the current usec window
     * we are currently and want at least 80ns.  This will give us at
     * least 1us.
     */
    call HW.si446x_clr_cs();
    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < 2) ;
    call HW.si446x_set_cs();
    call FastSpiByte.splitWrite(SI446X_CMD_FIFO_INFO);
    call FastSpiByte.splitReadWrite(0);
    call FastSpiByte.splitRead();
    /* response
     */
    call FastSpiByte.splitWrite(0);
    cts = call FastSpiByte.splitReadWrite(0);           /* CTS */
    rx_count = call FastSpiByte.splitReadWrite(0);      /* RX_FIFO_CNT */
    tx_count = call FastSpiByte.splitRead();            /* TX_FIFO_CNT */
    call HW.si446x_clr_cs();

    /*
     * how to figure out if it is a tx or rx in the fifo.  So
     * we can pull the fifo contents.  Do we need to look at the
     * radio state to see what is going on?
     */
    if (tx_count < rx_count)
      tx_count = rx_count;
    ll_si446x_trace(T_RC_DUMP_FIFO, 0, 0);
  }


  /**************************************************************************/
  /*
   * ll_si446x_dump_properties
   *
   * read and save all relevant properties from radio chip.
   */
  void ll_si446x_dump_properties() {
    const dump_prop_desc_t *dpp;
    cmd_timing_t *ctp, *ctp_ff;
    uint8_t group, idx, length;
    uint8_t  *w, wl;                    /* working */
    uint32_t t0, t1, tot0;

    ll_si446x_trace(T_RC_DUMP_PROPS, 0, 0);
    ctp_ff = &cmd_timings[0xff];
    t0 = call Platform.usecsRaw();
    while (!ll_si446x_get_cts()) {
      t1 = call Platform.usecsRaw();
      if ((t1-t0) > SI446X_CTS_TIMEOUT) {
        __PANIC_RADIO(8, t1, t0, t1-t0, 0);
      }
    }
    t1 = call Platform.usecsRaw();
    dpp = &g_dump_group_list[0];
    while (dpp->where) {
      group = dpp->prop_id >> 8;
      idx = dpp->prop_id & 0xff;
      length = dpp->length;
      w = dpp->where;
      t0 = call Platform.usecsRaw();
      tot0 = t0;
      ctp = &prop_timings[group];
      memset(ctp, 0, sizeof(*ctp));
      ctp->cmd = group;

      while (length) {
        t0 = call Platform.usecsRaw();
        if (!ll_si446x_get_cts()) {
          __PANIC_RADIO(9, 0, 0, 0, 0);
        }
        t1 = call Platform.usecsRaw();
        ctp->t_cts0 += t1 - t0;

        wl = (length > 16) ? 16 : length;
        t0 = call Platform.usecsRaw();
        call HW.si446x_set_cs();
        call FastSpiByte.splitWrite(SI446X_CMD_GET_PROPERTY);
        call FastSpiByte.splitReadWrite(group);
        call FastSpiByte.splitReadWrite(wl);
        call FastSpiByte.splitReadWrite(idx);
        call FastSpiByte.splitRead();
        call HW.si446x_clr_cs();
        t1 = call Platform.usecsRaw();
        ctp->t_cmd0 += t1 - t0;
        ctp->d_len0 += 4;

        ll_si446x_get_reply(w, wl, group);
        ctp->t_cts_r     += ctp_ff->t_cts_r;
        ctp->t_reply     += ctp_ff->t_reply;
        ctp->d_reply_len += ctp_ff->d_reply_len;
        length -= wl;
        idx += wl;
        w += wl;
      }
      t1 = call Platform.usecsRaw();
      ctp->t_elapsed = t1 - tot0;
      ll_si446x_read_fast_status(ctp->frr);
      dpp++;
    }
  }


  /**************************************************************************/
  /*
   * ll_si446x_drf
   *
   * dump full radio configuration and state.
   */
  void ll_si446x_drf() {
    uint32_t t0;

    ll_si446x_trace(T_RC_DRF_ALL, 0, 0);
    g_radio_dump.dump_start = call Platform.usecsRaw();

    /* do CSN before we reset the SPI port */
    g_radio_dump.CSN_pin     = call HW.si446x_csn();
    g_radio_dump.CTS_pin     = call HW.si446x_cts();
    g_radio_dump.IRQN_pin    = call HW.si446x_irqn();
    g_radio_dump.SDN_pin     = call HW.si446x_sdn();

    /*
     * make sure we don't violate the CS hold time of 80ns.  We use
     * 1us because we have the technology via Platform.usecsRaw.
     */
    call HW.si446x_clr_cs();          /* reset SPI on chip */
    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < 2) ;

    call HW.si446x_set_cs();
    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < 2) ;

    call HW.si446x_clr_cs();
    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < 2) ;

    g_radio_dump.cap_val     = call HW.si446x_cap_val();
    g_radio_dump.cap_control = call HW.si446x_cap_control();

    ll_si446x_cmd_reply(si446x_part_info, sizeof(si446x_part_info),
                        (void *) &g_radio_dump.part_info, SI446X_PART_INFO_REPLY_SIZE);

    ll_si446x_cmd_reply(si446x_func_info, sizeof(si446x_func_info),
                        (void *) &g_radio_dump.func_info, SI446X_FUNC_INFO_REPLY_SIZE);

    ll_si446x_cmd_reply(si446x_gpio_cfg_nc, sizeof(si446x_gpio_cfg_nc),
                        (void *) &g_radio_dump.gpio_cfg, SI446X_GPIO_CFG_REPLY_SIZE);

    ll_si446x_cmd_reply(si446x_fifo_info_nc, sizeof(si446x_fifo_info_nc),
                        radio_rsp, SI446X_FIFO_INFO_REPLY_SIZE);
    g_radio_dump.rxfifocnt  = radio_rsp[0];
    g_radio_dump.txfifofree = radio_rsp[1];

    ll_si446x_cmd_reply(si446x_ph_status_nc, sizeof(si446x_ph_status_nc),
                        (void *) &g_radio_dump.ph_status, SI446X_PH_STATUS_REPLY_SIZE);

    ll_si446x_cmd_reply(si446x_modem_status_nc, sizeof(si446x_modem_status_nc),
                        (void *) &g_radio_dump.modem_status, SI446X_MODEM_STATUS_REPLY_SIZE);

    ll_si446x_cmd_reply(si446x_chip_status_nc, sizeof(si446x_chip_status_nc),
                        (void *) &g_radio_dump.chip_status, SI446X_CHIP_STATUS_REPLY_SIZE);

    ll_si446x_cmd_reply(si446x_int_status_nc, sizeof(si446x_int_status_nc),
                        (void *) &g_radio_dump.int_state, SI446X_INT_STATUS_REPLY_SIZE);

    ll_si446x_cmd_reply(si446x_device_state, sizeof(si446x_device_state),
                        radio_rsp, SI446X_DEVICE_STATE_REPLY_SIZE);
    g_radio_dump.device_state = radio_rsp[0];
    g_radio_dump.channel      = radio_rsp[1];

    ll_si446x_read_fast_status(g_radio_dump.frr);

    ll_si446x_cmd_reply(si446x_packet_info_nc, sizeof(si446x_packet_info_nc),
                        (void *) &g_radio_dump.packet_info_len, SI446X_PACKET_INFO_REPLY_SIZE);

    ll_si446x_dump_properties();
    g_radio_dump.dump_end = call Platform.usecsRaw();
    g_radio_dump.delta =  g_radio_dump.dump_end - g_radio_dump.dump_start;
  }


  /**************************************************************************/
  /*
   * ll_wait_for_cts
   *
   * wait for the radio chip to report that it is ready for the next command.
   */
  bool ll_wait_for_cts() {
    uint32_t t0, t1;

    t0 = call Platform.usecsRaw();
    t1 = t0;
    while (!ll_si446x_get_cts()) {
      t1 = call Platform.usecsRaw();
      ll_si446x_read_fast_status(radio_pend);
      if ((t1-t0) > SI446X_CTS_TIMEOUT) {
        ll_si446x_read_fast_status(radio_pend1);
        ll_si446x_trace(T_RC_WAIT_CTS_F, radio_pend1[0], t1-t0);
#ifdef notdef
        ll_si446x_drf();
        __PANIC_RADIO(24, t1, t0, t1-t0, 0);
#endif
        ll_si446x_read_fast_status(radio_pend);
        return FALSE;
      }
    }
    ll_si446x_read_fast_status(radio_pend);
    return TRUE;
  }


  /**************************************************************************/
  /*
   * HW.interrupt
   */
  async event void HW.si446x_interrupt() {
    uint8_t        status[4];

    ll_si446x_read_fast_status(status);
    ll_si446x_trace(T_RC_INTERRUPT,
                    (status[0] << 8) | status[1],
                    (status[2] << 8) | status[3]
                    );
    signal Si446xCmd.interrupt();
  }


  /**************************************************************************/
  /*
   * Si446xCmd.enable_hw_cts
   * Si446xCmd.disable_hw_cts
   * is_hw_cts_enabled
   *
   * Enable/Disable use of the GPIO hardware pin for detecting
   * radio chip has completed last command and is ready for a new one.
   *
   */
  norace bool si446x_hw_cts_enabled;

  async command void Si446xCmd.enable_hw_cts() {
    si446x_hw_cts_enabled = TRUE;
  }

  async command void Si446xCmd.disable_hw_cts() {
    si446x_hw_cts_enabled = FALSE;
  }

  async command bool Si446xCmd.is_hw_cts_enabled() {
    return si446x_hw_cts_enabled;
  }

  /**************************************************************************/
  /*
   * Si446xCmd.change_state
   *
   * Force radio chip to the specified state.
   *
   * @param     state       new state to enter
   *
   * @return    final state achieved
   */

  async command si446x_device_state_t Si446xCmd.change_state(si446x_device_state_t state, bool wait) {
    uint8_t cmd[2];
    uint8_t ro, rn;

    cmd[0] = SI446X_CMD_CHANGE_STATE;
    cmd[1] = state;                          // new state
    ro = call Si446xCmd.fast_device_state();
    ll_si446x_send_cmd(cmd, sizeof(cmd));
    if (wait)
      ll_wait_for_cts();           // wait for command to complete
    rn = call Si446xCmd.fast_device_state();
    ll_si446x_trace(T_RC_CHG_STATE, ro, rn);
    return rn;
  }


  /**************************************************************************/
  /*
   * Si446xCmd.goto_sleep
   *
   * Force radio chip into low power operation (retains registers but
   * receiver is off).
   *
   */

  async command void Si446xCmd.goto_sleep() {
    uint8_t cmd[2];


    cmd[0] = SI446X_CMD_CHANGE_STATE;
    cmd[1] = RC_SLEEP;
    call Si446xCmd.fast_device_state();
    ll_si446x_send_cmd(cmd, sizeof(cmd));
    ll_si446x_trace(T_RC_CHG_STATE, 0, 0);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.check_CCA
   *
   * check the 'clear channel assessment' condition. denotes if our receiver
   * is detecting an incoming radio signal of sufficient strength to denote
   * channel is occupied.
   * returns true if channel is assessed as clear (low RSSI value)
   */
  async command bool Si446xCmd.check_CCA() {
    uint8_t rssi;
    bool    r;

    rssi = call Si446xCmd.fast_latched_rssi();
    r = (rssi < si446x_cca_threshold) ? (TRUE) : (FALSE);
    ll_si446x_trace(T_RC_CHECK_CCA, r, 0);
    return r;
  }


  /**************************************************************************/
  /*
   * Si446xCmd.clr_cs
   */
  async command void          Si446xCmd.clr_cs() {
    call HW.si446x_clr_cs();
  }


  /**************************************************************************/
  /*
   * Si446xCmd.config_frr
   *
   * configure the Fast Response Registers per the device driver needs.
   */
  async command void Si446xCmd.config_frr() {
    ll_si446x_send_cmd(si446x_frr_config, sizeof(si446x_frr_config));
  }


  /**************************************************************************/
  /*
   * Si446xCmd.dump_radio
   */
  async command void Si446xCmd.dump_radio() {
    ll_si446x_drf();
    ll_si446x_trace(T_RC_DUMP_RADIO, 0, 0);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.enableInterrupt
   * Si446xCmd.disableInterrupt
   * Si446xCmd.isInterruptEnabled
   */
  async command void Si446xCmd.enableInterrupt() {
    call HW.si446x_enableInterrupt();
    ll_si446x_trace(T_RC_ENABLE_INT, 0, 0);
  }

  async command void Si446xCmd.disableInterrupt() {
    call HW.si446x_disableInterrupt();
    ll_si446x_trace(T_RC_DIS_INTR, 0, 0);
  }

  async command bool Si446xCmd.isInterruptEnabled() {
    return call HW.si446x_isInterruptEnabled();
  }


  /**************************************************************************/
  /*
   * Si446xCmd.fast_device_state
   * uint8_t Si446xCmd.fast_ph_pend
   * Si446xCmd.fast_modem_pend
   * Si446xCmd.fast_latched_rssi
   *
   * read Fast Response Register.
   * register comes back on the same SPI transaction as the command.
   * CTS does not need to be true.
   *
   */
  async command uint8_t Si446xCmd.fast_device_state() {
    return ll_si446x_read_frr(SI446X_GET_DEVICE_STATE);
  }

  async command uint8_t Si446xCmd.fast_ph_pend() {
    return ll_si446x_read_frr(SI446X_GET_PH_PEND);
  }

  async command uint8_t Si446xCmd.fast_modem_pend() {
    return ll_si446x_read_frr(SI446X_GET_MODEM_PEND);
  }

  async command uint8_t Si446xCmd.fast_latched_rssi() {
    return ll_si446x_read_frr(SI446X_GET_LATCHED_RSSI);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.fast_all
   *
   * read the fast status registers.
   * trace the status and check for abnormal conditions.
   */
  async command void Si446xCmd.fast_all(uint8_t *status) {
    ll_si446x_read_fast_status(status);
    ll_si446x_trace_radio_pend(status);
    ll_si446x_check_weird(status);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.fifo_info
   *
   * retreive current receive/transmit fifo status and optionally flush.
   * can pass null pointers for status if just flushing.
   * individual flags specify whether to flush one, both, or neither fifo.
   */
  async command void Si446xCmd.fifo_info(uint16_t *rxp, uint16_t *txp, uint8_t flush_bits) {
    uint8_t flusher[2], fifo_cnts[2];

    flusher[0] = SI446X_CMD_FIFO_INFO;
    flusher[1] = flush_bits;
    ll_si446x_cmd_reply(flusher, 2, fifo_cnts, 2);
    ll_wait_for_cts();
    if (rxp)
      *rxp = fifo_cnts[0];
    if (txp)
      *txp = fifo_cnts[1];
    ll_si446x_trace(T_RC_FIFO_INFO, fifo_cnts[0], fifo_cnts[1]);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.get_config_lists()
   *
   * return the list of config lists to be used to configure the 446x chip.
   * since configuration is a long process (around 10ms), the list is processed
   * by the a separate task managed by the driver.
   *
   * Both si446x_wds_config and si446x_device_config are simple byte arrays
   * containing a sequence of Pascal-like strings (pstrings). Each pstring
   * starts with the string length followed by the command, followed by
   * command bytes.  The array is terminated by a zero length.
   */
norace  uint8_t const* config_list[] = {NULL, si446x_device_config, NULL};

  async command const uint8_t ** Si446xCmd.get_config_lists() {
    nop();
    config_list[0] = wds_config_select(NULL);
    return config_list;
  }


  /**************************************************************************/
  /*
   * Si446xCmd.get_cts
   *
   * encapsulate obtaining the current CTS value.
   *
   * CTS can be on a h/w pin or can be obtained via the SPI
   * bus.  This routine hides how it is obtained.
   */
  async command bool Si446xCmd.get_cts() {
    return ll_si446x_get_cts();
  }


  /**************************************************************************/
  /*
   * Si446xCmd.get_packet_info
   *
   * get packet_info for last received packet.
   * returns variable length field value (length) from last rx packet.
   * we do not override and fields length (that's just weird).
   */
  async command uint16_t Si446xCmd.get_packet_info() {
    ll_si446x_cmd_reply(si446x_packet_info_nc, sizeof(si446x_packet_info_nc), radio_rsp, 2);
    ll_si446x_trace(T_RC_GET_PKT_INF, radio_rsp[0], radio_rsp[1]);
    return radio_rsp[0] << 8 | radio_rsp[1];
  }


  /**************************************************************************/
  /*
   * Si446xCmd.ll_clr_ints
   * Si446xCmd.ll_getclr_ints
   *
   * clear chip interrupt pending status.
   * alternately method reads current status as well.
   */
  async command void Si446xCmd.ll_clr_ints(uint8_t ph_clr,
                                           uint8_t modem_clr,
                                           uint8_t chip_clr) {
    si446x_int_clr_t         cmd;
    uint8_t                  sz;

    cmd.cmd = SI446X_CMD_GET_INT_STATUS;
    sz = 1;
    if ((ph_clr) || (modem_clr) || (chip_clr)) {
      cmd.ph_pend = ph_clr;
      cmd.modem_pend = modem_clr;
      cmd.chip_pend = chip_clr;
      sz =  sizeof(cmd);
    }
    ll_si446x_send_cmd((void *) &cmd, sz);
  }
  /*
   * get/clr interrupt state
   * clr all pendings and return previous state in *intp
   */
  async command void Si446xCmd.ll_getclr_ints(volatile si446x_int_clr_t   *int_clr_p,
                                              volatile si446x_int_state_t *int_stat_p) {
    si446x_int_clr_t          cmd;
    uint8_t                   clen = sizeof(si446x_int_clr_t);

    // if null clr ptr, then clear everything by sending just command
    if (!int_clr_p) {
      int_clr_p = &cmd;
      clen = 1;
    }
    int_clr_p->cmd = SI446X_CMD_GET_INT_STATUS;
    ll_si446x_cmd_reply((void *) int_clr_p, clen,
                        (void *) int_stat_p, sizeof(si446x_int_state_t));
  }


  /**************************************************************************/
  /*
   * Si446xCmd.power_up
   *
   * tell the radio chip to power up
   *
   * The wds_config file contains strings used to configure the radio. Some
   * of these commands needs to be sent before power up, and some after.
   * if a patch is present, it is loaded first. Once the power_up cmd string
   * in the wds_config file has been sent, then done with power up. Remainder
   * of the wds_config will be written later when driver loads it.
   *
   */
  async command void Si446xCmd.power_up() {
    uint8_t const* cp;
    uint16_t count = 1000; // protect loop from bad config data
    cp = wds_config_select(NULL);
    while (cp && count--) {
      ll_si446x_send_cmd(&cp[1], cp[0]);
      if (cp[1] == SI446X_CMD_POWER_UP)
        break;
      cp += cp[0] + 1;
    }
    if (!count)
      __PANIC_RADIO(10, (uint32_t) cp, 0, 0, 0);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.read_property
   *
   * read property of radio chip
   */
  async command void Si446xCmd.read_property(uint16_t p_id, uint16_t num, uint8_t *rsp_p) {
    uint8_t cmd[16];

    cmd[0] = SI446X_CMD_GET_PROPERTY;
    cmd[1] = p_id >> 8;
    cmd[2] = num;
    cmd[3] = p_id & 0xff;
    ll_si446x_cmd_reply(cmd, 4, rsp_p, num);
    ll_si446x_trace(T_RC_READ_PROP, p_id, (uint8_t) *rsp_p);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.read_rx_fifo
   *
   * read data bytes from the TXFIFO.
   * First it sets CS which resets the radio SPI and enables
   * the SPI subsystem, next the cmd SI446X_CMD_RX_FIFO_READ
   * and then we pull data from the FIFO across the SPI bus.
   * CS is deasserted which terminates the block.
   *
   * If we pull too many bytes from the RX fifo, the chip will
   * throw an FIFO Underflow exception.
   */
  async command void Si446xCmd.read_rx_fifo(uint8_t *data, uint8_t length) {
    uint32_t t0, t1;

    t0 = call Platform.usecsRaw();
    call HW.si446x_set_cs();
    call FastSpiByte.splitWrite(SI446X_CMD_RX_FIFO_READ);
    call FastSpiByte.splitReadWrite(0);
    readBlock(data, length);
    call HW.si446x_clr_cs();
    t1 = call Platform.usecsRaw();
    t1 -= t0;
    ll_si446x_spi_trace(SPI_REC_RX_FIFO, 0, data, length);
    ll_si446x_trace(T_RC_READ_RX_FF, t1, length);
  }


   /**************************************************************************/
  /*
   * Si446xCmd.send_config
   *
   * send config string to the  radio chip.
   */
  async command void Si446xCmd.send_config(const uint8_t *properties, uint16_t length) {

    ll_si446x_send_cmd(properties, length);
    ll_si446x_read_fast_status(radio_pend);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.set_property
   *
   * write one or more properties to the radio chip
   */
  async command void Si446xCmd.set_property(uint16_t prop, uint8_t *values, uint16_t vl) {
    uint8_t prop_buf[16];
    uint16_t i;

    prop_buf[0] = SI446X_CMD_SET_PROPERTY;
    prop_buf[1] = prop >> 8;            /* group */
    prop_buf[2] = vl;                   /* num_props */
    prop_buf[3] = prop & 0xff;          /* start_prop */

    for (i = 0; i < 12 && i < vl; i++ )
      prop_buf[i+4] = values[i];
    ll_si446x_send_cmd(prop_buf, vl+4);
    ll_si446x_trace(T_RC_SET_PROP, prop, (uint16_t) *values);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.set_pwr_3_3
   *
   * set the radio power rail to 3.3v
   */
  async command void Si446xCmd.set_pwr_3_3v() {
    call HW.si446x_set_high_tx_pwr();
  }


  /**************************************************************************/
  /*
   * Si446xCmd.set_pwr_1_8
   *
   * set the radio power rail to 1.8v
   */
  async command void Si446xCmd.set_pwr_1_8v() {
    call HW.si446x_set_low_tx_pwr();
  }


  /**************************************************************************/
  /*
   * Si446xCmd.shutdown
   */
  async command void          Si446xCmd.shutdown() {
    call HW.si446x_shutdown();
    ll_si446x_trace(T_RC_SHUTDOWN, 0, 0);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.start_rx
   *
   * start the Receiver using specified parameters
   *
   */
  async command void Si446xCmd.start_rx() {
    ll_si446x_send_cmd(start_rx_cmd, sizeof(start_rx_cmd));
    ll_wait_for_cts();                    // wait for rx start up
  }


  /**************************************************************************/
  /*
   * Si446xCmd.start_rx_short
   *
   * start receiver using settings from previous start_rx operation
   *
   */
  async command void Si446xCmd.start_rx_short() {
    ll_si446x_send_cmd(start_rx_short_cmd, sizeof(start_rx_short_cmd));
    ll_wait_for_cts();                    // wait for rx start up
  }


  /**************************************************************************/
  /*
   * Si446xCmd.start_tx
   *
   * send the start command to the radio chip.
   * input parameter specifies length of packet to transmit
   */
  async command void Si446xCmd.start_tx(uint16_t len) {
    uint8_t x[5];

    x[0] = SI446X_CMD_START_TX;
    x[1] = 0;                     /* channel */
    x[2] = 0x30;                  /* back to READY */
    x[3] = 0;
    x[4] = len & 0xff;
    ll_si446x_send_cmd((void *) x, 5);
    ll_wait_for_cts();
  }


  /**************************************************************************/
  /*
   * Si446xCmd.trace
   *
   * add entry to global trace
   */
  async command void Si446xCmd.trace(trace_where_t where, uint16_t r0, uint16_t r1) {
    ll_si446x_trace(where, r0, r1);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.trace_radio_pend
   *
   * trace current radio interrupt status and hardware related pin state
   */
  async command void Si446xCmd.trace_radio_pend(uint8_t *pend) {
    ll_si446x_trace_radio_pend(pend);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.unshutdown
   */
  async command void         Si446xCmd.unshutdown() {
    call Si446xCmd.disable_hw_cts();
    call HW.si446x_unshutdown();
    ll_si446x_trace(T_RC_UNSHUTDOWN, 0, 0);
  }


  /**************************************************************************/
  /*
   * Si446xCmd.write_tx_fifo
   *
   * sends data bytes into the TXFIFO.
   * First it sets CS which resets the radio SPI and enables
   * the SPI subsystem, next the cmd SI446X_CMD_TX_FIFO_WRITE
   * is sent followed by the data.  After the data is sent
   * CS is deasserted which terminates the block.
   *
   * If the TX fifo gets full, an additional write will throw a
   * FIFO Overflow exception.
   */
  async command void Si446xCmd.write_tx_fifo(uint8_t *data, uint8_t length) {
    uint32_t t0, t1;

    t0 = call Platform.usecsRaw();
    call HW.si446x_set_cs();
    call FastSpiByte.splitWrite(SI446X_CMD_TX_FIFO_WRITE);
    writeBlock(data, length);
    call HW.si446x_clr_cs();
    t1 = call Platform.usecsRaw();
    t1 -= t0;
    ll_si446x_spi_trace(SPI_REC_TX_FIFO, 0, data, length);
    ll_si446x_trace(T_RC_WRITE_TX_FF, 0, 0);
  }

  /* CmdP doesn't handle the Panic.hook,  see DriverLayerP. */
  async event void Panic.hook() { }

}
