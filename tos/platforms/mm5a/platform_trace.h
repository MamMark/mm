/**
 * Copyright 2016 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker, <cire831@gmail.com>
 */

#ifndef __PLATFORM_TRACE_H__
#define __PLATFORM_TRACE_H__

#define TRACE_SIZE 64

typedef enum {
  T_REQ			= 1,
  T_GRANT		= 2,
  T_REL			= 3,
  T_SSR			= 4,
  T_SSW			= 5,
  T_GPS			= 6,
  T_THREAD_STOP		= 7,
  T_THREAD_START	= 8,
  T_THREAD_SUSPEND	= 9,
  T_THREAD_WAKE		= 10,

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

  T_R_SFD_UP            = 32,
  T_R_SFD_DOWN,
  T_R_SFD_OVW,
  T_R_SFD_FILL,
  T_R_SFD_DRAIN,
  T_R_SFD_FLUSH,

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
   * For debugging Arbiter 1
   */
  T_A1_REQ		= 1 + 256,
  T_A1_GRANT		= 2 + 256,
  T_A1_REL		= 3 + 256,
} trace_where_t;

#endif	// __PLATFORM_TRACE_H__
