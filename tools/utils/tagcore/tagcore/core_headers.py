# Copyright (c) 2020,      Eric B. Decker
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

__version__ = '0.4.6'

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
        ('node_id',   atom(('6s', '{}', binascii.hexlify))),
        ('pad',       atom(('<H', '0x{:04x}'))),
        ('owcb',      obj_owcb())
    ]))


# RTC SRC values
rtc_src_names = {
    0:  'BOOT',
    1:  'FORCED',
    2:  'DBLK',
    3:  'NET',
    4:  'GPS0',
    5:  'GPS',
}

def rtc_src_name(rtc_src):
    return rtc_src_names.get(rtc_src, 'rtcsrc/' + str(rtc_src))


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
        ('ow_debug',        atom(('B',  '0x{:02x}'))),
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
def obj_dt_debug():
    return aggie(OrderedDict([
        ('hdr',   obj_dt_hdr()),
    ]))


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


def obj_dt_gps_time():
    return aggie(OrderedDict([
        ('gps_hdr',   obj_dt_gps_hdr()),
        ('capdelta',  atom(('<i', '{}'))),
        ('tow1000',   atom(('<I', '{}'))),
        ('week_x',    atom(('<H', '{}'))),
        ('utc_year',  atom(('<H', '{}'))),
        ('utc_month', atom(('<B', '{}'))),
        ('utc_day',   atom(('<B', '{}'))),
        ('utc_hour',  atom(('<B', '{}'))),
        ('utc_min',   atom(('<B', '{}'))),
        ('utc_ms',    atom(('<H', '{}'))),
        ('nsats',     atom(('<B', '{}'))),
    ]))


def obj_dt_gps_geo():
    return aggie(OrderedDict([
        ('gps_hdr',   obj_dt_gps_hdr()),
        ('capdelta',  atom(('<i', '{}'))),
        ('nav_valid', atom(('<H', '0x{:02x}'))),
        ('nav_type',  atom(('<H', '0x{:02x}'))),
        ('lat',       atom(('<i', '{}'))),
        ('lon',       atom(('<i', '{}'))),
        ('alt_ell',   atom(('<i', '{}'))),
        ('alt_msl',   atom(('<i', '{}'))),
        ('sat_mask',  atom(('<I', '0x{:08x}'))),
        ('tow1000',   atom(('<I', '{}'))),
        ('week_x',    atom(('<H', '{}'))),
        ('nsats',     atom(('<B', '{}'))),
        ('add_mode',  atom(('<B', '0x{:02x}'))),
        ('ehpe100',   atom(('<I', '{}'))),
        ('hdop5',     atom(('<B', '{}'))),
    ]))


def obj_dt_gps_xyz():
    return aggie(OrderedDict([
        ('gps_hdr',   obj_dt_gps_hdr()),
        ('capdelta',  atom(('<i', '{}'))),
        ('x',         atom(('<i', '{}'))),
        ('y',         atom(('<i', '{}'))),
        ('z',         atom(('<i', '{}'))),
        ('sat_mask',  atom(('<I', '0x{:08x}'))),
        ('tow100',    atom(('<I', '{}'))),
        ('week_x',    atom(('<H', '{}'))),
        ('m1',        atom(('<B', '0x{:02x}'))),
        ('hdop5',     atom(('<B', '{}'))),
        ('nsats',     atom(('<B', '{}'))),
    ]))


def obj_dt_gps_clk():
    return aggie(OrderedDict([
        ('gps_hdr',   obj_dt_gps_hdr()),
        ('capdelta',  atom(('<i', '{}'))),
        ('tow100',    atom(('<I', '{}'))),
        ('drift',     atom(('<I', '{}'))),
        ('bias',      atom(('<I', '{}'))),
        ('week_x',    atom(('<H', '{}'))),
        ('nsats',     atom(('B', '{}'))),
    ]))


def obj_dt_gps_trk_element():
    return aggie(OrderedDict([
        ('az10',      atom(('<H', '{}'))),
        ('el10',      atom(('<H', '{}'))),
        ('state',     atom(('<H', '{}'))),
        ('svid',      atom(('<H', '{}'))),
        ('cno0',      atom(('B',  '{}'))),
        ('cno1',      atom(('B',  '{}'))),
        ('cno2',      atom(('B',  '{}'))),
        ('cno3',      atom(('B',  '{}'))),
        ('cno4',      atom(('B',  '{}'))),
        ('cno5',      atom(('B',  '{}'))),
        ('cno6',      atom(('B',  '{}'))),
        ('cno7',      atom(('B',  '{}'))),
        ('cno8',      atom(('B',  '{}'))),
        ('cno9',      atom(('B',  '{}'))),
    ]))


def obj_dt_gps_trk():
    return aggie(OrderedDict([
        ('gps_hdr',   obj_dt_gps_hdr()),
        ('capdelta',  atom(('<i', '{}'))),
        ('tow100',    atom(('<I', '{}'))),
        ('week',      atom(('<H', '{}'))),
        ('chans',     atom(('<H', '{}'))),
    ]))


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
        ('hdr',         obj_dt_hdr()),
        ('sched_delta', atom(('<I', '{}'))),
        ('sns_id',      atom(('<H', '{}'))),
        ('pad',         atom(('<H', '{}'))),
    ]))

def obj_dt_sen_set():
    return aggie(OrderedDict([
        ('hdr',   obj_dt_hdr()),
    ]))

def obj_dt_test():
    return aggie(OrderedDict([
        ('hdr',   obj_dt_hdr()),
    ]))

####
#
# NOTES
#
# A note record consists of a dt_note_t header (same as dt_header_t, a
# simple header) followed by n bytes of note.  typically a printable
# ascii string (yeah, localization is an issue, but not now).
#
def obj_dt_note():
    return aggie(OrderedDict([
        ('hdr',   obj_dt_hdr()),
    ]))

def obj_dt_config():
    return aggie(OrderedDict([
        ('hdr',   obj_dt_hdr()),
    ]))


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

def obj_dt_tagnet():
    return aggie(OrderedDict([
        ('hdr',   obj_dt_hdr()),
    ]))


# extract and decode gps nav track messages.
#
# base object is an obj_dt_gps_trk which includes 'chans' which
# tells us how many channels are following.  Each chan is made up of
# a obj_dt_gps_trk_element (gps_navtrk_chan).
#
# each instance of gps_navtrk_chan is held as part of a dictionary
# key'd off the numeric chan number, 0-11 (12 channels is typical),
# and attached to the main obj_dt_gps_trk object (obj).
#

gps_navtrk_chan = obj_dt_gps_trk_element()

def decode_gps_trk(level, offset, buf, obj):
    # delete any previous navtrk channel data
    for k in obj.iterkeys():
        if isinstance(k,int):
            del obj[k]

    consumed = obj.set(buf)
    chans    = obj['chans'].val

    # grab each channels cnos and other data
    for n in range(chans):
        d = {}                      # get a new dict
        consumed += gps_navtrk_chan.set(buf[consumed:])
        for k, v in gps_navtrk_chan.items():
            d[k] = v.val
        avg  = d['cno0'] + d['cno1'] + d['cno2']
        avg += d['cno3'] + d['cno4'] + d['cno5']
        avg += d['cno6'] + d['cno7'] + d['cno8']
        avg += d['cno9']
        avg /= float(10)
        d['cno_avg'] = avg
        obj[n] = d
    return consumed
