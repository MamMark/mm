/**
 * @Copyright (c) 2017-2018 Daniel J. Maltbie, Eric B. Decker
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
 * @contact: Daniel J. Maltbie <dmaltbie@daloma.org>
 *           Eric B. Decker <cire831@gmail.com>
 */

/**
 * This module provides functions for adapting system execution
 * control variables.
 */

#include <message.h>
#include <Tagnet.h>
#include <TagnetTLV.h>
#include <image_info.h>
#include <overwatch.h>
#include <rtctime.h>
#include <tagnet_panic.h>

typedef struct {
  uint32_t dir;
  rtctime_t time;
} last_rtc_t;

#define LAST_RTC_MAX 16
last_rtc_t last_rtc[LAST_RTC_MAX];
uint32_t   last_rtc_idx;

module TagnetSysExecP {
  provides interface  TagnetSysExecAdapter      as  SysActive;
  provides interface  TagnetSysExecAdapter      as  SysBackup;
  provides interface  TagnetSysExecAdapter      as  SysGolden;
  provides interface  TagnetSysExecAdapter      as  SysNIB;
  provides interface  TagnetSysExecAdapter      as  SysRunning;
  provides interface  TagnetAdapter<rtctime_t>  as  SysRtcTime;
  uses     interface  ImageManager              as  IM;
  uses     interface  ImageManagerData          as  IMD;
  uses     interface  OverWatch                 as  OW;
  uses     interface  Rtc;
  uses     interface  Panic;
}
implementation {

  void __last_grab_rtc(uint32_t dir, rtctime_t *rtp) {
    last_rtc[last_rtc_idx].dir = dir;
    call Rtc.copyTime(&(last_rtc[last_rtc_idx++].time), rtp);
    if (last_rtc_idx >= LAST_RTC_MAX)
      last_rtc_idx = 0;
  }


  /*
   * Active Image control
   */
  command uint8_t SysActive.get_state() {
    image_dir_slot_t    *dirp;

    dirp = call IMD.dir_get_active();
    if (dirp) {
      return call IMD.slotStateLetter(dirp->slot_state);
    }
    return ' ';
  }

  command error_t    SysActive.get_version(image_ver_t *versionp) {
    image_dir_slot_t    *dirp;

    if (!versionp)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    dirp = call IMD.dir_get_active();
    if (dirp) {
      call IMD.setVer(&dirp->ver_id, versionp);
      return SUCCESS;
    }
    return FAIL;
  }


  command error_t    SysActive.set_version(image_ver_t *versionp) {
    if (!versionp)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    return call IM.dir_set_active(versionp);
  }


  event   void    IM.dir_set_active_complete() {
    /*
     * Image has now been set active, next step is to force Overwatch
     * to install it and then reboot into it.
     */
    call OW.install();          /* won't return */
  }


  /*
   * Backup Image control
   */
  command uint8_t SysBackup.get_state() {
    image_dir_slot_t*dirp;

    dirp = call IMD.dir_get_backup();
    if (dirp) {
      return call IMD.slotStateLetter(dirp->slot_state);
    }
    return ' ';
  }

  command error_t SysBackup.get_version(image_ver_t *versionp) {
    image_dir_slot_t*dirp;

    if (!versionp)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    dirp = call IMD.dir_get_backup();
    if (dirp) {
      call IMD.setVer(&dirp->ver_id, versionp);
      return SUCCESS;
    }
    return FAIL;
  }

  command error_t SysBackup.set_version(image_ver_t *versionp) {
    if (!versionp)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    return call IM.dir_set_backup(versionp);
  }

  /*
   * Golden Image control
   */
  command uint8_t SysGolden.get_state() { return 'G'; }

  command error_t SysGolden.get_version(image_ver_t *versionp) {
    image_info_t    *infop = (void *) IMAGE_META_OFFSET;

    if (!versionp)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    call IMD.setVer(&infop->ver_id, versionp);
    return SUCCESS;
  }

  command error_t SysGolden.set_version(image_ver_t *versionp) {
    image_ver_t run_verp;

    if (!versionp)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    if ((call SysGolden.get_version(&run_verp) != SUCCESS) ||
        (!call IMD.verEqual(&run_verp, versionp)))
      return EINVAL;
    call OW.flush_boot(OW_BOOT_GOLD, ORR_USER_REQUEST);
    return SUCCESS;
  }

  /*
   * NIB Image control
   */
  command uint8_t SysNIB.get_state() { return 'N'; }

  command error_t SysNIB.get_version(image_ver_t *versionp) {
    image_info_t    *infop = (void *) NIB_BASE + IMAGE_META_OFFSET;

    if (!versionp)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    call IMD.setVer(&infop->ver_id, versionp);
    return SUCCESS;
  }

  command error_t SysNIB.set_version(image_ver_t *versionp) {
    image_ver_t run_verp;

    if (!versionp)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    if ((call SysNIB.get_version(&run_verp) != SUCCESS) ||
        (!call IMD.verEqual(&run_verp, versionp)))
      return EINVAL;
    call OW.flush_boot(OW_BOOT_NIB, ORR_USER_REQUEST);
    return SUCCESS;
  }

  /*
   * Running Image control
   */
  command uint8_t SysRunning.get_state() {
    uint8_t    st;
    if (call OW.getImageBase())
      st = call SysNIB.get_state();
    else
      st = call SysGolden.get_state();
    return st;
  }

  command error_t SysRunning.get_version(image_ver_t *versionp) {
    if (!versionp)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    if (call OW.getImageBase())
      return call SysNIB.get_version(versionp);
    else
      return call SysGolden.get_version(versionp);
  }

  command error_t SysRunning.set_version(image_ver_t *versionp) {
    image_ver_t run_verp;

    if (!versionp)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    if ((call SysRunning.get_version(&run_verp) != SUCCESS) ||
        (!call IMD.verEqual(&run_verp, versionp)))
      return EINVAL;
    if (call OW.getImageBase())
      call OW.flush_boot(OW_BOOT_NIB, ORR_USER_REQUEST);
    else
      call OW.flush_boot(OW_BOOT_GOLD, ORR_USER_REQUEST);
    return FAIL;                  /* won't get here! */
  }


  /*
   * System Rtctime control, get/set
   */
  command bool SysRtcTime.get_value(rtctime_t *rtp, uint32_t *lenp) {
    if (!rtp || (!lenp) || (*lenp < sizeof(*rtp)))
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    call Rtc.getTime(rtp);
    __last_grab_rtc(0, rtp);
    return TRUE;
  }


  command bool SysRtcTime.set_value(rtctime_t *rtp, uint32_t *lenp) {
    if (!rtp || (!lenp) || (*lenp < sizeof(*rtp)))
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    call Rtc.setTime(rtp);
    __last_grab_rtc(1, rtp);
    return TRUE;
  }


  event   void    IM.delete_complete() { }
  event   void    IM.dir_eject_active_complete() { }
  event   void    IM.dir_set_backup_complete() { }
  event   void    IM.finish_complete() {  }
  event   void    IM.write_continue() {  }
  async event void Rtc.currentTime(rtctime_t *timep, uint32_t reason_set) { }
  async event void Panic.hook() { }
}
