'''decoders for sirfbin packets'''

# Copyright (c) 2018 Eric B. Decker
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

# Decoders for sirfbin data types

from   sirf_headers  import sirf_navtrk_chan
from   sirf_headers  import sirf_vis_azel

__version__ = '0.2.0 (sd)'

def decode_sirf_navtrk(level, offset, buf, obj):

    # delete any previous navtrk channel data
    for k in obj.iterkeys():            # BRK
        if isinstance(k,int):
            del obj[k]

    consumed = obj.set(buf)
    chans  = obj['chans'].val

    # grab each channels cnos and other data
    for n in range(chans):
        d = {}                      # get a new dict
        consumed += sirf_navtrk_chan.set(buf[consumed:])
        for k, v in sirf_navtrk_chan.items():
            d[k] = v.val
        avg  = d['cno0'] + d['cno1'] + d['cno2']
        avg += d['cno3'] + d['cno4'] + d['cno5']
        avg += d['cno6'] + d['cno7'] + d['cno8']
        avg += d['cno9']
        avg /= float(10)
        d['cno_avg'] = avg
        obj[n] = d
    return consumed


def decode_sirf_vis(level, offset, buf, obj):

    # delete any previous vis data (previous packets)
    for k in obj.iterkeys():            # BRK
        if isinstance(k,int):
            del obj[k]

    consumed = obj.set(buf)
    num_sats = obj['vis_sats'].val

    # for each visible satellite, the sirf_vis_azel object will have sv_id,
    # sv_az, and sv_el.
    #
    # we copy the data off the object into a new dictionary and then add
    # this dictionary onto the sirf_vis_obj using the vis_sat number
    # (0..num_sats-1) as the key.

    for n in range(num_sats):
        d = {}                          # new dict
        consumed += sirf_vis_azel.set(buf[consumed:])
        for k, v in sirf_vis_azel.items():
            d[k] = v.val
        obj[n] = d
    return consumed


