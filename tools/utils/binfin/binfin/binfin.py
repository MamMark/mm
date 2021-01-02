#!/usr/bin/env python2
#
# Copyright (c) 2019, 2020 Eric B. Decker
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
#          Eric B. Decker  <cire831@gmail.com>
#
# BINFIN : A tool to update the img_info struct at the beginning of a tag image.
#	Immediately follows the Vector Table.  The img_info struct conveys details
#	about this image needed for later forensic analysis
#
#
#   Usage: binfin [-h] [-D] [-V] [-w] [-c] [-i] [--version <maj>.<min>.<build>]
#       [ -d <Img Desc.> ] [ --repo0 <Repo0 Desc.> ] [ --repo1 <Repo1 Desc.> ]
#                          [ --url0  <url0  desc.> ] [ --url1  <url1  desc.> ]
#       [ -t <timestamp> ] [ -H <HW Ver.>] [ -M <Model> ] <elf/exe filename>
#
#       <filename> the name of an elf exectable.
#           This file must contain an image_info struct.  This struct
#           will be updated with the information given in the arguments
#           below.
#
#
#   -h  Help show this usage information
#
#   -D  debug mode
#
#   -V  display version of binfin.
#
#   -i  run bininfo and exit.
#
#   -q  be quiet, otherwise give informative display
#
#   -w  write resulting image_info block to the image (and .bin if exists).
#       without -w, binfin will display the fetched and/or constructed
#       image_info.
#
#   -c  clear plus area of image_info before processing new values from the
#       command line.
#
#   --version <major>.<minor>.<build>
#       set software version to <maj>.<minor>,<build> above.
#
#   -d, --desc
#       Image Description
#
#   --repo0
#       Repo0 Description string
#
#   --url0
#       Repo0 URL string
#
#   --repo1
#       Repo1 Description string
#
#   --url1
#       Repo1 URL string
#
#   -t
#       Timestamp string (30 chars max)
#
#   -H
#       Hardware Version 8-bit HEX
#
#   -M
#       Model # 8-bit HEX
#


from   __future__ import print_function
from   __init__   import __version__ as VERSION

import sys
import argparse
import os.path

from   elf                  import *
from   tagcore.base_objs    import *
from   tagcore.misc_utils   import eprint
from   tagcore.misc_utils   import dump_buf
import tagcore.globals      as     g

from   bininfo                import bininfo
from   tagcore.imageinfo_defs import *
from   tagcore.imageinfo_defs import iip_tlv
from   tagcore.imageinfo      import ImageInfo

'''
Offsets into the ELF and .bin file(s) where the image_info struct should be located
ELF is used to find the image_info structure.  A valid ELF file is *required* to
make all this work.
'''
elf_meta_offset = None
bin_meta_offset = None
meta_size       = None

parser = None
ii_cls = None
debug  = None

def save_imageinfo_exe(filename, bin_img_info):
    global elf_meta_offset

    infile = open(filename, 'rb', 0)
    raw_elf = infile.read()
    infile.close()

    raw_elf = raw_elf[:elf_meta_offset] + bin_img_info + raw_elf[elf_meta_offset + meta_size:]
    outfile = open(filename, 'w+b')
    outfile.write(raw_elf)
    outfile.close()

def save_imageinfo_bin(filename, bin_img_info):
    global bin_meta_offset, debug

    try:
        infile = open(filename, 'rb', 0)
        raw_bin = infile.read()
    except:
        return
    infile.close()

    if debug:
        print('** binfin: {}  bin_len: {}  meta: {}  info_len: {} '.format(
                  filename,  len(raw_bin), bin_meta_offset, len(bin_img_info)))

    raw_bin = raw_bin[:bin_meta_offset] + bin_img_info + \
              raw_bin[bin_meta_offset + meta_size:]
    outfile = open(filename, 'w+b')
    outfile.write(raw_bin)
    outfile.close()


def process_TLV(xtype, value):
    global ii_cls

    ttype = iip_tlv[xtype]
    consumed = ii_cls.setTLV(ttype, value)

    if consumed == 0:
        cur, xmax = ii_cls.getPlusSize()
        raise RuntimeError('{} ({}) not added to Plus block, plus size {}/{}'.format(
                        xtype, len(value), cur, xmax))
    return


def binfin_args():
    global parser

    parser = argparse.ArgumentParser(
        description='Tag Binary Finisher (binfin)')

    parser.add_argument('-D', '--debug',
                        action='store_true',
                        help='turn on extra debugging information')

    parser.add_argument('-V',
        action = "version",
        version = '%(prog)s ' + VERSION)

    parser.add_argument('-w', '--write',
        action = 'store_true',
        help = 'write image_info to EXE/BIN MetaInfo')

    parser.add_argument('-c', '--clear',
        action = 'store_true',
        help = 'clear writeable area (image_plus) in image_info')

    parser.add_argument('-i', '--info',
        action = 'store_true',
        help = 'display current image_info and exit')

    parser.add_argument('-q', '--quiet',
        action = 'store_true',
        help = 'turn on quiet mode')

    parser.add_argument('--version',
        help = 'version string <major>.<minor>.<build> for the image.')

    parser.add_argument('-d', '--desc',
        help = 'description of this image')

    parser.add_argument('--repo0',
        help = 'Repo 0 Descriptor')

    parser.add_argument('--url0',
        help = 'Repo 0 URL Descriptor')

    parser.add_argument('--repo1',
        help = 'Repo 1 Descriptor')

    parser.add_argument('--url1',
        help = 'Repo 1 URL Descriptor')

    parser.add_argument('-t', '--timestamp',
        help = 'image build time')

    parser.add_argument('elf_file',
        help = 'ELF(.exe) executable or binary')

    return parser.parse_args()


########## main
def qprint(*args, **kwargs):
    if g.quiet: return
    print(*args, **kwargs)

def processMeta(argv):
    global parser, ii_cls
    global elf_meta_offset, bin_meta_offset, meta_size
    global debug

    args     = binfin_args()
    filename = args.elf_file

    if args.debug:
        debug   = True;
        g.debug = True;

    if args.quiet:
        g.quiet = True;

    if args.info:                       #if asking for Meta Info only
        if os.access(filename, os.R_OK) == False:
            eprint("need Read access to {}.".format(filename))
            sys.exit(2)
        bininfo(args.elf_file)
        sys.exit(0)

    if os.access(filename, os.R_OK) == False:
        eprint("need read access to {}.".format(filename))
        sys.exit(2)

    if args.write and os.access(filename, os.W_OK) == False:
        eprint("need write access to {} for -w (write).".format(filename))
        sys.exit(2)

    # get image info from input file and sanity check
    infile  = open(filename, 'rb', 0)
    raw_elf = infile.read()
    infile.seek(0)                      # back to front of file

    # Load the ELF data and use the section information to find where the
    # image_info is located.  Then they can move this around at will if
    # needed
    elf = ELFObject()
    try:
        elfhdr = elf.fromFile(infile)
    except:
        eprint("*** File {} does not contain required valid ELF structure".format(filename))
        eprint('*** ELF: unhandled exception', sys.exc_info()[0])
        raise
    infile.close()

    progs = elf.getProgrammableSections()
    meta  = elf.getSection('.image_meta')
    bin_meta_offset = meta.sh_addr - progs[0].p_paddr
    elf_meta_offset = meta.sh_offset
    meta_size       = meta.sh_size
    if elf_meta_offset == 0:
        parser.print_usage()
        eprint("File {} Requires a valid image_info META structure".format(filename))
        sys.exit(2)

    if meta_size != IMAGE_INFO_SIZE:
        eprint("binary meta size {} does not agree with tagcore meta size {}".format(
            meta_size, IMAGE_INFO_SIZE))
        sys.exit(2)

    raw_ii = raw_elf[elf_meta_offset:elf_meta_offset + meta_size]
    if debug:
        dump_buf(raw_ii, '', 'r_ii: ')
        print()

    if args.clear:
        raw_ii = raw_ii[:IMAGE_INFO_BASIC_SIZE] + \
                  '\0' * IMAGE_INFO_PLUS_SIZE
        if debug:
            dump_buf(raw_ii, '', 'clr:  ')
            print()

    ii_cls = ImageInfo(raw_ii)

    if args.version:
        ver = args.version.split('.')
        ii_cls.setVersion(ver[0], ver[1], ver[2])

    if args.desc:
        tlv_success = process_TLV('desc', args.desc)

    if args.repo0:
        tlv_success = process_TLV('repo0', args.repo0)

    if args.url0:
        tlv_success = process_TLV('url0', args.url0)

    if args.repo1:
        tlv_success = process_TLV('repo1', args.repo1)

    if args.url1:
        tlv_success = process_TLV('url1', args.url1)

    if args.timestamp:
        tlv_success = process_TLV('stamp', args.timestamp)

    text_offset = progs[0].p_offset
    text_size   = progs[0].p_filesz
    data_offset = progs[1].p_offset
    data_size   = progs[1].p_filesz

    # To update the checksum, we first zero it, calculate the checksum
    # then lay it into place.
    ii_cls.setChecksum(0)
    mod_im  = ii_cls.build()
    if debug:
        dump_buf(mod_im, '', 'mod:  ')
        print()
    raw_elf = raw_elf[:elf_meta_offset] + mod_im + raw_elf[elf_meta_offset + meta_size:]

    bin_img   = raw_elf[text_offset:text_offset+text_size] + raw_elf[data_offset:data_offset+data_size]
    bin_bytes = bytearray(bin_img)
    imgchksum = sum(bin_bytes) & 0xffffffff
    ii_cls.setChecksum(imgchksum)
    new_im = ii_cls.build()
    if debug:
        dump_buf(new_im, '', 'new:  ')
        print()

    qprint()
    if args.write:
        save_imageinfo_exe(filename, new_im)

        # See if a .bin file is in the same place.  If so... update that as well
        fn = filename.split(".")
        if len(fn) > 1:
            fn = '.'.join(fn[:len(fn)-1])
        fn += ".bin"
        save_imageinfo_bin(fn, new_im)
    else:
        print('*** write disabled')

    qprint(ii_cls)

#
# Begin at Main
#
if __name__ == "__main__":
    processMeta(sys.argv[1:])
