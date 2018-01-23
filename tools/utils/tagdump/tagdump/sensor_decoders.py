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
# Contact: Daniel J. Maltbie <dmaltbie@daloma.org>
#          Eric B. Decker <cire831@gmail.com>

# sensor data blocks decoders

import globals        as     g
from   core_records   import *
from   sensor_headers import *

def decode_sensor_data(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_SENSOR_DATA] = \
        (0, decode_sensor_data, dt_sen_data_obj, "SENSOR_DATA")


def decode_sensor_set(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_SENSOR_SET] = \
        (0, decode_sensor_set, dt_sen_set_obj, "SENSOR_SET")
