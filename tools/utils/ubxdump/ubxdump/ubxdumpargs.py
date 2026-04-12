# Copyright (c) 2020 Eric B. Decker
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
#

from   __future__ import print_function
from   __init__   import __version__ as VERSION
import argparse

def auto_int(x):
    return int(x, 0)

def auto_upper(x):
    return x.upper()

def parseargs():
    parser = argparse.ArgumentParser(
        description='Display SirfBin records.')

    parser.add_argument('input',
                        type=argparse.FileType('rb'),
                        help='input file')

    parser.add_argument('-V', '--version',
                        action='version',
                        version='%(prog)s ' + VERSION)

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

    # see tagdump.py for verbosity levels
    parser.add_argument('-v', '--verbose',
                        action='count',
                        default=0,
                        help='increase output verbosity')

    parser.add_argument('-w', '--wide',
                        action='store_true',
                        help='extra wide summary (better viewing)')

    return parser.parse_args()

if __name__ == '__main__':
    print(parseargs())
