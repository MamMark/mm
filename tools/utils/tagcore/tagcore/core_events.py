# Copyright (c) 2019, Eric B. Decker
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

'''Core Event definitions'''

from   __future__         import print_function

__all__ = [

    # event identifiers

    'PANIC_WARN',
    'FAULT',
    'GPS_CYCLE_LTFF',
    'GPS_FIRST_FIX',
    'DCO_REPORT',
    'DCO_SYNC',
    'TIME_SRC',
    'IMG_MGR',
    'TIME_SKEW',
    'SD_ON',
    'SD_OFF',
    'SD_REQ',
    'SD_REL',
    'RADIO_MODE',
    'GPS_BOOT_SLEEP',
    'GPS_CYCLE_START',
    'GPS_CYCLE_END',
    'GPS_DELTA',
    'GPS_BOOT',
    'GPS_BOOT_TIME',
    'GPS_BOOT_FAIL',
    'GPS_MON_MAJOR',
    'GPS_RX_ERR',
    'GPS_LOST_INT',
    'GPS_MSG_OFF',
    'GPS_CMD',
    'GPS_RAW_TX',
    'GPS_CANNED',
    'GPS_TURN_ON',
    'GPS_STANDBY',
    'GPS_TURN_OFF',
    'GPS_TX_RESTART',
    'GPS_ACK',
    'GPS_NACK',
    'GPS_NO_ACK',
    'GPS_FAST',
    'GPS_FIRST',
    'GPS_PWR_OFF',
    'GPS_SATS',
]

# EVENT
event_names = {
    0:  'NONE',

    1:  'PANIC_WARN',
    2:  'FAULT',

#   3:  'GPS_GEO',              # deprecated, backward compatibility
#   4:  'GPS_XYZ',              # deprecated, backward compatibility
#   5:  'GPS_TIME',             # deprecated, backward compatibility

    6:  'GPS_CYCLE_LTFF',
    7:  'GPS_FIRST_FIX',

    8:  'SSW_DELAY_TIME',
    9:  'SSW_BLK_TIME',
    10: 'SSW_GRP_TIME',

    11: 'SURFACED',
    12: 'SUBMERGED',
    13: 'DOCKED',
    14: 'UNDOCKED',

    15: 'DCO_REPORT',
    16: 'DCO_SYNC',

    17: 'TIME_SRC',
    18: 'IMG_MGR',
    19: 'TIME_SKEW',

    20: 'SD_ON',
    21: 'SD_OFF',
    22: 'SD_REQ',
    23: 'SD_REL',
    24: 'RADIO_MODE',

    25: 'GPS_CYCLE_NONE',
    26: 'GPS_PIPE_STALL',
    27: 'GPS_WAKEUP',
    28: 'GPS_BOOT_SLEEP',
    29: 'GPS_CYCLE_START',
    30: 'GPS_CYCLE_END',
    31: 'GPS_DELTA',
    32: 'GPS_BOOT',
    33: 'GPS_BOOT_TIME',
    34: 'GPS_BOOT_FAIL',

    36: 'GPS_MON_MAJOR',

    37: 'GPS_RX_ERR',
    38: 'GPS_LOST_INT',
    39: 'GPS_MSG_OFF',

    41: 'GPS_CMD',
    42: 'GPS_RAW_TX',
    44: 'GPS_CANNED',

    45: 'GPS_HW_CONFIG',
    46: 'GPS_RECONFIG',

    47: 'GPS_TURN_ON',
    48: 'GPS_STANDBY',
    49: 'GPS_TURN_OFF',

    52: 'GPS_TX_RESTART',
    54: 'GPS_ACK',
    55: 'GPS_NACK',
    56: 'GPS_NO_ACK',

    64: 'GPS_FAST',
    65: 'GPS_FIRST',
    69: 'GPS_PWR_OFF',
    70: 'GPS_SATS',
}

PANIC_WARN    = 1
FAULT         = 2
GPS_CYCLE_LTFF= 6
GPS_FIRST_FIX = 7
DCO_REPORT    = 15
DCO_SYNC      = 16
TIME_SRC      = 17
IMG_MGR       = 18
TIME_SKEW     = 19
SD_ON         = 20
SD_OFF        = 21
SD_REQ        = 22
SD_REL        = 23
RADIO_MODE    = 24
GPS_CYCLE_NONE= 25
GPS_PIPE_STALL= 26
GPS_WAKEUP    = 27
GPS_BOOT_SLEEP  = 28
GPS_CYCLE_START = 29
GPS_CYCLE_END = 30
GPS_DELTA     = 31
GPS_BOOT      = 32
GPS_BOOT_TIME = 33
GPS_BOOT_FAIL = 34
GPS_MON_MAJOR = 36
GPS_RX_ERR    = 37
GPS_LOST_INT  = 38
GPS_MSG_OFF   = 39
GPS_CMD       = 41
GPS_RAW_TX    = 42
GPS_CANNED    = 44
GPS_TURN_ON   = 47
GPS_STANDBY   = 48
GPS_TURN_OFF  = 49
GPS_TX_RESTART= 52
GPS_ACK       = 54
GPS_NACK      = 55
GPS_NO_ACK    = 56
GPS_FAST      = 64
GPS_FIRST     = 65
GPS_PWR_OFF   = 69
GPS_SATS      = 70


def event_name(event):
    return event_names.get(event, 'ev/' + str(event))


radio_major_names = {
    0:  'shutdown',
    1:  'home',
    2:  'near',
    3:  'lost',
}


def radio_major_name(mode):
    return radio_major_names.get(mode, 'major/' + str(mode))


radio_minor_names = {
    0:  'none',
    1:  'recvWait',
    2:  'recv',
    3:  'stbyWait',
    4:  'standby',
}

def radio_minor_name(mode):
    return radio_minor_names.get(mode, 'minor/' + str(mode))
