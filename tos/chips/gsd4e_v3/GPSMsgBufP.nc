/*
 * Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
 * All rights reserved.
 *
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 * @author Eric B. Decker <cire831@gmail.com>
 *
 * This module handles carving a single receive buffer into logical
 * messages for the gps module to use.  A single area of memory, gps_buf,
 * is carved up into logical gps messages (gps_msg) as gps messages arrive.
 *
 * The underlying memory is a single circular buffer.  This buffer allows
 * for the gps incoming traffic to be bursty, and allowing for some
 * flexibility in the processing dynamic.  When the message has been
 * processed it is returned to the free space of the buffer.
 *
 * Free space in this buffer is maintained by a single free structure that
 * remembers a data pointer and length.  It is always the space following
 * any tail (if the queue exists) to the next boundary, either the end
 * of the buffer or the head of the queue.
 *
 * Any free space at the front of the buffer can be found by head - gps_buf
 * and is used when we wrap_free (wrap the free pointer around to the front
 * of the buffer).
 *
 * We implement a first-in-first-out, contiguous, strictly ordered
 * allocation and queueing discipline.  This defines the message queue.
 * This allows us to minimize the complexity of the allocation and free
 * mechanisms when managing the memory blob.  This also keeps fragmentation
 * to a minimim.
 *
 * Messages are layed down in memory, stictly contiguous.  We do not allow
 * a message to wrap or become split in anyway.  This greatly simplifies
 * how the message is accessed by higher layer routines.  This also means
 * that all memory allocated between head and tail is strictly contiguous
 * subject to end of buffer wrappage.
 *
 * Since message byte collection happens at interrupt level (async) and
 * data collection is a syncronous actvity (task) provisions must be made
 * for handing the message off to task level.  While this is occuring it is
 * possible for additional bytes to arrive at interrupt level. They will
 * continue to be added to the buffer as an additional message until the
 * buffer runs out of space. The buffer size is set to accommodate some reasonable
 * number of incoming messages.  Once either the buffer becomes full or we
 * run out of gps_msg slots, further messages will be discarded.
 *
 * Management of buffers, messages, and free space.
 *
 * Each gps_msg slot maybe in one of several states:
 *
 *   EMPTY:     available for assignment, doesn't point to a memory region
 *   FILLING:   assigned, currently being filled by incoming bytes.
 *   FULL:      assigned and complete.  In the upgoing queue.
 *   BUSY:      someone is actively messing with the msg, its the head.
 *
 * The buffer can be in one of several states:
 *
 *   EMPTY, completely empty:  There will be one gps_msg set to FREE pointing at the
 *     entire free space.  If there are no msgs allocated, then the entire buffer has
 *     to be free.  free always points at gps_buf and len is GPS_BUF_SIZE.
 *
 *   M_N_1F, 1 (or more) contiguous gps_msgs.  And 1 free region.
 *     The free region can be either at the front, followed by the
 *     gps_msgs, or we can have gps_msgs (starting at the front of the buffer)
 *     followed by the free space.  free points at this region and its len
 *     reflects either the end of the buffer or from free to head.
 *
 *   M_N_2F, 1 (or more) contiguous gps_msgs and two free regions
 *     One before the gps_msg blocks and a trailing free region.  free will
 *     always point just beyond tail (tail->data + tail->len) and will have
 *     a length to either EOB or to head as appropriate.
 *
 * When we have two free regions, the main free region (pointed to by free) is
 * considered the main free region.  It is what is used when allocating new
 * space for a message.  It immediately trails the Tail area (the last allocated
 * message on the queue).  The other region is free space on the front of the
 * buffer, gps_buf to head.  This area is the aux free area.
 *
 * We use an explict free pointer to avoid mixing algorithms between free
 * space constraints and msg_slot constraints.  Seperate control structures
 * keeps the special cases needed to a minimum.
 *
 * When working towards the end of memory, some special cases must be
 * handled.  If we have room for a message but it won't fit in the region
 * at the end of memory we do a force_consumption of the bytes at the
 * end, they get added to tail->extra and we wrap the free pointer.
 * The new message gets allocated at the front of the buffer and we move
 * on.  When the previous tail message is msg_released the extra bytes
 * will also be removed.
 *
 * Note that we must check to see if the message will fit before changing
 * any state.
 *
 *
**** Discussion of control variables and corner cases:
 *
 * The buffer allocation is controlled by the following cells:
 *
 * gps_msgs: an array of strictly ordered gps_msg_t structs that point at
 *   regions in the gps_buffer memory.
 *
 * head(h): head index, points to an element of gps_msgs that defines the head
 *   of the fifo queue of msg_slots that contain allocated messages.  If head
 *   is INVALID no messages are queued (queue is empty).
 *
 * tail(t): tail index, points to the last element of gps_msgs that defines the tail
 *   of the fifo queue.  All msg_slots between h and t are valid and point
 *   at valid messages.
 *
 * messages are allocated stictly ordered (subject to wrap) and successive
 * entries in the gps_msgs array will point to messages that have arrived
 * later than earlier entries.  This sequence of msg_slots forms an ordered
 * first-in-first-out queue for the messages as they arrive.  Further
 * successive entries in the fifo will also be strictly contiguous.
 *
 *
 * free space control:
 *
 *   free: is a pointer into the gps_buffer.  It always points at memory
 *     that follows the tail msg if tail is valid.  It either runs from the
 *     end of tail to the end of the gps_buf (free region is in the rear of
 *     the buffer) or from the end of tail to start of head (free region is
 *     in the front of the buffer)
 *
 *   free_len: the length of the current free region.
 *
 *
**** Corner/Special Cases:
 *
**** Initial State:
 *   When the buffer is empty, there are no entries in the msg_queue, head
 *   will be INVALID.  Free will be set to gps_buf with a free_len of
 *   GPS_BUF_SIZE
 *
 * Transition from 1 queue element to 0.  ie.  the last msg is released and the
 * queue length is 1.  The queue may be located anywhere in memory, when the
 * last element is released we could end up with a fragmented free space, even
 * though all memory has now been release.
 *
 * When the last message is released, the free space will be reset back to fully
 * contiguous, ie. free = gps_buf, free_len = GPS_BUF_SIZE.
 *
**** Running out of memory:
 *
 * Memory starvation is indicated by free_len < len (the requested length).
 * We will always return NULL (fail) to msg_start call.  This only occurs
 * after any potential wrap_free has occurred.  When checking to see if a
 * message will fit we need to check the current free region as well as the
 * potential aux region (in the front).
 *
 *
**** Running Off the End:
 *
 * We run off the end of the gps_buffer when a new msg won't fit in the
 * current remaining free space.  We want to keep all messages contiguous
 * to simplify access to the data and the current message won't fit in the
 * remaining space.
 *
 * There may be more free space in the aux region at the front.  We first
 * check to see if a message will fit in the current region (free_len).
 * If not check the aux_region (aux_len).  If so force_consume free_len
 * and wrap to the aux region.
 *
**** Freeing last used msg_slot (free space reorg)
 *
 * When the last used message is freed, the entire buffer will be free
 * space.  We want to coalesce the free space into one contiguous region
 * again.  Set free = gps_buf and free_len = GPS_BUF_SIZE.  aux_len = 0.
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
