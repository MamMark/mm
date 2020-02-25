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

__version__ = '0.4.7'

from   collections  import OrderedDict
from   base_objs    import *

def acceln8s_element():
    return aggie(OrderedDict([
        ('x', atom(('b', '{}'))),
        ('y', atom(('b', '{}'))),
        ('z', atom(('b', '{}'))),
    ]))

obj_acceln8s = acceln8s_element()


def process_accel(nsamp_obj, decode_obj, buf):
    '''
    process_accel: decode accel data.  This is assumed to be an nsample
        object.

        nsamp_obj:  an obj_nsample() object.  'nsamples' and 'datarate'
        decode_obj: and object defining what each element of the nsample
                    looks like.

    process_accel will first delete any previous samples that have been hung
    off this object.  Then we fetch the number of samples that need to be
    decoded.  Each sample is then read and hung on the nsamp_obj using the
    sample number as the key.
    '''
    for k in nsamp_obj.iterkeys():
        if isinstance(k,int):
            del nsamp_obj[k]

    consumed = nsamp_obj.set(buf)
    nsamples = nsamp_obj['nsamples'].val

    for n in range(nsamples):
        d = OrderedDict()
        consumed += decode_obj.set(buf[consumed:])
        for k, v in decode_obj.items():
            d[k] = v.val
        nsamp_obj[n] = d
    return consumed


def decode_acceln8s(level, offset, buf, obj):
    '''
    decode_acceln8s: pointing into a buffer at the start of a nsample
        record set.

        obj: obj_nsample(), holds 'nsamples' and 'datarate'.
        buf: points at beginning of obj_nsample() data.

    Our data format is defined by obj_acceln8s.  Process_accel will
    read nsamples worth of obj_acceln8s() data.  This data gets appended
    onto the obj_nsample() object (obj).  Each entry is key'd using the
    sample number.
    '''
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
