# Copyright (c) 2020 Eric B. Decker
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

'''ubxdump: dump a ublox binary file

Vebosity;

  0   just display basic record, summary (default)
  1   basic record display - more details
  2   detailed record display
  3   dump packet buffer
  4   details of rehunt (look for new SOP)
  5   other errors and decoder/header versions
'''

from   __future__               import print_function

import sys
import struct

from   tagcore                  import *
import tagcore.core_rev         as     vers
from   tagcore.ubx_defs         import *
import tagcore.ubx_defs         as     ubx
import tagcore.tagfile          as     tf

from   ubxdumpargs              import parseargs

# import configuration, which will populate decode/emitter trees.
import ubxdump_config

from   __init__                 import __version__   as VERSION

ver_str = '\nubxdump: ' + VERSION

####
#
# ubxdump: dump ubx binary protocol packets
#
# Parses the input as a ublox binary (ubx) packet stream and displays in human
# readable output.
#
# usage: ubxdump.py [-h] [-v] [-V] [-j JUMP] [-x EndFilePos]
#                   [-D] [-n num_recs]
#                   input
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
unk_cids                = 0             # unknown record types
total_records           = 0
total_bytes             = 0

def init_globals():
    global verbose, debug
    global num_hunt, chksum_errors, unk_cids
    global total_records, total_bytes

    verbose             = 0
    debug               = 0

    num_hunt            = 0             # how often we've hunted for start
    chksum_errors       = 0             # checksum errors seen
    unk_cids            = 0             # unknown record types
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
            if accum == UBX_SOP_SEQ:
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
    """get next ubxbin record

    generate next valid sirfbin record, one at a time until no
    more bytes to read from input.

    Yields one record each time (offset, rec_len, cid, rec_buf).

    Input:   fd:         file descriptor we are reading from
    Output:  rec_offset: byte offset of the record from start of file
             cid:        type of packet
             rec_len:    record length
             rec_buf:    byte buffer with entire record
    """

    global chksum_errors

    # output variables
    offset      = 0
    last_offset = -1
    len_val     = 0
    cid         = 0
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
            offset += 1                 # move to next possible
            print('*** rehunt: moving to: @{0} (0x{0:x})'.format(offset))
            offset = hunt(fd, offset)
            if (offset < 0):
                break
            continue
        last_offset = offset
        rec_buf = bytearray(fd.read(UBX_HDR_SIZE))
        if (len(rec_buf) != UBX_HDR_SIZE):
            print('*** header read problem: wanted {}, got {}, @{}'.format(
                UBX_HDR_SIZE, len(rec_buf), offset))
            break                       # oops
        hdr, cid = ubx.ubx_cid_struct.unpack(rec_buf[0:UBX_LEN_OFFSET])
        if hdr != UBX_SOP_SEQ:
            print('*** bad SOP: x{:04x}, @{}'.format(hdr, offset))
            offset = hunt(fd, offset)
            if (offset < 0):
                break
            continue

        # little endian
        len_val = rec_buf[UBX_LEN_OFFSET] | (rec_buf[UBX_LEN_OFFSET + 1] << 8)

        # read len_val payload bytes, check for too big.
        if len_val > UBX_MAX_PAYLOAD:
            print('*** bad len: {}, @{}'.format(len_val, offset))
            offset = hunt(fd, offset)
            if (offset < 0):
                break
            continue

        # read in payload and checksum
        rec_len = len_val + UBX_CHK_SIZE
        rec_buf.extend(bytearray(fd.read(rec_len)))

        # account for the header already read in.
        rec_len += UBX_HDR_SIZE
        if len(rec_buf) != rec_len:
            print('*** incorrect number of bytes read: wanted {}, got {}, @{}'.format(
                rec_len, len(rec_buf), offset))
            break                       # oops, bail

        # verify checksum.
        chka = 0
        chkb = 0
        for idx in range(UBX_CLASS_OFFSET, rec_len - UBX_CHK_SIZE):
            chka += rec_buf[idx]
            chka &= 0xff
            chkb += chka
            chkb &= 0xff
        rec_sum = rec_buf[rec_len - UBX_CHK_SIZE] << 8 | rec_buf[rec_len - UBX_CHK_SIZE + 1]
        chksum  = chka << 8 | chkb
        if (chksum != rec_sum):
            chksum_errors += 1
            chksum1 = '*** checksum failure @{0} (0x{0:x}) ' + \
                      '[wanted: 0x{1:x}, got: 0x{2:x}]'
            print(chksum1.format(offset, rec_sum, chksum))
            dump_buf(rec_buf)
            offset = hunt(fd, offset)
            if (offset < 0):
                break
            continue                    # try again

        return offset, cid, rec_len, rec_buf

    # oops.  things blew up.  just return -1 for the offset
    return -1, 0, 0, ''


# format for summary
# --- offset len  cid    name
# --- 999999 999  ff/ff  ssssss
title0   = '--- offset  len{}   cid   name            iTOW'
summary0 = '--- @{:<6d} {:3}{}  ({:04x}) {:16s}'

def dump(args):
    """
    Reads records and prints out details

    A cid-specific decoder is selected for each type of record which
    determines the output

    The input 'args' contains a list of the user input parameters that
    determine which records to print, including: start, end

    Summary information is output after all records have been processed,
    including: number of records output, counts for each record type,
    and cid-specific decoder summary
    """

    global verbose, debug
    global num_hunt, chksum_errors, unk_cids
    global total_records, total_bytes

    init_globals()
    verbose = args.verbose if (args.verbose) else 0
    debug   = args.debug   if (args.debug)   else 0

    if (debug or (args.verbose and args.verbose >= 5)):
        print(ver_str)
        print('  base:       {}  ubx_defs: {}'.format(vers.base_ver, vers.ud_ver))
        print('  ubx:     e: {}         h: {}'.format(vers.ue_ver,   vers.uh_ver))
        print()

    def count_cid(cid):
        """
        increment counter in dict of cids, create new entry if needed.
        If not known count it as unknown.
        """
        global unk_cids

        try:
            ubx.cid_table[cid]
        except KeyError:
            unk_cids += 1

        try:
            ubx.cid_count[cid] += 1
        except KeyError:
            ubx.cid_count[cid] = 1

    if debug:
        if args.num:
            print('*** {} records'.format(args.num))
        print('*** verbosity: {:7}'.format(verbose))
        start_pos = args.jump if args.jump else 0
        end_pos   = args.endpos if args.endpos else 'eof'
        print('*** offsets: {:9} - {}'.format(start_pos, end_pos))
        print()


    # create file object that handles both buffered and direct io
    infile  = tf.TagFile(args.input)

    if (args.jump):
        infile.seek(args.jump)

    wide = ''
    if (args.wide):
        wide = '                                            '

    print(title0.format(wide))

    # extract record from input file and output decoded results
    try:
        while(True):
            rec_offset, cid, rlen, rec_buf = get_record(infile)
            if rec_offset < 0:
                break

            # look to see if past file position bound
            if (args.endpos and rec_offset > args.endpos):
                break                       # all done

            count_cid(cid)

            # first print the summary

            v = ubx.cid_table.get(cid, (None, None, None, 'unk'))
            decoder  = v[CID_DECODER]           # cid_table function
            emitters = v[CID_EMITTERS]          # cid_table emitter list
            obj      = v[CID_OBJECT]
            cid_name = v[CID_NAME]              # and the name of the cid

            # first display the summary, then any additional decodes
            print(summary0.format(rec_offset, rlen, wide, cid, cid_name),
                  end = '')

            # get_record has verified that we have a proper header and
            # validated checksum.  All ubx decoders assume we are pointing
            # at the start of the ubx header (the SOP).

            if (decoder):
                try:
                    decoder(verbose, rec_offset, rec_buf, obj)
                    if not emitters or len(emitters) == 0:
                        print()
                        if (verbose >= 5):
                            print('*** no emitters defined for cid x{:04x}'.format(cid))
                    else:
                        for e in emitters:
                            e(verbose, rec_offset, rec_buf, obj, 0)
                except struct.error:
                    print()
                    print('*** decode error: (len: {}, cid: x{:04x} {}, '
                          'expected: {}), @{}'.format(rlen, cid, cid_name,
                          len(obj) if obj else 0, rec_offset))
            else:
                print()
                if (verbose >= 5):
                    print()
                    print('*** no decoder installed for cid x{:04x} '
                          '({}), @{}'.format(cid, cid_name, rec_offset),
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
    print('*** hunts: {}, chksum_errs: {}, unk_cids: {}'.format(
        num_hunt, chksum_errors, unk_cids))
    print()
    out = []
    for k,v in sorted(ubx.cid_count.iteritems()):
        out.append(('x{:04x}: {}'.format(k, v)))
    print('cid/s: { ', end = '')
    print(*out, sep=', ', end='')
    print(' }')
    print()

if __name__ == "__main__":
    dump(parseargs())
