# Copyright (c) 2019-2020 Eric B. Decker
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

__version__ = '0.4.7.dev0'

__all__ = [
    'SNS_NAME',
    'SNS_OBJECT',
    'SNS_DECODER',
    'SNS_VAL_STR',
    'SNS_DICT',
    'SNS_EMITTERS',
    'SNS_MR_EMITTER',
    'SNS_OBJ_NAME',

    'sns_name',
    'sns_val_str',
    'sns_dict',
]


# the sns_table holds vectors for how to decode sensor data.
# each entry is keyed by dt_sns_id from the record and contains
# a 7-tuple that includes:
#
#   0: name         sensor name (string)
#   1: object       sensor data object
#   2: decoder      sensor decoder, buf -> object
#   3: val_str      sensor object value(s) to string, for display
#   4: dict         returns a dictionary describing the sensor
#   5: emitter      emitter list, output routines to call
#   6: obj name     string object name for sanity

sns_table = {}
sns_count = {}

SNS_NAME        = 0
SNS_OBJECT      = 1
SNS_DECODER     = 2
SNS_VAL_STR     = 3
SNS_DICT        = 4
SNS_EMITTERS    = 5
SNS_MR_EMITTER  = 6
SNS_OBJ_NAME    = 7


def sns_str_empty(obj, level=0):
    return ''

def sns_name(dt_sns_id):
    v = sns_table.get(dt_sns_id, ('sns/' + str(dt_sns_id), None, None, None,
                                  None, None))
    return v[SNS_NAME]


def sns_val_str(dt_sns_id, level = 0):
    v = sns_table.get(dt_sns_id, ('noSns', None, None, sns_str_empty,
                                  None, None))
    return v[SNS_VAL_STR](v[SNS_OBJECT], level)


# sns_dict: return function to generate a dictionary describing the sensor
#
# A sensor dict is used when generating machine readable output.  Using the
# dictionary, an output line is generated that contains every element from
# the dictionary.
#
# If verbose is selected the output is expanded and includes a header that
# labels each column.  The column names come from the keys in the dictionary.
# This is intended for humans checking the machine readable output.
#
def sns_dict(dt_sns_id):
    v = sns_table.get(dt_sns_id, ('noSns', None, None, None, None, None))
    return v[SNS_DICT]
