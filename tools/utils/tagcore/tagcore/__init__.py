"""
tagcore: utility and common routines for many tag things
@author:   Eric B. Decker
"""

__version__ = '0.4.8.dev1'

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
