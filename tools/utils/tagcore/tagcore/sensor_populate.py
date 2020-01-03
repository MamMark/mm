'''assign decoders and emitters for sirfbin mids'''

import sensor_defs     as     sensor
from   sensor_defs     import sns_str_empty
from   sensor_headers  import *
from   sensor_emitters import *

def decode_default(level, offset, buf, obj):
    return obj.set(buf)

def decode_null(level, offset, buf, obj):
    return 0

# 2nd level dispatch, Sensors by sensor id.
#
# SNS_DICT: a function that returns an mr_cit to denote what mr_display should add for this record.
#
# A display is generated using the following rules:
# If SNS_DICT is not None, use this function to build an mr_dict.  (SNS_EMITTER should be None)
# If SNS_DICT is None, then use emitter (SNS_MR_EMITTER) to generate the output.
#
#                         SNS_NAME    SNS_OBJECT      SNS_DECODER     SNS_STRING       SNS_DICT           SNS_EMITTERS       SNS_MR_EMITTER    SNS_OBJ_NAME
sensor.sns_table[2]   = ('TMP_PX',    obj_tmp_px(),   decode_default, sns_str_tmp_px,  sns_dict_tmp_px,   None,              None,            'obj_tmp_px')

# other sensors, just define their names.  no decoders, no strings, no dicts
sensor.sns_table[0]   = ('NONE',      None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[1]   = ('BATT',      None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[3]   = ('SAL',       None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[4]   = ('ACCEL',     None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[5]   = ('GYRO',      None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[6]   = ('MAG',       None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[7]   = ('GPS',       None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[8]   = ('PTEMP',     None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[9]   = ('PRESS',     None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[10]  = ('SPEED',     None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[11]  = ('GPS_GEO',   None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[12]  = ('GPS_XYZ ',  None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[13]  = ('GPS_TIME',  None, decode_null, sns_str_empty, None, None, 'none')
