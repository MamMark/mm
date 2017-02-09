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

  T_GPS_DO_GRANT	= 11,
  T_GPS_DO_DEFERRED	= 12,
  T_GPS_RELEASING	= 13,
  T_GPS_RELEASED	= 14,
  T_GPS_DO_REQUESTED	= 15,
  T_GPS_HOLD_TIME	= 16,
  T_SSW_DELAY_TIME	= 17,
  T_SSW_BLK_TIME	= 18,
  T_SSW_GRP_TIME	= 19,

  T_RS                  = 20,

//  T_R_EXCEP,
//  T_R_EXCEP_1,
//  T_R_TX_FD,
//  T_R_TX_FD_1,
  T_R_TX_PKT,
//  T_R_RX_FD,
  T_R_RX_PKT,
  T_R_RX_RECV,
  T_R_RX_BAD_CRC,
//  T_R_RX_OVR,
//  T_R_RX_OVR_1,
//  T_R_RX_LOOP,
//  T_R_RECOVER,

  T_TL                  =64,
  T_INT_OVR,
  T_INT_T0A0,
  T_INT_T0A1,
  T_INT_P1,

  /*
   * Si446xCmd trace points
   */
  T_RC_INTERRUPT            = 0x100,
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
  T_DL_INTERRUPT            = 0x200,
  T_DL_TRANS_ST,

  /*
   * For debugging Arbiter 1
   */
  T_A1_REQ		= 1 + 0x100,
  T_A1_GRANT,
  T_A1_REL,
} trace_where_t;

#endif	// __PLATFORM_TRACE_H__
