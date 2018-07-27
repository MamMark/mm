# Copyright (c) 2018 Rick Li Fo Sjoe
# Copyright (c) 2018 Eric B. Decker
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
# ImageInfo Class
#
#   Manage all aspects of the ImageInfo structure, given a
#   byte array that conforms to the ImageInfo definitions.
#

#from   __future__         import print_function

__version__ = '0.4.5rc0'

import sys
import struct
import datetime
import zlib
from   collections  import OrderedDict
from   base_objs    import *
from   core_headers import *

class ImageInfo:
    IMAGE_INFO_SIG = 0x33275401

    '''
    im_basic: will hold a obj_image_info struct from core_headers
        obj_image_info consists of:
            image_info_basic structure
            image_inf_plus
                tlv_block_len (2-byte) value of the remaining im_plus
        im_tlv_block_len is set during the MM build phase.  It is not altered.
            it determines the maximum size of the available space for TLV rows
        im_total_len is calculated based on the image_info size + im_tlv_block_len
    '''
    im_basic = None
    im_plus = None
    im_tlv_rows = None
    im_tlv_block_len = 0
    im_total_len = 0

    def __init__(self, rec_buf):
        self.im_basic = obj_image_info()
        corelen = self.im_basic.set(rec_buf)
        if self.im_basic['basic']['ii_sig'].val != self.IMAGE_INFO_SIG:
            print "Image Signature Check FAIL. Expect %X got %X" % (self.IMAGE_INFO_SIG, self.im_basic['basic']['ii_sig'].val)
            sys.exit(2)

        #We set checksum to 0 since we calc. a new checksum every time
        self.im_basic['basic']['im_chk'].val = 0

        self.im_tlv_rows = self.im_basic['plus']
        self.im_tlv_block_len = int(self.im_basic['plus']['tlv_block_len'].val)
        return

    def __repr__(self):
        ver_id = self.im_basic['basic']['ver_id']
        hw_ver = self.im_basic['basic']['hw_ver']
        chksum = self.im_basic['basic']['im_chk'].val
        out  = "image_info_data:\n"
        out += 'sw_ver\t: {}.{}.{} (0x{:x})\n'.format(ver_id['major'],
                    ver_id['minor'], ver_id['build'], ver_id['build'].val)
        out += 'hw_m/r\t: {}/{}\n'.format(
            hw_ver['model'], hw_ver['rev'])
        out += 'chksum\t: {:08x}\n'.format(chksum)
        for k,tlv in self.im_tlv_rows.get_tlv_rows():
            type = self._iipGetKeyByValue(k)
            out += "%s\t: %s\n" % (type, tlv.tlv_value)
        return out

    def _iipGetKeyByValue(self, val):
        for k, v in iip_tlv.items():
            if v == val:
                return k
        return "*N.A.*(%d)" % val

    def updateBasic(self, field, value):
        self.im_basic['basic'][field].val = value
        return

    '''
    setTLV() - Called to add/update a TLV in the 'image_info_plus'
    '''
    def setTLV(self, type, value):
        consumed = self.im_tlv_rows.add_tlv(type, value)
        return consumed

    def getTotalLength(self):
        return self.im_total_len

    '''
    build() - Called to reconstruct a byte array from the image_info
        components we've stored in this class.  Useful for plugging into
        ELF or .bin files
    '''
    def build(self):
        im_basic_out = self.im_basic.build()
        im_plus_out = self.im_tlv_rows.build_tlv()

        '''
        Now ZERO the remaining chunk of the TLV block Puts the 'end' TLV back
        '''
        im_plus_out += '\0' * (self.im_tlv_block_len - len(im_plus_out))
        self.im_total_len = len(im_basic_out) + len(im_plus_out)
        return im_basic_out+im_plus_out
