/*
 * Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
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
 *          Daniel J. Maltbie <dmaltbie@daloma.org>
 */

#include <datetime.h>

#ifndef __GPSMSGBUF_H__
#define __GPSMSGBUF_H__


#define GPS_BUF_SIZE 1024

/* set to a power of 2 */
#define GPS_MAX_MSGS 16

/* minimum memory slice, same as SIRFBIN_OVERHEAD */
#define GPS_MIN_MSG  8

typedef enum {
  GPS_MSG_EMPTY = 0,            /* not being used, available */
  GPS_MSG_FILLING,              /* currently being filled in */
  GPS_MSG_FULL,                 /* holds a message */
  GPS_MSG_BUSY,                 /* busy, message is being processed */
} gms_t;                        /* gps msg state */


typedef struct {
  uint8_t *data;
  uint32_t mark_j;              /* time mark in jiffies */
  datetime_t arrival_dt;        /* 10 byte datetime stamp, arrival */
  uint16_t len;
  uint16_t extra;
  gms_t    state;
} gps_msg_t;


/*
 * Because of strict ordering, both msg slots as well as memory blocks
 * we can have at most 3 seperate regions, 2 free and 1 full of contiguous
 * message data.
 *
 * The free pointer always points just beyond tail (if it exists) until the
 * next boundary.  A boundary can be either the end of the buffer or head.
 *
 * If we need to wrap from the end to the front of the buffer, we can find
 * this by taking head - gps_buf as the length.  The start is of course
 * gps_buf.  But it is easier to just keep track of what is free at the front
 * via aux_len.
 */
typedef struct {                /* should be 28 bytes */
  uint8_t *free;                /* free pointer */
  uint16_t free_len;            /* and its length */
  uint16_t aux_len;             /* size of space in front */

  uint16_t head;                /* head index of msg queue */
  uint16_t tail;                /* tail index of msg queue */
  uint16_t full;                /* number full */
  uint16_t max_full;            /* how deep did it get */
  uint16_t allocated;           /* current memory allocated */
  uint16_t max_allocated;       /* largest memory ever allocated */
} gmc_t;                        /* gps msg control */


#define MSG_NO_INDEX         (0xffff)

#define MSG_INDEX_EMPTY(x)    ((x) == ((uint16_t) -1))
#define MSG_INDEX_INVALID(x)  ((x) & (~(GPS_MAX_MSGS - 1)))
#define MSG_INDEX_VALID(x)   (((x) & (~(GPS_MAX_MSGS - 1))) == 0)

#define MSG_PREV_INDEX(x) (((x) - 1) & (GPS_MAX_MSGS - 1))
#define MSG_NEXT_INDEX(x) (((x) + 1) & (GPS_MAX_MSGS - 1))

#endif  /* __GPSMSGBUF_H__ */
