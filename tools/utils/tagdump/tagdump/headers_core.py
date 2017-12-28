#
# Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
# All rights reserved.
#

import binascii
import struct
from   decode_base  import *

DT_H_REVISION           = 0x00000009

# all dt parts are native and little endian

# hdr object dt, native, little endian
# do not include the pad byte.  Each hdr definition handles
# the pad byte differently.

dt_hdr_str    = '<HHIQH'
dt_hdr_struct = struct.Struct(dt_hdr_str)
dt_hdr_size   = dt_hdr_struct.size
dt_sync_majik = 0xdedf00ef
quad_struct   = struct.Struct('<I')      # for searching for syncs

DT_REBOOT     = 1
DT_SYNC       = 3

dt_hdr_obj = aggie(OrderedDict([
    ('len',     atom(('<H', '{}'))),
    ('type',    atom(('<H', '{}'))),
    ('recnum',  atom(('<I', '{}'))),
    ('st',      atom(('<Q', '0x{:x}'))),
    ('recsum',  atom(('<H', '0x{:04x}')))]))

datetime_obj = aggie(OrderedDict([
    ('jiffies', atom(('<H', '{}'))),
    ('yr',      atom(('<H', '{}'))),
    ('mon',     atom(('<B', '{}'))),
    ('day',     atom(('<B', '{}'))),
    ('hr',      atom(('<B', '{}'))),
    ('min',     atom(('<B', '{}'))),
    ('sec',     atom(('<B', '{}'))),
    ('dow',     atom(('<B', '{}')))]))

dt_simple_hdr   = aggie(OrderedDict([('hdr', dt_hdr_obj)]))

dt_reboot_obj   = aggie(OrderedDict([
    ('hdr',     dt_hdr_obj),
    ('pad0',    atom(('<H', '{:04x}'))),
    ('majik',   atom(('<I', '{:08x}'))),
    ('prev',    atom(('<I', '{:08x}'))),
    ('dt_rev',  atom(('<I', '{:08x}'))),
    ('base',    atom(('<I', '{:08x}'))),
    ('datetime',atom(('10s', '{}', binascii.hexlify))),
    ('pad1',    atom(('<H',  '{}')))]))

#
# reboot is followed by the ow_control_block
# We want to decode that as well.  native order, little endian.
# see OverWatch/overwatch.h.
#
owcb_obj        = aggie(OrderedDict([
    ('ow_sig',          atom(('<I', '0x{:08x}'))),
    ('rpt',             atom(('<I', '0x{:08x}'))),
    ('uptime',          atom(('<Q', '0x{:08x}'))),
    ('reset_status',    atom(('<I', '0x{:08x}'))),
    ('reset_others',    atom(('<I', '0x{:08x}'))),
    ('from_base',       atom(('<I', '0x{:08x}'))),
    ('reboot_count',    atom(('<I', '{}'))),
    ('ow_req',          atom(('<B', '{}'))),
    ('reboot_reason',   atom(('<B', '{}'))),
    ('ow_boot_mode',    atom(('<B', '{}'))),
    ('owt_action',      atom(('<B', '{}'))),
    ('ow_sig_b',        atom(('<I', '0x{:08x}'))),
    ('strange',         atom(('<I', '{}'))),
    ('strange_loc',     atom(('<I', '0x{:04x}'))),
    ('vec_chk_fail',    atom(('<I', '{}'))),
    ('image_chk_fail',  atom(('<I', '{}'))),
    ('elapsed',         atom(('<Q', '0x{:08x}'))),
    ('ow_sig_c',        atom(('<I', '0x{:08x}')))
]))


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


dt_version_obj  = aggie(OrderedDict([
    ('hdr',       dt_hdr_obj),
    ('pad',       atom(('<H', '{:04x}'))),
    ('base',      atom(('<I', '{:08x}')))]))


hw_version_obj      = aggie(OrderedDict([
    ('rev',       atom(('<B', '{:x}'))),
    ('model',     atom(('<B', '{:x}')))]))


image_version_obj   = aggie(OrderedDict([
    ('build',     atom(('<H', '{:x}'))),
    ('minor',     atom(('<B', '{:x}'))),
    ('major',     atom(('<B', '{:x}')))]))


image_info_obj  = aggie(OrderedDict([
    ('ii_sig',    atom(('<I', '0x{:08x}'))),
    ('im_start',  atom(('<I', '0x{:08x}'))),
    ('im_len',    atom(('<I', '0x{:08x}'))),
    ('vect_chk',  atom(('<I', '0x{:08x}'))),
    ('im_chk',    atom(('<I', '0x{:08x}'))),
    ('ver_id',    image_version_obj),
    ('desc0',     atom(('44s', '0x{:x}'))),
    ('desc1',     atom(('44s', '0x{:x}'))),
    ('build_date',atom(('30s', '0x{:x}'))),
    ('hw_ver',    hw_version_obj)]))


dt_sync_obj     = aggie(OrderedDict([
    ('hdr',       dt_hdr_obj),
    ('pad0',      atom(('<H', '{:04x}'))),
    ('majik',     atom(('<I', '{:08x}'))),
    ('prev_sync', atom(('<I', '{:x}'))),
    ('datetime',  atom(('10s','{}', binascii.hexlify)))]))


# EVENT

event_names = {
     1: "SURFACED",
     2: "SUBMERGED",
     3: "DOCKED",
     4: "UNDOCKED",
     5: "GPS_BOOT",
     6: "GPS_BOOT_TIME",
     7: "GPS_RECONFIG",
     8: "GPS_START",
     9: "GPS_OFF",
    10: "GPS_STANDBY",
    11: "GPS_FAST",
    12: "GPS_FIRST",
    13: "GPS_SATS_2",
    14: "GPS_SATS_7",
    15: "GPS_SATS_29",
    16: "GPS_CYCLE_TIME",
    17: "GPS_GEO",
    18: "GPS_XYZ",
    19: "GPS_TIME",
    20: "GPS_RX_ERR",
    21: "SSW_DELAY_TIME",
    22: "SSW_BLK_TIME",
    23: "SSW_GRP_TIME",
    24: "PANIC_WARN",
}

dt_event_obj    = aggie(OrderedDict([
    ('hdr',   dt_hdr_obj),
    ('event', atom(('<H', '{}'))),
    ('arg0',  atom(('<I', '0x{:04x}'))),
    ('arg1',  atom(('<I', '0x{:04x}'))),
    ('arg2',  atom(('<I', '0x{:04x}'))),
    ('arg3',  atom(('<I', '0x{:04x}'))),
    ('pcode', atom(('<B', '{}'))),
    ('w',     atom(('<B', '{}')))]))

dt_debug_obj    = dt_simple_hdr
