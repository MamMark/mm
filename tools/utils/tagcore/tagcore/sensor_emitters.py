# Copyright (c) 2019 Eric B. Decker
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

'''
basic definitions for sensors.
'''

from   __future__   import print_function

__version__ = '0.4.6.dev1'

def emit_default(level, offset, buf, obj):
    print()
    if (level >= 1):
        print('    {}'.format(obj))


def sns_str_tmp_px(obj, level = 0):
    s = ''
    sep = ''
    tmp_p = obj['tmp_p'].val
    tmp_x = obj['tmp_x'].val
    c_p = float(obj['tmp_p'].val)/16*0.0625
    c_x = float(obj['tmp_x'].val)/16*0.0625
    if level == 0:
        return '{:6.1f}C {:6.1f}C'.format(c_p, c_x)

    if level >= 2:
        s = '({:04x}) ({:04x})'.format(tmp_p, tmp_x)
        sep = ' '
    if level >= 1:
        f_p = c_p * 9/5 + 32
        f_x = c_x * 9/5 + 32
        s = s + sep + '{:6.1f}F {:6.1f}F'.format(f_p, f_x)
    return s


def emit_tmp_px(level, offset, buf, obj):
    pass
