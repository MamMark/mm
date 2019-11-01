# Copyright (c) 2019 Eric B. Decker
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
#
# implementation of machine readable export emitters
# enable with --mr_emitters or -m
#

'''machine readable emitters'''

from   __future__         import print_function

__version__ = '0.4.6.dev4'

import copy
from   datetime       import datetime
from   collections    import OrderedDict
import pytz

from   .globals       import *
from   .core_events   import *           # get event identifiers
from   .core_emitters import *
from   .dt_defs       import rtctime_full
from   .dt_defs       import expand_datetime
from   .core_events   import event_name
from   .base_objs     import atom
from   .misc_utils    import eprint
from   sensor_defs    import *
import sensor_defs    as     sensor

# gps events we want
gps_events_keep = {
    GPS_LTFF_TIME,
    GPS_FIRST_FIX,
    DCO_REPORT,
    DCO_SYNC,
    TIME_SRC,
    TIME_SKEW,
    RADIO_MODE,
    GPS_CYCLE_START,
    GPS_CYCLE_END,
    GPS_BOOT_TIME,
}


utc_str = '%Y/%m/%dT%H:%M:%S.%f' if pretty else '%Y%m%dT%H%M%S.%f'

#          date/time offset    rec  type
basic_hdr  = '{:^26}  {:>8}  {:>8}  {:>16}'
expanded_f = '{:>26}, {:>8}, {:>8}, {:>16}'
expanded_r =', {:>12}'
compact_f  = '{},{},{},{}'
compact_r  = ',{}'

def mr_chksum_err(offset, recsum, chksum):
    front_fmt  = expanded_f if pretty else compact_f
    remain_fmt = expanded_r if pretty else compact_r
    c = { 'recsum': recsum, 'chksum': chksum }
    if debug or verbose:
        front_fmt  = expanded_f
        remain_fmt = expanded_r
        # output titles
        print(basic_hdr.format('date','offset','rec','type'), end='')
        for k in c:
            print(remain_fmt.format(k), end='')
        print()

    cur_dt = datetime.now(tz=pytz.utc)
    print(front_fmt.format(expand_datetime(cur_dt, pretty),
                           offset, 0, 'CHKSUMERR'), end='')
    for k in c:
        print(remain_fmt.format(str(c[k])), end='')
    print()

def print_basic_obj(offset, hdr, obj, type_str):
    recnum   = hdr['recnum'].val
    rtctime  = hdr['rt']
    brt      = rtctime_full(rtctime, pretty)

    front_fmt  = expanded_f if pretty else compact_f
    remain_fmt = expanded_r if pretty else compact_r
    if debug or verbose:
        print(basic_hdr.format('date','offset','rec','type'), end='')
        front_fmt  = expanded_f
        remain_fmt = expanded_r
        for k in obj:
            print(remain_fmt.format(k), end='')
        print()
    print(front_fmt.format(brt, offset, recnum, type_str), end = '')
    for k in obj:
        val = obj[k].val if (isinstance(obj[k], atom)) else obj[k]
        print(remain_fmt.format(val), end='')
    print()


def emit_default_mr(level, offset, buf, obj):
    return
    hdr = obj['hdr']
    xtype = hdr['type'].val
    c = copy.deepcopy(obj)
    del c['hdr']
    print_basic_obj(offset, hdr, c, dt_name(xtype))


def emit_event_mr(level, offset, buf, obj):
    hdr = obj['hdr']
    ev  = obj['event'].val
    if ev not in gps_events_keep:
        if debug and verbose:
            eprint('*** dumping event {}/{}'.format(ev, event_name(ev)))
        return
    c = copy.deepcopy(obj)
    del c['hdr']
    del c['event']
    del c['pcode']
    del c['w']
    print_basic_obj(offset, hdr, c, event_name(ev))


def emit_gps_time_mr(level, offset, buf, obj):
    hdr   = obj['gps_hdr']['hdr']
    xtype = hdr['type'].val
    week_x = obj['week_x'].val
    tow    = obj['tow1000'].val/1000.
    c = OrderedDict()
    secs = obj['utc_ms'].val/1000
    ms   = obj['utc_ms'].val - secs * 1000
    c['weekx'] = week_x
    c['tow']   = tow
    c['utc_time'] = datetime(obj['utc_year'].val,
                             obj['utc_month'].val,
                             obj['utc_day'].val,
                             obj['utc_hour'].val,
                             obj['utc_min'].val,
                             secs,
                             ms * 1000,
                            ).strftime(utc_str)
    print_basic_obj(offset, hdr, c, dt_name(xtype))


def emit_gps_geo_mr(level, offset, buf, obj):
    hdr    = obj['gps_hdr']['hdr']
    xtype  = hdr['type'].val
    week_x = obj['week_x'].val
    tow    = obj['tow1000'].val/1000.
    ehpe   = obj['ehpe100'].val/100.
    hdop   = obj['hdop5'].val/5.
    if debug:
        c = copy.deepcopy(obj)
        del c['gps_hdr']
        del c['capdelta']
        del c['nav_valid']
        del c['alt_ell']
        print_basic_obj(offset, hdr, c, dt_name(xtype))
    c = OrderedDict()
    c['weekx'] = week_x
    c['tow']   = tow
    c['lat']   = obj['lat'].val / 10000000.
    c['lon']   = obj['lon'].val / 10000000.
    c['msl']   = obj['alt_msl'].val/100.
    c['ehpe']  = ehpe
    c['hdop']  = hdop
    nav_type   = '0x{:04x}'.format(obj['nav_type'].val)
    c['nav_type'] =  nav_type if verbose or debug else obj['nav_type'].val
    print_basic_obj(offset, hdr, c, dt_name(xtype))


def emit_gps_xyz_mr(level, offset, buf, obj):
    hdr    = obj['gps_hdr']['hdr']
    xtype  = hdr['type'].val
    week_x = obj['week_x'].val
    tow    = obj['tow100'].val/100.
    hdop   = obj['hdop5'].val/5.
    if debug:
        c = copy.deepcopy(obj)
        del c['gps_hdr']
        del c['capdelta']
        print_basic_obj(offset, hdr, c, dt_name(xtype))
    c = OrderedDict()
    c['weekx'] = week_x
    c['tow']   = tow
    c['x']     = obj['x'].val
    c['y']     = obj['y'].val
    c['z']     = obj['z'].val
    c['hdop']  = hdop
    sats       = '0x{:04x}'.format(obj['sat_mask'].val)
    c['sats']  = sats if verbose or debug else obj['sat_mask'].val
    nav_type   = '0x{:02x}'.format(obj['m1'].val)
    c['nav_type'] =  nav_type if verbose or debug else obj['m1'].val
    print_basic_obj(offset, hdr, c, dt_name(xtype))


def emit_gps_trk_mr(level, offset, buf, obj):
    hdr    = obj['gps_hdr']['hdr']
    xtype  = hdr['type'].val
    week   = obj['week'].val
    tow    = obj['tow100'].val/100.
    chans  = obj['chans'].val
    if debug:
        c = copy.deepcopy(obj)
        del c['gps_hdr']
        del c['capdelta']
        print_basic_obj(offset, hdr, c, dt_name(xtype))
    c = OrderedDict()
    c['week']  = week
    c['tow']   = tow
    c['chans'] = chans
    for i in range(0, chans):
        c['svid']   = obj[i]['svid']
        c['az']     = obj[i]['az10']/10.
        c['el']     = obj[i]['el10']/10.
        state       = obj[i]['state']
        c['state']  = '0x{:02x}'.format(state) if verbose or pretty else state
        st_str = gps_expand_trk_state_short(state)
        st_str = '-' if st_str == ' nostate' else st_str
        c['st_str']  = st_str
        c['cno_avg'] = obj[i]['cno_avg']
        for j in range(0, 10):
            cno_str = 'cno' + str(j)
            c[cno_str] = obj[i][cno_str]
        print_basic_obj(offset, hdr, c, dt_name(xtype))


def emit_sensor_data_mr(level, offset, buf, obj):
    hdr    = obj['hdr']
    xtype  = hdr['type'].val
    delta  = obj['sched_delta'].val
    sns_id = obj['sns_id'].val
    v = sensor.sns_table.get(sns_id, ('', None, None, None, None, ''))
    if debug:
        c = copy.deepcopy(obj)
        del c['hdr']
        del c['pad']
        sns_obj  = v[SNS_OBJECT]
        xdict = sns_dict(sns_id)(sns_obj)
        for k in xdict:
            c[k] = xdict[k]
        print_basic_obj(offset, hdr, c, dt_name(xtype))
    c = OrderedDict()
    sns_obj  = v[SNS_OBJECT]
    xdict = sns_dict(sns_id)(sns_obj)
    for k in xdict:
        c[k] = xdict[k]
    print_basic_obj(offset, hdr, c, dt_name(xtype))
