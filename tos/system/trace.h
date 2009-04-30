/**
 *
 * Copyright 2008 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#ifndef __TRACE_H__
#define __TRACE_H__

#define TRACE_SIZE 64

typedef enum {
  T_REQ		= 1,
  T_GRANT	= 2,
  T_REL		= 3,
  T_SSR		= 4,
  T_SSW		= 5,
  T_GPS		= 6,
  T_THREAD_STOP = 7,
  T_THREAD_START = 8,
  T_THREAD_SUSPEND = 9,
  T_THREAD_WAKE = 10,

  T_GPS_DEF_GRANT = 11,
  T_GPS_DEF_DEFERRED = 12,

  /*
   * For debugging Arbiter 1
   */
  T_A1_REQ	= 1 + 256,
  T_A1_GRANT	= 2 + 256,
  T_A1_REL	= 3 + 256,
} trace_where_t;


typedef struct {
  uint32_t stamp;
  trace_where_t where;
  uint16_t arg0;
  uint16_t arg1;
} trace_t;

#endif	// __TRACE_H__
