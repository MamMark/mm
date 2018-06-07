# Copyright (c) 2018, Eric B. Decker
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

'''Panic headers'''

__version__ = '0.3.2'

import binascii
from   collections  import OrderedDict

from   base_objs    import *
from   core_headers import obj_rtctime
from   core_headers import obj_image_info

panic_codes = {
    16: 'PANIC_Time',
    17: 'PANIC_ADC',
    18: 'PANIC_SD',
    19: 'PANIC_FileSys',
    20: 'PANIC_DblkManager',
    21: 'PANIC_ImageManager',
    22: 'PANIC_StreamStorage',
    23: 'PANIC_SS_RECOV',
    24: 'PANIC_GPS',
    25: 'PANIC_Misc',
    26: 'PANIC_Sensor',
    27: 'PANIC_PWR',
    28: 'PANIC_Radio',
    29: 'PANIC_Tagnet',

    112: 'PANIC_Excep',                # 0x70
    113: 'PANIC_Kern',                 # 0x71
    114: 'PANIC_Driver',               # 0x72
}


PANIC_DIR_SIG       = 0xDDDDB00B
PANIC_INFO_SIG      = 0x44665041
CRASH_INFO_SIG      = 0x4349B00B
CRASH_CATCHER_SIG   = 0x63430200
PANIC_ADDITIONS     = 0x44664144


def obj_panic_dir():
    return aggie(OrderedDict([
        ('panic_dir_id',          atom(('4s', '{}'))),
        ('panic_dir_sig',         atom(('<I', '{:x}'))),
        ('panic_dir_sector',      atom(('<I', '{}'))),
        ('panic_high_sector',     atom(('<I', '{}'))),
        ('panic_block_index',     atom(('<I', '{}'))),
        ('panic_block_index_max', atom(('<I', '{}'))),
        ('panic_block_size',      atom(('<I', '{}'))),
        ('panic_dir_checksum',    atom(('<I', '{}')))
    ]))


def obj_region():
    return aggie(OrderedDict([
        ('start',     atom(('<I', '{}'))),
        ('end',       atom(('<I', '{}')))
    ]))


def obj_panic_info():
    return aggie(OrderedDict([
        ('pi_sig',           atom(('<I', '{:04x}'))),
        ('boot_count',       atom(('<I', '{:2}'))),
        ('panic_count',      atom(('<I', '{:02}'))),
        ('rt',               obj_rtctime()),
        ('pcode',            atom(('<B', '{:02}'))),
        ('where',            atom(('<B', '{:02}'))),
        ('arg_0',            atom(('<I', '{:08x}'))),
        ('arg_1',            atom(('<I', '{:08x}'))),
        ('arg_2',            atom(('<I', '{:08x}'))),
        ('arg_3',            atom(('<I', '{:08x}'))),
    ]))


def obj_crash_info():
    return aggie(OrderedDict([
        ('ci_sig',    atom(('<I', '{}'))),
        ('axLR',      atom(('<I', '{}'))),
        ('MSP',       atom(('<I', '{}'))),
        ('PSP',       atom(('<I', '{}'))),
        ('primask',   atom(('<I', '{}'))),
        ('basepri',   atom(('<I', '{}'))),
        ('faultmask', atom(('<I', '{}'))),
        ('control',   atom(('<I', '{}'))),
        ('cc_sig',    atom(('<I', '{}'))),
        ('flags',     atom(('<I', '{}'))),
        ('bxReg_0',   atom(('<I', '{}'))),
        ('bxReg_1',   atom(('<I', '{}'))),
        ('bxReg_2',   atom(('<I', '{}'))),
        ('bxReg_3',   atom(('<I', '{}'))),
        ('bxReg_4',   atom(('<I', '{}'))),
        ('bxReg_5',   atom(('<I', '{}'))),
        ('bxReg_6',   atom(('<I', '{}'))),
        ('bxReg_7',   atom(('<I', '{}'))),
        ('bxReg_8',   atom(('<I', '{}'))),
        ('bxReg_9',   atom(('<I', '{}'))),
        ('bxReg_10',  atom(('<I', '{}'))),
        ('bxReg_11',  atom(('<I', '{}'))),
        ('bxReg_12',  atom(('<I', '{}'))),
        ('bxSP',      atom(('<I', '{}'))),
        ('bxLR',      atom(('<I', '{}'))),
        ('bxPC',      atom(('<I', '{}'))),
        ('bxPSR',     atom(('<I', '{}'))),
        ('axPSR',     atom(('<I', '{}'))),
        ('fpRegs',    atom(('<32I', '{}'))),
        ('fpscr',     atom(('<I', '{}')))
    ]))


def obj_add_info():
    return aggie(OrderedDict([
        ('ai_sig',           atom(('<I', '{}'))),
        ('ram_sector',       atom(('<I', '{}'))),
        ('ram_size',         atom(('<I', '{}'))),
        ('io_sector',        atom(('<I', '{}'))),
        ('fcrumb_sector',    atom(('<I', '{}'))),
    ]))


def obj_panic_block_0():
    return aggie(OrderedDict([
        ('panic_info', obj_panic_info()),
        ('image_info', obj_image_info()),
        ('add_info',   obj_add_info()),
        ('padding',    atom(('13I', '{}'))),
        ('crash_info', obj_crash_info()),
        ('ram_header', obj_region())
    ]))
