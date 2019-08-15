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

'''Sensor Decoders and objects'''

from   __future__   import print_function

__version__ = '0.4.5.dev1'

from   collections  import OrderedDict
from   base_objs    import *

def obj_tmp_px():
    return aggie(OrderedDict([
        ('tmp_p', atom(('<h', '{}'))),
        ('tmp_x', atom(('<h', '{}'))),
    ]))
