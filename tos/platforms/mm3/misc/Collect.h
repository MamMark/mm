/*
 * mm3Collect.h - data collector (record managment) interface
 * between data collection and mass storage.
 * Copyright 2008, Eric B. Decker
 * Mam-Mark Project
 */

#ifndef __COLLECTOR_H__
#define __COLLECTOR_H__

#include "stream_storage.h"

/*
 * DC_BLK_SIZE is 4 less then the block size of mass storage.
 * last 2 bytes is a running checksum (sum the block to 0).
 * The two bytes before that is a little endian order sequence
 * number.  It is reset to zero on a restart.
 *
 * Mass Storage block size is 512.  If this changes the tag
 * is severly bolloxed as this number is spread a number of
 * different places.  Fucked but true.
 */

#define DC_BLK_SIZE 508
#define DC_CHKSUM_LOC 510
#define DC_SEQ_LOC 508

typedef struct {
  uint16_t majik_a;
  ssw_buf_handle_t *handle;
  uint8_t *cur_buf;
  uint8_t *cur_ptr;
  uint16_t remaining;
  uint16_t chksum;
  uint16_t seq;
  uint16_t majik_b;
} dc_control_t;

#define DC_MAJIK_A 0x1008
#define DC_MAJIK_B 0x0403


#endif  /* __COLLECTOR_H__ */
