"""
sirfdump:  decode and display sirfbin messages
@author:   Eric B. Decker
"""

# 0.3.0         pull core objects from tagdump into tagcore

__version__ = '0.3.0.dev0'

__all__ = [
    'CORE_REV',                         # core_rev.py

    'buf_str',                          # misc_utils.py
    'dump_buf',

    'dt_name',                          # dt_defs.py
    'print_hdr',
    'print_record',

    'dt_hdr_obj',                       # core_header.py

    'base_ver',                         # base_objs version
    'dt_ver',                           # dt_defs version
    'sd_ver',                           # from various modules
    'se_ver',
    'sh_ver',
    'ce_ver',
    'ch_ver',
]

from    .core_rev       import *
from    .misc_utils     import *
from    .dt_defs        import *
from    .core_headers   import dt_hdr_obj

from    .base_objs      import __version__   as base_ver
from    .dt_defs        import __version__   as dt_ver
from    .core_emitters  import __version__   as ce_ver
from    .core_headers   import __version__   as ch_ver
from    .sirf_defs      import __version__   as sd_ver
from    .sirf_emitters  import __version__   as se_ver
from    .sirf_headers   import __version__   as sh_ver
