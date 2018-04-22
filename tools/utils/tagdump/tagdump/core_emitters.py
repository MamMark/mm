'''emitters (default) for core data type records'''

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

# basic emitters for main data blocks

__version__ = '0.2.7 (ce)'

from   dt_defs      import *
from   dt_defs      import rec0
from   dt_defs      import get_systime
from   dt_defs      import dt_name
from   dt_defs      import print_hdr
from   dt_defs      import print_record

from   core_headers import owcb_obj
from   core_headers import image_info_obj
from   core_headers import event_names
from   core_headers import gps_cmd_names
from   core_headers import PANIC_WARN
from   core_headers import GPS_CMD

from   sirf_defs    import *
import sirf_defs    as     sirf

from   sirf_headers  import mids_w_sids
from   sirf_headers  import sirf_hdr_obj

from   misc_utils    import dump_buf

################################################################
#
# REBOOT emitter, dt_reboot_obj, owcb_obj
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

rbt0  = '  {:s} -> {:s}  [{:s}]  ({:d}/{:d})'

rbt1a = '    REBOOT: {:7s}  f: {:5s}  c: {:5s}  m: {:5s}  reboots: {}/{}   chk_fails: {}'
rbt1b = '    dt: 2017/12/26-(mon)-01:52:40 GMT  prev_sync: {} (0x{:04x})  rev: {:7d}'

rbt2a = '    majik:   {:08x}  sigs:    {:08x}    {:08x}  {:08x}'
rbt2b = '    base:  f {:08x}  cur:     {:08x}'
rbt2c = '    rpt:     {:08x}  reset:   {:08x}      others: {:08x}'
rbt2d = '    fault/g: {:08x}  fault/n: {:08x}  ss/disable: {:08x}'
rbt2e = '    reboots: {:4}  fails: {:4}  strg: {:8}  loc: {:4}'
rbt2f = '    uptime: {:8}  elapsed: {:8}'
rbt2g = '    rbt_reason:   {:2}  ow_req: {:2}  mode: {:2}  act:  {:2}'
rbt2h = '    vec_chk_fail: {:2}  image_chk_fail:   {:2}'

def emit_reboot(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    st       = get_systime(rtctime)

    majik    = obj['majik'].val
    prev     = obj['prev_sync'].val
    dt_rev   = obj['dt_rev'].val
    base     = obj['base'].val
    if dt_rev != DT_H_REVISION:
        print('*** version mismatch, expected {:d}, got {:d}'.format(
            DT_H_REVISION, dt_rev))

    from_base    = owcb_obj['from_base'].val
    reboot_count = owcb_obj['reboot_count'].val
    fail_count   = owcb_obj['fail_count'].val
    boot_mode    = owcb_obj['ow_boot_mode'].val
    fault_gold   = owcb_obj['fault_gold'].val
    fault_nib    = owcb_obj['fault_nib'].val
    ss_dis       = owcb_obj['subsys_disable'].val
    chk_fails    = owcb_obj['vec_chk_fail'].val + \
                   owcb_obj['image_chk_fail'].val

    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype))),
    print(rbt0.format(base_name(from_base), base_name(base),
                      ow_boot_mode_name(boot_mode), reboot_count, fail_count))

    if (chk_fails):                     # do we have any flash or image chk fails
        print('*** chk fails: vec_fails: {}, image_fails: {}'.format(
            owcb_obj['vec_chk_fail'].val, owcb_obj['image_chk_fail'].val))
    if (fault_gold or fault_nib or ss_dis):
        print('*** fault/g: {:08x}  fault/n: {:08x}  ss_dis: {:08x}'.format(
            fault_gold, fault_nib, ss_dis))

    if (level >= 1):                   # basic record display (level 1)
        print(rbt1a.format(
            reboot_reason_name(owcb_obj['reboot_reason'].val),
            base_name(from_base), base_name(base),
            ow_boot_mode_name(owcb_obj['ow_boot_mode'].val),
            reboot_count, fail_count, chk_fails))
        print(rbt1b.format(prev, prev, dt_rev))

    if (level >= 2):                    # detailed display (level 2)
        print
        print(rbt2a.format(majik, owcb_obj['ow_sig'].val,
                   owcb_obj['ow_sig_b'].val, owcb_obj['ow_sig_c'].val))
        print(rbt2b.format(from_base, base))
        print(rbt2c.format(owcb_obj['rpt'].val, owcb_obj['reset_status'].val,
              owcb_obj['reset_others'].val))
        print(rbt2d.format(fault_gold, fault_nib, ss_dis))
        print(rbt2e.format(reboot_count, fail_count,
                           owcb_obj['strange'].val,
                           owcb_obj['strange_loc'].val))
        print(rbt2f.format(owcb_obj['uptime'].val,
                           owcb_obj['elapsed'].val))
        print(rbt2g.format(owcb_obj['reboot_reason'].val,
                           owcb_obj['ow_req'].val,
                           owcb_obj['ow_boot_mode'].val,
                           owcb_obj['owt_action'].val))
        print(rbt2h.format(owcb_obj['vec_chk_fail'].val,
                           owcb_obj['image_chk_fail'].val))


################################################################
#
# VERSION emitter, dt_version_obj, image_info_obj
#

# version emitter support

model_strs = {
    0x01:       'mm6a',
    0xf0:       'dev6a',
}


def model_name(model):
    return model_strs.get(model, 'unk')


# --- offset recnum  systime  len  type  name
# --- 999999 999999 99999999  999    99  ssssss
# ---    512      1      322  116     1  VERSION  NIB 0.2.63  hw: dev6a/1

ver0  = ' {:s}  {:s}  hw: {:s}/{:d}'

ver1a = '    VERSION: {:10s}  hw model/rev: {:x}/{:x} ({:s}/{:d})  r/i: x({:x}/{:x})'
ver2a = '    desc0:  (p) heads/tp-master-0-g0ac8c73-dirty'
ver2b = '    desc1:  (m) heads/recsum-0-g04de0f8-dirty'
ver2c = '    date:   Fri Dec 29 04:05:07 UTC 2017      ib/len: 0x{:x}/{:d} (0x{:x})'
ver2d = '    ii_sig: 0x33275401  vect_chk: 0x00000000  im_chk: 0x00000000'

def emit_version(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    base     = obj['base'].val

    st       = get_systime(rtctime)

    ver_str = '{:d}.{:d}.{:d}'.format(
        image_info_obj['ver_id']['major'].val,
        image_info_obj['ver_id']['minor'].val,
        image_info_obj['ver_id']['build'].val)
    model = image_info_obj['hw_ver']['model'].val
    rev   = image_info_obj['hw_ver']['rev'].val

    # convert description and build_date strings to something reasonable
    desc0 = image_info_obj['desc0'].val
    desc0 = desc0[:desc0.index("\0")]

    desc1 = image_info_obj['desc1'].val
    desc1 = desc1[:desc1.index("\0")]

    build_date = image_info_obj['build_date'].val
    build_date = build_date[:build_date.index("\0")]

    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype))),
    print(ver0.format(base_name(base), ver_str, model_name(model), rev))
    if (level >= 1):
        print(ver1a.format(ver_str, model, rev, model_name(model), rev,
                           obj['base'].val, image_info_obj['im_start'].val))

    if (level >= 2):
        print
        print(ver2a)
        print(ver2b)
        print(ver2c.format(image_info_obj['im_start'].val,
                       image_info_obj['im_len'].val,
                       image_info_obj['im_len'].val))
        print(ver2d)


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
    st       = get_systime(rtctime)

    majik    = obj['majik'].val
    prev     = obj['prev_sync'].val

    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype))),
    print(sync0.format(prev, prev))

    if (level >= 1):
        print(sync1a.format(majik, prev, prev))
        print(sync1b.format())


################################################################
#
# EVENT emitter
# uses decode_default with dt_event_obj to decode
#

def event_name(event):
    return event_names.get(event, 'unk')

def gps_cmd_name(gps_cmd):
    return gps_cmd_names.get(gps_cmd, 'unk')

event0  = ' {:s} {} {} {} {}'
event1  = '    {:s}: ({}) <{} {} {} {}>  x({:x} {:x} {:x} {:x})'

def emit_event(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    st       = get_systime(rtctime)

    event = obj['event'].val
    arg0  = obj['arg0'].val
    arg1  = obj['arg1'].val
    arg2  = obj['arg2'].val
    arg3  = obj['arg3'].val
    pcode = obj['pcode'].val
    w     = obj['w'].val
    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype))),

    if (event == PANIC_WARN):
        # special case, print PANIC_WARNs always, full display
        print(' {} {}/{}'.format(event_name(event), pcode, w))
        print('    {} {} {} {}  x({:04x} {:04x} {:04x} {:04x})'.format(
            arg0, arg1, arg2, arg3, arg0, arg1, arg2, arg3))
        return

    if (event == GPS_CMD):
        print(' GPS_CMD ({:s}) {} {} {} {}'.format(
            gps_cmd_name(arg0), arg0, arg1, arg2, arg3))
        return

    print(event0.format(event_name(event), arg0, arg1, arg2, arg3))
    if (level >= 1):
        print(event1.format(event_name(event), event,
                            arg0, arg1, arg2, arg3,
                            arg0, arg1, arg2, arg3))


################################################################
#
# DEBUG emitter
# uses decode_default with dt_debug_obj to decode
#

debug0  = ' xxxx'

def emit_debug(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    st       = get_systime(rtctime)

    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype))),
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
    st       = get_systime(rtctime)

    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype)))
    if (level >= 1):
        print('    {}'.format(obj['sirf_swver']))


def emit_gps_time(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        print(obj)
        print_hdr(obj)
        print


def emit_gps_geo(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        print(obj)
        print_hdr(obj)
        print


def emit_gps_xyz(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        print(obj)
        print_hdr(obj)
        print


################################################################
#
# SENSOR/SET decoders
#

def emit_sensor_data(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        print(obj)
        print_hdr(obj)
        print


def emit_sensor_set(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        print(obj)
        print_hdr(obj)
        print


################################################################
#
# TEST decoder
#

test0  = '    xxxx'

def emit_test(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    st       = get_systime(rtctime)

    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype))),
    print(test0.format())


################################################################
#
# NOTE decoder
#

def emit_note(level, offset, buf, obj):
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    st       = get_systime(rtctime)

    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype))),
    print('{}'.format(buf[point:]))


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
    st       = get_systime(rtctime)

    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype))),
    print(cfg0.format())


########################################################################
#
# main gps raw emitter, displays DT_GPS_RAW_SIRFBIN
# dt_gps_raw_obj, 2nd level emit on mid
#

def emit_gps_raw(level, offset, buf, obj):
    xlen     = obj['gps_hdr']['hdr']['len'].val
    xtype    = obj['gps_hdr']['hdr']['type'].val
    recnum   = obj['gps_hdr']['hdr']['recnum'].val
    rtctime  = obj['gps_hdr']['hdr']['rt']
    st       = get_systime(rtctime)

    dir_bit  = obj['gps_hdr']['dir'].val
    dir_str  = 'rx' if dir_bit == 0 else 'tx'

    print(rec0.format(offset, recnum, st, xlen, xtype,
                      dt_name(xtype))),                 # sans nl
    if (obj['sirf_hdr']['start'].val != SIRF_SOP_SEQ):
        index = len(obj) - len(sirf_hdr_obj)
        print('-- non-binary <{:2}>'.format(dir_str))
        if (level >= 1):
            print('    {:s}'.format(buf[index:])),      # sans nl
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
    print('-- MID: {:3}{:4} ({:02x}) <{:2}> {}'.format(
        mid, sid_str, mid, dir_str, mid_name)),         # sans nl

    if not emitters or len(emitters) == 0:
        print
        if (level >= 5):
            print('*** no emitters defined for mid {}'.format(mid))
        return
    for e in emitters:
        e(level, offset, buf[len(obj):], decoder_obj)
