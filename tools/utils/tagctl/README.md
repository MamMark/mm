TAGCTL
=======

Eric B. Decker <cire831@gmail.com>
copyright (c) 2018 Eric B. Decker

*License*: [GPL3](https://opensource.org/licenses/GPL-3.0)

tagctl: TAG ConTroL, simple interaction with remote tags.

INSTALL:
========

> sudo python setup.py install


will install as /usr/local/bin/tagctl


-r <root>               set base of the tagfuse filesystem
-s <hex digits>         select/set initial node
                        changes persistent node (.tagctl_cfg)


information we want:

o current rtc time, vs. current local/utc, drift
o fw:  running <ver>, golden <ver>, nib <ver>
o      base?
o uptime
o last reboot time
o last reboot reason
o img: active, backup
o img: 0: <>, 1: <>, 2: <>, 3: <>
o dblk: last record/offset, last sync, current eof (size)
o gps: current position, xyz, geo
o gps: status of alm, ephermeris
o gps: status of cgee
o panic status

tagctl nodes
       select <node_id> | <node_name>
       status
       note
       dump

   for the time being:

       cmd nop
       cmd panic
       cmd reboot
       cmd sleep

       cmd on
       cmd off
       cmd standby
       cmd pwron
       cmd pwroff
       cmd cycle

       cmd awake
       cmd mpm
       cmd pulse
       cmd reset
       cmd hibernate
       cmd wake

       send hex <hex>       transmit arbitrary msg (hex digits)
       send <msg_name>      transmit defined message
                            fills in header/trailer
       can <number>         canned send.
       can <canned name>


   later:

       cmd nop
       cmd panic
       cmd reboot
       cmd sleep

       gps on
       gps off
       gps standby
       gps pwron
       gps pwroff
       gps cycle

       gps awake
       gps mpm
       gps pulse
       gps reset
       gps hibernate
       gps wake

       gps xyz
       gps geo

       gps send hex <hex>       transmit arbitrary msg (hex digits)
       gps send <msg_name>      transmit defined message
                                fills in header/trailer
       gps <number>             canned send.

       config set -g node [<hex digits> | <node_name>]
                  packet <packet_name> <hex digits>
                  root <path>
                  name <node_name> <hex digits>

                  -g write to ~/.tagctl_cfg

       show [root, node, messages, nodes]


fuse_root: ~/tag/tag01          <root>
     node: 1fbcd99fd29f         <node>


/home/pi/tag/tag01
├── 1fbcd99fd29f
│   └── tag
│       ├── info
│       │   └── sens
│       │       └── gps
│       │           ├── cmd
│       │           └── xyz
│       ├── poll
│       │   ├── cnt
│       │   └── ev
│       ├── sd
│       │   └── 0
│       │       ├── dblk
│       │       │   ├── byte
│       │       │   ├── .committed
│       │       │   ├── .last_rec
│       │       │   ├── .last_sync
│       │       │   ├── note
│       │       │   └── .recnum
│       │       ├── img
│       │       └── panic
│       │           └── byte
│       │               ├── 0
│       │               ├── 1
│       │               ├── 2
│       │               ├── 3
│       │               └── 4
│       └── sys
│           ├── active
│           ├── backup
│           ├── golden
│           │   └── 0.3.359
│           ├── nib
│           │   └── 255.255.65535
│           ├── rtc
│           └── running
│               └── 0.3.359
├── 658bc8e5205c
│   └── tag
│       ├── info
│       │   └── sens
│       │       └── gps
│       │           ├── cmd
│       │           └── xyz
│       ├── poll
│       │   ├── cnt
│       │   └── ev
│       ├── sd
│       │   └── 0
│       │       ├── dblk
│       │       │   ├── byte
│       │       │   ├── .committed
│       │       │   ├── .last_rec
│       │       │   ├── .last_sync
│       │       │   ├── note
│       │       │   └── .recnum
│       │       ├── img
│       │       └── panic
│       │           └── byte
│       │               ├── 0
│       │               ├── 1
│       │               ├── 2
│       │               ├── 3
│       │               └── 4
│       └── sys
│           ├── active
│           ├── backup
│           ├── golden
│           │   └── 0.3.359
│           ├── nib
│           │   └── 255.255.65535
│           ├── rtc
│           └── running
│               └── 0.3.359
└── .test
    ├── echo
    ├── ones
    ├── sum
    └── zeros


Configuration:
    ~/.tagctl_cfg       global default
    ./.tagctl_cfg       local overrides

[basic]
root = <path>
node = <node_id> | <node_name>

[nodes]
<node_name> = <node_id>

[messages]
<name> = <hex digits>

[logging]
console_level = DEBUG
logfile       = /tmp/tagctl.log
logfile_level = DEBUG


[loggers]
keys=root

[handlers]
keys=stream_handler

[formatters]
keys=formatter

[logger_root]
level=DEBUG
handlers=stream_handler

[handler_stream_handler]
class=StreamHandler
level=DEBUG
formatter=formatter
args=(sys.stderr,)

[formatter_formatter]
format=%(asctime)s %(name)-12s %(levelname)-8s %(message)s


Use logging.config.fileConfig()

import logging
from logging.config import fileConfig

fileConfig('logging_config.ini')
logger = logging.getLogger()
logger.debug('often makes a very good meal of %s', 'visiting tourists')


Example Configuration Directly in Code
import logging

logger = logging.getLogger()
handler = logging.StreamHandler()
formatter = logging.Formatter(
        '%(asctime)s %(name)-12s %(levelname)-8s %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.DEBUG)

logger.debug('often makes a very good meal of %s', 'visiting tourists')
