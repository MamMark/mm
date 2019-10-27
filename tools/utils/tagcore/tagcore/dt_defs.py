# Copyright (c) 2018-2019 Eric B. Decker
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# See COPYING in the top level directory of this source tree.
#
# Contact: Eric B. Decker <cire831@gmail.com>

'''
data type (data block) basic definitions

define low level record manipulation and basic definitions for dblk
stream record headers.  Includes print/display routines.

Includes the following:

    - dt_records.  expose dictionary of data_type records we understand.
    - indicies to dt_record fields
      DT_REQ_LEN, DT_DECODERS, etc.
    - dt types, DT_REBOOT, DT_VERSION, etc.

    - print/display functions

      rec0              initial record print format
      rtctime_str       convert rtctime to printable string
      print_hourly      hourly banner if boundary crossed
      dt_name           convert a dt code to its printable name
      dump_hdr          simple hdr display (from raw buffer)
      print_hdr_obj     print a dt record header given its object
'''

from   __future__   import print_function
from   datetime     import datetime
from   core_headers import obj_dt_hdr

__version__ = '0.4.5.dev4'

cfg_print_hourly = True

# __all__ exports commonly used definitions.  It gets used
# when someone does a wild import of this module.

__all__ = [
    # object identifiers in each dt_record tuple
    'DTR_REQ_LEN',
    'DTR_DECODER',
    'DTR_EMITTERS',
    'DTR_OBJ',
    'DTR_NAME',
    'DTR_OBJ_NAME',

    # dt record types
    'DT_NONE',
    'DT_REBOOT',
    'DT_VERSION',
    'DT_SYNC',
    'DT_EVENT',
    'DT_DEBUG',
    'DT_SYNC_FLUSH',
    'DT_SYNC_REBOOT',
    'DT_GPS_VERSION',
    'DT_GPS_TIME',
    'DT_GPS_GEO',
    'DT_GPS_XYZ',
    'DT_SENSOR_DATA',
    'DT_SENSOR_SET',
    'DT_TEST',
    'DT_NOTE',
    'DT_CONFIG',
    'DT_GPS_PROTO_STATS',
    'DT_GPS_TRK',
    'DT_GPS_CLK',
    'DT_GPS_RAW_SIRFBIN',
    'DT_TAGNET',

    'rec0',
    'rtctime_str',
    'print_hourly',
    'dt_name',
    'dump_hdr',
    'print_hdr_obj',
    'dt_records',
    'dt_count',
    'dt_sync_majik',
]


# dt_records
#
# dictionary of all data_typed records we understand dict key is the
# record id (rtype).  Contents of each entry is a vector consisting of
# (req_len, decoder, object, name).
#
# req_len: required length if any.  0 if variable and not checked.
# decoder: a pointer to a routne that knows how to decode and display
#          the record
# object:  a pointer to an object descriptor for this record.
# name:    a string denoting the printable name for this record.
#
#
# when decoder code is imported, it is required to populate its entry
# in the dt_records dictionary.  Each decode is required to know its
# key and uses that to insert its vector (req_len. decode, obj, name)
# into the dictionary.
#
# dt_count keeps track of what rtypes we have seen.
#

dt_records = {}
dt_count   = {}

DTR_REQ_LEN  = 0                        # required length
DTR_DECODER  = 1                        # decode said rtype
DTR_EMITTERS = 2                        # emitters for said record struct
DTR_OBJ      = 3                        # rtype obj descriptor
DTR_NAME     = 4                        # rtype name
DTR_OBJ_NAME = 5                        # object name


# all dt parts are native and little endian

# headers are accessed via the dt_simple_hdr object
# hdr object dt, native, little endian

dt_sync_majik = 0xdedf00ef

DT_NONE                 = 0
DT_REBOOT               = 1
DT_VERSION              = 2
DT_SYNC                 = 3
DT_EVENT                = 4
DT_DEBUG                = 5
DT_SYNC_FLUSH           = 6
DT_SYNC_REBOOT          = 7
DT_GPS_VERSION          = 16
DT_GPS_TIME             = 17
DT_GPS_GEO              = 18
DT_GPS_XYZ              = 19
DT_SENSOR_DATA          = 20
DT_SENSOR_SET           = 21
DT_TEST                 = 22
DT_NOTE                 = 23
DT_CONFIG		= 24
DT_GPS_PROTO_STATS      = 25
DT_GPS_TRK              = 26
DT_GPS_CLK              = 27

DT_GPS_RAW_SIRFBIN      = 32
DT_TAGNET               = 33
DT_RADIO                = 34


# offset    recnum     rtime    len   dt name         offset
# 99999999 9999999  3599.999969 999   99 xxxxxxxxxxxx @999999 (0xffffff) [0xffff]
rec_title_str = "---  offset    recnum    rtime    len  dt  name"

# common format used by all records.  (rec0)
# ---  offset    recnum    rtime    len  dt  name
# ---                      0.000000 2018/5/17 17:00 (Thu)
# --- @99999999 9999999 3599.999969 999  99  ssssss
# --- @512            1 1099.105926 120   1  REBOOT  unset -> GOLD  [GOLD]  (r 3/0 p)

rec0  = '--- @{:<8d} {:7d} {:>11s} {:3d}  {:2d}  {:s}'


def rtctime_str(rtctime, fmt = 'basic'):
    '''
    convert a rtctime into a simple 'basic' string displaying the time
    as seconds.us since the top of the hour.

    input:      rtctime, a rtctime_obj
    output:     string seconds.us since the top of the hour

    ie. Thu 17 May 00:04:29 UTC 2018 9589 jiffies
        2018-05-17-(4)-00:04:29.9589j is displayed as '269.292633'

        269.292633      2018-05-17-(4)-00:04:29.9589j  (0x2575
        298.999969      2018-05-17-(4)-00:04:58.32767j (0x7fff)
        299.000000      2018-05-17-(4)-00:04:59.0j     (0x0000)
        299.999969      2018-05-17-(4)-00:04:59.32767j (0x7fff)
        300.000000      2018-05-17-(4)-00:05:00.0j     (0x0000)
       3599.999969      2018-05-17-(4)-00:59:59.32767j (0x7fff)
          0.000000      2018-05-17-(4)-01:00:00.0      (0x0000)

    the rtctime object must be set prior to calling get_basic_rt.
    '''
    rt = rtctime
    rt_secs  = rt['min'].val * 60 + rt['sec'].val
    rt_subsecs = (rt['sub_sec'].val * 1000000) / 32768
    return '{:d}.{:06d}'.format(rt_secs, rt_subsecs)

def rtctime_iso(rtctime):
    '''
    convert a rtctime into an ISO-8601 formatted string displaying the time.
    '''
    return datetime(rtctime['year'].val,
                     rtctime['mon'].val,
                     rtctime['day'].val,
                     rtctime['hr'].val,
                     rtctime['min'].val,
                     rtctime['sec'].val,
                     (rtctime['sub_sec'].val * 1000000) / 32768,
                    ).isoformat()


def rtctime_full(rtctime, pretty=1):
    '''
    convert a rtctime into a full ISO-8601 formatted string displaying the time.
    Full means all digits are spaced out.
    '''
    fmt_str = '%Y/%m/%dT%H:%M:%S.%f' if pretty else \
              '%Y%m%dT%H%M%S.%f'
    return datetime(rtctime['year'].val,
                     rtctime['mon'].val,
                     rtctime['day'].val,
                     rtctime['hr'].val,
                     rtctime['min'].val,
                     rtctime['sec'].val,
                     (rtctime['sub_sec'].val * 1000000) / 32768,
                    ).strftime(fmt_str)


last_rt = {'year': 0, 'mon': 0, 'day': 0, 'hr': 0}

def set_last(rt):
    last_rt['hr']   = rt['hr'].val
    last_rt['day']  = rt['day'].val
    last_rt['mon']  = rt['mon'].val
    last_rt['year'] = rt['year'].val


def print_hourly(rtctime):
    '''print an hourly banner if a hour boundary has been crossed.

    check to see if an hourly boundary has been crossed since the
    last time we checked.  If so print out a hour banner.

    ---                      0.000000 2018/5/17 17:00 (Thu)
    '''

    if not cfg_print_hourly: return
    rt      = rtctime
    lrt     = last_rt
    pstamp  = False
    if rt['hr'  ].val != lrt['hr'  ]: pstamp = True
    if rt['day' ].val != lrt['day' ]: pstamp = True
    if rt['mon' ].val != lrt['mon' ]: pstamp = True
    if rt['year'].val != lrt['year']: pstamp = True
    set_last(rt)
    if pstamp:
        print('---                      '
              '0.{:06d} {}/{}/{} {}:00 ({}) UTC'.format(
            0, rt['year'], rt['mon'], rt['day'], rt['hr'], rt['dow']))


def dt_name(rtype):
    v = dt_records.get(rtype, (0, None, None, None, 'dt/' + str(rtype)))
    return v[DTR_NAME]


# header format when normal processing doesn't work (see print_record)
hdr_format    = "{}@{:<8d} {:7d} {:>11s} {:<3d}  {:2d}  {:12s} @{} (0x{:06x}) [0x{:04x}]"
hdr_additonal = ' @{} (0x{:06x}) [0x{:04x}]'

dt_hdr = obj_dt_hdr()

def dump_hdr(offset, buf, pre = ''):
    '''load hdr from buf and display it.
    Will need to change for CR 22/0

    return:     True if we can load the header
                False if buffer is too short.
    '''

    hdr = dt_hdr
    hdr_len = len(hdr)
    if (len(buf) < hdr_len):
        print('*** dump_hdr: buf too small for a header, wanted {}, ' + \
              'got {}, @{}'.format(hdr_len, len(buf), offset))
        return False
    hdr.set(buf)
    rlen     = hdr['len'].val
    rtype    = hdr['type'].val
    recnum   = hdr['recnum'].val
    rtctime  = hdr['rt']
    brt      = rtctime_str(rtctime)
    recsum   = hdr['recsum'].val
    print(hdr_format.format(pre, offset, recnum, brt, rlen, rtype,
        dt_name(rtype), offset, offset, recsum))
    return True


def print_hdr_obj(obj):
    rtype    = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    rtctime  = obj['hdr']['rt']
    brt      = rtctime_str(rtctime)
    print('{:4} {:>11} ({:2}) {:6} --'.format(recnum, brt,
        rtype, dt_name(rtype)), end = '')
