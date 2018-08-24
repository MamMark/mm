#e!/usr/bin/env python2
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
from   __init__                 import __version__ as VERSION

import sys
import argparse
import os.path

from   elf import *
from   tagcore.base_objs    import *
from   tagcore.core_headers import *
import tagcore.imageinfo    as     iim

from    bininfo             import *

'''
Offsets into the ELF and .bin file(s) where the image_info struct should be located
ELF is used to find the image_info structure.  A valid ELF file is *required* to
make all this work.
'''
elf_meta_offset = None
bin_meta_offset = None

parser = None
imcls = None

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

def process_TLV(type, value):
    global imcls

    block_update_success = True
    ttype = iip_tlv[type]
    consumed = imcls.setTLV(ttype, value)

    if consumed == 0:
        im_tlv_label = _iipGetKeyByValue(ttype)
        print("Desc {} Fail: Block Length violation".format(im_tlv_label))
        sys.exit(2)
    return

def binfin_args():
    global parser
    parser = argparse.ArgumentParser(
        description='Binary Finalizer (binfin)')

    parser.add_argument('-V', '--version',
        action = "version",
        version = '%(prog)s ' + VERSION)

    parser.add_argument('-I',
        help = 'Image Descriptor')

    parser.add_argument('-R',
        help = 'Repo 0 Descriptor')

    parser.add_argument('-r',
        help = 'Repo 1 Descriptor')

    parser.add_argument('-t',
        help = 'TimeStamp')

    parser.add_argument('-i',
        action = 'store_true',
        help = 'BinInfo - Display BIN/EXE MetaInfo')

    parser.add_argument('mm_file',
        help = 'Filename ELF(.exe) format')

    return parser.parse_args()

########## main
def processMeta(argv):
    global elf_meta_offset, bin_meta_offset, parser, imcls

    args    = binfin_args()

    if args.i:      #if asking for Meta Info only
        bininfo(args.mm_file)
        sys.exit(0)

    output = ""

    c_out = False
    p_out = False

    filename = args.mm_file
    if os.path.isfile(filename) == False:
        print("File {} must be a valid .exe".format(filename))
        sys.exit(2)

    # get image info from input file and sanity check
    infile = open(filename, 'rb')
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
        parser.print_usage()
        print("File {} Requires a valid ELF structure".format(filename))
        sys.exit(2)

    progs =  elf.getProgrammableSections()
    meta = elf.getSection('.image_meta')
    bin_meta_offset = meta.sh_addr - progs[0].p_paddr
    elf_meta_offset = meta.sh_offset
    if elf_meta_offset == 0:
        parser.print_usage()
        print("File {} Requires a valid image_info META structure".format(filename))
        sys.exit(2)

    '''
    We found the image_info block so load it and validate
    '''
    imcls = iim.ImageInfo(image_elf[elf_meta_offset:])
    block_update_success = True
    if args.I:      #Image Desc.
        tlv_success = process_TLV('desc', args.I)

    if args.R:      #Repo0 Desc.
        tlv_success = process_TLV('repo0', args.R)

    if args.r:      #Repo1 Desc.
        tlv_success = process_TLV('repo1', args.r)

    if args.t:      #TimeStamp
        tlv_success = process_TLV('date', args.t)

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
