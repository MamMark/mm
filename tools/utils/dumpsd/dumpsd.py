#!/usr/bin/python

import os
import sys
import binascii
import struct
import argparse
from collections import OrderedDict


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

LOGICAL_SECTOR_SIZE = 512
LOGICAL_BLOCK_SIZE  = 508  # excludes trailer


class atom(object):
    '''
    takes 2-tuple: ('struct_string', 'default_print_format')

    set will set the instance.attribute "val" to the value
    of the atom's decode of the buffer.
    '''
    def __init__(self, a_tuple):
        self.s_str = a_tuple[0]
        self.s_rec = struct.Struct(self.s_str)
        self.p_str = a_tuple[1]

    def __len__(self):
        return self.s_rec.size

    def __repr__(self):
        return self.p_str.format(self.val)

    def set(self, buf):
        '''
        set the atom.val to the unpack from the format string.

        return the number of bytes (size) consumed
        '''
        self.val = self.s_rec.unpack(buf[:self.s_rec.size])[0]
        return self.s_rec.size


class aggie(OrderedDict):
    '''
    aggie: aggregation node.
    takes one parameter a dictionary of key -> {atom | aggie}
    '''
    def __init__(self, a_dict):
        super(aggie, self).__init__(a_dict)

    def __len__(self):
        l = 0
        for key, v_obj in self.iteritems():
            if isinstance(v_obj, atom) or isinstance(v_obj, aggie):
                l += v_obj.__len__()
        return l

    def __repr__(self):
        s = ''
        for key, v_obj in self.iteritems():
            if len(s) != 0:
                s += ', '
            if isinstance(v_obj, atom):
                s += key + ': ' + v_obj.__repr__()
            elif isinstance(v_obj, aggie):
                s += '[' + key + ': ' + v_obj.__repr__() + ']'
            else:
                s += "oops"
        return s

    def set(self, buf):
        '''
        '''
        consumed = 0
        for key, v_obj in self.iteritems():
            consumed += v_obj.set(buf[consumed:])
        return consumed


# hdr object at native, little endian
hdr_obj = aggie(OrderedDict([
    ('len',  atom(('H', '{}'))),
    ('type', atom(('H', '{}'))),
    ('xt',   atom(('I', '0x{:04x}')))]))

def print_hdr(obj):
    rtype = obj['hdr']['type'].val
    print('{:08x} ({:2}) {:6} -- '.format(
        obj['hdr']['xt'].val,
        rtype, dt_records[rtype][2])),


# all dt parts are native and little endian
#
# TINTRYALF (0)) is not a data type but a special case that
# kicks us to the next sector.  This Is Not The Record You Are Looking For

dt_simple_hdr   = aggie(OrderedDict([('hdr', hdr_obj)]))

dt_reboot_obj   = aggie(OrderedDict([('hdr',    hdr_obj),
                                     ('cycle',  atom(('I', '{:08x}'))),
                                     ('majik',  atom(('I', '{:08x}'))),
                                     ('dt_rev', atom(('I', '{:08x}')))]))

dt_version_obj  = aggie(OrderedDict([('hdr',    hdr_obj),
                                     ('base',   atom(('I', '{:08x}')))]))

dt_sync_obj     = aggie(OrderedDict([('hdr',    hdr_obj),
                                     ('cycle',  atom(('I', '{:08x}'))),
                                     ('majik',  atom(('I', '{:08x}')))]))

dt_panic_obj    = aggie(OrderedDict([('hdr',    hdr_obj),
                                     ('arg0',   atom(('I', '0x{:04x}'))),
                                     ('arg1',   atom(('I', '0x{:04x}'))),
                                     ('arg2',   atom(('I', '0x{:04x}'))),
                                     ('arg3',   atom(('I', '0x{:04x}'))),
                                     ('pcode',  atom(('B', '0x{:02x}'))),
                                     ('where',  atom(('B', '0x{:02x}'))),
                                     ('pad',    atom(('BB', '{}'     )))]))


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
    10: "GPS_FAST",
    11: "GPS_FIRST",
    12: "GPS_SATS_2",
    13: "GPS_SATS_7",
    14: "GPS_SATS_29",
    15: "GPS_CYCLE_TIME",
    16: "GPS_GEO",
    17: "GPS_XYZ",
    18: "GPS_TIME",
    19: "GPS_RX_ERR",
    20: "SSW_DELAY_TIME",
    21: "SSW_BLK_TIME",
    22: "SSW_GRP_TIME",
}

dt_event_obj    = aggie(OrderedDict([
    ('hdr',   hdr_obj),
    ('arg0',  atom(('I', '0x{:04x}'))),
    ('arg1',  atom(('I', '0x{:04x}'))),
    ('arg2',  atom(('I', '0x{:04x}'))),
    ('arg3',  atom(('I', '0x{:04x}'))),
    ('event', atom(('H', '{}'))),
    ('pad',   atom(('BB','{}')))]))

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

gps_swver_obj   = aggie(OrderedDict([('str0_len', atom(('B', '{}'))),
                                     ('str1_len', atom(('B', '{}')))]))
def gps_swver_decoder(buf, obj):
    consumed = obj.set(buf)
    len0 = obj['str0_len'].val
    len1 = obj['str1_len'].val
    str0 = buf[consumed:consumed+len0-1]
    str1 = buf[consumed+len0:consumed+len0+len1-1]
    print('\n  --<{}>--  --<{}>--'.format(str0, str1)),


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
#  mid   decoder, object,  name
     2: (gps_nav_decoder,   gps_nav_obj,   "NAV_DATA"),
     4: (None, None, "nav_track"),
     6: (gps_swver_decoder, gps_swver_obj, "SW_VER"),
     7: (None, None, "CLK_STAT"),
     9: (None, None, "cpu thruput"),
    11: (None, None, "ACK"),
    18: (gps_ots_decoder,   gps_ots_obj,   "OkToSend"),
    41: (gps_geo_decoder,   gps_geo_obj,   "GEO_DATA"),
    51: (None, None, "unk_51"),
    56: (None, None, "ext_ephemeris"),
    65: (None, None, "gpio"),
    71: (None, None, "hw_config_req"),
    88: (None, None, "unk_88"),
    92: (None, None, "cw_data"),
    93: (None, None, "TCXO learning"),
}

# gps piece, big endian
gps_hdr_obj     = aggie(OrderedDict([('start',   atom(('>H', '0x{:04x}'))),
                                     ('len',     atom(('>H', '0x{:04x}'))),
                                     ('mid',     atom(('B', '0x{:02x}')))]))

# dt, native, little endian
dt_gps_raw_obj  = aggie(OrderedDict([('hdr',     hdr_obj),
                                     ('mark',    atom(('>I', '0x{:04x}'))),
                                     ('chip',    atom(('B', '0x{:02x}'))),
                                     ('pad',     atom(('BBB', '{}'))),
                                     ('gps_hdr', gps_hdr_obj)]))


def decode_reboot(buf, obj):
    obj.set(buf)
    print(obj)
    print_hdr(obj)
    print

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

def decode_panic(buf, obj):
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
    if mid in mid_table: mid_name = mid_table[mid][2]
    else:                mid_name = "unk"
    print('MID: {:2} ({:02x}) {:10}'.format(mid, mid, mid_name)),

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
    if mid in mid_table and mid_table[mid][0]:
        mid_table[mid][0](buf[consumed:], mid_table[mid][1])
    print


# dt_records
#
# dictionary of all data_typed records we understand
# dict key is the record id.
#

dt_count = {}

dt_records = {
# dt decoder obj name
     0: (decode_tintryalf,      dt_tintryalf_obj,  "TINTRYALF"),
     1: (decode_reboot,         dt_reboot_obj,     "REBOOT"),
     2: (decode_version,        dt_version_obj,    "VERSION"),
     3: (decode_sync,           dt_sync_obj,       "SYNC"),
     4: (decode_panic,          dt_panic_obj,      "PANIC"),
     5: (decode_flush,          dt_flush_obj,      "FLUSH"),
     6: (decode_event,          dt_event_obj,      "EVENT"),
     7: (decode_debug,          dt_debug_obj,      "DEBUG"),
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


# gen_data_bytes generates data bytes from file (stripped of non-data bytes).
#
# Uses generator.send() to pass number of bytes to be read
# the number of bytes to read is returned by the yield, while
# the buffer read is returned by the yield
#
# The buffer will be as large as requested, which may require additional
# sectors to be read. Any remaining data in the sector will be used
# in the next yield request.
#
def gen_data_bytes(fd):
    # skip first block
    blk = fd.read(LOGICAL_SECTOR_SIZE)
    if not blk:
        return
    blk_struct = struct.Struct("508sHH")
    offset = 0
    old_seq_no = 0
    buf = bytearray()
    while (True):
        num = yield offset, buf
        buf = bytearray() # clear the return buffer each time
        if (num < 0):
            offset = 0  # force a skip to next sector
        else:
            while (num > 0):
                if (offset == 0):
                    sect = fd.read(LOGICAL_SECTOR_SIZE)
                    if not sect:
                        break
                    blk, seq_no, chk_sum = blk_struct.unpack(sect)
                    # check sequence number for discontinuity
                    if (seq_no) and (seq_no != (old_seq_no + 1)):
                        print(old_seq_no, seq_no)
                        break
                    old_seq_no = seq_no
                limit = num if (num < (LOGICAL_BLOCK_SIZE - offset)) \
                            else LOGICAL_BLOCK_SIZE - offset
                buf.extend(blk[offset:offset+limit])
                offset = offset + limit \
                         if ((offset + limit) < LOGICAL_BLOCK_SIZE) \
                            else 0
                num -= limit


# generate complete typed data records one at a time
#
# yields one record each time (len, type, data)
#
def gen_records(fd):

    # short hdr is the record_len and dtype.  Doesn't include the timestamp
    # TINTRYALF (0) is not technically a dtype but rather a special case
    # that is only 4 bytes long.  That way it always fits.

    short_hdr = struct.Struct("HH")
    data_bytes = gen_data_bytes(fd)
    data_bytes.send(None)               # prime the generator
    while (True):
        # read size bytes
        hdr_offset, hdr = data_bytes.send(short_hdr.size)
        if (not hdr) or (len(hdr) < short_hdr.size):
            break
        rlen, rtyp = dt_hdr.unpack(hdr)
        if (rtyp == 0): # tinytryalf
            data_bytes.send(-1)   # skip to next sector
            continue
        # return record header fields plus record contents
        offset, pl = data_bytes.send(rlen - LOGICAL_HEADER_SIZE)
        pl = hdr + pl
        yield rlen, rtyp, offset, pl
        if (rlen % 4):
            data_bytes.send(4 - (rlen % 4))  # skip to next word boundary


# main processing loop
#
# look for records and print out details for each one found
#
def dump(args):
    total = 0
    with open(args.input, 'rb') as infile:
        for hdr_offset, rlen, rtype, buf in gen_records(infile):
            print("@{} ({}): type: {}, len: {}".format(
                hdr_offset, hex(hdr_offset), rtype, rlen))
            dump_buf(buf)
            try:
                dt_count[rtype] += 1
            except KeyError:
                dt_count[rtype] = 1
            if (rtype in dt_records):
                decode = dt_records[rtype][0]
                obj    = dt_records[rtype][1]
                decode(buf, obj)
            else:
                print('unknown (0x{:02x})'.format(rtype))
            total += rlen
            print('----')

        print(infile.tell(),  total)
        print
        print('mids: ', mid_count)
        print('dts:  ', dt_count)


if __name__ == "__main__":
    # filename = input('Please enter source file name: ')
    filename = 'data.log'
    parser = argparse.ArgumentParser(
        description='Pretty print content of Tag Data logfile')
    parser.add_argument('input',
                        help='output file')
    parser.add_argument('--version',
                        action='version',
                        version='%(prog)s 0.0.0')
    parser.add_argument('-o', '--output',
                        type=argparse.FileType('w'),
                        help='this is an option')
    parser.add_argument("--rtypes",
                        type=str,
                        help="output records matching types in list")
    parser.add_argument("--start",
                        type=int,
                        help="include records with time greater than start")
    parser.add_argument("--end",
                        type=int,
                        help="include records with time before the end")
    parser.add_argument('-v', '--verbosity',
                        action='count',
                        default=0,
                        help="increase output verbosity")
    args = parser.parse_args()
    if args.rtypes:
        print(args.rtypes)
        for rtype_str in args.rtypes.split(' '):
            print(rtype_str)
            for dt_n, dt_val in dt_records.iteritems():
                print(dt_val)
                if (dt_val[2] == rtype_str):
                    print(rtype_str)
    dump(args)
#    print(args)
