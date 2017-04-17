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
#include <gps.h>
#include <GPSMsgBuf.h>


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
  }
  uses interface Panic;
}
implementation {
  uint8_t   gps_buf[GPS_BUF_SIZE];       /* underlying storage */
  gps_msg_t gps_msgs[GPS_MAX_MSGS];      /* msg slots */
  gmc_t     gmc;                         /* gps message control */


  void gps_warn(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.warn(PANIC_GPS, where, p0, p1, 0, 0);
  }

  void gps_panic(uint8_t where, parg_t p0, parg_t p1) {
    call Panic.panic(PANIC_GPS, where, p0, p1, 0, 0);
  }


  command error_t Init.init() {
    /* initilize the control cells for the msg queue and free space */
    gmc.free     = gps_buf;
    gmc.free_len = GPS_BUF_SIZE;
    gmc.head     = MSG_NO_INDEX;        /* no msgs in queue */
    gmc.tail     = MSG_NO_INDEX;        /* no msgs in queue */

    /* all msg slots initialized to EMPTY (0) */

    return SUCCESS;
  }


  /*
   * wrap_free: wrap free space as needed
   *
   * The Free space normally lives at the end of the msg queue and
   * ends at the edge of the gps_buffer.  If there is space at the
   * front when we hit the end of the buffer, we want to wrap and
   * start using that space.
   */
  void wrap_free() {
    if (gmc.free_len)                   /* still space left */
      return;
    if (gmc.aux_len == 0)               /* no space to add */
      return;
    gmc.free = gps_buf;                 /* wrap to beginning */
    gmc.free_len = gmc.aux_len;
    gmc_aux_len = 0;
  }


  async command uint8_t *GPSBuffer.msg_start(uint16_t len) {
    gps_msg_t *msg;             /* message slot we are working on */
    uint16_t   idx;             /* index of message slot */

    if (gmc.free < gps_buf || gmc.free >= gps_buf + GPS_BUF_SIZE ||
        gmc.free_len > GPS_BUF_SIZE) {
      gps_panic(GPSW_MSG_START, gmc.free, gmc.free_len);
      return NULL;
    }

    /*
     * bail out early if no free space or not enough
     */
    if (gmc.full >= GPS_MAX_MSGS ||
        (gmc.free_len < len && gmc.aux_len < len))
      return NULL;

    /*
     * Look at the msg queue to see what the state of free space is.
     * EMPTY (buffer is all FREE), !EMPTY (1 or 2 free space regions).
     */
    if (MSG_INDEX_INVALID(gmc.head)) {          /* no head, empty queue */
      /* no msgs, all free space */
      msg = &gps_msgs[0];
      msg->data  = gmc.free;
      msg-> len  = len;
      msg->state = GPS_MSG_FILLING;

      gmc.free = gmc.free + len;
      gmc.free_len -= len;              /* zero is okay */

      gmc.head   = 0;                   /* always 0 */
      gmc.tail   = 0;                   /* ditto for tail */
      gmc.full   = 1;                   /* just one */
      if (!gmc.max_full)                /* if zero, pop it */
        gmc.max_full = 1;

      return w_msg->data;
    }

    /*
     * The msg queue is not empty.  Tail (t) points at the last puppy.
     * We know we have 1 or 2 free regions.  free points at the one
     * we want to try first.
     */
    if (len <= gmc.free_len) {
      /* msg will fit in current free space. */
      idx = MSG_NEXT_INDEX(gmc.tail);
      msg = &gps_msg[idx];
      if (msg->state) {                 /* had better be empty */
        gps_panic(GPSW_MSG_START, (parg_t) msg, msg->state);
        return NULL;
      }

      msg->data  = gmc.free;
      msg->len   = len;
      msg->state = GPS_MSG_FILLING;
      gmc.tail   = idx;                 /* advance tail */

      gmc.free = gmc.free + len;
      gmc.free_len -= len;              /* zero is okay */

      gmc.full++;                       /* one more*/
      if (gmc.full > gmc.max_full)
        gmc.mac_full = gmc.full;

      wrap_free();                      /* wrap if needed */
      return w_msg->data;
    }
    return NULL;
  }


  async command void GPSBuffer.msg_abort() {
  }


  async command void GPSBuffer.msg_complete() {
  }


  async command uint8_t *GPSBuffer.msg_next() {
  }


  async command void GPSBuffer.msg_release(uint8_t *msg_data) {
  }


  /*
   * Panic.hook
   */
  async event void Panic.hook() { }
}
