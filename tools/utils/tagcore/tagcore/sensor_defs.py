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

'''
basic definitions for sensors.
'''

from   __future__   import print_function

__version__ = '0.4.5.rc97.dev0'

__all__ = [
    'SNS_NAME',
    'SNS_OBJECT',
    'SNS_DECODER',
    'SNS_VAL_STR',
    'SNS_EMITTERS',
    'SNS_OBJ_NAME',

    'SNS_ID_NONE',
    'SNS_ID_BATT',
    'SNS_ID_TEMP_PX',
    'SNS_ID_SAL',
    'SNS_ID_ACCEL',
    'SNS_ID_GYRO',
    'SND_ID_MAG',
    'SNS_ID_GPS',
    'SNS_ID_PTEMP',
    'SNS_ID_PRESS',
    'SNS_ID_SPEED',

    'sns_name',
    'sns_val_str',
]


# the sns_table holds vectors for how to decode sensor data.
# each entry is keyed by sns_id from the record and contains
# a 5-tuple that includes:
#
#   0: name         sensor name (string)
#   1: object       sensor data object
#   2: decoder      sensor decoder, buf -> object
#   3: val_str      sensor object value(s) to string, for display
#   4: emitter      emitter list, output routines to call
#   5: obj name     string object name for sanity

sns_table = {}
sns_count = {}

SNS_NAME     = 0
SNS_OBJECT   = 1
SNS_DECODER  = 2
SNS_VAL_STR  = 3
SNS_EMITTERS = 4
SNS_OBJ_NAME = 5


# Sensor data format Ids.  Must match tos/mm/sensor_ids.h

SNS_ID_NONE     = 0     # used for other data stream stuff
SNS_ID_BATT     = 1     # Battery Sensor
SNS_ID_TEMP_PX  = 2     # Temperature Sensor, Platform/External
SNS_ID_SAL      = 3     # Salinity sensor (one, two)
SNS_ID_ACCEL    = 4     # Accelerometer (x,y,z)
SNS_ID_GYRO     = 5     # Gyro
SND_ID_MAG      = 6     # Magnetometer (x, y, z)
SNS_ID_GPS      = 7     # GPS?
SNS_ID_PTEMP    = 8     # Temperature sensor
SNS_ID_PRESS    = 9     # Pressure (temp, pressure)
SNS_ID_SPEED    = 10    # Velocity (x,y)


def sns_str_empty(obj):
    return ''

def sns_name(sns_id):
    v = sns_table.get(sns_id, ('sns/' + str(sns_id), None, None, None, None, None))
    return v[SNS_NAME]


def sns_val_str(sns_id, level = 0):
    v = sns_table.get(sns_id, ('noSns', None, None, sns_str_empty, None, None))
    return v[SNS_VAL_STR](v[SNS_OBJECT], level)
