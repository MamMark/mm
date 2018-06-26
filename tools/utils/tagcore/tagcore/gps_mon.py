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

__version__ = '0.4.5.rc0'

__all__ = [
    'gps_cmd_name',
    'gps_mon_event_name',
    'gps_mon_minor_name',
    'gps_mon_major_name',
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
    'state':        7,
    'base':         8,
    'hunt':         9,
    'lost':         10,

    'awake':        0x10,
    'mpm':          0x11,
    'pulse':        0x12,
    'reset':        0x13,
    'raw_tx':       0x14,
    'hibernate':    0x15,
    'wake':         0x16,

    'can':          0x80,

    'setlogflag':   0x81,
    'clrlogflag':   0x82,

    'setlogging':   0x83,
    'clrlogging':   0x84,

    'forcelogging': 0x85,
    'getlogging':   0x86,

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
    7:              'state',
    8:              'base',
    9:              'hunt',
    10:             'lost',

    16:             'awake',
    17:             'mpm',
    18:             'pulse',
    19:             'reset',
    20:             'raw_tx',
    21:             'hibernate',
    22:             'wake',

    0x80:           'can',

    0x81:           'setlogflag',
    0x82:           'clrlogflag',

    0x83:           'setlogging',
    0x84:           'clrlogging',

    0x85:           'forcelogging',
    0x86:           'getlogging',

    0xfe:           'low',
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


# gps monitor minor events
gps_mon_events = {
    'none':          0,
    'fail':          1,
    'boot':          2,
    'swver':         3,
    'startup':       4,
    'msg':           5,
    'ots_no':        6,
    'ots_yes':       7,
    'lock_pos':      8,
    'lock_time':     9,
    'mpm':           10,
    'mpm_error':     11,
    'timeout_minor': 12,
    'timeout_major': 13,
    'major_changed': 14,
    'cycle':         15,
    'state_chk':     16,

    0:                  'none',
    1:                  'fail',
    2:                  'boot',
    3:                  'swver',
    4:                  'startup',
    5:                  'msg',
    6:                  'ots_no',
    7:                  'ots_yes',
    8:                  'lock_pos',
    9:                  'lock_time',
    10:                 'mpm',
    11:                 'mpm_error',
    12:                 'timeout_minor',
    13:                 'timeout_major',
    14:                 'major_changed',
    15:                 'cycle',
    16:                 'state_chk',
}

def gps_mon_event_name(mon_ev):
    if isinstance(mon_ev, str):
        return gps_mon_events.get(mon_ev, 0)
    return gps_mon_events.get(mon_ev, 'mon_ev/' + str(mon_ev))


# gps monitor states - minor (basic)
gps_mon_minors = {
    'off':              0,
    'fail':             1,
    'booting':          2,
    'config':           3,

    'comm_check':       4,
    'collect':          5,

    'mpm_wait':         6,
    'mpm_restart':      7,
    'mpm':              8,

    'standby':          9,

    0:                  'off',
    1:                  'fail',
    2:                  'booting',
    3:                  'config',

    4:                  'comm_check',
    5:                  'collect',

    6:                  'mpm_wait',
    7:                  'mpm_restart',
    8:                  'mpm',

    9:                  'standby',
}

def gps_mon_minor_name(minor_state):
    if isinstance(minor_state, str):
        return gps_mon_minors.get(minor_state, 1)
    return gps_mon_minors.get(minor_state, 'minor/' + str(minor_state))


# gps monitor states - major
gps_mon_majors = {
    'idle':             0,
    'cycle':            1,
    'mpm_collect':      2,
    'sats_startup':     3,
    'sats_collect':     4,
    'time_collect':     5,

    0:                  'idle',
    1:                  'cycle',
    2:                  'mpm_collect',
    3:                  'sats_startup',
    4:                  'sats_collect',
    5:                  'time_collect',
}

def gps_mon_major_name(major_state):
    if isinstance(major_state, str):
        return gps_mon_majors.get(major_state, 0)
    return gps_mon_majors.get(major_state, 'major/' + str(major_state))
