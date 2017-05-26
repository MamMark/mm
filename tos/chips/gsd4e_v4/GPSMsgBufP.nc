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
 * of the buffer or to the head of the queue.
 *
 * Typically, free space will be at the tail of the buffer (bottom, higher
 * addresses).  This will continue until the free space at the tail no longer
 * can fit new messages.
 *
 * While free space exists at the tail of the buffer, any msg_releases will
 * be added to the free space at the front of the buffer.  This free space
 * always starts at gps_buf and any auxilliary size is maintained in aux_len.
 * Thusly, aux_len = gps_msgs[gmc.head].data - gps_buf, if free space is
 * at the rear of the buffer.
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
****
**** Corner/Special Cases:
****
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
 * Memory starvation is indicated by free_len < len (the requested length)
 * and aux_len < len.  We will always return NULL (fail) to a msg_start
 * call.  This only occurs after any potential wrap_free has occurred.
 *
 * When checking to see if a message will fit we need to check the current
 * free region as well as the potential aux region (in the front).
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

enum {
  GPSW_WRAP_FREE = 16,
  GPSW_RESET_FREE,
  GPSW_MSG_START,
  GPSW_MSG_ADD_BYTE,
  GPSW_MSG_ABORT,
  GPSW_MSG_COMPLETE,
  GPSW_MSG_NEXT,
  GPSW_MSG_RELEASE
};


module GPSMsgBufP {
  provides {
    interface Init;
    interface GPSBuffer;
    interface GPSReceive;
  }
  uses interface Panic;
}
implementation {
         uint8_t   gps_buf[GPS_BUF_SIZE];       /* underlying storage */
         gps_msg_t gps_msgs[GPS_MAX_MSGS];      /* msg slots */
  norace gmc_t     gmc;                         /* gps message control */


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
   * gps_receive_task: actually run the incoming gps message queue
   *
   * gps_receive_task will run the gps queue.  It will be posted
   * any time the incoming fifo goes from 0 to 1 element.  It does the
   * following:
   *
   * o grab the next data pointer from the HEAD via msg_next
   * o pass the msg to any receive handler via GPSReceive.msg_available
   * o on return, kill the current message, msg_release
   * o repeat, until msg_next returns NULL.
   *
   * depending on task loading and balance considerations one may or may
   * not want to repost the task and handle one message at a time or some
   * combination.
   */

  task void gps_receive_task() {
    uint8_t *msg;
    uint16_t len;

    while (1) {
      msg = call GPSBuffer.msg_next(&len);
      if (!msg)
        break;
      signal GPSReceive.msg_available(msg, len);
      call GPSBuffer.msg_release();
    }
  }


  /*
   * wrap_free: wrap free space as needed
   *
   * The Free space normally lives at the end of the msg queue and ends at
   * the boundary of gps_buf (gps_buf + GPS_BUF_SIZE).  If there is space
   * at the front when we hit the end of the buffer, we want to wrap and
   * start using that space.
   *
   * However, under no circumstances should aux_len ever be non-zero if the
   * free space is in the front part of the buffer.  That would cause
   * problems.
   */
  void wrap_free() {
    if (gmc.free_len)                   /* still space left */
      return;
    if (gmc.aux_len == 0)               /* no space to add */
      return;
    if (MSG_INDEX_INVALID(gmc.head) ||
        gmc.free <= gps_msgs[gmc.head].data) {
      /*
       * if the head is invalid, we shouldn't be wrapping at all, whole
       * buffer is free.  That is where the msg should have gone.
       *
       * if free is below head, wrapped free space, then there shouldn't be
       * anything in aux.  Continuing at this point will wipe out any
       * message space at the front of the buffer.  blow up.
       *
       * We should always wrap from the end of the buffer to the front.
       */
      gps_panic(GPSW_WRAP_FREE, gmc.head, (parg_t) gmc.free);
      return;
    }
    gmc.free = gps_buf;                 /* wrap to beginning */
    gmc.free_len = gmc.aux_len;
    gmc.aux_len  = 0;
  }


  /*
   * reset_free: reset free space to pristine state.
   */
  void reset_free() {
    if (MSG_INDEX_VALID(gmc.head)) {
        gps_panic(GPSW_RESET_FREE, gmc.head, 0);
        return;
    }
    gmc.free     = gps_buf;
    gmc.free_len = GPS_BUF_SIZE;
    gmc.aux_len  = 0;
  }


  async command uint8_t *GPSBuffer.msg_start(uint16_t len) {
    gps_msg_t *msg;             /* message slot we are working on */
    uint16_t   idx;             /* index of message slot */

    if (gmc.free < gps_buf || gmc.free > gps_buf + GPS_BUF_SIZE ||
        gmc.free_len > GPS_BUF_SIZE) {
      gps_panic(GPSW_MSG_START, (parg_t) gmc.free, gmc.free_len);
      return NULL;
    }

    /*
     * gps packets have a minimum size.  If the request is too small
     * bail out.
     */
    if (len < GPS_MIN_MSG)
      return NULL;

    /*
     * bail out early if no free space or not enough slots
     */
    if (gmc.full >= GPS_MAX_MSGS ||
        (gmc.free_len < len && gmc.aux_len < len))
      return NULL;

    /*
     * Look at the msg queue to see what the state of free space is.
     * EMPTY (buffer is all FREE), !EMPTY (1 or 2 free space regions).
     */
    if (MSG_INDEX_INVALID(gmc.head)) {          /* no head, empty queue */
      if (gmc.free != gps_buf || gmc.free_len != GPS_BUF_SIZE) {
        gps_panic(GPSW_MSG_START, (parg_t) gmc.free, (parg_t) gps_buf);
        return NULL;
      }

      /* no msgs, all free space */
      msg = &gps_msgs[0];
      msg->data  = gmc.free;
      msg->len   = len;
      msg->state = GPS_MSG_FILLING;

      gmc.free  = gmc.free + len;
      gmc.free_len -= len;              /* zero is okay */

      gmc.allocated = len;
      if (gmc.allocated > gmc.max_allocated)
        gmc.max_allocated = gmc.allocated;

      gmc.head   = 0;                   /* always 0 */
      gmc.tail   = 0;                   /* ditto for tail */
      gmc.full   = 1;                   /* just one */
      if (!gmc.max_full)                /* if zero, pop it */
        gmc.max_full = 1;

      /* no need to wrap if gmc.free_len is zero, just consumed it all */

      return msg->data;
    }

    /*
     * make sure that tail->state is FULL (BUSY counts as FULL).  Need to
     * complete previous message before doing another start.
     */
    msg = &gps_msgs[gmc.tail];
    if (msg->state != GPS_MSG_FULL && msg->state != GPS_MSG_BUSY) {
      gps_panic(GPSW_MSG_START, gmc.tail, msg->state);
    }

    /*
     * First check to see if the request won't fit in the current free
     * space.
     *
     * If it doesn't fit, we still know it will fit into the aux area.
     * So ...
     *
     * note if something got screwy and the checks don't pass we fall
     * all the way through (none of the ifs take) and hit the panic
     * at the bottom.  Shouldn't ever happen.....  Ah the joys of paranoid
     * programming.  (the code at the end, the panic, should actually
     * get optimized out.)
     */
    if (len > gmc.free_len && len <= gmc.aux_len) {
      /*
       * ah ha!  Just as I suspected, doesn't fit into the current free
       * region but does fit into the free space at the front of the
       * buffer.
       *
       * first put the remaining free space onto the extra of tail.
       * zero free and wrap it.  That puts us onto the front free region.
       * Then we can just fall through into the next if and let
       * the regular advance take over.
       *
       * Note: since aux_len is non-zero, we have to have free space in the
       * tail of the buffer
       */
      msg = &gps_msgs[gmc.tail];
      msg->extra = gmc.free_len;
      gmc.free_len = 0;
      gmc.allocated += msg->extra;      /* put extra into allocated too */
      if (gmc.allocated > gmc.max_allocated)
        gmc.max_allocated = gmc.allocated;
      wrap_free();                      /* modifies gmc.free_len */
    }

    /*
     * The msg queue is not empty.  Tail (t) points at the last puppy.
     * We know we have 1 or 2 free regions.  free points at the one
     * we want to try first.  If we have 2 regions, free is the tail
     * and aux_len says the front one is active too.
     *
     * note: if we wrapped above, aux_len will be zero (back to 1 active
     * region, in the front).  We won't wrap again.
     */
    if (len <= gmc.free_len) {
      /* msg will fit in current free space. */
      idx = MSG_NEXT_INDEX(gmc.tail);
      msg = &gps_msgs[idx];
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
      gmc.allocated += len;
      if (gmc.allocated > gmc.max_allocated)
        gmc.max_allocated = gmc.allocated;

      gmc.full++;                       /* one more*/
      if (gmc.full > gmc.max_full)
        gmc.max_full = gmc.full;

      wrap_free();                      /* wrap if needed */
      return msg->data;
    }

    /* shouldn't be here, ever */
    gps_panic(GPSW_MSG_START, gmc.free_len, gmc.aux_len);
    return NULL;
  }


  /*
   * msg_abort: send current message back to the free pool
   *
   * current message is defined to be Tail.  It must be in
   * FILLING state.
   */
  async command void GPSBuffer.msg_abort() {
    gps_msg_t *msg;             /* message slot we are working on */

    if (MSG_INDEX_INVALID(gmc.tail)) {  /* oht oh */
      gps_panic(GPSW_MSG_ABORT, gmc.tail, 0);
      return;
    }
    msg = &gps_msgs[gmc.tail];
    if (msg->state != GPS_MSG_FILLING) { /* oht oh */
      gps_panic(GPSW_MSG_ABORT, (parg_t) msg, msg->state);
      return;
    }
    msg->state = GPS_MSG_EMPTY;         /* no longer in use */
    if (gmc.head == gmc.tail) {         /* only entry? */
      gmc.head = MSG_NO_INDEX;
      gmc.tail = MSG_NO_INDEX;
      gmc.full = 0;
      gmc.allocated = 0;
      reset_free();
      return;
    }

    /*
     * Two special cases:
     *
     * o free == gps_buf, a msg_start asked for the remainder of what is
     *                    left in the free region, free_len goes to zero
     *                    we fill with no extra the tail, and free is wrapped
     *                    it will be exactly gps_buf.
     *
     *          We want to move free back to the previous tail, which also
     *          means we need to restore the aux region (aux_len).  The is
     *          no extra.
     *
     * o tail->data == gps_buf, a msg didn't fit in the free space, we
     *                    force_consumed and added it to the previous tail.
     *                    The new message then got added at the front of the
     *                    aux region (gps_buf).
     *
     *          We want to remove the current tail (which is at the front of
     *          gps_buf), restore the aux region (aux_len), and move free
     *          back to point at the extra that was add to the prev tail.
     */

    if (gmc.free == gps_buf) {
      /*
       * Special Case 1: Free == gps_buf
       * tail is at the end.  Fix Aux (it is what free was) and
       * move all the data on tail into the new free region.
       *
       * msg is set to tail above, and its state set to EMPTY.
       * extra has to be 0.
       */
      gmc.aux_len = gmc.free_len;
      gmc.free = msg->data;
      gmc.allocated -= msg->len;
      gmc.free_len = msg->len;
      gmc.tail = MSG_PREV_INDEX(gmc.tail);
      gmc.full--;
      return;
    }

    /* msg set to tail above and its state to EMPTY */
    if (msg->data == gps_buf) {
      /*
       * Special Case 2: Tail->data == gps_buf
       * The Tail we are nuking was added because it wouldn't fit in the
       * previous free region, this caused Free to Wrap and there will be
       * extra bytes on the previous tail.
       *
       * Note: there has to be > 0 extra bytes.  If Extra is 0, then it was
       * a perfect fit, free_len would have gone to 0 and we would have wrapped
       * free.  This means we would have special case 1 and not 2.  ==> extra
       * has to be > 0.
       *
       * We want to restore aux_len (tail->len + free_len), back tail up to
       * its previous value.  free = tail->data+len (point at the extra area)
       * and free_len = tail->extra.  Nuke tail->extra.
       */
      gmc.aux_len = msg->len + gmc.free_len;
      gmc.allocated -= msg->len;
      gmc.tail = MSG_PREV_INDEX(gmc.tail);
      msg = &gps_msgs[gmc.tail];
      gmc.free = msg->data + msg->len;
      gmc.free_len = msg->extra;
      gmc.allocated -= msg->extra;
      gmc.full--;
      msg->extra = 0;
      return;
    }

    /*
     * Relatively Normal
     *
     * Tail and Free have a relatively normal relationship.  Just
     * move Free to where Tail starts and add in its length.
     *
     * msg set to tail above, and its state to EMPTY.
     */
    gmc.free = msg->data;
    gmc.free_len += msg->len;
    gmc.allocated -= msg->len;
    return;
  }


  /*
   * msg_compelete: flag current message as complete
   *
   * current message is TAIL.
   */
  async command void GPSBuffer.msg_complete() {
    gps_msg_t *msg;             /* message slot we are working on */

    if (MSG_INDEX_INVALID(gmc.tail)) {  /* oht oh */
      gps_panic(GPSW_MSG_COMPLETE, gmc.tail, 0);
      return;
    }
    msg = &gps_msgs[gmc.tail];
    if (msg->state != GPS_MSG_FILLING) { /* oht oh */
      gps_panic(GPSW_MSG_COMPLETE, (parg_t) msg, msg->state);
      return;
    }

    msg->state = GPS_MSG_FULL;
    if (gmc.tail == gmc.head)
      post gps_receive_task();          /* start processing the queue */
  }


  command uint8_t *GPSBuffer.msg_next(uint16_t *len) {
    gps_msg_t *msg;             /* message slot we are working on */

    atomic {
      if (MSG_INDEX_INVALID(gmc.head))          /* empty queue */
        return NULL;
      msg = &gps_msgs[gmc.head];
      if (msg->state != GPS_MSG_FULL) {         /* oht oh */
        gps_panic(GPSW_MSG_NEXT, (parg_t) msg, msg->state);
        return NULL;
      }
      msg->state = GPS_MSG_BUSY;
      *len = msg->len;
      return msg->data;
    }
  }


  /*
   * msg_release: release the next message in the queue
   *
   * the next message to be released is always the HEAD
   */
  command void GPSBuffer.msg_release() {
    gps_msg_t *msg;             /* message slot we are working on */

    atomic {
      if (MSG_INDEX_INVALID(gmc.head)) {  /* oht oh */
        gps_panic(GPSW_MSG_RELEASE, gmc.head, 0);
        return;
      }
      msg = &gps_msgs[gmc.head];
      /* oht oh - only FULL or BUSY can be released */
      if (msg->state != GPS_MSG_BUSY && msg->state != GPS_MSG_FULL) {
        gps_panic(GPSW_MSG_RELEASE, (parg_t) msg, msg->state);
        return;
      }
      msg->state = GPS_MSG_EMPTY;
      if (gmc.head == gmc.tail) {
        /* releasing entire buffer */
        gmc.head     = MSG_NO_INDEX;
        gmc.tail     = MSG_NO_INDEX;
        gmc.full     = 0;
        gmc.allocated= 0;
        msg->extra   = 0;
        reset_free();
        return;
      }

      if (gmc.free > msg->data) {
        /*
         * slice (the head being released) is below the free pointer,
         * this means free is on the tail of the region.  (back of the
         * buffer).
         *
         * The release needs to get added to the aux region.
         */
        gmc.aux_len += msg->len + msg->extra;
        gmc.allocated -= (msg->len + msg->extra);
        msg->extra = 0;
        gmc.head = MSG_NEXT_INDEX(gmc.head);
        gmc.full--;
        return;
      }

      /*
       * must be free < slice (head)
       *
       * free space is in front of the slice (head).  no aux.  add the
       * space from head/slice to the free space.
       *
       * Note: It is possible to have the free pointer in the front of the
       * buffer with zero length, ie. free is empty (aux should also be empty).
       * It is important not to wrap and assign free to the front of the buffer,
       * this will cause real messages to get over written.  This is checked
       * in wrap_free().
       */
      if (gmc.aux_len) {
        /*
         * free space is in the front of the buffer (below the head/slice)
         * aux_len shouldn't have anything on it.  Bitch.
         */
        gps_panic(GPSW_MSG_RELEASE, gmc.aux_len, (parg_t) gmc.free);
        return;
      }
      gmc.free_len += msg->len + msg->extra;
      gmc.allocated -= (msg->len + msg->extra);
      msg->extra = 0;
      gmc.head = MSG_NEXT_INDEX(gmc.head);
      gmc.full--;
      return;
    }
  }

  default event void GPSReceive.msg_available(uint8_t *msg, uint16_t len) { }

  /*
   * Panic.hook
   */
  async event void Panic.hook() { }
}
