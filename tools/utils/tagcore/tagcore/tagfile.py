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

'''switchable file/network interface for tag byte streams'''


from   __future__         import print_function

__all__ = [
    'TagFile',
    'TF_SEEK_END',
]

import os
import sys
import types
import time
import errno
import struct

from dt_defs import *

# negative offset indicates file i/o error
EODATA = -14
EINVAL = -6
EBUSY  = -5
ELAST  = -14

def int32(x):
  if x>0xFFFFFFFF:
    raise OverflowError
  if x>0x7FFFFFFF:
    x=int(0x100000000-x)
    if x<2147483648:
      return -x
    else:
      return -2147483648
  return x

# NOTE: os.lseek(fd, pos, how) and file.seek(pos, whence) use os.SEEK_SET (0),
# os.SEEK_CUR (1), and os.SEEK_END (2) for the how or whence parameter.

TF_SEEK_END = os.SEEK_END

MAX_ZERO_SIGS           = 1024          # 1024 quads, 4K bytes of zero

class TagFile(object):
    '''TagDump File Class

    inputs:     input   FileType, input file stream
                net_io  true if doing network i/o
                tail    true if hang at the tail of input, keep trying
                        waiting for more network i/o.  Forces net_io.
                verbose vebosity level (see tagdump.py)
                timeout timeout value (default 60 secs) for --tail/net_io

    methods:    read    reads CNT bytes from the input stream.  If doing
                        network i/o (net_io true) and --tail is set will
                        repeated try for additional reads when at eof.

                tell    will return current stream position in bytes.

                seek    set stream position to position/whence.  Whence
                        determines the base that is used for using position.
    '''

    def __init__(self, input, net_io = False, tail = False,
                 verbose = 0, timeout = 60):
        super( TagFile, self ).__init__()

        if not isinstance(input, types.FileType):
            raise IOError('not expected file type {}'.format(input))

        self.net_io = net_io
        self.tail   = tail
        self.verbose= verbose
        self.timeout= timeout
        self.fd     = input
        self.name   = input.name
        self.rsname = os.path.dirname(os.path.realpath(os.path.expanduser(self.name))) + '/.resync'

        if (self.net_io):
            self.fd.close()
            self.fileno   = os.open(self.name, os.O_DIRECT | os.O_RDONLY)

    def read(self, cnt):
        buf = ''
        while True:
            try:
                if (self.net_io):
                    new = os.read(self.fileno, cnt - len(buf))
                else:
                    new = self.fd.read(cnt - len(buf))

                # reading at the EOF may have already raised
                # OSError(ENODATA).  But if it doesn't the
                # read will return the null string, ''.  If
                # we get that, raise the OSError ourselves.

                if new == '':
                    raise OSError(errno.ENODATA, os.strerror(errno.ENODATA))
                buf += new
                if (len(buf) != cnt):
                    continue
                return buf
            except (OSError, IOError) as e:
                if (e.errno == errno.ENODATA):
                    if (self.tail):
                        if self.verbose >= 5:
                            print('*** TF.read: buf len: ', len(buf))
                        time.sleep(self.timeout)
                        continue
                    print('*** data stream EOF, sorry')
                    print('*** use --tail to wait for data at EOF')
                    return ''
                print('*** TF.read: unhandled OSError/IOError exception',
                      sys.exc_info()[0])
                raise
            except:
                print('*** TF.read: unhandled exception', sys.exc_info()[0])
                raise

    def tell(self):
        if (self.net_io):
            return os.lseek(self.fileno, 0, os.SEEK_CUR)
        else:
            return self.fd.tell()

    def seek(self, pos, how=os.SEEK_SET):
        if (self.net_io):
            return os.lseek(self.fileno, pos, how)
        else:
            return self.fd.seek(pos, how)

    def resync(self, offset):
        '''resync the data stream to the next SYNC record

        input:  offset      where to start looking for sync

        output: offset      offset of found sync record
                            -n (1..16) if something went wrong
                            positive value is Tag error code

        In the case of 'net_io' the tag is requested to search
        for the next sync by using file.truncate() to initiate
        the search and checking for completion by polling the
        'dblk/.resync' file size. When file size is zero, then tag
        is busy looking for sync record. When file size is non-zero,
        the tag has completed the search. This could indicate the
        new file position or could be a sync error, which is indicated
        by the negative offset value.

        Otherwise the search will be conducted on file by reading
        the byte stream to look for a valid sync record. This is
        done by advancing one quad-aligned word and inspecting the
        byte stream for a valid SYNC record. There are three possible
        SYNC record types that all share the same record format and
        only differ in type. (SYNC, SYNC_FLUSH, SYNC_REBOOT). A valid
        record has the correct type, length, majik value, and header
        checksum.

        Once we think we have a good SYNC, we leave the file position
        at the start of the SYNC.  And let other checks needed be
        performed by get_record.

        We use the smallest negative numbers to indicate various tag
        errors. The offset is an unsigned 32bit number, meaning this
        overlaps with the last bytes of the file. But we assert
        that the last 28 bytes of the file cannot be a sync record
        and therefore this call will never return this a valid offset.
        '''
        if (self.verbose >= 2):
            print()
            print('*** resync started @{0} (0x{0:x})'.format(offset))

        # make sure offset starts on quad word
        if (offset & 3 != 0):
            resync0 = '*** resync: unaligned offset: {0} (0x{0:x}) -> {1} (0x{1:x})'
            print(resync0.format(offset, (offset/4)*4))
            offset = (offset / 4) * 4

        # if using network then have remote tag search for sync record
        #
        if self.net_io:
            rsfileno = os.open(self.rsname, os.O_RDWR)
            if (self.verbose >= 3):
                print('resync',self.rsname, offset, rsfileno)
            os.ftruncate(rsfileno, offset)
            for i in range(100):
                offset = os.fstat(rsfileno).st_size
                if offset != 0: break
                time.sleep(.1)
            os.close(rsfileno)
            # look for error code as one of least negative numbers
            if (self.verbose >= 3):
                print('resync2',offset,i)
            if int32(offset) > 0 or int32(offset) < ELAST:
                self.seek(offset)
                return offset
            if int32(offset) == EODATA:
                raise EOFError
            raise IOError

        # else search file byte stream for sync record
        #
        record = dt_records[DT_SYNC][DTR_OBJ]
        zero_sigs = 0
        while (True):
            # read a sync record's worth of data and check field validity
            try:
                self.seek(offset)
                buf = self.read(dt_records[DT_SYNC][DTR_REQ_LEN])
                if len(buf) < dt_records[DT_SYNC][DTR_REQ_LEN]:
                  if (self.verbose >= 4):
                    print('*** resync: too few bytes read for resync record, '
                          'wanted {}, got {}'.format(
                            dt_records[DT_SYNC][DTR_REQ_LEN], len(buf)))
                  return EODATA
                record.set(buf)
                # check majik, length, type and header sum
                if ((record['majik'].val == dt_sync_majik) and
                    (record['hdr']['len'].val == len(record)) and
                    ((record['hdr']['type'].val == DT_SYNC) or
                     (record['hdr']['type'].val == DT_SYNC_FLUSH) or
                     (record['hdr']['type'].val == DT_SYNC_REBOOT))): # found valid sync record
                    self.seek(offset) # backup file pointer to beginning of record
                    return offset     # and return offset of record
                if (record['majik'] == 0):
                    zero_sigs += 1    # series of zeros means no data in file
                    if (zero_sigs > MAX_ZERO_SIGS):
                        print('*** resync: too many zeros ({} x 4), bailing, @{}'.format(
                            MAX_ZERO_SIGS, offset))
                        return EODATA      # file looks empty
                    else:
                        zero_sigs = 0
                offset += 4         # advance to next quad-aligned word and repeat
                if (self.verbose >= 3):
                    rlen   = record['hdr']['len'].val
                    rtype  = record['hdr']['type'].val
                    recnum = record['hdr']['recnum'].val
                    resync2 = '*** resync: failed record @{} (0x{:x}): ' + \
                              'len: {}, type: {}, rec: {}'
                    print(resync2.format(offset-4, offset-4, rlen, rtype, recnum))
                    print('    moving to: @{0} (0x{0:x})'.format(offset, offset))
            except struct.error:
                resync1 = '*** resync: (struct error) [len: {0}] @{1} (0x{1:x})'
                print(resync1.format(len(buf), offset, offset))
                raise
            except IOError:
                print('*** resync: file io error @{}'.format(offset))
                raise
            except EOFError:
                print('*** resync: end of file @{}'.format(offset))
                raise
            except:
                print('*** resync: exception error: {} @{}'.format(
                    sys.exc_info()[0], offset))
                raise
        return -1
