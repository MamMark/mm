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

'''configuration module for tagctl

configure tagctl

TagCtl can be configured via a configuration file set and/or from the
command line.

responsible for the following:

1) parsing any command line options.
2) read and process any configuration files (first the 'global',
   ~/.tagctl_cfg, followed by any 'local' ./tagctl_cfg).
3) configure logging
4) export globals, verbose/debug
5) export configuration dictionary

See help(tagctl) (__init__.py) for details on command line arguments.


Configuration Files.

configuration files use the basic .INI format supported by ConfigObj.  We
use the followinging syntax:

[basic]
      root: define the root directory of the tagfuse filesystem
      node: set the default node being communicated with.

[nodes]
      define arbitrary name to node_id mappings that can be used when
      referring to nodes.

[logfile]
      level: define the logging level going to the logfile.
             defaults to DEBUG
      name:  define the name of a logging file.

[messages]
      define arbitrary ubx messages that can be sent to the gps
      (development command).

Verbosity levels:
  0   quiet  (from -q)
  1   INFO level
  2   DEBUG level, display configuration

########################################################################
'''

from __future__ import print_function

__all__ = [
    'GPS_CMD_PATH',
    'GPS_XYZ_PATH',
    'GPS_GEO_PATH',

    'DBLK_PATH',
    'DBLK_BYTE',
    'NOTE_PATH',

    'PANIC_PATH',
    'PANIC_BYTE',

    'TagCtlException',
    'TagCtlNoRootError',
    'TagCtlRootPathError',
    'TagCtlNoNodeError',
    'TagCtlNodePathError',
]

import os
import sys
import argparse
import logging
import time

logging.Formatter.converter = time.gmtime
logging.getLogger(__name__).addHandler(logging.NullHandler())

from   __init__ import __version__ as VERSION

# parser for tagctl_cfg files
from   configobj  import ConfigObj

class TagCtlException(Exception):
    log = logging.getLogger(__name__)
    log.error('exception', exc_info = True)

class TagCtlNoRootError(TagCtlException):
    pass

class TagCtlRootPathError(TagCtlException):
    pass

class TagCtlNoNodeError(TagCtlException):
    pass

class TagCtlNodePathError(TagCtlException):
    pass


#
# global configuration control cells
#
verbose   = None                        # how chatty to be
debug     = None                        # extra debug chatty
config    = None                        # combined configuration dict
root_str  = None
node_str  = None
node_path = None

# relative paths to various locations on a tag
# full path is <root>/<node>/<remainder of path>

GPS_CMD_PATH = 'tag/info/sens/gps/cmd'
GPS_XYZ_PATH = 'tag/info/sens/gps/xyz'
GPS_GEO_PATH = 'tag/info/sens/gps/geo'

DBLK_PATH    = 'tag/sd/0/dblk'
DBLK_BYTE    = DBLK_PATH + '/' + 'byte'
NOTE_PATH    = DBLK_PATH + '/' + 'note'

PANIC_PATH   = 'tag/sd/0/panic'
PANIC_BYTE   = PANIC_PATH + '/' + 'byte'


def _auto_upper(x):
    return x.upper()


def ctl_parseargs():
    parser = argparse.ArgumentParser(
        description = 'tag remote control utility')

    parser.add_argument('remainder', nargs = '*')

    parser.add_argument('-V', '--version',
        action  = 'version',
        version = '%(prog)s ' + VERSION)

    parser.add_argument('-D', '--debug',
        action  = 'store_true',
        default = False,
        help    = 'turn on extra debugging information')

    parser.add_argument('-x', '--noconfig',
        action = 'store_true',
        help   = 'disable reading configuration files')

    parser.add_argument('-r', '--root',
        type = str,
        help = 'set root of the tagfuse filesystem.')

    parser.add_argument('-n', '--node',
        type = str,
        dest = 'node_str',
        help = 'node selector.  name (preferred) or hex digits')

    verbose_group = parser.add_mutually_exclusive_group()

    # the default MUST come first.
    verbose_group.add_argument('-v', '--verbose',
        action  = 'count',
        default = 1,
        dest    = 'verbose_level',
        help    = 'increase output verbosity')

    verbose_group.add_argument('-q', '--quiet',
        action  = 'store_const',
        const   = 0,
        dest    = 'verbose_level',
        help    = 'suppress output except warning and errors')

    parser.add_argument('--logfile',
        action  = 'store',
        default = None,
        help    = 'Specify a file to log output. Disabled by default.')

    parser.add_argument('-c', '--conlevel',
        type = _auto_upper,
        dest = 'con_level',
        help = 'console logging level')

    parser.add_argument('-l', '--loglevel',
        type = _auto_upper,
        dest = 'log_level',
        help = 'logfile logging level')

    return parser.parse_args()


def set_node_path():
    if not root_str:
        raise TagCtlNoRootError('root not set')

    if not os.path.isdir(root_str):
        raise TagCtlRootPathError(
            'root {}, does not exist'.format(
                root_str))

    if not node_str:
        raise TagCtlNoNodeError('node not set')

    # try to translate the name, if this fails just use
    # the node name directly
    try:
        node_id = config['nodes'][node_str]
    except (KeyError, TypeError):
        node_id = node_str

    node_path = os.path.join(root_str, node_id)
    if os.path.isdir(node_path):
        node_path = node_path
        return
    raise TagCtlNodePathError(
        'node path, {} does not exist'.format(
            node_path))


fmt_con = logging.Formatter(
    '--- %(name)-22s %(message)s')
fmt_log = logging.Formatter(
    '--- %(asctime)s (%(levelname)s) %(name)-22s - %(message)s')

def configure(ctl_args):
    global verbose, debug, config, root_str, node_str

    verbose = ctl_args.verbose_level
    debug   = ctl_args.debug
    found   = ''

    # start with empty, and configure defaults
    config = ConfigObj()
    config['logfile'] = {}
    config['logfile']['name']  = ''
    config['logfile']['level'] = 'DEBUG'

    if not ctl_args.noconfig:
        found        = []
        local_config = '.tagctl_cfg'
        home_config  = os.path.expanduser('~/.tagctl_cfg')

        # add home config if it exists
        if os.path.isfile(home_config):
            found.append(home_config)
            other = ConfigObj(home_config)
            config.merge(other)

        # add any local config if it exists
        if os.path.isfile(local_config):
            found.append(local_config)
            other = ConfigObj(local_config)
            config.merge(other)
            config.filename = other.filename

    # modify any logging controls based on cmd line switches.
    # --conlevel and --loglevel always force their levels.
    #
    # verbose_level controls console level (-v, -q)
    # con_level overrides any console level
    # log_level overrides any logfile level
    #
    # if verbose_level is higher than 1, set DEBUG initially

    conlev = {
        0: 'WARNING',
        1: 'INFO',
    }.get(ctl_args.verbose_level, 'DEBUG')
    loglev  = config['logfile']['level']
    logname = config['logfile']['name']

    if ctl_args.debug:
        conlev = 'DEBUG'
        loglev = 'DEBUG'

    if ctl_args.con_level:
        conlev = ctl_args.con_level

    if ctl_args.log_level:
        loglev = ctl_args.log_level

    if ctl_args.logfile:
        logname = ctl_args.logfile

    # convert the logging levels to something logging will be happy with
    if conlev.isdigit():
        conlev = int(conlev)
    if loglev.isdigit():
        loglev = int(loglev)

    # create logging channels
    #
    # LOG = logging.getLogger('tagctl')
    #
    # o set root logger to DEBUG
    # o create console streamer, set level to appropriate level
    #   cmd switch > config file, defaults to INFO
    #
    # We modify the root to have any handlers we may need.  We always
    # configure a console logging channel.  Initial level is INFO.
    # If quiet, we bump this up to WARNING.

    root = logging.getLogger()
    root.setLevel(logging.DEBUG)

    log = logging.getLogger(__name__)
    log.setLevel(logging.DEBUG)

    try:
        console = logging.StreamHandler()
        console.setFormatter(fmt_con)
        console.setLevel(conlev)
        root.addHandler(console)

        # if requested create logfile and hook onto the root
        if len(logname) > 0:
            fh = logging.FileHandler(logname)
            fh.setFormatter(fmt_log)
            fh.setLevel(loglev)
            root.addHandler(fh)
    except (ValueError, TypeError) as e:
        print('*** bad level: {}'.format(e))
        sys.exit()

    log.debug('configuring from {}'.format(', '.join(found)))
    if verbose >= 2:
        if len(found):
            log.debug('configuration:')
            try:
                for sec_name in config.sections:
                    log.debug('    [{}]'.format(sec_name))
                    for n,v in config[sec_name].iteritems():
                        log.debug('        {:14s} = {}'.format(n,v))
            # AttributeError gets thrown if no sections.
            except AttributeError:
                pass

        else:
            log.debug('*** no configuration loaded.')

    try:
        root_str = config['basic']['root']
    except (KeyError, TypeError):
        pass
    try:
        node_str = config['basic']['node']

    except (KeyError, TypeError):
        pass

    if ctl_args.root:
        root_str = ctl_args.root
    if ctl_args.node_str:
        # node_str can be either a 12 digit node id
        # or a node name.  We check length and then try
        # converting the hex string.
        #
        # if not 12 digits then just assume that it is
        # a node name which will be looked up later.
        if len(ctl_args.node_str) != 12:
            node_str = ctl_args.node_str
        else:
            try:
                node     = int(ctl_args.node_str, 16)
                node_str = ctl_args.node_str
            except ValueError:
                print()
                print('*** bad hex digits in -s arg: {}'.format(
                    ctl_args.node_str))
                print('*** aborting')
                print()
                sys.exit()

    if root_str:
        root_str = os.path.expanduser(root_str).rstrip('/')

    log.debug('verbose: {}, debug: {}'.format(verbose, debug))
    log.debug('root: {}'.format(root_str))
    log.debug('node: {}'.format(node_str))
    log.debug('path: {}'.format(node_path))


def display_section(sec_name):
    if config.has_key(sec_name):
        print('[{}]'.format(sec_name))
        try:
            for n,v in config[sec_name].iteritems():
                print('  {:14s} = {}'.format(n,v))

        # AttributeError gets thrown if no sections.
        except AttributeError:
            pass

def display_messages():
    display_section('messages')

def set_node_path():
    global node_path
    log = logging.getLogger(__name__)

    if not root_str:
        raise TagCtlNoRootError('root not set')

    if not os.path.isdir(root_str):
        raise TagCtlRootPathError(
            'root {}, does not exist'.format(root_str))

    working_path = root_str

    if not node_str:
        raise TagCtlNoNodeError('node not set')

    # try to translate the name, if this fails just use
    # the node name directly
    try:
        node_id = config['nodes'][node_str]
    except (KeyError, TypeError):
        node_id = node_str

    working_path = os.path.join(working_path, node_id)
    if os.path.isdir(working_path):
        node_path = working_path
        log.debug('node_path set to {}'.format(node_path))
        return
    raise TagCtlNodePathError(
        '*** node path, {} does not exist'.format(
            working_path))


def ctl_startup():
    args = ctl_parseargs()
    configure(args)
    return args


if __name__ == '__main__':
    ctl_startup()
