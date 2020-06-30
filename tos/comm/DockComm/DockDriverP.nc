/*
 * Copyright (c) 2020, Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 *
 * Dedicated usci spi port.
 */

#include <panic.h>
#include <platform_panic.h>
#include <dockcomm.h>

#ifndef PANIC_DOCK
enum {
  __pcode_dock = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_DOCK __pcode_dock
#endif

#ifdef  DOCK_EAVESDROP
#define DOCK_EAVES_SIZE 1024
norace uint8_t dbuf[DOCK_EAVES_SIZE];
norace uint32_t didx;
#endif

module DockDriverP {
  provides {
    interface MsgTransmit;
  }
  uses {
    interface DockProto;
    interface DockCommHardware as HW;

    interface Panic;
    interface Platform;
  }
}
implementation {

  void dock_warn(uint8_t where, parg_t p, parg_t p1) {
    call Panic.warn(PANIC_DOCK, where, p, p1, 0, 0);
  }

  void dock_panic(uint8_t where, parg_t p, parg_t p1) {
    call Panic.panic(PANIC_DOCK, where, p, p1, 0, 0);
  }


  command void MsgTransmit.send(uint8_t *ptr, uint16_t len) {
    call HW.dc_send_block(ptr, len);
  }

  event void HW.dc_send_block_done(uint8_t *ptr, uint16_t len, error_t error) {
  }

  command void MsgTransmit.send_abort() {
    call HW.dc_send_block_stop();
  }


  default event void MsgTransmit.send_done(error_t err) { }

  event void DockProto.msgStart(uint16_t len) {
  }


  event void DockProto.msgEnd() {
  }


  void driver_protoAbort(uint16_t reason) {
  }


  event void DockProto.protoAbort(uint16_t reason) {
    driver_protoAbort(reason);
  }


  event void HW.dc_byte_avail(uint8_t byte) {
#ifdef DOCK_EAVESDROP
    dbuf[didx++] = byte;
    if (didx >= DOCK_EAVES_SIZE)
      didx = 0;
#endif
    call DockProto.byteAvail(byte);
  }

  event void HW.dc_atattn() {
    call DockProto.protoRestart();
  }

  event void HW.dc_unattn() { }

  async event void Panic.hook() { }
}
