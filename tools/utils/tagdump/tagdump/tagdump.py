#!/usr/bin/env python2
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

import sys
import binascii
import struct
import argparse

from   tagdumpargs  import parseargs
from   decode_base  import *
from   headers_core import *
from   headers_gps  import *

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
#
# DT_H_REVISION is defined in headers_core.py

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
     1: (116, decode_reboot,         dt_reboot_obj,     "REBOOT"),
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


def dump_buf(buf, pre=''):
    bs = buf_str(buf)
    stride = 16         # how many bytes per line

    # 3 chars per byte
    idx = 0
    print(pre + 'rec:  '),
    while(idx < len(bs)):
        max_loc = min(len(bs), idx + (stride * 3))
        print(bs[idx:max_loc])
        idx += (stride * 3)
        if idx < len(bs):              # if more then print counter
            print(pre + '{:04x}: '.format(idx/3)),


def dt_name(rtype):
    v = dt_records.get(rtype, (0, None, None, 'unk'))
    return v[DTR_NAME]


def print_hdr(obj):
    # rec  time     rtype name
    # 0001 00000279 (20) REBOOT

    rtype  = obj['hdr']['type'].val
    recnum = obj['hdr']['recnum'].val
    st     = obj['hdr']['st'].val

    # gratuitous space shows up after the print, sigh
    print('{:04} {:8} ({:2}) {:6} --'.format(recnum, st,
        rtype, dt_records[rtype][DTR_NAME])),


# recnum systime len type name         offset
# 999999 0009999 999   99 xxxxxxxxxxxx @999999 (0xffffff) [0xffff]
rec_title_str = "--- recnum  systime  len  type  name         offset"
rec_format    = "--- {:6}  {:7}  {:3}    {:2}  {:12s} @{:6} (0x{:08x}) [0x{:04x}]"

def print_record(offset, buf):
    if (len(buf) < dt_hdr_size):
        print('*** print_record, buf too small for a header, wanted {}, got {}'.format(
            dt_hdr_size, len(buf)))
    else:
        rlen, rtype, recnum, systime, recsum = dt_hdr_struct.unpack_from(buf)
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
        print('*** resync called with unaligned offset: {0} (0x{0:x})'.format(
            offset))
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
                print('*** failed to resync @ offset {0} (0x{0:x})'.format(
                    fd.tell()))
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
            print('*** aligning offset {0} (0x{0:08x})'.format(offset))
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
        rlen, rtype, recnum, systime, recsum = dt_hdr_struct.unpack(rec_buf)

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
            print('*** checksum failure @ offset {0} (0x{0:x})'.format(
                offset))
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
    verbose = args.verbose if (args.verbose) else 0

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

        count_dt(rtype)
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

    print
    print('*** end of processing @{} (0x{:x}),  processed: {} records, {} bytes'.format(
        infile.tell(), infile.tell(), total_records, total_bytes))
    print('*** reboots: {}, resyncs: {}, chksum_errs: {}, unk_rtypes: {}'.format(
        dt_count.get(DT_REBOOT, 0), num_resyncs, chksum_errors, unk_rtypes))
    print
    print('mid_s: {}'.format(mid_count))
    print('dt_s:  {}'.format(dt_count))


if __name__ == "__main__":
    dump(parseargs())
