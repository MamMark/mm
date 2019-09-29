'''assign decoders and emitters for sirfbin mids'''

import sirf_defs     as     sirf
from   sirf_headers  import *
from   sirf_emitters import *

def decode_default(level, offset, buf, obj):
    return obj.set(buf)

def decode_null(level, offset, buf, obj):
    return 0


#                      EE_DECODER            EE_EMITTERS               EE_OBJECT                  EE_NAME         EE_OBJ_NAME
sirf.ee56_table[5]  = (decode_default,     [ emit_ee56_bcastEph ],     obj_sirf_ee56_bcastEph(),  'eeBcastEph',   'obj_sirf_ee_sifStat')
sirf.ee56_table[42] = (decode_default,     [ emit_ee56_sifStat ],      obj_sirf_ee56_sifStat(),   'eeSifStat',    'obj_sirf_ee_sifStat')

sirf.ee56_table[1]    = (decode_null, None, None, 'eeGPSDataEphemMask', 'none')
sirf.ee56_table[2]    = (decode_null, None, None, 'eeIntegrity',        'none')
sirf.ee56_table[3]    = (decode_null, None, None, 'eeStatus',           'none')
sirf.ee56_table[4]    = (decode_null, None, None, 'eeClkBiasAdj',       'none')
sirf.ee56_table[32]   = (decode_null, None, None, 'eeAckNack',          'none')
sirf.ee56_table[33]   = (decode_null, None, None, 'eeAge',              'none')
sirf.ee56_table[34]   = (decode_null, None, None, 'eeSGEEAge',          'none')
sirf.ee56_table[41]   = (decode_null, None, None, 'eeSifAidingStatus',  'none')
sirf.ee56_table[255]  = (decode_null, None, None, 'eeAck',              'none')

sirf.stat70_table[1]  = (decode_null, None, None, 'statAlmanacRsp',     'none')
sirf.stat70_table[2]  = (decode_null, None, None, 'statEphemerisRsp',   'none')

sirf.stat212_table[1] = (decode_null, None, None, 'statAlmanacReq',     'none')
sirf.stat212_table[2] = (decode_null, None, None, 'statEphemerisReq',   'none')

sirf.ee232_table[2]   = (decode_null, None, None, 'eePollEEstatus',     'none')
sirf.ee232_table[25]  = (decode_null, None, None, 'eeGetEEage',         'none')
sirf.ee232_table[32]  = (decode_null, None, None, 'eeSifAidControl',    'none')
sirf.ee232_table[33]  = (decode_null, None, None, 'eeGetSIFaiding',     'none')
sirf.ee232_table[253] = (decode_null, None, None, 'eeStorageControl',   'none')
sirf.ee232_table[254] = (decode_null, None, None, 'eeCGEEpredControl',  'none')
sirf.ee232_table[255] = (decode_null, None, None, 'eeDebug',            'none')

sirf.nl64_table[1]    = (decode_null, None, None, 'auxInit',            'none')
sirf.nl64_table[2]    = (decode_null, None, None, 'auxMeas',            'none')
sirf.nl64_table[3]    = (decode_null, None, None, 'aidingInit',         'none')


#                      MID_DECODER           MID_EMITTERS              MID_OBJECT                  MID_NAME        MID_OBJ_NAME
sirf.mid_table[2]   = (decode_default,     [ emit_sirf_nav_data ],     obj_sirf_nav(),            'navData',      'obj_sirf_nav')
sirf.mid_table[4]   = (decode_sirf_navtrk, [ emit_sirf_navtrk ],       obj_sirf_navtrk(),         'navTrack',     'obj_sirf_navtrk')
sirf.mid_table[6]   = (decode_default,     [ emit_sirf_swver ],        obj_sirf_swver(),          'swVer',        'obj_sirf_swver')
sirf.mid_table[7]   = (decode_default,     [ emit_default ],           obj_sirf_clock_status(),   'clockStatus',  'obj_sirf_clock_status')
sirf.mid_table[11]  = (decode_null,        [ emit_sirf_ack_nack ],     None,                      'ack',          'none')
sirf.mid_table[12]  = (decode_null,        [ emit_sirf_ack_nack ],     None,                      'nack',         'none')
sirf.mid_table[13]  = (decode_sirf_vis,    [ emit_sirf_vis ],          obj_sirf_vis(),            'visList',      'obj_sirf_vis')
sirf.mid_table[14]  = (decode_default,     [ emit_sirf_alm_data ],     obj_sirf_alm_data(),       'almData',      'obj_sirf_alm_data')
sirf.mid_table[15]  = (decode_default,     [ emit_sirf_ephem_data ],   obj_sirf_ephem_data(),     'ephemData',    'obj_sirf_ephem_data')
sirf.mid_table[18]  = (decode_default,     [ emit_sirf_ots ],          obj_sirf_ots(),            'okToSend',     'obj_sirf_ots')
sirf.mid_table[19]  = (decode_default,     [ emit_default  ],          obj_sirf_nav_params(),     'navParamsRsp', 'obj_sirf_nav_params')

sirf.mid_table[28]  = (decode_default,     [ emit_default ],           obj_sirf_nl_measData(),    'nl_measData',  'obj_sirf_navlib_measData')
sirf.mid_table[29]  = (decode_default,     [ emit_default ],           obj_sirf_nl_dgpsData(),    'nl_dgpsData',  'obj_sirf_navlib_dgpsData')
sirf.mid_table[30]  = (decode_default,     [ emit_default ],           obj_sirf_nl_svState(),     'nl_svState',   'obj_sirf_navlib_svState')
sirf.mid_table[31]  = (decode_default,     [ emit_default ],           obj_sirf_nl_initData(),    'nl_initData',  'obj_sirf_navlib_initData')

sirf.mid_table[41]  = (decode_default,     [ emit_sirf_geo ],          obj_sirf_geo(),            'geoData',      'obj_sirf_geo')
sirf.mid_table[56]  = (decode_sirf_ee56,   [ emit_sirf_ee56 ],         None,                      'extEphem',     'none, sub-objects')
sirf.mid_table[64]  = (decode_sirf_nl64,   [ emit_sirf_nl64 ],         None,                      'navlib msgs',  'none, sub-objects')
sirf.mid_table[70]  = (decode_sirf_stat70, [ emit_sirf_stat70 ],       None,                      'status msgs',  'none, sub-objects')

sirf.mid_table[90]  = (decode_default,     [ emit_sirf_pwr_mode_rsp ], obj_sirf_pwr_mode_rsp(),   'pwrRsp',       'obj_sirf_pwr_mode_rsp')
sirf.mid_table[128] = (decode_default,     [ emit_default  ],          obj_sirf_init_data_src(),  'initDataSrc',  'obj_sirf_init_data_src')
sirf.mid_table[130] = (decode_default,     [ emit_sirf_alm_set ],      obj_sirf_alm_set(),        'setAlmanac',   'obj_sirf_alm_set')
sirf.mid_table[149] = (decode_default,     [ emit_sirf_ephem_set ],    obj_sirf_ephem_set(),      'setEphemeris', 'obj_sirf_ephem_set')
sirf.mid_table[166] = (decode_default,     [ emit_sirf_set_msg_rate ], obj_sirf_set_msg_rate(),   'setMsgRate',   'obj_sirf_set_msg_rate')
sirf.mid_table[212] = (decode_sirf_stat212,[ emit_sirf_stat212 ],      None,                      'status requests', 'none, sub-objects')
sirf.mid_table[214] = (decode_default,     [ emit_default  ],          obj_sirf_hw_conf_rsp(),    'hwConfigRsp',  'obj_sirf_hw_conf_rsp')
sirf.mid_table[218] = (decode_default,     [ emit_sirf_pwr_mode_req ], obj_sirf_pwr_mode_req(),   'pwrReq',       'obj_sirf_pwr_mode_req')
sirf.mid_table[225] = (decode_default,     [ emit_sirf_statistics ],   obj_sirf_statistics(),     'stats',        'obj_sirf_statistics')
sirf.mid_table[232] = (decode_sirf_ee232,  [ emit_sirf_ee232 ],        None,                      'extEphem',     'none, sub-objects')
sirf.mid_table[255] = (decode_default,     [ emit_sirf_dev_data ],     obj_sirf_dev_data(),       'devData',      'obj_sirf_dev_data')


#
# other MIDs, just define their names.  no decoders
# default emitter is print in emit_gps_raw
#
sirf.mid_table[1]   = (decode_null, None, None, 'ref navData',              'none')
sirf.mid_table[3]   = (decode_null, None, None, 'true tracker',             'none')
sirf.mid_table[5]   = (decode_null, None, None, 'rawTracker',               'none')
sirf.mid_table[7]   = (decode_null, None, None, 'clkStat',                  'none')
sirf.mid_table[8]   = (decode_null, None, None, '50bps data',               'none')
sirf.mid_table[9]   = (decode_null, None, None, 'cpu thruput',              'none')
sirf.mid_table[10]  = (decode_null, None, None, 'error id',                 'none')
sirf.mid_table[17]  = (decode_null, None, None, 'diff corrections',         'none')
sirf.mid_table[27]  = (decode_null, None, None, 'dgps status format',       'none')
sirf.mid_table[43]  = (decode_null, None, None, 'queue cmdParams',          'none')
sirf.mid_table[45]  = (decode_null, None, None, 'dr rawData',               'none')
sirf.mid_table[48]  = (decode_null, None, None, 'dr nav',                   'none')
sirf.mid_table[50]  = (decode_null, None, None, 'sbas params',              'none')
sirf.mid_table[51]  = (decode_null, None, None, 'unk_51',                   'none')
sirf.mid_table[52]  = (decode_null, None, None, '1pps time',                'none')
sirf.mid_table[65]  = (decode_null, None, None, 'gpio',                     'none')
sirf.mid_table[66]  = (decode_null, None, None, 'dop values',               'none')
sirf.mid_table[68]  = (decode_null, None, None, 'meas eng',                 'none')
sirf.mid_table[69]  = (decode_null, None, None, 'pos rsp',                  'none')
sirf.mid_table[70]  = (decode_null, None, None, 'alm/ephem statusRsp',      'none')
sirf.mid_table[71]  = (decode_null, None, None, 'hwConfig req',             'none')
sirf.mid_table[72]  = (decode_null, None, None, 'sensor data',              'none')
sirf.mid_table[73]  = (decode_null, None, None, 'aiding req',               'none')
sirf.mid_table[74]  = (decode_null, None, None, 'session rsp',              'none')
sirf.mid_table[75]  = (decode_null, None, None, 'ack nack error',           'none')
sirf.mid_table[77]  = (decode_null, None, None, 'low pwr mode',             'none')
sirf.mid_table[88]  = (decode_null, None, None, 'unk_88',                   'none')
sirf.mid_table[91]  = (decode_null, None, None, 'hw control out',           'none')
sirf.mid_table[92]  = (decode_null, None, None, 'cw data',                  'none')
sirf.mid_table[93]  = (decode_null, None, None, 'TCXO learning',            'none')
sirf.mid_table[129] = (decode_null, None, None, 'set_nmea',                 'none')
sirf.mid_table[131] = (decode_null, None, None, 'formated dump',            'none')
sirf.mid_table[132] = (decode_null, None, None, 'send swver',               'none')
sirf.mid_table[133] = (decode_null, None, None, 'dgps source',              'none')
sirf.mid_table[134] = (decode_null, None, None, 'set binary port',          'none')
sirf.mid_table[135] = (decode_null, None, None, 'set protocol',             'none')
sirf.mid_table[136] = (decode_null, None, None, 'mode control',             'none')
sirf.mid_table[137] = (decode_null, None, None, 'dop mask control',         'none')
sirf.mid_table[138] = (decode_null, None, None, 'dgps control',             'none')
sirf.mid_table[139] = (decode_null, None, None, 'elevation mask',           'none')
sirf.mid_table[140] = (decode_null, None, None, 'power mask',               'none')
sirf.mid_table[143] = (decode_null, None, None, 'static navigation',        'none')
sirf.mid_table[144] = (decode_null, None, None, 'poll_clk_status',          'none')
sirf.mid_table[145] = (decode_null, None, None, 'dgps serial port',         'none')
sirf.mid_table[146] = (decode_null, None, None, 'poll almanac',             'none')
sirf.mid_table[147] = (decode_null, None, None, 'poll ephemeris',           'none')
sirf.mid_table[148] = (decode_null, None, None, 'flash update',             'none')
sirf.mid_table[150] = (decode_null, None, None, 'switch op mode',           'none')
sirf.mid_table[151] = (decode_null, None, None, 'set trickle power',        'none')
sirf.mid_table[152] = (decode_null, None, None, 'poll nav params',          'none')
sirf.mid_table[161] = (decode_null, None, None, 'store gps snapshot',       'none')
sirf.mid_table[165] = (decode_null, None, None, 'set uart config',          'none')
sirf.mid_table[167] = (decode_null, None, None, 'set low power acq',        'none')
sirf.mid_table[168] = (decode_null, None, None, 'poll command params',      'none')
sirf.mid_table[170] = (decode_null, None, None, 'set sbas params',          'none')
sirf.mid_table[172] = (decode_null, None, None, 'sirfdrive/nav',            'none')
sirf.mid_table[175] = (decode_null, None, None, 'user set command',         'none')
sirf.mid_table[177] = (decode_null, None, None, 'data logger',              'none')
sirf.mid_table[178] = (decode_null, None, None, 'sw/tb peek/poke(3)',       'none')
sirf.mid_table[180] = (decode_null, None, None, 'gsc2xr preset op config',  'none')
sirf.mid_table[205] = (decode_null, None, None, 'sw/ctl off(16)',           'none')
sirf.mid_table[210] = (decode_null, None, None, 'position request',         'none')
sirf.mid_table[211] = (decode_null, None, None, 'set corrections',          'none')
sirf.mid_table[212] = (decode_null, None, None, 'status requests',          'none')
sirf.mid_table[213] = (decode_null, None, None, 'session_req',              'none')
sirf.mid_table[215] = (decode_null, None, None, 'aiding',                   'none')
sirf.mid_table[216] = (decode_null, None, None, 'osp ack/nack/error/reject','none')
sirf.mid_table[219] = (decode_null, None, None, 'hw control input',         'none')
sirf.mid_table[220] = (decode_null, None, None, 'cw configuration',         'none')
sirf.mid_table[221] = (decode_null, None, None, 'tcxo learning ctrl out',   'none')
sirf.mid_table[233] = (decode_null, None, None, 'grf3i status',             'none')
sirf.mid_table[234] = (decode_null, None, None, 'sensor control input',     'none')
