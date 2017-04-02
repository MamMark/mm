/*
 * Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
 * All rights reserved.
 *
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 * @author Eric B. Decker <cire831@gmail.com>
 *
 * This module handles the logical interface to the receive buffer
 * along with the higher level interface to reference the messages
 * (likely more than one) in the buffer. The message structure is
 * a logical overlay onto the physical receive buffer.
 *
 * A single buffer is used which assumes that the processing occurs
 * fairly quickly. This module provides a routine to store the next
 * byte of a message into the buffer. Additional routines provide
 * a way to mark the state of the message for identifying buffer
 * boundaries (start-of-message, end-of-message, start-checksum,
 * end-checksum, and check-sum). Additional routines provide
 * control over the handling of message receive completion
 * (complete or abort).
 *
 * There is room left at the front of the msg buffer to put the data
 * collector header (four bytes).
 *
 * Since message byte collection happens at interrupt level (async)
 * and data collection is a syncronous actvity provisions must be
 * made for handing the message off to task level.  While this is
 * occuring it is possible for additional bytes to arrive at interrupt
 * level. They will continue to be added to the buffer as additional
 * messages until the buffer runs out of space. The buffer size must
 * accommodate all possible receive messages that arrive due to
 * periodic control or due to response to a request we have made.
 *
 * RULES for managing the buffers and messages:
 *
 * - start with one free msg table entry the size of entire buffer
 * - when first msg is received, add as first entry and split off a
 *    second entry with the remainder of the buffer
 * - continue receiving from end of last received msg
 * - add next msg entry into table when EOM is detected (check CRC here)
 * - if msg won’t fit into buffer (cur > max) then discard and wait for
 *    first msg entry to become free
 * - when freeing, coalesce adjacent entries into one contiguous buffer
 */

/*
 * SIRF BIN CHECKSUM (SiRF Binary Protocol Reference Manual, v2.4)
 * The checksum is transmitted high order byte first followed by the low byte.
 * This is the so-called big-endian order.
 * The checksum is 15-bit checksum of the bytes in the payload data.
 * The following pseudo code defines the algorithm used.
 *   Let message be the array of bytes to be sent by the transport.
 *   Let msgLen be the number of bytes in the message array to be transmitted.
 *   Index = first
 *   checkSum = 0
 *   while index < msgLen
 *    checkSum = checkSum + message[index]
 *    checkSum = checkSum AND (2^15-1).
 *    increment index
 *
 * NEMA CHECKSUM (wikipedia)
 * The checksum at the end of each sentence is the XOR of all of the bytes in
 * the sentence, excluding the initial dollar sign.
 * The following pseudo code defines the algorithm used.
 *   char mystring[] = "GPRMC,092751.000,A,5321.6802,N,00630.3371,W,0.06,31.66,280511,,,A";
 *   int checksum(const char *s) {
 *       int checksum = 0;
 *       while(*s)
 *          checksum ^= *s++;
 *       return checksum;
 *   }
 */


#include <panic.h>
#include <platform_panic.h>
#include "GPSMsgBuf.h"
#include "math.h"

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif

module GPSMsgBufP {
  provides {
    interface Init;
    interface GPSBuffer;
    interface GPSReceive;
  }
  uses {
    interface Panic;
  }
}
implementation {
  norace gps_buf_t       buffer;
  norace gps_msg_table_t msg_table[GPS_MAX_MSG_TABLE];

/* utility routines */

  /* warn */
  void _warn(uint8_t where, parg_t p) {
    call Panic.warn(PANIC_GPS, where, p, 0, 0, 0);
  }

  /* panic */
  void _panic(uint8_t where, parg_t p) {
    call Panic.panic(PANIC_GPS, where, p, 0, 0, 0);
  }

/* buffer handling interface routines */

  async command       void  GPSBuffer.add_byte(uint8_t byte) {
    if (!buffer.collect_state) {                  // msg_start() not called yet
      _panic(GPSW_ADD_BYTE, byte);
      return;
    }
    if (buffer.collect_state == BC_FLUSHING) {      // flushing, waiting for msg_complete()
      return;
    }
    if (buffer.i_current >= (GPS_MAX_BUF - 1)) { // out-of-range offset
      buffer.collect_state = BC_FLUSHING;
      return;
    }
    nop();
    buffer.data[buffer.i_current] = byte;
    switch(buffer.checking) {
      default:
        _panic(GPSW_ADD_BYTE, byte);
        break;
      case CHECK_OFF:
        break;
      case CHECK_NMEA:
        buffer.checksum ^= byte;
        break;
      case CHECK_SIRFBIN:
        buffer.checksum += byte;
        buffer.checksum &= 0x7fff;
        break;
    }
    buffer.i_current++;
  }

  async command       void     GPSBuffer.begin_NMEA_SUM() {
      atomic {
        buffer.checking = CHECK_NMEA;
        buffer.checksum = 0;
      }
  }

  async command       void     GPSBuffer.begin_SIRF_SUM() {
    atomic {
      buffer.checking = CHECK_SIRFBIN;
      buffer.checksum = 0;
    }
  }

  async command       uint16_t     GPSBuffer.end_SUM(int8_t correction) {
    // offset controls where to find first checksum byte in buffer
    atomic {
      buffer.checking = CHECK_OFF;
      buffer.i_checksum = buffer.i_current + correction;
  }
  return buffer.checksum;
  }

  async command       void     GPSBuffer.msg_abort() {
    atomic {
      buffer.collect_state = BC_IDLE;
      buffer.i_current = buffer.i_begin;
      buffer.checking = CHECK_OFF;
    }
  }

  async command       void     GPSBuffer.msg_complete() {
    unsigned int   i;
    gps_msg_t      *msg;

    atomic {
      if (!buffer.collect_state) {      /* collecting? */
        _panic(GPSW_MSG_COMPLETE, 1);   /* nope - should be */
        return;
      }
      if (buffer.collect_state == BC_FLUSHING) {
        buffer.collect_state = BC_IDLE;
        buffer.i_current = buffer.i_begin;
        return;
      }
      nop();
      /* add completed msg to msg table */
      msg = NULL;
      for (i = 0; i < GPS_MAX_MSG_TABLE; i++) {   // add completed msg to table
        if (msg_table[i].state == MSG_FREE) {
          msg_table[i].state = MSG_IN_USE;
          msg = (gps_msg_t *) &buffer.data[buffer.i_begin];
          msg_table[i].msg = msg;
          msg_table[i].len = buffer.i_current - buffer.i_begin;
          msg->len = msg_table[i].len;
          break;
        }
      }
      buffer.collect_state = BC_IDLE;
    }
    if (msg) {
      signal GPSReceive.receive(msg);
      return;
    }

    /* no free entry in message table, drop current incoming */
    buffer.i_current = buffer.i_begin;
    _warn(GPSW_MSG_COMPLETE, 2);
  }

  async command       void     GPSBuffer.msg_start() {
    if (buffer.collect_state) {         /* anything other than idle is wrong */
      _panic(GPSW_MSG_START, 0);
    }
    nop();
    buffer.collect_state = BC_BODY;
    buffer.i_begin = (((uint32_t) &buffer.data[buffer.i_current] % 2) != 0) // force word boundary
                      ? buffer.i_current++ : buffer.i_current;
    buffer.i_current += sizeof(gps_msg_t);   // add room for typed data header
    buffer.checking = CHECK_OFF;
    buffer.checksum = 0;
  }

/* message handling interface routines */

  command       void       GPSReceive.recv_done(gps_msg_t *msg) {
    uint8_t     i;

    nop();
    for (i = 0; i < GPS_MAX_MSG_TABLE; i++) {
      atomic {
        if (msg_table[i].msg == msg) {
          msg_table[i].state = MSG_FREE;
          return;
        }
      }
    }
    _panic(GPSW_SEND_DONE, 0);
  }

//  signal GPSSend.send_done(gps_msg_t *msg);
//  command       void       GPSSend.send(gps_msg_t *msg) { }

  /*
   * Init.init: initialize module
   */
  command error_t Init.init() {
    uint8_t         i;

    buffer.i_current = 0;
    buffer.i_limit = 0;
    buffer.i_begin = 0;
    buffer.i_limit = 0;
    buffer.collect_state = BC_IDLE;
    buffer.checking = CHECK_OFF;
    i = 0;
    for (i = 0; i < GPS_MAX_MSG_TABLE; i++) {
      msg_table[i].state = MSG_FREE;
      msg_table[i].msg = NULL;
      msg_table[i].len = 0;
    }
    msg_table[0].len = GPS_MAX_BUF;  // set first entry to hold entire buffer
    return SUCCESS;
  }

  /*
   * Panic.hook
   */
  async event void Panic.hook() { }
}

#ifdef notdef
/*
 * GPS Message Collector states.  Where in the message is the state machine.  Used
 * when collecting messages.   Force COLLECT_START to be 0 so it gets initilized
 * by the bss initilizer and we don't have to do it.
 */
typedef enum {                          /* looking for...  */
  COLLECT_START = 0,                    /* start of packet */
                                        /* must be zero    */
  COLLECT_START_2,                      /* a2              */
  COLLECT_LEN,                          /* 1st len byte    */
  COLLECT_LEN_2,                        /* 2nd len byte    */
  COLLECT_PAYLOAD,                      /* payload         */
  COLLECT_CHK,                          /* 1st chksum byte */
  COLLECT_CHK_2,                        /* 2nd chksum byte */
  COLLECT_END,                          /* b0              */
  COLLECT_END_2,                        /* b3              */
  COLLECT_BUSY,				/* processing      */
} collect_state_t;

collect_state_t collect_state;		// message collection state, init to 0
norace uint16_t collect_length;		// length of payload
uint16_t        collect_cur_chksum;		// running chksum of payload
bool            draining;                     // non-zero if simply draining.
bool            collect_all;                  // TRUE if we collect all packets

uint8_t  collect_msg[GPS_BUF_SIZE];
uint8_t  collect_nxt;				// where we are in the buffer

/*
 * Error counters
 */
uint16_t collect_too_big;
uint16_t collect_chksum_fail;
uint16_t collect_proto_fail;
uint32_t last_surfaced;
uint32_t last_submerged;

to add a collect message do this:
    dt_gps_raw_t *gdp;
    /*
     * collect raw message for debugging.  Eventually this will go away
     * or be put on a conditional.
     */
    gdp = (dt_gps_raw_t *) collect_msg;
    gdp->len = DT_HDR_SIZE_GPS_RAW + SIRF_OVERHEAD + collect_length;
    gdp->dtype = DT_GPS_RAW;
    gdp->chip  = CHIP_GPS_GSD4E;
    gdp->stamp_ms = call LocalTime.get();
    call Collect.collect(collect_msg, gdp->len);
#endif
