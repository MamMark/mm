# Copyright (c) 2017-2018 Eric B. Decker, Daniel J. Maltbie
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
# Contact: Daniel J. Maltbie <dmaltbie@daloma.org>
#          Eric B. Decker <cire831@gmail.com>

# basic decoders for main data blocks

from   core_headers import *

from   dt_defs      import *
import dt_defs      as     dtd
from   dt_defs      import rec0
from   dt_defs      import dt_name

from   sirf_defs    import *
import sirf_defs    as     sirf

from   gps_decoders import swver_str
from   gps_headers  import mids_w_sids
from   misc_utils   import dump_buf

__version__ = '0.1.1 (cd)'

################################################################
#
# REBOOT decoder
#

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

def decode_reboot(level, offset, buf, obj):
    consumed = obj.set(buf)
    len      = obj['hdr']['len'].val
    type     = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val

    majik    = obj['majik'].val
    prev     = obj['prev'].val
    dt_rev   = obj['dt_rev'].val
    base     = obj['base'].val
    if dt_rev != DT_H_REVISION:
        print('*** version mismatch, expected {:d}, got {:d}'.format(
            DT_H_REVISION, dt_rev))

    consumed     = owcb_obj.set(buf[consumed:])
    from_base    = owcb_obj['from_base'].val
    reboot_count = owcb_obj['reboot_count'].val
    fail_count   = owcb_obj['fail_count'].val
    boot_mode    = owcb_obj['ow_boot_mode'].val
    fault_gold   = owcb_obj['fault_gold'].val
    fault_nib    = owcb_obj['fault_nib'].val
    ss_dis       = owcb_obj['subsys_disable'].val
    chk_fails    = owcb_obj['vec_chk_fail'].val + \
                   owcb_obj['image_chk_fail'].val

    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),
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
        print(rbt1b.format(obj['prev'].val, obj['prev'].val, dt_rev))

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

#                            128 = sizeof(reboot record) + sizeof(owcb)
dtd.dt_records[DT_REBOOT] = (128, decode_reboot, dt_reboot_obj, "REBOOT")


################################################################
#
# VERSION decoder
#

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

def decode_version(level, offset, buf, obj):
    consumed = obj.set(buf)             # decode version header
    len      = obj['hdr']['len'].val
    type     = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val
    base     = obj['base'].val

    consumed = image_info_obj.set(buf[consumed:])
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

    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),
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

dtd.dt_records[DT_VERSION] = (168, decode_version, dt_version_obj, "VERSION")


################################################################
#
# SYNC decoder
#

sync0  = '  prev: @{:d} (0x{:x})'

sync1a = '    SYNC: majik:  0x{:x}   prev: {} (0x{:x})'
sync1b = '          dt: 2017/12/26-01:52:40 (1) GMT'

def decode_sync(level, offset, buf, obj):
    consumed = obj.set(buf)
    len      = obj['hdr']['len'].val
    type     = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val

    majik    = obj['majik'].val
    prev     = obj['prev_sync'].val

    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),
    print(sync0.format(prev, prev))

    if (level >= 1):
        print(sync1a.format(majik, prev, prev))
        print(sync1b.format())

dtd.dt_records[DT_SYNC] = (36, decode_sync, dt_sync_obj, "SYNC")


################################################################
#
# EVENT decoder
#

def event_name(event):
    return event_names.get(event, 'unk')

def gps_cmd_name(gps_cmd):
    return gps_cmd_names.get(gps_cmd, 'unk')

event0  = ' {:s} {} {} {} {}'
event1  = '    {:s}: ({}) <{} {} {} {}>  x({:x} {:x} {:x} {:x})'

def decode_event(level, offset, buf, obj):
    consumed = obj.set(buf)
    len      = obj['hdr']['len'].val
    type     = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val

    event = obj['event'].val
    arg0  = obj['arg0'].val
    arg1  = obj['arg1'].val
    arg2  = obj['arg2'].val
    arg3  = obj['arg3'].val
    pcode = obj['pcode'].val
    w     = obj['w'].val
    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),

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

dtd.dt_records[DT_EVENT] = (40, decode_event, dt_event_obj, "EVENT")


################################################################
#
# DEBUG decoder
#

debug0  = ' xxxx'

def decode_debug(level, offset, buf, obj):
    consumed = obj.set(buf)
    len      = obj['hdr']['len'].val
    type     = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val

    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),
    print(debug0.format())

dtd.dt_records[DT_DEBUG] = (0, decode_debug, dt_debug_obj, "DEBUG")


def decode_gps_version(level, offset, buf, obj):
    consumed = obj.set(buf)
    xlen     = obj['hdr']['len'].val
    xtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val
    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype)))
    if (level >= 1):
        print('    {}'.format(swver_str(buf[consumed:])))


dtd.dt_records[DT_GPS_VERSION] = \
        (0, decode_gps_version, dt_gps_hdr_obj, "GPS_VERSION")


def decode_gps_time(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

dtd.dt_records[DT_GPS_TIME] = \
        (0, decode_gps_time, dt_gps_time_obj, "GPS_TIME")


def decode_gps_geo(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

dtd.dt_records[DT_GPS_GEO] = \
        (0, decode_gps_geo, dt_gps_geo_obj, "GPS_GEO")


def decode_gps_xyz(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

dtd.dt_records[DT_GPS_XYZ] = \
        (0, decode_gps_xyz, dt_gps_xyz_obj, "GPS_XYZ")


################################################################
#
# TEST decoder
#

test0  = ' xxxx'

def decode_test(level, offset, buf, obj):
    consumed = obj.set(buf)
    len      = obj['hdr']['len'].val
    type     = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val

    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),
    print(test0.format())

dtd.dt_records[DT_TEST] = (0, decode_test, dt_test_obj, "TEST")


################################################################
#
# NOTE decoder
#

def decode_note(level, offset, buf, obj):
    consumed = obj.set(buf)
    len      = obj['hdr']['len'].val
    type     = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val

    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),
    print('{}'.format(buf[consumed:]))

dtd.dt_records[DT_NOTE] = (0, decode_note, dt_note_obj, "NOTE")


################################################################
#
# CONFIG decoder
#

cfg0  = ' xxxx'

def decode_config(level, offset, buf, obj):
    consumed = obj.set(buf)
    len      = obj['hdr']['len'].val
    type     = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val

    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),
    print(cfg0.format())

dtd.dt_records[DT_CONFIG] = (0, decode_config, dt_config_obj, "CONFIG")


########################################################################
#
# main gps raw decoder, decodes DT_GPS_RAW_SIRFBIN
#

def decode_gps_raw(level, offset, buf, obj):
    consumed = obj.set(buf)
    xlen     = obj['gps_hdr']['hdr']['len'].val
    xtype    = obj['gps_hdr']['hdr']['type'].val
    recnum   = obj['gps_hdr']['hdr']['recnum'].val
    st       = obj['gps_hdr']['hdr']['st'].val

    mid = obj['raw_gps_hdr']['mid'].val
    sid = buf[consumed]                 # if there is a sid, next byte
    try:
        sirf.mid_count[mid] += 1
    except KeyError:
        sirf.mid_count[mid] = 1

    v = sirf.mid_table.get(mid, (None, None, ''))
    decoder     = v[MID_DECODER]            # dt function
    decoder_obj = v[MID_OBJECT]             # dt object

    print(rec0.format(offset, recnum, st, xlen, xtype, dt_name(xtype))),
    dir_bit = obj['gps_hdr']['dir'].val
    dir_str = 'rx' if dir_bit == 0 \
         else 'tx'
    v = sirf.mid_table.get(mid, (None, None, 'unk'))
    mid_name = v[MID_NAME]

    if (obj['raw_gps_hdr']['start'].val != 0xa0a2):
        index = len(obj) - len(raw_gps_hdr_obj)
        print('-- non-binary <{:2}>'.format(dir_str))
        if (level >= 1):
            print('    {:s}'.format(buf[index:])),
        if (level >= 2):
            dump_buf(buf, '    ')
        return

    sid_str = '' if mid not in mids_w_sids else '/{}'.format(sid)
    print('-- MID: {:2}{} ({:02x}) <{:2}> {}'.format(
        mid, sid_str, mid, dir_str, mid_name)),

    if not decoder:
        print
        if (level >= 5):
            print('*** no decoder/obj defined for mid {}'.format(mid))
        return
    decoder(level, offset, buf[consumed:], decoder_obj)

dtd.dt_records[DT_GPS_RAW_SIRFBIN] = \
        (0, decode_gps_raw, dt_gps_raw_obj, "GPS_RAW")
