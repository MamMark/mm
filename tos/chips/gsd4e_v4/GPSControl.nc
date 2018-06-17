/*
 * Copyright (c) 2018 Eric B. Decker
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

interface GPSControl {
  /*
   * start the GPS up and turn ON
   *
   * upon completion will see either
   *
   *   gps_boot_fail()          didn't work
   *   gps_booted()             comm established, and GPS is up.
   */
  command error_t turnOn();

  /* events signalling results of turnOn (comm boot) */
  event void gps_booted();
  event void gps_boot_fail();

  /*
   * make the GPS shutdown.   If necessary pull RESET
   *
   * upon completion will see
   */
  command error_t turnOff();
  event   void    gps_shutdown();

  /*
   * force the GPS into hibernate state
   */
  command error_t standby();
  event   void    standbyDone();


  /* lower level control commands */
  command void hibernate();
  command void wake();
  command void pulseOnOff();
  command bool awake();

  command void reset();
  command void powerOn();
  command void powerOff();

  /*
   * log_errors
   * log any error this module and its friends might have.
   */
  command void logErrors();
}
