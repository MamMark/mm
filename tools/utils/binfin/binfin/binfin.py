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
# BINFIN : A tool to update the img_info struct at the beginning,
#	after the Vector Table.  The img_info struct conveys details
#	about this image needed for later forensic analysis
#
#   Usage: binfin.py [-v] [ -h ] [ -d ] [ -V=<Major Version> ] [ -v=<Minor Version> ]
#       [ -I=<Img Desc.> ] [ -R=<Repo0 Desc.> ] [ -r=<Repo1 Desc.> ]
#       [ -t=<timestamp> ] [ -H=<HW Ver.>] [ -M=<Model> ] <filename>
#
#       <filename> the name of an EXE, with ELF
#           This file must contain an image_info struct.  This struct
#           will be updated with the information given in the arguments
#           below.  In addition, the image Checksum is updated to include
#           the addtion of the arguments below
#
#   -h
#       Help show this usage information
#
#   -d
#       debug mode [currently n.a.]
#
#   -V
#       Software major version # 16-bit HEX value [currently n.a.]
#
#   -v
#       Software minor version # 8-bit HEX value [currently n.a.]
#
#   -I
#       Image Description string (44 chars. max)
#
#   -R
#       Repo0 Description string (44 chars max)
#
#   -r
#       Repo1 Description string (44 chars max)
#
#   -t
#       Timestamp string (30 chars max)
#
#   -H
#       Hardware Version 8-bit HEX [currently n.a.]
#
#   -M
#       Model # 8-bit HEX [currently n.a.]
#

from __future__ import print_function

import sys
import getopt
import struct
import datetime
import zlib
from   collections import OrderedDict
import os.path
from   elf import *
from   tagcore.base_objs    import *
from   tagcore.core_headers import *
import tagcore.imageinfo    as     iim

'''
Offsets into the ELF and .bin file(s) where the image_info struct should be located
ELF is used to find the image_info structure.  A valid ELF file is *required* to
make all this work.
'''
elf_meta_offset = None
bin_meta_offset = None

debug = None

def save_imageinfo_exe(filename, img_info, img_length):
    global elf_meta_offset

    infile = open(filename, 'rb', 0)
    image_elf = infile.read()
    infile.close()

    image_elf = image_elf[:elf_meta_offset] + img_info + image_elf[elf_meta_offset + img_length:]
    outfile = open(filename, 'w+b')
    outfile.write(image_elf)
    outfile.close()

def save_imageinfo_bin(filename, img_info, img_length):
    global bin_meta_offset, debug

    try:
        infile = open(filename, 'rb', 0)
        image_bin = infile.read()
    except:
        return
    infile.close()

    if debug:
        print("BIN FN: {} -- 0X{:X} PADDR: 0X{:X} Length: {}".format(filename, len(image_bin), bin_meta_offset, img_length))

    image_bin = image_bin[:bin_meta_offset] + img_info + image_bin[bin_meta_offset + img_length:]

    outfile = open(filename, 'w+b')
    outfile.write(image_bin)
    outfile.close()

def calc_image_checksum(img):
    chksum = sum(bytearray(img))
    return chksum & 0xffffffff

def usage():
    print('Usage: '+sys.argv[0]+" [ -h ]")
    print("\t[ -I=<Img Desc.> ] [ -R=<Repo0 Desc.> ] [ -r=<Repo1 Desc.> ]")
    print("\t[ -t=<timestamp> ] <filename>")

########## main
def processMeta(argv):
    global elf_meta_offset, bin_meta_offset

    input = "main.exe"	#default file we look for
    output = ""
    c_out = False
    p_out = False
    try:
        opts, args = getopt.getopt(argv, "hdB:V:v:I:R:r:t:H:M:", ["help", "debug", "version"])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    if len(args) == 0:
        usage()
        sys.exit(2)

    filename = args[0]
    if os.path.isfile(filename) == False:
        usage()
        print("File {} must be a valid .exe".format(filename))
        sys.exit(2)

    # get image info from input file and sanity check
    infile = open(filename, 'rb', 0)
    image_elf = infile.read()
    infile.close()

    '''
    Load the ELF data and use the section information to find where the
    image_info is located.  Then they can move this around at will if
    needed
    '''
    elf = ELFObject()
    try:
        elfhdr = elf.fromFile(open(filename, 'rb', 0))
    except:
        usage()
        print("File {} Requires a valid ELF structure".format(filename))
        sys.exit(2)

    progs =  elf.getProgrammableSections()
    meta = elf.getSection('.image_meta')
    bin_meta_offset = meta.sh_addr
    elf_meta_offset = meta.sh_offset
    if elf_meta_offset == 0:
        usage()
        print("File {} Requires a valid image_info META structure".format(filename))
        sys.exit(2)

    '''
    We found the image_info block so load it and validate
    '''
    imcls = iim.ImageInfo(image_elf[elf_meta_offset:])
    block_update_success = True
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            usage()
            sys.exit(2)
        elif opt == '-d':
            global _debug
            debug = 1
        elif opt == '--version':   #Binfin version
            print("Binfin Version : {}".format(__version__))
        elif opt == '-I':   #Image Desc
            ttype = iip_tlv['desc']
            consumed = imcls.setTLV(ttype, arg)
        elif opt == '-R':   #Repo0 Desc
            ttype = iip_tlv['repo0']
            consumed = imcls.setTLV(ttype, arg)
        elif opt == '-r':   #Repo1 Desc
            ttype = iip_tlv['repo1']
            consumed = imcls.setTLV(ttype, arg)
        elif opt == '-t':   #TimeStamp
            ttype = iip_tlv['date']
            consumed = imcls.setTLV(ttype, arg)
        if consumed == 0:
            im_tlv_label = _iipGetKeyByValue(ttype)
            print("Desc {} Fail: Block Length violation".format(im_tlv_label))
            block_update_success = False
            break

    if block_update_success == False:
        sys.exit(2)

    text_offset = progs[0].p_offset
    text_size = progs[0].p_filesz
    data_offset = progs[1].p_offset
    data_size = progs[1].p_filesz

    '''
    First we update the Meta DATA checksum = 0
    '''
    imcls.updateBasic('im_chk', 0)
    oldim = imcls.build()
    oldim_length = imcls.getTotalLength()
    image_elf = image_elf[:elf_meta_offset] + oldim+image_elf[elf_meta_offset + oldim_length:]

    '''
    Second pass we update the Meta DATA *with* checksum
    '''
    binimg = image_elf[text_offset:text_offset+text_size] + image_elf[data_offset:data_offset+data_size]
    imgchksum = calc_image_checksum(binimg)
    imcls.updateBasic('im_chk', imgchksum)
    newim = imcls.build()
    newim_length = imcls.getTotalLength()
    print(imcls)

    save_imageinfo_exe(filename, newim, newim_length)

    '''
    See if a .bin file is in the same place.  If so... update that
    as well
    '''
    fn = filename.split(".")
    if len(fn) > 1:
        fn = '.'.join(fn[:len(fn)-1])
    fn += ".bin"
    save_imageinfo_bin(fn, newim, newim_length)

#
# Begin at Main
#
if __name__ == "__main__":
    processMeta(sys.argv[1:])
