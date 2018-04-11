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

#include <rtc.h>
#include <rtctime.h>
#include <platform_panic.h>

#ifndef PANIC_TIME
enum {
  __pcode_time = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_TIME __pcode_time
#endif

module PlatformRtcP {
  provides interface Rtc;
  uses {
    interface Rtc as Msp432Rtc;
    interface LocalTime<TMilli>;
    interface Panic;
  }
}
implementation {
  async command void Rtc.rtcStop() {
    call Msp432Rtc.rtcStop();
  }


  async command void Rtc.rtcStart() {
    call Msp432Rtc.rtcStart();
  }


  async command bool Rtc.rtcValid(rtctime_t *time) {
    return call Msp432Rtc.rtcValid(time);
  }


  async command error_t Rtc.setTime(rtctime_t *timep) {
    return call Msp432Rtc.setTime(timep);
  }


  async command error_t Rtc.getTime(rtctime_t *timep) {
    uint32_t   lt;                      /* LocalTime (ms) */
    rtctime_t *rp;

    if (!timep)
      call Panic.panic(PANIC_TIME, 0, 0, 0, 0, 0);

    /*
     * for the time being, we fake it by filling in the low 32 bits with
     * a LocalTime (ms) stamp
     */
    lt = call LocalTime.get();
    rp = timep;
    memset(rp, 0, sizeof(*rp));
    rp->min     = (lt >> 24) & 0xff;    /* top byte        */
    rp->sec     = (lt >> 16) & 0xff;    /* next byte       */
    rp->sub_sec = lt & 0xffff;          /* and low 16 bits */
    return SUCCESS;

//  return call Msp432Rtc.getTime(timep);
  }


  async command void Rtc.clearTime(rtctime_t *timep) {
    call Msp432Rtc.clearTime(timep);
  }


  async command void Rtc.copyTime(rtctime_t *dtimep, rtctime_t *stimep) {
    call Msp432Rtc.copyTime(dtimep, stimep);
  }


  async command int Rtc.compareTimes(rtctime_t *time0p, rtctime_t *time1p) {
    call Msp432Rtc.compareTimes(time0p, time1p);
  }


  async command error_t Rtc.requestTime(uint32_t event_code) {
    return call Msp432Rtc.requestTime(event_code);
  }


  async command error_t Rtc.setEventMode(RtcEvent_t event_mode) {
    return call Msp432Rtc.setEventMode(event_mode);
  }


  async command RtcEvent_t Rtc.getEventMode() {
    return call Msp432Rtc.getEventMode();
  }


  async command error_t Rtc.setAlarm(rtctime_t *timep, uint32_t field_set) {
    call Msp432Rtc.setAlarm(timep, field_set);
  }


  async command uint32_t Rtc.getAlarm(rtctime_t *timep) {
    return call Msp432Rtc.getAlarm(timep);
  }


  async event void Msp432Rtc.currentTime(rtctime_t *timep,
                                 uint32_t reason_set) {
    signal Rtc.currentTime(timep, reason_set);
  }

  default async event void Rtc.currentTime(rtctime_t *timep,
                                     uint32_t reason_set) { }

  async event void Panic.hook() { }
}
