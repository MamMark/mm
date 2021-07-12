# Copyright (c) 2020, 2021 Eric B. Decker, Daniel J. Maltbie
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

__version__ = '0.4.10.dev4'

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
# start: 0xb562   (big endian)
# cid:   class/id (big endian)
#        byte  byte
# len:   little endian

def obj_ubx_hdr():
    return aggie(OrderedDict([
        ('start', atom(('>H', '0x{:04x}'))),
        ('cid',   atom(('>H', '0x{:04X}'))),
        ('len',   atom(('<H', '{}'))),
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


# ubx_cfg_ant 0x0613
#
# len 2: Get returns response with current ANT configuration
# len 4: ANT configuration.

def obj_ubx_cfg_ant():
    return aggie(OrderedDict([
        ('ubx', obj_ubx_hdr()),
    ]))


def obj_ubx_cfg_ant_var():
    return aggie(OrderedDict([
        ('flags', atom(('<H', '0x{:04x}'))),
        ('pins',  atom(('<H', '0x{:04x}'))),
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


# ubx_cfg_inf 0602
# len 1: poll, protocol byte
# len n * 10: n ports

def obj_ubx_cfg_inf_poll():
    return aggie(OrderedDict([
        ('protoId',   atom(('<B', '{:02X}'))),
    ]))

def obj_ubx_cfg_inf_port():
    return aggie(OrderedDict([
        ('protoId',   atom(('<B', '{:02X}'))),
        ('reserved1', atom(('3s', '{}', binascii.hexlify))),
        ('infMask',   atom(('6s', '{}', binascii.hexlify))),
    ]))

def obj_ubx_cfg_inf():
    return aggie(OrderedDict([
        ('ubx',        obj_ubx_hdr()),
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
        ('rates', atom(('6s', '{}', binascii.hexlify))),
    ]))

def obj_ubx_cfg_msg():
    return aggie(OrderedDict([
        ('ubx',        obj_ubx_hdr()),
        ('msgClassId', atom(('>H', '0x{:04X}'))),
    ]))


def obj_ubx_cfg_navx5_var():
    return aggie(OrderedDict([
        ('version',             atom(('<H', '{}'))),
        ('mask1',               atom(('<H', '0x{:04X}'))),
        ('mask2',               atom(('<I', '0x{:04X}'))),
        ('reserved1',           atom(('<H', '{}'))),
        ('minSVs',              atom(('<B', '{}'))),
        ('maxSVs',              atom(('<B', '{}'))),
        ('minCNO',              atom(('<B', '{}'))),
        ('reserved2',           atom(('<B', '{}'))),
        ('iniFix3D',            atom(('<B', '{}'))),
        ('reserved3',           atom(('<H', '{}'))),
        ('ackAiding',           atom(('<B', '{}'))),
        ('wknRollover',         atom(('<H', '{}'))),
        ('sigAttenCompMode',    atom(('<B', '{}'))),
        ('reserved4',           atom(('<B', '{}'))),
        ('reserved5',           atom(('<H', '{}'))),
        ('reserved6',           atom(('<H', '{}'))),
        ('usePPP',              atom(('<B', '{}'))),
        ('aopCfg',              atom(('<B', '{}'))),
        ('reserved7',           atom(('<H', '{}'))),
        ('aopOrbMaxErr',        atom(('<H', '{}'))),
        ('reserved8',           atom(('<I', '{}'))),
        ('reserved9',           atom(('3s', '{}', binascii.hexlify))),
        ('useAdr',              atom(('<B', '{}'))),
    ]))


def obj_ubx_cfg_nav5_var():
    return aggie(OrderedDict([
        ('mask',                atom(('<H', '0x{:04X}'))),
        ('dynmode1',            atom(('<B', '{}'))),
        ('fixmode',             atom(('<B', '{}'))),
        ('fixedAlt',            atom(('<i', '{}'))),
        ('fixedAltVar',         atom(('<I', '{}'))),
        ('minElev',             atom(('<b', '{}'))),
        ('drLimit',             atom(('<B', '{}'))),
        ('pDop',                atom(('<H', '{}'))),
        ('tDop',                atom(('<H', '{}'))),
        ('pAcc',                atom(('<H', '{}'))),
        ('tAcc',                atom(('<H', '{}'))),
        ('staticHoldThresh',    atom(('<B', '{}'))),
        ('dgnssTimeout',        atom(('<B', '{}'))),
        ('cnoThreshNumSVs',     atom(('<B', '{}'))),
        ('cnoThresh',           atom(('<B', '{}'))),
        ('reserved1',           atom(('<H', '{}'))),
        ('staticHoldMaxDist',   atom(('<H', '{}'))),
        ('utcStandard',         atom(('<B', '{}'))),
        ('reserved2',           atom(('<B', '{}'))),
        ('reserved2x',          atom(('<I', '{}'))),
    ]))


# can have a var section obj_ubx_cfg_nav5_var.
# poll or the var section
def obj_ubx_cfg_nav5():
    return aggie(OrderedDict([
        ('ubx',                 obj_ubx_hdr()),
    ]))


# ubx_cfg_otp 0641
# len 0:  poll
# len 12: data set
#
# decoder adds key 'var' if data present.

def obj_ubx_cfg_otp():
    return aggie(OrderedDict([
        ('ubx',                 obj_ubx_hdr()),
    ]))

def obj_ubx_cfg_otp_var():
    return aggie(OrderedDict([
        ('subcmd',              atom(('<H', '{}'))),
        ('word',                atom(('<B', '{}'))),
        ('section',             atom(('<B', '{}'))),
        ('hash',                atom(('<I', '0x{:04x}'))),
        ('data',                atom(('<I', '0x{:04x}'))),
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


# ubx_mon_hw 0a09
# len 60

def obj_ubx_mon_hw():
    return aggie(OrderedDict([
        ('ubx', obj_ubx_hdr()),
    ]))

def obj_ubx_mon_hw_data():
    return aggie(OrderedDict([
        ('pinSel',      atom(('<I', '0x{:04x}'))),
        ('pinBank',     atom(('<I', '0x{:04x}'))),
        ('pinDir',      atom(('<I', '0x{:04x}'))),
        ('pinVal',      atom(('<I', '0x{:04x}'))),
        ('noisePerMs',  atom(('<H', '0x{:04x}'))),
        ('agcCnt',      atom(('<H', '0x{:04x}'))),
        ('aStatus',     atom(('<B', '0x{:02x}'))),
        ('aPower',      atom(('<B', '0x{:02x}'))),
        ('flags',       atom(('<B', '0x{:02x}'))),
        ('reserved1',   atom(('<B', '0x{:02x}'))),
        ('usedMask',    atom(('<I', '0x{:04x}'))),
        ('VP',          atom(('17s', '{}', binascii.hexlify))),
        ('jamInd',      atom(('<B', '0x{:02x}'))),
        ('reserved2',   atom(('<H', '0x{:04x}'))),
        ('pinIrq',      atom(('<I', '0x{:04x}'))),
        ('pullH',       atom(('<I', '0x{:04x}'))),
        ('pullL',       atom(('<I', '0x{:04x}'))),
    ]))


# ubx_nav_aopstatus 0160
# len 0  poll
# len 16 stuff

def obj_ubx_nav_aopstatus_16():
    return aggie(OrderedDict([
        ('iTOW',        atom(('<I', '{}'))),
        ('aopCfg',      atom(('<B', '{}'))),
        ('status',      atom(('<B', '0x{:02x}'))),
        ('reserved1',   atom(('10s', '{}', binascii.hexlify))),
    ]))


def obj_ubx_nav_aopstatus():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
    ]))


# ubx_nav_clock 0122
# len 20

def obj_ubx_nav_clock():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('iTOW',        atom(('<I', '{}'))),
        ('clkB',        atom(('<i', '{}'))), # geometric
        ('clkD',        atom(('<i', '{}'))), # positional
        ('tAcc',        atom(('<I', '{}'))), # time
        ('fAcc',        atom(('<I', '{}'))), # vertical
    ]))


# ubx_nav_dop 0104
# len 18

def obj_ubx_nav_dop():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('iTOW',        atom(('<I', '{}'))),
        ('gDOP',        atom(('<H', '{}'))), # geometric
        ('pDOP',        atom(('<H', '{}'))), # positional
        ('tDOP',        atom(('<H', '{}'))), # time
        ('vDOP',        atom(('<H', '{}'))), # vertical
        ('hDOP',        atom(('<H', '{}'))), # horizontal
        ('nDOP',        atom(('<H', '{}'))), # northing
        ('eDOP',        atom(('<H', '{}'))), # easting
    ]))


# ubx_nav_eoe 0161
# len 4

def obj_ubx_nav_eoe():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('iTOW',        atom(('<I', '{}'))),
    ]))


# ubx_nav_orb 0134
# len 8 + 6 * numSVs
# var section has numSVs orb_elms, indexed by [0..numSVs-1]
# decoder adds 'var' section

def obj_ubx_nav_orb_elm():
    return aggie(OrderedDict([
        ('gnssId',      atom(('<B', '{}'))),
        ('svId',        atom(('<B', '{}'))),
        ('svFlag',      atom(('<B', '0x{:02x}'))),
        ('eph',         atom(('<B', '0x{:02x}'))),
        ('alm',         atom(('<B', '0x{:02x}'))),
        ('otherOrb',    atom(('<B', '0x{:02x}'))),
    ]))

def obj_ubx_nav_orb():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('iTOW',        atom(('<I', '{}'))),
        ('version',     atom(('<B', '{}'))),
        ('numSv',       atom(('<B', '{}'))),
        ('reserved1',   atom(('2s', '{}', binascii.hexlify))),
    ]))


# ubx_nav_posecef 0101
# len 20

def obj_ubx_nav_posecef():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('iTOW',        atom(('<I', '{}'))),
        ('ecefX',       atom(('<i', '{}'))),
        ('ecefY',       atom(('<i', '{}'))),
        ('ecefZ',       atom(('<i', '{}'))),
        ('pAcc',        atom(('<I', '{}'))),
    ]))


# ubx_nav_posllh 0102
# len 28

def obj_ubx_nav_posllh():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('iTOW',        atom(('<I', '{}'))),
        ('lon',         atom(('<i', '{}'))),
        ('lat',         atom(('<i', '{}'))),
        ('height',      atom(('<i', '{}'))),
        ('hMSL',        atom(('<i', '{}'))),
        ('hAcc',        atom(('<I', '{}'))),
        ('vAcc',        atom(('<I', '{}'))),
    ]))


# ubx_nav_pvt 0107
# len 92

def obj_ubx_nav_pvt():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
    ]))

def obj_ubx_nav_pvt_var():
    return aggie(OrderedDict([
        ('iTOW',        atom(('<I', '{}'))),
        ('year',        atom(('<H', '{}'))),
        ('month',       atom(('<B', '{}'))),
        ('day',         atom(('<B', '{}'))),
        ('hour',        atom(('<B', '{}'))),
        ('min',         atom(('<B', '{}'))),
        ('sec',         atom(('<B', '{}'))),
        ('valid',       atom(('<B', '0x{:02x}'))),
        ('tAcc',        atom(('<I', '{}'))),
        ('nano',        atom(('<i', '{}'))),
        ('fixType',     atom(('<B', '{}'))),
        ('flags',       atom(('<B', '0x{:02x}'))),
        ('flags2',      atom(('<B', '0x{:02x}'))),
        ('numSV',       atom(('<B', '{}'))),
        ('lon',         atom(('<i', '{}'))),
        ('lat',         atom(('<i', '{}'))),
        ('height',      atom(('<i', '{}'))),
        ('hMSL',        atom(('<i', '{}'))),
        ('hAcc',        atom(('<I', '{}'))),
        ('vAcc',        atom(('<I', '{}'))),
        ('velN',        atom(('<i', '{}'))),
        ('velE',        atom(('<i', '{}'))),
        ('velD',        atom(('<i', '{}'))),
        ('gSpeed',      atom(('<i', '{}'))),
        ('headMot',     atom(('<i', '{}'))),
        ('sAcc',        atom(('<I', '{}'))),
        ('headAcc',     atom(('<I', '{}'))),
        ('pDOP',        atom(('<H', '{}'))),

        # flags3 is documented as a X2 (<H) but only the low 5 bits are used
        # we use it as a byte and subsume the upper byte into the reserved1.

        ('flags3',      atom(('<B', '0x{:02x}'))),
        ('reserved1',   atom(('5s', '{}', binascii.hexlify))),
        ('headVeh',     atom(('<i', '{}'))),
        ('magDec',      atom(('<h', '{}'))),
        ('magAcc',      atom(('<H', '{}'))),
    ]))


# ubx_nav_sat 0135
# len 8 + 12 * numSVs
# var section has numSVs sat_elms, indexed by [0..numSVs-1]
# decoder adds 'var' section

def obj_ubx_nav_sat_elm():
    return aggie(OrderedDict([
        ('gnssId',      atom(('<B', '{}'))),
        ('svId',        atom(('<B', '{}'))),
        ('cno',         atom(('<B', '{}'))),
        ('elev',        atom(('<b', '{}'))),
        ('azim',        atom(('<h', '{}'))),
        ('prRes',       atom(('<h', '{}'))),
        ('flags',       atom(('<I', '0x{:04x}'))),
    ]))

def obj_ubx_nav_sat():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('iTOW',        atom(('<I', '{}'))),
        ('version',     atom(('<B', '{}'))),
        ('numSv',       atom(('<B', '{}'))),
        ('reserved1',   atom(('2s', '{}', binascii.hexlify))),
    ]))


# ubx_nav_status 0103
# len 16

def obj_ubx_nav_status():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('iTOW',        atom(('<I', '{}'))),
        ('gpsFix',      atom(('<B', '{}'))),
        ('flags',       atom(('<B', '0x{:02x}'))),
        ('fixStat',     atom(('<B', '0x{:02x}'))),
        ('flags2',      atom(('<B', '0x{:02x}'))),
        ('ttff',        atom(('<I', '{}'))),
        ('msss',        atom(('<I', '{}'))),
    ]))


# ubx_nav_timegps 0120
# len 16

def obj_ubx_nav_timegps():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('iTOW',        atom(('<I', '{}'))),
        ('fTOW',        atom(('<i', '{}'))), # fractional
        ('week',        atom(('<h', '{}'))), # gps week
        ('leapS',       atom(('<b', '{}'))), # leap secs, GPS-UTC
        ('valid',       atom(('<B', '{}'))),
        ('tAcc',        atom(('<I', '{}'))),
    ]))


# ubx_nav_timels 0126
# len 24

def obj_ubx_nav_timels():
    return aggie(OrderedDict([
        ('ubx',             obj_ubx_hdr()),
        ('iTOW',            atom(('<I', '{}'))),
        ('version',         atom(('<B', '{}'))),
        ('reserved1',       atom(('3s', '{}', binascii.hexlify))),
        ('srcOfCurrLs',     atom(('<B', '{}'))),
        ('currLs',          atom(('<b', '{}'))),
        ('srcOfLsChange',   atom(('<B', '{}'))),
        ('lsChange',        atom(('<b', '{}'))),
        ('timeToLsEvent',   atom(('<i', '{}'))),
        ('dateOfLsGpsWn',   atom(('<H', '{}'))),
        ('dateOfLsGpsDn',   atom(('<H', '{}'))),
        ('reserved2',       atom(('3s', '{}', binascii.hexlify))),
        ('valid',           atom(('<B', '{}'))),
    ]))


# ubx_nav_timeutc 0121
# len 20

def obj_ubx_nav_timeutc():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('iTOW',        atom(('<I', '{}'))),
        ('tAcc',        atom(('<I', '{}'))),
        ('nano',        atom(('<i', '{}'))),
        ('year',        atom(('<H', '{}'))),
        ('month',       atom(('<B', '{}'))),
        ('day',         atom(('<B', '{}'))),
        ('hour',        atom(('<B', '{}'))),
        ('min',         atom(('<B', '{}'))),
        ('sec',         atom(('<B', '{}'))),
        ('valid',       atom(('<B', '{}'))),
    ]))


# ubx_rxm_pmreq 0241
# basic hdr is ubx_rxm_pmreq
# var section is either pmreq_8 or pmreq_16
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


# ubx_tim_tp 0d01
# len 16

def obj_ubx_tim_tp():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
        ('towMS',       atom(('<I', '{}'))),
        ('towSubMS',    atom(('<I', '{}'))),
        ('qErr',        atom(('<i', '{}'))),
        ('week',        atom(('<H', '{}'))),
        ('flags',       atom(('<B', '0x{:02x}'))),
        ('refInfo',     atom(('<B', '0x{:02x}'))),
    ]))


# ubx.len 4 or 8 has cmd
def obj_ubx_upd_sos_4():
    return aggie(OrderedDict([
        ('cmd',       atom(('<B',  '{}'))),
        ('reserved1', atom(('3s',  '{}', binascii.hexlify))),
    ]))

# ubx.len 8 has rsp too
def obj_ubx_upd_sos_8():
    return aggie(OrderedDict([
        ('cmd',       atom(('<B',  '{}'))),
        ('reserved1', atom(('3s',  '{}', binascii.hexlify))),
        ('rsp',       atom(('<B',  '{}'))),
        ('reserved2', atom(('3s',  '{}', binascii.hexlify))),
    ]))

def obj_ubx_upd_sos():
    return aggie(OrderedDict([
        ('ubx',         obj_ubx_hdr()),
    ]))


########################################################################
#
# Ublox Decoders
#
########################################################################

def decode_ubx_cfg_ant(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # 'var' section removed, should have a obj_ubx_cfg_ant left
    # populate it.  Length 0 is a poll.  4 has data.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val

    # poll
    if xlen == 0:
        return consumed

    if xlen == 4:
        obj['var'] = obj_ubx_cfg_ant_var();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    return consumed


def decode_ubx_cfg_cfg(level, offset, buf, obj):
    if obj.get('var') is not None:
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


def decode_ubx_cfg_inf(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # variable has been removed, should have a ubx_hdr left ('ubx')
    # populate it.  1st byte after the hdr is the port_id.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val

    if xlen == 1:                       # poll
        obj['var'] = obj_ubx_cfg_inf_poll()
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    if xlen == 10:
        obj['var'] = obj_ubx_cfg_inf_port()
        consumed += obj['var'].set(buf[consumed:])
        return consumed
    return consumed


def decode_ubx_cfg_msg(level, offset, buf, obj):
    if obj.get('var') is not None:
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


def decode_ubx_cfg_nav5(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # variable has been removed, should have a ubx_hdr left ('ubx')
    # populate it.  1st byte after the hdr is the port_id.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val
    if xlen == 0:                       # get
        return consumed

    obj['var'] = obj_ubx_cfg_nav5_var();
    consumed += obj['var'].set(buf[consumed:])
    return consumed


def decode_ubx_cfg_navx5(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # variable has been removed, should have a ubx_hdr left ('ubx')
    # populate it.  1st byte after the hdr is the port_id.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val
    if xlen == 0:                       # get
        return consumed

    obj['var'] = obj_ubx_cfg_navx5_var();
    consumed += obj['var'].set(buf[consumed:])
    return consumed


def decode_ubx_cfg_otp(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # variable has been removed, should have a ubx_hdr left ('ubx')
    # populate it.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val
    if xlen == 0:                       # get
        return consumed

    obj['var'] = obj_ubx_cfg_otp_var();
    consumed += obj['var'].set(buf[consumed:])
    return consumed


def decode_ubx_cfg_prt(level, offset, buf, obj):
    if obj.get('var') is not None:
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


def decode_ubx_mon_hw(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # variable has been removed, should have a ubx_hdr left ('ubx')
    # populate it.  Either it is a poll or a fully populated mon_hw packet.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val
    if xlen != 60:
        return consumed

    obj['var'] = obj_ubx_mon_hw_data();
    consumed += obj['var'].set(buf[consumed:])
    return consumed


def decode_ubx_nav_aopstatus(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # 'var' section removed, should have a obj_ubx_cfg_ant left
    # populate it.  Length 0 is a poll.  16 has data.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val

    # poll
    if xlen == 0:
        return consumed

    if xlen == 16:
        obj['var'] = obj_ubx_nav_aopstatus_16();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    return consumed


def decode_ubx_nav_orb(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # 'var' section removed, should have a obj_ubx_nav_orb left
    # populate it.  This will populate the static fields including numSv
    consumed = obj.set(buf)
    obj['var'] = OrderedDict()
    numSv = obj['numSv'].val
    for n in range(numSv):
        obj['var'][n] = obj_ubx_nav_orb_elm()
        consumed += obj['var'][n].set(buf[consumed:])
    return consumed


def decode_ubx_nav_pvt(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # 'var' section removed, should have a obj_ubx_nav_pvt left
    # populate it.  This will populate the ubx header.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val
    if xlen == 0:               # poll has no data
        return consumed
    obj['var'] = obj_ubx_nav_pvt_var();
    consumed += obj['var'].set(buf[consumed:])
    return consumed


def decode_ubx_nav_sat(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # 'var' section removed, should have a obj_ubx_nav_sat left
    # populate it.  This will populate the static fields including numSv
    consumed = obj.set(buf)
    obj['var'] = OrderedDict()
    numSv = obj['numSv'].val
    for n in range(numSv):
        obj['var'][n] = obj_ubx_nav_sat_elm()
        consumed += obj['var'][n].set(buf[consumed:])
    return consumed


def decode_ubx_rxm_pmreq(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # variable has been removed, should have a ubx_hdr left ('ubx')
    # populate it.  1st byte after the hdr is the port_id.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val

    if xlen == 8:                       # no version/wakeupSources
        obj['var'] = obj_ubx_rxm_pmreq_8();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    if xlen == 16:                       # version and wakeupSources
        obj['var'] = obj_ubx_rxm_pmreq_16();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    return consumed


def decode_ubx_upd_sos(level, offset, buf, obj):
    if obj.get('var') is not None:
        del(obj['var'])

    # variable has been removed, should have a ubx_hdr left ('ubx')
    # populate it.
    consumed = obj.set(buf)
    xlen = obj['ubx']['len'].val

    if xlen == 4:
        obj['var'] = obj_ubx_upd_sos_4();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    if xlen == 8:
        obj['var'] = obj_ubx_upd_sos_8();
        consumed += obj['var'].set(buf[consumed:])
        return consumed

    return consumed
