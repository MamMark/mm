'''assign decoders and emitters for core data types'''

from   dt_defs       import *
import dt_defs       as     dtd
from   core_headers  import *
from   core_emitters import *

def decode_default(level, offset, buf, obj):
    return obj.set(buf)

#                                      152 = sizeof(reboot record) + sizeof(owcb) (36 + 116)
dtd.dt_records[DT_REBOOT]           = (152, decode_default, [ emit_reboot ],      obj_dt_reboot(),    'REBOOT',       'obj_dt_reboot'   )
#                                      376 = sizeof(version record) + sizeof(image_info)  (24 + 32 + 2 + 318)
dtd.dt_records[DT_VERSION]          = (376, decode_default, [ emit_version ],     obj_dt_version(),   'VERSION',      'obj_dt_version'  )
dtd.dt_records[DT_SYNC]             = ( 28, decode_default, [ emit_sync ],        obj_dt_sync(),      'SYNC',         'obj_dt_sync'     )
dtd.dt_records[DT_EVENT]            = ( 40, decode_default, [ emit_event ],       obj_dt_event(),     'EVENT',        'obj_dt_event'    )
dtd.dt_records[DT_DEBUG]            = (  0, decode_default, [ emit_debug ],       obj_dt_debug(),     'DEBUG',        'obj_dt_debug'    )
dtd.dt_records[DT_SYNC_FLUSH]       = ( 28, decode_default, [ emit_sync ],        obj_dt_sync(),      'SYNC/F',       'obj_dt_sync'     )
dtd.dt_records[DT_GPS_VERSION]      = (  0, decode_default, [ emit_gps_version ], obj_dt_gps_ver(),   'GPS_VERSION',  'obj_dt_gps_ver'  )
dtd.dt_records[DT_GPS_TIME]         = (  0, decode_default, [ emit_gps_time ],    obj_dt_gps_time(),  'GPS_TIME',     'obj_dt_gps_time' )
dtd.dt_records[DT_GPS_GEO]          = (  0, decode_default, [ emit_gps_geo ],     obj_dt_gps_geo(),   'GPS_GEO',      'obj_dt_gps_geo'  )
dtd.dt_records[DT_GPS_XYZ]          = (  0, decode_default, [ emit_gps_xyz ],     obj_dt_gps_xyz(),   'GPS_XYZ',      'obj_dt_gps_xyz'  )
dtd.dt_records[DT_SENSOR_DATA]      = (  0, decode_default, [ emit_sensor_data ], obj_dt_sen_data(),  'SENSOR_DATA',  'obj_dt_sen_data' )
dtd.dt_records[DT_SENSOR_SET]       = (  0, decode_default, [ emit_sensor_set ],  obj_dt_sen_set(),   'SENSOR_SET',   'obj_dt_sen_set'  )
dtd.dt_records[DT_TEST]             = (  0, decode_default, [ emit_test ],        obj_dt_test(),      'TEST',         'obj_dt_test'     )
dtd.dt_records[DT_NOTE]             = (  0, decode_default, [ emit_note ],        obj_dt_note(),      'NOTE',         'obj_dt_note'     )
dtd.dt_records[DT_CONFIG]           = (  0, decode_default, [ emit_config ],      obj_dt_config(),    'CONFIG',       'obj_dt_config'   )
dtd.dt_records[DT_GPS_PROTO_STATS]  = (  0, decode_default, [ emit_gps_proto_stats ],
                                                                            obj_dt_gps_proto_stats(), 'GPS_STATS',    'obj_dt_gps_proto_stats' )

dtd.dt_records[DT_GPS_RAW_SIRFBIN]  = (  0, decode_gps_raw, [ emit_gps_raw ],     obj_dt_gps_raw(),   'GPS_RAW',      'obj_dt_gps_raw'  )
dtd.dt_records[DT_TAGNET]           = (  0, decode_default, [ emit_tagnet ],      obj_dt_tagnet(),    'TAGNET',       'obj_dt_tagnet'   )
