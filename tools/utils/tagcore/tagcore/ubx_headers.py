# Copyright (c) 2020 Eric B. Decker, Daniel J. Maltbie
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

'''ubxbin protocol decoders and header objects'''

from   __future__         import print_function

__version__ = '0.4.8.dev1'

import binascii
from   collections  import OrderedDict

from   base_objs    import *
from   ubx_defs     import *
import ubx_defs     as     ubx


########################################################################
#
# Ubx Headers/Objects
#
########################################################################

#######
#
# ubxbin header, little endian.
#
# start: 0xb542
# len:   little endian
# class: byte
# id:    byte

def obj_ubx_hdr():
    return aggie(OrderedDict([
        ('start', atom(('>H', '0x{:04x}'))),
        ('cid',   atom(('>H', '0x{:04X}'))),
        ('len',   atom(('<H', '0x{:04x}'))),
    ]))


########################################################################
#
# Gps Raw decode messages
#
