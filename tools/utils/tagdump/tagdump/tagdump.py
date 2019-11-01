# Copyright (c) 2017-2019 Daniel J. Maltbie, Eric B. Decker
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
# Contact: Daniel J. Maltbie <dmaltbie@daloma.org>
#          Eric B. Decker <cire831@gmail.com>

'''
tagdump - dump tag data stream records

Parses the data stream and displays in human readable output.
Can also output parsed records to an external database for
later processing.

Each record is completely self contained including a checksum
that is over both the header and data portion of the record.
(See typed_data.h for details).

see tagdumpargs.py for argument processing.

usage: tagdump.py [-h] [-v] [-V] [-H] [-j JUMP] [-e EndFilePos]
                  [--rtypes RTYPES(ints)] [--rnames RNAMES(name[,...])]
                  [-x | --export]
                  [-s START_TIME] [-e END_TIME]
                  [-r START_REC]  [-l LAST_REC]
                  [-g GPS_EVAL]
                  [-p | --pretty]
                  input
'''

from   __future__         import print_function

import struct

# parse arguments and import result
from   tagdumpargs         import args

from   tagcore             import *
from   tagcore.globals     import *
import tagcore.core_rev    as     vers
from   tagcore.dt_defs     import *
import tagcore.dt_defs     as     dtd
import tagcore.sirf_defs   as     sirf
from   tagcore.tagfile     import *
from   tagcore.misc_utils  import eprint
from   tagcore.mr_emitters import mr_chksum_err

import tagdump_config                   # populate configuration

from   __init__          import __version__   as VERSION
ver_str = '\ntagdump: ' + VERSION + ':  core: ' + str(CORE_REV) + \
          '/' + str(CORE_MINOR)


# This program needs to understand the format of the DBlk data stream.  The
# format of a particular instance is described by typed_data.h.  The define
# CORE_REV in core_rev.h and core_rev.py indicates the version of core
# files being used including typed_data.h.  Matching is a good thing.  We
# won't abort but will bitch if we mismatch.
#
# CORE_MINOR indicates minor changes in published structures.

#
# global control cells
#
rec_low                 = 0            # inclusive
rec_high                = 0            # inclusive
rec_last                = 0            # last rec num looked at

# 1st sector of the first is the directory
DBLK_DIR_SIZE           = 0x200
RLEN_MAX_SIZE           = 1024
RESYNC_HDR_OFFSET       = 28            # how to get back to the start
                                        # or how to move past the majik

# global stat counters
num_resyncs             = 0             # how often we've resync'd
chksum_errors           = 0             # checksum errors seen
unk_rtypes              = 0             # unknown record types
total_records           = 0
total_bytes             = 0
dt_hdr                  = obj_dt_hdr()


def init_globals():
    global rec_low, rec_high, rec_last
    global num_resyncs, chksum_errors, unk_rtypes
    global total_records, total_bytes

    rec_low             = 0
    rec_high            = 0
    rec_last            = 0
    num_resyncs         = 0             # how often we've resync'd
    chksum_errors       = 0             # checksum errors seen
    unk_rtypes          = 0             # unknown record types
    total_records       = 0
    total_bytes         = 0


def resync(fd, offset):
    '''
    resync the data stream to the next SYNC record

    the actual work is handled in the tagfile module, but count
    number of times resync has been performed.
    '''
    global num_resyncs
    num_resyncs += 1
    return fd.resync(offset)


def get_record(fd):
    """
    Generate valid typed-data records one at a time until no more bytes
    can be read from the input file.

    Yields one record each time:
        dt_hdr_obj: (len, type, recnum, rtctime, recsum)

    Input:   fd:         file descriptor we are reading from
    Output:  rec_offset: byte offset of the record from start of file
             hdr         obj_dt_hdr (see above)
             rec_buf:    byte buffer with entire record
    """

    global chksum_errors

    # output and other vars
    offset      = -1
    hdr         = dt_hdr
    rec_buf     = bytearray()

    hdr_len     = len(hdr)              # only call it once
    rlen        = 0
    rtype       = 0
    recnum      = 0
    recsum      = 0

    align0 = '*** aligning offset {0} (0x{0:x}) -> {1} (0x{1:x}) [{2} bytes]'

    last_offset = 0                     # protects against finding same sync

    while (True):
        offset = fd.tell()
        # new records are required to start on a quad boundary
        # however, we always read to the next quad alignment to help ensure
        # that the sparse tagfuse stuff works better (fewer holes).
        if (offset & 3):
            new_offset = ((offset/4) + 1) * 4
            eprint(align0.format(offset, new_offset, new_offset - offset))
            offset = new_offset
            fd.seek(offset)
        if (offset == last_offset):
            #
            # offset/last_offset being equal says we are doing a resync
            # and we ended back at the same record.
            #
            # advance our current position to just beyond the last sync we
            # tried and find the next sync.
            #
            offset += RESYNC_HDR_OFFSET
            eprint('*** resyncing: moving past current majik to: @{0} (0x{0:x})'.format(
                offset))
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue
        last_offset = offset
        rec_buf = bytearray(fd.read(hdr_len))
        if len(rec_buf) < hdr_len:
            eprint('*** record header read too short: wanted {}, got {}, @{}'.format(
                hdr_len, len(rec_buf), offset))
            break                       # oops
        hdr.set(rec_buf)
        rlen   = hdr['len'].val
        rtype  = hdr['type'].val
        recnum = hdr['recnum'].val
        recsum = hdr['recsum'].val

        # check for obvious errors
        if (rlen < hdr_len):
            eprint('*** record size too small: {} @{}'.format(rlen, offset))
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue

        if (rlen > RLEN_MAX_SIZE):
            eprint('*** record size too large: {} @{}'.format(rlen, offset))
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue

        if (recnum == 0):               # zero is never allowed
            eprint('*** zero record number @{} - resyncing'.format(offset))
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue

        # now see if we have any data payload
        # if dlen is negative, that says we are below min header size
        dlen = rlen - hdr_len
        if (dlen < 0):                  # major oops, rlen is screwy
            eprint('*** record header too short: wanted {} got {} @{}'.format(
                hdr_len, rlen, offset))
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue

        # make sure to read bytes to the next quad alignment.  This helps
        # to keep the tagfuse sparse file implementation happier.
        # extra can NEVER be 0.  It can be 1, 2, 3, or 4.  4 indicates
        # that we are already at a new quad alignment.
        extra = 4 - ((offset + rlen) & 3)
        if extra < 4:
            if debug and verbose >= 5:
                eprint('*** reading extra {} bytes for quad alignment'.format(extra))
            dlen += extra

        if (dlen > 0):
            rec_buf.extend(bytearray(fd.read(dlen)))

        if (len(rec_buf) < rlen):
            eprint('*** record read too short: wanted {} got {} @{}'.format(
                rlen, len(rec_buf), offset))
            break                       # oops, bail

        # verify checksum.
        #
        # sum the entire record (byte by byte) and then remove the bytes from recsum.
        # recsum was computed with the field being 0 and then layed down
        # so we need to remove it before comparing.  Recsum is 16 bits wide so can not
        # simply be added in as part of the checksum computation.
        #
        chksum = sum(rec_buf[:rlen])
        chksum -= (recsum & 0xff00) >> 8
        chksum -= (recsum & 0x00ff)
        chksum &= 0xffff                # force to 16 bits vs. 16 bit recsum
        if (chksum != recsum):
            chksum_errors += 1
            chksum1 = '*** checksum failure @{0} (0x{0:x}) ' + \
                      '[wanted: 0x{1:x} got: 0x{2:x}]'
            eprint(chksum1.format(offset, recsum, chksum))
            if mr_emitters:
                mr_chksum_err(offset, recsum, chksum)
            else:
                if not dump_hdr(offset, rec_buf, '*** ') or verbose >= 3:
                    print()
                    dump_buf(rec_buf, '    ')
            offset = resync(fd, offset)
            if (offset < 0):
                break
            continue                    # try again

        v = dtd.dt_records.get(rtype, (0, None, None, None, ''))
        required_len = v[DTR_REQ_LEN]
        if (required_len):
            if (required_len != rlen):
                print('*** len violation, required: {} got {}'.format(
                    required_len, rlen))
                dump_hdr(offset, rec_buf, '*** ')
                print()
                dump_buf(rec_buf, '    ')
                offset = resync(fd, offset)
                if (offset < 0):
                    break
                continue            # try again

        # life is good.  return actual record.
        return offset, hdr, rec_buf

    # oops.  things blew up.  just return -1 for the offset
    return -1, hdr, ''


def process_dir(fd):
    fd.seek(DBLK_DIR_SIZE)


def dump():
    """
    Reads records and prints out details

    A dt-specific decoder is selected for each type of record which
    determines the output

    The global 'args' contains a list of the user input parameters that
    determine which records to print, including: start, end, type

    Summary information is output after all records have been processed,
    including: number of records output, counts for each record type,
    and dt-specific decoder summary
    """

    global rec_low, rec_high, rec_last
    global num_resyncs, chksum_errors, unk_rtypes
    global total_records, total_bytes

    init_globals()

    dtd.cfg_print_hourly = args.hourly
    if debug or verbose >= 5:
        eprint(ver_str)
        eprint('  base_objs: {:10}  dt_defs: {:10}'.format(
            vers.base_ver, vers.dt_ver))
        eprint('   core:     {:10}  e: {:10}  h: {:10}  panic:  h: {:10}'.format(
            vers.core_ver, vers.ce_ver, vers.ch_ver, vers.pi_ver))
        eprint('   sirf:  d: {:10}  e: {:10}  h: {:10}'.format(
            vers.sd_ver, vers.se_ver, vers.sh_ver))
        eprint('   sns:   d: {:10}  e: {:10}  h: {:10}'.format(
            vers.snsd_ver, vers.snse_ver, vers.snsh_ver))
        eprint()

    def count_dt(rtype):
        """
        increment counter in dict of rtypes, create new entry if needed
        also check for existence of dtd.dt_records entry.  If not known
        count it as unknown.
        """
        global unk_rtypes

        try:
            dtd.dt_records[rtype]
        except KeyError:
            unk_rtypes += 1

        try:
            dtd.dt_count[rtype] += 1
        except KeyError:
            dtd.dt_count[rtype] = 1

    # Any -s argument (walk syncs backward) or -r -1 (last_rec) forces net io
    if (args.sync is not None or args.start_rec == -1 or args.tail):
        args.net = True

    if debug:
        tail_str = ' (tailing)'  if args.tail else ''
        io_str   = 'network' if args.net  else 'local'
        to_str   = '  timeout: {} secs'.format(args.timeout) \
                   if args.net else ''
        eprint('*** {} i/o{}{}'.format(io_str, tail_str, to_str))
        if args.num:
            eprint('*** {} records'.format(args.num))
        eprint('*** verbosity: {:7}'.format(verbose))
        eprint('*** quiet:     {:7}'.format(quiet))
        eprint('*** pretty:    {:7}'.format(pretty))
        start_rec = args.start if args.start else 1
        end_rec   = args.end   if args.end   else 'end'
        eprint('*** records: {:9} - {}'.format(start_rec, end_rec))
        start_pos = args.jump if args.jump else 0
        end_pos   = args.endpos if args.endpos else 'eof'
        eprint('*** offsets: {:9} - {}'.format(start_pos, end_pos))
        if args.rtypes:
            eprint('*** restricted to rtypes: {}'.format(args.rtypes))
        eprint()


    # create file object that handles both buffered and direct io
    infile  = TagFile(args.input, net_io = args.net, tail = args.tail,
                      verbose = verbose, timeout = args.timeout)

    if (args.start_rec):
        rec_low  = args.start_rec
    if (args.last_rec):
        rec_high = args.last_rec

    # process the directory, this will leave us pointing at the first header
    process_dir(infile)

    if (args.jump):
        if (args.jump == -1):
            infile.seek(0, how = TF_SEEK_END)
        elif (args.jump < 0):
            infile.seek(args.jump, how = TF_SEEK_END)
        else:
            infile.seek(args.jump)

    no_header = args.quiet or args.mr_emitters
    if not no_header:
        print(dtd.rec_title_str)

    # extract record from input file and output decoded results
    try:
        while(True):
            rec_offset, hdr, rec_buf = get_record(infile)

            if (rec_offset < 0):
                break

            # hdr was populated (.set) by get_record
            rlen     = hdr['len'].val
            rtype    = hdr['type'].val
            recnum   = hdr['recnum'].val

            if (recnum < rec_last):
                eprint('*** recnum went backwards.  last: {}, new: {}, @{}'.format(
                    rec_last, recnum, rec_offset))
            if (rec_last and recnum > rec_last + 1):
                eprint('*** record gap: ({}) records @{}'.format(
                    recnum - rec_last, rec_offset))
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

            # look to see if past file position bound
            if (args.endpos and rec_offset > args.endpos):
                break                       # all done

            count_dt(rtype)
            v = dtd.dt_records.get(rtype, (0, None, None, None, ''))
            decoder  = v[DTR_DECODER]           # dt function
            emitters = v[DTR_EMITTERS]          # emitter list
            obj      = v[DTR_OBJ]               # dt object
            if (decoder):
                try:
                    decoder(verbose, rec_offset, rec_buf, obj)
                    if emitters and len(emitters):
                        for e in emitters:
                            e(verbose, rec_offset, rec_buf, obj)
                except struct.error:
                    eprint('*** decoder/emitter struct/obj error: (len: {}, '
                          'rtype: {} {}, wanted: {}), @{}'.format(
                              rlen, rtype, dt_name(rtype),
                              len(obj) if obj else 0, rec_offset))
            else:
                if debug or not quiet or verbose >= 5:
                    eprint('*** no decoder installed for rtype {}, @{}'.format(
                        rtype, rec_offset))
            if (verbose >= 3):
                print()
                dump_hdr(rec_offset, rec_buf, '    ')
                dump_buf(rec_buf, '    ')
            if verbose >= 1 and not quiet and not mr_emitters:
                print()
            total_records += 1
            total_bytes   += rlen
            if (args.num and total_records >= args.num):
                break
            #
            # if we have a SYNC_FLUSH then advance to the next sector
            # boundary.  System_Flush and we should have a reboot record
            # in the next sector.
            #
            if rtype == DT_SYNC_FLUSH:
                new_offset = rec_offset + 512
                new_offset &= 0xfffffe00
                eprint()
                eprint('*** SYNC_FLUSH: @{} advancing to next '
                       'sector @{}'.format(rec_offset, new_offset))
                eprint()
                infile.seek(new_offset)

    except KeyboardInterrupt:
        eprint()
        eprint()
        eprint('*** user stop')

    eprint()
    eprint('*** end of processing @{}  (0x{:x})  processed: {} records  {} bytes'.format(
            infile.tell(), infile.tell(), total_records, total_bytes))
    eprint('*** reboots: {}  resyncs: {}  chksum_errs: {}  unk_rtypes: {}'.format(
        dtd.dt_count.get(DT_REBOOT, 0), num_resyncs, chksum_errors, unk_rtypes))
    if chksum_errors > 0:
        eprint()
        eprint('****** non-zero chksum_errors: {}'.format(chksum_errors))
        eprint()
    eprint('rtypes: {}'.format(dtd.dt_count))
    eprint('mids:   {}'.format(sirf.mid_count))

if __name__ == "__main__":
    dump()
