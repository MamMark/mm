'''decoders for core data type records'''

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

# basic decoders for main data blocks

__version__ = '0.1.3 (cd)'

from   core_headers import owcb_obj
from   core_headers import image_info_obj
from   sirf_headers import mids_w_sids
from   sirf_headers import sirf_hdr_obj

from   sirf_defs    import *
import sirf_defs    as     sirf


################################################################
#
# REBOOT decoder, dt_reboot_obj, owcb_obj
#

def decode_reboot(level, offset, buf, obj):
    consumed  = obj.set(buf)
    consumed += owcb_obj.set(buf[consumed:])
    return consumed


################################################################
#
# VERSION decoder, dt_version_obj, image_info_obj
#

def decode_version(level, offset, buf, obj):
    consumed  = obj.set(buf)
    consumed += image_info_obj.set(buf[consumed:])
    return consumed


########################################################################
#
# main gps raw decoder, decodes DT_GPS_RAW_SIRFBIN
# dt_gps_raw_obj, 2nd level decode on mid
#

def decode_gps_raw(level, offset, buf, obj):
    consumed = obj.set(buf)

    if obj['sirf_hdr']['start'].val != SIRF_SOP_SEQ:
        return consumed - len(sirf_hdr_obj)

    mid = obj['sirf_hdr']['mid'].val

    try:
        sirf.mid_count[mid] += 1
    except KeyError:
        sirf.mid_count[mid] = 1

    v = sirf.mid_table.get(mid, (None, None, None, ''))
    decoder     = v[MID_DECODER]            # dt function
    decoder_obj = v[MID_OBJECT]             # dt object
    if not decoder:
        print
        if (level >= 5):
            print('*** no decoder/obj defined for mid {}'.format(mid))
        return consumed
    return consumed + decoder(level, offset, buf[consumed:], decoder_obj)
