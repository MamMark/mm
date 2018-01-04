#
# Copyright (c) 2017-2018 Eric B. Decker, Daniel J. Maltbie
# All rights reserved.
#
# Decoders for gps data types

import globals      as     g
from   core_records import *
from   gps_headers  import *

def decode_gps_version(level, buf, obj):
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_GPS_VERSION] = \
        (0, decode_gps_version, dt_gps_ver_obj, "GPS_VERSION")


def decode_gps_time(level, buf, obj):
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_GPS_TIME] = (0, decode_gps_time, dt_gps_time_obj, "GPS_TIME")


def decode_gps_geo(level, buf, obj):
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_GPS_GEO] = (0, decode_gps_geo, dt_gps_geo_obj, "GPS_GEO")


def decode_gps_xyz(level, buf, obj):
    if (level >= 1):
        obj.set(buf)
        print(obj)
        print_hdr(obj)
        print

g.dt_records[DT_GPS_XYZ] = (0, decode_gps_xyz, dt_gps_xyz_obj, "GPS_XYZ")


def gps_nav_decoder(level, buf, obj):
    if (level >= 1):
        obj.set(buf)
        print(obj)

g.mid_table[2] = (gps_nav_decoder, gps_nav_obj, "NAV_DATA")


def gps_navtrk_decoder(level, buf,obj):
    if (level >= 1):
        consumed = obj.set(buf)
        print(obj)
        chans = obj['chans'].val
        for n in range(chans):
            consumed += gps_navtrk_chan.set(buf[consumed:])
            print(gps_navtrk_chan)

g.mid_table[4] = (gps_navtrk_decoder, gps_navtrk_obj, "NAV_TRACK")


def gps_swver_decoder(level, buf, obj):
    if (level >= 1):
        consumed = obj.set(buf)
        len0 = obj['str0_len'].val
        len1 = obj['str1_len'].val
        str0 = buf[consumed:consumed+len0-1]
        str1 = buf[consumed+len0:consumed+len0+len1-1]
        print('\n  --<{}>--  --<{}>--'.format(str0, str1)),

g.mid_table[6] = (gps_swver_decoder, gps_swver_obj, "SW_VER")


def gps_vis_decoder(level, buf, obj):
    if (level >= 1):
        consumed = obj.set(buf)
        print(obj)
        num_sats = obj['vis_sats'].val
        for n in range(num_sats):
            consumed += gps_vis_azel.set(buf[consumed:])
            print(gps_vis_azel)

g.mid_table[13] = (gps_vis_decoder, gps_vis_obj, "VIS_LIST")


def gps_ots_decoder(level, buf, obj):
    if (level >= 1):
        obj.set(buf)
        ans = 'no'
        if obj.val: ans = 'yes'
        ans = '  ' + ans
        print(ans),

g.mid_table[18] = (gps_ots_decoder, gps_ots_obj, "OkToSend")


def gps_geo_decoder(level, buf, obj):
    if (level >= 1):
        obj.set(buf)
        print(obj)

g.mid_table[41] = (gps_geo_decoder, gps_geo_obj, "GEO_DATA")


def gps_name_only(level, buf, obj):
    if (level >= 1):
        print


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

def print_gps_hdr(obj, mid):
    dir = obj['dir'].val
    dir_str = 'rx' if dir == 0 \
         else 'tx'
    v = g.mid_table.get(mid, (None, None, 'unk'))
    mid_name = v[MID_NAME]
    print('MID: {:2} ({:02x}) <{:2}> {:10} '.format(mid, mid, dir_str, mid_name)),


def decode_gps_raw(level, buf, obj):
    consumed = obj.set(buf)
    mid = obj['gps_hdr']['mid'].val
    try:
        g.mid_count[mid] += 1
    except KeyError:
        g.mid_count[mid] = 1

    v = g.mid_table.get(mid, (None, None, ''))
    decoder     = v[MID_DECODER]            # dt function
    decoder_obj = v[MID_OBJECT]             # dt object

    # gps raw packet contents are displayed if level is 1 or higher
    # no summary.
    if (level >= 1):
        print(obj)
        print_hdr(obj)
        print_gps_hdr(obj, mid)
        if not decoder:
            if (level >= 5):
                print
                print('*** no decoder/obj defined for mid {}'.format(mid))
            return
        decoder(level, buf[consumed:], decoder_obj)

g.dt_records[DT_GPS_RAW_SIRFBIN] = \
        (0, decode_gps_raw, dt_gps_raw_obj, "GPS_RAW")
