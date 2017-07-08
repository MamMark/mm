/*
 * Copyright (c) 2010, Eric B. Decker
 * All rights reserved.
 *
 * DTSender provides a queued mechanism for sending Typed Data messages across
 * the comm link.  One pending outgoing message is provided for each sensor
 * channel.
 *
 * Typed data blocks are defined in typed_data.h
 *
 * @author Eric B. Decker
 * @date   June 1 2010
 */ 

//#include "AM.h"
//#include "sensors.h"
//

#define dts_panic_comm(where, arg) do { call Panic.panic(PANIC_COMM, where, arg, 0, 0, 0); } while (0)

module DTSenderP {
  provides interface DTSender[uint8_t cid];
  uses {
    interface AMSend;
    interface Packet;
    interface Panic;
  }
}

implementation {
  message_t data_msg[NUM_SENSORS];

  enum {
    EMPTY=0xff,
  };

  uint8_t head = EMPTY;
  uint8_t tail = EMPTY;
  uint8_t fifo[NUM_SENSORS] = { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };


#if NUM_SENSORS != 10
#warning "MM_NUM_SENSORS/NUM_SENSORS is different than 10"
#endif

  message_t * const dm_p[NUM_SENSORS] = {
    &data_msg[0],
    &data_msg[1],
    &data_msg[2],
    &data_msg[3],
    &data_msg[4],
    &data_msg[5],
    &data_msg[6],
    &data_msg[7],
    &data_msg[8],
    &data_msg[9],
  };


  void advFifo(void) {
    uint8_t n;

    if (head == EMPTY)
      return;

    n = head;
    head = fifo[head];
    if (head == EMPTY)
      tail = EMPTY;
    fifo[n] = EMPTY;
  }


  bool inFifo(uint8_t id) {
    return (fifo[id] != EMPTY) || (tail == id);
  }


  /*
   * Accepts a buffer formatted as a data block (see typed_data.h) and sends
   * it out the DT port.
   *
   * A simple FIFO queued interface is used and one message per slot is reserved.
   * Slots for each sensor in the system are allocated and one extra (SNS_ID 0)
   * is used for generic messages.
   *
   * If idle then fire up a send.  If already busy push onto the fifo queue
   * similar to how the task queue works.
   */
  command error_t DTSender.send[uint8_t cid](void *buf, uint8_t len) {
    uint8_t *bp;
    message_t *dm;
    error_t err;

    if (cid >= NUM_SENSORS || inFifo(cid)) {
      dts_panic_comm(3, cid);
      return FAIL;
    }
    dm = dm_p[cid];
    bp = call Packet.getPayload(dm, len);
    if (!dm || !bp) {
      /*
       * note: getPayload checks len to see if the data will fit.  If not
       * it returns NULL.  This is the check for len > maxPayloadLength.
       */
      call Panic.panic(PANIC_COMM, 4, (parg_t) dm, (parg_t) bp, len, 0);
      return FAIL;
    }
    memcpy(bp, buf, len);
    call Packet.setPayloadLength(dm, len);

    /*
     * packet is ready to get shipped out.  If the fifo is empty, put it on
     * and launch a send.
     */
    if (head == EMPTY) {
      err = call AMSend.send(AM_BROADCAST_ADDR, dm, len);
      if (err) {
	dts_panic_comm(5, err);
	return err;
      }
      head = cid;			/* put it on the fifo */
      tail = cid;
      return err;
    }

    /*
     * fifo not empty.  add to tail
     */
    fifo[tail] = cid;
    tail = cid;
    return SUCCESS;
  }


  event void AMSend.sendDone(message_t* msg, error_t err) {
    uint8_t cid, len;
    message_t * dm;

    if (msg != dm_p[head] || err) {
      call Panic.panic(PANIC_COMM, 7, (parg_t) msg, err, 0, 0);
      return;
    }

    /*
     * clear out current head,  the signal back saying done can fire up the next one
     * so we need to be clear prior to the signal.
     */
    cid = head;
    advFifo();
    if (head != EMPTY) {
      dm = dm_p[head];
      len = call Packet.payloadLength(dm);
      err = call AMSend.send(AM_BROADCAST_ADDR, dm, len);
      if (err) {
	dts_panic_comm(8, err);
	return;
      }
    }
    signal DTSender.sendDone[cid](err);
  }


  default event void DTSender.sendDone[uint8_t cid](error_t rtn) {
    dts_panic_comm(10, 0);
  }

  async event void Panic.hook() { }
}
