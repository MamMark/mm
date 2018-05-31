# Copyright (c) 2018 Eric B. Decker
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

__version__ = '0.3.2.dev5'

from   core_rev     import *
from   dt_defs      import *

from   core_headers import event_name
from   core_headers import PANIC_WARN           # event
from   core_headers import GPS_MON_MINOR        # event
from   core_headers import GPS_MON_MAJOR        # event
from   core_headers import GPS_RX_ERR           # event
from   core_headers import GPS_CMD              # event

from   gps_mon      import *

from   sirf_defs    import *
import sirf_defs    as     sirf

from   sirf_headers import mids_w_sids
from   misc_utils   import dump_buf

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
    return ow_bases.get(base, 'unk')

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
}

def ow_boot_mode_name(mode):
    return ow_boot_mode_strs.get(mode, 'unk')

def ow_req_name(req):
    return ow_req_strs.get(req, 'unk')

def owt_action_name(action):
    return ow_action_strs.get(action, 'unk')

def reboot_reason_name(reason):
    return ow_reboot_reason_strs.get(reason, 'unk')


# --- offset recnum  systime  len  type  name
# --- 999999 999999 99999999  999    99  ssssss
# ---    512      1      322  116     1  REBOOT  NIB -> GOLD (GOLD)  (r/f)

rbt0  = '  {:s} -> {:s}  [{:s}]  (r {:d}/{:d} p)'

rbt1a = '    REBOOT: {:7s}  f: {:5s}  c: {:5s}  m: {:5s}  reboots/p: {}/{}   chk_fails: {}'
rbt1b = '    rt: 2017/12/26-(mon)-01:52:40 GMT  prev_sync: {} (0x{:04x})  rev: {:4d}/{:d}'

rbt2a = '    majik:   {:08x}  sigs:    {:08x}    {:08x}  {:08x}'
rbt2b = '    base:  f {:08x}  cur:     {:08x}'
rbt2c = '    rpt:     {:08x}  reset:   {:08x}      others: {:08x}'
rbt2d = '    fault/g: {:08x}  fault/n: {:08x}  ss/disable: {:08x}'
rbt2e = '    reboots: {:4}  panics: {:4}  strg: {:8}  loc: {:4}'
rbt2f = '    uptime: {}  boot: {}  prev: {}'
rbt2g = '    rbt_reason:   {:2}  ow_req: {:2}  mode: {:2}  act:  {:2}'

# obj is obj_dt_reboot (includes an obj_owcb record)
def emit_reboot(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    brt      = rtctime_str(rtctime)

    majik    = obj['majik'].val
    prev     = obj['prev_sync'].val
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
    boot_mode    = owcb['ow_boot_mode'].val
    reboot_count = owcb['reboot_count'].val
    chk_fails    = owcb['chk_fails'].val

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')
    print(rbt0.format(base_name(from_base), base_name(base),
                      ow_boot_mode_name(boot_mode), reboot_count, panic_count))

    # any weird failures?  Always report
    if (chk_fails or fault_gold or fault_nib or ss_dis):
        print('*** chkfails: {}  fault/g: {:08x}  fault/n: {:08x}  ss_dis: {:08x}'.format(
            chk_fails, fault_gold, fault_nib, ss_dis))

    if (level >= 1):                   # basic record display (level 1)
        print(rbt1a.format(
            reboot_reason_name(owcb['reboot_reason'].val),
            base_name(from_base), base_name(base),
            ow_boot_mode_name(owcb['ow_boot_mode'].val),
            reboot_count, panic_count, chk_fails))
        print(rbt1b.format(prev, prev, core_rev, core_minor))

    if (level >= 2):                    # detailed display (level 2)
        print()
        print(rbt2a.format(majik, owcb['ow_sig'].val,
                   owcb['ow_sig_b'].val, owcb['ow_sig_c'].val))
        print(rbt2b.format(from_base, base))
        print(rbt2c.format(owcb['rpt'].val, owcb['reset_status'].val,
              owcb['reset_others'].val))
        print(rbt2d.format(fault_gold, fault_nib, ss_dis))
        print(rbt2e.format(reboot_count, panic_count,
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
    return model_strs.get(model, 'unk')


# --- offset recnum      brt  len  type  name
# --- 999999 999999 3599.999  999    99  ssssss
# ---    512      1      322  116     1  VERSION  NIB 0.2.63  hw: dev6a/1

ver0  = ' {:s}  {:s}  hw: {:s}/{:d}'

ver1a = '    VERSION: {:10s}  hw model/rev: {:x}/{:x} ({:s}/{:d})  r/i: x({:x}/{:x})'
ver2a = '    desc:       placeholder'
ver2b = '    repo0:  (p) heads/tp-master-0-g0ac8c73-dirty'
ver2c = '    repo1:  (m) heads/recsum-0-g04de0f8-dirty'
ver2d = '    date:   Fri Dec 29 04:05:07 UTC 2017      ib/len: 0x{:x}/{:d} (0x{:x})'
ver2e = '    ii_sig: 0x33275401  chksum: 0x00000000'

def emit_version(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    base     = obj['base'].val
    ii       = obj['image_info']
    brt      = rtctime_str(rtctime)

    ver_str = '{:d}.{:d}.{:d}'.format(
        ii['ver_id']['major'].val,
        ii['ver_id']['minor'].val,
        ii['ver_id']['build'].val)
    model = ii['hw_ver']['model'].val
    rev   = ii['hw_ver']['rev'].val

    # convert description and build_date strings to something reasonable
    desc  = ii['image_desc'].val
    desc  = desc[:desc.index('\0')]

    repo0 = ii['repo0'].val
    repo0 = repo0[:repo0.index('\0')]

    repo1 = ii['repo1'].val
    repo1 = repo1[:repo1.index('\0')]

    stamp_date = ii['stamp_date'].val
    stamp_date = stamp_date[:stamp_date.index('\0')]

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)), end = '')
    print(ver0.format(base_name(base), ver_str, model_name(model), rev))
    if (level >= 1):
        print(ver1a.format(ver_str, model, rev, model_name(model), rev,
                           obj['base'].val, ii['im_start'].val))

    if (level >= 2):
        print()
        print(ver2a)
        print(ver2b)
        print(ver2c)
        print(ver2d.format(ii['im_start'].val,
                       ii['im_len'].val,
                       ii['im_len'].val))
        print(ver2e)


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

event0  = ' {:s} {} {} {} {}'
event1  = '    {:s}: ({}) <{} {} {} {}>  x({:x} {:x} {:x} {:x})'

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
    if (event == PANIC_WARN):
        # special case, print PANIC_WARNs always, full display
        print(' {} {}/{}'.format(event_name(event), pcode, w))
        print('    {} {} {} {}  x({:04x} {:04x} {:04x} {:04x})'.format(
            arg0, arg1, arg2, arg3, arg0, arg1, arg2, arg3))
        return

    if (event == GPS_MON_MINOR):
        print(' gps/mon (MINOR), {:>10s}  {:>10s} -> {:<10s}'.format(
            '<{}>'.format(gps_mon_event_name(arg2)),
            gps_mon_minor_name(arg0),
            gps_mon_minor_name(arg1)))
        return

    if (event == GPS_MON_MAJOR):
        print(' gps/mon (MAJOR), {:>10s}  {:>10s} -> {:<10s}'.format(
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

    print(event0.format(event_name(event), arg0, arg1, arg2, arg3))
    if (level >= 1):
        print(event1.format(event_name(event), event,
                            arg0, arg1, arg2, arg3,
                            arg0, arg1, arg2, arg3))


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
    dump_hdr(offset, buf)
    if (level >= 1):
        print(obj)
        print_hdr(obj)
        print()


def emit_gps_geo(level, offset, buf, obj):
    dump_hdr(offset, buf)
    if (level >= 1):
        print(obj)
        print_hdr_obj(obj)
        print()


def emit_gps_xyz(level, offset, buf, obj):
    dump_hdr(offset, buf)
    if (level >= 1):
        print(obj)
        print_hdr_obj(obj)
        print()


################################################################
#
# SENSOR/SET decoders
#

def emit_sensor_data(level, offset, buf, obj):
    dump_hdr(offset, buf)
    if (level >= 1):
        print(obj)
        print_hdr_obj(obj)
        print()


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
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    brt      = rtctime_str(rtctime)

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,         # sans nl
                      dt_name(xtype)), end = '')
    print(cfg0.format())


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
