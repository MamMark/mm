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

__version__ = '0.4.5'

import binascii
from   collections  import OrderedDict

from   base_objs    import *
from   core_headers import obj_rtctime
from   core_headers import obj_image_info
from   core_headers import obj_owcb

panic_codes = {
    16: 'PANIC_Time',
    17: 'PANIC_ADC',
    18: 'PANIC_SD',
    19: 'PANIC_FileSys',
    20: 'PANIC_DblkManager',
    21: 'PANIC_ImageManager',
    22: 'PANIC_StreamStorage',
    23: 'PANIC_PAN',
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
CRASH_CATCHER_SIG   = 0x63430300
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
        ('base_addr',        atom(('<I', '{:04x}'))),
        ('rt',               obj_rtctime()),
        ('pi_pcode',         atom(('<B', '{}'))),
        ('pi_where',         atom(('<B', '{}'))),
        ('pi_arg0',          atom(('<I', '{}'))),
        ('pi_arg1',          atom(('<I', '{}'))),
        ('pi_arg2',          atom(('<I', '{}'))),
        ('pi_arg3',          atom(('<I', '{}'))),
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

'''
Define the IO memory items we need
see tos/platforms/mm6a/hardware/panic_regions.h
'''
def obj_io_info():
    return aggie(OrderedDict([
        ('Timer_A0',      atom(('=48s', '{}'))),    #0x4000 0000
        ('Timer_A1',      atom(('=48s', '{}'))),    #0x4000 0400
        ('eUSCI_A0',      atom(('=32s', '{}'))),    #0x4000 1000
        ('eUSCI_A1',      atom(('=32s', '{}'))),    #0x4000 1400
        ('eUSCI_A2',      atom(('=32s', '{}'))),    #0x4000 1800
        ('eUSCI_A3',      atom(('=32s', '{}'))),    #0x4000 1C00
        ('eUSCI_B0',      atom(('=32s', '{}'))),    #0x4000 2000
        ('eUSCI_B1',      atom(('=32s', '{}'))),    #0x4000 2400
        ('eUSCI_B2',      atom(('=32s', '{}'))),    #0x4000 2800
        ('eUSCI_B3',      atom(('<32s', '{}'))),    #0x4000 2C00
        ('RTC_C',         atom(('=32s', '{}'))),    #0x4000 4400
        ('WDT_A',         atom(('=2s', '{}'))),      #0x4000 4800
        ('PortMap',       atom(('=2s', '{}'))),      #0x4000 5000
        ('P2Map_0',       atom(('=2s', '{}'))),      #0x4000 5010
        ('P3Map_0',       atom(('=2s', '{}'))),      #0x4000 5018
        ('P7Map_0',       atom(('=2s', '{}'))),      #0x4000 5038
        ('Timer32_1',     atom(('=8s', '{}'))),     #0x4000 C000
        ('Timer32_2',     atom(('=8s', '{}'))),     #0x4000 C020
        ('DMA_Channel',   atom(('=28s', '{}'))),      #0x4000 E000
        ('DMA_Control',   atom(('=28s', '{}'))),      #0x4000 F000
        ('ICSR',          atom(('<4s', '{}'))),       #0xE000 ED04
        ('VTOR',          atom(('=4s', '{}'))),       #0xE000 ED08
        ('SHCSR',         atom(('=4s', '{}'))),       #0xE000 ED24
        ('CFSR',          atom(('=4s', '{}'))),       #0xE000 ED28
        ('HFSR',          atom(('=4s', '{}'))),       #0xE000 ED2C
        ('DFSR',          atom(('=4s', '{}'))),       #0xE000 ED30
        ('MMFAR',         atom(('=4s', '{}'))),       #0xE000 ED34
        ('BFAR',          atom(('=4s', '{}'))),       #0xE000 ED38
        ('AFSR',          atom(('=4s', '{}'))),       #0xE000 ED3C
    ]))

'''
I/O Register Memory Region Mapping Table
Requires *exact* same name as aggie defintion above
ARM7 specific
'''
io_reg_map = OrderedDict({
    'Timer_A0'     : 0x40000000,
    'Timer_A1'     : 0x40000400,
    'eUSCI_A0'     : 0x40001000,
    'eUSCI_A1'     : 0x40001400,
    'eUSCI_A2'     : 0x40001800,
    'eUSCI_A3'     : 0x40001C00,
    'eUSCI_B0'     : 0x40002000,
    'eUSCI_B1'     : 0x40002400,
    'eUSCI_B2'     : 0x40002800,
    'eUSCI_B3'     : 0x40002C00,
    'RTC_C'        : 0x40004400,
    'WDT_A'        : 0x40004800,
    'PortMap'      : 0x40005000,
    'P2Map_0'      : 0x40005010,
    'P3Map_0'      : 0x40005018,
    'P7Map_0'      : 0x40005080,
    'Timer32_1'    : 0x4000C000,
    'Timer32_2'    : 0x4000C020,
    'DMA_Channel'  : 0x4000E000,
    'DMA_Control'  : 0x4000F000,
    'ICSR'         : 0xE000ED04,
    'VTOR'         : 0xE000ED08,
    'SHCSR'        : 0xE000ED24,
    'CFSR'         : 0xE000ED28,
    'HFSR'         : 0xE000ED2C,
    'DFSR'         : 0xE000ED30,
    'MMFAR'        : 0xE000ED34,
    'BFAR'         : 0xE000ED38,
    'AFSR'         : 0xE000ED3C,
})

'''
Define the System Control Block data needed in panic
'''
def obj_scb_info():
    return aggie(OrderedDict([
        ('CFSR',      atom(('<I', '{}'))),    #0xE000ED28
        ('HFSR',      atom(('<I', '{}'))),    #0xE000ED2C
        ('DFSR',      atom(('<I', '{}'))),    #0xE000ED30
        ('MMFAR',     atom(('<I', '{}'))),    #0xE000ED34
        ('BFAR',      atom(('<I', '{}'))),    #0xE000ED38
    ]))

def obj_add_info():
    return aggie(OrderedDict([
        ('ai_sig',           atom(('<I', '{}'))),
        ('ram_offset',       atom(('<I', '{}'))),
        ('ram_size',         atom(('<I', '{}'))),
        ('io_offset',        atom(('<I', '{}'))),
        ('fcrumb_offset',    atom(('<I', '{}'))),
    ]))


def obj_panic_zero_0():
    return obj_panic_hdr0()

def obj_panic_hdr0():
    return aggie(OrderedDict([
        ('panic_info',   obj_panic_info()),
        ('owcb_info',    obj_owcb()),
        ('image_info',   obj_image_info()),
        ('add_info',     obj_add_info()),
        ('ph0_checksum', atom(('<I',  '{:08x}'))),
    ]))


def obj_panic_zero_1():
    return obj_panic_hdr1()

def obj_panic_hdr1():
    return aggie(OrderedDict([
        ('ph1_sig',      atom(('<I',  '{:08x}'))),
        ('core_rev',     atom(('<H',  '{}'))),
        ('core_minor',   atom(('<H',  '{}'))),
        ('pad',          atom(('58I', '{}'))),
        ('ph0_offset',   atom(('<I',  '{:08x}'))),
        ('ph1_offset',   atom(('<I',  '{:08x}'))),
        ('ph1_checksum', atom(('<I',  '{:08x}'))),
        ('ram_checksum', atom(('<I',  '{:08x}'))),
        ('io_checksum',  atom(('<I',  '{:08x}'))),
        ('crash_info',   obj_crash_info()),
        ('ram_header',   obj_region()),
    ]))
