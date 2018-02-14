/*
 * Copyright (c) 2017-2018 Eric B. Decker
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

/*
 * OverWatch to underlying hardware interface
 */

#include <image_info.h>

interface OverWatchHardware {
  /*
   * return a compacted Reset Status from the hardware.
   * clears any understood bits from the hardware.
   *
   * this is used for reporting status after a reset/reboot.
   * layout is h/w dependent.  See tos/<platform>/hardware/OWHardwareM.nc
   *
   * ResetOther is used for obtaining any other reset status bits that
   * we currently don't recognize (listed as reserved when this code was
   * written).  Should always be reported as 0.
   */
  async command uint32_t getResetStatus();
  async command uint32_t getResetOthers();

  /*
   * launch an image, typically a NIB region.
   *
   * if it fails just return.
   */
  async command void boot_image(image_info_t *iip);

  /*
   * soft_reset: software controlled reset.
   * hard_reset: hard reset (simulated POR)
   * fake_reset: relaunch, no reset.
   * flush:      tell reboot that we want a flush.
   *
   * soft_reset() is used when we don't want to bounce I/O pins.
   * software is responsible for all aspects of the reset.  This is
   * of course an oxymoron and there are probably some h/w components
   * that don't get reset.
   *
   * hard_reset() should be used to do the full monty.  Full POR if possible.
   *
   * fake_reset() is used when we don't want to do the real reset but
   * rather we do want some of the functionality.  Typically used when
   * debugging reset problems.
   *
   * flush() signals to the underlying reboot mechanisms to signal a reset
   * is imminent.
   */
  async command void soft_reset();
  async command void hard_reset();
  async command void fake_reset();
  async command void flush();

  /*
   * getImageBase: return base address of the image
   *
   * Where did the current executing image load.?
   */
  async command uint32_t getImageBase();

  /*
   * flash access.
   */
  async command error_t flashProtectAll();

  /* erase flash */
  async command error_t flashErase(uint8_t *start, uint32_t len);

  /* program flash */
  async command error_t flashProgram(uint8_t *src, uint8_t *fdest, uint32_t len);
}
