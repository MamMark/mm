# Copyright (c) 2019-2020 Eric B. Decker
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

'''gps chip utils, UBX chip dependent'''

__version__ = '0.4.8.dev1'

__all__ = [
    'gps_fix_name',
]


# fix_name(fixtype): return string denoting the fix type.
#
# UBX has fixtype
#

fix_names = {
    0: 'nofix',
    1: 'dr',
    2: '2d',
    3: '3d',
    4: 'gps_dr',
    5: 'time',
}

def gps_fix_name(fixtype):
    f_name = fix_names.get(fixtype, 'fix/' + str(fixtype))
    return f_name
