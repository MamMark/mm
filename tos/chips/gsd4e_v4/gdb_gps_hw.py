# Setup required to use this module
#
# copy gdb_tagmon.py to <app>/.gdb_tagmon.py
# and add "source .gdb/.gdb_tagmon.py" to the <app>/.gdbinit file.
#

from __future__ import print_function
from binascii   import hexlify

txrx_str = {
    0:  'none',
    1:  'rx',
    2:  'tx',
    3:  'tx_rx',
}

class GpsIntTrace(gdb.Command):
    """Display the gps h/w interrupt record trace."""
    def __init__ (self):
        super(GpsIntTrace, self).__init__("gps_int", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        last = int(gdb.parse_and_eval('GPS0HardwareP__gps_int_rec_idx'))
        xmax = int(gdb.parse_and_eval('sizeof(GPS0HardwareP__gps_int_recs)/'
                                      'sizeof(GPS0HardwareP__gps_int_recs[0])'))
        cur = last + 1
        if cur >= xmax: cur = 0
        prev_ts = 0;

        while True:
            gp = gdb.parse_and_eval('GPS0HardwareP__gps_int_recs[0d{}]'.format(cur))
            ts    = int(gp['ts'])
            arg   = int(gp['arg'])
            ev    = gp['ev'].__str__().replace('GPSI_','')
            count = int(gp['count'])
            stat  = int(gp['stat'])
            txrx  = int(gp['tx_rx'])

            if prev_ts == 0:    delta = 0
            else:               delta = ts - prev_ts
            prev_ts = ts

            print('{:03d}  {:>4}  0x{:06x} {:8} {:>10s}  0x{:02x}  {}'.format(
                cur, '({})'.format(count), ts, delta, ev, stat,
                txrx_str.get(txrx, 'unk')))
            if cur == last:
                break
            cur += 1
            if cur >= xmax:
                cur = 0

GpsIntTrace()
