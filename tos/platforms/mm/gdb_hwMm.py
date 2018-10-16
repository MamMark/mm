# Setup required to use this module
#
# copy gdb_hwMm.py to <app>/.gdb_hwMm.py
# and add "source .gdb/.gdb_hwMm.py" to the <app>/.gdbinit file.
#

from __future__ import print_function
from binascii   import hexlify

PERIPH = 0x40000000
TA0    = PERIPH + 0x000
TA1    = TA0    + 0x400
TA2    = TA1    + 0x400
TA3    = TA2    + 0x400

def ccr_n(ta, n):
    return int(gdb.parse_and_eval(ta + '->CCR[{}]'.format(n)))

def cctl_n(ta, n):
    return int(gdb.parse_and_eval(ta + '->CCTL[{}]'.format(n)))

class HwTMilli(gdb.Command):
    """Display h/w timer info, TMilli."""
    def __init__ (self):
        super(HwTMilli, self).__init__("hwTMilli", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        ta     = '((Timer_A_Type *) 0x{:08x})'.format(TA1)
        ctl    = int(gdb.parse_and_eval(ta + '->CTL'))
        cctl0  = cctl_n(ta, 0)
        r      = int(gdb.parse_and_eval(ta + '->R'))
        ccr0   = ccr_n(ta, 0)
        upper  = int(gdb.parse_and_eval('TransformCounterC__0__m_upper'))
        lower  = r >> 5
        tmilli = (upper << 11) | (r >> 5)

        a0_t0 = int(gdb.parse_and_eval('TransformAlarmC__0__m_t0'))
        a0_dt = int(gdb.parse_and_eval('TransformAlarmC__0__m_dt'))
        c0_u  = int(gdb.parse_and_eval('TransformCounterC__0__m_upper'))

        print('   TA1: {:04x}        CTL: {:04x}   CCTL0: {:04x}      CCR0: {:04x}'.format(
            r, ctl, cctl0, ccr0))
        for _n in range(1, 5):
            _ccr  = ccr_n(ta, _n)
            _cctl = cctl_n(ta, _n)
            if _ccr or (_cctl & 0xfffe):
                print('{}CCTL{}: {:04x}      CCR{}: {:04x}'.format(
                    32*' ', _n, _cctl, _n, _ccr))
        print('tmilli: {:08x}  a0_t0: {:08x}  dt: {:08x}  c0_u: {:08x}'.format(
            tmilli, a0_t0, a0_dt, c0_u))

HwTMilli()
