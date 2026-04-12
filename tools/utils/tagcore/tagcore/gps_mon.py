# Copyright (c) 2018-2019, 2021 Eric B. Decker
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

__version__ = '0.4.10.dev0'

__all__ = [
    'gps_cmd_name',
    'gps_mon_event_name',
    'gps_mon_major_name',
]


remlog_cmds = {
    'setflag':  0x81,                   # takes enum
    'clrflag':  0x82,                   # takes enum
    'set':      0x83,                   # bit mask
    'clr':      0x84,                   # bit mask
    'force':    0x85,                   # bit array
    'get':      0x86,                   # get bit array

    0x81:       'setflag',
    0x82:       'clrflag',
    0x83:       'set',
    0x84:       'clr',
    0x85:       'force',
    0x86:       'get',
}


# commands from tos/mm/gps/gps_mon.h
gps_cmds = {
    'nop':          0,
    'on':           1,
    'off':          2,
    'standby':      3,
    'pwron':        4,
    'pwroff':       5,
    'cycle':        6,
    'state':        7,
    'home':         8,
    'near':         9,
    'lost':         10,

    'raw_tx':       0x14,

    'can':          0x80,

    # reserved for RemLog (remote logging control)
    'rl/setflag':   0x81,
    'rl/clrflag':   0x82,

    'rl/set':       0x83,
    'rl/clr':       0x84,

    'rl/force':     0x85,
    'rl/get':       0x86,

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
    7:              'state',
    8:              'home',
    9:              'near',
    10:             'lost',

    20:             'raw_tx',

    0x80:           'can',

    0x81:           'rl/setflag',
    0x82:           'rl/clrflag',

    0x83:           'rl/set',
    0x84:           'rl/clr',

    0x85:           'rl/force',
    0x86:           'rl/get',

    0xfd:           'sleep',
    0xfe:           'panic',
    0xff:           'reboot',
}

def gps_cmd_name(gps_cmd):
    if isinstance(gps_cmd, str):
        return gps_cmds.get(gps_cmd, 0)
    return gps_cmds.get(gps_cmd, 'cmd/' + str(gps_cmd))

CMD_NOP    = gps_cmds['nop']
CMD_CAN    = gps_cmds['can']
CMD_RAW_TX = gps_cmds['raw_tx']

# total number of bytes, including overhead that we can send
# using RAW_TX.  UBX_HEADER is 8 bytes, b5 62, class, id, len, chka, chkb
MAX_RAW_TX = 64

# canned_msgs, see GPSmonitorP.nc
canned_msgs = {
}


# gps monitor minor events
gps_mon_events = {
    'none':          0,
    'fail':          1,
    'boot':          2,
    'swver':         3,
    'startup':       4,
    'msg':           5,

    'fix':           8,
    'time':          9,
    'sleep':         10,

    'timeout_major': 13,
    'major_changed': 14,
    'cycle':         15,
    'state_chk':     16,
    'pwr_off':       17,

    0:                  'none',
    1:                  'fail',
    2:                  'boot',
    3:                  'swver',
    4:                  'startup',
    5:                  'msg',

    8:                  'fix',
    9:                  'time',
    10:                 'sleep',

    13:                 'timeout_major',
    14:                 'major_changed',
    15:                 'cycle',
    16:                 'state_chk',
    17:                 'pwr_off',
}

def gps_mon_event_name(mon_ev):
    if isinstance(mon_ev, str):
        return gps_mon_events.get(mon_ev, 0)
    return gps_mon_events.get(mon_ev, 'mon_ev/' + str(mon_ev))



# gps monitor states - major
gps_mon_majors = {
    'boot':             0,
    'sleep_delay':      1,
    'sleep':            2,
    'cycle':            3,
    'sats_startup':     4,
    'sats_collect':     5,
    'time_collect':     6,

    0:                  'boot',
    1:                  'sleep_delay',
    2:                  'sleep',
    3:                  'cycle',
    4:                  'sats_startup',
    5:                  'sats_collect',
    6:                  'time_collect',
}

def gps_mon_major_name(major_state):
    if isinstance(major_state, str):
        return gps_mon_majors.get(major_state, 0)
    return gps_mon_majors.get(major_state, 'major/' + str(major_state))
