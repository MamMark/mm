'''file or network interface for data stream data'''

# Copyright (c) 2017-2018 Daniel J. Maltbie, Eric B. Decker
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


import os
import sys
import types
import time
import errno

# NOTE: os.lseek(fd, pos, how) and file.seek(pos, whence) use os.SEEK_SET (0),
# os.SEEK_CUR (1), and os.SEEK_END (2) for the how or whence parameter.

TF_SEEK_END = os.SEEK_END

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

        if (self.net_io):
            self.fd.close()
            self.fileno = os.open(self.name, os.O_DIRECT | os.O_RDONLY)

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
            except OSError as e:
                if (e.errno == errno.ENODATA):
                    if (self.tail):
                        if self.verbose >= 5:
                            print '*** TF.read: buf len: ', len(buf)
                        time.sleep(self.timeout)
                        continue
                    print '*** data stream EOF, sorry'
                    print '*** use --tail to wait for data at EOF'
                    return ''
                print '*** TF.read: unhandled OSError exception', sys.exc_info()[0]
                raise
            except:
                print '*** TF.read: unhandled exception', sys.exc_info()[0]
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
