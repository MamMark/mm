# Copyright (c) 2019 Eric B. Decker
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
#
# implementation of gps_eval emitters
# enable with -g<n>, --gps_eval <n>
#
# -g0: summary display
# -g1: gps major state, gps boot
# -g2: gps_trk basic
# -g3: gps_trk expanded/geo, xyz, time details
# -g4: gps sats (2, 7, 41), gps_raw
# -g5: gps minor state changes
# -g9: display all

'''core emitters for gps_eval'''

from   __future__         import print_function

__version__ = '0.4.6.dev3'

from   .globals    import gps_level     # emit level, will be numeric
from   core_events import *             # get event identifiers
import core_emitters


# gps events we want to display
gps_events = {
    PANIC_WARN:     0,
    EV_GPS_GEO:     0,
    EV_GPS_XYZ:     0,
    EV_GPS_TIME:    0,
    GPS_LTFF_TIME:  0,
    GPS_FIRST_LOCK: 0,
    GPS_LOCK:       0,
    TIME_SRC:       0,
    TIME_SKEW:      0,
    GPS_BOOT:       1,
    GPS_BOOT_TIME:  1,
    GPS_BOOT_FAIL:  0,
    GPS_MON_MINOR:  5,
    GPS_MON_MAJOR:  1,
    GPS_RX_ERR:     0,
    GPS_LOST_INT:   0,
    GPS_CMD:        0,
    GPS_TURN_ON:    9,
    GPS_STANDBY:    9,
    GPS_TURN_OFF:   9,
    GPS_MPM:        9,
    GPS_MPM_RSP:    9,
    GPS_FIRST:      9,
    GPS_SATS2:      4,
    GPS_SATS7:      4,
    GPS_SATS41:     4,
}


def emit_event_ge(level, offset, buf, obj):
    event = obj['event'].val
    event_level = gps_events.get(event)
    if event_level == None or event_level > gps_level:
        return
    core_emitters.emit_event(level, offset, buf, obj)


def emit_gps_geo_ge(level, offset, buf, obj):
    if level == 0 and gps_level > 2:
        level = 1
    core_emitters.emit_gps_geo(level, offset, buf, obj)


def emit_gps_xyz_ge(level, offset, buf, obj):
    if level == 0 and gps_level > 2:
        level = 1
    core_emitters.emit_gps_xyz(level, offset, buf, obj)


def emit_gps_trk_ge(level, offset, buf, obj):
    if gps_level < 2:
        return
    if level == 0 and gps_level > 2:
        level = 1
    core_emitters.emit_gps_trk(level, offset, buf, obj)


def emit_gps_raw_ge(level, offset, buf, obj):
    core_emitters.emit_gps_raw(level, offset, buf, obj)
