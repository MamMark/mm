/*
 * Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
 * All rights reserved.
 *
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 * @author Eric B. Decker <cire831@gmail.com>
 */

#ifndef __GPSMSGBUF_H__
#define __GPSMSGBUF_H__


#define GPS_BUF_SIZE 1024
#define GPS_MAX_MSGS 32

typedef enum {
  GPS_MSG_EMPTY = 0,            /* not being used, available */
  GPS_MSG_FREE,                 /* points at free buffer space */
  GPS_MSG_FILLING,              /* currently being filled in */
  GPS_MSG_FULL,                 /* holds a message */
  GPS_MSG_BUSY,                 /* busy, message is being processed */
} gms_t;                        /* gps msg state */


typedef struct {
  uint8_t *data;
  uint16_t len;
  uint16_t extra;
  gms_t    state;
} gps_msg_t;


/*
 * Because of strict ordering, both msg slots as well as memory blocks
 * we can have at most 3 seperate regions, 2 free and 1 full of contiguous
 * message data.
 *
 * So we have free_f, free_t, and head.
 */
typedef struct {
  uint16_t free_f;              /* index of free entry */
  uint16_t free_t;              /* tail free */
  uint16_t head;                /* head index of msg queue */
  uint16_t tail;                /* tail index of msg queue */
  uint16_t full;                /* number full */
  uint16_t max_full;            /* how deep did it get */
} gmc_t;                        /* gps msg control */


#define MSG_INDEX_INVALID(x) ((x) & 0x8000)
#define MSG_INDEX_VALID(x)   (((x) & 0x8000) == 0)
#define MSG_NO_INDEX         (0xffff)

#define MSG_NEXT_INDEX(x) (((x) + 1) & 0x1f)

#endif  /* __GPSMSGBUF_H__ */
