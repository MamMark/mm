# Copyright (c) 2017-2019, Daniel J. Maltbie, Eric B. Decker
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
#          Eric B. Decker <cire831@gmail.com>

'''Core Data Type decoders and objects'''

from   __future__         import print_function

__version__ = '0.4.5rc97.dev0'

import binascii
from   collections  import OrderedDict

from   base_objs    import *
from   sirf_headers import obj_sirf_hdr
from   sirf_headers import obj_sirf_swver

from   sensor_defs  import *
import sensor_defs  as     sensor

from   sirf_defs    import *
import sirf_defs    as     sirf


########################################################################
#
# Core Decoders
#
########################################################################

#
# Sensor Data decoder
#
# decodes top level of the sensor_data record and then uses the sns_id
# and sns_table to dispatch the appropriate decoder for the actual
# sensor data.  Sensor data is stored on the object pointed to in the
# sns_table entry.
#
# obj must be a obj_dt_sensor_data.
#
# this decoder does the following:
#
# o consume/process a dt_sensor_data hdr
# o extract sns_id from the dt_sensor_data hdr.
# o extract the appropriate vector from sns_table[sns_id]
# o consume/process the sensor data using decode/obj from the vector entry

def decode_sensor(level, offset, buf, obj):
    consumed = obj.set(buf)

    sns_id = obj['sns_id'].val

    try:
        sensor.sns_count[sns_id] += 1
    except KeyError:
        sensor.sns_count[sns_id] = 1

    v = sensor.sns_table.get(sns_id, ('', None, None, None, None, ''))
    decoder     = v[SNS_DECODER]            # sns decoder
    decoder_obj = v[SNS_OBJECT]             # sns object
    if not decoder:
        if (level >= 5):
            print('*** no decoder/obj defined for sns {}'.format(sns_id))
        return consumed
    return consumed + decoder(level, offset, buf[consumed:], decoder_obj)


# GPS RAW decoder
#
# main gps raw decoder, decodes DT_GPS_RAW_SIRFBIN
# dt_gps_raw_obj, 2nd level decode on mid
#
# obj must be a obj_dt_gps_raw.
#
# this decoder does the following:  (it is not a simple decode_default)
#
# o consume/process a gps_raw_hdr (dt_hdr + gps_hdr)
# o consume/process the sirfbin hdr (SOP + LEN + MID)
# o checks the sirfbin hdr for proper SOP.
#
# Not a sirfbin packet:
# o only consume up to the beginning of the SOP
#
# SirfBin packet:
# o Look mid up in mid_table
# o consume/process the remainder of the packet using the appropriate decoder

def decode_gps_raw(level, offset, buf, obj):
    consumed = obj.set(buf)

    if obj['sirf_hdr']['start'].val != SIRF_SOP_SEQ:
        return consumed - len(obj['sirf_hdr'])

    mid = obj['sirf_hdr']['mid'].val

    try:
        sirf.mid_count[mid] += 1
    except KeyError:
        sirf.mid_count[mid] = 1

    v = sirf.mid_table.get(mid, (None, None, None, ''))
    decoder     = v[MID_DECODER]            # dt function
    decoder_obj = v[MID_OBJECT]             # dt object
    if not decoder:
        if (level >= 5):
            print('*** no decoder/obj defined for mid {}'.format(mid))
        return consumed
    return consumed + decoder(level, offset, buf[consumed:], decoder_obj)


########################################################################
#
# Core Header objects
#
########################################################################

def obj_rtctime():
    return aggie(OrderedDict([
        ('sub_sec', atom(('<H', '{}'))),
        ('sec',     atom(('<B', '{}'))),
        ('min',     atom(('<B', '{}'))),
        ('hr',      atom(('<B', '{}'))),
        ('dow',     atom(('<B', '{}'))),
        ('day',     atom(('<B', '{}'))),
        ('mon',     atom(('<B', '{}'))),
        ('year',    atom(('<H', '{}'))),
    ]))


def obj_dt_hdr():
    return aggie(OrderedDict([
        ('len',     atom(('<H', '{}'))),
        ('type',    atom(('B',  '{}'))),
        ('hdr_crc8',atom(('B',  '{}'))),
        ('recnum',  atom(('<I', '{}'))),
        ('rt',      obj_rtctime()),
        ('recsum',  atom(('<H', '0x{:04x}'))),
    ]))


def obj_dt_reboot():
    return aggie(OrderedDict([
        ('hdr',       obj_dt_hdr()),
        ('core_rev',  atom(('<H', '0x{:04x}'))),
        ('core_minor',atom(('<H', '0x{:04x}'))),
        ('base',      atom(('<I', '0x{:08x}'))),
        ('owcb',      obj_owcb())
    ]))


# RTC SRC values
rtc_src_names = {
    0:  'BOOT',
    1:  'FORCED',
    2:  'DBLK',
    3:  'NET',
    4:  'GPS',
}

def rtc_src_name(rtc_src):
    rs_name = rtc_src_names.get(rtc_src, 0)
    if rs_name == 0:
        rs_name = 'rtcsrc_' + str(rtc_src)
    return rs_name


#
# reboot is followed by the ow_control_block
# We want to decode that as well.  native order, little endian.
# see OverWatch/overwatch.h.
#
def obj_owcb():
    return aggie(OrderedDict([
        ('ow_sig',          atom(('<I', '0x{:08x}'))),
        ('rpt',             atom(('<I', '0x{:08x}'))),
        ('boot_time',       obj_rtctime()),
        ('prev_boot',       obj_rtctime()),
        ('reset_status',    atom(('<I', '0x{:08x}'))),
        ('reset_others',    atom(('<I', '0x{:08x}'))),
        ('from_base',       atom(('<I', '0x{:08x}'))),
        ('panic_count',     atom(('<I', '{}'))),
        ('panics_gold',     atom(('<I', '{}'))),

        ('fault_gold',      atom(('<I', '0x{:08x}'))),
        ('fault_nib',       atom(('<I', '0x{:08x}'))),
        ('subsys_disable',  atom(('<I', '0x{:08x}'))),
        ('protection_status', atom(('<I', '0x{:08x}'))),

        ('ow_sig_b',        atom(('<I', '0x{:08x}'))),

        ('ow_req',          atom(('<B', '{}'))),
        ('reboot_reason',   atom(('<B', '{}'))),

        ('ow_boot_mode',    atom(('<B', '{}'))),
        ('owt_action',      atom(('<B', '{}'))),

        ('reboot_count',    atom(('<I', '{}'))),
        ('strange',         atom(('<I', '{}'))),
        ('strange_loc',     atom(('<I', '0x{:04x}'))),
        ('chk_fails',       atom(('<I', '{}'))),
        ('logging_flags',   atom(('<I', '{}'))),

        ('pi_panic_idx',    atom(('<H', '{}'))),
        ('pi_pcode',        atom(('<B', '{}'))),
        ('pi_where',        atom(('<B', '{}'))),
        ('pi_arg0',         atom(('<I', '{}'))),
        ('pi_arg1',         atom(('<I', '{}'))),
        ('pi_arg2',         atom(('<I', '{}'))),
        ('pi_arg3',         atom(('<I', '{}'))),

        ('rtc_src',         atom(('B',  '{}'))),
        ('pad0',            atom(('B',  '{}'))),
        ('pad1',            atom(('<H', '{}'))),

        ('ow_sig_c',        atom(('<I', '0x{:08x}')))
    ]))


def obj_dt_version():
    return aggie(OrderedDict([
        ('hdr',       obj_dt_hdr()),
        ('base',      atom(('<I', '0x{:08x}'))),
        ('image_info', obj_image_info())
    ]))


def obj_hw_version():
    return aggie(OrderedDict([
        ('rev',       atom(('<B', '{}'))),
        ('model',     atom(('<B', '{}'))),
    ]))


def obj_image_version():
    return aggie(OrderedDict([
        ('build',     atom(('<H', '{}'))),
        ('minor',     atom(('<B', '{}'))),
        ('major',     atom(('<B', '{}'))),
    ]))


def obj_image_info():
    return aggie(OrderedDict([
        ('basic',     obj_image_basic()),
        ('plus',      obj_image_plus()),
    ]))

# plus is part of image_info but first we must account
# for any additional reserved words but using basic.basic_len

def obj_image_basic():
    return aggie(OrderedDict([
        ('ii_sig',    atom(('<I', '0x{:08x}'))),
        ('im_start',  atom(('<I', '0x{:08x}'))),
        ('im_len',    atom(('<I', '0x{:08x}'))),
        ('ver_id',    obj_image_version()),
        ('im_chk',    atom(('<I', '0x{:08x}'))),
        ('hw_ver',    obj_hw_version()),
        ('reserved',  atom(('10s',  '{}'))),
    ]))


# do not recycle or reorder number.  Feel free to add.
# one byte, max value 255, 0 says done.

iip_tlv = {
    'end'       :0,
    'desc'      :1,
    'repo0'     :2,
    'repo0_url' :3,
    'repo1'     :4,
    'repo1_url' :5,
    'date'      :6,
}


# obj_image_plus is built dynamically when processing
# or creating image_info_plus tlvs.
#
# tlvs are aggies created dynamically when we know the size
# of the tlv data.  We create effectively the following
#
#    def obj_image_plus_tlv():
#        return aggie(OrderedDict([
#            ('tlv_type', atom(('B', '{}'))),
#            ('tlv_len',  atom(('B', '{}'))),
#            ('tlv_data', atom(('Ns', '{}'))),
#        ]))
#
# where 'N' is the size of the string.  To be nice to gdb/C
# it is recommended to null terminate the string.
#
# This is handled by the tlv_aggie class defined in base_objs.py
#
# The TLV_END tlv is used to terminate the sequence of TLVs.
# It has a length of 2 bytes, tlv_type: 0 and tlv_len: 0.
# This consumes 2 bytes in the tlv_block.  It does not
# have a 'tlv_data' atom.  (there isn't any data).
#


def obj_image_plus_tlv():
    return tlv_aggie(aggie(OrderedDict([
        ('tlv_type', atom(('<B', '{}'))),
        ('tlv_len',  atom(('<B', '{}'))),
#        ('tlv_value',  atom(('<s', '{}'))),
    ])))


def obj_image_plus():
    return tlv_block_aggie(aggie(OrderedDict([
        ('tlv_block_len',    atom(('<H', '{}'))),
#        ('tlv_block',    obj_image_plus_tlv()),
    ])))


def obj_dt_sync():
    return aggie(OrderedDict([
        ('hdr',       obj_dt_hdr()),
        ('prev_sync', atom(('<I', '0x{:x}'))),
        ('majik',     atom(('<I', '0x{:08x}'))),
    ]))


# EVENT
event_names = {
    0:  'NONE',

    1:  'PANIC_WARN',
    2:  'FAULT',

    3:  'GPS_GEO',
    4:  'GPS_XYZ',
    5:  'GPS_TIME',
    6:  'GPS_LTFF_TIME',
    7:  'GPS_FIRST_LOCK',
    31: 'GPS_LOCK',

    8:  'SSW_DELAY_TIME',
    9:  'SSW_BLK_TIME',
    10: 'SSW_GRP_TIME',

    11: 'SURFACED',
    12: 'SUBMERGED',
    13: 'DOCKED',
    14: 'UNDOCKED',

    15: 'DCO_REPORT',
    16: 'DCO_SYNC',
    17: 'TIME_SRC',
    18: 'IMG_MGR',
    19: 'TIME_SKEW',

    32: 'GPS_BOOT',
    33: 'GPS_BOOT_TIME',
    34: 'GPS_BOOT_FAIL',

    35: 'GPS_MON_MINOR',
    36: 'GPS_MON_MAJOR',

    37: 'GPS_RX_ERR',
    38: 'GPS_LOST_INT',
    39: 'GPS_MSG_OFF',

    40: 'GPS_AWAKE_S',
    41: 'GPS_CMD',
    42: 'GPS_RAW_TX',
    43: 'GPS_SWVER_TO',
    44: 'GPS_CANNED',

    45: 'GPS_HW_CONFIG',
    46: 'GPS_RECONFIG',

    47: 'GPS_TURN_ON',
    48: 'GPS_STANDBY',
    49: 'GPS_TURN_OFF',
    50: 'GPS_MPM',
    51: 'GPS_PULSE',

    52: 'GPS_TX_RESTART',
    53: 'GPS_MPM_RSP',

    64: 'GPS_FAST',
    65: 'GPS_FIRST',
    66: 'GPS_SATS/2',
    67: 'GPS_SATS/7',
    68: 'GPS_SATS/41',
    69: 'GPS_PWR_OFF',
}

def event_name(event):
    ev_name = event_names.get(event, 0)
    if ev_name == 0:
        ev_name = 'ev_' + str(event)
    return ev_name


PANIC_WARN    = 1
FAULT         = 2
GPS_GEO       = 3
GPS_XYZ       = 4
GPS_TIME      = 5
DCO_REPORT    = 15
DCO_SYNC      = 16
TIME_SRC      = 17
IMG_MGR       = 18
GPS_MON_MINOR = 35
GPS_MON_MAJOR = 36
GPS_RX_ERR    = 37
GPS_CMD       = 41
GPS_MPM_RSP   = 53


img_mgr_events = {
    0: 'none',
    1: 'alloc',
    2: 'abort',
    3: 'finish',
    4: 'delete',
    5: 'active',
    6: 'backup',
    7: 'eject',
}

def img_mgr_event_name(im_ev):
    iv_name = img_mgr_events.get(im_ev, 0)
    if iv_name == 0:
        iv_name = 'imgmgr_ev_' + str(im_ev)
    return iv_name


def obj_dt_event():
    return aggie(OrderedDict([
        ('hdr',   obj_dt_hdr()),
        ('event', atom(('<H', '{}'))),
        ('pcode', atom(('<B', '{}'))),
        ('w',     atom(('<B', '{}'))),
        ('arg0',  atom(('<I', '0x{:04x}'))),
        ('arg1',  atom(('<I', '0x{:04x}'))),
        ('arg2',  atom(('<I', '0x{:04x}'))),
        ('arg3',  atom(('<I', '0x{:04x}'))),
    ]))


#
# not implemented yet.
#
obj_dt_debug    = obj_dt_hdr

#
# dt, native, little endian
# used by DT_GPS_VERSION and DT_GPS_RAW_SIRFBIN (gps_raw)
#
def obj_dt_gps_hdr():
    return aggie(OrderedDict([
        ('hdr',     obj_dt_hdr()),
        ('mark',    atom(('<I', '0x{:04x}'))),
        ('chip',    atom(('B',  '0x{:02x}'))),
        ('dir',     atom(('B',  '{}'))),
        ('pad',     atom(('<H', '{}'))),
    ]))


def obj_dt_gps_ver():
    return aggie(OrderedDict([
        ('gps_hdr',    obj_dt_gps_hdr()),
        ('sirf_swver', obj_sirf_swver()),
    ]))

obj_dt_gps_time = obj_dt_hdr
obj_dt_gps_geo  = obj_dt_hdr
obj_dt_gps_xyz  = obj_dt_hdr


####
#
# Sensor Data
#
# Record header, sensor data header, followed by sensor data.
#
# Sns_Id determines the format of any following data.  See sensor_defs.py
# for details.
#
def obj_dt_sen_data():
    return aggie(OrderedDict([
        ('hdr',    obj_dt_hdr()),
        ('delta',  atom(('<I', '{}'))),
        ('sns_id', atom(('<H', '{}'))),
        ('pad',    atom(('<H', '{}'))),
    ]))

obj_dt_sen_set  = obj_dt_hdr

obj_dt_test     = obj_dt_hdr

####
#
# NOTES
#
# A note record consists of a dt_note_t header (same as dt_header_t, a
# simple header) followed by n bytes of note.  typically a printable
# ascii string (yeah, localization is an issue, but not now).
#
obj_dt_note     = obj_dt_hdr
obj_dt_config   = obj_dt_hdr


####
#
# GPS PROTO STATS
#

def obj_dt_gps_proto_stats():
    return aggie(OrderedDict([
        ('hdr',                 obj_dt_hdr()),
        ('stats',               obj_gps_proto_stats()),
    ]))

def obj_gps_proto_stats():
    return aggie(OrderedDict([
        ('starts',              atom(('<I', '{}'))),
        ('complete',            atom(('<I', '{}'))),
        ('ignored',             atom(('<I', '{}'))),
        ('resets',              atom(('<H', '{}'))),
        ('too_small',           atom(('<H', '{}'))),
        ('too_big',             atom(('<H', '{}'))),
        ('chksum_fail',         atom(('<H', '{}'))),
        ('rx_timeouts',         atom(('<H', '{}'))),
        ('rx_errors',           atom(('<H', '{}'))),
        ('rx_framing',          atom(('<H', '{}'))),
        ('rx_overrun',          atom(('<H', '{}'))),
        ('rx_parity',           atom(('<H', '{}'))),
        ('proto_start_fail',    atom(('<H', '{}'))),
        ('proto_end_fail',      atom(('<H', '{}'))),
    ]))


# DT_GPS_RAW_SIRFBIN, dt, native, little endian
#  sirf data big endian.
def obj_dt_gps_raw():
    return aggie(OrderedDict([
        ('gps_hdr',  obj_dt_gps_hdr()),
        ('sirf_hdr', obj_sirf_hdr()),
    ]))

obj_dt_tagnet   = obj_dt_hdr
