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
# Contact: Eric B. Decker <cire831@gmail.com>
#   Updated: Rick Li Fo Sjoe <flyrlfs@gmail.com>

'''PIX: Panic Inspector/eXtractor

display and extract panic blocks from a composite PANIC file.
Extracted panics can be fed to CrashDump for analysis.

usage: pix [-h] [-V]
           [-o <output>]
           [--output <output>]
           panic_file

Args:

optional arguments:
  -h            show this help message and exit
  -V            show program's version number and exit
  -l            List all PanicBlocks available

  -o <output>   enables extraction and sets output file.
                (args.output, file)

positional argument:
  panic_file    input file, composite PANIC file.
'''

from   __future__               import print_function
from   __init__                 import __version__ as VERSION

import sys
import struct
import argparse
from   collections              import OrderedDict
from   pprint                   import PrettyPrinter

from   tagcore.core_headers     import *
from   tagcore.imageinfo        import *
from   tagcore.panic_headers    import *

from crashdump                  import *

ppPP = PrettyPrinter(indent = 4)
pp   = ppPP.pprint

DEFAULT_BLOCK_SIZE = 512    #Default we use for DIR record

# Global scope
args    = None
inFile  = None
outFile = None

pblk            = 'ffffff'
plist           = []
valid_panic_count = 0

panic_dir_sector  = None
panic_high_sector = None
panic_block_index = None
panic_block_size  = None
panic_block_maximum = None

'''
pix_init : Read the directory and validate we have good data to look at
'''
def pix_init():
    global inFile, panic_dir_sector, panic_high_sector, panic_block_size
    global  DEFAULT_BLOCK_SIZE, panic_block_maximum, panic_block_index

    # Read in Directory block for verification
    raw = inFile.read(DEFAULT_BLOCK_SIZE)
    panic_dir_obj     = obj_panic_dir()
    consumed          = panic_dir_obj.set(raw)
    panic_dir_cksum   = panic_dir_obj['panic_dir_checksum'].val
    panic_dir_raw = struct.unpack("<"+"{}".format(consumed/4)+"I", bytearray(raw[:consumed]))
    calcsum = sum(panic_dir_raw) & 0xFFFFFFFF
    if calcsum != 0:
        print("*** Panic Directory Checksum Fail: {:08X} Expected {:08X}".format(calcsum, 0))

    dir_sig           = (panic_dir_obj['panic_dir_sig'].val)
    if (dir_sig != PANIC_DIR_SIG):
        print('*** dir_sig_mismatch: wanted {:08x}, got {:08x}'.format(
            PANIC_DIR_SIG, dir_sig))

    panic_dir_sector  = (panic_dir_obj['panic_dir_sector'].val)
    panic_high_sector = (panic_dir_obj['panic_high_sector'].val)
    panic_block_size  = (panic_dir_obj['panic_block_size'].val)
    panic_block_index = (panic_dir_obj['panic_block_index'].val)
    panic_block_maximum = (panic_dir_obj['panic_block_index_max'].val)
    return

'''
panic_valid() : Validates a specific panic block
'''
def panic_valid(blockno):
    global plist, panic_block_size, DEFAULT_BLOCK_SIZE, PANIC_INFO_SIG

    offset = (blockno * (panic_block_size * DEFAULT_BLOCK_SIZE)) + DEFAULT_BLOCK_SIZE
    inFile.seek(offset)
    buf = inFile.read(DEFAULT_BLOCK_SIZE)

    panic_block_0_obj  = obj_panic_zero_0()
    panic_block_0_size = len(panic_block_0_obj)
    pbsize = len(panic_block_0_obj['panic_info']) + len(panic_block_0_obj['owcb_info'])
    image_info = ImageInfo(buf[pbsize:])
    bptr = buf
    consumed   = panic_block_0_obj.set(bptr)
    panic_info = panic_block_0_obj['panic_info']
    pi_sig     = panic_info['pi_sig'].val
    if pi_sig != PANIC_INFO_SIG:
        print("*** Panic Info Signature Fail :#{}  wanted {:08X}, got {:08X}".format(
            blockno,
            PANIC_INFO_SIG,
            panic_info['pi_sig'],
            ))
    return {'pb':panic_block_0_obj, 'im':image_info, 'offset':offset}

'''
panic_search() : Search for all panic blocks and get basic header info.
    Build a list of this to allow for further Xtraction
'''
def panic_search():
    global inFile, plist, valid_panic_count, panic_block_index

    for panic in range(0, panic_block_index):
        p = panic_valid(panic)
        if (p):
            valid_panic_count += 1
            plist.append(p)
    return

def panic_dir():
    global valid_panic_count, plist
    print("{} Panic Dump(s) found".format(valid_panic_count))
    out = ""
    k = 0
    for panic in plist:
        panic_info = panic['pb']['panic_info']
        image_info = panic['im']
        image_desc = image_info.getTLV(iip_tlv['desc'])
        rep0_desc = image_info.getTLV(iip_tlv['repo0'])
        out += "#{} {}/{}/{} {}:{}:{}.{}\n{} {}".format(k,
            panic_info['rt']['mon'].val,
            panic_info['rt']['day'].val, panic_info['rt']['year'].val,
            panic_info['rt']['hr'].val, panic_info['rt']['min'].val,
            panic_info['rt']['sec'].val, panic_info['rt']['sub_sec'].val,
            image_desc, rep0_desc)
        out += "\n"
        k += 1
    print("{}".format(out))
    return

def panic_args():
    parser = argparse.ArgumentParser(
        description='Panic Inspector/eXtractor (PIX)')

    parser.add_argument('-V', '--version',
        action = "version",
        version = '%(prog)s ' + VERSION)

    parser.add_argument('-l', '--ls',
        action = 'store_true',
        help = 'List Panics for XTraction')

    parser.add_argument('-x', '--extract',
        type = int,
        help = 'Extract specific panic block #')

    parser.add_argument('panic_file',
                        type = argparse.FileType('rb'),
                        help = 'panic file')

    parser.add_argument('-o', '--output',
                        type = argparse.FileType('wb'),
                        help = 'dest filename for extraction')

    return parser.parse_args()

def main():
    global args, inFile, outFile, valid_panic_count, panic_block_index, plist
    global panic_block_size, DEFAULT_BLOCK_SIZE

    print('Panic Inspector/eXtractor')
    args    = panic_args()
    '''
    if args.version:
        print("Binfin Version : {}".format(__version__))
    '''
    inFile  = args.panic_file
    outFile = args.output

    pix_init()
    panic_search()

    if args.ls:
        panic_dir()

    if args.output:
        panic_block = args.extract
        if panic_block >= panic_block_index:
            print("**Enter a valid Panic Block.  Use -l to see available panic blocks***")
            sys.exit(1)

        pb = plist[panic_block]
        pblk_offset = pb['offset']
        inFile.seek(pblk_offset)
        ex_blk = inFile.read(panic_block_size*DEFAULT_BLOCK_SIZE)
        crashdump = CrashDumpFormat(pb, ex_blk)
        crashdump.dump_build(outFile)
        outFile.close()

if __name__ == "__main__":
    main()
