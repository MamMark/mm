# Copyright (c) 2018-2019 Eric B. Decker
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

'''core revision level

core_rev reflects the revision level of various key core data structures
exported.  See include/core_rev.h for a list of what files are reflected
in this versioning.

core_minor gets popped when something visible changes but doesn't impact
the basic ability to decode.   ie.  adding new events.
'''

CORE_REV   = 21
CORE_MINOR =  97

from    .__init__       import __version__   as core_ver
from    .base_objs      import __version__   as base_ver
from    .dt_defs        import __version__   as dt_ver
from    .core_emitters  import __version__   as ce_ver
from    .core_headers   import __version__   as ch_ver
from    .panic_headers  import __version__   as pi_ver
from    .sirf_defs      import __version__   as sd_ver
from    .sirf_emitters  import __version__   as se_ver
from    .sirf_headers   import __version__   as sh_ver
from    .net_headers    import __version__   as tn_ver

from    .sensor_defs     import __version__  as snsd_ver
from    .sensor_emitters import __version__  as snse_ver
from    .sensor_headers  import __version__  as snsh_ver
