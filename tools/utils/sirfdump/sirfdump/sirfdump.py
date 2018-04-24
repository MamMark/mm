'''sirfdump: dump a sirfbin file'''
#
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

# Vebosity;
#
#   0   just display basic record, summary (default)
#   1   basic record display - more details
#   2   detailed record display
#   3   dump packet buffer
#   4   details of rehunt (look for new SOP)
#   5   other errors and decoder/header versions

from   __future__               import print_function

import sys
import struct

from   tagdump.sirf_defs        import *
import tagdump.sirf_defs        as     sirf
import tagdump.tagfile          as     tf
from   tagdump.misc_utils       import dump_buf
from   tagdump.sirf_headers     import mids_w_sids

from   sirfdumpargs             import parseargs

# import configuration, which will populate decode/emitter trees.
import sirfdump_config

from   __init__                 import __version__   as VERSION
from   tagdump.decode_base      import __version__   as db_ver
from   tagdump.sirf_defs        import __version__   as sb_ver
from   tagdump.sirf_decoders    import __version__   as sd_ver
from   tagdump.sirf_emitters    import __version__   as se_ver
from   tagdump.sirf_headers     import __version__   as sh_ver

ver_str = '\nsirfdump: ' + VERSION

####
#
# sirfdump: dump sirf binary protocol packets
#
# Parses the input as a sirf binary packet stream and displays in human
# readable output.
#
# usage: sirfdump.py [-h] [-v] [-V] [-j JUMP] [-x EndFilePos]
#                    [-D] [-n num_recs]
#                    input
#
# Args:
#
# optional arguments:
#   -h              show this help message and exit
#   -V              show program's version number and exit
#
#   -D              turn on Debugging information
#                   (args.debug, boolean)
#
#   -j JUMP         set input file position
#                   (args.jump, integer)
#                   -1: goto EOF
#                   negative number, offset from EOF.
#
#   -x endpos       set last file position to process
#                   (args.endpos, integer)
#
#   -n num          limit display to <num> records
#                   (args.num, integer)
#
#   -v, --verbose   increase output verbosity
#                   (args.verbose)
#
#   -w              wide summary
#                   (args.wide)
#
# positional parameters:
#
#   input:          file to process.  (args.input)


#
# global control cells
#
verbose                 = 0             # how chatty to be
debug                   = 0             # extra debug chatty

MAX_ZERO_HDRS           = 4096          # 4K bytes of zero

# global stat counters
num_hunt                = 0             # how often hunting for packet start
chksum_errors           = 0             # checksum errors seen
unk_mids                = 0             # unknown record types
total_records           = 0
total_bytes             = 0

def init_globals():
    global verbose, debug
    global num_hunt, chksum_errors, unk_mids
    global total_records, total_bytes

    verbose             = 0
    debug               = 0

    num_hunt            = 0             # how often we've hunted for start
    chksum_errors       = 0             # checksum errors seen
    unk_mids            = 0             # unknown record types
    total_records       = 0
    total_bytes         = 0


def hunt(fd, offset):
    '''
    hunt for next start of packet

    input:   fd         file descriptor
             offset     where to start the hunt

    returns: offset     where we found the new start
    '''

    global num_hunt

    print('*** hunt started @{0} (0x{0:x})'.format(offset))
    fd.seek(offset)
    num_hunt += 1
    zero_hdrs = 0
    accum     = 0
    while (True):
        offset = fd.tell()
        try:
            byte   = fd.read(1)          # get next byte
            accum  = (accum & 0xff) << 8 | ord(byte)
            if accum == 0xa0a2:
                break
        except IOError:
            print('*** hunt: file io error @{}'.format(offset))
            return -1
        except EOFError:
            print('*** hunt: end of file @{}'.format(offset))
            return -1
        except:
            print('*** hunt: exception error: {} @{}'.format(
                sys.exc_info()[0], offset))
            raise
        if (accum == 0):
            zero_hdrs += 1
            if (zero_hdrs > MAX_ZERO_HDRS):
                print('*** hunt: too many zeros ({}), bailing, @{}'.format(
                    MAX_ZERO_HDRS, offset))
                return -1
        else:
            zero_hdrs = 0
    fd.seek(-2, 1)                  # back up to beginning of start of packet
    offset = fd.tell()
    if (verbose >= 4):
        print('*** hunt: found SOP @{0} (0x{0:x})'.format(offset))
    return offset



def get_record(fd):
    """get next sirfbin record

    generate next valid sirfbin record, one at a time until no
    more bytes to read from input.

    Yields one record each time (offset, rlen, mid, rec_buf).

    Input:   fd:         file descriptor we are reading from
    Output:  rec_offset: byte offset of the record from start of file
             rlen:       record length
             mid:        type of packet
             rec_buf:    byte buffer with entire record
    """

    global chksum_errors

    # output variables
    offset      = 0
    last_offset = -1
    rlen        = 0
    mid         = 0
    rec_buf     = bytearray()

    while (True):
        offset = fd.tell()
        if offset == last_offset:
            #
            # offset/last_offset being equal says we are doing a rehunt
            # and we ended back at the same record.
            #
            # advance our current position to just beyond the last sync we
            # tried.  Find the next one.
            #
            offset += 2                 # move to next possible
            print('*** rehunt: moving to: @{0} (0x{0:x})'.format(offset))
            offset = hunt(fd, offset)
            if (offset < 0):
                break
            continue
        last_offset = offset
        rec_buf = bytearray(fd.read(SIRF_HDR_SIZE))
        if (len(rec_buf) != SIRF_HDR_SIZE):
            print('*** header read problem: wanted {}, got {}, @{}'.format(
                SIRF_HDR_SIZE, len(rec_buf), offset))
            break                       # oops
        hdr, rlen = sirf.sirf_hdr_struct.unpack(rec_buf)
        if hdr != SIRF_SOP_SEQ:
            print('*** bad SOP: {:4x}, @{}'.format(hdr, offset))
            offset = hunt(fd, offset)
            if (offset < 0):
                break
            continue

        # read rlen payload bytes, check for too big.
        if rlen > SIRF_MAX_PAYLOAD:
            print('*** bad len: {}, @{}'.format(rlen, offset))
            offset = hunt(fd, offset)
            if (offset < 0):
                break
            continue

        # read in payload, checksum and terminating sequence
        # deduct one because we already did the first byte, the mid
        req_len = rlen + SIRF_END_SIZE
        rec_buf.extend(bytearray(fd.read(req_len)))

        # account for the header already read in.
        req_len += SIRF_HDR_SIZE
        if len(rec_buf) != req_len:
            print('*** incorrect number of bytes read: wanted {}, got {}, @{}'.format(
                req_len, len(rec_buf), offset))
            break                       # oops, bail

        # first extract the checksum and terminating sequence.  check term sequence.
        req_sum, term = sirf.sirf_end_struct.unpack(rec_buf[SIRF_HDR_SIZE + rlen:])
        if term != SIRF_EOP_SEQ:
            print('*** bad EOP: {:4x}, @{}'.format(term, offset))
            offset = hunt(fd, offset)
            if (offset < 0):
                break
            continue

        # verify checksum.
        #
        # the sum is only over the payload and does not cover either the SOP, hdr/len
        # nor the EOP, checksum/term.
        #
        # If needs to match the checksum value in the packet.
        #
        chksum = sum(rec_buf[SIRF_HDR_SIZE:SIRF_HDR_SIZE + rlen])
        chksum &= 0x7fff                # force to 15 bits
        if (chksum != req_sum):
            chksum_errors += 1
            chksum1 = '*** checksum failure @{0} (0x{0:x}) ' + \
                      '[wanted: 0x{1:x}, got: 0x{2:x}]'
            print(chksum1.format(offset, req_sum, chksum))
            dump_buf(rec_buf)
            offset = hunt(fd, offset)
            if (offset < 0):
                break
            continue                    # try again

        # life is good.  return actual record.
        mid = rec_buf[SIRF_MID_OFFSET]
        return offset, req_len, mid, rec_buf

    # oops.  things blew up.  just return -1 for the offset
    return -1, 0, 0, ''


# format for summary
# --- offset len  mid     name
# --- 999999 999  128/99  ssssss
# ---    512      1      322  116     1  REBOOT  unset -> GOLD (GOLD)
title0  = '--- offset  len{}                        mid      name'
summary0 = '--- @{:<6d} {:3}{}                  ({:02x})  {:3}{:4}  {:s}'

def dump(args):
    """
    Reads records and prints out details

    A mid-specific decoder is selected for each type of record which
    determines the output

    The input 'args' contains a list of the user input parameters that
    determine which records to print, including: start, end

    Summary information is output after all records have been processed,
    including: number of records output, counts for each record type,
    and mid-specific decoder summary
    """

    global verbose, debug
    global num_hunt, chksum_errors, unk_mids
    global total_records, total_bytes

    init_globals()

    if (args.verbose and args.verbose >= 5):
        print(ver_str)
        print('  decode_base: {}  sirf_defs: {}'.format(db_ver, sb_ver))
        print('  sirf:     d: {}  e: {}  h: {}'.format(sd_ver, se_ver, sh_ver))
        print()

    def count_mid(mid):
        """
        increment counter in dict of mids, create new entry if needed.
        If not known count it as unknown.
        """
        global unk_mids

        try:
            sirf.mid_table[mid]
        except KeyError:
            unk_mids += 1

        try:
            sirf.mid_count[mid] += 1
        except KeyError:
            sirf.mid_count[mid] = 1

    # create file object that handles both buffered and direct io
    infile  = tf.TagFile(args.input)

    verbose = args.verbose if (args.verbose) else 0
    debug   = args.debug   if (args.debug)   else 0

    if (args.jump):
        infile.seek(args.jump)

    wide = ''
    if (args.wide):
        wide = '                                            '

    print(title0.format(wide))

    # extract record from input file and output decoded results
    try:
        while(True):
            rec_offset, rlen, mid, rec_buf = get_record(infile)
            if rec_offset < 0:
                break

            # look to see if past file position bound
            if (args.endpos and rec_offset > args.endpos):
                break                       # all done

            count_mid(mid)

            # first print the summary

            v = sirf.mid_table.get(mid, (None, None, None, 'unk'))
            decode   = v[MID_DECODER]           # mid_table function
            emitters = v[MID_EMITTERS]          # mid_table emitter list
            obj      = v[MID_OBJECT]
            mid_name = v[MID_NAME]              # and the name of the mid

            sid    = rec_buf[SIRF_SID_OFFSET]   # if there is a sid, next byte
            sid_str = '' if mid not in mids_w_sids else '/{}'.format(sid)

            # first display the summary, then any additional decodes
            print(summary0.format(rec_offset, rlen, wide, mid, mid,
                                  sid_str, mid_name), end = '')

            # get_record has verified that we have a proper header, tail,
            # and validated checksum.  All sirf decoders assume we are pointing
            # past the mid.  The mid has already been consumed.
            #
            # so we must start the decoding there as well.

            buf = rec_buf[SIRF_HDR_SIZE+1:]
            if (decode):
                try:
                    decode(verbose, rec_offset, buf, obj)
                    if emitters and len(emitters):
                        for e in emitters:
                            e(verbose, rec_offset, buf, obj)
                except struct.error:
                    print()
                    print('*** decode error: (len: {}, mid: {} {}, '
                          'expected: {}), @{}'.format(rlen, mid, mid_name,
                          len(obj) if obj else 0, rec_offset))
            else:
                print()
                if (verbose >= 5):
                    print()
                    print('*** no decoder installed for mid {} '
                          '({:02x}), @{}'.format(mid, mid, rec_offset),
                          end = '')
            if (verbose >= 3):
                print()
                dump_buf(rec_buf, '    ')
            if (verbose >= 1):
                print()
            total_records += 1
            total_bytes   += rlen
            if (args.num and total_records >= args.num):
                break
    except KeyboardInterrupt:
        print()
        print()
        print('*** user stop')

    print()
    print('*** end of processing @{} (0x{:x}),  processed: {} records, {} bytes'.format(
        infile.tell(), infile.tell(), total_records, total_bytes))
    print('*** hunts: {}, chksum_errs: {}, unk_mids: {}'.format(
        num_hunt, chksum_errors, unk_mids))
    print()
    print('mid/s: {}'.format(sirf.mid_count))

if __name__ == "__main__":
    dump(parseargs())
