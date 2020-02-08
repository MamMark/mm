# Copyright (c) 2017-2018, Daniel J. Maltbie, Eric B. Decker
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

'''Network Data Type decoders and objects'''

from   __future__         import print_function

__version__ = '0.4.6'

import binascii
from   collections  import OrderedDict

from   base_objs    import *
from   net_headers  import *
#from   net_defs     import *

__all__ = ['obj_dt_tagnet']


########################################################################
#
# Network Decoders
#
########################################################################

def obj_dt_tagnet():
    return obj_tagnet_hdr()

def obj_radio_stats():
    return aggie(OrderedDict([
        ('rc_readys',         atom(('<I', '{}'))),
        ('tx_packets',        atom(('<I', '{}'))),
        ('tx_reports',        atom(('<I', '{}'))),
        ('rx_packets',        atom(('<I', '{}'))),
        ('rx_reports',        atom(('<I', '{}'))),
        ('tx_timeouts',       atom(('<H', '{}'))),
        ('tx_underruns',      atom(('<H', '{}'))),
        ('rx_bad_crcs',       atom(('<H', '{}'))),
        ('rx_timeouts',       atom(('<H', '{}'))),
        ('rx_inv_syncs',      atom(('<H', '{}'))),
        ('rx_errors',         atom(('<H', '{}'))),
        ('rx_overruns',       atom(('<H', '{}'))),
        ('rx_active_overrun', atom(('<H', '{}'))),
        ('rx_crc_overruns',   atom(('<H', '{}'))),
        ('rx_crc_packet_rx',  atom(('<H', '{}'))),
        ('nops',              atom(('<H', '{}'))),
        ('unshuts',           atom(('<H', '{}'))),
        ('channel',           atom(('<B', '{}'))),
        ('tx_power',          atom(('<B', '{}'))),
        ('tx_ff_index',       atom(('<B', '{}'))),
        ('rx_ff_index',       atom(('<B', '{}'))),
        ('rc_signal',         atom(('<B', '{}'))),
        ('tx_signal',         atom(('<B', '{}'))),
        ('tx_error',          atom(('<B', '{}'))),
        ('send_tries',        atom(('<B', '{}'))),
        ('send_wait_time',    atom(('<I', '{}'))),
        ('send_max_wait',     atom(('<I', '{}'))),
        ('last_rssi',         atom(('<B', '{}'))),
        ('min_rssi',          atom(('<B', '{}'))),
        ('max_rssi',          atom(('<B', '{}'))),
    ]))
