/*
 * Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
 * All rights reserved.
 *
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 * @author Eric B. Decker <cire831@gmail.com>
 */

#ifndef __GPSMSGBUF_H__
#define __GPSMSGBUF_H__


#define GPS_MAX_BUF           1024
#define GPS_MAX_MSG_TABLE     20

typedef enum {
  CHECK_OFF = 0,
  CHECK_NMEA,
  CHECK_SIRFBIN
} gps_checksum_t;


typedef enum {
  BC_IDLE = 0,
  BC_BODY,
  BC_FLUSHING,
} buf_collect_state_t;


typedef struct gps_buf_struct {
  uint16_t                    i_current;
  uint16_t                    i_begin;
  uint16_t                    i_limit;
  uint16_t                    i_checksum;
  uint16_t                    checksum;
  gps_checksum_t              checking;
  uint8_t                     data[GPS_MAX_BUF] __attribute__ ((aligned (2)));
  buf_collect_state_t         collect_state;
} gps_buf_t;
//

typedef enum {
  MSG_FREE = 0,
  MSG_IN_USE,
  MSG_BUSY
} gps_msg_state_t;

typedef struct gps_msg_struct {
  uint16_t                    len;
  uint16_t                    dt_type;
  uint8_t                     buf[];
} gps_msg_t __attribute__ ((aligned (1)));

typedef struct gps_msg_table_struct {
  gps_msg_t                  *msg;
  uint16_t                    len;
  gps_msg_state_t             state;
} gps_msg_table_t;


#endif GPSMSGBUF
