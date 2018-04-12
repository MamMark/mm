/**
 * @Copyright (c) 2017 Daniel J. Maltbie
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
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
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

    dirp = call IMD.dir_get_active();
    if (dirp) {
      call IMD.setVer(&dirp->ver_id, versionp);
      return SUCCESS;
    }
    return FAIL;
  }


  command error_t    SysActive.set_version(image_ver_t *versionp) {
    /* note that overwatch.install() is called when set_active_complete()
     * is signalled
     */
    return call IM.dir_set_active(versionp);
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

    dirp = call IMD.dir_get_backup();
    if (dirp) {
      call IMD.setVer(&dirp->ver_id, versionp);
      return SUCCESS;
    }
    return FAIL;
  }

  command error_t SysBackup.set_version(image_ver_t *versionp) {
    return call IM.dir_set_backup(versionp);
  }

  /*
   * Golden Image control
   */
  command uint8_t SysGolden.get_state() { return 'G'; }

  command error_t SysGolden.get_version(image_ver_t *versionp) {
    image_info_t    *infop = (void *) IMAGE_META_OFFSET;
    call IMD.setVer(&infop->ver_id, versionp);
    return SUCCESS;
  }

  command error_t SysGolden.set_version(image_ver_t *versionp) {
    image_ver_t run_verp;
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
    call IMD.setVer(&infop->ver_id, versionp);
    return SUCCESS;
  }

  command error_t SysNIB.set_version(image_ver_t *versionp) {
    image_ver_t run_verp;
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
    if (call OW.getImageBase())
      return call SysNIB.get_version(versionp);
    else
      return call SysGolden.get_version(versionp);
  }

  command error_t SysRunning.set_version(image_ver_t *versionp) {
    image_ver_t run_verp;

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
    error_t err;

    if (!rtp || (!lenp) || (*lenp < sizeof(*rtp)))
      call Panic.panic(PANIC_TAGNET, 11, 0, 0, 0, 0);

    err = call Rtc.getTime(rtp);
    if (err) {
      *lenp = 0;
      return FALSE;
    }
    return TRUE;
  }


  command bool SysRtcTime.set_value(rtctime_t *rtp, uint32_t *lenp) {
    error_t     err;

    if (!rtp || (!lenp) || (*lenp < sizeof(*rtp)))
      call Panic.panic(PANIC_TAGNET, 12, 0, 0, 0, 0);

    err = call Rtc.setTime(rtp);
    if (err) {
      *lenp = 0;
      return FALSE;
    }
    return TRUE;
  }


  event   void    IM.dir_set_active_complete() {
    /*
     * Image has now been set active, next step is to force Overwatch
     * to install it and then reboot into it.
     */
    call OW.install();          /* won't return */
  }


  event   void    IM.delete_complete() { }
  event   void    IM.dir_eject_active_complete() { }
  event   void    IM.dir_set_backup_complete() { }
  event   void    IM.finish_complete() {  }
  event   void    IM.write_continue() {  }
  async event void Rtc.currentTime(rtctime_t *timep, uint32_t reason_set) { }
  async event void Panic.hook() { }
}
