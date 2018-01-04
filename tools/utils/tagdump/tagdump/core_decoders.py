#
# Copyright (c) 2017-2018 Eric B. Decker, Daniel J. Maltbie
# All rights reserved.
#
# basic decoders for main data blocks

import globals      as     g
from   core_records import *
from   core_headers import *

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


rbt1a = '    REBOOT: {:7s}  f: {:4s}  c: {:4s}  m: {:4s}  boots: {}  chk_fails: {}'
rbt1b = '    dt: 2017/12/26-01:52:40 (1) GMT  prev_sync: {} (0x{:04x})  rev: 0x{:04x}'

rbt2a = '    majik:  {:08x}  sigs:   {:08x} {:08x} {:08x}'
rbt2b = '    base: f {:08x}  cur:    {:08x}'
rbt2c = '    rpt:    {:08x}  reset:  {:08x}   others:  {:08x}'
rbt2d = '    reboots:    {:4}  strg:   {:8}   loc:         {:4}'
rbt2e = '    uptime: {:8} (0x{:08x})        elapsed: {:8} (0x{:08x})'
rbt2f = '    rbt_reason:   {:2}  ow_req: {:2}  mode: {:2}  act:  {:2}'
rbt2g = '    vec_chk_fail: {:2}  image_chk_fail:   {:2}'

def decode_reboot(level, buf, obj):
    consumed = obj.set(buf)
    dt_rev = obj['dt_rev'].val
    if dt_rev != DT_H_REVISION:
        print('*** version mismatch, expected 0x{:04x}, got 0x{:04x}'.format(
            DT_H_REVISION, dt_rev))
    consumed = owcb_obj.set(buf[consumed:])
    chk_fails = owcb_obj['vec_chk_fail'].val + owcb_obj['image_chk_fail'].val
    if (chk_fails):                     # do we have any flash or image chk fails
        print('*** chk fails: vec_fails: {}, image_fails: {}'.format(
            owcb_obj['vec_chk_fail'].val, owcb_obj['image_chk_fail'].val))
    if (level >= 1):                   # basic record display (level 1)
        print(rbt1a.format(
            reboot_reason_name(owcb_obj['reboot_reason'].val),
            base_name(owcb_obj['from_base'].val), base_name(obj['base'].val),
            ow_boot_mode_name(owcb_obj['ow_boot_mode'].val),
            owcb_obj['reboot_count'].val, chk_fails))
        print(rbt1b.format(obj['prev'].val, obj['prev'].val, dt_rev))

    if (level >= 2):                    # detailed display (level 2)
        print
        print(rbt2a.format(obj['majik'].val, owcb_obj['ow_sig'].val,
                   owcb_obj['ow_sig_b'].val, owcb_obj['ow_sig_c'].val))
        print(rbt2b.format(owcb_obj['from_base'].val, obj['base'].val))
        print(rbt2c.format(owcb_obj['rpt'].val, owcb_obj['reset_status'].val,
              owcb_obj['reset_others'].val))
        print(rbt2d.format(owcb_obj['reboot_count'].val,
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

def decode_version(level, buf, obj):
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_VERSION] = (168, decode_version, dt_version_obj, "VERSION")


################################################################
#
# SYNC decoder
#

def decode_sync(level, buf, obj):
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_SYNC] = (40, decode_sync, dt_sync_obj, "SYNC")


################################################################
#
# EVENT decoder
#

def decode_event(level, buf, event_obj):
    event_obj.set(buf)
    event = event_obj['event'].val
    if (level >= 1):
        print(event_obj)
        print_hdr(event_obj)
        print('({:2}) {:10} 0x{:04x}  0x{:04x}  0x{:04x}  0x{:04x}'.format(
            event, event_names[event],
            event_obj['arg0'].val,
            event_obj['arg1'].val,
            event_obj['arg2'].val,
            event_obj['arg3'].val))

g.dt_records[DT_EVENT] = (40, decode_event, dt_event_obj, "EVENT")


################################################################
#
# DEBUG decoder
#

def decode_debug(level, buf, obj):
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_DEBUG] = (0, decode_debug, dt_debug_obj, "DEBUG")


################################################################
#
# TEST decoder
#

def decode_test(level, buf, obj):
    pass

g.dt_records[DT_TEST] = (0, decode_test, dt_test_obj, "TEST")


################################################################
#
# NOTE decoder
#

def decode_note(level, buf, obj):
    pass

g.dt_records[DT_NOTE] = (0, decode_note, dt_note_obj, "NOTE")


################################################################
#
# CONFIG decoder
#

def decode_config(level, buf, obj):
    pass

g.dt_records[DT_CONFIG] = (0, decode_config, dt_config_obj, "CONFIG")
