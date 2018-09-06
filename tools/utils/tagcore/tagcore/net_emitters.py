# Copyright (c) 2018 Daniel J. Maltbie <dmaltbie@daloma.org>
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

'''emitters for TagNet network data type records'''

from   __future__         import print_function

__version__ = '0.0.1'

from   ctypes       import c_long

from   dt_defs      import rec0, rtctime_str

from   net_headers  import *

################################################################
#

def emit_tagnet(level, offset, buf, obj):
    xlen     = obj['len'].val
    xtype    = obj['type'].val
    recnum   = obj['recnum'].val
    rtctime  = obj['rt']
    brt      = rtctime_str(rtctime)

    print_hourly(rtctime)
    print(rec0.format(offset, recnum, brt, xlen, xtype,
                      dt_name(xtype)))

    # isolate just the tagnet message
    msgbuf   = buf[len(obj):]
    try:
        msg = TagMessage(msgbuf)
        print('header:{}'.format(msg.header))
        print('name:{}'.format(msg.name))
        print('payload:{}'.format(msg.payload if msg.payload else ''))
    except:
        print('raw:{}'.format(hexlify(msgbuf)))
