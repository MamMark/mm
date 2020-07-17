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
 */

/**
 * Define the interface to DockComm SPI hardware.
 *
 * 6 wires, 3 SPI, 3 control
 *
 * SCLK                     spi clock
 * SIMO                     spi slave in  master out
 * SOMI                     spi slave out master in
 * DC_ATTN                  master attn, start new packet
 * DC_SLAVE_RDY             slave is ready to catch, flow control
 * DC_MSG_PENDING           slave has a message for the master
 *
 * dc_byte_avail():         byte avail from h/w
 * dc_set_srsp():           set simple response byte.
 *
 * dc_send_block():         split phase.
 * dc_send_block_done():    completion on split phase
 * dc_send_block_stop():    stop current send_block (abort)
 *
 * dc_attn():               at attention event.
 * dc_unattn():             not at attention event.
 * dc_attn_pin():           get status of ATTN pin.
 * dc_attn_int_enable():    enable/disable rx interrupt.
 * dc_attn_int_disable():
 * dc_attn_int_enabled():   returns true if attn interrupt on.
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

interface DockCommHardware {

  event   void    dc_byte_avail(uint8_t byte);
  command void    dc_set_srsp(uint8_t   srsp);

  command error_t dc_send_block(uint8_t *ptr, uint16_t len);
  command void    dc_send_block_stop();
  event   void    dc_send_block_done(uint8_t *ptr, uint16_t len, error_t error);

  event   void    dc_atattn();
  event   void    dc_unattn();

  command uint8_t dc_attn_pin();
  command void    dc_attn_enable();
  command void    dc_attn_disable();
  command bool    dc_attn_enabled();
}
