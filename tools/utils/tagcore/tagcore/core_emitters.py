# Copyright (c) 2018-2019 Eric B. Decker
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# See COPYING in the top level directory of this source tree.
#
# Contact: Eric B. Decker <cire831@gmail.com>

'''basic emitters for core data type records'''

from   __future__         import print_function

__version__ = '0.4.6.dev11'

from   ctypes       import c_int32

from   core_rev     import *
from   dt_defs      import *

# GPS_{OD_FIX, FIX_MASK}, gps_{fix_name, expand_satmask, expand_trk_state}
from   gps_chip_utils import *

from   core_events  import *                    # get event_ids
from   core_events  import event_name
from   core_headers import rtc_src_name
from   core_headers import img_mgr_event_name

from   gps_mon      import *

from   sirf_defs    import *
import sirf_defs    as     sirf

from   sirf_headers import mids_w_sids
from   misc_utils   import dump_buf

from   sensor_defs  import *
import sensor_defs  as     sensor

################################################################
#
# REBOOT emitter, obj_dt_reboot, obj_owcb (in dt_reboot object)
#

# reboot emitter support

ow_bases = {
    0x00000000: "GOLD",
    0x00020000: "NIB",
    0xffffffff: "unset"
}

def base_name(base):
    return ow_bases.get(base, 'base: {:08x}'.format(base))

ow_boot_mode_strs = {
    0:  "GOLD",
    1:  "OWT",
    2:  "NIB",
}

ow_req_strs = {
    0:  "BOOT",
    1:  "INSTALL",
    2:  "FAIL",
}

owt_actions_strs = {
    0: "NONE",
    1: "INIT",
    2: "INSTALL",
    3: "EJECT",
}

ow_reboot_reason_strs = {
    0:  "NONE",
    1:  "FAIL",
    2:  "CLOBBER",
    3:  "STRANGE",
    4:  "FORCED",
    5:  "SKEW",
    6:  "USER",
    7:  "PANIC",
    8:  "LOWPWR",

    'PANIC': 7,
}

REASON_PANIC = ow_reboot_reason_strs['PANIC']

def ow_boot_mode_name(mode):
    return ow_boot_mode_strs.get(mode, 'boot/' + str(mode))

def ow_req_name(req):
    return ow_req_strs.get(req, 'req/' + str(req))

def owt_action_name(action):
    return ow_action_strs.get(action, 'action/' + str(action))

def reboot_reason_name(reason):
    return ow_reboot_reason_strs.get(reason, 'reason/' + str(reason))


# --- offset recnum  systime  len  type  name
# --- 999999 999999 99999999  999    99  ssssss
# ---    512      1      322  116     1  REBOOT  NIB -> GOLD (GOLD)  (r/f)

rbt0  = '  {:s} -> {:s}  [{:s}] <{:s}>'

rbt0a = '    REBOOT: {:7s}  f: {:5s}  c: {:5s}  m: {:5s}  rbts/g/n: {}/{}/{}   chk_fails: {}'
rbt0b = '    rt: 2017/12/26-(mon)-01:52:40 GMT  rev: {:4d}/{:d}'
rbt_p = '    PANIC: {}  p/w: {}/{}  args: x({:04x} {:04x} {:04x} {:04x})'

rbt2a = '    sigs:    {:08x}    {:08x}  {:08x}'
rbt2b = '    base:  f {:08x}  cur:     {:08x}'
rbt2c = '    rpt:     {:08x}  reset:   {:08x}      others: {:08x}'
rbt2d = '    fault/g: {:08x}  fault/n: {:08x}  ss/disable: {:08x}  ps: {:04x}'
rbt2e = '    reboots: {:4}  panics (g/n): {:4}/{:<4}  strg: {:4}  loc: {:4}'
rbt2f = '    uptime: {}  boot: {}  prev: {}'
rbt2g = '    rbt_reason:   {:2}  ow_req: {:2}  mode: {:2}  act:  {:2}'

# obj is obj_dt_reboot (includes an obj_owcb record)
def emit_reboot(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    brt      = rtctime_str(rtctime)

    core_rev = obj['core_rev'].val
    core_minor = obj['core_minor'].val
    base     = obj['base'].val
    if core_rev != CORE_REV or core_minor != CORE_MINOR:
        print('*** version mismatch, expected {:d}/{:d}, got {:d}/{:d}'.format(
            CORE_REV, CORE_MINOR, core_rev, core_minor))

    owcb         = obj['owcb']
    boot_time    = owcb['boot_time']
    prev_boot    = owcb['prev_boot']
    from_base    = owcb['from_base'].val
    panic_count  = owcb['panic_count'].val
    fault_gold   = owcb['fault_gold'].val
    fault_nib    = owcb['fault_nib'].val
    ss_dis       = owcb['subsys_disable'].val
    protec_stat  = owcb['protection_status'].val
    boot_mode    = owcb['ow_boot_mode'].val
    reboot_count = owcb['reboot_count'].val
    chk_fails    = owcb['chk_fails'].val
    log_flags    = owcb['logging_flags'].val
    panics_gold  = owcb['panics_gold'].val

    pi_idx       = owcb['pi_panic_idx'].val
    pi_pcode     = owcb['pi_pcode'].val
    pi_where     = owcb['pi_where'].val
    pi_arg0      = owcb['pi_arg0'].val
    pi_arg1      = owcb['pi_arg1'].val
    pi_arg2      = owcb['pi_arg2'].val
    pi_arg3      = owcb['pi_arg3'].val

    rtc_src      = owcb['rtc_src'].val

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')
    print(rbt0.format(base_name(from_base), base_name(base),
                      ow_boot_mode_name(boot_mode),
                      reboot_reason_name(owcb['reboot_reason'].val)))

    # any weird failures?  Always report
    if (chk_fails or fault_gold or fault_nib or ss_dis):
        print('*** chkfails: {}  fault/g: {:08x}  fault/n: {:08x}  ss_dis: {:08x}'.format(
            chk_fails, fault_gold, fault_nib, ss_dis))

    print(rbt0a.format(
        reboot_reason_name(owcb['reboot_reason'].val),
        base_name(from_base), base_name(base),
        ow_boot_mode_name(owcb['ow_boot_mode'].val),
        reboot_count, panics_gold, panic_count, chk_fails))
    print(rbt0b.format(core_rev, core_minor))

    if owcb['reboot_reason'].val == REASON_PANIC:
        print(rbt_p.format(pi_idx, pi_pcode, pi_where,
                           pi_arg0, pi_arg1, pi_arg2, pi_arg3))

    if (level >= 2):                    # detailed display (level 2)
        print()
        print(rbt2a.format(owcb['ow_sig'].val,
                   owcb['ow_sig_b'].val, owcb['ow_sig_c'].val))
        print(rbt2b.format(from_base, base))
        print(rbt2c.format(owcb['rpt'].val, owcb['reset_status'].val,
              owcb['reset_others'].val))
        print(rbt2d.format(fault_gold, fault_nib, ss_dis, protec_stat))
        print(rbt2e.format(reboot_count, panics_gold, panic_count,
                           owcb['strange'].val,
                           owcb['strange_loc'].val))
#        print(rbt2f.format(0, owcb['boot_time'], owcb['prev_boot']))
        print(rbt2f.format(0, 0, 0))
        print(rbt2g.format(owcb['reboot_reason'].val,
                           owcb['ow_req'].val,
                           owcb['ow_boot_mode'].val,
                           owcb['owt_action'].val))


################################################################
#
# VERSION emitter, obj_dt_version, obj_image_info
#

# version emitter support

model_strs = {
    0x01:       'mm6a',
    0xf0:       'dev6a',
}


def model_name(model):
    return model_strs.get(model, 'model/' + str(model))


# --- offset recnum      brt  len  type  name
# --- 999999 999999 3599.999  999    99  ssssss
# ---    512      1      322  116     1  VERSION  NIB 0.2.63  hw: dev6a/1

ver0  = ' {:s}  {:s}  hw: {:s}/{:d}'

ver1a = '    VERSION: {:10s}  hw model/rev: {:x}/{:x} ({:s}/{:d})  r/i: x({:x}/{:x})'
ver2a = '    desc:       placeholder'
ver2b = '    repo0:  (p) heads/tp-master-0-g0ac8c73-dirty'
ver2b0= '                [https://github.com/tp-freeforall/prod]'
ver2c = '    repo1:  (m) heads/recsum-0-g04de0f8-dirty'
ver2c0= '                [https://github.com/cire831/mm]'
ver2d = '    date:   Fri Dec 29 04:05:07 UTC 2017      ib/len: 0x{:x}/{:d} (0x{:x})'
ver2e = '    ii_sig: 0x{:08x}  chksum: 0x{:08x}'

def emit_version(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    base     = obj['base'].val
    ii       = obj['image_info']
    brt      = rtctime_str(rtctime)

    ver_str = '{:d}.{:d}.{:d}'.format(
        ii['basic']['ver_id']['major'].val,
        ii['basic']['ver_id']['minor'].val,
        ii['basic']['ver_id']['build'].val)
    model = ii['basic']['hw_ver']['model'].val
    rev   = ii['basic']['hw_ver']['rev'].val

    # convert description and build_date strings to something reasonable
#    desc  = ii['plus']['image_desc'].val
#    desc  = desc[:desc.index('\0')]
#
#    repo0 = ii['plus']['repo0'].val
#    repo0 = repo0[:repo0.index('\0')]
#
#    repo1 = ii['plus']['repo1'].val
#    repo1 = repo1[:repo1.index('\0')]
#
#    stamp_date = ii['plus']['stamp_date'].val
#    stamp_date = stamp_date[:stamp_date.index('\0')]

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')
    print(ver0.format(base_name(base), ver_str, model_name(model), rev))
    if (level >= 1):
        print(ver1a.format(ver_str, model, rev, model_name(model), rev,
                           base, ii['basic']['im_start'].val))

    if (level >= 2):
        print()
        print(ver2a)
        print(ver2b)
        print(ver2b0)
        print(ver2c)
        print(ver2c0)
        print(ver2d.format(ii['basic']['im_start'].val,
                       ii['basic']['im_len'].val,
                       ii['basic']['im_len'].val))
        print(ver2e.format(ii['basic']['ii_sig'].val,
                           ii['basic']['im_chk'].val))


################################################################
#
# SYNC emitter
# uses decode_default with dt_sync_obj to decode
#

sync0  = '  prev: @{:d} (0x{:x})'

sync1a = '    SYNC: majik:  0x{:x}   prev: {} (0x{:x})'
sync1b = '          dt: 2017/12/26-01:52:40 (1) GMT'

def emit_sync(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    brt      = rtctime_str(rtctime)

    majik    = obj['majik'].val
    prev     = obj['prev_sync'].val

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')
    print(sync0.format(prev, prev))

    if (level >= 1):
        print(sync1a.format(majik, prev, prev))
        print(sync1b.format())


################################################################
#
# EVENT emitter
# uses decode_default with dt_event_obj to decode
#

event0  = ' {:14s} {} {} {} {}'
event1  = '    {:14s}: ({}) <{} {} {} {}>  x({:x} {:x} {:x} {:x})'

def emit_event(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    brt      = rtctime_str(rtctime)

    event = obj['event'].val
    arg0  = obj['arg0'].val
    arg1  = obj['arg1'].val
    arg2  = obj['arg2'].val
    arg3  = obj['arg3'].val
    pcode = obj['pcode'].val
    w     = obj['w'].val

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')

    if (level >= 1):
        print(event1.format(event_name(event), event,
                            arg0, arg1, arg2, arg3,
                            arg0, arg1, arg2, arg3))

    if (event == PANIC_WARN):
        # special case, print PANIC_WARNs always, full display
        print(' {} {}/{}'.format(event_name(event), pcode, w))
        print('    {} {} {} {}  x({:04x} {:04x} {:04x} {:04x})'.format(
            arg0, arg1, arg2, arg3, arg0, arg1, arg2, arg3))
        return

    # deprecated, backward compatibility
    if event == EV_GPS_GEO:
        arg0 = c_int32(arg0).value/10000000.
        arg1 = c_int32(arg1).value/10000000.
        arg3 = arg3/1000.
        print(' {:14s}  {:10.7f}  {:10.7f}  wk/tow: {}/{}'.format(
            event_name(event), arg0, arg1, arg2, arg3))
        return

    # deprecated, backward compatibility
    if event == EV_GPS_XYZ:
        arg1 = c_int32(arg1).value
        arg2 = c_int32(arg2).value
        arg3 = c_int32(arg3).value
        print(' {:14s} {} - x: {}  y: {}  z: {}'.format(
            event_name(event), arg0, arg1, arg2, arg3))
        return

    # deprecated, backward compatibility
    if event == EV_GPS_TIME:
        year = (arg0 >> 16) & 0xffff
        mon  = (arg0 >> 8)  & 0xff
        day  =  arg0        & 0xff
        hr   = (arg1 >> 8)  & 0xff
        xmin =  arg1        & 0xff
        secs =  arg2 / 1000.
        print(' {:14s} UTC: {}/{:02}/{:02} {:2}:{:02}:{}'.format(
            event_name(event), year, mon, day, hr, xmin,
            '{:.3f}'.format(secs).zfill(6)))
        return

    if event == DCO_REPORT:
        arg0 = c_int32(arg0).value
        arg1 = c_int32(arg1).value
        arg2 = c_int32(arg2).value
        arg3 = c_int32(arg3).value
        # fall through to bottom

    if event == DCO_SYNC:
        arg0 = c_int32(arg0).value
        arg1 = c_int32(arg1).value
        arg2 = c_int32(arg2).value
        arg3 = c_int32(arg3).value
        print(' {:14s} adj: {}  delta: {} ({}/{})'.format(
            event_name(event), arg0, arg1, arg2, arg3))
        return

    if event == TIME_SRC:
        arg1 = arg0
        arg0 = rtc_src_name(arg0)
        # fall through to bottom

    if event == IMG_MGR:
        print(' {:14s} {:6s} 0x{:x} 0x{:x} {}'.format(
            event_name(event), img_mgr_event_name(arg0),
                            arg1, arg2, arg3))
        return

    if (event == GPS_MON_MINOR):
        print(' gps/mon (MINOR) {:^15s} {:>12s} -> {}'.format(
            '<{}>'.format(gps_mon_event_name(arg2)),
            gps_mon_minor_name(arg0),
            gps_mon_minor_name(arg1)))
        return

    if (event == GPS_MON_MAJOR):
        print(' gps/mon (MAJOR) {:^15s} {:>12s} -> {}'.format(
            '<{}>'.format(gps_mon_event_name(arg2)),
            gps_mon_major_name(arg0),
            gps_mon_major_name(arg1)))
        return

    if (event == GPS_CMD):
        print(' GPS_CMD ({:s}) {} {} {} {}'.format(
            gps_cmd_name(arg0), arg0, arg1, arg2, arg3))
        return

    if event == GPS_RX_ERR:
        print(' GPS_RX_ERR: 0x{:02x}  nerr delta: {}  state: {}'.format(
            arg0, arg1 - arg2, arg3))
        return

    if event == GPS_MPM_RSP:
        print(' GPS_MPM_RSP    0x{:04x} ({}) {} {}'.format(
            arg0, arg1, arg2, arg3))
        return

    print(event0.format(event_name(event), arg0, arg1, arg2, arg3))


################################################################
#
# DEBUG emitter
# uses decode_default with obj_dt_debug to decode
#

debug0  = ' xxxx'

def emit_debug(level, offset, buf, obj):
    xlen     = obj['len'].val
    xtype    = obj['type'].val
    recnum   = obj['recnum'].val
    rtctime  = obj['rt']
    brt      = rtctime_str(rtctime)

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')
    print(debug0.format())


################################################################
#
# GPS_VERSION emitter
# uses decode_default with dt_gps_hdr_obj to decode
#

def emit_gps_version(level, offset, buf, obj):
    xlen     = obj['gps_hdr']['hdr']['len'].val
    xtype    = obj['gps_hdr']['hdr']['type'].val
    recnum   = obj['gps_hdr']['hdr']['recnum'].val
    rtctime  = obj['gps_hdr']['hdr']['rt']
    brt      = rtctime_str(rtctime)

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype, dt_name(xtype)))
    if (level >= 1):
        print('    {}'.format(obj['sirf_swver']))


def emit_gps_time(level, offset, buf, obj):
    xlen     = obj['gps_hdr']['hdr']['len'].val
    xtype    = obj['gps_hdr']['hdr']['type'].val
    recnum   = obj['gps_hdr']['hdr']['recnum'].val
    rtctime  = obj['gps_hdr']['hdr']['rt']
    brt      = rtctime_str(rtctime)

    capdelta=obj['capdelta'].val
    tow    = obj['tow1000'].val/float(1000)
    week_x = obj['week_x'].val
    year   = obj['utc_year'].val
    mon    = obj['utc_month'].val
    day    = obj['utc_day'].val
    hr     = obj['utc_hour'].val
    xmin   = obj['utc_min'].val
    ms     = obj['utc_ms'].val
    nsats  = obj['nsats'].val
    secs   = ms/1000
    ms     = ms - secs * 1000

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')

    print('  UTC: {}/{:02}/{:02} {:2}:{:02}:{:02}.{:03}  {}/{:4.3f}         [{}]'.format(
        year, mon, day, hr, xmin, secs, ms, week_x, tow, nsats))


def emit_gps_geo(level, offset, buf, obj):
    xlen     = obj['gps_hdr']['hdr']['len'].val
    xtype    = obj['gps_hdr']['hdr']['type'].val
    recnum   = obj['gps_hdr']['hdr']['recnum'].val
    rtctime  = obj['gps_hdr']['hdr']['rt']
    brt      = rtctime_str(rtctime)

    capdelta  = obj['capdelta'].val
    nav_valid = obj['nav_valid'].val
    nav_type  = obj['nav_type'].val
    lat       = obj['lat'].val/10000000.
    lon       = obj['lon'].val/10000000.
    alt_ell   = obj['alt_ell'].val/100.
    alt_msl   = obj['alt_msl'].val/100.
    satmask   = obj['sat_mask'].val
    tow       = obj['tow1000'].val/1000.
    week_x    = obj['week_x'].val
    nsats     = obj['nsats'].val
    add_mode  = obj['add_mode'].val
    ehpe      = obj['ehpe100'].val/100.
    hdop      = obj['hdop5'].val/5.

    # if nav_valid is 0 we are overdetermined.
    fix_type = (nav_type & GPS_FIX_MASK) if nav_valid else GPS_OD_FIX
    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')

    print('   {:10.7f}  {:10.7f}      {}/{:4.3f}  {:5}  [{}]'.format(
        lat, lon, week_x, tow, gps_fix_name(fix_type), nsats))

    if (level >= 1):
        alt_ell_ft = alt_ell * 3.28084
        alt_msl_ft = alt_msl * 3.28084
        # if nav_valid nonzero we don't have a valid fix (no lock)
        valid_str  = 'valid: x{:04x}  '.format(nav_valid) if nav_valid else ''
        print('    {}type: x{:04x}  ehpe: {}  hdop: {:4.1f}  [{}] ({:08x})'.format(
            valid_str, nav_type, ehpe, hdop, gps_expand_satmask(satmask),
            satmask), end = '')
        print('  msl: {:3.1f} ({:3.1f})'.format(alt_msl_ft, alt_msl))


def emit_gps_xyz(level, offset, buf, obj):
    xlen     = obj['gps_hdr']['hdr']['len'].val
    xtype    = obj['gps_hdr']['hdr']['type'].val
    recnum   = obj['gps_hdr']['hdr']['recnum'].val
    rtctime  = obj['gps_hdr']['hdr']['rt']
    brt      = rtctime_str(rtctime)

    capdelta \
          = obj['capdelta'].val
    x     = obj['x'].val
    y     = obj['y'].val
    z     = obj['z'].val
    sats  = obj['sat_mask'].val
    tow   = obj['tow100'].val/float(100)
    weekx = obj['week_x'].val
    m1    = obj['m1'].val
    hdop  = obj['hdop5'].val/5.
    nsats = obj['nsats'].val

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')

    fix     = m1 & GPS_FIX_MASK
    fix_str = gps_fix_name(fix)
    print('   {}/{}/{}     {}/{:4.3f}  {:6} [{}]'.format(
        x, y, z, weekx, tow, fix_str, nsats))

    if (level >= 1):
        print('    ',  end = '')
        print('m1: {:02x}  hdop: {:4.1f}  [{}]  ({:08x})'.format(
            m1, hdop, gps_expand_satmask(sats), sats))


def emit_gps_trk(level, offset, buf, obj):
    xlen     = obj['gps_hdr']['hdr']['len'].val
    xtype    = obj['gps_hdr']['hdr']['type'].val
    recnum   = obj['gps_hdr']['hdr']['recnum'].val
    rtctime  = obj['gps_hdr']['hdr']['rt']
    brt      = rtctime_str(rtctime)

    capdelta  = obj['capdelta'].val
    tow       = obj['tow100'].val/float(100)
    week10    = obj['week'].val
    chans     = obj['chans'].val
    good_sats = 0
    nz_sats   = 0
    sat_min   = 50.0
    sat_max   = 0.0
    xavg      = 0.0

    for n in range(chans):
        cno_avg = obj[n]['cno_avg']
        svid    = obj[n]['svid']
        if cno_avg and svid <= 32:
            nz_sats += 1
            xavg += cno_avg
            if cno_avg < sat_min: sat_min = cno_avg
            if cno_avg > sat_max: sat_max = cno_avg
            if cno_avg >= 20.0:
                good_sats += 1

    xavg = xavg/nz_sats if nz_sats != 0.0 else 0.0
    if sat_min >= 50.0: sat_min = 0
    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')
    print('  {}/{}  {:4.1f}  {:4.1f}  {:4.1f}'.format(
        good_sats, nz_sats, sat_min, xavg, sat_max))

    if level >= 1:
        print('    NAV_TRACK: {}/{:.3f}s  chans: {}'.format(
            week10, tow, chans))
        for n in range(chans):
            svid    = obj[n]['svid']
            az      = obj[n]['az10']/10.0
            el      = obj[n]['el10']/10.0
            state   = obj[n]['state']
            cno_avg = obj[n]['cno_avg']
            if cno_avg > 0.0 or level >= 2:
                print('    {:3}: az: {:5.1f}  el: {:5.1f}  {:#04x} {:8}  cno: {:4.1f}'.format(
                    svid, az, el, state, gps_expand_trk_state_short(state), cno_avg))

    if level >= 2:
        print()
        for n in range(chans):
            svid    = obj[n]['svid']
            az      = obj[n]['az10']/10.0
            el      = obj[n]['el10']/10.0
            state   = obj[n]['state']
            cno_str = ''
            for i in range(10):
                cno_str += ' {:2}'.format(obj[n]['cno'+str(i)])
            print('    {:3}: az: {:5.1f}  el: {:5.1f}  {:#04x} {:8}  cno/s: {}'.format(
                svid, az, el, state, gps_expand_trk_state_short(state), cno_str))
            if state:
                print('                                    ', end='')
                print('{}'.format(gps_expand_trk_state_long(state)))


def emit_gps_clk(level, offset, buf, obj):
    xlen     = obj['gps_hdr']['hdr']['len'].val
    xtype    = obj['gps_hdr']['hdr']['type'].val
    recnum   = obj['gps_hdr']['hdr']['recnum'].val
    rtctime  = obj['gps_hdr']['hdr']['rt']
    brt      = rtctime_str(rtctime)

    capdelta = obj['capdelta'].val
    tow      = obj['tow100'].val/float(100)
    weekx    = obj['week_x'].val
    nsats    = obj['nsats'].val
    drift    = obj['drift'].val
    bias     = obj['bias'].val

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')
    print('  {}/{:.3f}  {}  {}  [{}]'.format(
        weekx, tow, drift, bias, nsats))


    if level >= 1:
        print('    CLK_STATUS: capture: {}'.format(capdelta))


################################################################
#
# SENSOR/SET decoders
#

def emit_sensor_data(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    brt      = rtctime_str(rtctime)

    delta    = obj['sched_delta'].val
    sns_id   = obj['sns_id'].val

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')

    v = sensor.sns_table.get(sns_id, ('', None, None, None, None, ''))
    print('  {:s}  {:s}'.format(sns_name(sns_id), sns_val_str(sns_id)))

    if level >= 1:
        print('{:>74s}'.format(sns_val_str(sns_id, level)))


def emit_sensor_set(level, offset, buf, obj):
    dump_hdr(offset, buf)
    if (level >= 1):
        print(obj)
        print_hdr_obj(obj)
        print()


################################################################
#
# TEST decoder
#

test0  = '    xxxx'

def emit_test(level, offset, buf, obj):
    xlen     = obj['len'].val
    xtype    = obj['type'].val
    recnum   = obj['recnum'].val
    rtctime  = obj['rt']
    brt      = rtctime_str(rtctime)

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')
    print(test0.format())


################################################################
#
# NOTE emitter
#
# notes can have pretty much anything in them.  They may or may not
# be terminated with a NUL.  We strip the NUL and any trailing whitespace
#

def emit_note(level, offset, buf, obj):
    xlen     = obj['len'].val
    xtype    = obj['type'].val
    recnum   = obj['recnum'].val
    rtctime  = obj['rt']
    brt      = rtctime_str(rtctime)

    # isolate just the note, and strip NUL and whitespace
    note     = buf[len(obj):]
    note     = note.rstrip('\0')
    note     = note.rstrip()

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,         # sans nl
                      dt_name(xtype)), end = '')
    if (len(note) > 44):
        print()
    print('    {}'.format(note))


################################################################
#
# CONFIG decoder
#

cfg0  = ' xxxx'

def emit_config(level, offset, buf, obj):
    xlen     = obj['len'].val
    xtype    = obj['type'].val
    recnum   = obj['recnum'].val
    rtctime  = obj['rt']
    brt      = rtctime_str(rtctime)

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,         # sans nl
                      dt_name(xtype)), end = '')
    print(cfg0.format())


########################################################################
#
# GPS Proto Stats
#
#sirf stats: t/o chk err frm ovr par rst  proto    </>     ign
#99999/99999 999 999 999 999 999 999 999 999/999 999/999 99999
#
def emit_gps_proto_stats(level, offset, buf, obj):
    hdr      = obj['hdr']
    xlen     = hdr['len'].val
    xtype    = hdr['type'].val
    recnum   = hdr['recnum'].val
    rtctime  = hdr['rt']
    brt      = rtctime_str(rtctime)

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,         # sans nl
                      dt_name(xtype)), end = '')
    stats               =   obj['stats']
    starts              = stats['starts'].val
    complete            = stats['complete'].val
    ignored             = stats['ignored'].val
    resets              = stats['resets'].val
    too_small           = stats['too_small'].val
    too_big             = stats['too_big'].val
    chksum_fail         = stats['chksum_fail'].val
    rx_timeouts         = stats['rx_timeouts'].val
    rx_errors           = stats['rx_errors'].val
    rx_framing          = stats['rx_framing'].val
    rx_overrun          = stats['rx_overrun'].val
    rx_parity           = stats['rx_parity'].val
    proto_start_fail    = stats['proto_start_fail'].val
    proto_end_fail      = stats['proto_end_fail'].val
    print('  e: {}  r: {}  f: {}  o: {}'.format(rx_errors, resets,
                                             rx_framing, rx_overrun))
    if level >= 1:
        print('    sirf stats: t/o chk err frm ovr par rst  proto    </>     ign')
        print('    {:5d}/{:<5d} {:3d} {:3d} {:3d} {:3d} {:3d} {:3d} {:3d} {:3d}/{:<3d} {:3d}/{:<3d} {:5d}'.format(
            complete,   starts,           rx_timeouts,    chksum_fail,
            rx_errors,  rx_framing,       rx_overrun,     rx_parity,
            resets,     proto_start_fail, proto_end_fail,
            too_small,  too_big,          ignored))


########################################################################
#
# main gps raw emitter, displays DT_GPS_RAW_SIRFBIN
# obj_dt_gps_raw, 2nd level emit on mid
#

def emit_gps_raw(level, offset, buf, obj):
    xlen     = obj['gps_hdr']['hdr']['len'].val
    xtype    = obj['gps_hdr']['hdr']['type'].val
    recnum   = obj['gps_hdr']['hdr']['recnum'].val
    rtctime  = obj['gps_hdr']['hdr']['rt']
    brt      = rtctime_str(rtctime)

    dir_bit  = obj['gps_hdr']['dir'].val
    dir_str  = 'rx' if dir_bit == 0 else 'tx'

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')
    if (obj['sirf_hdr']['start'].val != SIRF_SOP_SEQ):
        index = len(obj) - len(obj['sirf_hdr'])
        print('-- non-binary <{:2}>'.format(dir_str))
        if (level >= 1):
            print('    {:s}'.format(buf[index:]), end = '')
        if (level >= 2):
            dump_buf(buf, '    ')
        return

    mid      = obj['sirf_hdr']['mid'].val
    sid      = buf[len(obj)]                # if there is a sid, next byte

    v = sirf.mid_table.get(mid, (None, None, None, ''))
    emitters    = v[MID_EMITTERS]           # emitter list
    decoder_obj = v[MID_OBJECT]             # dt object
    mid_name    = v[MID_NAME]

    sid_str = '' if mid not in mids_w_sids else '/{}'.format(sid)
    print(' -- MID: {:3}{:4} ({:02x}) <{:2}> {}'.format(
        mid, sid_str, mid, dir_str, mid_name), end = '')        # sans nl

    if not emitters or len(emitters) == 0:
        print()
        if (level >= 5):
            print('*** no emitters defined for mid {}'.format(mid))
        return
    for e in emitters:
        e(level, offset, buf[len(obj):], decoder_obj)


def emit_tagnet(level, offset, buf, obj):
    xlen     = obj['len'].val
    xtype    = obj['type'].val
    recnum   = obj['recnum'].val
    rtctime  = obj['rt']
    brt      = rtctime_str(rtctime)

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,         # sans nl
                      dt_name(xtype)), end = '')
    print()
