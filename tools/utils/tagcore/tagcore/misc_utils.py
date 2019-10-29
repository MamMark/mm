# Copyright (c) 2017-2018 Eric B. Decker, Daniel J. Maltbie
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

'''misc utilities'''

from   __future__ import print_function
import binascii
import sys

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


def dump_buf(buf, pre = '', desc = 'rec:  '):
    bs = buf_str(buf)
    stride = 16         # how many bytes per line

    # 3 chars per byte
    idx = 0
    print(pre + desc, end = '')
    while(idx < len(bs)):
        max_loc = min(len(bs), idx + (stride * 3))
        print(bs[idx:max_loc])
        idx += (stride * 3)
        if idx < len(bs):              # if more then print counter
            print(pre + '{:04x}: '.format(idx/3), end = '')

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)
