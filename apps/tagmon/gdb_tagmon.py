# Setup required to use this module
#
# copy gdb_tagmon.py to <app>/.gdb_tagmon.py
# and add "source .gdb/.gdb_tagmon.py" to the <app>/.gdbinit file.
#

from __future__ import print_function
from binascii   import hexlify

class TagmonTrace(gdb.Command):
    """Display a Tagmon radio state trace."""
    def __init__ (self):
        super(TagmonTrace, self).__init__("tm_trace", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        major      = gdb.parse_and_eval('TagnetMonitorP__rcb.state')
        major_name = str(major).replace('TagnetMonitorP__RS_','')
        major      = int(major)
        minor      = gdb.parse_and_eval('TagnetMonitorP__rcb.sub[{}].state'.format(major))
        minor_name = str(minor).replace('TagnetMonitorP__SS_','')
        minor      = int(minor)
        cycle_cnt  = int(gdb.parse_and_eval('TagnetMonitorP__rcb.cycle_cnt'))

        last = int(gdb.parse_and_eval('TagnetMonitorP__radio_trace_cur'))
        xmax = int(gdb.parse_and_eval('sizeof(TagnetMonitorP__radio_trace)/'
                                      'sizeof(TagnetMonitorP__radio_trace[0])'))
        cur = last + 1
        if cur >= xmax: cur = 0

        print()
        print('cur: {}/{}, cycle_cnt: {}'.format(major_name, minor_name, cycle_cnt))
        print()
        while True:
            tt = gdb.parse_and_eval('TagnetMonitorP__radio_trace[0d{}]'.format(cur))
            ts_ms = int(tt['ts_ms'])
            ts_usecs = int(tt['ts_usecs'])
            ts_ms_last = int(tt['ts_ms_last'])
            ts_usecs_last = int(tt['ts_usecs_last'])
            count    = int(tt['count'])
            maj_name = tt['major'].__str__().replace('TagnetMonitorP__RS_','')
            min_name = tt['minor'].__str__().replace('TagnetMonitorP__SS_','')
            frm_maj  = tt['old_major'].__str__().replace('TagnetMonitorP__RS_','')
            frm_min  = tt['old_minor'].__str__().replace('TagnetMonitorP__SS_','')
            reason   = tt['reason'].__str__().replace('TagnetMonitorP__TMR_','').lower()
            if count == 0:          # non-transition trace entry
                print('{:3d}         x{:06x}         {:08x}           {:<8}               {}'.format(
                    cur, ts_ms, ts_usecs, reason,
                    '{}_{}'.format(maj_name[0].lower(), min_name)))
            elif count == 1:
                print('{:3d} {:>6}  x{:06x}         {:08x}           {:<8} {:>10s} -> {}'.format(
                    cur, '({})'.format(count), ts_ms, ts_usecs, reason,
                    '{}_{}'.format(frm_maj[0].lower(), frm_min),
                    '{}_{}'.format(maj_name[0].lower(), min_name)))
            else:
                print('{:3d} {:>6}  x{:06x}/{:<6x}  {:08x}/{:08x}  {:<8} {:>10s} -> {}'.format(
                    cur, '({})'.format(count), ts_ms, ts_ms_last, ts_usecs, ts_usecs_last, reason,
                    '{}_{}'.format(frm_maj[0].lower(), frm_min),
                    '{}_{}'.format(maj_name[0].lower(), min_name)))
            if cur == last:
                break
            cur += 1
            if cur >= xmax:
                cur = 0

class TagmonState(gdb.Command):
    """Display the last Tagmon radio state change."""
    def __init__ (self):
        super(TagmonState, self).__init__("tm_state", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        last     = int(gdb.parse_and_eval('TagnetMonitorP__radio_trace_cur'))
        tt       = gdb.parse_and_eval('TagnetMonitorP__radio_trace[0d{}]'.format(last))
        ts_ms = int(tt['ts_ms'])
        ts_usecs = int(tt['ts_usecs'])
        ts_ms_last = int(tt['ts_ms_last'])
        ts_usecs_last = int(tt['ts_usecs_last'])
        count    = int(tt['count'])
        maj_name = tt['major'].__str__().replace('TagnetMonitorP__RS_','')
        min_name = tt['minor'].__str__().replace('TagnetMonitorP__SS_','')
        frm_maj  = tt['old_major'].__str__().replace('TagnetMonitorP__RS_','')
        frm_min  = tt['old_minor'].__str__().replace('TagnetMonitorP__SS_','')
        reason   = tt['reason'].__str__().replace('TagnetMonitorP__TMR_','').lower()
        if count == 1:
            print('    {:>6}  x{:06x}         {:08x}           {:<8} {:>10s} -> {}'.format(
                '({})'.format(count), ts_ms, ts_usecs, reason,
                '{}_{}'.format(frm_maj[0].lower(), frm_min),
                '{}_{}'.format(maj_name[0].lower(), min_name)))
        else:
            print('    {:>6}  x{:06x}/{:<6x}  {:08x}/{:08x}  {:<8} {:>10s} -> {}'.format(
                '({})'.format(count), ts_ms, ts_ms_last, ts_usecs, ts_usecs_last, reason,
                '{}_{}'.format(frm_maj[0].lower(), frm_min),
                '{}_{}'.format(maj_name[0].lower(), min_name)))

TagmonTrace()
TagmonState()
