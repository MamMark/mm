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

'''gps chip utils, chip dependent'''

__version__ = '0.4.6.dev0'

__all__ = [
    'fix_name',
    'expand_satmask',
    'expand_trk_state_short',
    'expand_trk_state_long',
]


# fix_name(fixtype): return string denoting the fix type.
#
# SirfStarIV chips report fixes via NavData (2) and Geodetic (41).
#
# NavData shows up in mid2:mode1:ptype (low 7 bits) field.  Geo shows up in
# mid41:nav_type:fix_type (low 7 bits).  Both ptype and fix_type have
# exactly the same values.

fix_names = {
    0:  'nofix',
    1:  '1SVKF',
    2:  '2SVKF',
    3:  '3SVKF',
    4:  '4+KF',
    5:  '2DLSQ',
    6:  '3DLSQ',
    7:  'DR',
}

def fix_name(fixtype):
    f_name = fix_names.get(fixtype, 'fix/' + str(fixtype))
    return f_name

# expand_satmask(satmask): return string denoting what sats are in the satmask
#
# SirfStarIV chips can report what satellites are used in a solution using
# a satellite mask.  This only works for satellites 01 to 32.  A different
# mechanism will need to be found for chips using higher PRNs for the
# SVIDs.
#
# expand_satmask(0x00200100) returns '09 22'

def expand_satmask(satmask):
    if satmask == 0:
        return ''
    sat_str = ''
    sep = ''
    for i in range(32):
        if satmask & (1<<i):
            sat_str = sat_str + sep + '{:02d}'.format(i + 1)
            sep = ' '
    return sat_str


# expand_trk_state(state): return expansion for a given bit
#
# SirfStarIV trackers return a state bit field with the following meanings.
# expand_trk_state returns a string representation of the state.

sirf_trk_bits = {
    0:  ('Acq',       'a'),
    1:  ('Carrier',   'c'),
    2:  ('Bitsync',   'b'),
    3:  ('Subframe',  's'),
    4:  ('Pullin',    'p'),
    5:  ('codeLock',  'l'),
    6:  ('Trklost',   't'),
    7:  ('Ephemeris', 'e'),
}

def expand_trk_state_short(state, off_char = ''):
    if state == 0: return ' nostate'
    rtn = ''
    for i in range(7, -1, -1):
        bitset = True if (state & (1 << i)) else False
        rtn += sirf_trk_bits[i][1] if bitset else off_char
    return rtn


def expand_trk_state_long(state, sep=' '):
    rtn = ''
    xsep = ''
    for i in range(7, -1, -1):
        bitset = True if (state & (1 << i)) else False
        if bitset:
            rtn = rtn + xsep + sirf_trk_bits[i][0]
            xsep = sep
    return rtn
