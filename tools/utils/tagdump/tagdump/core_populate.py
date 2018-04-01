'''assign decoders and emitters for core data types'''

from   dt_defs       import *
import dt_defs       as     dtd
from   core_decoders import *
from   core_emitters import *
from   core_headers  import *

def decode_default(level, offset, buf, obj):
    return obj.set(buf)

#                                      120 = sizeof(reboot record) + sizeof(owcb)
dtd.dt_records[DT_REBOOT]           = (120, decode_reboot,  [ emit_reboot ],      dt_reboot_obj,    "REBOOT",       'dt_reboot_obj')
#                                      168 = sizeof(version record) + sizeof(image_info)
dtd.dt_records[DT_VERSION]          = (168, decode_version, [ emit_version ],     dt_version_obj,   "VERSION",      'dt_version_obj')
dtd.dt_records[DT_SYNC]             = ( 28, decode_default, [ emit_sync ],        dt_sync_obj,      "SYNC",         'dt_sync_obj')
dtd.dt_records[DT_EVENT]            = ( 40, decode_default, [ emit_event ],       dt_event_obj,     "EVENT",        'dt_event_obj')
dtd.dt_records[DT_DEBUG]            = (  0, decode_default, [ emit_debug ],       dt_debug_obj,     "DEBUG",        'dt_debug_obj')
dtd.dt_records[DT_GPS_VERSION]      = (  0, decode_default, [ emit_gps_version ], dt_gps_ver_obj,   "GPS_VERSION",  'dt_gps_ver_obj')
dtd.dt_records[DT_GPS_TIME]         = (  0, decode_default, [ emit_gps_time ],    dt_gps_time_obj,  "GPS_TIME",     'dt_gps_time_obj')
dtd.dt_records[DT_GPS_GEO]          = (  0, decode_default, [ emit_gps_geo ],     dt_gps_geo_obj,   "GPS_GEO",      'dt_gps_geo_obj')
dtd.dt_records[DT_GPS_XYZ]          = (  0, decode_default, [ emit_gps_xyz ],     dt_gps_xyz_obj,   "GPS_XYZ",      'dt_gps_xyz_obj')
dtd.dt_records[DT_SENSOR_DATA]      = (  0, decode_default, [ emit_sensor_data ], dt_sen_data_obj,  "SENSOR_DATA",  'dt_sen_data_obj')
dtd.dt_records[DT_SENSOR_SET]       = (  0, decode_default, [ emit_sensor_set ],  dt_sen_set_obj,   "SENSOR_SET",   'dt_sen_set_obj')
dtd.dt_records[DT_TEST]             = (  0, decode_default, [ emit_test ],        dt_test_obj,      "TEST",         'dt_test_obj')
dtd.dt_records[DT_NOTE]             = (  0, decode_default, [ emit_note ],        dt_note_obj,      "NOTE",         'dt_note_obj')
dtd.dt_records[DT_CONFIG]           = (  0, decode_default, [ emit_config ],      dt_config_obj,    "CONFIG",       'dt_config_obj')
dtd.dt_records[DT_GPS_RAW_SIRFBIN]  = (  0, decode_gps_raw, [ emit_gps_raw ],     dt_gps_raw_obj,   "GPS_RAW",      'dt_gps_raw_obj')
