/* Copyright 2015 Barry Friedman, Eric Decker
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
 * Contact: Barry Friedman <friedman.barry@gmail.com>
 *          Eric B. Decker <cire831@gmail.com>
 */

/*
 * PwrReg Interface
 *
 * Used when controlling pwr regulators that have a simple enable
 * coupled with a non-zero turn on time.
 *
 * When the regulator is off and has been turned on, it takes a
 * finite amount of time for the regulator to stablize.  The
 * pwrReg driver takes this into account and signals the PwrAvail
 * signal after enough time has passed for stabilization.
 *
 * command: pwrReq()   to request power
 * command: pwrRel()   to release demand for power on rail
 * event:   pwrAvail() to indicate power is stable.
 *
 * Typically, the pwrReg driver will maintain a use count.  If the
 * use count goes to 0, it will power the regulator down.
 */

/*
 * Looking at tps78233 datasheet, it looks like there's a about a 3ms delay
 * for Vout to reach say 3.3V when EN is driven about 1.2V. If the regulator is
 * on already there is no delay.
 *
 * Since there could be a delay needed if we need to enable the regulator
 * there needs to be an event to indicate when power is available.
 *
 */

interface PwrReg {

  /**
   * Request pwr
   *
   * @return SUCCESS the request has been accepted and a pwrAvail event
   *                 will be generated in the future.
   *
   *         EALREADY, pwr is already up and stable.
   */
  command error_t pwrReq();

  /**
   * Release pwr
   */
  command void    pwrRel();

  /**
   * pwrAvail event
   *
   * signals that power has stabilized.
   */
  event   void    pwrAvail();
}
