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
 * We implement a first-in-first-out, contiguous, strictly ordered allocation
 * and queueing discipline.  This allows us to minimize the complexity of the
 * allocation and free mechanisms when managing the memory blob.  This also
 * keeps fragmentation to a minimim.
 *
 * Messages are layed down in memory, stictly contiguous.  We do not allow
 * a message to wrap or become split in anyway.  This greatly simplifies
 * how the message is accessed by higher layer routines.
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
 *   FREE:      available for assignment, points to a free region of memory.
 *   FILLING:   assigned, currently being filled by incoming bytes.
 *   FULL:      assigned and complete.  In the upgoing queue.
 *   BUSY:      someone is actively messing with the msg, its the head.
 *
 * The buffer can be in one of several states:
 *
 *   EMPTY, completely empty:  There will be one gps_msg set to FREE pointing at the
 *     entire free space.  If there are no msgs allocated, then the entire buffer has
 *     to be free.
 *
 *   M_N_1F, 1 (or more) contiguous gps_msgs.  And 1 free region.
 *     The free region can be either at the front, followed by the
 *     gps_msgs, or we can have gps_msgs (starting at the front of the buffer)
 *     followed by the free space.
 *
 *   M_N_2F, 1 (or more) contiguous gps_msgs and two free regions
 *     One before the gps_msg blocks and a trailing free region.
 *
 * Regardless of the state, the data structures must be capable of
 * representing the appropriate condition without losing any memory.
 *
 * We do this using a single set of gps_msg slots without any explicit free
 * pointers.  If a region of memory is free there is a gps_msg slot that
 * points to it set to FREE.  In the degenerate case when we have consumed
 * all gps_msg slots, then there is by definition no free memory.  No
 * memory is lost because it will be assigned to the last assigned gps_msg
 * slot.
 *
 * What makes this work is the extra control cell in each gps_msg slot,
 * extra.  Extra keeps track of any additional buffer allocated to a slot.
 * In the above, example, the remaining free space will be assigned to the
 * last gps_msg slot.  Its extra cell will indicate how many additional
 * bytes have been allocated.
 *
**** Discussion of control variables and corner cases:
 *
 * The buffer allocation is controlled by the following cells:
 *
 * gps_msgs: an array of strictly ordered gps_msg_t structs that point at
 *   regions in the gps_buffer memory.
 *
 * h: head index, points to an element of gps_msgs that defines the head
 *    of the fifo queue of msg_slots for slots that contain actual messages.
 *
 * t: tail index, points to the last lement of gps_msgs that defines the tail
 *    of the fifo queue.  All msg_slots between h and t are valid and point
 *    at valid messages.
 *
 * regions of the buffer are pointed to by msg_slots.  Each msg slot contains
 * a pointer to an area in the buffer, its length, possible extra allocation,
 * and the state of this gps_msg slot (see above).
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
 *   f_m: free_main, this is the main free space index.  If there is any
 *        free space than this is the index of the next free block that
 *        will be used for a new msg.  It points at a msg_slot that will
 *        be (t+1)%32 if t exists.  If t does not exist, then there can
 *        be no msg_slots allocated and the entire buffer is free.
 *
 *        Note that at all times except for when t is invalid, f_m should
 *        be (t+1)%slots.  That is the next msg_slot that will be allocated
 *        during the next msg_start, needs to be exactly what f_m is
 *        pointing at that holds the current free region.  This preserves
 *        the strict ordering of the msg queue.
 *
 *   f_a: free_aux.  When messages are returned to the free space, this
 *        happens to messages that are at the front of the fifo.  This free
 *        space has to be accounted for.  f_a points to a msg_slot that
 *        captures any free regions from the front of the queue.
 *
 *        Eventually, f_m will hit the end of the buffer and will need
 *        to wrap.  When this happens f_m will subsume the free memory
 *        being maintained by f_a and allocations can continue.
 *
 *        The idea is f_a captures any freeing that occurs at the front
 *        of the queue until f_m hits the discontinuity at the end of the
 *        buffer, at which time, f_m wraps back to the front and picks up
 *        the free memory that f_a has been keeping track of.
 *
 *        f_a is ONLY used when there is a free space discontinuity that
 *        f_m crosses.
 *
 * Corner/Special Cases:
 *
**** Initial State:
 *   When the buffer is empty, there will be one msg_slot, set to FREE,
 *   pointing at the start of the buffer, len BUF_SIZE.
 *
 *      f_m -> msg_slot -> data     gps_buf, BUF_SIZE, 0, FREE
 *      all other msg_slots EMPTY.
 *
 *      f_a INVALID
 *      h, t INVALID
 *
 *      note: f_m can be any valid gps_msgs index.  Initially this will be 0
 *      but any idex can be used. it depends on where it f_m ends up as
 *      the queue is cycled.
 *
 * Transition from 1 queue element to 0.  ie.  the last msg is released and the
 * queue length is 1.
 *
 *   The msg_release will cause the gps_msgs[h] to be added to the end of the
 *   f_a region.  This then means that the f_a region should now butt up against
 *   the current f_m free region.  One can leave this discontinuity alone or
 *   one can rearrange and make f_m's msg_slot point at the beginning of memory.
 *
**** Running out of memory:
 *
 * If we run out of memory, ie. the existing msg_slots (< 32) consume all of the
 * gps buffer, then any msg_start will need to return NULL and cause the incoming
 * state machine to flush incoming bytes.
 *
 * This state will be indicated because f_m -> msg -> data NULL, and len 0.
 *
 * When a msg_release occurs, the msg will be added to f_a and checks will need to
 * be done to restart f_m with good data.
 *
 *
**** Running out of msg_slots:
 *
 * If so many msgs come in such that we consume all msg_slots (buffers
 * consumed < BUF_SIZE), then msg_start will return NULL, etc.
 *
 * There can be no f_a regions because any prior movement of f_m that would
 * cause an advance of the free control would have switched over to f_a.
 * The msg_slot being used by f_a will have become available for allocation
 * (f_a INVALID).  Eventually, f_m will have run through all available msg_slots
 * except for the last one being used by f_m.
 *
 * Now the last successful msg_start occurs, the f_m slot is used for that msg
 * but there are now no longer any free msg_slots for any remaining free_space.
 * By definition at this point we no long have any free space.  We modify the
 * last msg_slot (will be the new t) to allocate all additional free space from
 * the last free msg_slot.  The additional allocation is indicated in the
 * value of 'extra'.
 *
**** Transition from no available msg_slots to 1 msg_slot.
 *
 * When a msg_release occurs in this state we will transition from no free space
 * to being able to represent free space again.  However we may have a discontinous
 * condition that would need both a f_m index and f_a index to represent properly.
 * This is problematic since we have only released one msg_slot.
 *
 * To work around that problem, we ignore the free space that was consumed
 * by t->extra.  And only free what is being held by the msg_slot being released.
 * Eventually, the msg at T will be released and the extra memory will be returned
 * as well.  So the situation eventually corrects itself.
 *
 * In the meantime, the condition that got us into this state is considered extreme
 * and shouldn't be happening, so adding complexity to return all the memory doesn't
 * seem justified.
 *
**** Running Off the End:
 *
 * We run off the end of the gps_buffer when a new msg won't fit in the
 * current remaining free space.  We want to keep all messages contiguous
 * to simplify access to the data and the current message won't fit in the
 * remaining space.
 *
 * There may be more free space in the auxilliary region f_a.  See if there
 * is enough space there (if not fail, without changing any state).  If
 * there is space in f_a then we need to consume the rest of the gps_buf
 * into the tail entry (t, via t->extra, this is a forced_consume), move
 * f_m to f_a and then allocate the new msg normally.
 *
**** Freeing last used msg_slot (free space reorg)
 *
 * When the last used message is freed, the entire buffer will be free
 * space.  The state of f_m and f_a can be just about anything.  If f_a
 * is VALID that says that f_m crosses the discontinuity and this a problem.
 * If the next msg_start has a length bigger than f_m->len this will fail.
 * Normally this would cause a forced consumption of the free space in f_m.
 * But for that to work there has to be an existing Tail (T) (that is where
 * the extra gets accounted for).
 *
 * So anytime we don't have a valid tail (ie. all memory is free), we have
 * to reset the free space back to a single region with no discontinuities.
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
