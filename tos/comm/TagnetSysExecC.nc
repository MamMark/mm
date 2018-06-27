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
#include <rtc.h>
#include <rtctime.h>

configuration TagnetSysExecC {
  provides interface  TagnetSysExecAdapter      as  SysActive;
  provides interface  TagnetSysExecAdapter      as  SysBackup;
  provides interface  TagnetSysExecAdapter      as  SysGolden;
  provides interface  TagnetSysExecAdapter      as  SysNIB;
  provides interface  TagnetSysExecAdapter      as  SysRunning;
  provides interface  TagnetAdapter<rtctime_t>  as  SysRtcTime;
}
implementation {
  components          TagnetSysExecP        as  Element;
  components          ImageManagerC;
  components          OverWatchC;
  components          PlatformC;
  components          PanicC;

  SysActive           =  Element.SysActive;
  SysBackup           =  Element.SysBackup;
  SysGolden           =  Element.SysGolden;
  SysNIB              =  Element.SysNIB;
  SysRunning          =  Element.SysRunning;
  SysRtcTime          =  Element.SysRtcTime;
  Element.IM         ->  ImageManagerC.IM[unique("image_manager_clients")];
  Element.IMD        ->  ImageManagerC;
  Element.OW         ->  OverWatchC;
  Element.Rtc        ->  PlatformC;
  Element.Panic      ->  PanicC;
}
