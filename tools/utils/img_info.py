#!/usr/bin/env python2
#
# Copyright (c) 2018 Daniel J. Maltbie
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
#
#
#  IMAGE_INFO provides information about a Tag software image. This data is
#  embedded in the image itself. The IMAGE_META_OFFSET is the offset into
#  the image where image_info lives in the image.  It directly follows the
#  exception vectors which are 0x140 bytes long.
#

from   tagcore.imageinfo_defs import *

#
# Struct created for accessing image info (little indian)
# sig, image_start, imagelength, vector_chk, image_chk, im_build, im_minor,
# im_major, main_tree, aux_tree, build_time, im_rev, im_model = image_info
#
IM_FIELDS = '<LLLLLHBB44s44s30sBB'
image_info_struct = pystruct.Struct(IM_FIELDS)
IMAGE_MIN_SIZE  =  (IMAGE_META_OFFSET + image_info_struct.size)

FILENAME    = 'main.bin'

def _file_size(fd):
    fd.seek(0, 2) # seek to the end
    _size = fd.tell()
    if _size < IMAGE_MIN_SIZE: raise RadioLoadException("input file too short")
    fd.seek(0, 0)    # seek to the beginnnig
    return _size

def get_image_info(filename):
    print(filename)
    infile = open(filename, 'rb')
    file_size = _file_size(infile)

    # get image info from input file and sanity check
    infile.seek(IMAGE_META_OFFSET) # seek to location of image info
    image_info = image_info_struct.unpack(infile.read(image_info_struct.size))
    print("file information")
    sig, image_start, imagelength, vector_chk, image_chk, im_build, im_minor, im_major,\
            main_tree, aux_tree, build_time, im_rev, im_model = image_info
    pstr = "  signature: 0x{:x}, start: 0x{:x}, length: 0x{:x}, vect_chk: 0x{:x}, image_chk: 0x{:x}"
    print(pstr.format(sig, image_start, imagelength, vector_chk, image_chk))
    pstr = "  version: ({}.{}.{}(0x{:x})), rev: {}, model: {}"
    print(pstr.format(im_major, im_minor, im_build, im_build, im_rev, im_model))
    if sig != IMAGE_INFO_SIG:
        raise RadioLoadException("image info is corrupted")
    if imagelength != file_size:
        raise RadioLoadException("file size doesn't match image info, file: {}, info: {}".format(
            file_size, imageLength))
    infile.seek(0)    # seek back to the beginnnig
    return (infile, (im_major, im_minor, im_build), imagelength)
