# Copyright (c) 2017-2019 Eric B. Decker, Daniel J. Maltbie
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
from   datetime   import datetime
import binascii
import sys

__version__ = '0.4.6'


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


def utc_str(pretty=1):
    fmt_str = '%Y/%m/%dT%H:%M:%S.%f' if pretty else '%Y%m%dT%H%M%S.%f'
    return fmt_str

##
# rtc2datetime: convert an rtc object to a datetime object
#
def rtc2datetime(rtc_obj):
    if rtc_obj['year'].val == 0:
        return datetime(1970,1,1,0,0,0,0)
    return datetime(
        rtc_obj['year'].val,
        rtc_obj['mon'].val,
        rtc_obj['day'].val,
        rtc_obj['hr'].val,
        rtc_obj['min'].val,
        rtc_obj['sec'].val,
       (rtc_obj['sub_sec'].val* 1000000) / 32768,
    )

def rtctime_iso(rtctime):
    '''
    convert a rtctime into an ISO-8601 formatted string displaying the time.
    '''
    return rtc2datetime(rtctime).isoformat()


def rtctime_full(rtctime, pretty=1):
    '''
    convert a rtctime into a full ISO-8601 formatted string displaying the time.
    Full means all digits are spaced out.
    '''
    return rtc2datetime(rtctime).strftime(utc_str(pretty))

def expand_datetime(dt, pretty=1):
    return dt.strftime(utc_str(pretty))
