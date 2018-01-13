#
# Copyright (c) 2017-2018 Eric B. Decker, Daniel J. Maltbie
# All rights reserved.
#
# Decoders for gps data types

import globals       as     g
from   core_records  import *
from   gps_headers   import *
from   core_decoders import rec0

def decode_gps_version(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_GPS_VERSION] = \
        (0, decode_gps_version, dt_gps_ver_obj, "GPS_VERSION")


def decode_gps_time(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_GPS_TIME] = (0, decode_gps_time, dt_gps_time_obj, "GPS_TIME")


def decode_gps_geo(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_GPS_GEO] = (0, decode_gps_geo, dt_gps_geo_obj, "GPS_GEO")


def decode_gps_xyz(level, offset, buf, obj):
    print_record(offset, buf)
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_GPS_XYZ] = (0, decode_gps_xyz, dt_gps_xyz_obj, "GPS_XYZ")


########################################################################
#
# GPS RAW messages
#

def gps_nav_decoder(level, offset, buf, obj):
    if (level >= 1):
        obj.set(buf)
        print(obj)

g.mid_table[2] = (gps_nav_decoder, gps_nav_obj, "NAV_DATA")


def gps_navtrk_decoder(level, offset, buf, obj):
    if (level >= 1):
        consumed = obj.set(buf)
        print(obj)
        chans = obj['chans'].val
        for n in range(chans):
            consumed += gps_navtrk_chan.set(buf[consumed:])
            print(gps_navtrk_chan)

g.mid_table[4] = (gps_navtrk_decoder, gps_navtrk_obj, "NAV_TRACK")


def gps_swver_decoder(level, offset, buf, obj):
    if (level >= 1):
        consumed = obj.set(buf)
        len0 = obj['str0_len'].val
        len1 = obj['str1_len'].val
        str0 = buf[consumed:consumed+len0-1]
        str1 = buf[consumed+len0:consumed+len0+len1-1]
        print('\n  --<{}>--  --<{}>--'.format(str0, str1)),

g.mid_table[6] = (gps_swver_decoder, gps_swver_obj, "SW_VER")


def gps_vis_decoder(level, offset, buf, obj):
    if (level >= 1):
        consumed = obj.set(buf)
        print(obj)
        num_sats = obj['vis_sats'].val
        for n in range(num_sats):
            consumed += gps_vis_azel.set(buf[consumed:])
            print(gps_vis_azel)

g.mid_table[13] = (gps_vis_decoder, gps_vis_obj, "VIS_LIST")


def gps_ots_decoder(level, offset, buf, obj):
    if (level >= 1):
        obj.set(buf)
        ans = 'no'
        if obj.val: ans = 'yes'
        print
        print('    OkToSend:  {:>3s}'.format(ans)),

g.mid_table[18] = (gps_ots_decoder, gps_ots_obj, "OkToSend")


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

def gps_geo_decoder(level, offset, buf, obj):
    obj.set(buf)
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


g.mid_table[41] = (gps_geo_decoder, gps_geo_obj, "GEO_DATA")


def gps_name_only(level, offset, buf, obj):
    pass


#
# other MIDs, just define their names.  no decoders
#
g.mid_table[7]   = (gps_name_only, None, "CLK_STAT")
g.mid_table[9]   = (gps_name_only, None, "cpu thruput")
g.mid_table[11]  = (gps_name_only, None, "ACK")
g.mid_table[28]  = (gps_name_only, None, "NAV_LIB")
g.mid_table[51]  = (gps_name_only, None, "unk_51")
g.mid_table[56]  = (gps_name_only, None, "ext_ephemeris")
g.mid_table[65]  = (gps_name_only, None, "gpio")
g.mid_table[71]  = (gps_name_only, None, "hw_config_req")
g.mid_table[88]  = (gps_name_only, None, "unk_88")
g.mid_table[92]  = (gps_name_only, None, "cw_data")
g.mid_table[93]  = (gps_name_only, None, "TCXO learning")
g.mid_table[129] = (gps_name_only, None, "set_nmea")
g.mid_table[132] = (gps_name_only, None, "send_sw_ver")
g.mid_table[134] = (gps_name_only, None, "set_baud_rate")
g.mid_table[144] = (gps_name_only, None, "poll_clk_status")
g.mid_table[166] = (gps_name_only, None, "set_msg_rate")
g.mid_table[178] = (gps_name_only, None, "peek/poke")


########################################################################
#
# main gps raw decoder, decodes DT_GPS_RAW_SIRFBIN
#

def decode_gps_raw(level, offset, buf, obj):
    consumed = obj.set(buf)
    len      = obj['hdr']['len'].val
    type     = obj['hdr']['type'].val
    recnum   = obj['hdr']['recnum'].val
    st       = obj['hdr']['st'].val

    mid = obj['gps_hdr']['mid'].val
    try:
        g.mid_count[mid] += 1
    except KeyError:
        g.mid_count[mid] = 1

    v = g.mid_table.get(mid, (None, None, ''))
    decoder     = v[MID_DECODER]            # dt function
    decoder_obj = v[MID_OBJECT]             # dt object

    print(rec0.format(offset, recnum, st, len, type, dt_name(type))),
    dir = obj['dir'].val
    dir_str = 'rx' if dir == 0 \
         else 'tx'
    v = g.mid_table.get(mid, (None, None, 'unk'))
    mid_name = v[MID_NAME]

    if (obj['gps_hdr']['start'].val != 0xa0a2):
        index = obj.__len__() - gps_hdr_obj.__len__()
        print('-- non-binary <{:2}>'.format(dir_str))
        if (level >= 1):
            print('    {:s}'.format(buf[index:])),
        if (level >= 2):
            dump_buf(buf, '    ')
        return

    print('-- MID: {:2} ({:02x}) <{:2}> {:10} '.format(mid, mid, dir_str, mid_name))

    # gps raw packet contents are displayed if level is 1 or higher
    if (level >= 1):
        if not decoder:
            if (level >= 5):
                print
                print('*** no decoder/obj defined for mid {}'.format(mid))
            return
        decoder(level, offset, buf[consumed:], decoder_obj)

g.dt_records[DT_GPS_RAW_SIRFBIN] = \
        (0, decode_gps_raw, dt_gps_raw_obj, "GPS_RAW")
