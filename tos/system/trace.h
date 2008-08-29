/**
 *
 * Copyright 2008 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#ifndef __TRACE_H__
#define __TRACE_H__

#define TRACE_SIZE 32

typedef enum {
  T_REQ = 1,
  T_GRANT,
  T_REL,
  T_SSR,
  T_SSW,
  T_GPS,
} trace_where_t;


typedef struct {
  uint32_t stamp;
  trace_where_t where;
  uint16_t arg0;
  uint16_t arg1;
} trace_t;

#endif	// __TRACE_H__
