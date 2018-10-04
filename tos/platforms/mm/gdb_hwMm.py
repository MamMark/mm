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

class HwTMilli(gdb.Command):
    """Display h/w timer info, TMilli."""
    def __init__ (self):
        super(HwTMilli, self).__init__("hwTMilli", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        ta     = '((Timer_A_Type *) 0x{:08x})'.format(TA1)
        ctl    = int(gdb.parse_and_eval(ta + '->CTL'))
        cctl0  = int(gdb.parse_and_eval(ta + '->CCTL[0]'))
        r      = int(gdb.parse_and_eval(ta + '->R'))
        ccr0   = int(gdb.parse_and_eval(ta + '->CCR[0]'))
        upper  = int(gdb.parse_and_eval('TransformCounterC__0__m_upper'))
        lower  = r >> 5
        tmilli = (upper << 11) | (r >> 5)

        a0_t0 = int(gdb.parse_and_eval('TransformAlarmC__0__m_t0'))
        a0_dt = int(gdb.parse_and_eval('TransformAlarmC__0__m_dt'))
        c0_u  = int(gdb.parse_and_eval('TransformCounterC__0__m_upper'))

        print('   TA1: {:04x}        CTL: {:04x}   CCTL0: {:04x}      CCR0: {:04x}'.format(
            r, ctl, cctl0, ccr0))
        print('tmilli: {:08x}  a0_t0: {:08x}  dt: {:08x}  c0_u: {:08x}'.format(
            tmilli, a0_t0, a0_dt, c0_u))

HwTMilli()
