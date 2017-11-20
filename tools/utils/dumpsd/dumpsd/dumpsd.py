#!/usr/bin/python

import os
import sys
import binascii
import struct
import argparse
from collections import OrderedDict

from decode_base import *

import chunks

####
#
# This program reads an input source file and parses out the
# typed data records.
#
# Certain constraints on input are applied
# - input consists of a multiple of 512 bytes (the sector size).
# - each sector is further defined to contain a logical blk
#   trailer of 4 bytes along with up to 508 bytes of record data.
#   (uint16_t sequence_no, uint16_t checksum)
#   The logical trailer bytes are stripped.
# - a record can be as large as 64k bytes (2**16)
#   each record has a standard header of length and d_type (4 bytes)
#   followed by record-specific data
# - records
#

#
# This program needs to understand the format of the DBlk data stream.
# The format of a particular instance is described by typed_data.h.
# The define DT_H_REVISION in typed_data.h indicates which version.
# Matching is a good thing.  We won't abort but will bitch if we mismatch.

DT_H_REVISION       = 0x00000005

LOGICAL_SECTOR_SIZE = 512
LOGICAL_BLOCK_SIZE  = 508       # excludes trailer

# all dt parts are native and little endian

# hdr object at native, little endian
hdr_obj = aggie(OrderedDict([
    ('len',  atom(('H', '{}'))),
    ('type', atom(('H', '{}'))),
    ('st',   atom(('Q', '0x{:08x}')))]))


def print_hdr(obj):
    rtype = obj['hdr']['type'].val
    # gratuitous space shows up after the print, sigh
    print('{:08x} ({:2}) {:6} --'.format(
        obj['hdr']['st'].val,
        rtype, dt_records[rtype][2])),


dt_simple_hdr   = aggie(OrderedDict([('hdr', hdr_obj)]))

dt_reboot_obj   = aggie(OrderedDict([('hdr',    hdr_obj),
                                     ('majik',  atom(('I', '{:08x}'))),
                                     ('dt_rev', atom(('I', '{:08x}')))]))

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


dt_version_obj  = aggie(OrderedDict([('hdr',    hdr_obj),
                                     ('base',   atom(('I', '{:08x}')))]))



dt_sync_obj     = aggie(OrderedDict([('hdr',    hdr_obj),
                                     ('majik',  atom(('I', '{:08x}')))]))


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
    ('hdr',   hdr_obj),
    ('event', atom(('H', '{}'))),
    ('ss',    atom(('B', '{}'))),
    ('w',     atom(('B', '{}'))),
    ('arg0',  atom(('I', '0x{:04x}'))),
    ('arg1',  atom(('I', '0x{:04x}'))),
    ('arg2',  atom(('I', '0x{:04x}'))),
    ('arg3',  atom(('I', '0x{:04x}')))]))

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
dt_gps_raw_obj  = aggie(OrderedDict([('hdr',     hdr_obj),
                                     ('mark',    atom(('>I', '0x{:04x}'))),
                                     ('chip',    atom(('B',  '0x{:02x}'))),
                                     ('dir',     atom(('B',  '{}'))),
                                     ('pad',     atom(('BB', '{}'))),
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

dt_total = 0
dt_count = {}

dt_records = {
#   dt   decoder                obj                 name
     1: (decode_reboot,         dt_reboot_obj,     "REBOOT"),
     2: (decode_version,        dt_version_obj,    "VERSION"),
     3: (decode_sync,           dt_sync_obj,       "SYNC"),
     4: (decode_flush,          dt_flush_obj,      "FLUSH"),
     5: (decode_event,          dt_event_obj,      "EVENT"),
     6: (decode_debug,          dt_debug_obj,      "DEBUG"),
    16: (decode_gps_version,    dt_gps_ver_obj,    "GPS_VERSION"),
    17: (decode_gps_time,       dt_gps_time_obj,   "GPS_TIME"),
    18: (decode_gps_geo,        dt_gps_geo_obj,    "GPS_GEO"),
    19: (decode_gps_xyz,        dt_gps_xyz_obj,    "GPS_XYZ"),
    20: (decode_sensor_data,    dt_sen_data_obj,   "SENSOR_DATA"),
    21: (decode_sensor_set,     dt_sen_set_obj,    "SENSOR_SET"),
    22: (decode_test,           dt_test_obj,       "TEST"),
    23: (decode_note,           dt_note_obj,       "NOTE"),
    24: (decode_config,         dt_config_obj,     "CONFIG"),
    32: (decode_gps_raw,        dt_gps_raw_obj,    "GPS_RAW"),
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
    print('buf:  '),
    while(idx < len(bs)):
        max_loc = min(len(bs), idx + (stride * 3))
        print(bs[idx:max_loc])
        idx += (stride * 3)
        if idx < len(bs):              # if more then print counter
            print('{:04x}: '.format(idx/3)),


def gen_data_bytes(fd):
    """
    gen_data_bytes generates data bytes from file (stripped of non-data bytes).

    Uses generator.send() to pass number of bytes to be read
        the number of bytes to read is to the yield, while
        the buffer read is returned by the yield

    The buffer will be as large as requested, which may require additional
    sectors to be read. Any remaining data in the sector will be used
    in the next yield operation.

    sect: space for holding a full LOGICAL_SECTOR
        blk:  we split sect apart into 508 bytes (blk), seq_no, and chk_sum
        buf:  is the marshalling buffer where we collect all the data
              that has been asked for.

    file_offset, buf = data_bytes.send(req_len)

    input:  num is how many bytes to read from file
    output: file_offset: file position of first byte read from file
                    buf: buffer of bytes read from file

    offset can have one of three values:
        n   file position of first byte in buf
        0   bad read, try again
       -1   end of file, nothing more to read
    """
    # define logical block structure (always read full block)
    blk_str     = str(LOGICAL_BLOCK_SIZE) + 'sHH'
    blk_struct  = struct.Struct(blk_str)

    # variables to keep track of input block state between yields
    blk         = None
    index       = LOGICAL_SECTOR_SIZE

    # output variables
    buf         = bytearray()
    file_offset = 0

    while (True):
        num = yield file_offset, buf    # yield

        # starting byte is file_offset, and one sector has been read
        file_offset = 0
        buf = bytearray()               # clear the return buffer each time
        while (num > 0):
            offset, chunk = chunks.get_chunk(fd, num)
            if (offset == 0):
                continue                # bad chunk, try again
            if (offset == -1):
                file_offset = -1        # end of file
                break
            if (file_offset == 0):      # first chunk, set start of
                file_offset = offset
            buf.extend(chunk)
            num -= len(chunk)


def gen_records(fd):
    """
    Generate valid typed-data records one at a time until no more bytes
    to read from the input file.

    Yields one record each time (len, type, data)

    Every record starts with a short hdr, consisting of the record length
    and dtype.  Doesn't include the timestamp.

    TINTRYALF (0) "This Is Not The Record You Are Looking For"
    Not a data type but a special case that kicks us to the next sector.

    TINTRYALF is only 4 bytes long (len, dtype, no timestamp) and as such
    will ALWAYS fit in any space that is left in the sector buffer.
    """
    short_hdr = struct.Struct("HH")
    data_bytes = gen_data_bytes(fd)
    data_bytes.send(None)               # prime the bytes generator

    def get_short_hdr():
        rtype = -1
        rlen = 0
        offset, hdr = data_bytes.send(short_hdr.size)
        if (offset > 0):
            rlen, rtype = short_hdr.unpack(hdr)
        return offset, hdr, rlen, rtype

    def get_body(rlen):
        offset, body = data_bytes.send(rlen - short_hdr.size)
        if (offset > 0):
            if ((short_hdr.size + len(body)) < rlen):
                print('*** oops. rec too short')
                dump_buf(hdr + body[:64])
        return offset, body

    while (True):
        rec_offset = 0
        while (rec_offset == 0):
            rec_offset, hdr, rlen, rtype = get_short_hdr()
            if (rec_offset == -1):           # EOF
                break
            if (rec_offset == 0):            # bad read
                chunks.resync(fd)
                continue
            if (rtype == 0) and (rlen == 0): # EOF
                rec_offset =  -1
                break
# zzz is the format wrong for tintryalf?
# seeing the fields swapped (rlen <> rtype)
            if (rtype == 0) or (rlen == 0):  # tintryalf
                chunks.next_sector_pos(fd)
                rec_offset = 0
                continue
            try:
                dt_records[rtype]            # see if type is known
            except:
                chunks.resync(fd)
                rec_offset = 0
                continue
            offset, body = get_body(rlen)
            if (offset == -1):               # EOF
                rec_offset = -1
                break
            if (offset == 0):                # bad read
                chunks.resync(fd)
                rec_offset = 0
                continue

        # zzz additional per record checking here

        if (rec_offset == -1):                # EOF
            break
        # return header fields plus record contents
        yield rec_offset, rlen, rtype, hdr + body    # yield
        if (fd.tell()%4):
            chunks.next_word_pos(fd)       # skip any padding


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
    def count_dt(rtype):
        """
        increment counter in dict of rtypes, create new entry if needed
        """
        global dt_total
        dt_total += 1
        try:
            dt_count[rtype] += 1
        except KeyError:
            dt_count[rtype] = 1

    def print_record_details(vb):
        if (vb >= 1):
            print("@{} ({}): type: {}, len: {}".format(
                hdr_offset, hex(hdr_offset), rtype, rlen))
        if (vb >=2):
            dump_buf(buf)

    def dt_by_index(name):
        for k,v in dt_records.iteritems():
            if (k == name):
                return v[2]
        return ""

    total_bytes_processed = 0
    infile = args.input
    verbosity = args.verbosity if (args.verbosity) else 1

    # skip first block, it's the directory block (reserved)
    if (args.jump):
        infile.seek(args.jump)
        chunks.resync(infile)
    else:
        chunks.next_sector_pos(infile)
    # extract record from input file and output decoded results
    for hdr_offset, rlen, rtype, buf in gen_records(infile):
        if (args.last_sector) \
           and (hdr_offset/LOGICAL_SECTOR_SIZE >= args.last_sector):
            break                      # past last sector of interest
        if (args.first_sector) \
           and (hdr_offset/LOGICAL_SECTOR_SIZE < args.first_sector):
            continue                   # before 1st sector of interest
        if (args.rtypes) \
           and (dt_by_index(rtype) not in args.rtypes):
            continue                   # not an rtype of interest
        print_record_details(verbosity)
        decode = dt_records[rtype][0]  # dt function
        obj    = dt_records[rtype][1]  # dt object
        try:
            decode(buf, obj)
        except struct.error:
            if (verbosity > 0):
                print('decode error: (dt: 0x{:x}, len: {})'.format(
                    rtype,
                    rlen))
        total_bytes_processed += rlen
        count_dt(rtype)

    print
    print('end of processing @{}[sector:{}],  processed: {} records, {} bytes'.format(
        infile.tell(),
        infile.tell()/LOGICAL_SECTOR_SIZE,
        dt_total,
        total_bytes_processed))
    print
    print('mids: {}'.format(mid_count))
    print('dts:  {}'.format(dt_count))
    if (verbosity > 2):
        for off, buf in chunks.chunk4b_offsets:
            print('chunk@0x{:x}, len({}): {}'.format(
                off,
                len(buf),
                binascii.hexlify(buf)))


if __name__ == "__main__":
    pass
