"""
tagcore: utility and common routines for many tag things
@author:   Eric B. Decker
"""

__version__ = '0.3.3.dev0'

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
