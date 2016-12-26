/*
 * Currently not used.
 *
 * GpsMsgBuffer.h - gps msg buffer interface (low level)
 * Copyright 2012 Eric B. Decker
 * Mam-Mark Project
 *
 * GMBC -> GpsMsgBuffer Control
 */

#ifndef _GpsMsgBuffer_H_
#define _GpsMsgBuffer_H_

#define NUM_GPS_BUFFERS 2

/*
 * Gps Msg Buffer States
 *
 * Free:	available to be assigned.  empty.
 * Filling:	being filled in.
 * Busy:	being processed.
 *
 * A buffer cycle is as follows:
 *
 * 1) Initially a buffer is marked FREE.
 *
 * 2) The GPS driver allocates a buffer, marks it Filling, and proceeds.
 *
 * 3) When filled it is handed over to the msg processing task
 *    after being marked Busy.
 *
 * 4) When the msg processor finishes it will hand the buffer
 *    back via GPSMsgPacket.bufferFree(buf).
 *
 * 5) The buffer is marked free.
 */

typedef enum {
  GPS_BUF_STATE_FREE = 0,
  GPS_BUF_STATE_FILLING,
  GPS_BUF_STATE_BUSY,
  GPS_BUF_STATE_MAX
} gps_buf_state_t;


#define GPS_BUF_MAJIK 0xeaf0

typedef struct {
    uint16_t majik;
    gps_buf_state_t buf_state;
    uint32_t stamp;
    uint8_t  buf[GPS_BUF_SIZE];
} gps_buf_t;


#ifdef notdef
/*
 * GPS MSG Control Structure
 *
 * state:	 state of the gps msp buffer interface
 * dblk:	 block id of where to put the nxt buffer
 * ssw_out: 	 Buffer being written out via dma to the stream storage device.
 * ssw_in:	 Next buffer that should be coming back from the collector.
 * ssw_alloc:    Next buffer to be given out.
 * ssw_num_full: number of full buffers including the one being written.
 * ssw_max_full: maximum number of full buffers ever
 */

typedef enum {
  GMBC_IDLE	= 0,
  GMBC_REQUESTED,
  GMBC_WRITING,
} gmbc_state_t;


typedef struct {
  uint16_t    majik_a;		/* practice safe computing */
  gmbc_state_t state;		/* state of the writer. */
  uint8_t     gmbc_out;		/* next buffer to be written to mass storage */
  uint8_t     gmbc_in;		/* next buffer that should come back from the collector */
  uint8_t     gmbc_filling;	/* next buffer to be allocated. */
  uint16_t    majik_b;		/* tombstone */
} gmbc_control_t;

#define GMBC_MAJIK 0x8181

#endif	/* notdef */

#endif /* _GpsMsgBuffer_H_ */
