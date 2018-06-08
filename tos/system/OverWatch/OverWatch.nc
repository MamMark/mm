/*
 * Copyright (c) 2017-2018 Daniel Maltbie, Eric B. Decker
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
 *          Daniel J. Maltbie <dmaltbie@danome.com>
 */

#include <image_mgr.h>
#include <overwatch.h>

/* move interface descriptions over to the implementation */

interface OverWatch {
  /**
   * Install
   *
   * Request the Overwatcher to load a new active image. The
   * new image should already have been written to the SD and the
   * directory entry marked as active. Otherwise, it will effectively
   * reboot the system.
   *
   */
  async command void install();

  /**
   * force_boot
   *
   * Request OverWatch to boot the system into the specified boot mode.
   * (OWT, GOLD, NIB).  This is a low level OverWatch command.  It does
   * not cause any buffers to be flushed.
   *
   * @param   boot_mode     which image instance to boot into
   * @param   reason        why the force_boot is being done
   * @return  error_t
   */
  async command void force_boot(ow_boot_mode_t boot_mode,
                                ow_reboot_reason_t reason);

  /**
   * flush_boot
   *
   * Request a reboot of the system into the specified mode but
   * first make sure any buffers are flushed.
   *
   * @param   boot_mode     which image instance to boot into
   * @param   reason        why the force_boot is being done
   * @return  error_t
   */
  async command void flush_boot(ow_boot_mode_t boot_mode,
                                ow_reboot_reason_t reason);

  /**
   * Fail
   *
   * Tell OverWatch that this image has failed.
   *
   * OverWatch will determine if the currently running instance has
   * exceeded a failure threshold (too many failures per unit of time) and
   * cause a fall back to the backup (previously active image). If no
   * backup image is available then Overwatch will launch Golden.
   *
   * @param reason      failure reason, most likely a panic or unhandled
   *                    interrupt
   */
  async command void fail(ow_reboot_reason_t reason);

  /**
   * Reboot
   *
   * Tell OverWatch to reboot.
   *
   * Used to force a reboot.  Overwatch will reexecute any request pending.
   *
   * @param reason      reboot reason, most likely ORR_LOW_PWR
   */
  async command void reboot(ow_reboot_reason_t reason);



  async command void strange(uint32_t loc);

  async command ow_boot_mode_t      getBootMode();
  async command void                clearReset();
  async command ow_control_block_t *getControlBlock();

  async command uint32_t            getImageBase();

  async command void                setFault(uint32_t fault_mask);
  async command void                clrFault(uint32_t fault_mask);

  async command void                halt_and_CF();

  async command void                incPanicCount();
}
