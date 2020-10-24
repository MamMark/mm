# Copyright (c) 2020 Eric B. Decker
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

__version__ = '0.4.8.dev3'


def emit_default(level, offset, buf, obj, xdir):
    if 'iTOW' in obj:
        iTOW = obj['iTOW'].val
        print('{:9d}'.format(iTOW))
    else:
        print()
    if (level >= 1):
        print('  {}'.format(obj))


fix_type = {
    0: 'nofix',
    1: 'dr',
    2: '2d',
    3: '3d',
    4: 'gps_dr',
    5: 'time',
}

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
    ubx  = obj['ubx']
    cid    = obj['ubx']['cid'].val
    ackCid = obj['ackClassId'].val
    acktype = 'ack' if cid == 0x501 else 'nack'
    print('{:s} ({:04x}) {}'.format(cid_name(ackCid), ackCid, acktype))
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


def emit_ubx_nav_aopstatus(level, offset, buf, obj, xdir):
    iTOW    = obj['iTOW'].val
    aopCfg  = obj['aopCfg'].val
    status  = obj['status'].val
    cfgstr  = 'enabled' if aopCfg & 1 else 'disabled'
    statstr = 'running' if status     else 'idle'
    print('{:9d}  {:s}  {:s}'.format(iTOW, cfgstr, statstr))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_dop(level, offset, buf, obj, xdir):
    iTOW = obj['iTOW'].val
    gDOP = float(obj['gDOP'].val)/100
    pDOP = float(obj['pDOP'].val)/100
    tDOP = float(obj['tDOP'].val)/100
    vDOP = float(obj['vDOP'].val)/100
    hDOP = float(obj['hDOP'].val)/100
    print('{:9d}  g: {:.2f}  p: {:.2f}  t: {:.2f}  v: {:.2f}  h: {:.2f}'.format(
        iTOW, gDOP, pDOP, tDOP, vDOP, hDOP))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_clock(level, offset, buf, obj, xdir):
    iTOW = obj['iTOW'].val
    clkB = obj['clkB'].val
    clkD = obj['clkD'].val
    tAcc = obj['tAcc'].val
    fAcc = obj['fAcc'].val
    print('{:9d}  b: {:d} d: {:d}  t: {:d}  f: {:d}'.format(
        iTOW, clkB, clkD, tAcc, fAcc))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_posecef(level, offset, buf, obj, xdir):
    iTOW  = obj['iTOW'].val
    ecefX = float(obj['ecefX'].val)/100.
    ecefY = float(obj['ecefY'].val)/100.
    ecefZ = float(obj['ecefZ'].val)/100.
    pAcc  = obj['pAcc'].val
    print('{:9d}  {:8.2f} {:8.2f} {:8.2f}  pAcc: {}'.format(
        iTOW, ecefX, ecefY, ecefZ, pAcc))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_pvt(level, offset, buf, obj, xdir):
    iTOW     = obj['iTOW'].val
    year     = obj['year'].val
    month    = obj['month'].val
    day      = obj['day'].val
    hour     = obj['hour'].val
    xmin     = obj['min'].val
    sec      = obj['sec'].val
    valid    = obj['valid'].val
    tacc     = obj['tAcc'].val
    nano     = obj['nano'].val
    ftype    = obj['fixType'].val
    flags    = obj['flags'].val
    flags2   = obj['flags2'].val
    numSV    = obj['numSV'].val
    lon      = obj['lon'].val
    lat      = obj['lat'].val
    height   = obj['height'].val
    hMSL     = obj['hMSL'].val
    pdop     = obj['pDOP'].val
    flags3   = obj['flags3'].val

    mrstr    = 'M' if valid & 0x8 else 'm'
    mrstr   += 'R' if valid & 0x4 else 'r'
    mrstr   += 'D' if flags & 0x2 else 'd'
    mrstr   += 'F' if flags & 0x1 else 'f'

    tdstr    = 'D' if valid & 0x1 else 'd'
    tdstr   += 'T' if valid & 0x2 else 't'

    fixtype  = fix_type.get(ftype, 'fix/' + str(ftype))

    psm      = (flags >> 2) & 0x7
    psmstr   = psm_type.get(psm, 'psm/' + str(psm))

    lstr     = 'l' if flags3 & 0x1 else 'L'
    flon     = float(lon)/10000000.
    flat     = float(lat)/10000000.

    if tacc == 0xffffffff:
        tacc = -1

    print('{:9d}  {:5s}  ({:02d})  vf: {:s}  {:s}: {:04d}/{:02d}/{:02d}-{:02d}:{:02d}:{:02d} {:010d}  {:11.7f} {:12.7f} [t {:4}, p {:4}]'.format(
        iTOW, fixtype, numSV, mrstr, tdstr, year, month, day,
        hour, xmin, sec, nano, flat, flon, tacc, pdop))
    if level >= 1:
        print('  {}'.format(obj))


def emit_ubx_nav_status(level, offset, buf, obj, xdir):
    iTOW     = obj['iTOW'].val
    gpsFix   = obj['gpsFix'].val
    flags    = obj['flags'].val
    fixStat  = obj['fixStat'].val
    flags2   = obj['flags2'].val
    ttff     = float(obj['ttff'].val)/1000.
    msss     = float(obj['msss'].val)/1000.
    fixtype  = fix_type.get(gpsFix, 'fix/' + str(gpsFix))
    flagstr  = 'T' if flags & 0x8 else 't'
    flagstr += 'W' if flags & 0x4 else 'w'
    flagstr += 'D' if flags & 0x2 else 'd'
    flagstr += 'F' if flags & 0x1 else 'f'
    psm      = (flags2 & 0x3) + 2
    spoof    = (flags2 & 0x18) >> 3
    carr     = flags2 >> 6
    psmstr   = psm_type.get(psm, 'psm/' + str(psm))
    print('{:9d}  {:5s}  {:6s} f: {:s}  ttff: {:.3f}  ss: {:.3f}  spoof: {}  carr: {}'.format(
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
    print('{:9d}  {:3s}  w: {:4d}  ls: {:2d}  tAcc: {:d}'.format(
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
    print('{:9d}  {:2s}  cur: {:d}/{:d}  chg: {:d}/{:d}  delta: {:d}  w/d: {:d}/{:d}'.format(
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
    print('{:9d}  {:3s}  {:4d}/{:02d}/{:02d} {:02d}:{:02d}:{:02d} {:06d}  std: {:d}  tAcc: {:d}'.format(
        iTOW, vstr, year, month, day, hour, xmin, sec, nano, std, tAcc))
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


# raw nav strings for output

rnav1a = '    NAV_DATA: nsats: {}, x/y/z (m): {}/{}/{}  vel (m/s): {}/{}/{}'
rnav1b = '    mode1: {:#02x}  mode2: {:#02x}  gps10: {}/{:.3f}'
rnav1c = '    prns: [{}] hdop: {}'

# mid 2 navdata
def emit_sirf_nav_data(level, offset, buf, obj):
    xpos        = obj['xpos'].val
    ypos        = obj['ypos'].val
    zpos        = obj['zpos'].val
    xvel        = obj['xvel8'].val/float(8)
    yvel        = obj['yvel8'].val/float(8)
    zvel        = obj['zvel8'].val/float(8)
    mode1       = obj['mode1'].val
    hdop        = obj['hdop5'].val/float(5)
    mode2       = obj['mode2'].val
    week10      = obj['week10'].val
    tow         = obj['tow100'].val/float(100)
    nsats       = obj['nsats'].val

    fix     = mode1 & GPS_FIX_MASK
    fix_str = gps_fix_name(fix)
    print('   {:5s}  [{}]'.format(fix_str, nsats))

    if (level >= 1):
        prns     = obj['prns'].val
        prn_list = ' '.join(['{:02}'.format(ord(x)) for x in prns if ord(x) != 0])
        print(rnav1a.format(nsats, xpos, ypos, zpos, xvel, yvel, zvel))
        print(rnav1b.format(mode1, mode2, week10, tow))
        print(rnav1c.format(prn_list, hdop))


########################################################################
#
# raw nav track strings for output

rnavtrk1 = '    NAV_TRACK: {}/{:.3f}s  chans: {}'
rnavtrkx = '    {:3}: az: {:5.1f}  el: {:4.1f}  state: {:#04x}  {:7}  cno (avg): {}'
rnavtrky = '    {:3}: az: {:5.1f}  el: {:4.1f}  state: {:#04x}  cno/s: {}'
rnavtrkz = '    {:3}: az: {:3}  el: {:3}  state: {:#04x}  cno/s: {}'

# mid 4 navtrk
def emit_sirf_navtrk(level, offset, buf, obj):
    week10 = obj['week10'].val
    tow    = obj['tow100'].val/float(100)
    chans  = obj['chans'].val
    good_sats = 0
    for n in range(chans):
        if obj[n]['cno_avg']     and \
           obj[n]['sv_id'] <= 32 and \
           obj[n]['cno_avg'] > 20.0:
            good_sats += 1
    print('         [{}]'.format(good_sats))
    if (level >= 1):
        print(rnavtrk1.format(week10, tow, chans))
        for n in range(chans):
            if (obj[n]['cno_avg']):
                state = obj[n]['state']
                print(rnavtrkx.format(obj[n]['sv_id'],
                                      obj[n]['sv_az23']*3.0/2.0,
                                      obj[n]['sv_el2']/2.0,
                                      state, gps_expand_trk_state_short(state),
                                      obj[n]['cno_avg']))
    if (level >= 2):
        print()
        for n in range(chans):
            cno_str = ''
            state = obj[n]['state']
            for i in range(10):
                cno_str += ' {:2}'.format(obj[n]['cno'+str(i)])
            print(rnavtrky.format(obj[n]['sv_id'],
                                  obj[n]['sv_az23']*3.0/2.0,
                                  obj[n]['sv_el2']/2.0,
                                  state,
                                  cno_str))
            if state:
                print('                        ', end='')
                print('             ', end='')
                print('{:#4x} {}'.format(state, gps_expand_trk_state_long(state)))
    if (level >= 3):
        print()
        print('raw:')
        for n in range(chans):
            cno_str = ''
            for i in range(10):
                cno_str += ' {:2}'.format(obj[n]['cno'+str(i)])
            print(rnavtrkz.format(obj[n]['sv_id'],
                                  obj[n]['sv_az23'],
                                  obj[n]['sv_el2'],
                                  obj[n]['state'],
                                  cno_str))


# mid 6 swver
def emit_sirf_swver(level, offset, buf, obj):
    print()
    if (level >= 1):
        print('    {}'.format(obj))

# mids 11 and 12, ack/nack
def emit_sirf_ack_nack(level, offset, buf, obj):
    print(' ({}/{})'.format(buf[0], buf[1]))


# mid 14, almanac data
def emit_sirf_alm_data(level, offset, buf, obj):
    svid   = obj['sv_id'].val
    week   = obj['alm_week_status'].val
    data   = obj['data'].val
    chksum = obj['checksum'].val
    ok     = 'G' if (week & 0x3f) else 'x'
    week = week >> 6
    print('  {:2d}/{}'.format(svid, ok))
    if level >= 1:
        print('    sv: {:2d}  week: {:4d}  checksum: 0x{:04x}'.format(
            svid, week, chksum))
    if level >= 2:
        print()
        dump_buf(data, '    ', 'data: ')


# mid 15, ephemeris data
def emit_sirf_ephem_data(level, offset, buf, obj):
    svid   = obj['sv_id'].val
    data   = obj['data'].val
    print('  {}'.format(svid))
    if level >= 2:
        print()
        dump_buf(data, '    ', 'data: ')


# mid 18, OkToSend
def emit_sirf_ots(level, offset, buf, obj):
    ans = 'yes' if obj.val else 'no'
    print(' (' + ans + ')')


def emit_sirf_vis(level, offset, buf, obj):
    num_sats = obj['vis_sats'].val
    print('          [{}]'.format(num_sats))
    sats = [ obj[n]['sv_id'] for n in range(num_sats) ]
    if level >= 1:
        print('    {:<2} sats: {}'.format(num_sats, " ".join(map(str, sats))))
    if level >= 2:
        for n in range(num_sats):
            print('      {:2}:  el {:2}   az {:3}'.format(
                obj[n]['sv_id'], obj[n]['sv_el'], obj[n]['sv_az']))


########################################################################
#
# raw geo strings for output

rgeo1a = '    GEO_DATA:     {:4}/{:.3f}s, utc: {}/{:02}/{:02}-{:02}:{:02}:{:02}.{:03}'
rgeo1b = '    lat/long: {:>16s}  {:>16s}, alt(e): {:7.2f} m  alt(msl): {:7.2f} m'
rgeo1c = '    {:53}{:8.2f} ft          {:8.2f} ft'

rgeo2a = '    nav_valid: 0x{:04x}  nav_type: 0x{:04x}  gps: {:4}/{:<10}'
rgeo2b = '    utc: {}/{:02}/{:02}-{:02}:{:02}.{:03}      sat_mask: 0x{:08x}'
rgeo2c = '    lat: {}  lon: {}  alt_elipsoid: {}  alt_msl: {}  map_datum: {}'
rgeo2d = '    sog: {}  cog: {}  mag_var: {}  climb: {}  heading_rate: {}  ehpe: {}'
rgeo2e = '    evpe: {}  ete: {}  ehve: {}  clock_bias: {}  clock_bias_err: {}'
rgeo2f = '    clock_drift: {}  clock_drift_err: {}  distance: {}  distance_err: {}'
rgeo2g = '    head_err: {}  nsats: {}  hdop: {}  additional_mode: 0x{:02x}'

def emit_sirf_geo(level, offset, buf, obj):
    nav_valid   = obj['nav_valid'].val
    nav_type    = obj['nav_type'].val
    xweek       = obj['week_x'].val
    tow         = obj['tow1000'].val/float(1000)
    utc_year    = obj['utc_year'].val
    utc_month   = obj['utc_month'].val
    utc_day     = obj['utc_day'].val
    utc_hour    = obj['utc_hour'].val
    utc_min     = obj['utc_min'].val
    utc_ms      = obj['utc_ms'].val
    utc_sec     = utc_ms/1000
    utc_ms      = (utc_ms - utc_sec * 1000)
    sat_mask    = obj['sat_mask'].val
    lat         = obj['lat'].val
    if (lat < 0):
        lat_str = '{}'.format(-lat/float(10000000)) + '(S)'
    else:
        lat_str = '{}'.format(lat/float(10000000)) + '(N)'
    lon         = obj['lon'].val
    if (lon < 0):
        lon_str = '{}'.format(-lon/float(10000000)) + '(W)'
    else:
        lon_str = '{}'.format(lon/float(10000000)) + '(E)'
    alt_elipsoid= obj['alt_elipsoid'].val
    alt_elipsoid /= float(100)
    alt_msl     = obj['alt_msl'].val
    alt_msl    /= float(100)
    alt_e_ft    = alt_elipsoid * 3.28084
    alt_msl_ft  = alt_msl * 3.28084
    map_datum   = obj['map_datum'].val
    sog         = obj['sog'].val
    cog         = obj['cog'].val
    mag_var     = obj['mag_var'].val
    climb       = obj['climb'].val
    heading_rate= obj['heading_rate'].val
    ehpe        = obj['ehpe'].val
    evpe        = obj['evpe'].val
    ete         = obj['ete'].val
    ehve        = obj['ehve'].val
    clock_bias  = obj['clock_bias'].val
    clock_bias_err \
                = obj['clock_bias_err'].val
    clock_drift = obj['clock_drift'].val
    clock_drift_err \
                = obj['clock_drift_err'].val
    distance    = obj['distance'].val
    distance_err= obj['distance_err'].val
    head_err    = obj['head_err'].val
    nsats       = obj['nsats'].val
    hdop        = obj['hdop5'].val
    additional_mode \
                = obj['additional_mode'].val
    fix = (nav_type & GPS_FIX_MASK)
    fix = GPS_OD_FIX if fix and nav_valid == 0 else fix
    fix_str = gps_fix_name(fix)
    fix_str = 'nofix_OD' if fix == 0 and nav_valid == 0 else fix_str
    print('   {:5}  [{}]'.format(fix_str, nsats))
    if (level >= 1):
        print(rgeo1a.format(xweek, tow, utc_year, utc_month, utc_day,
                            utc_hour, utc_min, utc_sec, utc_ms))
        print(rgeo1b.format(lat_str, lon_str, alt_elipsoid, alt_msl))
        sat_str = '{} sats ({}) [{}]'.format(nsats, fix_str, gps_expand_satmask(sat_mask))
        print(rgeo1c.format(sat_str, alt_e_ft, alt_msl_ft))

    if (level >= 2):
        print()
        print(rgeo2a.format(nav_valid, nav_type, xweek, obj['tow1000'].val))
        print(rgeo2b.format(utc_year, utc_month, utc_day, utc_hour, utc_min,
                            obj['utc_ms'].val, sat_mask))
        print(rgeo2c.format(lat, lon, obj['alt_elipsoid'].val,
                            obj['alt_msl'].val, map_datum))
        print(rgeo2d.format(sog, cog, mag_var, climb, heading_rate, ehpe))
        print(rgeo2e.format(evpe, ete, ehve, clock_bias, clock_bias_err))
        print(rgeo2f.format(clock_drift, clock_drift_err, distance, distance_err))
        print(rgeo2g.format(head_err, nsats, hdop, additional_mode))


def emit_sirf_sid_dispatch(level, offset, buf, obj, table, table_name):
    sid = buf[0]
    v   = table.get(sid, (None, None, None, 'sid/' + str(sid), ''))
    emitters = v[EE_EMITTERS]
    obj      = v[EE_OBJECT]
    name     = v[EE_NAME]
    print(' ({})'.format(name), end = '')
    if not emitters or len(emitters) == 0:
        print()                         # default clean line
        if (level >= 5):
            print('*** {}: no emitters defined for sid {}'.format(
                table_name, sid))
        return
    for e in emitters:
        e(level, offset, buf[1:], obj)  # ignore the sid

def emit_sirf_ee56(level, offset, buf, obj):
    emit_sirf_sid_dispatch(level, offset, buf, obj, sirf.ee56_table, 'sirf_ee56')

def emit_sirf_nl64(level, offset, buf, obj):
    emit_sirf_sid_dispatch(level, offset, buf, obj, sirf.nl64_table, 'sirf_nl64')

def emit_sirf_stat70(level, offset, buf, obj):
    emit_sirf_sid_dispatch(level, offset, buf, obj, sirf.stat70_table, 'sirf_stat70')

def emit_tcxo93(level, offset, buf, obj):
    emit_sirf_sid_dispatch(level, offset, buf, obj, sirf.tcxo93_table, 'tcxo93')

def emit_sirf_stat212(level, offset, buf, obj):
    emit_sirf_sid_dispatch(level, offset, buf, obj, sirf.stat212_table, 'sirf_stat212')

def emit_tcxo221(level, offset, buf, obj):
    emit_sirf_sid_dispatch(level, offset, buf, obj, sirf.tcxo221_table, 'tcxo221')

def emit_mid225(level, offset, buf, obj):
    emit_sirf_sid_dispatch(level, offset, buf, obj, sirf.mid225_table, 'mid225')

def emit_sirf_ee232(level, offset, buf, obj):
    emit_sirf_sid_dispatch(level, offset, buf, obj, sirf.ee232_table, 'sirf_ee232')


def emit_ee56_bcastEph(level, offset, buf, obj):
    channel = obj['channel'].val
    svid    = obj['svid'].val
    print('  c{} s{}'.format(channel, svid))
    if (level >= 1):
        print()
        data = obj['data'].val
        dump_buf(data, '    ', 'data: ')


def emit_ee56_sifStat(level, offset, buf, obj):
    print()
    if (level >= 1):
        print('    {}'.format(obj))


# mid 128, init data source, restart or factory reset
def emit_sirf_init_data_src(level, offset, buf, obj):
    reset_config = obj['reset_config'].val
    print('  (0x{:02x})'.format(reset_config))
    if level >= 1:
        print('    {}'.format(obj))


# mid 130, set almanac data
def emit_sirf_alm_set(level, offset, buf, obj):
    print()
    data   = obj['data'].val
    if level >= 2:
        dump_buf(data, '    ', 'data: ')


# mid 149, set ephemeris data
def emit_sirf_ephem_set(level, offset, buf, obj):
    print()
    data   = obj['data'].val
    if level >= 2:
        dump_buf(data, '    ', 'data: ')


mode_names = {
    0: 'single',
    1: 'poll',
    2: 'all',
    3: 'def_nav',                       # 2, 4
    4: 'debug',                         # 9, 255
    5: 'nav_debug',                     # 7, 28, 29, 30, 31
}


# mid 166, setMsgRate
def emit_sirf_set_msg_rate(level, offset, buf, obj):
    mode = obj['mode'].val
    mid  = obj['mid'].val
    rate = obj['rate'].val

    print(' ({},{},{})'.format(mode,mid,rate))
    mode_name = mode_names.get(mode, 'mode/' + str(mode))
    v = sirf.mid_table.get(mid, (None, None, None, 'mid/' + str(mid)))
    mid_name = v[MID_NAME]
    rate = 'off' if rate == 0 else str(rate)
    result = 'ick'
    if mode_name == 'single':
        mid_num = '  <{} ({:02x})>'.format(mid, mid)
        result = ' '.join(['single ',    mid_name, rate, mid_num])
    elif mode_name == 'poll':
        mid_num = '  <{} ({:02x})>'.format(mid, mid)
        result = ' '.join(['poll ',      mid_name, mid_num])
    elif mode_name == 'all':
        result = ' '.join(['all ',       rate])
    elif mode_name == 'def_nav':
        result = ' '.join(['def_nav ',   rate, '  <2,4>'])
    elif mode_name == 'debug':
        result = ' '.join(['debug ',     rate, '  <9,255>'])
    elif mode_name == 'nav_debug':
        result = ' '.join(['nav_debug ', rate, '  <7, 28-31>'])
    else:
        mid_num = '  <{} ({:02x})>'.format(mid, mid)
        result = ' '.join([mode_name,    mid_name, rate, mid_num])
    print('    setMsgRate: {}'.format(result))


# mid 233/<sid>
def emit_sirf_pwr_mode_req(level, offset, buf, obj):
    sid = obj['sid'].val
    timeout = obj['timeout'].val
    control = obj['control'].val
    reserved = obj['reserved'].val
    if sid == 2:
        print(' MPM  {} {}'.format(timeout, control))
    else:
        print()                         # clean line
        print(obj)


# sirf_pwr_mode_rsp
#
# error codes in the rsp packet varies depending on which SID it is.
# error in the object is 2 bytes and matches the MPM rsp sid (2).
# other sids (0-1, 3-4) have a single byte response, according to
# the limited docs we have.  But we haven't seen actual behaviour.

def emit_sirf_pwr_mode_rsp(level, offset, buf, obj):
    sid = obj['sid'].val
    error = obj['error'].val
    reserved = obj['reserved'].val
    if sid == 2:
        if error == 0x0010: ok_str = 'ok'
        else:               ok_str = 'oops'
        print(' MPM {} (0x{:04x})'.format(ok_str, error))
        if level >= 1 or error != 0x0010:
            err_list = []
            if (error == 0x0000): err_list.append('none?')
            if (error & 0x0010):  err_list.append('ok')
            if (error & 0x0020):  err_list.append('noKF')
            if (error & 0x0040):  err_list.append('noRTC')
            if (error & 0x0080):  err_list.append('hpe')
            if (error & 0x0100):  err_list.append('MPMpend')
            if (error == 0x0010): pre = '   '
            else:                 pre = '***'
            if (error != 0x0010):
                print('{} MPM response: {:04x} - <{}>'.format(pre, error,
                                                   " ".join(err_list)))
    else:
        print()                         # get clean line
        print(obj)


rstat1a = '    STATS:  sid:    {}  ttff_reset:  {:3.1f}   ttff_aiding:  {:3.1f}      ttff_nav:  {:3.1f}'
rstat1b = '       nav_mode: 0x{:02x}    pos_mode: 0x{:02x}   status:    0x{:04x}    start_mode: {:>4}'

rstat2a = '    ttff_reset:   {:2}   ttff_aiding:    {:2}     ttff_nav:      {:2}'
rstat2b = '    nav_mode:   0x{:02x}      pos_mode:  0x{:02x}       status:  0x{:04x}  start_mode:      {}'
rstat2c = '    pae_n:         {}         pae_e:     {}        pae_d:       {}  time_aiding_err: {}'
rstat2d = '    pos_unc_horz:  {}  pos_unc_vert:     {}     time_unc:       {}  freq_unc:        {}'
rstat2e = '    n_aided_ephem: {}   n_aided_acq:     {}                        freq_aiding_err: {}'

# start_mode
start_mode_names = {
     0: "cold",
     1: "warm",
     2: "hot",
     3: "fast",
}


def emit_mid225_6_stats(level, offset, buf, obj):
    sid             = 6
    ttff_reset      = obj['ttff_reset'].val
    ttff_aiding     = obj['ttff_aiding'].val
    ttff_nav        = obj['ttff_nav'].val
    pae_n           = obj['pae_n'].val
    pae_e           = obj['pae_e'].val
    pae_d           = obj['pae_d'].val
    time_aiding_err = obj['time_aiding_err'].val
    freq_aiding_err = obj['freq_aiding_err'].val
    pos_unc_horz    = obj['pos_unc_horz'].val
    pos_unc_vert    = obj['pos_unc_vert'].val
    time_unc        = obj['time_unc'].val
    freq_unc        = obj['freq_unc'].val
    n_aided_ephem   = obj['n_aided_ephem'].val
    n_aided_acq     = obj['n_aided_acq'].val
    nav_mode        = obj['nav_mode'].val
    pos_mode        = obj['pos_mode'].val
    status          = obj['status'].val
    start_mode      = obj['start_mode'].val
    print('({})'.format(sid))
    if (level >= 1):
        print(rstat1a.format(sid, ttff_reset/10.0, ttff_aiding/10.0,
                             ttff_nav/10.0))
        print(rstat1b.format(nav_mode, pos_mode, status,
                             start_mode_names.get(start_mode,
                                          'start/' + str(start_mode))))
    if (level >= 2):
        print(' raw:')
        print(rstat2a.format(ttff_reset, ttff_aiding, ttff_nav))
        print(rstat2b.format(nav_mode, pos_mode, status, start_mode))
        print(rstat2c.format(pae_n, pae_e, pae_d, time_aiding_err))
        print(rstat2d.format(pos_unc_horz, pos_unc_vert, time_unc, freq_unc))
        print(rstat2e.format(n_aided_ephem, n_aided_acq, freq_aiding_err))

def emit_sirf_dev_data(level, offset, buf, obj):
    print()
    if (level >= 1):
        print('    {}'.format(obj))
