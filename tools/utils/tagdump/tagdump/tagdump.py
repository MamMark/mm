#!/usr/bin/python
#
# Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
#
# - Neither the name of the copyright holders nor the names of
#   its contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
#

import os
import sys
import binascii
import struct
import argparse
from   collections import OrderedDict
from   decode_base import *

####
#
# tagdump: dump a MamMark DBLKxxxx data stream.
#
# Parses the data stream and displays in human readable output.
#
# Each record is completely self contained including a checksum
# that is over both the header and data portion of the record.
# (See typed_data.h for details).
#
# see tagdumpargs.py for argument processing.
#
# usage: tagdump.py [-h] [-v] [-V] [-j JUMP]
#                   [--rtypes RTYPES(ints)] [--rnames RNAMES(name[,...])]
#                   [-s START_TIME] [-e END_TIME]
#                   [-r START_REC]  [-l LAST_REC]
#                   input
#
# Args:
#
# optional arguments:
#   -h              show this help message and exit
#   -V              show program's version number and exit
#
#   --rtypes RTYPES output records matching types in list names
#                   comma or space seperated list of rtype ids or NAMES
#     (args.rtypes, list of strings)
#
#   -j JUMP         set input file position
#                   (args.jump, integer)
#
#   -s START_TIME   include records with datetime greater than START_TIME
#   -e END_TIME     (args.{start,end}_time)
#
#   -r START_REC    starting/ending records to dump.
#   -l LAST_REC     (args.{start,last}_rec, integer)
#
#   -v, --verbose   increase output verbosity
#                   (args.verbose)
#
# positional parameters:
#
#   input:          file to process.  (args.input)


# This program needs to understand the format of the DBlk data stream.
# The format of a particular instance is described by typed_data.h.
# The define DT_H_REVISION in typed_data.h indicates which version.
# Matching is a good thing.  We won't abort but will bitch if we mismatch.


DT_H_REVISION           = 0x00000007

#
# global control cells
#
rec_low                 = 0            # inclusive
rec_high                = 0            # inclusive
rec_last                = 0            # last rec num looked at
verbose                 = 0            # how chatty to be


# 1st sector of the first is the directory
DBLK_DIR_SIZE           = 0x200
RLEN_MAX_SIZE           = 1024
RESYNC_HDR_OFFSET       = 24            # how to get back to the start
MAX_ZERO_SIGS           = 1024          # 1024 quads, 4K bytes of zero


# global stat counters
num_resyncs             = 0             # how often we've resync'd
chksum_errors           = 0             # checksum errors seen
unk_rtypes              = 0             # unknown record types
total_records           = 0
total_bytes             = 0

# count by rectype, how many seen of each type
dt_count = {}


def init_globals():
    global rec_low, rec_high, rec_last, verbose
    global num_resyncs, chksum_errors, unk_rtypes
    global total_records, total_bytes, dt_count

    rec_low             = 0
    rec_high            = 0
    rec_last         = 0
    verbose             = 0

    num_resyncs         = 0             # how often we've resync'd
    chksum_errors       = 0             # checksum errors seen
    unk_rtypes          = 0             # unknown record types
    total_records       = 0
    total_bytes         = 0

    dt_count            = {}


# all dt parts are native and little endian

# hdr object dt, native, little endian
# do not include the pad byte.  Each hdr definition handles
# the pad byte differently.

dt_hdr_str    = 'HHIQH'
dt_hdr_struct = struct.Struct(dt_hdr_str)
dt_hdr_size   = dt_hdr_struct.size
dt_sync_majik = 0xdedf00ef
quad_struct   = struct.Struct('I')      # for searching for syncs

DT_REBOOT     = 1
DT_SYNC       = 3

dt_hdr_obj = aggie(OrderedDict([
    ('len',     atom(('H', '{}'))),
    ('type',    atom(('H', '{}'))),
    ('recnum',  atom(('I', '{}'))),
    ('st',      atom(('Q', '0x{:x}'))),
    ('recsum',  atom(('H', '0x{:04x}')))]))

datetime_obj = aggie(OrderedDict([
    ('jiffies', atom(('H', '{}'))),
    ('yr',      atom(('H', '{}'))),
    ('mon',     atom(('B', '{}'))),
    ('day',     atom(('B', '{}'))),
    ('hr',      atom(('B', '{}'))),
    ('min',     atom(('B', '{}'))),
    ('sec',     atom(('B', '{}'))),
    ('dow',     atom(('B', '{}')))]))

def print_hdr(obj):
    # rec  time     rtype name
    # 0001 00000279 (20) REBOOT

    rtype  = obj['hdr']['type'].val
    recnum = obj['hdr']['recnum'].val
    st     = obj['hdr']['st'].val

    # gratuitous space shows up after the print, sigh
    print('{:04} {:8} ({:2}) {:6} --'.format(recnum, st,
        rtype, dt_records[rtype][DTR_NAME]))


dt_simple_hdr   = aggie(OrderedDict([('hdr', dt_hdr_obj)]))

dt_reboot_obj   = aggie(OrderedDict([
    ('hdr',     dt_hdr_obj),
    ('pad0',    atom(('H', '{:04x}'))),
    ('majik',   atom(('I', '{:08x}'))),
    ('prev',    atom(('I', '{:08x}'))),
    ('dt_rev',  atom(('I', '{:08x}'))),
    ('datetime',atom(('10s', '{}', binascii.hexlify)))]))

#
# reboot is followed by the ow_control_block
# We want to decode that as well.  native order, little endian.
# see OverWatch/overwatch.h.
#
owcb_obj        = aggie(OrderedDict([
    ('ow_sig',          atom(('I', '0x{:08x}'))),
    ('rpt',             atom(('I', '0x{:08x}'))),
    ('st',              atom(('Q', '0x{:08x}'))),
    ('reset_status',    atom(('I', '0x{:08x}'))),
    ('reset_others',    atom(('I', '0x{:08x}'))),
    ('from_base',       atom(('I', '0x{:08x}'))),
    ('reboot_count',    atom(('I', '{}'))),
    ('ow_req',          atom(('B', '{}'))),
    ('reboot_reason',   atom(('B', '{}'))),
    ('ow_boot_mode',    atom(('B', '{}'))),
    ('owt_action',      atom(('B', '{}'))),
    ('ow_sig_b',        atom(('I', '0x{:08x}'))),
    ('strange',         atom(('I', '{}'))),
    ('strange_loc',     atom(('I', '0x{:04x}'))),
    ('vec_chk_fail',    atom(('I', '{}'))),
    ('image_chk_fail',  atom(('I', '{}'))),
    ('elapsed',         atom(('Q', '0x{:08x}'))),
    ('ow_sig_c',        atom(('I', '0x{:08x}')))
]))


dt_version_obj  = aggie(OrderedDict([
    ('hdr',       dt_hdr_obj),
    ('pad',       atom(('H', '{:04x}'))),
    ('base',      atom(('I', '{:08x}')))]))


hw_version_obj      = aggie(OrderedDict([
    ('rev',       atom(('B', '{:x}'))),
    ('model',     atom(('B', '{:x}')))]))


image_version_obj   = aggie(OrderedDict([
    ('build',     atom(('H', '{:x}'))),
    ('minor',     atom(('B', '{:x}'))),
    ('major',     atom(('B', '{:x}')))]))


image_info_obj  = aggie(OrderedDict([
    ('sig',       atom(('I', '0x{:08x}'))),
    ('im_start',  atom(('I', '0x{:08x}'))),
    ('im_end',    atom(('I', '0x{:08x}'))),
    ('vect_chk',  atom(('I', '0x{:08x}'))),
    ('im_chk',    atom(('I', '0x{:08x}'))),
    ('ver_id',    image_version_obj),
    ('desc0',     atom(('44s', '0x{:x}'))),
    ('desc1',     atom(('44s', '0x{:x}'))),
    ('build_date',atom(('30s', '0x{:x}'))),
    ('hw_ver',    hw_version_obj)]))


dt_sync_obj     = aggie(OrderedDict([
    ('hdr',       dt_hdr_obj),
    ('pad0',      atom(('H', '{:04x}'))),
    ('majik',     atom(('I', '{:08x}'))),
    ('prev_sync', atom(('I', '{:x}'))),
    ('datetime',  atom(('10s','{}', binascii.hexlify)))]))


# FLUSH: flush remainder of sector due to SysReboot.flush()
dt_flush_obj    = dt_simple_hdr

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
    ('event', atom(('H', '{}'))),
    ('arg0',  atom(('I', '0x{:04x}'))),
    ('arg1',  atom(('I', '0x{:04x}'))),
    ('arg2',  atom(('I', '0x{:04x}'))),
    ('arg3',  atom(('I', '0x{:04x}'))),
    ('pcode', atom(('B', '{}'))),
    ('w',     atom(('B', '{}')))]))

dt_debug_obj    = dt_simple_hdr

dt_gps_ver_obj  = dt_simple_hdr
dt_gps_time_obj = dt_simple_hdr
dt_gps_geo_obj  = dt_simple_hdr
dt_gps_xyz_obj  = dt_simple_hdr

dt_sen_data_obj = dt_simple_hdr
dt_sen_set_obj  = dt_simple_hdr
dt_test_obj     = dt_simple_hdr
dt_note_obj     = dt_simple_hdr
dt_config_obj   = dt_simple_hdr

#
# warning GPS messages are big endian.  The surrounding header (the dt header
# etc) is little endian (native order).
#
gps_nav_obj     = aggie(OrderedDict([
    ('xpos',  atom(('>i', '{}'))),
    ('ypos',  atom(('>i', '{}'))),
    ('zpos',  atom(('>i', '{}'))),
    ('xvel',  atom(('>h', '{}'))),
    ('yvel',  atom(('>h', '{}'))),
    ('zvel',  atom(('>h', '{}'))),
    ('mode1', atom(('B', '0x{:02x}'))),
    ('hdop',  atom(('B', '0x{:02x}'))),
    ('mode2', atom(('B', '0x{:02x}'))),
    ('week10',atom(('>H', '{}'))),
    ('tow',   atom(('>I', '{}'))),
    ('nsats', atom(('B', '{}')))]))

def gps_nav_decoder(buf, obj):
    obj.set(buf)
    print(obj)

gps_navtrk_obj  = aggie(OrderedDict([
    ('week10', atom(('>H', '{}'))),
    ('tow',    atom(('>I', '{}'))),
    ('chans',  atom(('B',  '{}')))]))

gps_navtrk_chan = aggie([('sv_id',    atom(('B',  '{:2}'))),
                         ('sv_az23',  atom(('B',  '{:3}'))),
                         ('sv_el2',   atom(('B',  '{:3}'))),
                         ('state',    atom(('>H', '0x{:04x}'))),
                         ('cno0',     atom(('B',  '{}'))),
                         ('cno1',     atom(('B',  '{}'))),
                         ('cno2',     atom(('B',  '{}'))),
                         ('cno3',     atom(('B',  '{}'))),
                         ('cno4',     atom(('B',  '{}'))),
                         ('cno5',     atom(('B',  '{}'))),
                         ('cno6',     atom(('B',  '{}'))),
                         ('cno7',     atom(('B',  '{}'))),
                         ('cno8',     atom(('B',  '{}'))),
                         ('cno9',     atom(('B',  '{}')))])

def gps_navtrk_decoder(buf,obj):
    consumed = obj.set(buf)
    print(obj)
    chans = obj['chans'].val
    for n in range(chans):
        consumed += gps_navtrk_chan.set(buf[consumed:])
        print(gps_navtrk_chan)

gps_swver_obj   = aggie(OrderedDict([('str0_len', atom(('B', '{}'))),
                                     ('str1_len', atom(('B', '{}')))]))
def gps_swver_decoder(buf, obj):
    consumed = obj.set(buf)
    len0 = obj['str0_len'].val
    len1 = obj['str1_len'].val
    str0 = buf[consumed:consumed+len0-1]
    str1 = buf[consumed+len0:consumed+len0+len1-1]
    print('\n  --<{}>--  --<{}>--'.format(str0, str1)),

gps_vis_obj     = aggie([('vis_sats', atom(('B',  '{}')))])
gps_vis_azel    = aggie([('sv_id',    atom(('B',  '{}'))),
                         ('sv_az',    atom(('>h', '{}'))),
                         ('sv_el',    atom(('>h', '{}')))])

def gps_vis_decoder(buf, obj):
    consumed = obj.set(buf)
    print(obj)
    num_sats = obj['vis_sats'].val
    for n in range(num_sats):
        consumed += gps_vis_azel.set(buf[consumed:])
        print(gps_vis_azel)

# OkToSend
gps_ots_obj = atom(('B', '{}'))

def gps_ots_decoder(buf, obj):
    obj.set(buf)
    ans = 'no'
    if obj.val: ans = 'yes'
    ans = '  ' + ans
    print(ans),

gps_geo_obj     = aggie(OrderedDict([
    ('nav_valid',        atom(('>H', '0x{:04x}'))),
    ('nav_type',         atom(('>H', '0x{:04x}'))),
    ('week_x',           atom(('>H', '{}'))),
    ('tow',              atom(('>I', '{}'))),
    ('utc_year',         atom(('>H', '{}'))),
    ('utc_month',        atom(('B', '{}'))),
    ('utc_day',          atom(('B', '{}'))),
    ('utc_hour',         atom(('B', '{}'))),
    ('utc_min',          atom(('B', '{}'))),
    ('utc_ms',           atom(('>H', '{}'))),
    ('sat_mask',         atom(('>I', '0x{:08x}'))),
    ('lat',              atom(('>i', '{}'))),
    ('lon',              atom(('>i', '{}'))),
    ('alt_elipsoid',     atom(('>i', '{}'))),
    ('alt_msl',          atom(('>i', '{}'))),
    ('map_datum',        atom(('B', '{}'))),
    ('sog',              atom(('>H', '{}'))),
    ('cog',              atom(('>H', '{}'))),
    ('mag_var',          atom(('>H', '{}'))),
    ('climb',            atom(('>h', '{}'))),
    ('heading_rate',     atom(('>h', '{}'))),
    ('ehpe',             atom(('>I', '{}'))),
    ('evpe',             atom(('>I', '{}'))),
    ('ete',              atom(('>I', '{}'))),
    ('ehve',             atom(('>H', '{}'))),
    ('clock_bias',       atom(('>i', '{}'))),
    ('clock_bias_err',   atom(('>i', '{}'))),
    ('clock_drift',      atom(('>i', '{}'))),
    ('clock_drift_err',  atom(('>i', '{}'))),
    ('distance',         atom(('>I', '{}'))),
    ('distance_err',     atom(('>H', '{}'))),
    ('head_err',         atom(('>H', '{}'))),
    ('nsats',            atom(('B', '{}'))),
    ('hdop',             atom(('B', '{}'))),
    ('additional_mode',  atom(('B', '0x{:02x}'))),
]))

def gps_geo_decoder(buf, obj):
    obj.set(buf)
    print(obj)

mid_count = {}

mid_table = {
#  mid    decoder               object          name
     2: ( gps_nav_decoder,      gps_nav_obj,    "NAV_DATA"),
     4: ( gps_navtrk_decoder,   gps_navtrk_obj, "NAV_TRACK"),
     6: ( gps_swver_decoder,    gps_swver_obj,  "SW_VER"),
     7: ( None,                 None,           "CLK_STAT"),
     9: ( None,                 None,           "cpu thruput"),
    11: ( None,                 None,           "ACK"),
    13: ( gps_vis_decoder,      gps_vis_obj,    "VIS_LIST"),
    18: ( gps_ots_decoder,      gps_ots_obj,    "OkToSend"),
    28: ( None,                 None,           "NAV_LIB"),
    41: ( gps_geo_decoder,      gps_geo_obj,    "GEO_DATA"),
    51: ( None,                 None,           "unk_51"),
    56: ( None,                 None,           "ext_ephemeris"),
    65: ( None,                 None,           "gpio"),
    71: ( None,                 None,           "hw_config_req"),
    88: ( None,                 None,           "unk_88"),
    92: ( None,                 None,           "cw_data"),
    93: ( None,                 None,           "TCXO learning"),
}

# gps piece, big endian, follows dt_gps_raw_obj
gps_hdr_obj     = aggie(OrderedDict([('start',   atom(('>H', '0x{:04x}'))),
                                     ('len',     atom(('>H', '0x{:04x}'))),
                                     ('mid',     atom(('B', '0x{:02x}')))]))

# dt, native, little endian
dt_gps_raw_obj  = aggie(OrderedDict([('hdr',     dt_hdr_obj),
                                     ('chip',    atom(('B',  '0x{:02x}'))),
                                     ('dir',     atom(('B',  '{}'))),
                                     ('mark',    atom(('>I', '0x{:04x}'))),
                                     ('gps_hdr', gps_hdr_obj)]))


rbt0 = '  rpt:           0x{:08x}, st:        0x{:08x}'
rbt1 = '  reset_status:  0x{:08x}, reset_others: 0x{:08x}, from_base: 0x{:08x}'
rbt2 = '  reboot_count: {:2}, ow_req: {:3}, reboot_reason: {}, ow_boot_mode: {}, owt_action: {}'
rbt3 = '  strange:     {:3}, loc: 0x{:04x}, vec_chk_fail: {}, image_chk_fail: {}'
rbt4 = '  elapsed:       0x{:08x}'

def decode_reboot(buf, obj):
    consumed = obj.set(buf)
    dt_rev = obj['dt_rev'].val
    print(obj)
    print_hdr(obj)
    consumed = owcb_obj.set(buf[consumed:])
    print('ow_sig: 0x{:08x}, ow_sig_b: 0x{:08x}, ow_sig_c: {:08x}'.format(
        owcb_obj['ow_sig'].val,
        owcb_obj['ow_sig_b'].val,
        owcb_obj['ow_sig_c'].val))
    print(rbt0.format(owcb_obj['rpt'].val, owcb_obj['st'].val))
    print(rbt1.format(owcb_obj['reset_status'].val,  owcb_obj['reset_others'].val,
                      owcb_obj['from_base'].val))
    print(rbt2.format(owcb_obj['reboot_count'].val,  owcb_obj['ow_req'].val,
                      owcb_obj['reboot_reason'].val, owcb_obj['ow_boot_mode'].val,
                      owcb_obj['owt_action'].val))
    print(rbt3.format(owcb_obj['strange'].val,       owcb_obj['strange_loc'].val,
                      owcb_obj['vec_chk_fail'].val,  owcb_obj['image_chk_fail'].val))
    print(rbt4.format(owcb_obj['elapsed'].val))

    if dt_rev != DT_H_REVISION:
        print('*** version mismatch, expected 0x{:08x}, got 0x{:08x}'.format(
            DT_H_REVISION, dt_rev))

def decode_version(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

def decode_sync(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

def decode_flush(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

def decode_event(buf, event_obj):
    event_obj.set(buf)
    print(event_obj)
    print_hdr(event_obj)
    event = event_obj['event'].val
    print('({:2}) {:10} 0x{:04x}  0x{:04x}  0x{:04x}  0x{:04x}'.format(
        event, event_names[event],
        event_obj['arg0'].val,
        event_obj['arg1'].val,
        event_obj['arg2'].val,
        event_obj['arg3'].val))

def decode_debug(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

def decode_gps_version(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

def decode_gps_time(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

def decode_gps_geo(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

def decode_gps_xyz(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

def decode_sensor_data(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

def decode_sensor_set(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

def decode_test(buf, obj):
    pass

def decode_note(buf, obj):
    pass

def decode_config(buf, obj):
    pass

def print_gps_hdr(obj, mid):
    dir = obj['dir'].val
    dir_str = 'rx' if dir == 0 \
         else 'tx'
    if mid in mid_table: mid_name = mid_table[mid][2]
    else:                mid_name = "unk"
    print('MID: {:2} ({:02x}) <{:2}> {:10} '.format(mid, mid, dir_str, mid_name)),

def decode_gps_raw(buf, obj):
    consumed = obj.set(buf)
    print(obj)
    print_hdr(obj)
    mid = obj['gps_hdr']['mid'].val
    try:
        mid_count[mid] += 1
    except KeyError:
        mid_count[mid] = 1
    print_gps_hdr(obj, mid)
    if mid in mid_table:
        decoder    = mid_table[mid][0]
        decode_obj = mid_table[mid][1]
        if decoder:
            decoder(buf[consumed:], decode_obj)
    print
    pass                                # BRK


# dt_records
#
# dictionary of all data_typed records we understand
# dict key is the record id.
#

# key is rtype
# vector has (required_len, decoder, object descriptor, and name)
#   required len will be 0 if it is variable or not checked.

DTR_REQ_LEN = 0                         # required length
DTR_DECODER = 1                         # decode said rtype
DTR_OBJ     = 2                         # rtype obj descriptor
DTR_NAME    = 3                         # rtype name

dt_records = {
#   dt   len  decoder                obj                 name
     1: (112, decode_reboot,         dt_reboot_obj,     "REBOOT"),
     2: (168, decode_version,        dt_version_obj,    "VERSION"),
     3: ( 40, decode_sync,           dt_sync_obj,       "SYNC"),
     4: ( 40, decode_event,          dt_event_obj,      "EVENT"),
     5: (  0, decode_debug,          dt_debug_obj,      "DEBUG"),
    16: (  0, decode_gps_version,    dt_gps_ver_obj,    "GPS_VERSION"),
    17: (  0, decode_gps_time,       dt_gps_time_obj,   "GPS_TIME"),
    18: (  0, decode_gps_geo,        dt_gps_geo_obj,    "GPS_GEO"),
    19: (  0, decode_gps_xyz,        dt_gps_xyz_obj,    "GPS_XYZ"),
    20: (  0, decode_sensor_data,    dt_sen_data_obj,   "SENSOR_DATA"),
    21: (  0, decode_sensor_set,     dt_sen_set_obj,    "SENSOR_SET"),
    22: (  0, decode_test,           dt_test_obj,       "TEST"),
    23: (  0, decode_note,           dt_note_obj,       "NOTE"),
    24: (  0, decode_config,         dt_config_obj,     "CONFIG"),
    32: (  0, decode_gps_raw,        dt_gps_raw_obj,    "GPS_RAW"),
  }


def buf_str(buf):
    """
    Convert buffer into its display bytes
    """
    i    = 0
    p_ds = ''
    p_s  = binascii.hexlify(buf)
    while (i < (len(p_s))):
        p_ds += p_s[i:i+2] + ' '
        i += 2
    return p_ds


def dump_buf(buf):
    bs = buf_str(buf)
    stride = 16         # how many bytes per line

    # 3 chars per byte
    idx = 0
    print('rec:  '),
    while(idx < len(bs)):
        max_loc = min(len(bs), idx + (stride * 3))
        print(bs[idx:max_loc])
        idx += (stride * 3)
        if idx < len(bs):              # if more then print counter
            print('{:04x}: '.format(idx/3)),


def dt_name(rtype):
    v = dt_records.get(rtype, (0, None, None, 'unk'))
    return v[DTR_NAME]


# recnum systime len type name         offset
# 999999 0009999 999   99 xxxxxxxxxxxx @999999 (0xffffff) [0xffff]
rec_title_str = "--- recnum  systime  len  type  name         offset"
rec_format    = "--- {:6}  {:7}  {:3}    {:2}  {:12s} @{:6} (0x{:08x}) [0x{:04x}]"

def print_record(offset, buf):
    if (len(buf) < dt_hdr_size):
        print('*** print_record, buf too small for a header, wanted {}, got {}'.format(
            dt_hdr_size, len(buf)))
    else:
        rlen, rtype, recnum, systime, recsum = dt_hdr_struct.unpack(buf[:dt_hdr_size])
        print(rec_format.format(recnum, systime, rlen, rtype,
            dt_name(rtype), offset, offset, recsum))
    if (verbose > 1):
        dump_buf(buf)


#
# resync the data stream to the next SYNC/REBOOT record
#
# we search for the SYNC_MAJIK and then back up an appropriate
# amount (RESYNC_HDR_OFFSET).  We check for reasonable length
# and reasonable rtype (SYNC or REBOOT).
#
# Once we think we have a good SYNC/REBOOT, we leave the file
# position at the start of the SYNC/REBOOT.  And let other
# checks needed be performed by gen_records.
#
# returns -1 if something went wrong
#         offset of next record if not.
#
def resync(fd, offset):
    global num_resyncs

    if (offset & 3 != 0):
        print('*** resync called with unaligned offset: {}'.format(offset))
        offset = (offset / 4) * 4
    fd.seek(offset)
    num_resyncs += 1
    zero_sigs = 0
    while (True):
        while (True):
            try:
                sig = quad_struct.unpack(fd.read(quad_struct.size))[0]
                if sig == dt_sync_majik:
                    break
            except struct.error:
                print('*** failed to resync @ offset {}'.format(fd.tell()))
                return -1
            except IOError:
                print('*** file io error')
                return -1
            except EOFError:
                print('*** end of file')
                return -1
            except:
                print('*** exception error: {}'.format(sys.exc_info()[0]))
                raise
            offset += quad_struct.size
            if (sig == 0):
                zero_sigs += 1
                if (zero_sigs > MAX_ZERO_SIGS):
                    print('*** resync: too many zeros, bailing')
                    return -1
            else:
                zero_sigs = 0
        fd.seek(-RESYNC_HDR_OFFSET, 1)          # back up to start of attempt
        offset_try = fd.tell()
        buf = bytearray(fd.read(dt_hdr_size))
        if (len(buf) < dt_hdr_size):            # oht oh, too small, very strange
            print('*** resync: read of dt_hdr too small')
            return -1

        # we want rlen and rtype, we leave recsum checking for gen_records
        rlen, rtype, recnum, systime, recsum = dt_hdr_struct.unpack(buf)
        if ((rtype == DT_SYNC   and rlen == dt_records[DT_SYNC]  [DTR_REQ_LEN]) or
            (rtype == DT_REBOOT and rlen == dt_records[DT_REBOOT][DTR_REQ_LEN])):
            fd.seek(offset_try)
            return offset_try

        # not what we expected.  continue looking for SYNC_MAJIKs where we left off
        fd.seek(offset_try + RESYNC_HDR_OFFSET)


def get_record(fd):
    """
    Generate valid typed-data records one at a time until no more bytes
    to read from the input file.

    Yields one record each time (len, type, recnum, systime, recsum, rec_buf).

    Input:   fd:         file descriptor we are reading from
    Output:  rec_offset: byte offset of the record from start of file
             rlen:       record length
             rtype:      record type
             recnum      record number
             systime     time since last reboot
             recsum      checksum ovr header and data
             rec_buf:    byte buffer with entire record
    """

    global chksum_errors

    # output variables
    offset      = -1
    rlen        = 0
    rtype       = 0
    recnum      = 0
    systime     = 0
    recsum      = 0
    rec_buf     = bytearray()

    last_offset = 0                     # protects against infinite resync

    while (True):
        offset = fd.tell()
        # new records are required to start on a quad boundary
        if (offset & 3):
            print('*** aligning offset {} ({:08x})'.format(offset, offset))
            offset = ((offset/4) + 1) * 4
            fd.seek(offset)
        if (offset == last_offset):
            #
            # offset/last_offset being equal says we are doing a resync
            # and we ended back at the same record.
            #
            # advance our current position to just beyond the last sync we
            # tried.  Find the next one.
            #
            offset += RESYNC_HDR_OFFSET
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue
        last_offset = offset
        rec_buf = bytearray(fd.read(dt_hdr_size))
        if (len(rec_buf) < dt_hdr_size):
            print('*** record header read too short: wanted {}, got {}'.format(
                dt_hdr_size, len(rec_buf)))
            break                       # oops
        rlen, rtype, recnum, systime, recsum = \
                dt_hdr_struct.unpack(rec_buf)

        if (recnum == 0):               # zero is never allowed
            print('*** zero record number - resyncing')
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue

        if (rlen > RLEN_MAX_SIZE):
            print('*** record size too large: {}'.format(rlen))
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue

        # now see if we have any data payload
        # if dlen is negative, that says we are below min header size
        dlen = rlen - dt_hdr_size
        if (dlen < 0):                  # major oops, rlen is screwy
            print('*** record header too short: wanted {}, got {}'.format(
                dt_hdr_size, rlen))
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue

        if (dlen > 0):
            rec_buf.extend(bytearray(fd.read(dlen)))

        if (len(rec_buf) < rlen):
            print('*** record read too short: wanted {}, got {}'.format(
                rlen, len(rec_buf)))
            break                       # oops, bail

        # verify checksum.
        # sum the entire record and then remove the bytes from recsum.
        # recsum was computed with the field being 0 and then layed down
        # so we need to remove it before comparing.
        chksum = sum(rec_buf)
        chksum -= (recsum & 0xff00) >> 8
        chksum -= (recsum & 0x00ff)
        if (chksum != recsum):
            chksum_errors += 1
            print('*** checksum failure @ offset {}'.format(offset))
            print_record(offset, rec_buf)
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue                    # try again
        try:
            required_len = dt_records[rtype][DTR_REQ_LEN]
            if (required_len):
                if (required_len != rlen):
                    offset = resync(fd, offset)
                    if (offset < 0):
                        break
                    continue            # try again
        except KeyError:
            pass

        # life is good.  return actual record.
        return offset, rlen, rtype, recnum, systime, recsum, rec_buf

    # oops.  things blew up.  just return -1 for the offset
    return -1, 0, 0, 0, 0, 0, ''


def process_dir(fd):
    fd.seek(DBLK_DIR_SIZE)


def dump(args):
    """
    Reads records and prints out details

    A dt-specific decoder is selected for each type of record which
    determines the output

    The input 'args' contains a list of the user input parameters that
    determine which records to print, including: start, end, type

    Summary information is output after all records have been processed,
    including: number of records output, counts for each record type,
    and dt-specific decoder summary
    """

    global rec_low, rec_high, rec_last, verbose
    global num_resyncs, chksum_errors, unk_rtypes
    global total_records, total_bytes, unk_rtypes

    init_globals()

    def count_dt(rtype):
        """
        increment counter in dict of rtypes, create new entry if needed
        also check for existence of dt_records entry.  If not known
        count it as unknown.
        """
        try:
            dt_records[rtype]
        except KeyError:
            unk_rtypes += 1

        try:
            dt_count[rtype] += 1
        except KeyError:
            dt_count[rtype] = 1


    infile = args.input
    verbose = args.verbose if (args.verbose) else 1

    if (args.start_rec):
        rec_low  = args.start_rec
    if (args.last_rec):
        rec_high = args.last_rec

    # convert any args.rtypes to upper case

    # process the directory, this will leave us pointing at the first header
    process_dir(infile)

    if (args.jump):
        infile.seek(args.jump)

    print(rec_title_str)

    # extract record from input file and output decoded results
    while(True):
        rec_offset, rlen, rtype, recnum, systime, recsum, rec_buf = \
                get_record(infile)
        if (rec_offset < 0):
            break;

        if (recnum < rec_last):
            print('*** recnum went backwards.  last: {}, new: {}'.format(
                rec_last, recnum))
        if (rec_last and recnum > rec_last + 1):
            print('*** record gap: ({}) records'.format(recnum - rec_last))
        rec_last = recnum

        # apply any filters (inclusion)
        if (args.rtypes):
            # either the number rtype must be in the search list
            # or the name of the rtype must be in the search list
            if ((str(rtype)       not in args.rtypes) and
                  (dt_name(rtype) not in args.rtypes)):
                continue                   # not an rtype of interest

        # look to see if record number bounds
        if (rec_low and recnum < rec_low):
            continue
        if (rec_high and recnum > rec_high):
            break                       # all done

        print_record(rec_offset, rec_buf)
        decode = dt_records[rtype][DTR_DECODER]  # dt function
        obj    = dt_records[rtype][DTR_OBJ]      # dt object
        try:
            decode(rec_buf, obj)
        except struct.error:
            print('*** decode error: (len: {}, rtype: {} {})'.format(
                rlen, rtype, dt_name(rtype)))
        total_records += 1
        total_bytes   += rlen
        count_dt(rtype)

    print
    print('*** end of processing @{},  processed: {} records, {} bytes'.format(
        infile.tell(), total_records, total_bytes))
    print('*** reboots: {}, resyncs: {}, chksum_errs: {}, unk_rtypes: {}'.format(
        dt_count.get(DT_REBOOT, 0), num_resyncs, chksum_errors, unk_rtypes))
    print
    print('mid_s: {}'.format(mid_count))
    print('dt_s:  {}'.format(dt_count))


if __name__ == "__main__":
    pass
