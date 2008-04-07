/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 *
 * Partially based on AMQueueImplP.nc copyright (c) 2005 Stanford
 * author Phil Levis
 */

/**
 * mm3Comm provides a single interface that can be switched between
 * the radio or the direct connect serial line.
 *
 * Control packets:
 *
 * Debug packets:
 *
 * Data packets:  Data packets are currently just used for sending
 * sensor eavesdrops.  Space is allocated for each sensor to have
 * at most one eavesdrop packet outstanding at any time.
 *
 * Each channel (control, debug, or data) contends for the comm line.
 * Data packets contend with each other before contending for the
 * comm line with control and debug traffic.
 *
 * @author Eric B. Decker
 * @date   Apr 3 2008
 */ 

#include "AM.h"
#include "sensors.h"

module mm3CommDataP {
  provides {
    interface mm3CommData[uint8_t client_id];
    interface Init;
  }
  uses {
    interface Panic;
    interface Send;
//    interface Receive;
    interface Packet;
    interface AMPacket;
  }
}

implementation {
  enum {
    DATA_OUT_CLIENTS = MM3_NUM_SENSORS,
  };

  /*
   * originally inUse and cancelling were bit masks to conserve RAM
   * space.  But the code generated is rather unwieldly so we went
   * with the simplier in code generation vs. slightly more costly
   * in ram space solution.  ie.  boolean arrays.
   */
  message_t  dataOutBufs[DATA_OUT_CLIENTS];
  message_t  *dataOut[DATA_OUT_CLIENTS];
  bool       inUse[DATA_OUT_CLIENTS];
  bool       cancelling[DATA_OUT_CLIENTS];
  uint8_t    outCur;

  /*
   * Accepts a buffer formatted as a data block (see sd_blocks.h) and sends
   * it out the DATA port.
   *
   * Addressing needs to be worked out.  Right now everything just goes to the
   * serial port.  This occurs via the call to the Comm layer which is responsible
   * for controlling whether comm uses the Radio or the Serial port (direct connect).
   *
   * This module uses the allocated (dataOutBufs) message for the outgoing message
   * (indexed via the sensor id, client id).  Only one outgoing message can be outstanding
   * per client (sensor).
   */

  command error_t mm3CommData.send_data[uint8_t client_id](void *buf, uint8_t len) {
    message_t *msg;
    error_t err;

    if (client_id >= DATA_OUT_CLIENTS) {
      return FAIL;
    }
    if (len > call Packet.maxPayloadLength())
      return FAIL;
    if (inUse[client_id])
      return EBUSY;

    msg = dataOut[client_id];
    inUse[client_id] = TRUE;
    call Packet.clear(msg);
    call Packet.setPayloadLength(msg, len);
    call AMPacket.setType(msg, AM_MM3_DATA);
    memcpy(call Packet.getPayload(msg, len), buf, len);

    /*
     * Fix me.  Need to do something about destination or group address of
     * the outgoing packet.
     */
    call AMPacket.setDestination(msg, AM_BROADCAST_ADDR);
    
    if (outCur >= DATA_OUT_CLIENTS) { // queue empty
      outCur = client_id;
      err = call Send.send(msg, len);
      if (err == SUCCESS)
	return err;

      /*
       * send failed.  bail after reseting back to empty
       */
      outCur = DATA_OUT_CLIENTS;
      inUse[client_id] = FALSE;
      return err;
    }
    return SUCCESS;
  }


  void nextPacket() {
    uint8_t i;

    outCur = (outCur + 1) % DATA_OUT_CLIENTS;
    for (i = 0; i < DATA_OUT_CLIENTS; i++) {
      if (inUse[outCur] && !cancelling[outCur])
	break;
      outCur = (outCur + 1) % DATA_OUT_CLIENTS;      
    }

    /*
     * if we have looked at all possibilites (i == DATA_OUT_CLIENTS)
     * mark the queue empty.
     */
    if (i >= DATA_OUT_CLIENTS)
      outCur = DATA_OUT_CLIENTS;
  }


  task void errorTask();

  void tryToSend() {
    error_t nextErr;
    message_t *nextMsg;
    uint8_t len;

    nextPacket();		// bumps outCur
    if (outCur < DATA_OUT_CLIENTS) { // queue not empty
      /*
       * something to do.  not empty and outCur points
       * at next entry that has a message with something
       * in it.
       */
      nextMsg  = dataOut[outCur];
      len = call Packet.payloadLength(nextMsg);
      nextErr = call Send.send(nextMsg, len);
      if(nextErr != SUCCESS)
	post errorTask();
    }
  }
  

  void sendDone(uint8_t last, message_t *msg, error_t err) {
    if (dataOut[last] != msg)
      call Panic.brk();
    inUse[last] = FALSE;
    tryToSend();
    signal mm3CommData.send_data_done[last](err);
  }


  task void errorTask() {
    sendDone(outCur, dataOut[outCur], FAIL);
  }


  event void Send.sendDone(message_t* msg, error_t err) {
    if (outCur >= DATA_OUT_CLIENTS) {
      call Panic.brk();
      return;
    }
    if(dataOut[outCur] == msg)
      sendDone(outCur, msg, err);
    else call Panic.brk();
  }
    

  command error_t Init.init() {
    uint8_t i;

    for (i = 0; i < DATA_OUT_CLIENTS; i++)
      dataOut[i] = &dataOutBufs[i];
    memset(inUse, 0, sizeof(inUse));
    memset(cancelling, 0, sizeof(cancelling));
    outCur = DATA_OUT_CLIENTS;
    return SUCCESS;
  }


  default event void mm3CommData.send_data_done[uint8_t client_id](error_t rtn) {
    call Panic.brk();
  }

#ifdef notdef
    task void CancelTask() {
        uint8_t i,j,mask,last;
        message_t *msg;
        for(i = 0; i < DATA_OUT_CLIENTS/8 + 1; i++) {
            if(cancelMask[i]) {
                for(mask = 1, j = 0; j < 8; j++) {
                    if(cancelMask[i] & mask) {
                        last = i*8 + j;
                        msg = dataOut[last].msg;
                        dataOut[last].msg = NULL;
                        cancelMask[i] &= ~mask;
                        signal Send.sendDone[last](msg, ECANCEL);
                    }
                    mask <<= 1;
                }
            }
        }
    }
    
    command error_t Send.cancel[uint8_t client_id](message_t* msg) {
        if (client_id >= DATA_OUT_CLIENTS ||         // Not a valid client    
            dataOut[client_id].msg == NULL ||    // No packet pending
            dataOut[client_id].msg != msg) {     // Not the right packet
            return FAIL;
        }
        if(outCur == client_id) {
            am_id_t amId = call AMPacket.type(msg);
            error_t err = call AMSend.cancel[amId](msg);
            return err;
        }
        else {
	  SET_MASK_BIT(cancelMask, client_id);
            post CancelTask();
            return SUCCESS;
        }
    }
#endif
}  
