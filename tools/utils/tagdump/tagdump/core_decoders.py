#
# Copyright (c) 2017-2018 Eric B. Decker, Daniel J. Maltbie
# All rights reserved.
#
# basic decoders for main data blocks

import globals      as     g
from   core_records import *
from   core_headers import *

# common format used by all records.  (rec0)
# --- offset recnum  systime  len  type  name
# --- 999999 999999 99999999  999    99  ssssss
# ---    512      1      322  116     1  REBOOT  unset -> GOLD (GOLD)
rec0  = '--- @{:<6d} {:6d} {:8d}  {:3d}    {:2d}  {:s}'


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
# ---    512      1      322  116     1  REBOOT  NIB -> GOLD (GOLD)  (n)

rbt0  = '  {:s} -> {:s}  [{:s}]  ({:d})'

rbt1a = '    REBOOT: {:7s}  f: {:4s}  c: {:4s}  m: {:4s}  boots: {}   chk_fails: {}'
rbt1b = '    dt: 2017/12/26-01:52:40 (1) GMT  prev_sync: {} (0x{:04x})  rev:  0x{:04x}'

rbt2a = '    majik:  {:08x}  sigs:   {:08x} {:08x} {:08x}'
rbt2b = '    base: f {:08x}  cur:    {:08x}'
rbt2c = '    rpt:    {:08x}  reset:  {:08x}   others:  {:08x}'
rbt2d = '    reboots:    {:4}  strg:   {:8}   loc:         {:4}'
rbt2e = '    uptime: {:8} (0x{:08x})        elapsed: {:8} (0x{:08x})'
rbt2f = '    rbt_reason:   {:2}  ow_req: {:2}  mode: {:2}  act:  {:2}'
rbt2g = '    vec_chk_fail: {:2}  image_chk_fail:   {:2}'

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
        print('*** version mismatch, expected 0x{:04x}, got 0x{:04x}'.format(
            DT_H_REVISION, dt_rev))

    consumed     = owcb_obj.set(buf[consumed:])
    from_base    = owcb_obj['from_base'].val
    reboot_count = owcb_obj['reboot_count'].val
    boot_mode    = owcb_obj['ow_boot_mode'].val

    chk_fails = owcb_obj['vec_chk_fail'].val + owcb_obj['image_chk_fail'].val
    if (chk_fails):                     # do we have any flash or image chk fails
        print('*** chk fails: vec_fails: {}, image_fails: {}'.format(
            owcb_obj['vec_chk_fail'].val, owcb_obj['image_chk_fail'].val))

    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),
    print(rbt0.format(base_name(from_base), base_name(base),
                      ow_boot_mode_name(boot_mode), reboot_count))

    if (level >= 1):                   # basic record display (level 1)
        print(rbt1a.format(
            reboot_reason_name(owcb_obj['reboot_reason'].val),
            base_name(from_base), base_name(base),
            ow_boot_mode_name(owcb_obj['ow_boot_mode'].val),
            reboot_count, chk_fails))
        print(rbt1b.format(obj['prev'].val, obj['prev'].val, dt_rev))

    if (level >= 2):                    # detailed display (level 2)
        print
        print(rbt2a.format(majik, owcb_obj['ow_sig'].val,
                   owcb_obj['ow_sig_b'].val, owcb_obj['ow_sig_c'].val))
        print(rbt2b.format(from_base, base))
        print(rbt2c.format(owcb_obj['rpt'].val, owcb_obj['reset_status'].val,
              owcb_obj['reset_others'].val))
        print(rbt2d.format(reboot_count,
                           owcb_obj['strange'].val,
                           owcb_obj['strange_loc'].val))
        print(rbt2e.format(owcb_obj['uptime'].val, owcb_obj['uptime'].val,
                           owcb_obj['elapsed'].val, owcb_obj['elapsed'].val))
        print(rbt2f.format(owcb_obj['reboot_reason'].val,
                           owcb_obj['ow_req'].val,
                           owcb_obj['ow_boot_mode'].val,
                           owcb_obj['owt_action'].val))
        print(rbt2g.format(owcb_obj['vec_chk_fail'].val,
                           owcb_obj['image_chk_fail'].val))

g.dt_records[DT_REBOOT] = (116, decode_reboot, dt_reboot_obj, "REBOOT")


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

ver1a = '    VERSION: {:10s}  hw model/rev: {:x}/{:x} ({:s}/{:d})  r/i: 0x{:x}/{:x}'
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

g.dt_records[DT_VERSION] = (168, decode_version, dt_version_obj, "VERSION")


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

g.dt_records[DT_SYNC] = (40, decode_sync, dt_sync_obj, "SYNC")


################################################################
#
# EVENT decoder
#

def event_name(event):
    return event_names.get(event, 'unk')

event0  = ' {:s}  {}  {}'
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

    print(event0.format(event_name(event), arg0, arg1))
    if (level >= 1):
        print(event1.format(event_name(event), event,
                            arg0, arg1, arg2, arg3,
                            arg0, arg1, arg2, arg3))

g.dt_records[DT_EVENT] = (40, decode_event, dt_event_obj, "EVENT")


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

g.dt_records[DT_DEBUG] = (0, decode_debug, dt_debug_obj, "DEBUG")


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

g.dt_records[DT_TEST] = (0, decode_test, dt_test_obj, "TEST")


################################################################
#
# NOTE decoder
#

note0  = ' xxxx'

def decode_note(level, offset, buf, obj):
    consumed = obj.set(buf)
    len      = obj['hdr']['len'].val
    type     = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val

    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),
    print(note0.format())

g.dt_records[DT_NOTE] = (0, decode_note, dt_note_obj, "NOTE")


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

g.dt_records[DT_CONFIG] = (0, decode_config, dt_config_obj, "CONFIG")
