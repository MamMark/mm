# Copyright (c) 2017-2019 Daniel J. Maltbie, Eric B. Decker
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
#          Eric B. Decker <cire831@gmail.com>
#
# Gave up on trying to get the argparse version to print multiple version
# strings.  Main code will display the decode/header versions if verbose
# and tagdumpargs will display the main program version.
#

'''
dump a MamMark DBLKxxxx data stream.

dumps a MamMark dblk data file or network stream while
optionally writing parsed records to an external database.

output: args  global for holding resultant arguments

Args:

optional arguments:
  -h              show this help message and exit
  -V              show program's version number and exit

  -H              turn off hourly banners

  --rtypes RTYPES output records matching types in list names
                  comma or space seperated list of rtype ids or NAMES
                  (args.rtypes, list of strings)

  -D              turn on Debugging information
                  (args.debug, boolean)

  -j JUMP         set input file position
                  (args.jump, integer)
                  -1: goto EOF
                  negative number, offset from EOF.

  -x endpos       set last file position to process
                  (args.endpos, integer)

  -n num          limit display to <num> records
                  (args.num, integer)

  --net           enable network (tagnet) i/o
                  (args.net, boolean)

  -s SYNC_DELTA   search some number of syncs backward
                  always implies --net, -s 0 says .last_sync
                  -s 1 and -s -1 both say sync one back.
                  (args.sync, int)

  --start START_TIME
                  include records with rtctime greater than START_TIME
  --end END_TIME  (args.{start,end}_time)

  -r START_REC    starting/ending records to dump.
                  -r -1 says start with .last_rec (implies --net)
  -l LAST_REC     (args.{start,last}_rec, integer)

  -t, --timeout TIMEOUT
                  set --tail timeout to TIMEOUT seconds, defaults to 60

  --tail          do not stop when we run out of data.  monitor and
                  get new data as it arrives.  (implies --net)
                  (args.tail, boolean)

  -v, --verbose   increase output verbosity
                  (args.verbose)

      0   just display basic record occurance (default)
      1   basic record display - more details
      2   detailed record display
      3   dump buffer/record
      4   details of resync
      5   other errors and decoder versions


positional parameters:

  input:          file to process.  (args.input)


'''

from   __future__         import print_function

import sys
import argparse
from   tagcore  import *
from   __init__ import __version__   as VERSION

def auto_int(x):
    return int(x, 0)

def auto_upper(x):
    return x.upper()

def parseargs():
    parser = argparse.ArgumentParser(
        description='Print contents of Tag Data Stream.')

    parser.add_argument('input',
                        type=argparse.FileType('rb'),
                        help='input file')

    parser.add_argument('-V', '--version',
                        action='version',
                        version='%(prog)s ' + VERSION + ', core: ' + \
                            str(CORE_REV) + '/' + str(CORE_MINOR))

    parser.add_argument('--rtypes',
                        type=auto_upper,
                        help='output records matching types in list')

    parser.add_argument('-H', '--hourly',
                        action='store_false',
                        help='turns off hourly banners')

    parser.add_argument('-D', '--debug',
                        action='store_true',
                        help='turn on extra debugging information')

    parser.add_argument('-j', '--jump',
                        type=auto_int,
                        help='set input file position, -1 EOF, neg from EOF')

    parser.add_argument('-x', '--endpos',
                        type=auto_int,
                        help='set ending file position to process')

    parser.add_argument('-n', '--num',
                        type=int,
                        help='limit display to <num> records')

    parser.add_argument('--net',
                        action='store_true',
                        help='use tag net io, (unbuffered io)')

    parser.add_argument('-s', '--sync',
                        type=int,
                        help='sync backward SYNC syncs')

    # not working yet
    parser.add_argument('--start',
                        type=int,
                        help='include records with rtctime >= than START')

    # not working yet
    parser.add_argument('--end',
                        type=int,
                        help='stop with records after END')

    parser.add_argument('-r', '--start_rec',
                        type=int,
                        help='starting record to dump.')

    parser.add_argument('-l', '--last_rec',
                        type=int,
                        help='last record to dump.')

    parser.add_argument('-t', '--timeout',
                        type=int,
                        default=60,
                        help='--tail read timeout.')

    parser.add_argument('--tail',
                        action='store_true',
                        help='continue reading data at EOF')

    parser.add_argument('-v', '--verbose',
                        action='count',
                        default=0,
                        help='increase output verbosity')

    return parser.parse_args()

if len(sys.argv) < 2:
    # something weird is going on, just fake it
    sys.argv.append('/dev/null')
args = parseargs()
if __name__ == '__main__':
    print(args)
