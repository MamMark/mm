# Copyright (c) 2019-2020 Eric B. Decker
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

__version__ = '0.4.6.dev8'

import copy
from   datetime       import datetime
from   collections    import OrderedDict
import pytz

import tagcore.globals as    g
from   .core_events   import *           # get event identifiers
from   .core_emitters import *
from   .misc_utils    import rtctime_full
from   .misc_utils    import expand_datetime
from   .misc_utils    import eprint
from   .misc_utils    import utc_str
from   .core_events   import event_name
from   .base_objs     import atom
from   sensor_defs    import *
import sensor_defs    as     sensor

# gps events we want
gps_events_keep = {
    GPS_FIRST_FIX,
    DCO_REPORT,
    DCO_SYNC,
    TIME_SRC,
    TIME_SKEW,
    RADIO_MODE,
    GPS_CYCLE_START,
    GPS_CYCLE_LTFF,
    GPS_CYCLE_END,
    GPS_BOOT_TIME,
}


#          date/time offset    rec  type
basic_hdr  = '{:^26}  {:>8}  {:>8}  {:>16}'
expanded_f = '{:>26}, {:>8}, {:>8}, {:>16}'
expanded_r =', {:>12}'
compact_f  = '{},{},{},{}'
compact_r  = ',{}'

def mr_chksum_err(offset, recsum, chksum):
    front_fmt  = expanded_f if g.pretty else compact_f
    remain_fmt = expanded_r if g.pretty else compact_r
    c = { 'recsum': recsum, 'chksum': chksum }
    if g.debug or g.verbose:
        front_fmt  = expanded_f
        remain_fmt = expanded_r
        # output titles
        print(basic_hdr.format('date','offset','rec','type'), end='')
        for k in c:
            print(remain_fmt.format(k), end='')
        print()

    cur_dt = datetime.now(tz=pytz.utc)
    print(front_fmt.format(expand_datetime(cur_dt, g.pretty),
                           offset, 0, 'CHKSUMERR'), end='')
    for k in c:
        print(remain_fmt.format(str(c[k])), end='')
    print()

##
# mr_display: machine readable output
#
# input: offset         offset of record being displayed
#        sns_hdr        either a wrapper which includes a dt_hdr
#                       or a dt_hdr itself.  Needed for info about
#                       the record, time info etc.
#        mr_dict        a OrderedDict of additional info to be displayed.
#        label          label for the mr line, typically the record type.
#                       if None, then use dt_name(xtype).
#
# mr_display will display standard header information:
#    20200103T021456.606231,50252,538,           SENSOR
#
# and then it will add any information passed in via the OrderedDict
# mr_dict.
#
# if we are in verbose or debug mode then the display will be expanded
# to make it more readable (human checking of the machine output).  A
# title line above the record will be displayed identifing what each
# datum is.
#
def mr_display(offset, sns_hdr, mr_dict, label=None):
    hdr = sns_hdr['hdr'] if ('hdr' in sns_hdr) else sns_hdr
    recnum   = hdr['recnum'].val
    rtctime  = hdr['rt']
    brt      = rtctime_full(rtctime, g.pretty)
    if not label:
        label = dt_name(hdr['type'].val)

    front_fmt  = expanded_f if g.pretty else compact_f
    remain_fmt = expanded_r if g.pretty else compact_r
    if g.debug or g.verbose:
        print(basic_hdr.format('date','offset','rec','type'), end='')
        front_fmt  = expanded_f
        remain_fmt = expanded_r
        if mr_dict.keys():
            for k in mr_dict:
                print(remain_fmt.format(k), end='')
        print()
    print(front_fmt.format(brt, offset, recnum, label), end = '')
    if mr_dict.keys():                  # if we have keys process them.
        for k in mr_dict:
            val = mr_dict[k].val if (isinstance(mr_dict[k], atom)) else mr_dict[k]
            print(remain_fmt.format(val), end='')
    print()


def emit_default_mr(level, offset, buf, obj):
    c = copy.copy(obj)
    if 'gps_hdr' in obj:
        hdr = obj['gps_hdr']['hdr']
        del c['gps_hdr']
    else:
        hdr = obj['hdr']
        del c['hdr']
    mr_display(offset, hdr, c)


def emit_reboot_mr(level, offset, buf, obj):
    hdr   = obj['hdr']
    mr_display(offset, hdr, {})

def emit_event_mr(level, offset, buf, obj):
    hdr = obj['hdr']
    ev  = obj['event'].val
    if ev not in gps_events_keep:
        if g.debug and g.verbose:
            eprint('*** dumping event {}/{}'.format(ev, event_name(ev)))
        return
    c = copy.copy(obj)
    del c['hdr']
    del c['event']
    del c['pcode']
    del c['w']
    mr_display(offset, hdr, c, event_name(ev))


def emit_gps_time_mr(level, offset, buf, obj):
    hdr   = obj['gps_hdr']['hdr']
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
                            ).strftime(utc_str(g.pretty))
    mr_display(offset, hdr, c)


def emit_gps_geo_mr(level, offset, buf, obj):
    hdr    = obj['gps_hdr']['hdr']
    week_x = obj['week_x'].val
    tow    = obj['tow1000'].val/1000.
    ehpe   = obj['ehpe100'].val/100.
    hdop   = obj['hdop5'].val/5.
    if g.debug:
        c = copy.copy(obj)
        del c['gps_hdr']
        del c['capdelta']
        del c['nav_valid']
        del c['alt_ell']
        mr_display(offset, hdr, c)
    c = OrderedDict()
    c['weekx'] = week_x
    c['tow']   = tow
    c['lat']   = obj['lat'].val / 10000000.
    c['lon']   = obj['lon'].val / 10000000.
    c['msl']   = obj['alt_msl'].val/100.
    c['ehpe']  = ehpe
    c['hdop']  = hdop
    nav_type   = '0x{:04x}'.format(obj['nav_type'].val)
    c['nav_type'] =  nav_type if g.verbose or g.debug else obj['nav_type'].val
    mr_display(offset, hdr, c)


def emit_gps_xyz_mr(level, offset, buf, obj):
    hdr    = obj['gps_hdr']['hdr']
    week_x = obj['week_x'].val
    tow    = obj['tow100'].val/100.
    hdop   = obj['hdop5'].val/5.
    if g.debug:
        c = copy.copy(obj)
        del c['gps_hdr']
        del c['capdelta']
        mr_display(offset, hdr, c)
    c = OrderedDict()
    c['weekx'] = week_x
    c['tow']   = tow
    c['x']     = obj['x'].val
    c['y']     = obj['y'].val
    c['z']     = obj['z'].val
    c['hdop']  = hdop
    sats       = '0x{:04x}'.format(obj['sat_mask'].val)
    c['sats']  = sats if g.verbose or g.debug else obj['sat_mask'].val
    nav_type   = '0x{:02x}'.format(obj['m1'].val)
    c['nav_type'] =  nav_type if (g.verbose or g.debug) else obj['m1'].val
    mr_display(offset, hdr, c)


def emit_gps_trk_mr(level, offset, buf, obj):
    hdr    = obj['gps_hdr']['hdr']
    week   = obj['week'].val
    tow    = obj['tow100'].val/100.
    chans  = obj['chans'].val
    if g.debug:
        c = copy.copy(obj)
        del c['gps_hdr']
        del c['capdelta']
        mr_display(offset, hdr, c)
    c = OrderedDict()
    c['week']  = week
    c['tow']   = tow
    c['chans'] = chans
    for i in range(0, chans):
        c['svid']   = obj[i]['svid']
        c['az']     = obj[i]['az10']/10.
        c['el']     = obj[i]['el10']/10.
        state       = obj[i]['state']
        c['state']  = '0x{:02x}'.format(state) if g.verbose or g.pretty else state
        st_str = gps_expand_trk_state_short(state)
        st_str = '-' if st_str == ' nostate' else st_str
        c['st_str']  = st_str
        c['cno_avg'] = obj[i]['cno_avg']
        for j in range(0, 10):
            cno_str = 'cno' + str(j)
            c[cno_str] = obj[i][cno_str]
        mr_display(offset, hdr, c)


def emit_sensor_data_mr(level, offset, buf, obj):
    hdr    = obj['hdr']
    sns_id = obj['sns_id'].val
    v = sensor.sns_table.get(sns_id, ('', None, None, None, None, ''))
    if g.debug:
        c = copy.copy(obj)
        del c['hdr']
        del c['pad']
        sns_obj  = v[SNS_OBJECT]
        dict_func = sns_dict(sns_id)
        xdict = dict_func(sns_obj) if dict_func else None
        if xdict:
            for k in xdict:
                c[k] = xdict[k]
        mr_display(offset, hdr, c)
    sns_obj  = v[SNS_OBJECT]
    dict_func = sns_dict(sns_id)
    xdict = dict_func(sns_obj) if dict_func else None
    if xdict:
        mr_display(offset, hdr, xdict)
    else:
        mr_emitter = v[SNS_MR_EMITTER]
        if mr_emitter:
            # obj is hdr/sns hdr
            # sns_obj is nsamples/datarate/samples
            mr_emitter(offset, obj, sns_obj)

def emit_note_mr(level, offset, buf, obj):
    c = copy.copy(obj)
    hdr = obj['hdr']
    del c['hdr']

    # isolate just the note, and strip NUL and whitespace
    # note follows the header
    note     = buf[len(obj):]
    note     = note.rstrip('\0')
    note     = note.rstrip()
    c['len']  = len(note)
    c['note'] = note
    mr_display(offset, hdr, c)

def emit_gps_proto_mr(level, offset, buf, obj):
    hdr   = obj['hdr']
    c     = obj['stats']
    mr_display(offset, hdr, c)
