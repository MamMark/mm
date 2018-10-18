# Setup required to use this module
#
# copy gdb_dblk.py to <app>/.gdb_dblk.py
# and add "source .gdb/.gdb_dblk.py" to the <app>/.gdbinit file.
#

from __future__ import print_function
from binascii   import hexlify

class DblkManager(gdb.Command):
    """Display DblkManager control blocks"""
    def __init__ (self):
        super(DblkManager, self).__init__("dblkManager", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        dmgr = 'DblkManagerP__{}'
        dmcb = 'DblkManagerP__dmc.{}'
        lower = int(gdb.parse_and_eval(dmcb.format('dblk_lower')))
        lower_off = (lower - lower) << 9
        xnext = int(gdb.parse_and_eval(dmcb.format('dblk_nxt')))
        xnext_off = (xnext - lower) << 9
        upper = int(gdb.parse_and_eval(dmcb.format('dblk_upper')))
        upper_off = (upper - lower) << 9
        state = gdb.parse_and_eval(dmcb.format('dm_state'))

        cur = int(gdb.parse_and_eval(dmgr.format('cur_offset')))
        fnd = int(gdb.parse_and_eval(dmgr.format('found_offset')))

        state = state.__str__().replace('DMS_','')
        print('Dmgr: state: {:8s}  {:4x} <= {:^8x} <= {:4x} {:10x}/{:x}'.format(
            state, lower, xnext, upper, fnd, cur))
        print('                   {:08x}    {:08x}    {:08x}'.format(
            lower_off, xnext_off, upper_off))

class DblkMap(gdb.Command):
    """Display DblkMap control blocks"""
    def __init__ (self):
        super(DblkMap, self).__init__("dblkMap", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        dmap   = 'DblkMapFileP__{}'
        dmf_cb = 'DblkMapFileP__dmf_cb.{}'
        dm_cache = 'DblkMapFileP__dmf_cb.cache.{}'

        fill_id = int(gdb.parse_and_eval(dmf_cb.format('fill_blk_id')))
        err     = gdb.parse_and_eval(dmf_cb.format('err'))
        cid     = int(gdb.parse_and_eval(dmf_cb.format('cid')))
        state   = gdb.parse_and_eval(dmf_cb.format('io_state'))

        offset  = int(gdb.parse_and_eval(dm_cache.format('offset')))
        clen    = int(gdb.parse_and_eval(dm_cache.format('len')))
        c_blkid = int(gdb.parse_and_eval(dm_cache.format('id')))
        target  = int(gdb.parse_and_eval(dm_cache.format('target_offset')))
        extra   = int(gdb.parse_and_eval(dm_cache.format('extra')))

        state   = state.__str__().replace('DMF_','')

        print('dblkMap: state: {}  cid: {}  err: {:9s}  fill: {:x}'.format(
            state, cid, err, fill_id))
        print('  cache: ({:04x}) {:08x}/{:03x}  target: {:08x}  extra: {:03x}'.format(
            c_blkid, offset, clen, target, extra))

class ResyncCtl(gdb.Command):
    """Display Resync control blocks"""
    def __init__ (self):
        super(ResyncCtl, self).__init__("resyncCtl", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        max_err = int(gdb.parse_and_eval('ELAST'))
        max_fnd_err = 0xffffffff - max_err + 1
        resync = 'ResyncP__{}'
        r_scb  = 'ResyncP__scb.{}'
        cur    = int(gdb.parse_and_eval(r_scb.format('cur_offset')))
        lower  = int(gdb.parse_and_eval(r_scb.format('lower')))
        upper  = int(gdb.parse_and_eval(r_scb.format('upper')))
        fnd    = int(gdb.parse_and_eval(r_scb.format('found_offset')))
        busy   = int(gdb.parse_and_eval(r_scb.format('in_progress')))
        err    = gdb.parse_and_eval(r_scb.format('err'))
        cid    = int(gdb.parse_and_eval(r_scb.format('cid')))
        xdir   = gdb.parse_and_eval(r_scb.format('direction'))

        busy   = 'B' if busy else 'b'
        xdir   = xdir.__str__().replace('ResyncP__SRCH_','')

        if fnd >= max_fnd_err:
            fnd = 0x100000000 - fnd
            fnd = gdb.parse_and_eval('(error_t) {}'.format(fnd))
        else:
            fnd = '{:08x}'.format(fnd)

        # lower <= cur < upper  dir  B(cid)  err  fnd
        print('resync: {:08x} <= {:08x} < {:08x}  {}  {}({})  {}  f: {}'.format(
            lower, cur, upper, xdir, busy, cid, err, fnd))

DblkManager()
DblkMap()
ResyncCtl()
