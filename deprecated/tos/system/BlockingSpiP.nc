/*
 * Copyright (c) 2008 Stanford University.
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Stanford University nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL STANFORD
 * UNIVERSITY OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Based on BlockingAMSenderImpl and BlockingResource by Kevin Klues
 */
 
/**
 * @author Kevin Klues (klueska@cs.stanford.edu)
 * @author Eric B. Decker (cire831@gmail.com)
 */

generic module BlockingSpiP() {
  provides {
    interface BlockingSpiByte;
    interface BlockingSpiPacket;
  }
  uses {
    interface SystemCall;
    interface SpiByte;
    interface SpiPacket;
  }
}

implementation {

  typedef struct byte_params {
    uint8_t tx;
    error_t  error;
  } byte_params_t;

  typedef struct packet_params {
    uint8_t *txBuf;
    uint8_t *rxBuf;
    uint16_t len;
    error_t  error;
  } packet_params_t;
  
  syscall_t* send_call;		// gets initialized to zero on boot

  /************************************************************/
  /********************** SpiPacket ***************************/
  /************************************************************/
  void sendTask(syscall_t* s) {
    packet_params_t* p = s->params;
    p->error = call SpiPacket.send(p->txBuf, p->rxBuf, p->len);
    if (p->error != SUCCESS)
      call SystemCall.finish(s);
  }
  
  command error_t BlockingSpiPacket.send(uint8_t *txBuf, uint8_t *rxBuf, uint16_t len) {
    syscall_t s;
    packet_params_t p;

    if (send_call)
      return EBUSY;

    /*
     * FIX ME.  The compiler complains if the atomic is missing (non-atomic write)
     * why doesn't it complain about the read?
     */
    atomic send_call = &s;
    
    p.txBuf = txBuf;
    p.rxBuf = rxBuf;
    p.len   = len;
    
    call SystemCall.start(&sendTask, &s, INVALID_ID, &p);

    atomic send_call = NULL;
    return p.error;
  }
  
  task void spiPacketDone() {
    call SystemCall.finish(send_call);
  }

  async event void SpiPacket.sendDone(uint8_t* txBuf, uint8_t* rxBuf, uint16_t len, error_t error) {
    packet_params_t* p;

    p = send_call->params;
    p->error = error;
    post spiPacketDone();
  }
  
  /***********************************************************/
  /********************** Spi Byte ***************************/
  /***********************************************************/
  void writeTask(syscall_t* s) {
    byte_params_t* p = s->params;
    p->error = call SpiByte.write(p->tx);
    call SystemCall.finish(s);
  }
  
  async command uint8_t BlockingSpiByte.write( uint8_t tx ) {
    syscall_t s;
    byte_params_t p;

    if (send_call)
      return EBUSY;

    send_call = &s;
    
    p.tx = tx;
    
    call SystemCall.start(&writeTask, &s, INVALID_ID, &p);

    send_call = NULL;
    return p.error;
  }
}
