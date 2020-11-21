/*
 * Copyright (c) 2018, 2020 Eric B. Decker
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
  /**
   * GPSControl.turnOn()
   * start the GPS up and turn ON
   *
   * supports single/split phase
   *
   * returns:
   *   SUCCESS  split phase, gps start up initated.
   *   FAIL     oops
   *   EALREADY gps already started up and operational.
   *            single phase turn on.
   *
   * split phase:
   *   gps_boot_fail()          didn't work
   *   gps_booted()             comm established, and GPS is up.
   */
  command error_t turnOn();

  /* events signalling results of turnOn (comm boot) */
  event void gps_booted();
  event void gps_boot_fail();

  /**
   * GPSControl.turnOff()
   * make the GPS shutdown.   If necessary pull RESET
   *
   * supports single/split phase.
   *
   * returns:
   *   SUCCESS  split phase, gps shutdown initiated.
   *   FAIL     oops
   *   EALREADY gps already shutdown.
   *
   * split phase will complete with gps_shutdown.
   */
  command error_t turnOff();
  event   void    gps_shutdown();

  /*
   * force the GPS into hibernate state
   *
   * returns:
   *   SUCCESS  split phase, standby initiated.
   *   FAIL     oops
   *   EALREADY GPS in standby
   *
   * split phase will complete with the standbyDone() event.
   */
  command error_t standby();
  event   void    standbyDone();

  /*
   * wake the GPS up from hibernate
   *
   * returns:
   *   SUCCESS  split phase, wakeup initiated.
   *   FAIL     oops
   *   EALREADY GPS awake
   *
   * split phase will complete with the wakeupDone() event.
   */
  command error_t wakeup();
  event   void    wakeupDone();


  /* lower level control commands */
  command void hibernate();
  command void wake();
  command void pulseOnOff();
  command bool awake();

  command void reset();
  command void powerOn();
  command void powerOff();

  /*
   * logStats
   * log any statistics this module and its friends might have.
   * it will auto clear after logging.
   */
  command void logStats();
}
