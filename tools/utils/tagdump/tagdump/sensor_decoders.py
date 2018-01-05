#
# Copyright (c) 2018 Eric B. Decker
# All rights reserved.
#
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
