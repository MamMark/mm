# Copyright (c) 2018 Daniel J. Maltbie <dmaltbie@daloma.org>
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
# Contact: Daniel J. Maltbie <dmaltbie@daloma.org>

'''emitters for producing InfluxDB line protocol JSON records'''

from   __future__         import print_function

__version__ = '0.0.3.dev0'

TEST = False

import sys
from datetime import datetime
from time     import sleep
from binascii import hexlify
from requests.exceptions import ConnectionError

import pprint
pp = pprint.PrettyPrinter(indent=4)

from base_objs import atom
from dt_defs   import dt_records, rtctime_str, rtctime_iso
from core_headers import event_name

import tagcore.globals

__all__ = [ 'emit_influx' ]
versions_ok = [ '1.5.2', '1.7.0' ]


host     = 'localhost'
port     = 8086
user     = 'root'
password = 'root'
dbname   = 'test'


def influx_print():
    if tagcore.globals.verbose > 0 or tagcore.globals.export:
        return 1
    else:
        return 0



# handle influxdb being installed and not installed.
try:
    influxdb_version = ''
    if tagcore.globals.export == -1:
        print('### --noexport, no external database export')
        tagcore.globals.export = 0
        raise ImportError

    from influxdb import InfluxDBClient

    if influx_print():
        print('### influxdb host: {}, port: {}, user: {}, password: {}, dbname: {}'.format(
            host, port, user, password, dbname))
    influx_db = InfluxDBClient(host, port, user, password, dbname)
    try:
        influxdb_version = influx_db.ping()
        if influx_print():
            print("### Influxdb version: {}".format(influxdb_version))
        #influx_db.drop_database(dbname)
        if influxdb_version in versions_ok:
            dblist = influx_db.get_list_database()
            if influx_print():
                print("### Influxdb available databases: {}".format(dblist))
            no_db = True
            for db in dblist:
                if db['name'] == dbname:
                    no_db = False
                    break
            if (no_db):
                print("### Influxdb creating database: {}".format(dbname))
                influx_db.create_database(dbname)
        else:
            print('### influxdb not correct version: {}', influxdb_version)
            influxdb_saved_version = influxdb_version
            influxdb_version = ''
            if tagcore.globals.export:
                print('-x (export) specified and cannot connect to influxdb')
                sys.exit()
    except ConnectionError:
        if influx_print():
            print('### influxdb not running.  No database export')
        if tagcore.globals.export:
            print('-x (export) specified and cannot connect to influxdb')
            sys.exit()

except ImportError:
    if influx_print():
        print('### influxdb not installed.  No database export')
    if tagcore.globals.export:
        print('### -x (export) specified and cannot connect to influxdb')
        sys.exit()


def int32(x):
  if x>0xFFFFFFFF:
    raise OverflowError
  if x>0x7FFFFFFF:
    x=int(0x100000000-x)
    if x<2147483648:
      return -x
    else:
      return -2147483648
  return x


def flatten_dict(init, lkey=''):
    # zzz print('### init', init, lkey)
    ret = {}
    for rkey,val in init.items():
        key = lkey+rkey
        if isinstance(val, dict):
            # zzz print('### key/val', key, val)
            ret.update(flatten_dict(val, key+'_'))
        elif isinstance(val, atom) \
             and (isinstance(val.val, int) or isinstance(val.val, long)):
            # zzz print('### int', key, val.val)
            if rkey == 'event':
                ret[lkey + '_event_name'] = event_name(int(val.val))
            ret[key] = int32(val.val)
        else:
            ret[key] = '{}'.format(val)
    # zzz print('### flatten',ret)
    return ret

if TEST:
    test = {'a': 'e1',
            'c': {'a': 2,
                  'b': {'x': 5,
                        'y' : 10}},
            'd': [1, 2, 3]}
    print(flatten_dict(test))


def influx_record(mname, time, fields, tags):
    return [{
        "measurement": mname,
        "time": time,
        'tags': tags,
        "fields": fields
    }]


'''
This will have to change for hdr restructure in CR: 22/0.

_example_input = {'hdr': {'len': 28,  'type': 3,  'recnum': 156570,  'rt': {'sub_sec': 9194,  'sec': 59,  'min': 46,  'hr': 22,  'dow': 3,  'day': 13,  'mon': 9,  'year': 2018},  'recsum': 0x071f}, 'prev_sync': '6f3820',  'majik': 'dedf00ef'}

_example_output = [
    {'measurement': 'SYNC'},
    'fields': {'hdr_rt_min': 33,
               'hdr_rt_dow': 2,
               'hdr_len': 28,
               'hdr_rt_sub_sec': 27051,
               'hdr_recnum': 128926,
               'hdr_rt_hr': 22,
               'hdr_rt_sec': 48,
               'hdr_rt_year': 2018,
               'majik': '0xdedf00ef',
               'hdr_rt_day': 12,
               'hdr_rt_mon': 9,
               'hdr_recsum': 2061,
               'hdr_type': 3,
               'prev_sync': 6171560},
    'time': '2018-09-12T22:33:48.825531',
    'tags': {'app': 'tagdump'},
]
'''

def build_tags(obj):
    '''
    add tags used to filter selection.
    '''
    tags = {}
    if 'event' in obj: tags.update({'event': event_name(obj['event'].val)})
    return tags


def emit_influx(level, offset, buf, obj):
    # zzz print('### emit_influx version: {}, level: {}, offset: {}, len: {}'.format(influxdb_version, level, offset, len(buf)))
    if influxdb_version == '':
        return
    if obj:
        try:
            xlen     = obj['hdr']['len'].val
            xtype    = obj['hdr']['type'].val
            recnum   = obj['hdr']['recnum'].val
            rtctime  = obj['hdr']['rt']
            brt      = rtctime_str(rtctime)
        except:
            try:
                xlen     = obj['len'].val
                xtype    = obj['type'].val
                recnum   = obj['recnum'].val
                rtctime  = obj['rt']
                brt      = rtctime_str(rtctime)
            except:
                print('### emit_influx error obj no good, offset: {}, buf: {}'.format(offset,
                                                                                      hexlify(buf)))
                return
        # zzz pp.pprint(obj)
        # zzz print('### emit_influx name: {}, num: {}, xtype: {}, xlen: {}, brt: {}, utc: {}'.format(
        # dt_records[int(xtype)][4], recnum, xtype, xlen, brt, rtctime_iso(rtctime)))
        # zzz print('### emit_influx {}'.format(flatten_dict(obj, '')))
        json_rec =influx_record(dt_records[int(xtype)][4],
                                rtctime_iso(rtctime),
                                flatten_dict(obj, ''),
                                build_tags(obj))
        # zzz print('### influx JSON:', json_rec)
        influx_db.write_points(json_rec)
    else:
        print('### emit_influx error level: {}, offset: {}, buf: {}'.format(hexlify(buf)))
