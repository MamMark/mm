'''assign decoders and emitters for sirfbin mids'''

import sirf_defs     as     sirf
from   sirf_decoders import *
from   sirf_emitters import *
from   sirf_headers  import *

def decode_default(level, offset, buf, obj):
    return obj.set(buf)

def decode_null(level, offset, buf, obj):
    return 0

def emit_print(level, offset, buf, obj):
    print

sirf.mid_table[2]   = (decode_default,      [ emit_sirf_nav_data ],     sirf_nav_obj,           'NavData',      'sirf_nav_obj')
sirf.mid_table[4]   = (decode_sirf_navtrk,  [ emit_sirf_navtrk ],       sirf_navtrk_obj,        'NavTrack',     'sirf_navtrk_obj')
sirf.mid_table[6]   = (decode_default,      [ emit_default ],           sirf_swver_obj,         'SwVer',        'sirf_swver_obj')
sirf.mid_table[13]  = (decode_sirf_vis,     [ emit_sirf_vis ],          sirf_vis_obj,           'VisList',      'sirf_vis_obj')
sirf.mid_table[18]  = (decode_default,      [ emit_sirf_ots ],          sirf_ots_obj,           'OkToSend',     'sirf_ots_obj')
sirf.mid_table[41]  = (decode_default,      [ emit_sirf_geo ],          sirf_geo_obj,           'GeoData',      'sirf_geo_obj')
sirf.mid_table[90]  = (decode_default,      [ emit_sirf_pwr_mode_rsp ], sirf_pwr_mode_rsp_obj,  'PwrRsp',       'sirf_pwr_mode_rsp_obj')
sirf.mid_table[218] = (decode_default,      [ emit_sirf_pwr_mode_req ], sirf_pwr_mode_req_obj,  'PwrReq',       'sirf_pwr_mode_req_obj')
sirf.mid_table[225] = (decode_default,      [ emit_sirf_statistics ],   sirf_statistics_obj,    'Stats',        'sirf_statistics_obj')


#
# other MIDs, just define their names.  no decoders
#
sirf.mid_table[7]   = (decode_null, [ emit_print ], None, "CLK_STAT")
sirf.mid_table[9]   = (decode_null, [ emit_print ], None, "cpu thruput")
sirf.mid_table[11]  = (decode_null, [ emit_print ], None, "ACK")
sirf.mid_table[28]  = (decode_null, [ emit_print ], None, "NAV_LIB")
sirf.mid_table[51]  = (decode_null, [ emit_print ], None, "unk_51")
sirf.mid_table[56]  = (decode_null, [ emit_print ], None, "ext_ephemeris")
sirf.mid_table[65]  = (decode_null, [ emit_print ], None, "gpio")
sirf.mid_table[71]  = (decode_null, [ emit_print ], None, "hw_config_req")
sirf.mid_table[73]  = (decode_null, [ emit_print ], None, "aiding_req")
sirf.mid_table[88]  = (decode_null, [ emit_print ], None, "unk_88")
sirf.mid_table[92]  = (decode_null, [ emit_print ], None, "cw_data")
sirf.mid_table[93]  = (decode_null, [ emit_print ], None, "TCXO learning")
sirf.mid_table[129] = (decode_null, [ emit_print ], None, "set_nmea")
sirf.mid_table[132] = (decode_null, [ emit_print ], None, "send_sw_ver")
sirf.mid_table[134] = (decode_null, [ emit_print ], None, "set_baud_rate")
sirf.mid_table[144] = (decode_null, [ emit_print ], None, "poll_clk_status")
sirf.mid_table[166] = (decode_null, [ emit_print ], None, "set_msg_rate")
sirf.mid_table[178] = (decode_null, [ emit_print ], None, "peek/poke")
sirf.mid_table[213] = (decode_null, [ emit_print ], None, "session_req")
sirf.mid_table[214] = (decode_null, [ emit_print ], None, "hw_config_rsp")
sirf.mid_table[215] = (decode_null, [ emit_print ], None, "aiding_rsp")
