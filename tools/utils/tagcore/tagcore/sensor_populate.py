'''assign decoders and emitters for sirfbin mids'''

from   dt_defs         import *
from   sensor_headers  import *
from   sensor_emitters import *
import sensor_defs     as     sensor
from   sensor_defs     import sns_str_empty

def decode_default(level, offset, buf, obj):
    return obj.set(buf)

def decode_null(level, offset, buf, obj):
    return 0

# 2nd level dispatch, Sensors by sensor id.
#
# SNS_DICT: a function that returns a mr_dict.  This dictionary provides information about
#           additional fields to dsipaly for the current record.
#
# A display is generated using the following rules:
#
# If SNS_DICT is not None, use this function to build an mr_dict.  (SNS_EMITTER should be None)
# If SNS_DICT is None, then use emitter (SNS_MR_EMITTER) to generate the output.
#
#                                       SNS_NAME     SNS_OBJECT      SNS_DECODER      SNS_STRING       SNS_DICT           SNS_EMITTERS       SNS_MR_EMITTER    SNS_OBJ_NAME
sensor.sns_table[DT_SNS_TMP_PX]     = ('TMP_PX',     obj_tmp_px(),   decode_default,  sns_str_tmp_px,  sns_dict_tmp_px,   None,              None,            'obj_tmp_px')
sensor.sns_table[DT_SNS_ACCEL_N8S]  = ('ACCELn8s',   obj_nsample(),  decode_acceln8s, sns_str_acceln,  None,              [ emit_acceln ],   emit_acceln_mr,  'obj_nsample')

# other sensors, just define their names.  no decoders, no strings, no dicts
sensor.sns_table[DT_SNS_NONE]       = ('NONE',       None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[DT_SNS_BATT]       = ('BATT',       None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[DT_SNS_SAL]        = ('SAL',        None, decode_null, sns_str_empty, None, None, 'none')

sensor.sns_table[DT_SNS_ACCEL_N10S] = ('ACCELn10s',  None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[DT_SNS_ACCEL_N12S] = ('ACCELn12s',  None, decode_null, sns_str_empty, None, None, 'none')

sensor.sns_table[DT_SNS_GYRO_N]     = ('GYROn',      None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[DT_SNS_MAG_N]      = ('MAGn',       None, decode_null, sns_str_empty, None, None, 'none')

sensor.sns_table[DT_SNS_PTEMP]      = ('PTEMP',      None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[DT_SNS_PRESS]      = ('PRESS',      None, decode_null, sns_str_empty, None, None, 'none')
sensor.sns_table[DT_SNS_SPEED]      = ('SPEED',      None, decode_null, sns_str_empty, None, None, 'none')
