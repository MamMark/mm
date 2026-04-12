# Setup required to use this module
#
# copy gdb_tagmon.py to <app>/.gdb_tagmon.py
# and add "source .gdb/.gdb_tagmon.py" to the <app>/.gdbinit file.
#

from __future__ import print_function
from binascii   import hexlify
import re

txrx_str = {
    0:  'none',
    1:  'rx',
    2:  'tx',
    3:  'tx_rx',
}

class GpsIntTrace(gdb.Command):
    """Display the gps h/w interrupt record trace."""
    def __init__ (self):
        super(GpsIntTrace, self).__init__("gpsInt", gdb.COMMAND_USER)

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

# ubx stats: t/o chk err frm ovr par rst  proto    </>   nbuf   ign max
#99999/99999 999 999 999 999 999 999 999 999/999 999/999 9999 99999 999

def get_and_print_stats():
    sp = gdb.parse_and_eval('ubxProtoP__ubx_stats')
    op = gdb.parse_and_eval('ubxProtoP__ubx_other_stats')
    print('ubx stats: t/o chk err frm ovr par rst  proto    </>   nbuf   ign max')
    print('{:5d}/{:<5d} {:3d} {:3d} {:3d} {:3d} {:3d} {:3d} {:3d} {:3d}/{:<3d} {:3d}/{:<3d} {:4d} {:5d} {:3d}'.format(
        int(sp['complete']),   int(sp['starts']),     int(sp['rx_timeouts']), int(sp['chksum_fail']),
        int(sp['rx_errors']),  int(sp['rx_framing']), int(sp['rx_overrun']),  int(sp['rx_parity']),
        int(sp['resets']),     int(sp['proto_start_fail']), int(sp['proto_end_fail']),
        int(sp['too_small']),  int(sp['too_big']),          int(op['no_buffer']),
        int(sp['ignored']),    int(op['max_seen'])))
    return sp, op

class GpsProtoStats(gdb.Command):
    """Display the gps protocol stats."""
    def __init__ (self):
        super(GpsProtoStats, self).__init__("gpsProtoStats", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        get_and_print_stats()


class GpsClearStats(gdb.Command):
    """Nuke the gps protocol stats."""
    def __init__ (self):
        super(GpsClearStats, self).__init__("gpsClearStats", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        sp, op = get_and_print_stats()
        print('*** clearing')
        for nxt in re.findall('(\w*)\s*=\s*', str(sp)):
            var = 'ubxProtoP__ubx_stats.' + nxt
            gdb.execute('set {}  = 0'.format(var))
        for nxt in re.findall('(\w*)\s*=\s*', str(op)):
            var = 'ubxProtoP__ubx_other_stats.' + nxt
            gdb.execute('set {}  = 0'.format(var))
        sp, op = get_and_print_stats()

GpsIntTrace()
GpsProtoStats()
GpsClearStats()
