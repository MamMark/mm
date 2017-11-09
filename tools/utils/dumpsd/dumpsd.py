#!/usr/bin/python

import os
import sys
import binascii
import struct

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
LOGICAL_HEADER_SIZE = 4


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


hdr_len  = atom(('H', '{}'))
hdr_type = atom(('H', '{}'))
hdr_xt   = atom(('I', '0x{:04x}'))

hdr_obj    = aggie(OrderedDict([('len', hdr_len), ('type', hdr_type)]))
hdr_xt_obj = aggie(OrderedDict([('len', hdr_len), ('type', hdr_type), ('xt', hdr_xt)]))


def print_hdr_xt(obj):
    rtype = obj['hdr']['type'].val
    print('{:08x} ({:2}) {:6} -- '.format(
        obj['hdr']['xt'].val,
        rtype, dt_records[rtype][2])),


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

event_arg   = atom(('I', '0x{:04x}'))
event_event = atom(('H', '{}'))
event_obj   = aggie(OrderedDict([('hdr', hdr_xt_obj),
                                 ('arg0', event_arg),
                                 ('arg1', event_arg),
                                 ('arg2', event_arg),
                                 ('arg3', event_arg),
                                 ('event', event_event)]))


def decode_tintryalf(buf, obj):
    pass

def decode_reboot(buf, obj):
    pass

def decode_version(buf, obj):
    pass

def decode_sync(buf, obj):
    pass

def decode_panic(buf, obj):
    pass

def decode_flush(buf, obj):
    pass


def decode_event(buf, event_obj):
    print('=============')
    event_obj.set(buf)
    print(event_obj)
    print_hdr_xt(event_obj)
    event = event_obj['event'].val
    print('({:2}) {:20}  {}  {}  {}  {}'.format(
        event, event_names[event],
        event_obj['arg0'].val,
        event_obj['arg1'].val,
        event_obj['arg2'].val,
        event_obj['arg3'].val))
    print('=============')


def decode_debug(buf, obj):
    pass

def decode_gps_version(buf, obj):
    pass

def decode_gps_time(buf, obj):
    pass

def decode_gps_geo(buf, obj):
    pass

def decode_gps_xyz(buf, obj):
    pass

def decode_sensor_data(buf, obj):
    pass

def decode_sensor_set(buf, obj):
    pass

def decode_test(buf, obj):
    pass

def decode_note(buf, obj):
    pass

def decode_config(buf, obj):
    pass

def decode_gps_raw_sirfbin(buf, obj):
    pass


# dt_records
#
# dictionary of all data_typed records we understand
# dict key is the record id.
#
dt_records = {
     0: (decode_tintryalf,          None,           "TINTRYALF"),
     1: (decode_reboot,             None,           "REBOOT"),
     2: (decode_version,            None,           "VERSION"),
     3: (decode_sync,               None,           "SYNC"),
     4: (decode_panic,              None,           "PANIC"),
     5: (decode_flush,              None,           "FLUSH"),
     6: (decode_event,              event_obj,      "EVENT"),
     7: (decode_debug,              None,           "DEBUG"),
    16: (decode_gps_version,        None,           "GPS_VERSION"),
    17: (decode_gps_time,           None,           "GPS_TIME"),
    18: (decode_gps_geo,            None,           "GPS_GEO"),
    19: (decode_gps_xyz,            None,           "GPS_XYZ"),
    20: (decode_sensor_data,        None,           "SENSOR_DATA"),
    21: (decode_sensor_set,         None,           "SENSOR_SET"),
    22: (decode_test,               None,           "TEST"),
    23: (decode_note,               None,           "NOTE"),
    24: (decode_config,             None,           "CONFIG"),
    32: (decode_gps_raw_sirfbin,    None,           "GPS_RAW"),
  }


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
    dt_hdr = struct.Struct("HH")
    data_bytes = gen_data_bytes(fd)
    data_bytes.send(None) # prime the generator
    while (True):
        # read size bytes
        offset, hdr = data_bytes.send(dt_hdr.size)
        if (not hdr) or (len(hdr) < LOGICAL_HEADER_SIZE):
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

def insert_space(st):
    """
    Convert byte array into string and insert space periodically to
    break up long string
    """
    p_ds = ''
    ix = 4
    i = 0
    p_s = binascii.hexlify(st)
    while (i < (len(st) * 2)):
        p_ds += p_s[i:i+ix] + ' '
        i += ix
    return p_ds

# main processing loop
#
# look for records and print out details for each one found
#
def main(source):
    total = 0
    with open(source, 'rb') as fd:
        for rlen, rtype, offset, buf in gen_records(fd):
            print("type:{}, len:{}, next:{}({}), buf:{}".format(
                rtype, rlen, (fd.tell()-512)+offset,
                hex((fd.tell()-512)+offset),
                insert_space(buf)))
            if (rtype in dt_records):
                decode = dt_records[rtype][0]
                obj    = dt_records[rtype][1]
                decode(buf, obj)
            else:
                print('unknown (0x{:02x})'.format(rtype))
            total += rlen
            print('----')

        print(fd.tell(),  total)


if __name__ == "__main__":
    # filename = input('Please enter source file name: ')
    filename = 'data.log'
    main(filename)
