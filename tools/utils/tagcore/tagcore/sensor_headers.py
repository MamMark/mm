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

'''Sensor Decoders and objects'''

from   __future__   import print_function

__version__ = '0.4.6.dev2'

from   collections  import OrderedDict
from   base_objs    import *

def acceln_element():
    return aggie(OrderedDict([
        ('x', atom(('<H', '{}'))),
        ('y', atom(('<H', '{}'))),
        ('z', atom(('<H', '{}'))),
    ]))

def acceln8_element():
    return aggie(OrderedDict([
        ('x', atom(('B', '{}'))),
        ('y', atom(('B', '{}'))),
        ('z', atom(('B', '{}'))),
    ]))

def acceln8s_element():
    return aggie(OrderedDict([
        ('x', atom(('b', '{}'))),
        ('y', atom(('b', '{}'))),
        ('z', atom(('b', '{}'))),
    ]))

obj_acceln   = acceln_element()
obj_acceln8  = acceln8_element()
obj_acceln8s = acceln8s_element()


def process_accel(sub_obj, decode_obj, buf):
    for k in sub_obj.iterkeys():
        if isinstance(k,int):
            del sub_obj[k]

    consumed = sub_obj.set(buf)
    nsamples = sub_obj['nsamples'].val

    for n in range(nsamples):
        d = OrderedDict()
        consumed += decode_obj.set(buf[consumed:])
        for k, v in decode_obj.items():
            d[k] = v.val
        sub_obj[n] = d
    return consumed


def decode_acceln(level, offset, buf, obj):
    return process_accel(obj, obj_acceln, buf)

def decode_acceln8(level, offset, buf, obj):
    return process_accel(obj, obj_acceln8, buf)

def decode_acceln8s(level, offset, buf, obj):
    return process_accel(obj, obj_acceln8s, buf)


def obj_tmp_px():
    return aggie(OrderedDict([
        ('tmp_p', atom(('<h', '{}'))),
        ('tmp_x', atom(('<h', '{}'))),
    ]))

def obj_nsample():
    return aggie(OrderedDict([
        ('nsamples', atom(('<H', '{}'))),
        ('datarate', atom(('<H', '{}'))),
    ]))

#why doesnt this work?
#obj_acceln8 = obj_nsample_hdr()
