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

'''tagctl - remote control utility for mm tags'''

from   __future__         import print_function

import os
import sys
import logging

from   binascii             import hexlify
from   tagcore              import buf_str
import tagcore.gps_cmds     as     gps

from   tagcore.sirf_defs    import SIRF_SOP_SEQ as SOP
from   tagcore.sirf_defs    import SIRF_EOP_SEQ as EOP

from   ctl_config           import *
import ctl_config           as     cfg

from   cliff.app            import App
from   cliff.commandmanager import CommandManager
from   cliff.command        import Command

logging.getLogger(__name__).addHandler(logging.NullHandler())

class Can(Command):
    log = logging.getLogger(__name__ + '.can')
    can_msgs = gps.canned_msgs

    def get_parser(self, prog_name):
        parser = super(Can, self).get_parser(prog_name)
        parser.add_argument('msg', nargs='?')
        return parser

    def take_action(self, parsed_args):
        self.log.debug('args: {}'.format(parsed_args))
        self.log.debug('can:  {}'.format(parsed_args.msg))

        msg = parsed_args.msg
        if not msg:
            print('a msg would be nice')
            return
        cfg.set_node_path()
        cmd_path = os.path.join(cfg.node_path, GPS_CMD_PATH)
        self.log.debug('node_path: {}'.format(cfg.node_path))
        self.log.debug('cmd_path:  {}'.format(cmd_path))
        msg_val = self.can_msgs.get(msg, -1)
        if msg_val == -1:
            print('*** bad msg: {} {}'.format(msg_val,
                self.can_msgs.get(msg_val, 'unk')))
            return
        cmd_fileno = os.open(cmd_path, os.O_DIRECT | os.O_RDWR)
        out_msg = bytearray([gps.CMD_CAN, msg_val])
        os.write(cmd_fileno, out_msg)
        msg_val = self.can_msgs.get(msg_val, 'unk')
        print('sending can {} [{}]-> {}'.format(msg_val,
                    hexlify(out_msg), cfg.node_str))

class Cmd(Command):
    log = logging.getLogger(__name__ + '.cmd')
    g_cmds = gps.gps_cmds

    def get_parser(self, prog_name):
        parser = super(Cmd, self).get_parser(prog_name)
        parser.add_argument('cmd', nargs='?', default='nop')
        return parser

    def take_action(self, parsed_args):
#        import pdb; pdb.set_trace()
        self.log.debug('args: {}'.format(parsed_args))
        self.log.debug('cmd:  {}'.format(parsed_args.cmd))

        cmd = parsed_args.cmd
        cfg.set_node_path()
        cmd_path = os.path.join(cfg.node_path, GPS_CMD_PATH)
        self.log.debug('node_path: {}'.format(cfg.node_path))
        self.log.debug('cmd_path:  {}'.format(cmd_path))
        gps_cmd = self.g_cmds.get(cmd, 0)
        if gps_cmd == gps.CMD_CAN: gps_cmd = gps.CMD_NOP
        cmd_fileno = os.open(cmd_path, os.O_DIRECT | os.O_RDWR)
        out_msg = bytearray([gps_cmd])
        os.write(cmd_fileno, out_msg)
        gps_cmd = self.g_cmds.get(gps_cmd, 'unk')
        print('sending cmd {} [{}]-> {}'.format(gps_cmd, hexlify(out_msg), cfg.node_str))

class Send(Command):
    log = logging.getLogger(__name__ + '.send')

    def get_parser(self, prog_name):
        parser = super(Send, self).get_parser(prog_name)
        parser.add_argument('msg', nargs='?', default='nop')
        return parser

    def take_action(self, parsed_args):
        self.log.debug('args: {}'.format(parsed_args))
        self.log.debug('send: {}'.format(parsed_args.msg))

        msg      = parsed_args.msg
        mid      = cfg.config['messages'][msg]
        mid      = bytearray.fromhex(mid)
        len_mid  = len(mid)
        full_msg = bytearray([gps.CMD_RAW_TX, SOP >> 8, SOP & 0xff])
        full_msg.extend(bytearray([len_mid >> 8, len_mid & 0x00ff]))
        full_msg.extend(mid)
        chk = sum(mid)
        full_msg.extend(bytearray([chk >> 8, chk & 0xff]))
        full_msg.extend(bytearray([EOP >> 8, EOP & 0xff]))

        cfg.set_node_path()
        cmd_path = os.path.join(cfg.node_path, GPS_CMD_PATH)

        self.log.debug('node_path: {}'.format(cfg.node_path))
        self.log.debug('cmd_path:  {}'.format(cmd_path))

        print('sending {} [{}] -> {}'.format(msg, buf_str(full_msg),
                                             cfg.node_str))

        cmd_fileno = os.open(cmd_path, os.O_DIRECT | os.O_RDWR)
        os.write(cmd_fileno, full_msg)

class CtlApp(App):
    log = logging.getLogger(__name__ + '.ctl')

    def __init__(self):
        ctl_cmd_mgr = CommandManager('ctl_main')
        super(CtlApp, self).__init__(
            description     = 'tagctl main',
            version         = '0.1',
            command_manager = ctl_cmd_mgr,
        )

    def initialize_app(self, argv):
        self.log.debug('--- initialize_app - argv: {}'.format(argv))

    def prepare_to_run_command(self, cmd):
        self.log.debug('prepare_to_run_command %s', cmd.__class__.__name__)
        self.log.debug('--- __name__: {}'.format(__name__))

    def clean_up(self, cmd, result, err):
        self.log.debug('clean_up %s', cmd.__class__.__name__)
        if err:
            self.log.debug('got an error: %s', err)


def doit(args):
    log = logging.getLogger(__name__ + '.doit')
    try:
        cfg.set_node_path()
        print()
        log.debug('node path: {}'.format(cfg.node_path))
        log.debug('remaining: {}'.format(args.remainder))
        print()

        while(True):
            break

    except TagCtlException as e:
        log.error('exception: {}'.format(e))
        sys.exit(1)

    except KeyboardInterrupt:
        print()
        print('*** user stop'),
        print()


def main():
    log = logging.getLogger(__name__)
    log.debug('startup')
    args = cfg.ctl_startup()
    log.debug('--- instantiate CtlApp')
    myapp = CtlApp()
    return myapp.run(args.remainder)

if __name__ == '__main__':
    main()
