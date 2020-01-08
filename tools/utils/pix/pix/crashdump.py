# Copyright (c) 2018 Rick Li Fo Sjoe
# Copyright (c) 2019 Eric B. Decker
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
# Contact: Rick Li Fo Sjoe <flyrlfs@gmail.com>
#

'''
CrashDump requires a fileformat different from the PanicDump the Tag
creates.  This struct defines the CrashCatcher format

Please visit https://github.com/adamgreen/CrashCatcher#dump-format for
details on this file format.
'''

from   __future__               import print_function
from   __init__                 import __version__ as VERSION

import sys
import struct
import zlib
from   collections  import OrderedDict

from   tagcore.base_objs    import *
from   tagcore.imageinfo    import *
from   tagcore.core_headers import *
from   tagcore.panic_headers import *

class CrashDumpFormat:
    global CRASH_CATCHER_SIG

    DEFAULT_BLOCK_SIZE = 512
    panic = None
    panic_raw = None
    panic_block0_obj = None
    panic_block1_obj = None

    CRASHDUMP_SIG = CRASH_CATCHER_SIG

    def __init__(self, panic, raw):
        self.panic = panic
        self.panic_raw = raw
        self.panic_block0_obj  = self.panic['pb']
        self.panic_block1_obj  = obj_panic_zero_1()
        self.panic_block1_obj.set(raw[self.DEFAULT_BLOCK_SIZE:])
        return

    def dump_build(self, outFile):
        panic_info = self.panic_block0_obj['panic_info']
        add_info   = self.panic_block0_obj['add_info']
        crash_info = self.panic_block1_obj['crash_info']
        if crash_info['ci_sig'] != CRASH_INFO_SIG:
            print('*** crash_info_sig_mismatch: wanted {:08x}, got {:08x}'.format(
                CRASH_INFO_SIG, crash_info['ci_sig'].val))

        image_info = self.panic['im']
        image_desc = image_info.getTLV(iip_tlv['desc'])
        rep0_desc = image_info.getTLV(iip_tlv['repo0'])
        out = "{}/{}/{} {}:{}:{}.{}\n{} {}".format(panic_info['rt']['mon'].val,
            panic_info['rt']['day'].val, panic_info['rt']['year'].val,
            panic_info['rt']['hr'].val, panic_info['rt']['min'].val,
            panic_info['rt']['sec'].val, panic_info['rt']['sub_sec'].val,
            image_desc, rep0_desc)
        out += "\n"
        print(out)
        print(image_info)

        ci_sig      = (crash_info['ci_sig'].val)
        cc_sig      = (crash_info['cc_sig'].val)
        cc_flags    = (crash_info['flags'].val)
        bxReg_0     = (crash_info['bxReg_0'].val)
        bxReg_1     = (crash_info['bxReg_1'].val)
        bxReg_2     = (crash_info['bxReg_2'].val)
        bxReg_3     = (crash_info['bxReg_3'].val)
        bxReg_4     = (crash_info['bxReg_4'].val)
        bxReg_5     = (crash_info['bxReg_5'].val)
        bxReg_6     = (crash_info['bxReg_6'].val)
        bxReg_7     = (crash_info['bxReg_7'].val)
        bxReg_8     = (crash_info['bxReg_8'].val)
        bxReg_9     = (crash_info['bxReg_9'].val)
        bxReg_10    = (crash_info['bxReg_10'].val)
        bxReg_11    = (crash_info['bxReg_11'].val)
        bxReg_12    = (crash_info['bxReg_12'].val)
        bxSP        = (crash_info['bxSP'].val)
        bxLR        = (crash_info['bxLR'].val)
        bxPC        = (crash_info['bxPC'].val)
        bxPSR       = (crash_info['bxPSR'].val)
        bxMSP	     = (crash_info['MSP'].val)
        bxPSP	     = (crash_info['PSP'].val)
        axPSR       = (crash_info['axPSR'].val)

        ai_sig      = (add_info['ai_sig'].val)
        ii_block    = ImageInfo(image_info.build())

        ram_offset  = (add_info['ram_offset'].val) - self.panic['offset']
        ram_sector  = (ram_offset / self.DEFAULT_BLOCK_SIZE)
        ram_size    = (add_info['ram_size'].val)
        io_offset  = (add_info['io_offset'].val) - self.panic['offset']
        io_sector = io_offset / self.DEFAULT_BLOCK_SIZE
        crumb_offset= (add_info['fcrumb_offset'].val) - self.panic['offset']

        '''
        WRite the CrashDump 0x6343 (Cc) Signature
        NOTE: We override the panic dump cc_sig.  We need 0300 for
            version otherwise CrashDebug complains with ENODEV
        '''
        global CRASH_CATCHER_SIG
        outFile.write("{:08X}".format(CRASH_CATCHER_SIG))
        outFile.write("\n")

        #Floating Point Regs do *not* follow registers
        outFile.write("{:08X}".format(0))
        '''
        For new we exclude FP regs from the dump --TODO--
        outFile.write("{:08X}".format(1 << 24))
        '''
        outFile.write("\n")

        #Dump Registers
        regs_1      = [bxReg_0,bxReg_1,bxReg_2,bxReg_3]
        regs_2      = [bxReg_4,bxReg_5,bxReg_6,bxReg_7]
        regs_3      = [bxReg_8,bxReg_9,bxReg_10,bxReg_11]
        regs_4      = [bxReg_12]
        regs_5	     = [bxSP]
        regs_6	     = [bxLR, bxPC, bxPSR]
        regs_7	     = [bxMSP, bxPSP, axPSR]
        for b in regs_1:
            val = struct.pack(">I", b)
            val = struct.unpack("<I", val)[0]
            outFile.write("{:08X}".format(val))
        outFile.write("\n")
        for b in regs_2:
            val = struct.pack(">I", b)
            val = struct.unpack("<I", val)[0]
            outFile.write("{:08X}".format(val))
        outFile.write("\n")
        for b in regs_3:
            val = struct.pack(">I", b)
            val = struct.unpack("<I", val)[0]
            outFile.write("{:08X}".format(val))
        outFile.write("\n")
        for b in regs_4:
            val = struct.pack(">I", b)
            val = struct.unpack("<I", val)[0]
            outFile.write("{:08X}".format(val))
        outFile.write("\n")
        for b in regs_5:
            val = struct.pack(">I", b)
            val = struct.unpack("<I", val)[0]
            outFile.write("{:08X}".format(val))
        outFile.write("\n")
        for b in regs_6:
            val = struct.pack(">I", b)
            val = struct.unpack("<I", val)[0]
            outFile.write("{:08X}".format(val))
        outFile.write("\n")
        for b in regs_7:
            val = struct.pack(">I", b)
            val = struct.unpack("<I", val)[0]
            outFile.write("{:08X}".format(val))
        outFile.write("\n")

        '''
        Dump the RAM region
        '''
        ram_header = self.panic_block1_obj['ram_header']
        ram_start   = (ram_header['start'].val)
        ram_end     = (ram_header['end'].val)
        print("RAM: {:08X} - {:08X}".format(ram_start, ram_end))
        val = struct.pack(">I", ram_start)
        val = struct.unpack("<I", val)[0]
        outFile.write("{:08X}".format(val))
        val = struct.pack(">I", ram_end)
        val = struct.unpack("<I", val)[0]
        outFile.write("{:08X}".format(val))
        outFile.write("\n")

        rambytes = bytearray(self.panic_raw[ram_offset:])
        offset = 0
        while True:
            b = rambytes[offset]
            outFile.write("{:02X}".format(b))
            offset += 1
            if offset >= ram_size:
                break;
            if offset % 16 == 0:
                outFile.write("\n")
        outFile.write("\n")

        '''
        I/O Space... Do we dump this at all?
        '''
        global io_reg_map
        rambytes = self.panic_raw[io_offset:crumb_offset]
        io_info = obj_io_info()
        io_info.set(rambytes)
        for reg, addr in io_reg_map.items():
            iostart = addr
            reglen = len(io_info[reg])
            val = struct.pack(">I", addr)
            val = struct.unpack("<I", val)[0]
            outFile.write("{:08X}".format(val))
            ioend = addr+reglen
            val = struct.pack(">I", addr + reglen)
            val = struct.unpack("<I", val)[0]
            outFile.write("{:08X}".format(val))
            outFile.write("\n")
#            print("{} : {:08X} - {:08X}".format(reg, iostart, ioend))

            charcount = 0
            reg_data = io_info[reg].val
            reg_data = bytearray(reg_data)
            for c in reg_data:
                outFile.write("{:02X}".format(c))
                charcount += 1
                if charcount % 16 == 0:
                    outFile.write("\n")
            if charcount % 16 != 0:
                outFile.write("\n")

        '''
        Dump the Crumbs region  --TODO--
        outFile.write("{:08X}".format(ram_start))
        outFile.write("{:08X}".format(ram_end))
        outFile.write("\n")

        fcrumb_offset = add_info['fcrumb_offset'].val
        fcrumb_pb_offset = fcrumb_offset - self.panic['offset']
        rambytes = bytearray(self.panic_raw[fcrumb_pb_offset:len(self.panic_raw)])
        offset = 0
        while True:
            b = rambytes[offset]
            outFile.write("{:02X}".format(b))
            offset += 1
            if offset >= ram_size:
                break;
            if offset % 16 == 0:
                outFile.write("\n")
        outFile.write("\n")
        '''

        return
