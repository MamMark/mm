# Copyright (c) 2020, 2021 Eric B. Decker
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

'''emitters for ubxbin packets'''

from   __future__         import print_function

from   ubx_defs       import *
import ubx_defs       as     ubx
from   gps_chip_utils import *
from   misc_utils     import buf_str
from   misc_utils     import dump_buf

__version__ = '0.4.10.dev6'


def emit_default(level, offset, buf, obj, xdir):
    if 'iTOW' in obj:
        iTOW = obj['iTOW'].val
        print('  {:9d}'.format(iTOW))
    else:
        print()
    if (level >= 1):
        print('  {}'.format(obj))


psm_type = {
    0: 'inact',
    1: 'ena',
    2: 'acq',
    3: 'trk',
    4: 'pot',
}


########################################################################
#
# UbxBin RAW message emitters
#
# parameters to emitters:
#
#   level:  debug/verbose level
#   offset: file offset of whole record
#   buf:    current buffer being worked on.
#   obj:    ubx object from ubx populate vector
#   xdir:   direction, 1 for tx from main to gps, 0 from gps to main
#
########################################################################

def emit_ubx_ack(level, offset, buf, obj, xdir):
    ubx     = obj['ubx']
    cid     = obj['ubx']['cid'].val
    ackCid  = obj['ackClassId'].val
    acktype = 'ack' if cid == 0x501 else 'nack'
    print('{:s} ({:04x}) {}'.format(cid_name(ackCid), ackCid, acktype))
    if level >= 1:
        print('  {}'.format(obj))

def emit_ubx_cfg_ant(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    xlen = ubx['len'].val
    if xlen == 0:                       # poll
        print('poll')
    elif xlen == 4:
        flags = obj['var']['flags'].val
        pins  = obj['var']['pins'].val
        xtype = 'set' if xdir else 'rsp'
        print('{:3s} f: {:04x} p: {:04x}'.format(xtype, flags, pins))
    else:
        print('weird')
    if level >= 1:
        print('  {}'.format(obj))

def emit_ubx_cfg_cfg(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    xlen = ubx['len'].val
    clearMask = obj['clearMask'].val
    saveMask  = obj['saveMask'].val
    loadMask  = obj['loadMask'].val
    devMaskStr = '  {:02x}'.format(obj['var']['devMask'].val) if xlen == 13 else ''
    print('c/s/l:  {:04x}/{:04x}/{:04x}{:s}'.format(clearMask, saveMask, loadMask, devMaskStr))
    if level >= 1:
        print('  {}'.format(obj), end = '')


gnss_id = {
    0: 'gps',
    1: 'sbas',
    2: 'gal',
    3: 'bd',
    4: 'imes',
    5: 'qzss',
    6: 'glo',
}

def emit_ubx_cfg_gnss(level, offset, buf, obj, xdir):
    ubx     = obj['ubx']
    xlen    = ubx['len'].val
    if xlen == 0:                       # poll
        print('    poll')
        return
    msgver  = obj['hdr']['msgVer'].val
    if msgver != 0:
        print('   msgVer {:d} not understood'.format(msgver))
        return
    numblks     = obj['hdr']['numConfigBlocks'].val
    numtrkchhw  = obj['hdr']['numTrkChHw'].val
    numtrkchuse = obj['hdr']['numTrkChUse'].val
    print('    hw: {:0d}, use: {:0d}, nblks: {:d}'.format(
        numtrkchhw, numtrkchuse, numblks))
    if numblks > 0:
        print()
        print('    gId            rsv   max    flags')
        for blk in range(numblks):
            gid     = obj['var'][blk]['gnssId'].val
            restrk  = obj['var'][blk]['resTrkCh'].val
            maxtrk  = obj['var'][blk]['maxTrkCh'].val
            flags   = obj['var'][blk]['flags'].val
            ena     = 'ena' if flags & 1 else 'dis'
            flags   = flags >> 16
            print('   {:d}/{:4s}   {:s}    {:2d}     {:2d}     {:04x}'.format(
                gid, gnss_id.get(gid, 'unk'), ena, restrk, maxtrk, flags))
        print()

    if level >= 4:
        print()
        print('  {}'.format(obj))


def emit_ubx_cfg_prt(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    port = obj['var']['portId'].val
    xlen = ubx['len'].val
    if xlen == 1:                       # poll
        print('poll   portId: {}'.format(port))
    elif xlen == 20:
        xtype = 'set' if xdir else 'rsp'
        txrdy = 0
        if port == 4:
            txrdy = obj['var']['txReady'].val
        print('{:3s}    portId: {}, txrdy: {:02x}'.format(xtype, port, txrdy))
    else:
        print('weird  portId: {}  len: {}'.format(port, ubx['len']))
    if level >= 1:
        print('  {}'.format(obj))


inf_proto = {
    0: 'ubx',
    1: 'nmea',
}

def emit_ubx_cfg_inf(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    xlen = ubx['len'].val
    if xlen == 1:
        pid  = obj['var']['protoId'].val
        print('poll  {:s} ({:d})'.format(inf_proto.get(pid, 'unk'), pid))
    elif xlen == 10:
        pid  = obj['var']['protoId'].val
        infmask = bytearray(obj['var']['infMask'].val)
        print('{:s} ({:d}): {:s}'.format(inf_proto.get(pid, 'unk'), pid,
                '-'.join('{:02x}'.format(x) for x in infmask)))
    else:
        print('unhandled len, {:d}'.format(xlen))
    if level >= 4:
        print('  {}'.format(obj), end='')


def emit_ubx_cfg_msg(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    xlen = ubx['len'].val
    cid  = obj['msgClassId'].val
    if xlen == 2:
        print('poll {:8s} ({:04x})'.format(cid_name(cid), cid))
    elif xlen == 3:
        rate = obj['var']['rate']
        print('set  {:16s} ({:04x}), rate: {}'.format(cid_name(cid), cid, rate))
    elif xlen == 8:
        rates = obj['var']['rates'].val
        print('rsp  {:8s} ({:04x}) {}'.format(cid_name(cid), cid,
                                               str(map(ord, rates))))
    else:
        print()
    if level >= 1:
        print('  {}'.format(obj))


# handle both nav5 and navx5
def emit_ubx_cfg_nav5(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    xlen = ubx['len'].val
    if xlen == 0:
        print('get')
        return
    else:
        print()
    if level >= 1:
        print('  {}'.format(obj))


bbr_clr_type = {
    0:          'hot',
    1:          'warm',
    0xffff:     'cold',
}


reset_type = {
    0:          'hw_wd',
    1:          'sw',
    2:          'sw_gps',
    4:          'hw_shut',
    8:          'gps_stop',
    9:          'gps_start',
}


def emit_ubx_cfg_otp(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    xlen = ubx['len'].val
    if xlen == 0:                       # poll
        print('poll')
    elif xlen == 12:
        print('  {}'.format(obj))
    else:
        print('weird')


def emit_ubx_cfg_rst(level, offset, buf, obj, xdir):
    navBbrMask  = obj['navBbrMask'].val
    resetMode   = obj['resetMode'].val
    bbr_clr_str = bbr_clr_type.get(navBbrMask, 'other')
    reset_str   = reset_type.get(resetMode, 'rst/' + str(resetMode))
    print('           {:6s} ({:04x})  {:s} ({:d})'.format(bbr_clr_str, navBbrMask,
                                                          reset_str, resetMode))


def emit_ubx_inf(level, offset, buf, obj, xdir):
    objlen = len(obj)                   # ubx header length
    xlen = obj['len'].val
    print('{:s}'.format(buf[objlen:objlen+xlen]))


mon_hw_astatus = {
    0:  'init',
    1:  'dk',
    2:  'ok',
    3:  'short',
    4:  'open',
}

mon_hw_apower = {
    0:  'off',
    1:  'on',
    2:  'dk',
}


def emit_ubx_mon_hw(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    xlen = ubx['len'].val
    if xlen == 0:                       # poll
        print('poll')
    elif xlen == 60:
        astatus = obj['var']['aStatus'].val
        apower  = obj['var']['aPower'].val
        astatus_str = mon_hw_astatus.get(astatus, 'astatus({:d})'.format(astatus))
        apower_str  = mon_hw_apower.get(apower, 'apower({:d})'.format(apower))
        print('rsp  ant: {:s} {:s}'.format(astatus_str, apower_str))
    else:
        print('weird')
    if level >=1 and xdir == 0:         # if rx display whole packet
        print('  {}'.format(obj))


def emit_ubx_nav_aopstatus(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    xlen = ubx['len'].val
    if xlen == 0:                       # poll
        print('poll')
    elif xlen == 16:
        iTOW    = obj['var']['iTOW'].val
        aopCfg  = obj['var']['aopCfg'].val
        status  = obj['var']['status'].val
        cfgstr  = 'enabled' if aopCfg & 1 else 'disabled'
        statstr = 'running' if status     else 'idle'
        print('  {:9d}  {:s}  {:s}'.format(iTOW, cfgstr, statstr))
    else:
        print('  weird len')
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_dop(level, offset, buf, obj, xdir):
    iTOW = obj['iTOW'].val
    gDOP = float(obj['gDOP'].val)/100
    pDOP = float(obj['pDOP'].val)/100
    tDOP = float(obj['tDOP'].val)/100
    vDOP = float(obj['vDOP'].val)/100
    hDOP = float(obj['hDOP'].val)/100
    print('  {:9d}  g: {:.2f}  p: {:.2f}  t: {:.2f}  v: {:.2f}  h: {:.2f}'.format(
        iTOW, gDOP, pDOP, tDOP, vDOP, hDOP))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_clock(level, offset, buf, obj, xdir):
    iTOW = obj['iTOW'].val
    clkB = obj['clkB'].val
    clkD = obj['clkD'].val
    tAcc = obj['tAcc'].val
    fAcc = obj['fAcc'].val
    print('  {:9d}  b: {:d} d: {:d}  t: {:d}  f: {:d}'.format(
        iTOW, clkB, clkD, tAcc, fAcc))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_posecef(level, offset, buf, obj, xdir):
    iTOW  = obj['iTOW'].val
    ecefX = float(obj['ecefX'].val)/100.
    ecefY = float(obj['ecefY'].val)/100.
    ecefZ = float(obj['ecefZ'].val)/100.
    pAcc  = obj['pAcc'].val
    print('  {:9d}  {:8.2f} {:8.2f} {:8.2f}  pAcc: {}'.format(
        iTOW, ecefX, ecefY, ecefZ, pAcc))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_pvt(level, offset, buf, obj, xdir):
    ubx     = obj['ubx']
    xlen    = ubx['len'].val
    if xlen == 0:                       # poll
        print('poll')
        return
    var      = obj['var']
    iTOW     = var['iTOW'].val
    year     = var['year'].val
    month    = var['month'].val
    day      = var['day'].val
    hour     = var['hour'].val
    xmin     = var['min'].val
    sec      = var['sec'].val
    valid    = var['valid'].val
    tacc     = var['tAcc'].val
    nano     = var['nano'].val
    ftype    = var['fixType'].val
    flags    = var['flags'].val
    flags2   = var['flags2'].val
    numSV    = var['numSV'].val
    lon      = var['lon'].val
    lat      = var['lat'].val
    height   = var['height'].val
    hMSL     = var['hMSL'].val
    pdop     = var['pDOP'].val
    flags3   = var['flags3'].val

    mrstr    = 'M' if valid & 0x8 else 'm'
    mrstr   += 'R' if valid & 0x4 else 'r'
    mrstr   += 'D' if flags & 0x2 else 'd'
    mrstr   += 'F' if flags & 0x1 else 'f'

    tdstr    = 'D' if valid & 0x1 else 'd'
    tdstr   += 'T' if valid & 0x2 else 't'

    fixtype  = gps_fix_name(ftype)

    psm      = (flags >> 2) & 0x7
    psmstr   = psm_type.get(psm, 'psm/' + str(psm))

    lstr     = 'l' if flags3 & 0x1 else 'L'
    flon     = float(lon)/10000000.
    flat     = float(lat)/10000000.

    if tacc == 0xffffffff:
        tacc = -1

    print('  {:9d}  {:5s}  [{:02d}]  vf: {:s}  {:s}: {:04d}/{:02d}/{:02d}-{:02d}:{:02d}:{:02d} {:010d}  {:11.7f} {:12.7f} [t {:4}, p {:4}]'.format(
        iTOW, fixtype, numSV, mrstr, tdstr, year, month, day,
        hour, xmin, sec, nano, flat, flon, tacc, pdop))
    if level >= 1:
        print('  {}'.format(obj))


nav_sat_qual_ind = {
    0:  'no_sig',
    1:  'search',
    2:  'acquired',
    3:  'not_usable',
    4:  'ct',
    5:  'cct',
    6:  'cct',
    7:  'cct',
}

nav_sat_health = {
    0:  'X',
    1:  'H',
    2:  'h',
}

nav_sat_orbit = {
    0:  'none',
    1:  'eph',
    2:  'alm',
    3:  'offline',
    4:  'auton',
    5:  'other',
    6:  'other',
    7:  'other',
}

def emit_ubx_nav_sat(level, offset, buf, obj, xdir):
    iTOW      = obj['iTOW'].val
    version   = obj['version'].val
    if version != 1:
        # strange version
        print('  {:9d}, version not understood ({:d})', iTOW, version)
        return
    numSv     = obj['numSv'].val
    good_sats = 0
    good_sum  = 0
    num_used  = 0
    for sv in range(numSv):
        cno   = obj['var'][sv]['cno'].val
        flags = obj['var'][sv]['flags'].val
        used  = flags & 0x08
        if used:
            num_used  += 1
        if cno > 19:
            good_sats += 1
            good_sum  += cno
    avg = float(good_sum)/good_sats if good_sats else 0.0
    print('  {:9d}  nsats: {:d}  used {:d}  >19: {:d}  avg: {:.2f}'.format(
        iTOW, numSv, num_used, good_sats, avg))
    if level >= 1:
        if numSv > 0:
            print('   Id   cno    el/az    flags  HUAE AO        qual/orbit')
        for sv in range(numSv):
            gnss  = obj['var'][sv]['gnssId'].val
            svId  = obj['var'][sv]['svId'].val
            cno   = obj['var'][sv]['cno'].val
            elev  = obj['var'][sv]['elev'].val
            azim  = obj['var'][sv]['azim'].val
            flags = obj['var'][sv]['flags'].val
            if cno < 20:
                if level < 2:
                    continue

            qual       = flags & 0x7
            qual_str   = nav_sat_qual_ind.get(qual, 'weird')
            health     = (flags >> 4) & 0x3
            orbit      = (flags >> 8) & 0x7
            orbit_str  = nav_sat_orbit.get(orbit, 'orbit')

            flag_str   = nav_sat_health.get(health, 'x')        # health
            flag_str  += 'U' if flags & 0x000008 else 'u'       # used
            flag_str  += 'A' if flags & 0x001000 else 'a'       # almanac avail
            flag_str  += 'E' if flags & 0x000800 else 'e'       # ephemeris avail
            flag_str  += ' '
            flag_str  += 'A' if flags & 0x004000 else 'a'       # AssistNow Auton
            flag_str  += 'O' if flags & 0x002000 else 'o'       # AssistNow Offline

            flag_str  += '  {:>10s}/{:<8s}  '.format(qual_str, orbit_str)

            flag_str  += 'D' if flags & 0x200000 else 'd'       # doppler correction
            flag_str  += 'C' if flags & 0x100000 else 'c'       # carrier correction
            flag_str  += 'P' if flags & 0x100000 else 'p'       # pseudorange corrections
            flag_str  += 'S' if flags & 0x080000 else 's'       # SPARTN corrections
            flag_str  += 'S' if flags & 0x040000 else 's'       # SLAS corrections
            flag_str  += 'R' if flags & 0x020000 else 'r'       # RTCM corrections
            flag_str  += 'S' if flags & 0x010000 else 's'       # SBAS corrections

            flag_str  += ' '
            flag_str  += 'S' if flags & 0x000080 else 's'       # smoothed
            flag_str  += 'D' if flags & 0x000040 else 'd'       # diff corrections

            print('{:3d}:{:03d}  {:02d}   {:03d}/{:03d}  0x{:04x}  {:s}'.format(
                gnss, svId, cno, elev, azim, flags, flag_str))
    if level >= 3:
        print()
        print('  {}'.format(obj))

def emit_ubx_nav_status(level, offset, buf, obj, xdir):
    iTOW     = obj['iTOW'].val
    gpsFix   = obj['gpsFix'].val
    flags    = obj['flags'].val
    fixStat  = obj['fixStat'].val
    flags2   = obj['flags2'].val
    ttff     = float(obj['ttff'].val)/1000.
    msss     = float(obj['msss'].val)/1000.
    fixtype  = gps_fix_name(gpsFix)
    flagstr  = 'T' if flags & 0x8 else 't'
    flagstr += 'W' if flags & 0x4 else 'w'
    flagstr += 'D' if flags & 0x2 else 'd'
    flagstr += 'F' if flags & 0x1 else 'f'
    psm      = (flags2 & 0x3) + 2
    spoof    = (flags2 & 0x18) >> 3
    carr     = flags2 >> 6
    psmstr   = psm_type.get(psm, 'psm/' + str(psm))
    print('  {:9d}  {:5s}  {:6s} f: {:s}  ttff: {:.3f}  ss: {:.3f}  spoof: {}  carr: {}'.format(
        iTOW, fixtype, psmstr, flagstr, ttff, msss, spoof, carr))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_timegps(level, offset, buf, obj, xdir):
    iTOW  = obj['iTOW'].val
    fTOW  = obj['fTOW'].val
    week  = obj['week'].val
    leapS = obj['leapS'].val
    valid = obj['valid'].val
    tAcc  = obj['tAcc'].val
    vstr  = 'L' if valid & 0x4 else 'l'
    vstr += 'W' if valid & 0x2 else 'w'
    vstr += 'T' if valid & 0x1 else 't'
    print('  {:9d}  {:3s}  w: {:4d}  ls: {:2d}  tAcc: {:d}'.format(
        iTOW, vstr, week, leapS, tAcc))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_timels(level, offset, buf, obj, xdir):
    iTOW          = obj['iTOW'].val
    srcOfCurrLs   = obj['srcOfCurrLs'].val
    currLs        = obj['currLs'].val
    srcOfLsChange = obj['srcOfCurrLs'].val
    lsChange      = obj['lsChange'].val
    timeToLsEvent = obj['timeToLsEvent'].val
    lsGpsWn       = obj['dateOfLsGpsWn'].val
    lsGpsDn       = obj['dateOfLsGpsDn'].val
    valid         = obj['valid'].val
    vstr  = 'E' if valid & 0x2 else 'e'
    vstr += 'C' if valid & 0x1 else 'c'
    print('  {:9d}  {:2s}  cur: {:d}/{:d}  chg: {:d}/{:d}  delta: {:d}  w/d: {:d}/{:d}'.format(
        iTOW, vstr, srcOfCurrLs, currLs, srcOfLsChange, lsChange,
        timeToLsEvent, lsGpsWn, lsGpsDn))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_timeutc(level, offset, buf, obj, xdir):
    iTOW  = obj['iTOW'].val
    tAcc  = obj['tAcc'].val
    nano  = obj['nano'].val
    year  = obj['year'].val
    month = obj['month'].val
    day   = obj['day'].val
    hour  = obj['hour'].val
    xmin  = obj['min'].val
    sec   = obj['sec'].val
    valid = obj['valid'].val
    vstr  = 'U' if valid & 0x4 else 'u'
    vstr += 'W' if valid & 0x2 else 'w'
    vstr += 'T' if valid & 0x1 else 't'
    std   = valid >> 4
    print('  {:9d}  {:3s}  {:4d}/{:02d}/{:02d} {:02d}:{:02d}:{:02d} {:06d}  std: {:d}  tAcc: {:d}'.format(
        iTOW, vstr, year, month, day, hour, xmin, sec, nano, std, tAcc))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_rxm_pmreq(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    xlen = ubx['len'].val
    dur   = obj['var']['duration'].val
    flags = obj['var']['flags'].val
    if xlen == 8:
        print('dur: {}    {:04x}'.format(dur, flags))
    elif xlen == 16:
        wakeup = obj['var']['wakeupSources'].val
        print('dur: {}    {:04x}  {:04x}'.format(dur, flags, wakeup))
    else:
        print('xxxx')
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_tim_tp(level, offset, buf, obj, xdir):
    towMS    = obj['towMS'].val
    towSubMS = obj['towSubMS'].val
    qErr     = obj['qErr'].val
    week     = obj['week'].val
    flags    = obj['flags'].val
    refInfo  = obj['refInfo'].val
    fstr  = 'Q' if flags & 0x10 else ''
    fstr += 'U' if flags & 0x2  else 'u'
    fstr += 'u' if flags & 0x1  else 'g'
    raim  = (flags >> 2) & 0x03
    utcstd =  refInfo >> 4
    timeref = refInfo & 0xf
    print('{:8d}  {:>3s}/{:d}  s: {:d}  q: {:d}  w: {:d}  f: {:02x}  ref: {:02x}  {:d}/{:d}'.format(
        towMS, fstr, raim, towSubMS, qErr, week, flags, refInfo, utcstd, timeref))
    if level >= 1:
        print('  {}'.format(obj))


upd_sos_cmd = {
    0:  'create',
    1:  'clear',
    2:  'sos_ack',
    3:  'restored',
}

upd_sos_create_ack = {
    0:  'nack',
    1:  'ack',
}

upd_sos_restore_rsp = {
    0:  'unknown',
    1:  'failed',
    2:  'restored',
    3:  'no backup',
}

def emit_ubx_upd_sos(level, offset, buf, obj, xdir):
    ubx  = obj['ubx']
    xlen = ubx['len'].val
    if xlen == 0:                       # poll
        if xdir:
            print('poll')
        else:
            print('poll, weird')
    elif xlen == 4:
        cmd     = obj['var']['cmd'].val
        cmd_str = upd_sos_cmd.get(cmd, 'cmd/{:d}'.format(cmd))
        if xdir == -1:
            xtype = 'cmd'
        else:
            xtype   = 'cmd' if xdir else 'rsp'
        print('{:3s} {:s}'.format(xtype, cmd_str))
    elif xlen == 8:
        cmd     = obj['var']['cmd'].val
        cmd_str = upd_sos_cmd.get(cmd, 'cmd/{:d}'.format(cmd))
        rsp     = obj['var']['rsp'].val
        if cmd == 2:
            # create ack
            rsp_str = upd_sos_create_ack.get(rsp, 'rsp/{:d}'.format(rsp))
        elif cmd == 3:
            rsp_str = upd_sos_restore_rsp.get(rsp, 'rsp/{:d}'.format(rsp))
        else:
            rsp_str = 'rsp/{:d}'.format(rsp)
        if xdir == -1:
            xtype = 'rsp'
        else:
            xtype = 'cmd' if xdir else 'rsp'
        print('{:3s} {:s} {:s}'.format(xtype, cmd_str, rsp_str))
    else:
        print('weird')
    if level >= 1:
        print('  {}'.format(obj))
