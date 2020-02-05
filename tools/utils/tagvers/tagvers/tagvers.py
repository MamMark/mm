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

'''
tagvers - display tag utility versioning
'''

from   __future__         import print_function
import sys

try:
    import tagcore.core_rev as vers
except ImportError:
    print('*** tagcore is required, but is not installed.')
    sys.exit()

try:
    import tagdump
    tagdump_ver = tagdump.__version__
except ImportError:
    tagdump_ver = 'uninstalled'

try:
    import binfin
    binfin_ver = binfin.__version__
except ImportError:
    binfin_ver = 'uninstalled'

try:
    import pix
    pix_ver = pix.__version__
except ImportError:
    pix_ver = 'uninstalled'

try:
    import sirfdump
    sirfdump_ver = sirfdump.__version__
except ImportError:
    sirfdump_ver = 'uninstalled'

try:
    import tagctl
    tagctl_ver = tagctl.__version__
except ImportError:
    tagctl_ver = 'uninstalled'

import tagcore.gps_chip_utils
import tagcore.gps_mon
import tagcore.json_emitters
import tagcore.misc_utils
import tagcore.mr_emitters

def dump_vers():
    print()
    print('tagcore: {}  core_rev: {}/{}'.format(vers.core_ver,
                                                vers.CORE_REV,
                                                vers.CORE_MINOR,
    ))
    print('  base_objs: {:12}  dt_defs: {:12}'.format(
        vers.base_ver, vers.dt_ver))
    print('   core:     {:12}  e: {:12}  h: {:12}  panic:  h: {:12}'.format(
        vers.core_ver, vers.ce_ver, vers.ch_ver, vers.pi_ver))
    print('   sirf:  d: {:12}  e: {:12}  h: {:12}'.format(
        vers.sd_ver, vers.se_ver, vers.sh_ver))
    print('   sns:   d: {:12}  e: {:12}  h: {:12}'.format(
        vers.snsd_ver, vers.snse_ver, vers.snsh_ver))
    print('   net: {} e: {:12}  h: {:12}'.format(18 * ' ',
        vers.tne_ver, vers.tnh_ver))
    print()
    print('tagdump:  {:12}     jason_emitters:  {}'.format(
        tagdump_ver, tagcore.json_emitters.__version__))
    print('tagctl:   {:12}     mr_emitters:     {}'.format(
        tagctl_ver,  tagcore.mr_emitters.__version__))
    print('sirfdump: {:12}     gps_chip_utils:  {}'.format(
        sirfdump_ver, tagcore.gps_chip_utils.__version__))
    print('binfin:   {:12}     gps_mon:         {}'.format(
        binfin_ver, tagcore.gps_mon.__version__))
    print('pix:      {:12}     misc_utils:      {}'.format(
        pix_ver, tagcore.misc_utils.__version__))
    print()

def main():
    dump_vers()

if __name__ == "__main__":
    dump_vers()
