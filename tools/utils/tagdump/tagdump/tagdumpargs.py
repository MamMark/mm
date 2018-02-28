# Copyright (c) 2017-2018 Daniel J. Maltbie, Eric B. Decker
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

from __init__ import __version__ as VERSION
from core_records import DT_H_REVISION as DT_REV
import argparse


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
                        version='%(prog)s ' + VERSION + ':  dt_rev ' + str(DT_REV))

    parser.add_argument('--rtypes',
                        type=auto_upper,
                        help='output records matching types in list')

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

    parser.add_argument('--lsync',
                        action='store_true',
                        help='(net) start with last sync')

    parser.add_argument('--lrec',
                        action='store_true',
                        help='(net) start with last record')

    parser.add_argument('-s', '--sync',
                        type=int,
                        help='sync backward SYNC syncs')

    # not working yet
    parser.add_argument('--start',
                        type=int,
                        help='include records with datetime >= than START')

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

    parser.add_argument('--tail',
                        action='store_true',
                        help='continue reading data at EOF')

    # see tagdump.py for verbosity levels
    parser.add_argument('-v', '--verbose',
                        action='count',
                        default=0,
                        help='increase output verbosity')

    return parser.parse_args()

if __name__ == '__main__':
    print(parseargs())
