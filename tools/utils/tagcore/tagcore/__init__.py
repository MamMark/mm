"""
tagcore: utility and common routines for many tag things
@author:   Eric B. Decker
"""

__version__ = '0.4.6.dev13'

__all__ = [
    'CORE_REV',                         # core_rev.py
    'CORE_MINOR',                       # core_rev.py
    'buf_str',                          # misc_utils.py
    'dump_buf',
    'obj_dt_hdr',                       # core_header.py
]

from    .core_rev       import CORE_REV
from    .core_rev       import CORE_MINOR
from    .misc_utils     import buf_str, dump_buf
from    .core_headers   import obj_dt_hdr

# 0.4.6.dev+    CR 22/+
#       o add GPS_CYCLE_{START,END} for instrumentation
#       o clean up "all" in core_events, remove unused event exports
#       o add instrumentation for SD_REQ/REL for SD arbiter.
#       o mr_emitters, machine readable emiters for database extraction
#
#       o DT_GPS_CLK, objs and emitter
#
#       o display more detail on ee50bpsBcastEph  56/5
#       o only display gps_raw with -g4 or greater (gps_eval)
#       o update gps_time, gps_geo to include nsats
#       o update gps_xyz to include gps time x/secs100
#
#       o add gps_eval populator
#       o add gps_eval emitters for gps evaluation.
#
#       o split event names and identifiers into core_events
#
#       o put GPS_XYZ, TIME, and GEO onto data records
#       o deprecate XYZ, TIME, GEO events, tagdump displays retained for
#         backward compatbility.
#       o simplified TMP_PX display.
#       o TMP_PX should be signed.
#       o GPS_XYZ, TIME, GEO displays.
#       o add quiet switch
#       o add GPS_TRK
#       o switch gps_tracking to gps_trk
#
# 0.4.5         release 0.4.5, CR: 21/100
#
# 0.4.5.rc97
#               decouple sensor id from regime index
#               make sensor id global and unique
#               add sensor_headers (decoders and objects)
#               add sensor_emitters, sensor_populate, sensor_defs
#               add details to sensor_data object (headers)
#               simple sensor_data emitter.
#               decode for tmp_px composite sensor.
#
# 0.4.5.rc96
#               add --noexport to override database export.
#               accept multiple influx versions, 1.5.2, 1.7.0
# 0.4.5.rc95    CR: 21/95 GPS change MPM to LPM (low power mode).
# 0.4.5.rc93    CR: 21/93 add TIME_SKEW event for CoreRtc.syncSetTime.
# 0.4.5.rc92    CR: 21/92 hdr_crc8 kludge, doesn't include recsum.
# 0.4.5.rc91    CR: 21/91 remove sync info from reboot (not a sync).
# 0.4.5.rc90    CR: 21/90 add hdr_crc8
# 0.4.5rc11     CR: 21/2
#               support for remote logging (21/2)
#               pwr force off linkages     (21/1)
#               GPS_PWR_OFF event
#               add panic_info back into panic_info_t (panic)
#               image manager event decode
#               rtc_src
#               imageinfo repr, display version/hw_ver in right order
#               add DCO_REPORT and DCO_SYNC
#               revised image_info structure (split basic/plus)
#               revise panic data structures.
#               fix reboot size
#               updated overwatch_control_block
#               - protection status
#               - updated fault flags
# 0.3.3.dev4
#       19/9    CoreRev: 19/9
#               make mpm responses log EVENT_MPM_RSP.
#       19/6    tagctl: major state control of TagnetMonitor
#               better 'unk' display
#               gps_cmds: add 'cycle' and 'state'
#               GPS_FIRST_LOCK, GPS_TX_RESTART events
#       19/4    Sync Flush (SYNC/F)
#               OverWatch: panic_count and panic_gold
#                 persistant logging_flags
#               updated OverWatch data, add PanicCnt, reorganize
#               simple DT_TAGNET decoder
# 0.3.2         Core_Rev 19/0
#               reorder EVENTS, core_rev 19/0
#               revised gps monitor state machine (v1)
#               Event GPS_MSG_OFF
#               collapse CANNED (add factory resets/clear)
#               add navlib decoders/emitters (28, 29, 30, 31 and 64/2)
#               refactor ee56, ee232, and add nl64 decoders into sid_dispatch
#               export core_ver
#
# 0.3.1         pull TagFile into tagcore
#               add gps_cmds and canned messages as gps_cmds.py
#               convert rtctime into basic rtctime_str.
#               add print_hourly
#               base_objs, add notset, runtime error for bad object
#
# 0.3.0         pull core objects from tagdump into tagcore
