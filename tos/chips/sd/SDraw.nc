/**
 * SD Raw access
 *
 * Copyright (c) 2010, Eric B. Decker, Carl W. Davis
 * Copyright (c) 2017, Eric B. Decker
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
 *          Carl W. Davis
 */

/*
 * Raw access to SD operations.
 *
 * The normal SD driver is event driven.   When we panic we stop the normal
 * execution of tinyos so the event driven driver no longer works.   Raw
 * access allows the panic driver to use the SD to dump out the machine state.
 */

#include "sd_cmd.h"

interface SDraw {
  command void      start_op();
  command void      end_op();
  command uint8_t   get();
  command void      put(uint8_t byte);
  command uint8_t   send_cmd(uint8_t cmd, uint32_t arg);
  command uint8_t   raw_acmd(uint8_t cmd, uint32_t arg);
  command uint8_t   raw_cmd(uint8_t cmd, uint32_t arg);
  command void      send_recv(uint8_t *tx, uint8_t *rx, uint16_t len);

  /*
   * Other SD operations
   *
   * See SDspP for definitions
   */
  async command uint32_t  blocks();
  async command bool      erase_state();
  async command bool      chk_zero(uint8_t  *sd_buf);
  async command bool      chk_erased(uint8_t  *sd_buf);
  async command bool      zero_fill(uint8_t *sd_buf, uint32_t offset);

  command uint32_t  ocr();              /*  32 bits */
  command error_t   cid(uint8_t *buf);  /* 128 bits */
  command error_t   csd(uint8_t *buf);  /* 128 bits */
  command error_t   scr(uint8_t *buf);  /*  64 bits */
}
