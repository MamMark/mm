"""
tagcore: utility and common routines for many tag things
@author:   Eric B. Decker
"""

__version__ = '0.3.1.dev1'

__all__ = [
    'CORE_REV',                         # core_rev.py

    'buf_str',                          # misc_utils.py
    'dump_buf',

    'dt_name',                          # dt_defs.py
    'dump_hdr',
    'print_hdr_obj',

    'dt_hdr_obj',                       # core_header.py
]

from    .core_rev       import CORE_REV
from    .dt_defs        import dt_name, dump_hdr, print_hdr_obj
from    .misc_utils     import buf_str, dump_buf
from    .core_headers   import dt_hdr_obj

# 0.3.1         pull TagFile into tagcore
#               add gps_cmds and canned messages as gps_cmds.py
#      .dev1    convert rtctime into basic rtctime_str.
#
# 0.3.0         pull core objects from tagdump into tagcore
