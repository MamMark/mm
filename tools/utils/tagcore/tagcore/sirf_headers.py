# Copyright (c) 2017-2019 Eric B. Decker, Daniel J. Maltbie
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

'''sirfbin protocol decoders and header objects'''

from   __future__         import print_function

__version__ = '0.4.6.dev3'

import binascii
from   collections  import OrderedDict

from   base_objs    import *
from   sirf_defs    import *
import sirf_defs    as     sirf


########################################################################
#
# Sirf Headers/Objects
#
########################################################################

####
#
# Special atom class for sirf_swver
# not a simple value.
# format string must include two strings.  ie. '{} {}'
#

class atom_sirf_swver(object):
    '''sirf_swver atom.  special.
    takes 2-tuple: ('struct_string', 'default_print_format')

    default_print_format must have space for two items.

    optional 3-tuple: (..., ..., formating_function)

    set will set the instance.attribute "val" to the value
    of the atom's decode of the buffer.  swver.val is the 2-tuple,
    (str0, str1).
    '''
    def __init__(self, a_tuple):
        self.s_str = a_tuple[0]
        self.s_rec = struct.Struct(self.s_str)
        self.p_str = a_tuple[1]
        if (len(a_tuple) > 2):
            self.f_str = a_tuple[2]
        else:
            self.f_str = None
        self.val = ('','')

    def __len__(self):
        return len(self.val[0]) + len(self.val[1]) + 2

    def __repr__(self):
        if callable(self.f_str):
            return self.p_str.format(self.f_str(self.val))
        return self.p_str.format(*self.val)

    def set(self, buf):
        '''set the swver val from the buffer

        len0 len1 str0 str1   is what we expect.

        return the number of bytes (size) consumed,
          len(str0) + len(str1) + 2

        store val as the tuple (str0, str1)
        stored strings do NOT include any trailing NUL.
        however, the consumed value returned is the actual
        number of bytes consumed.
        '''
        len0 = buf[0]
        len1 = buf[1]
        str0 = buf[2:len0+2]
        str1 = buf[2+len0:2+len0+len1]
        self.val = ( str0.rstrip('\0'), str1.rstrip('\0') )
        return len(str0) + len(str1) + 2


class atom_sirf_dev_data(object):
    '''sirf_dev_data atom.  special.
    takes 2-tuple: ('struct_string', 'default_print_format')

    default_print_format must have space for two items.

    optional 3-tuple: (..., ..., formating_function)

    set will set the instance.attribute "val" to the value
    of the atom's decode of the buffer.  dev_data.val is the
    string from the buffer.  It is not null terminated, and
    we want to throw away the chksum and terminator so we
    want buf[:-SIRF_END_SIZE]
    '''
    def __init__(self, a_tuple):
        self.s_str = a_tuple[0]
        self.s_rec = struct.Struct(self.s_str)
        self.p_str = a_tuple[1]
        if (len(a_tuple) > 2):
            self.f_str = a_tuple[2]
        else:
            self.f_str = None
        self.val = ('','')

    def __len__(self):
        return len(self.val)

    def __repr__(self):
        if callable(self.f_str):
            return self.p_str.format(self.f_str(self.val))
        return self.p_str.format(self.val)

    def set(self, buf):
        '''set the dev_data val from the buffer

        <string><chksum><term> is what we have in buf.

        return the number of bytes (size) consumed,
          len(string) + checksum + term

        store val as the string
        '''
        self.val = buf[:-SIRF_END_SIZE]
        return len(buf)


#########
#
# list of mids that have sids.
# usage: if mid in mids_w_sids:  <mid has a sid>
#
mids_w_sids = [
     19,  48,  51,  56,  63,  64,  65,  68,  69,  70,  72,  73,  74,  75,
     77,  90,  91,  92,  93, 161, 172, 177, 178, 205, 211, 212, 213, 215,
    216, 218, 219, 220, 221, 225, 233, 232, 233, 234
]


#######
#
# sirfbin header, big endian.
#
# start: 0xa0a2
# len:   big endian, < 2047
# mid:   byte

def obj_sirf_hdr():
    return aggie(OrderedDict([
        ('start',   atom(('>H', '0x{:04x}'))),
        ('len',     atom(('>H', '0x{:04x}'))),
        ('mid',     atom(('B',  '0x{:02x}'))),
    ]))


########################################################################
#
# Gps Raw decode messages
#
# warning GPS messages are big endian.  The surrounding header (the dt header
# etc) is little endian (native order).
#

# navdata (2)
def obj_sirf_nav():
    return aggie(OrderedDict([
        ('xpos',  atom(('>i', '{}'))),
        ('ypos',  atom(('>i', '{}'))),
        ('zpos',  atom(('>i', '{}'))),
        ('xvel8', atom(('>h', '{}'))),
        ('yvel8', atom(('>h', '{}'))),
        ('zvel8', atom(('>h', '{}'))),
        ('mode1', atom(('B', '0x{:02x}'))),
        ('hdop5', atom(('B', '0x{:02x}'))),
        ('mode2', atom(('B', '0x{:02x}'))),
        ('week10',atom(('>H', '{}'))),
        ('tow100',atom(('>I', '{}'))),
        ('nsats', atom(('B', '{}'))),
        ('prns',  atom(('12s', '{}', binascii.hexlify))),
    ]))


# navtrack (4)
def obj_sirf_navtrk():
    return aggie(OrderedDict([
        ('week10', atom(('>H', '{}'))),
        ('tow100', atom(('>I', '{}'))),
        ('chans',  atom(('B',  '{}'))),
    ]))


def obj_sirf_navtrk_chan():
    return aggie(OrderedDict([
        ('sv_id',    atom(('B',  '{:2}'))),
        ('sv_az23',  atom(('B',  '{:3}'))),
        ('sv_el2',   atom(('B',  '{:3}'))),
        ('state',    atom(('>H', '0x{:04x}'))),
        ('cno0',     atom(('B',  '{}'))),
        ('cno1',     atom(('B',  '{}'))),
        ('cno2',     atom(('B',  '{}'))),
        ('cno3',     atom(('B',  '{}'))),
        ('cno4',     atom(('B',  '{}'))),
        ('cno5',     atom(('B',  '{}'))),
        ('cno6',     atom(('B',  '{}'))),
        ('cno7',     atom(('B',  '{}'))),
        ('cno8',     atom(('B',  '{}'))),
        ('cno9',     atom(('B',  '{}'))),
    ]))


# swver (6), its special
def obj_sirf_swver():
    return atom_sirf_swver(('', '--<{}>--  --<{}>--'))


# clock status (7)
def obj_sirf_clock_status():
    return aggie(OrderedDict([
        ('week_x',   atom(('>h', '{}'))),
        ('tow100',   atom(('>I', '{}'))),
        ('nsats',    atom(('B', '{}'))),
        ('drift',    atom(('>I', '{}'))),
        ('bias',     atom(('>I', '{}'))),
        ('est_time', atom(('>I', '{}'))),
    ]))


# sat vis (13)
def obj_sirf_vis():
    return aggie(OrderedDict([
        ('vis_sats', atom(('B',  '{}'))),
    ]))

def obj_sirf_vis_azel():
    return aggie(OrderedDict([
        ('sv_id',    atom(('B',  '{}'))),
        ('sv_az',    atom(('>h', '{}'))),
        ('sv_el',    atom(('>h', '{}'))),
    ]))


# almanac data (14)
def obj_sirf_alm_data():
    return aggie(OrderedDict([
        ('sv_id',               atom(('B',   '{}'))),
        ('alm_week_status',     atom(('>H',  '0x{:04x}'))),
        ('data',                atom(('24s', '{}', binascii.hexlify))),
        ('checksum',            atom(('>H',  '0x{:04x}'))),
    ]))


# ephemeris data (15)
def obj_sirf_ephem_data():
    return aggie(OrderedDict([
        ('sv_id',               atom(('B',   '{}'))),
        ('data',                atom(('90s', '{}', binascii.hexlify))),
    ]))


# OkToSend (18)
def obj_sirf_ots():
    return atom(('B', '{}'))


# NavParams (19)
def obj_sirf_nav_params():
    return aggie(OrderedDict([
        ('rsvd0',               atom(('>H', '0x{:04x}'))),
        ('pos_calc_mode',       atom(('B',  '0x{:02x}'))),
        ('alt_hold_mode',       atom(('B',  '0x{:02x}'))),
        ('alt_hold_src',        atom(('B',  '0x{:02x}'))),
        ('alt_src_input',       atom(('>h', '0x{:04x}'))),
        ('degraded_mode',       atom(('B',  '0x{:02x}'))),
        ('degraded_timeout',    atom(('B',  '{}'))),
        ('dr_timeout',          atom(('B',  '{}'))),
        ('track_smooth_mode',   atom(('B',  '0x{:02x}'))),
        ('static_nav',          atom(('B',  '0x{:02x}'))),
        ('3sv_least',           atom(('B',  '0x{:02x}'))),
        ('rsvd1',               atom(('>I', '0x{:04x}'))),
        ('dop_mask_mode',       atom(('B',  '0x{:02x}'))),
        ('nav_ele_mask',        atom(('>h', '0x{:04x}'))),
        ('nav_pwr_mask',        atom(('B',  '{}'))),
        ('rsvd2',               atom(('>I', '0x{:04x}'))),
        ('dgps_source',         atom(('B',  '0x{:02x}'))),
        ('dgps_mode',           atom(('B',  '0x{:02x}'))),
        ('dgps_timeout',        atom(('B',  '0x{:02x}'))),
        ('rsvd3',               atom(('>I', '0x{:04x}'))),
        ('lp_push_2_fix',       atom(('B',  '0x{:02x}'))),
        ('lp_on_time',          atom(('>i', '0x{:04x}'))),
        ('lp_interval',         atom(('>i', '{}'))),
        ('user_tasks_ena',      atom(('B',  '0x{:02x}'))),
        ('user_task_int',       atom(('>i', '0x{:04x}'))),
        ('lp_pwr_cycling',      atom(('B',  '0x{:02x}'))),
        ('lp_max_acq_srch',     atom(('>I', '0x{:04x}'))),
        ('lp_max_off_time',     atom(('>I', '0x{:04x}'))),
        ('apm_pwr_duty',        atom(('B',  '0x{:02x}'))),
        ('num_fixes',           atom(('>H', '0x{:04x}'))),
        ('time_btwn_fixes',     atom(('>H', '0x{:04x}'))),
        ('hve_max',             atom(('B',  '0x{:02x}'))),
        ('rsp_time_max',        atom(('B',  '0x{:02x}'))),
        ('time_acq_duty_prio',  atom(('B',  '0x{:02x}'))),
    ]))


# NavLib measData (28)
def obj_sirf_nl_measData():
    return aggie(OrderedDict([
        ('channel',             atom(( 'B', '{}'))),
        ('timeTag',             atom(('>I', '{}'))),
        ('satId',               atom(( 'B', '{}'))),
        ('gpsTime',             atom(('>Q', '{}'))),
        ('pseudo',              atom(('>Q', '{}'))),
        ('carrier',             atom(('>I', '{}'))),
        ('phase',               atom(('>Q', '{}'))),
        ('timeTrack',           atom(('>H', '{}'))),
        ('syncFlags',           atom(( 'B', '{}'))),
        ('cno0',                atom(( 'B', '{}'))),
        ('cno1',                atom(( 'B', '{}'))),
        ('cno2',                atom(( 'B', '{}'))),
        ('cno3',                atom(( 'B', '{}'))),
        ('cno4',                atom(( 'B', '{}'))),
        ('cno5',                atom(( 'B', '{}'))),
        ('cno6',                atom(( 'B', '{}'))),
        ('cno7',                atom(( 'B', '{}'))),
        ('cno8',                atom(( 'B', '{}'))),
        ('cno9',                atom(( 'B', '{}'))),
        ('deltaRange',          atom(('>H', '{}'))),
        ('meanDelta',           atom(('>H', '{}'))),
        ('extrap',              atom(('>H', '{}'))),
        ('phaseErr',            atom(( 'B', '{}'))),
        ('lowPwr',              atom(( 'B', '{}'))),
    ]))

# NavLib dgpsData (29)
def obj_sirf_nl_dgpsData():
    return aggie(OrderedDict([
        ('satId',               atom(('>H', '{}'))),
        ('iod',                 atom(('>H', '{}'))),
        ('source',              atom(( 'B', '{}'))),
        ('pseudoCorr',          atom(('>I', '{}'))),
        ('pseudoRateCorr',      atom(('>I', '{}'))),
        ('corrAge',             atom(('>I', '{}'))),
        ('reserved0',           atom(('>I', '{}'))),
        ('reserved1',           atom(('>I', '{}'))),
    ]))

# NavLib svState (30)
def obj_sirf_nl_svState():
    return aggie(OrderedDict([
        ('satId',               atom(( 'B', '{}'))),
        ('gpsTime',             atom(('>Q', '{}'))),
        ('posX',                atom(('>Q', '{}'))),
        ('posY',                atom(('>Q', '{}'))),
        ('posZ',                atom(('>Q', '{}'))),
        ('velX',                atom(('>Q', '{}'))),
        ('velY',                atom(('>Q', '{}'))),
        ('velZ',                atom(('>Q', '{}'))),
        ('clockBias',           atom(('>Q', '{}'))),
        ('clockDrift',          atom(('>I', '{}'))),
        ('ephemFlag',           atom(( 'B', '{}'))),
        ('reserved0',           atom(('>I', '{}'))),
        ('reserved1',           atom(('>I', '{}'))),
        ('ionoDelay',           atom(('>I', '{}'))),
    ]))


# NavLib initData (31)
def obj_sirf_nl_initData():
    return aggie(OrderedDict([
        ('rsv0',                atom(( 'B', '{}'))),
        ('altMode',             atom(( 'B', '{}'))),
        ('altSrc',              atom(( 'B', '{}'))),
        ('altitude',            atom(('>I', '{}'))),
        ('degradedMode',        atom(( 'B', '{}'))),
        ('degradedTimeout',     atom(('>H', '{}'))),
        ('drTimeout',           atom(('>H', '{}'))),
        ('rsv1',                atom(('>H', '{}'))),
        ('trkSmoothMode',       atom(( 'B', '{}'))),
        ('rsv2',                atom(( 'B', '{}'))),
        ('rsv3',                atom(( 'B', '{}'))),
        ('rsv4',                atom(( 'B', '{}'))),
        ('rsv5',                atom(( 'B', '{}'))),
        ('dgpsSel',             atom(( 'B', '{}'))),
        ('dgpsTimeout',         atom(('>H', '{}'))),
        ('elevNavMask',         atom(('>H', '{}'))),
        ('rsv6',                atom(('>H', '{}'))),
        ('rsv7',                atom(( 'B', '{}'))),
        ('rsv8',                atom(('>H', '{}'))),
        ('rsv9',                atom(( 'B', '{}'))),
        ('rsv10',               atom(('>H', '{}'))),
        ('staticNavMode',       atom(( 'B', '{}'))),
        ('rsv11',               atom(('>H', '{}'))),
        ('posX',                atom(('>Q', '{}'))),
        ('posY',                atom(('>Q', '{}'))),
        ('posZ',                atom(('>Q', '{}'))),
        ('posInitSrc',          atom(( 'B', '{}'))),
        ('gpsTime',             atom(('>Q', '{}'))),
        ('gpsWeek',             atom(('>H', '{}'))),
        ('timeInitSrc',         atom(( 'B', '{}'))),
        ('drift',               atom(('>Q', '{}'))),
        ('driftInitSrc',        atom(( 'B', '{}'))),
    ]))


# geodata (41)
def obj_sirf_geo():
    return aggie(OrderedDict([
        ('nav_valid',        atom(('>H', '0x{:04x}'))),
        ('nav_type',         atom(('>H', '0x{:04x}'))),
        ('week_x',           atom(('>H', '{}'))),
        ('tow1000',          atom(('>I', '{}'))),
        ('utc_year',         atom(('>H', '{}'))),
        ('utc_month',        atom(('B', '{}'))),
        ('utc_day',          atom(('B', '{}'))),
        ('utc_hour',         atom(('B', '{}'))),
        ('utc_min',          atom(('B', '{}'))),
        ('utc_ms',           atom(('>H', '{}'))),
        ('sat_mask',         atom(('>I', '0x{:08x}'))),
        ('lat',              atom(('>i', '{}'))),
        ('lon',              atom(('>i', '{}'))),
        ('alt_elipsoid',     atom(('>i', '{}'))),
        ('alt_msl',          atom(('>i', '{}'))),
        ('map_datum',        atom(('B', '{}'))),
        ('sog',              atom(('>H', '{}'))),
        ('cog',              atom(('>H', '{}'))),
        ('mag_var',          atom(('>H', '{}'))),
        ('climb',            atom(('>h', '{}'))),
        ('heading_rate',     atom(('>h', '{}'))),
        ('ehpe',             atom(('>I', '{}'))),
        ('evpe',             atom(('>I', '{}'))),
        ('ete',              atom(('>I', '{}'))),
        ('ehve',             atom(('>H', '{}'))),
        ('clock_bias',       atom(('>i', '{}'))),
        ('clock_bias_err',   atom(('>i', '{}'))),
        ('clock_drift',      atom(('>i', '{}'))),
        ('clock_drift_err',  atom(('>i', '{}'))),
        ('distance',         atom(('>I', '{}'))),
        ('distance_err',     atom(('>H', '{}'))),
        ('head_err',         atom(('>H', '{}'))),
        ('nsats',            atom(('B', '{}'))),
        ('hdop5',            atom(('B', '{}'))),
        ('additional_mode',  atom(('B', '0x{:02x}'))),
    ]))


# 56/5  Verified 50bps Bcast Ephemeris/Iono data
# has channel, svid, sub-frames 1, 2, 3 and possibly sub-frame 4.
#
# we currently don't know the structure of the sub-frames.  But for now we
# simply want to know if we are getting good ephemeris for the given
# satellite.  Simply receiving the 56/5 for the satellite tells us that.
#
# we ignore any data beyond channel and svid.

def obj_sirf_ee56_bcastEph():
    return aggie(OrderedDict([
        ('channel',          atom(('B',   '{}'))),
        ('svid',             atom(('B',   '{}'))),
        ('data',             atom(('40s', '{}', binascii.hexlify))),
    ]))

# 56/42 sifStatus (sifStat)
def obj_sirf_ee56_sifStat():
    return aggie(OrderedDict([
        ('sifState',            atom(('B',   '{}'))),
        ('cgeePredState',       atom(('B',   '{}'))),
        ('sifAiding',           atom(('B',   '{}'))),
        ('sgeeDwnLoad',         atom(('B',   '{}'))),
        ('cgeePredTimeLeft',    atom(('>I',  '{}'))),
        ('cgeePredPendingMask', atom(('>I',  '0x{:04x}'))),
        ('svidCGEEpred',        atom(('B',   '{}'))),
        ('sgeeAgeValidity',     atom(('B',   '{}'))),
        ('cgeeAgeValidity',     atom(('32s', '{}', binascii.hexlify))),
    ]))


# pwr_mode_rsp (90), has SID
def obj_sirf_pwr_mode_rsp():
    return aggie(OrderedDict([
        ('sid',              atom(('B', '{}'))),
        ('error',            atom(('>H', '0x{:02x}'))),
        ('reserved',         atom(('>H', '{}'))),
    ]))


# 56/42 sifStatus (sifStat)
def obj_sirf_ee56_sifStat():
    return aggie(OrderedDict([
        ('sifState',            atom(('B',   '{}'))),
        ('cgeePredState',       atom(('B',   '{}'))),
        ('sifAiding',           atom(('B',   '{}'))),
        ('sgeeDwnLoad',         atom(('B',   '{}'))),
        ('cgeePredTimeLeft',    atom(('>I',  '{}'))),
        ('cgeePredPendingMask', atom(('>I',  '0x{:04x}'))),
        ('svidCGEEpred',        atom(('B',   '{}'))),
        ('sgeeAgeValidity',     atom(('B',   '{}'))),
        ('cgeeAgeValidity',     atom(('32s', '{}', binascii.hexlify))),
    ]))


# tcxo, 93/{1,2}
def obj_tcxo93_clkModel():                              # 93/1
    return aggie(OrderedDict([
        ('source',           atom(('B',  '0x{:02x}'))),
        ('ageRateUncert10',  atom(('B',  '{}'))),       # 0.1 scale
        ('initOffUncert10',  atom(('B',  '{}'))),
        ('spare0',           atom(('B',  '{}'))),
        ('clkDrift',         atom(('>i', '{}'))),
        ('tempUncert',       atom(('>H', '{}'))),
        ('mfgWeek',          atom(('>H', '{}'))),
        ('spare1',           atom(('>I', '{}'))),
    ]))


def obj_tcxo93_tempTable():                             # 93/2
    return aggie(OrderedDict([
        ('spare1',           atom(('>H', '{}'))),
        ('offset',           atom(('>h', '{}'))),
        ('globalMin',        atom(('>h', '{}'))),
        ('globalMax',        atom(('>h', '{}'))),
        ('firstWeek',        atom(('>H', '{}'))),
        ('lastWeek',         atom(('>H', '{}'))),
        ('lsb',              atom(('>H', '{}'))),
        ('agingBin',         atom(('B',  '{}'))),
        ('agingUpCnt',       atom(('>b',  '{}'))),
        ('binCnt',           atom(('B',  '{}'))),
        ('spare2',           atom(('B',  '{}'))),
    ]))


# init_data_src (128)
def obj_sirf_init_data_src():
    return aggie(OrderedDict([
        ('ecef_x',           atom(('>i', '{}'))),
        ('ecef_y',           atom(('>i', '{}'))),
        ('ecef_z',           atom(('>i', '{}'))),
        ('clock_drift',      atom(('>i', '{}'))),
        ('tow100',           atom(('>I', '{}'))),
        ('week_x',           atom(('>H', '{}'))),
        ('chans',            atom(('B',  '{}'))),
        ('reset_config',     atom(('B',  '0x{:02x}'))),
    ]))


# almanac set (130)
def obj_sirf_alm_set():
    return aggie(OrderedDict([
        ('data',             atom(('892s', '{}', binascii.hexlify))),
    ]))


# ephemeris set (149)
def obj_sirf_ephem_set():
    return aggie(OrderedDict([
        ('data',             atom(('90s', '{}', binascii.hexlify))),
    ]))


# set msg rate (166)
def obj_sirf_set_msg_rate():
    return aggie(OrderedDict([
        ('mode',             atom(('B', '{}'))),
        ('mid',              atom(('B', '{}'))),
        ('rate',             atom(('B', '{}'))),
        ('rsvd0',            atom(('B', '{}'))),
        ('rsvd1',            atom(('B', '{}'))),
        ('rsvd2',            atom(('B', '{}'))),
        ('rsvd3',            atom(('B', '{}'))),
    ]))


# HW Config Response
def obj_sirf_hw_conf_rsp():
    return aggie(OrderedDict([
        ('hw_config',        atom(('B',  '{}'))),
        ('nominal_upper',    atom(('B',  '{}'))),
        ('nominal_freq',     atom(('>I', '{}'))),
        ('nw_enhance',       atom(('B',  '{}'))),
    ]))


# pwr_mode_req (218), has SID
def obj_sirf_pwr_mode_req():
    return aggie(OrderedDict([
        ('sid',              atom(('B',  '{}'))),
        ('timeout',          atom(('B',  '{}'))),
        ('control',          atom(('B',  '{}'))),
        ('reserved',         atom(('>H', '{}'))),
    ]))


# statistics (225/6)
def obj_mid225_6_statistics():
    return aggie(OrderedDict([
        ('ttff_reset',      atom(('>H', '{}'))),
        ('ttff_aiding',     atom(('>H', '{}'))),
        ('ttff_nav',        atom(('>H', '{}'))),
        ('pae_n',           atom(('>i', '{}'))),
        ('pae_e',           atom(('>i', '{}'))),
        ('pae_d',           atom(('>i', '{}'))),
        ('time_aiding_err', atom(('>i', '{}'))),
        ('freq_aiding_err', atom(('>h', '{}'))),
        ('pos_unc_horz',    atom(('B',  '{}'))),
        ('pos_unc_vert',    atom(('>H', '{}'))),
        ('time_unc',        atom(('B',  '{}'))),
        ('freq_unc',        atom(('B',  '{}'))),
        ('n_aided_ephem',   atom(('B',  '{}'))),
        ('n_aided_acq',     atom(('B',  '{}'))),
        ('nav_mode',        atom(('B',  '{}'))),
        ('pos_mode',        atom(('B',  '{}'))),
        ('status',          atom(('>H', '{}'))),
        ('start_mode',      atom(('B',  '{}'))),
        ('reserved',        atom(('B',  '{}'))),
    ]))


# dev_data, MID 255
# following the MID is ascii data, the length of the sirfbin
# packet tells how long this string is.  The buffer contains
# the string followed by chksum and terminating sequence.

def obj_sirf_dev_data():
    return atom_sirf_dev_data(('', '{}'))


########################################################################
#
# Sirf Decoders
#
########################################################################

sirf_navtrk_chan = obj_sirf_navtrk_chan()

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


sirf_vis_azel = obj_sirf_vis_azel()

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


# process extended ephemeris packets
# buf is pointing at the SID.
def decode_sirf_sid_dispatch(level, offset, buf, obj, table, table_name):
    consumed = 1                        # account for sid
    sid = buf[0]
    v   = table.get(sid, (None, None, None, 'sid/' + str(sid), ''))
    decoder  = v[EE_DECODER]
    obj      = v[EE_OBJECT]
    sid_name = v[EE_NAME]
    if not decoder:
        if (level >= 5):
            print('*** no decoder/obj defined for sid {}'.format(sid))
        return consumed
    try:
        consumed = consumed + \
                decoder(level, offset, buf[consumed:], obj)
    except struct.error:
        print
        print('*** decode error: {}: sid {} {}, @{}'.format(table_name,
            sid, sid_name, rec_offset))
    return consumed

def decode_sirf_ee56(level, offset, buf, obj):
    return decode_sirf_sid_dispatch(level, offset, buf, obj, sirf.ee56_table, 'sirf_ee56')

def decode_sirf_nl64(level, offset, buf, obj):
    return decode_sirf_sid_dispatch(level, offset, buf, obj, sirf.nl64_table, 'sirf_nl64')

def decode_sirf_stat70(level, offset, buf, obj):
    return decode_sirf_sid_dispatch(level, offset, buf, obj, sirf.stat70_table, 'sirf_stat70')

def decode_tcxo93(level, offset, buf, obj):
    return decode_sirf_sid_dispatch(level, offset, buf, obj, sirf.tcxo93_table, 'tcxo93')

def decode_sirf_stat212(level, offset, buf, obj):
    return decode_sirf_sid_dispatch(level, offset, buf, obj, sirf.ee212_table, 'sirf_stat212')

def decode_tcxo221(level, offset, buf, obj):
    return decode_sirf_sid_dispatch(level, offset, buf, obj, sirf.tcxo221_table, 'tcxo221')

def decode_mid225(level, offset, buf, obj):
    return decode_sirf_sid_dispatch(level, offset, buf, obj, sirf.mid225_table, 'mid225')

def decode_sirf_ee232(level, offset, buf, obj):
    return decode_sirf_sid_dispatch(level, offset, buf, obj, sirf.ee232_table, 'sirf_ee232')
