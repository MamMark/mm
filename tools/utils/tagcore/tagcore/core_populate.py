'''assign decoders and emitters for core data types'''

from   dt_defs       import *
import dt_defs       as     dtd
from   core_headers  import *
from   core_emitters import *
from   json_emitters import emit_influx

def decode_default(level, offset, buf, obj):
    return obj.set(buf)

def decode_null(level, offset, buf, obj):
    return 0

#                                      156 = sizeof(reboot record) + sizeof(owcb) (36 + 120)
dtd.dt_records[DT_REBOOT]           = (156, decode_default, [ emit_reboot, emit_influx ],           obj_dt_reboot(),          'REBOOT',       'obj_dt_reboot'   )
#                                      356 = sizeof(version record) + sizeof(image_info)  (24 + 332)
dtd.dt_records[DT_VERSION]          = (356, decode_default, [ emit_version, emit_influx ],          obj_dt_version(),         'VERSION',      'obj_dt_version'  )
dtd.dt_records[DT_SYNC]             = ( 28, decode_default, [ emit_sync, emit_influx ],             obj_dt_sync(),            'SYNC',         'obj_dt_sync'     )
dtd.dt_records[DT_EVENT]            = ( 40, decode_default, [ emit_event, emit_influx ],            obj_dt_event(),           'EVENT',        'obj_dt_event'    )
dtd.dt_records[DT_DEBUG]            = (  0, decode_default, [ emit_debug, emit_influx ],            obj_dt_debug(),           'DEBUG',        'obj_dt_debug'    )
dtd.dt_records[DT_SYNC_FLUSH]       = ( 28, decode_default, [ emit_sync, emit_influx ],             obj_dt_sync(),            'SYNC/F',       'obj_dt_sync'     )
dtd.dt_records[DT_SYNC_REBOOT]      = ( 28, decode_default, [ emit_sync, emit_influx ],             obj_dt_sync(),            'SYNC/R',       'obj_dt_sync'     )

dtd.dt_records[DT_GPS_RAW]          = (  0, decode_gps_raw, [ emit_gps_raw, emit_influx ],          obj_dt_gps_raw(),         'GPS_RAW',      'obj_dt_gps_raw'  )
dtd.dt_records[DT_TAGNET]           = (  0, decode_default, [ emit_tagnet,  emit_influx ],          obj_dt_tagnet(),          'TAGNET',       'obj_dt_tagnet'   )
dtd.dt_records[DT_GPS_VERSION]      = (  0, decode_default, [ emit_gps_version, emit_influx ],      obj_dt_gps_ver(),         'GPS_VERSION',  'obj_dt_gps_ver'  )
dtd.dt_records[DT_GPS_TIME]         = (  0, decode_default, [ emit_gps_time, emit_influx ],         obj_dt_gps_time(),        'GPS_TIME',     'obj_dt_gps_time' )
dtd.dt_records[DT_GPS_GEO]          = (  0, decode_default, [ emit_gps_geo, emit_influx ],          obj_dt_gps_geo(),         'GPS_GEO',      'obj_dt_gps_geo'  )
dtd.dt_records[DT_GPS_XYZ]          = (  0, decode_default, [ emit_gps_xyz, emit_influx ],          obj_dt_gps_xyz(),         'GPS_XYZ',      'obj_dt_gps_xyz'  )
dtd.dt_records[DT_SENSOR_DATA]      = (  0, decode_sensor,  [ emit_sensor_data, emit_influx ],      obj_dt_sns_data(),        'SENSOR',       'obj_dt_sen_data' )
dtd.dt_records[DT_SENSOR_SET]       = (  0, decode_null,    [ ],                                    None,                     'SENSOR_SET',   'obj_dt_sen_set'  )
dtd.dt_records[DT_TEST]             = (  0, decode_default, [ emit_test, emit_influx ],             obj_dt_test(),            'TEST',         'obj_dt_test'     )
dtd.dt_records[DT_NOTE]             = (  0, decode_default, [ emit_note, emit_influx ],             obj_dt_note(),            'NOTE',         'obj_dt_note'     )
dtd.dt_records[DT_CONFIG]           = (  0, decode_default, [ emit_config, emit_influx ],           obj_dt_config(),          'CONFIG',       'obj_dt_config'   )
dtd.dt_records[DT_GPS_PROTO_STATS]  = (  0, decode_default, [ emit_gps_proto_stats, emit_influx ],  obj_dt_gps_proto_stats(), 'GPS_STATS',    'obj_dt_gps_proto_stats' )
dtd.dt_records[DT_GPS_TRK]          = (  0, decode_gps_trk, [ emit_gps_trk, emit_influx ],          obj_dt_gps_trk(),         'GPS_TRK',      'obj_dt_trk' )
dtd.dt_records[DT_GPS_CLK]          = (  0, decode_default, [ emit_gps_clk, emit_influx ],          obj_dt_gps_clk(),         'GPS_CLK',      'obj_dt_clk' )

dtd.dt_records[DT_SNS_TMP_PX]       = (  0, decode_sensor,  [ emit_sensor_data, emit_influx ],      obj_dt_sns_data(),        'SNS_TMP_PX',   'obj_dt_sns_data' )
dtd.dt_records[DT_SNS_ACCEL_N8S]    = (  0, decode_sensor,  [ emit_sensor_data, emit_influx ],      obj_dt_sns_data(),        'SNS_ACCELn8s', 'obj_dt_sns_data' )

dtd.dt_records[DT_SNS_NONE]         = (  0, decode_null,    [ ],                                    None,                     'SNS_NONE',     'none' )
dtd.dt_records[DT_SNS_BATT]         = (  0, decode_null,    [ ],                                    None,                     'SNS_BATT',     'none' )
dtd.dt_records[DT_SNS_SAL]          = (  0, decode_null,    [ ],                                    None,                     'SNS_SAL',      'none' )
dtd.dt_records[DT_SNS_ACCEL_N10S]   = (  0, decode_null,    [ ],                                    None,                     'SNS_ACCEL_N10S','none' )
dtd.dt_records[DT_SNS_ACCEL_N12S]   = (  0, decode_null,    [ ],                                    None,                     'SNS_ACCEL_N12S','none' )
dtd.dt_records[DT_SNS_GYRO_N]       = (  0, decode_null,    [ ],                                    None,                     'SNS_GYRO_N',   'none' )
dtd.dt_records[DT_SNS_MAG_N]        = (  0, decode_null,    [ ],                                    None,                     'SNS_MAG_N',    'none' )
dtd.dt_records[DT_SNS_PTEMP]        = (  0, decode_null,    [ ],                                    None,                     'SNS_PTEMP',    'none' )
dtd.dt_records[DT_SNS_PRESS]        = (  0, decode_null,    [ ],                                    None,                     'SNS_PRESS',    'none' )
dtd.dt_records[DT_SNS_SPEED]        = (  0, decode_null,    [ ],                                    None,                     'SNS_SPEED',    'none' )
