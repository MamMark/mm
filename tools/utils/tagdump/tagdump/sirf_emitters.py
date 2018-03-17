'''emitters (default) for sirfbin packets'''

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

# emitters for sirfbin data types

from   misc_utils    import buf_str

__version__ = '0.1.3 (se)'


########################################################################
#
# SirfBin RAW messages
#
########################################################################
#
# raw nav strings for output

rnav1a = '    NAV_DATA: nsats: {}, x/y/z (m): {}/{}/{}  vel (m/s): {}/{}/{}'
rnav1b = '    mode1: {:#02x}  mode2: {:#02x}  week10: {}  tow (s): {}'
rnav1c = '    prns: {} hdop: {}'

def emit_sirf_nav_data(level, offset, buf, obj):
    xpos        = obj['xpos'].val
    ypos        = obj['ypos'].val
    zpos        = obj['zpos'].val
    xvel        = obj['xvel'].val
    yvel        = obj['yvel'].val
    zvel        = obj['zvel'].val
    mode1       = obj['mode1'].val
    hdop        = obj['hdop'].val
    mode2       = obj['mode2'].val
    week10      = obj['week10'].val
    tow         = obj['tow'].val
    nsats       = obj['nsats'].val

    print(' ({})'.format(nsats))

    if (level >= 1):
        print(rnav1a.format(nsats, xpos, ypos, zpos,
                            xvel/float(8), yvel/float(8), zvel/float(8)))
        print(rnav1b.format(mode1, mode2, week10, tow/float(100)))
        print(rnav1c.format(buf_str(obj['prns'].val),
                            hdop/float(5)))


########################################################################
#
# raw nav track strings for output

rnavtrk1 = '    NAV_TRACK: week10: {}  tow: {}s  chans: {}'
rnavtrkx = '    {:2}: az: {:5.1f}  el: {:4.1f}  state: {:#06x}  cno (avg): {}'
rnavtrky = '    {:2}: az: {:5.1f}  el: {:4.1f}  state: {:#06x}  cno/s: {}'
rnavtrkz = '    {:2}: az: {:3}  el: {:3}  state: {:#06x}  cno/s: {}'

def emit_sirf_navtrk(level, offset, buf, obj):
    week10 = obj['week10'].val
    tow    = obj['tow'].val/float(100)
    chans  = obj['chans'].val
    print
    if (level >= 1):
        print(rnavtrk1.format(week10, tow, chans))
        for n in range(chans):
            if (obj[n]['cno_avg']):
                print(rnavtrkx.format(obj[n]['sv_id'],
                                      obj[n]['sv_az23']*3.0/2.0,
                                      obj[n]['sv_el2']/2.0,
                                      obj[n]['state'],
                                      obj[n]['cno_avg']))
    if (level >= 2):
        print
        for n in range(chans):
            cno_str = ''
            for i in range(10):
                cno_str += ' {:2}'.format(obj[n]['cno'+str(i)])
            print(rnavtrky.format(obj[n]['sv_id'],
                                  obj[n]['sv_az23']*3.0/2.0,
                                  obj[n]['sv_el2']/2.0,
                                  obj[n]['state'],
                                  cno_str))
    if (level >= 3):
        print
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


def emit_sirf_swver(level, offset, buf, obj):
    print
    if (level >= 1):
        print(obj),


def emit_sirf_vis(level, offset, buf, obj):
    num_sats = obj['vis_sats'].val
    print '({})'.format(num_sats)
    sats = ''
    if level >= 1:
        print('    {:<2} sats:'.format(num_sats)),
        for n in range(num_sats):
            sats += ' {}'.format(obj[n]['sv_id'])
        print sats
    if level >= 2:
        for n in range(num_sats):
            print '      {:2}:  el {:2}   az {:3}'.format(
                obj[n]['sv_id'], obj[n]['sv_el'], obj[n]['sv_az'])


def emit_sirf_ots(level, offset, buf, obj):
    print
    if (level >= 1):
        ans = 'no'
        if obj.val: ans = 'yes'
        print('    OkToSend:  {:>3s}'.format(ans))


########################################################################
#
# raw geo strings for output

rgeo1a = '    GEO_DATA: xweek: {:4} tow: {:10}s, utc: {}/{:02}/{:02}-{:02}:{:02}:{:02}.{}'
rgeo1b = '    lat/long: {:>16s}  {:>16s}, alt(e): {:7.2f} m  alt(msl): {:7.2f} m'
rgeo1c = '    {:6}  {:10s}                                   {:8.2f} ft          {:8.2f} ft'

rgeo2a = '    nav_valid: 0x{:04x}  nav_type: 0x{:04x}  xweek: {:4}  tow: {:10}'
rgeo2b = '    utc: {}/{:02}/{:02}-{:02}:{:02}.{}      sat_mask: 0x{:08x}'
rgeo2c = '    lat: {}  lon: {}  alt_elipsoid: {}  alt_msl: {}  map_datum: {}'
rgeo2d = '    sog: {}  cog: {}  mag_var: {}  climb: {}  heading_rate: {}  ehpe: {}'
rgeo2e = '    evpe: {}  ete: {}  ehve: {}  clock_bias: {}  clock_bias_err: {}'
rgeo2f = '    clock_drift: {}  clock_drift_err: {}  distance: {}  distance_err: {}'
rgeo2g = '    head_err: {}  nsats: {}  hdop: {}  additional_mode: 0x{:02x}'

def emit_sirf_geo(level, offset, buf, obj):
    nav_valid   = obj['nav_valid'].val
    nav_type    = obj['nav_type'].val
    xweek       = obj['week_x'].val
    tow         = obj['tow'].val
    tow         = tow/float(1000)
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
    hdop        = obj['hdop'].val
    additional_mode \
                = obj['additional_mode'].val

    if (nav_valid & 1):
        print(' nl'),
        lock_str = 'nolock'
    else:
        print('  L'),
        lock_str = 'lock'
    print(' ({})'.format(nsats))
    if (level >= 1):
        print(rgeo1a.format(xweek, tow, utc_year, utc_month, utc_day,
                            utc_hour, utc_min, utc_sec, utc_ms))
        print(rgeo1b.format(lat_str, lon_str, alt_elipsoid, alt_msl))
        print(rgeo1c.format(lock_str, '({} sats)'.format(nsats),
                            alt_e_ft, alt_msl_ft))

    if (level >= 2):
        print
        print(rgeo2a.format(nav_valid, nav_type, xweek, obj['tow'].val))
        print(rgeo2b.format(utc_year, utc_month, utc_day, utc_hour, utc_min,
                            obj['utc_ms'].val, sat_mask))
        print(rgeo2c.format(lat, lon, obj['alt_elipsoid'].val,
                            obj['alt_msl'].val, map_datum))
        print(rgeo2d.format(sog, cog, mag_var, climb, heading_rate, ehpe))
        print(rgeo2e.format(evpe, ete, ehve, clock_bias, clock_bias_err))
        print(rgeo2f.format(clock_drift, clock_drift_err, distance, distance_err))
        print(rgeo2g.format(head_err, nsats, hdop, additional_mode))


def emit_sirf_pwr_mode_req(level, offset, buf, obj):
    sid = obj['sid'].val
    timeout = obj['timeout'].val
    control = obj['control'].val
    reserved = obj['reserved'].val
    if sid == 2:
        print(' MPM  {} {}'.format(timeout, control))
    else:
        print(obj)


def emit_sirf_pwr_mode_rsp(level, offset, buf, obj):
    sid = obj['sid'].val
    error = obj['error'].val
    reserved = obj['reserved'].val
    if sid == 2:
        print(' MPM  0x{:04x}'.format(error))
    else:
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


def emit_sirf_statistics(level, offset, buf, obj):
    sid             = obj['sid'].val
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
        print(rstat1a.format(sid, ttff_reset/10.0, ttff_aiding/10.0, ttff_nav/10.0))
        print(rstat1b.format(nav_mode, pos_mode, status,
                             start_mode_names.get(start_mode, 'unk')))
    if (level >= 2):
        print(' raw:')
        print(rstat2a.format(ttff_reset, ttff_aiding, ttff_nav))
        print(rstat2b.format(nav_mode, pos_mode, status, start_mode))
        print(rstat2c.format(pae_n, pae_e, pae_d, time_aiding_err))
        print(rstat2d.format(pos_unc_horz, pos_unc_vert, time_unc, freq_unc))
        print(rstat2e.format(n_aided_ephem, n_aided_acq, freq_aiding_err))
