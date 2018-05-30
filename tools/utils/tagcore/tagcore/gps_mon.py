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

'''gps commands and messages exported by the tag gps code'''

from   __future__         import print_function

import struct
from   misc_utils   import dump_buf

__version__ = '0.3.2.dev1'

__all__ = [
    'gps_cmd_name',
]

# commands from tos/mm/gps/gps_mon.h
gps_cmds = {
    'nop':          0,
    'on':           1,
    'off':          2,
    'standby':      3,
    'pwron':        4,
    'pwroff':       5,
    'cycle':        6,

    'awake':        0x10,
    'mpm':          0x11,
    'pulse':        0x12,
    'reset':        0x13,
    'raw_tx':       0x14,
    'hibernate':    0x15,
    'wake':         0x16,

    'can':          0x80,

    'low':          0xfc,
    'sleep':        0xfd,
    'panic':        0xfe,
    'reboot':       0xff,

    0:              'nop',
    1:              'on',
    2:              'off',
    3:              'standby',
    4:              'pwron',
    5:              'pwroff',
    6:              'cycle',

    16:             'awake',
    17:             'mpm',
    18:             'pulse',
    19:             'reset',
    20:             'raw_tx',
    21:             'hibernate',
    22:             'wake',

    0x80:           'can',

    0xfe:           'low',
    0xfd:           'sleep',
    0xfe:           'panic',
    0xff:           'reboot',
}

def gps_cmd_name(gps_cmd):
    if isinstance(gps_cmd, str):
        return gps_cmds.get(gps_cmd, 0)
    return gps_cmds.get(gps_cmd, 'unk')

CMD_NOP    = gps_cmds['nop']
CMD_CAN    = gps_cmds['can']
CMD_LOW    = gps_cmds['low']
CMD_RAW_TX = gps_cmds['raw_tx']

# total number of bytes, including overhead that we can send
# using RAW_TX.  SIRF_HEADER is 8 bytes, a0 a2, len, b0, b3
MAX_RAW_TX = 64

# canned_msgs, see GPSmonitorP.nc
canned_msgs = {
    'peek':             0,
    'swver':            1,
    'factory':          2,
    'factory_clear':    3,

    0:                  'peek',
    1:                  'swver',
    2:                  'factory',
    3:                  'factory_clear',
}


# gps monitor states - minor (basic)
gps_mon_states = {
    'off':              0,
    'fail':             1,
    'booting':          2,
    'startup':          3,

    'comm_check':       4,

    'collect_fixes':    5,

    'lock_wait':        6,
    'mpm_wait':         7,
    'mpm_restart':      8,
    'mpm':              9,

    'standby':          10,
    'up':               11,

    0:                  'off',
    1:                  'fail',
    2:                  'booting',
    3:                  'startup',

    4:                  'comm_check',

    5:                  'collect_fixes',

    6:                  'lock_wait',
    7:                  'mpm_wait',
    8:                  'mpm_restart',
    9:                  'mpm',

    10:                 'standby',
    11:                 'up',
}
