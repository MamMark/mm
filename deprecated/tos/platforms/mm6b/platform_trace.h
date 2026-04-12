/**
 * Copyright 2016-2017 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker, <cire831@gmail.com>
 */

#ifndef __PLATFORM_TRACE_H__
#define __PLATFORM_TRACE_H__

#define TRACE_SIZE 256

typedef enum {
  T_REQ			= 1,
  T_GRANT		= 2,
  T_REL			= 3,

  T_SSR			= 4,
  T_SSW			= 5,
  T_GPS			= 6,

  /*
   * For debugging Arbiter 1
   */
  T_A1_REQ		= 1 + 0x100,
  T_A1_GRANT,
  T_A1_REL,

  /*
   * Si446xCmd trace points
   */
  T_RC_INTERRUPT            = 0x20,
  T_RC_CHG_STATE,
  T_RC_CHECK_CCA,
  T_RC_CMD_REPLY,
  T_RC_DIS_INTR,
  T_RC_DRF_ALL,
  T_RC_DUMP_PROPS,
  T_RC_DUMP_RADIO,
  T_RC_DUMP_FIFO,
  T_RC_ENABLE_INT,
  T_RC_FIFO_INFO,
  T_RC_GET_REPLY,
  T_RC_GET_PKT_INF,
  T_RC_READ_PROP,
  T_RC_READ_RX_FF,
  T_RC_SEND_CMD,
  T_RC_SET_PROP,
  T_RC_SHUTDOWN,
  T_RC_UNSHUTDOWN,
  T_RC_WAIT_CTS_F,
  T_RC_WAIT_CTS,
  T_RC_WRITE_TX_FF,

  /*
   * Si446xDriverLayer trace points
   */
  T_DL_INTERRUPT            = 0x40,
  T_DL_TRANS_ST,

} trace_where_t;

#endif	// __PLATFORM_TRACE_H__
