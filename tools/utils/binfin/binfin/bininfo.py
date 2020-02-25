#!/usr/bin/env python2
#
# Copyright (c) 2020 Eric B. Decker
# Copyright (c) 2018 Rick Li Fo Sjoe
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
# BININFO : A tool to display the img_info struct at the beginning,
#	after the Vector Table.  The img_info struct conveys details
#	about this image needed for later forensic analysis

from   __future__ import print_function
from   __init__   import __version__ as VERSION

import sys
import argparse
import os

from   elf import *
import tagcore.globals        as     g
from   tagcore.base_objs      import *
from   tagcore.imageinfo_defs import *
from   tagcore.imageinfo      import ImageInfo
from   tagcore.misc_utils     import eprint
from   tagcore.misc_utils     import dump_buf

'''
Offsets into the ELF and .bin file(s) where the image_info struct should be located
ELF is used to find the image_info structure.  A valid ELF file is *required* to
make all this work.
'''

def find_image_info(bin_file):
    return IMAGE_META_OFFSET

def bininfo(filename):
    global elf_meta_offset, bin_meta_offset

    if os.access(filename, os.R_OK) == False:
        eprint("need read access to {}.".format(filename))
        sys.exit(2)
    print('\nimage_info:')
    inFile = open(filename)
    #
    # Load the ELF data and use the section information to find where the
    # image_info is located.  Then they can move this around at will if
    # needed
    #
    elf = ELFObject()
    elfhdr = 0
    try:
        elfhdr = elf.fromFile(inFile)
        progs =  elf.getProgrammableSections()
        meta = elf.getSection('.image_meta')
        meta_offset = meta.sh_offset
        if meta_offset == 0:
            eprint("can not find image_info meta data in {}".format(filename))
            sys.exit(2)
    except:
        #
        # Ok.. We may have a BIN file.  Try rumaging in there to find
        # the image_info
        #
        inFile.seek(0)
        meta_offset = find_image_info(inFile)
        if meta_offset == 0:
            eprint("no image_info Meta data found in {}".format(filename))
            sys.exit(2)

    inFile.seek(meta_offset)
    meta_raw = inFile.read(IMAGE_INFO_SIZE)
    inFile.close()
    if g.debug:
        dump_buf(meta_raw[:0x150])
        print()

    im_cls = ImageInfo(meta_raw)
    print(im_cls)
