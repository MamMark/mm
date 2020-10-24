'''assign decoders and emitters for ubxbin class/ids'''

import ubx_defs     as     ubx
from   ubx_headers  import *
from   ubx_emitters import *

def decode_default(level, offset, buf, obj):
    return obj.set(buf)

def decode_null(level, offset, buf, obj):
    return 0


#                          CID_DECODER           CID_EMITTERS              CID_OBJECT                  CID_NAME        CID_OBJ_NAME
ubx.cid_table[0x0101]   = (decode_default,     [ emit_ubx_nav_posecef ],   obj_ubx_nav_posecef(),     'nav/posecef',  'obj_ubx_nav_posecef')
ubx.cid_table[0x0102]   = (decode_default,     [ emit_default ],           obj_ubx_nav_posllh(),      'nav/posllh',   'obj_ubx_nav_posllh')
ubx.cid_table[0x0103]   = (decode_default,     [ emit_ubx_nav_status ],    obj_ubx_nav_status(),      'nav/status',   'obj_ubx_nav_status')
ubx.cid_table[0x0104]   = (decode_default,     [ emit_ubx_nav_dop ],       obj_ubx_nav_dop(),         'nav/dop',      'obj_ubx_nav_dop')
ubx.cid_table[0x0107]   = (decode_default,     [ emit_ubx_nav_pvt ],       obj_ubx_nav_pvt(),         'nav/pvt',      'obj_ubx_nav_pvt')

ubx.cid_table[0x0120]   = (decode_default,     [ emit_ubx_nav_timegps ],   obj_ubx_nav_timegps(),     'nav/timegps',  'obj_ubx_nav_timegps')
ubx.cid_table[0x0121]   = (decode_default,     [ emit_ubx_nav_timeutc ],   obj_ubx_nav_timeutc(),     'nav/timeutc',  'obj_ubx_nav_timeutc')
ubx.cid_table[0x0122]   = (decode_default,     [ emit_ubx_nav_clock ],     obj_ubx_nav_clock(),       'nav/clock',    'obj_ubx_nav_clock')
ubx.cid_table[0x0126]   = (decode_default,     [ emit_ubx_nav_timels ],    obj_ubx_nav_timels(),      'nav/timels',   'obj_ubx_nav_timels')

#ubx.cid_table[0x0134]   = (decode_ubx_nav_orb, [ emit_default ],           obj_ubx_nav_orb(),         'nav/orb',      'obj_ubx_nav_orb')
#ubx.cid_table[0x0135]   = (decode_ubx_nav_sat, [ emit_default ],           obj_ubx_nav_sat(),         'nav/sat',      'obj_ubx_nav_sat')
ubx.cid_table[0x0134]   = (decode_null,        None,                       None,                      'nav/orb',       'none')
ubx.cid_table[0x0135]   = (decode_null,        None,                       None,                      'nav/sat',       'none')

ubx.cid_table[0x0160]   = (decode_default,     [ emit_ubx_nav_aopstatus ], obj_ubx_nav_aopstatus(),   'nav/aopstat',  'obj_ubx_nav_aopstatus')
ubx.cid_table[0x0161]   = (decode_default,     [ emit_default ],           obj_ubx_nav_eoe(),         'nav/eoe',      'obj_ubx_nav_eoe')

ubx.cid_table[0x0400]   = (decode_default,     [ emit_ubx_inf ],           obj_ubx_hdr(),             'inf/error',    'obj_ubx_inf_error')
ubx.cid_table[0x0401]   = (decode_default,     [ emit_ubx_inf ],           obj_ubx_hdr(),             'inf/warning',  'obj_ubx_inf_warning')
ubx.cid_table[0x0402]   = (decode_default,     [ emit_ubx_inf ],           obj_ubx_hdr(),             'inf/notice',   'obj_ubx_inf_notice')
ubx.cid_table[0x0403]   = (decode_default,     [ emit_ubx_inf ],           obj_ubx_hdr(),             'inf/test',     'obj_ubx_inf_test')
ubx.cid_table[0x0404]   = (decode_default,     [ emit_ubx_inf ],           obj_ubx_hdr(),             'inf/debug',    'obj_ubx_inf_debug')

ubx.cid_table[0x0500]   = (decode_default,     [ emit_ubx_ack ],           obj_ubx_ack(),             'ack/nack',     'obj_ubx_ack')
ubx.cid_table[0x0501]   = (decode_default,     [ emit_ubx_ack ],           obj_ubx_ack(),             'ack/ack',      'obj_ubx_ack')

ubx.cid_table[0x0600]   = (decode_ubx_cfg_prt, [ emit_ubx_cfg_prt ],       obj_ubx_cfg_prt(),         'cfg/prt',      'obj_ubx_cfg_prt')
ubx.cid_table[0x0601]   = (decode_ubx_cfg_msg, [ emit_ubx_cfg_msg ],       obj_ubx_cfg_msg(),         'cfg/msg',      'obj_ubx_cfg_msg')
ubx.cid_table[0x0604]   = (decode_default,     [ emit_ubx_cfg_rst ],       obj_ubx_cfg_rst(),         'cfg/rst',      'obj_ubx_cfg_rst')
ubx.cid_table[0x0609]   = (decode_ubx_cfg_cfg, [ emit_ubx_cfg_cfg ],       obj_ubx_cfg_cfg(),         'cfg/cfg',      'obj_ubx_cfg_cfg')
ubx.cid_table[0x0623]   = (decode_ubx_cfg_navx5,[ emit_ubx_cfg_nav5 ],     obj_ubx_cfg_nav5(),        'cfg/navx5',    'obj_ubx_cfg_navx5')
ubx.cid_table[0x0624]   = (decode_ubx_cfg_nav5, [ emit_ubx_cfg_nav5 ],     obj_ubx_cfg_nav5(),        'cfg/nav5',     'obj_ubx_cfg_nav5')

ubx.cid_table[0x0a04]   = (decode_null,        None,                       None,                      'mon/ver',      'none')
ubx.cid_table[0x0a09]   = (decode_null,        None,                       None,                      'mon/hw',       'none')

ubx.cid_table[0x0d01]   = (decode_default,     [ emit_ubx_tim_tp ],        obj_ubx_tim_tp(),          'tim/tp',       'obj_ubx_tim_tp')

#
# other CIDs, just define their names.  no decoders
# default emitter is print in emit_gps_raw
#
ubx.cid_table[0x0105]   = (decode_null, None, None, 'nav/att',          'none')
ubx.cid_table[0x0106]   = (decode_null, None, None, 'nav/sol',          'none')
ubx.cid_table[0x0109]   = (decode_null, None, None, 'nav/odo',          'none')
ubx.cid_table[0x0110]   = (decode_null, None, None, 'nav/resetodo',     'none')
ubx.cid_table[0x0111]   = (decode_null, None, None, 'nav/velecef',      'none')
ubx.cid_table[0x0112]   = (decode_null, None, None, 'nav/velned',       'none')
ubx.cid_table[0x0113]   = (decode_null, None, None, 'nav/hpposecef',    'none')
ubx.cid_table[0x0114]   = (decode_null, None, None, 'nav/hpposllh',     'none')
ubx.cid_table[0x0123]   = (decode_null, None, None, 'nav/timeglo',      'none')
ubx.cid_table[0x0124]   = (decode_null, None, None, 'nav/timebds',      'none')
ubx.cid_table[0x0125]   = (decode_null, None, None, 'nav/timegal',      'none')
ubx.cid_table[0x0128]   = (decode_null, None, None, 'nav/nmi',          'none')
ubx.cid_table[0x0130]   = (decode_null, None, None, 'nav/svinfo',       'none')
ubx.cid_table[0x0131]   = (decode_null, None, None, 'nav/dpgs',         'none')
ubx.cid_table[0x0132]   = (decode_null, None, None, 'nav/sbas',         'none')
ubx.cid_table[0x0139]   = (decode_null, None, None, 'nav/geofence',     'none')
ubx.cid_table[0x013B]   = (decode_null, None, None, 'nav/svin',         'none')
ubx.cid_table[0x013C]   = (decode_null, None, None, 'nav/relposned',    'none')
ubx.cid_table[0x0142]   = (decode_null, None, None, 'nav/slas',         'none')
ubx.cid_table[0x0143]   = (decode_null, None, None, 'nav/sig',          'none')

ubx.cid_table[0x0213]   = (decode_null, None, None, 'rxm/sfrbx',        'none')
ubx.cid_table[0x0214]   = (decode_null, None, None, 'rxm/measx',        'none')
ubx.cid_table[0x0215]   = (decode_null, None, None, 'rxm/rawx',         'none')
ubx.cid_table[0x0220]   = (decode_null, None, None, 'rxm/svsi',         'none')
ubx.cid_table[0x0232]   = (decode_null, None, None, 'rxm/rtcm',         'none')
ubx.cid_table[0x0241]   = (decode_null, None, None, 'rxm/pmreq',        'none')
ubx.cid_table[0x0259]   = (decode_null, None, None, 'rxm/rlm',          'none')
ubx.cid_table[0x0261]   = (decode_null, None, None, 'rxm/imes',         'none')

ubx.cid_table[0x0602]   = (decode_null, None, None, 'cfg/inf',          'none')
ubx.cid_table[0x0606]   = (decode_null, None, None, 'cfg/dat',          'none')
ubx.cid_table[0x0608]   = (decode_null, None, None, 'cfg/rate',         'none')
ubx.cid_table[0x0611]   = (decode_null, None, None, 'cfg/rxm',          'none')
ubx.cid_table[0x0613]   = (decode_null, None, None, 'cfg/ant',          'none')
ubx.cid_table[0x0616]   = (decode_null, None, None, 'cfg/sbas',         'none')
ubx.cid_table[0x0617]   = (decode_null, None, None, 'cfg/nmea',         'none')
ubx.cid_table[0x061B]   = (decode_null, None, None, 'cfg/usb',          'none')
ubx.cid_table[0x061E]   = (decode_null, None, None, 'cfg/odo',          'none')
ubx.cid_table[0x0631]   = (decode_null, None, None, 'cfg/tp5',          'none')
ubx.cid_table[0x0634]   = (decode_null, None, None, 'cfg/rinv',         'none')
ubx.cid_table[0x0639]   = (decode_null, None, None, 'cfg/itfm',         'none')
ubx.cid_table[0x063B]   = (decode_null, None, None, 'cfg/pm2',          'none')
ubx.cid_table[0x063D]   = (decode_null, None, None, 'cfg/tmode2',       'none')
ubx.cid_table[0x063E]   = (decode_null, None, None, 'cfg/gnss',         'none')
ubx.cid_table[0x0647]   = (decode_null, None, None, 'cfg/logfilter',    'none')
ubx.cid_table[0x0653]   = (decode_null, None, None, 'cfg/txslot',       'none')
ubx.cid_table[0x0657]   = (decode_null, None, None, 'cfg/pwr',          'none')
ubx.cid_table[0x065c]   = (decode_null, None, None, 'cfg/hnr',          'none')
ubx.cid_table[0x0660]   = (decode_null, None, None, 'cfg/esrc',         'none')
ubx.cid_table[0x0661]   = (decode_null, None, None, 'cfg/dosc',         'none')
ubx.cid_table[0x0662]   = (decode_null, None, None, 'cfg/smgr',         'none')
ubx.cid_table[0x0669]   = (decode_null, None, None, 'cfg/geofence',     'none')
ubx.cid_table[0x0670]   = (decode_null, None, None, 'cfg/dgnss',        'none')
ubx.cid_table[0x0671]   = (decode_null, None, None, 'cfg/tmode3',       'none')
ubx.cid_table[0x0686]   = (decode_null, None, None, 'cfg/pms',          'none')
ubx.cid_table[0x068C]   = (decode_null, None, None, 'cfg/valdel',       'none')
ubx.cid_table[0x068A]   = (decode_null, None, None, 'cfg/valset',       'none')
ubx.cid_table[0x068B]   = (decode_null, None, None, 'cfg/valget',       'none')
ubx.cid_table[0x068D]   = (decode_null, None, None, 'cfg/slas',         'none')
ubx.cid_table[0x0693]   = (decode_null, None, None, 'cfg/batch',        'none')

ubx.cid_table[0x0914]   = (decode_null, None, None, 'upd/sos',          'none')

ubx.cid_table[0x0a02]   = (decode_null, None, None, 'mon/io',           'none')
ubx.cid_table[0x0a06]   = (decode_null, None, None, 'mon/msgpp',        'none')
ubx.cid_table[0x0a07]   = (decode_null, None, None, 'mon/rxbuf',        'none')
ubx.cid_table[0x0a08]   = (decode_null, None, None, 'mon/txbuf',        'none')
ubx.cid_table[0x0a0B]   = (decode_null, None, None, 'mon/hw2',          'none')
ubx.cid_table[0x0a21]   = (decode_null, None, None, 'mon/rxr',          'none')
ubx.cid_table[0x0a27]   = (decode_null, None, None, 'mon/patch',        'none')
ubx.cid_table[0x0a28]   = (decode_null, None, None, 'mon/gnss',         'none')
ubx.cid_table[0x0a2e]   = (decode_null, None, None, 'mon/smgr',         'none')
ubx.cid_table[0x0a32]   = (decode_null, None, None, 'mon/batch',        'none')
ubx.cid_table[0x0a36]   = (decode_null, None, None, 'mon/comms',        'none')
ubx.cid_table[0x0a37]   = (decode_null, None, None, 'mon/hw3',          'none')
ubx.cid_table[0x0a38]   = (decode_null, None, None, 'mon/rf',           'none')

ubx.cid_table[0x0d03]   = (decode_null, None, None, 'tim/tm2',          'none')
ubx.cid_table[0x0d04]   = (decode_null, None, None, 'tim/svin',         'none')
ubx.cid_table[0x0d06]   = (decode_null, None, None, 'tim/vrfy',         'none')
ubx.cid_table[0x0d11]   = (decode_null, None, None, 'tim/dosc',         'none')
ubx.cid_table[0x0d12]   = (decode_null, None, None, 'tim/tos',          'none')
ubx.cid_table[0x0d13]   = (decode_null, None, None, 'tim/smeas',        'none')
ubx.cid_table[0x0d15]   = (decode_null, None, None, 'tim/vcocal',       'none')
ubx.cid_table[0x0d16]   = (decode_null, None, None, 'tim/fchg',         'none')
ubx.cid_table[0x0d17]   = (decode_null, None, None, 'tim/hoc',          'none')

ubx.cid_table[0x2103]   = (decode_null, None, None, 'log/erase',        'none')
ubx.cid_table[0x2104]   = (decode_null, None, None, 'log/string',       'none')
ubx.cid_table[0x2107]   = (decode_null, None, None, 'log/create',       'none')
ubx.cid_table[0x2108]   = (decode_null, None, None, 'log/info',         'none')
ubx.cid_table[0x2109]   = (decode_null, None, None, 'log/retrieve',     'none')
ubx.cid_table[0x210B]   = (decode_null, None, None, 'log/rtrvpos',      'none')
ubx.cid_table[0x210D]   = (decode_null, None, None, 'log/rtrvstr',      'none')
ubx.cid_table[0x210E]   = (decode_null, None, None, 'log/findtime',     'none')
ubx.cid_table[0x210F]   = (decode_null, None, None, 'log/rtrvposxtra',  'none')
ubx.cid_table[0x2110]   = (decode_null, None, None, 'log/rtrvbatch',    'none')
ubx.cid_table[0x2111]   = (decode_null, None, None, 'log/batch',        'none')

ubx.cid_table[0x2703]   = (decode_null, None, None, 'sec/uniqid',       'none')
