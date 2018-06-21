# Copyright (c) 2018 Eric B. Decker
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

"""manipulate tags via commands via tagfuse/radio

usage: tagctl.py [-h] [-V] [-D] [-x | --noconfig ]
              [[-v | --verbose] | [-q | --quiet]]
              [-r <root_path>] [-s <node_id>]
              [-c <num> | --conlevel <num>]
              [-l <num> | --loglevel <num>]
              [--logfile <log_file>]

Args:

optional arguments to main ctl_main app:
  -h              show this help message and exit
  -V              show program's version number and exit

  -D              turn on Debugging information
                  (args.debug, boolean)

  -x, --noconfig  do not read any configuration files
                  (args.noconfig, bool)

  -r <set root>   override root value.  The tagfuse filesystem root.
                  (args.root, string)

  -s <node_id>    select node id.  Override static config.
                  (args.node_name, str)

  -q, --quiet     be quiet, only display WARNING, ERROR and CRITICALs
                  (args.verbose_level) sets to 0

  -v, --verbose   increase output verbosity
                  (args.verbose_level) sets to 1+, default 1 (INFO)

Vebosity; (controls console logging)

  0   quiet  (from -q)
  1   INFO level (default)
  2   DEBUG level, display configuration

-D (debug) sets logging level to DEBUG, both console and logfile
      gets overridden by --conlevel and --loglevel if specified.


logging:

logging levels:
        0      10      20     30        40      50
      NOTSET < DEBUG < INFO < WARNING < ERROR < CRITICAL/FATAL

  --logfile       set logfile name.
                  (args.logfile)

  -c <num>, --conlevel <num>  set console logging level
                  (args.con_level)  (default: INFO)

  -l <num>, --loglevel <num>  set logfile logging level
                  (args.log_level)  (default: DEBUG)

  remainder       list of all other input parameters
                  (args.remainder)


TagCtl uses a configuration file that can be loaded from the users
home directory and the current directory.  ~/.tagctl_cfg is called
the global configuration and ./.tagctl_cfg is the local configuration.
local configuration overrides the global one.

See ctl_config.py for more details.


TagCtl can also be configured using command line switches.  See
ctl_config.py for more details.

command line switches (-r and -s) override any static configuration
values.

########################################################################
"""

# 0.0.2         rename __main__ to tagctl
# 0.0.1         initial version

__version__ = '0.0.2.dev1'
