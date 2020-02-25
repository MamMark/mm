# Copyright (c) 2018 Rick Li Fo Sjoe
# Copyright (c) 2018, 2020 Eric B. Decker
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
#          Eric B. Decker  <cire831@gmail.com>
#
# ImageInfo Class
#
#   Manage all aspects of the ImageInfo structure, given a
#   byte array that conforms to the ImageInfo definitions.
#

from   __future__         import print_function

__version__ = '0.4.7.dev4'

import sys
import struct
import zlib
from   collections          import OrderedDict
from   tagcore.core_headers import obj_image_info
from   misc_utils           import eprint
from   misc_utils           import dump_buf

import tagcore.globals        as     g
from   tagcore.imageinfo_defs import *
from   tagcore.imageinfo_defs import iip_tlv


class ImageInfo:
    '''
    im_info: will hold a obj_image_info object from core_headers
        obj_image_info consists of:
            image_info_basic structure
            image_info_plus
        im_byte_len is computed byte length of basic and plus objects.
    '''
    im_info         = None
    im_basic        = None
    im_plus         = None
    im_plus_len     = None
    im_byte_len     = None

    def __init__(self, rec_buf):
        self.im_info  = obj_image_info()
        self.im_basic = self.im_info['basic']   # obj_image_basic
        self.im_plus  = self.im_info['plus']    # tlv_block_aggie
        self.im_info.set(rec_buf)
        if self.im_basic['ii_sig'].val != IMAGE_INFO_SIG:
            eprint('*** image signature mismatch: expected {:08x}, got {:08x}'.format(
                IMAGE_INFO_SIG, self.im_basic['ii_sig'].val))
            sys.exit(2)
        self.im_plus_len = int(self.im_basic['im_plus_len'].val)
        self.im_plus.set_max(self.im_plus_len)
        return

    def __repr__(self):
        load_addr = self.im_basic['im_start'].val
        load_len  = self.im_basic['im_len'].val
        ver_id = self.im_basic['ver_id']
        hw_ver = self.im_basic['hw_ver']
        chksum = self.im_basic['im_chk'].val
        xtype = 'Golden' if load_addr == 0 else 'NIB' if load_addr == 0x20000 else 'UNK'
        out  = 'load\t: {:06d} (0x{:06x})     len    : {:06d} (0x{:06x})\t{}\n'.format(
            load_addr, load_addr, load_len, load_len, xtype)
        out += 'sw_ver\t: {}.{}.{}\t'.format(ver_id['major'],
                                             ver_id['minor'],
                                             ver_id['build'])
        out += '        hw_m/r : {}/{}\n'.format(
            hw_ver['model'], hw_ver['rev'])
        out += 'chksum\t: 0x{:08x}\n'.format(chksum)
        for k,tlv in self.im_plus.get_tlv_rows():
            tlv_type = self._iipGetKeyByValue(k)
            out += '{}\t: {}\n'.format(tlv_type, tlv['tlv_value'])
        return out

    def getPlusSize(self):
        '''
        return (cur, max) of the Plus area.
        '''
        return self.im_plus.getPlusSize()

    def setVersion(self, major, minor, build):
        self.im_basic['ver_id']['major'].val = int(major)
        self.im_basic['ver_id']['minor'].val = int(minor)
        self.im_basic['ver_id']['build'].val = int(build)

    def setChecksum(self, val):
        self.im_basic['im_chk'].val = val

    def _iipGetKeyByValue(self, val):
        for k, v in iip_tlv.items():
            if v == val:
                return k
        return 'tlv/{}'.format(val)

    def updateBasic(self, field, value):
        self.im_basic[field].val = value
        return

    def setTLV(self, tlv_type, value):
        '''
        setTLV() - Called to add/update a TLV in the 'image_info_plus'
        '''
        consumed = self.im_plus.add_tlv(tlv_type, value)
        return consumed

    def getTLV(self, tlv_type):
        for k, tlv in self.im_plus.get_tlv_rows():
            if tlv_type == k:
                return tlv.tlv_value
        return false

    def getByteLength(self):
        return self.im_byte_len

    def build(self):
        '''
        build() - builds a byte array from the image_info components stored
            in this class.  Result gets plugged into ELF or .bin files
        '''
        im_basic_out = self.im_basic.build()
        if g.debug:
            dump_buf(im_basic_out, '', 'bsc:  ')
            print()
        im_plus_out  = self.im_plus.build_tlv()
        if g.debug:
            dump_buf(im_plus_out,  '', 'pls:  ')
            print()

        # ZERO the remaining chunk of the TLV block Puts the 'end' TLV back
        im_plus_out += '\0' * (self.im_plus_len - len(im_plus_out))

        self.im_byte_len = len(im_basic_out) + len(im_plus_out)
        if self.im_byte_len != IMAGE_INFO_SIZE:
            raise RuntimeError('(imageinfo): meta size mismatch {} vs. {}'.format(
                self.im_byte_len, IMAGE_INFO_SIZE))
        return im_basic_out + im_plus_out
