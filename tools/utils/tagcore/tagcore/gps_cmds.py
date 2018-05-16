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
from   core_headers import dt_hdr_obj

__version__ = '0.3.0.dev1'

# commands from tos/mm/gps/gps_cmds.h
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

CMD_NOP    = gps_cmds['nop']
CMD_CAN    = gps_cmds['can']
CMD_LOW    = gps_cmds['low']
CMD_RAW_TX = gps_cmds['raw_tx']

# canned_msgs, see GPSmonitorP.nc
canned_msgs = {
    'peek':             0,
    'send_boot':        1,
    'send_start':       2,
    'start_cgee':       3,
    'swver':            4,
    'all_off':          5,
    'all_on':           6,
    'sbas':             7,
    'full_pwr':         8,
    'mpm_0':            9,
    'mpm_7f':           10,
    'mpm_ff':           11,
    'poll_ephem':       12,
    'ee_age':           13,
    'cgee_only':        14,
    'aiding_status':    15,
    'eerom_off':        16,
    'eerom_on':         17,
    'pred_enable':      18,
    'pred_disable':     19,
    'ee_debug':         20,
    'bad_chk':          21,

    0:      'peek',
    1:      'send_boot',
    2:      'send_start',
    3:      'start_cgee',
    4:      'swver',
    5:      'all_off',
    6:      'all_on',
    7:      'sbas',
    8:      'full_pwr',
    9:      'mpm_0',
    10:     'mpm_7f',
    11:     'mpm_ff',
    12:     'poll_ephem',
    13:     'ee_age',
    14:     'cgee_only',
    15:     'aiding_status',
    16:     'eerom_off',
    17:     'eerom_on',
    18:     'pred_enable',
    19:     'pred_disable',
    20:     'ee_debug',
    21:     'bad_chk',
}
