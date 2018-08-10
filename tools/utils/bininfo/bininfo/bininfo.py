#!/usr/bin/env python2
#
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
#
#   Usage: bininfo.py [ -h ] <filename>
#
#       <filename> the name of an EXE, with ELF
#           This file must contain an image_info struct.
#
#   -h
#       Help show this usage information
#

from __future__ import print_function
from   __init__                 import __version__ as VERSION

import sys
import argparse

from   elf import *
from   tagcore.base_objs    import *
from   tagcore.core_headers import *
import tagcore.imageinfo    as     iim

IMAGE_INFO_SIG = 0x33275401
IMAGE_INFO_OFFSET = 0x140

'''
Offsets into the ELF and .bin file(s) where the image_info struct should be located
ELF is used to find the image_info structure.  A valid ELF file is *required* to
make all this work.
'''

def find_image_info(bin_file):
    global IMAGE_INFO_OFFSET
    offset = False

    offset = IMAGE_INFO_OFFSET
    return offset

def panic_args():
    parser = argparse.ArgumentParser(
        description='BinInfo (BinInfo)')

    parser.add_argument('-v', '--version',
        action = "version",
        version = '%(prog)s ' + VERSION)

    parser.add_argument('bin_file',
                        type = argparse.FileType('rb'),
                        help = 'Bin file')

    return parser.parse_args()

########## main
def processMeta(argv):
    global elf_meta_offset, bin_meta_offset, args

    print('BinInfo')
    input = "main.exe"	#default file we look for
    args    = panic_args()

    inFile  = args.bin_file

    '''
    Load the ELF data and use the section information to find where the
    image_info is located.  Then they can move this around at will if
    needed
    '''
    elf = ELFObject()
    elfhdr = 0
    try:
        elfhdr = elf.fromFile(inFile)
        progs =  elf.getProgrammableSections()
        meta = elf.getSection('.image_meta')
        meta_offset = meta.sh_offset
        if meta_offset == 0:
            print("File Requires a valid image_info META structure")
            sys.exit(2)
    except:
        '''
        Ok.. We may have a BIN file.  Try rumaging in there to find
        the image_info
        '''
        inFile.seek(0)
        meta_offset = find_image_info(inFile)
        if meta_offset == False:
            print("File Requires a valid image_info META structure")
            sys.exit(2)

    inFile.seek(meta_offset)
    meta_raw = inFile.read()
    inFile.close()

    '''
    We found the image_info block so load it and validate
    '''
    imcls = iim.ImageInfo(meta_raw)
    print(imcls)

#
# Begin at Main
#
if __name__ == "__main__":
    processMeta(sys.argv[1:])
