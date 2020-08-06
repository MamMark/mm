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

__version__ = '0.4.8.dev3'

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
# cid:   class/id (big endian)
#        byte  byte
# len:   little endian

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

# ubx_ack_nack/ack  (0500, 0501)

def obj_ubx_ack():
    return aggie(OrderedDict([
        ('ubx',        obj_ubx_hdr()),
        ('ackClassId', atom(('>H', '0x{:04X}'))),
    ]))


# ubx_cfg_cfg 0x0609
#
# len 12: clear, save, load (no devMask)
# len 13: clear, save, load, devMask (1 byte)
#
# devMask held in a 'var' section

def obj_ubx_cfg_cfg_devmask():
    return aggie(OrderedDict([
        ('devMask',      atom(('B',  '{:02x}'))),
    ]))

def obj_ubx_cfg_cfg():
    return aggie(OrderedDict([
        ('ubx',       obj_ubx_hdr()),
        ('clearMask', atom(('<I', '{:08X}'))),
        ('saveMask',  atom(('<I', '{:08X}'))),
        ('loadMask',  atom(('<I', '{:08X}'))),
    ]))


# ubx_cfg_msg 0601
# len 2: poll
# len 3: get/set, rate byte
# len 8: get/set, per port (0-5) rate
#
# decoder adds 'rate' if len 3.
#              'rates[0..5]' len 8.

def obj_ubx_cfg_msg_rate():
    return aggie(OrderedDict([
        ('rate', atom(('B', '{}'))),
    ]))

def obj_ubx_cfg_msg_rates():
    return aggie(OrderedDict([
        ('rates', atom(('8s', '{}', binascii.hexlify))),
    ]))
    pass

def obj_ubx_cfg_msg():
    return aggie(OrderedDict([
        ('ubx',      obj_ubx_hdr()),
        ('msgClassId', atom(('>H', '0x{:04X}'))),
    ]))


# ubx_cfg_prt 0600
# len 1:  poll
# len 20: get/set, port config
#
# decoder adds key 'var' which then has either a
# obj_ubx_cfg_prt_poll or obj_ubx_cfg_prt_spi object.
#
# if not an spi port config, just pretend it is a poll.

def obj_ubx_cfg_prt_poll():
    return aggie(OrderedDict([
        ('portId',       atom(('B',  '{}'))),
    ]))

def obj_ubx_cfg_prt_spi():
    return aggie(OrderedDict([
        ('portId',       atom(('B',  '{}'))),
        ('reserved1',    atom(('B',  '{}'))),
        ('txReady',      atom(('<H', '0x{:04x}'))),
        ('mode',         atom(('<I', '0x{:04x}'))),
        ('reserved2',    atom(('<I', '{}'))),
        ('inProtoMask',  atom(('<H', '0x{:04x}'))),
        ('outProtoMask', atom(('<H', '0x{:04x}'))),
        ('flags',        atom(('<H', '0x{:04x}'))),
        ('reserved3',    atom(('<H', '0x{:04x}'))),
    ]))

def obj_ubx_cfg_prt():
    return aggie(OrderedDict([
        ('ubx',      obj_ubx_hdr()),
    ]))


# ubx_cfg_rst 0604
# len 4

def obj_ubx_cfg_rst():
    return aggie(OrderedDict([
        ('ubx',        obj_ubx_hdr()),
        ('navBbrMask', atom(('<H', '0x{:04x}'))),
        ('resetMode',  atom(('B',  '{}'))),
        ('reserved1',  atom(('B',  '{}'))),
    ]))


# ubx_rxm_pmreq 0241
# len 8:  no version or wakeupSources
# len 16: version and wakeupSources
def obj_ubx_rxm_pmreq_8():
    return aggie(OrderedDict([
        ('duration',    atom(('<I',  '{}'))),
        ('flags',       atom(('<I',  '{:04x}'))),
    ]))

def obj_ubx_rxm_pmreq_16():
    return aggie(OrderedDict([
        ('version',       atom(('B',   '{}'))),
        ('reserved1',     atom(('3s',  '{}', binascii.hexlify))),
        ('duration',      atom(('<I',  '{}'))),
        ('flags',         atom(('<I',  '{:04x}'))),
        ('wakeupSources', atom(('<I',  '{:04x}'))),
    ]))

def obj_ubx_rxm_pmreq():
    return aggie(OrderedDict([
        ('ubx',      obj_ubx_hdr()),
    ]))


########################################################################
#
# Ublox Decoders
#
########################################################################

def decode_ubx_ack(level, offset, buf, obj):
    return obj.set(buf)


def decode_ubx_cfg_cfg(level, offset, buf, obj):
    if obj.get('var'):
        del(obj['var'])

    # 'var' section removed, should have a obj_ubx_cfg_cfg left
    # populate it.  This will populate clear, save, load.
    # If len is 13, need devMask as well.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val
    if xlen == 13:
        # need to get devMask as a 'var' section
        obj['var'] = obj_ubx_cfg_cfg_devmask();
        consumed += obj['var'].set(buf[consumed:])
    return consumed


def decode_ubx_cfg_prt(level, offset, buf, obj):
    if obj.get('var'):
        del(obj['var'])

    # variable has been removed, should have a ubx_hdr left ('ubx')
    # populate it.  1st byte after the hdr is the port_id.
    consumed = obj.set(buf)
    port_id = buf[consumed]
    xlen = obj['ubx']['len'].val
    if xlen != 20 or port_id != 4:
        # poll or other port
        obj['var'] = obj_ubx_cfg_prt_poll();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    # must be a cfg_prt for the spi
    obj['var'] = obj_ubx_cfg_prt_spi();
    consumed += obj['var'].set(buf[consumed:])
    return consumed


def decode_ubx_cfg_msg(level, offset, buf, obj):
    if obj.get('var'):
        del(obj['var'])

    # variable has been removed, should have a ubx_hdr left ('ubx')
    # populate it.  1st byte after the hdr is the port_id.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val

    if xlen == 2:                       # poll
        return consumed

    if xlen == 3:                       # single rate, current port
        obj['var'] = obj_ubx_cfg_msg_rate();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    if xlen == 8:                       # multiple rates
        obj['var'] = obj_ubx_cfg_msg_rates();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    return consumed

def decode_ubx_rxm_pmreq(level, offset, buf, obj):
    if obj.get('var'):
        del(obj['var'])

    # variable has been removed, should have a ubx_hdr left ('ubx')
    # populate it.  1st byte after the hdr is the port_id.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val

    if xlen == 8:                       # single rate, current port
        obj['var'] = obj_ubx_rxm_pmreq_8();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    if xlen == 16:                       # multiple rates
        obj['var'] = obj_ubx_rxm_pmreq_16();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    return consumed
