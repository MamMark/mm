/*
 * Copyright (c) 2008, 2010, 2011 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 30 March 2011
 *
 * Handle processing cmds received on the command (control) channel.
 */

// #include "Timer.h"
#include "mm_control.h"

volatile uint8_t cw = 0;

module CmdHandlerP {
  provides {
//    interface Init;
    interface StdControl as CmdControl;
  }
  uses {
//    interface Boot;
    interface AMSend;
    interface AMPacket;
    interface Packet;
    interface Timer<TMilli>;

    interface Receive      as CmdReceive;
    interface SplitControl as SerialControl;
    interface Leds;
  }
}

implementation {

  message_t msg;
  bool      msg_busy;
  am_addr_t dest_addr;
  uint8_t   seq;

//  event void Boot.booted() {
//    if (call SerialControl.start() != SUCCESS)
//      call Leds.set(7);
//  }
  
  command error_t CmdControl.start() {
    while (cw) {
      nop();
    }
    if (call SerialControl.start() != SUCCESS)
      call Leds.set(7);
    return SUCCESS;
  }

  void send(void) {
    message_t *dm;
    mm_cmd_t  *cmdp;
    uint8_t   *bp;
    uint8_t   i, len;

    dm = &msg;
    cmdp = call Packet.getPayload(dm, 10);
    cmdp->cmd = CMD_PING;
    cmdp->seq = seq;
    len = (seq & 0xf) + 1;
    bp = (uint8_t *) &cmdp->data[0];
    for (i = 0; i < len; i++)
      bp[i] = seq + i;
    cmdp->len = len + sizeof(mm_cmd_t);
    len = cmdp->len;
    call Packet.setPayloadLength(dm, len);
    call AMPacket.setSource(dm, (0xe010 | ((seq & 0xf) << 8) | (seq & 0xf)));
    call AMSend.send(dest_addr,  dm, len);
    seq++;
  }

  event void SerialControl.startDone(error_t err) {
    dest_addr = AM_BROADCAST_ADDR;
    seq = 1;
    if(err != SUCCESS)
      call Leds.set(7);
//    send();
  }

  event void AMSend.sendDone(message_t* m, error_t err) {
    if (m == &msg)
      msg_busy = FALSE;
#ifdef notdef
    call Timer.startOneShot(2*1024UL);
    if (dest_addr == AM_BROADCAST_ADDR)
      dest_addr = 0x0001;
    else if (dest_addr == 0x0001)
      dest_addr = 0x0004;
    else
      dest_addr = AM_BROADCAST_ADDR;
#endif
  }

  event void Timer.fired() {
//    send();
  }

  event void SerialControl.stopDone(error_t err) { }

  command error_t CmdControl.stop() {
    call SerialControl.stop();
    return SUCCESS;
  }

  event message_t * CmdReceive.receive(message_t * m, void * payload, uint8_t len) {
    mm_cmd_t * cmd = payload;
    nop();
    if (cmd->cmd == CMD_PING) {
      if (msg_busy)
	return m;
      cmd->cmd |= CMD_RESPONSE;
      dest_addr = call AMPacket.source(m);
      call AMSend.send(dest_addr, m, len);
      msg_busy = TRUE;
      m = &msg;
    }
   return m;
  }
}
