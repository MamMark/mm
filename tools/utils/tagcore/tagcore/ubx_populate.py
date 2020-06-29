'''assign decoders and emitters for sirfbin mids'''

import ubx_defs     as     ubx
from   ubx_headers  import *
from   ubx_emitters import *

def decode_default(level, offset, buf, obj):
    return obj.set(buf)

def decode_null(level, offset, buf, obj):
    return 0


#                      CID_DECODER           CID_EMITTERS              CID_OBJECT                  CID_NAME        CID_OBJ_NAME
#ubx.cid_table[2]   = (decode_default,     [ emit_sirf_nav_data ],     obj_sirf_nav(),            'navData',      'obj_sirf_nav')


#
# other CIDs, just define their names.  no decoders
# default emitter is print in emit_gps_raw
#
ubx.cid_table[0x0101]   = (decode_null, None, None, 'nav/posecef',      'none')
ubx.cid_table[0x0102]   = (decode_null, None, None, 'nav/posllh',       'none')
ubx.cid_table[0x0103]   = (decode_null, None, None, 'nav/status',       'none')
ubx.cid_table[0x0104]   = (decode_null, None, None, 'nav/dop',          'none')
ubx.cid_table[0x0105]   = (decode_null, None, None, 'nav/att',          'none')
ubx.cid_table[0x0106]   = (decode_null, None, None, 'nav/sol',          'none')
ubx.cid_table[0x0107]   = (decode_null, None, None, 'nav/pvt',          'none')
ubx.cid_table[0x0109]   = (decode_null, None, None, 'nav/odo',          'none')
ubx.cid_table[0x0110]   = (decode_null, None, None, 'nav/resetodo',     'none')
ubx.cid_table[0x0111]   = (decode_null, None, None, 'nav/velecef',      'none')
ubx.cid_table[0x0112]   = (decode_null, None, None, 'nav/velned',       'none')
ubx.cid_table[0x0113]   = (decode_null, None, None, 'nav/hpposecef',    'none')
ubx.cid_table[0x0114]   = (decode_null, None, None, 'nav/hpposllh',     'none')
ubx.cid_table[0x0120]   = (decode_null, None, None, 'nav/timegps',      'none')
ubx.cid_table[0x0121]   = (decode_null, None, None, 'nav/timeutc',      'none')
ubx.cid_table[0x0122]   = (decode_null, None, None, 'nav/clock',        'none')
ubx.cid_table[0x0123]   = (decode_null, None, None, 'nav/timeglo',      'none')
ubx.cid_table[0x0124]   = (decode_null, None, None, 'nav/timebds',      'none')
ubx.cid_table[0x0125]   = (decode_null, None, None, 'nav/timegal',      'none')
ubx.cid_table[0x0126]   = (decode_null, None, None, 'nav/timels',       'none')
ubx.cid_table[0x0130]   = (decode_null, None, None, 'nav/svinfo',       'none')
ubx.cid_table[0x0131]   = (decode_null, None, None, 'nav/dpgs',         'none')
ubx.cid_table[0x0132]   = (decode_null, None, None, 'nav/sbas',         'none')
ubx.cid_table[0x0134]   = (decode_null, None, None, 'nav/orb',          'none')
ubx.cid_table[0x0135]   = (decode_null, None, None, 'nav/sat',          'none')
ubx.cid_table[0x0139]   = (decode_null, None, None, 'nav/geofence',     'none')
ubx.cid_table[0x013B]   = (decode_null, None, None, 'nav/svin',         'none')
ubx.cid_table[0x013C]   = (decode_null, None, None, 'nav/relposned',    'none')
ubx.cid_table[0x0143]   = (decode_null, None, None, 'nav/sig',          'none')
ubx.cid_table[0x0161]   = (decode_null, None, None, 'nav/eoe',          'none')

ubx.cid_table[0x0400]   = (decode_null, None, None, 'inf/error',        'none')
ubx.cid_table[0x0401]   = (decode_null, None, None, 'inf/warning',      'none')
ubx.cid_table[0x0402]   = (decode_null, None, None, 'inf/notice',       'none')
ubx.cid_table[0x0403]   = (decode_null, None, None, 'inf/test',         'none')
ubx.cid_table[0x0404]   = (decode_null, None, None, 'inf/debug',        'none')

ubx.cid_table[0x0500]   = (decode_null, None, None, 'ack/nack',         'none')
ubx.cid_table[0x0501]   = (decode_null, None, None, 'ack/ack',          'none')

ubx.cid_table[0x0600]   = (decode_null, None, None, 'cfg/prt',          'none')
ubx.cid_table[0x0601]   = (decode_null, None, None, 'cfg/msg',          'none')
ubx.cid_table[0x0602]   = (decode_null, None, None, 'cfg/inf',          'none')
ubx.cid_table[0x0604]   = (decode_null, None, None, 'cfg/rst',          'none')
ubx.cid_table[0x0606]   = (decode_null, None, None, 'cfg/dat',          'none')
ubx.cid_table[0x0608]   = (decode_null, None, None, 'cfg/rate',         'none')
ubx.cid_table[0x0609]   = (decode_null, None, None, 'cfg/cfg',          'none')
ubx.cid_table[0x0611]   = (decode_null, None, None, 'cfg/rxm',          'none')
ubx.cid_table[0x0613]   = (decode_null, None, None, 'cfg/ant',          'none')
ubx.cid_table[0x0616]   = (decode_null, None, None, 'cfg/sbas',         'none')
ubx.cid_table[0x0617]   = (decode_null, None, None, 'cfg/nmea',         'none')
ubx.cid_table[0x061B]   = (decode_null, None, None, 'cfg/usb',          'none')
ubx.cid_table[0x061E]   = (decode_null, None, None, 'cfg/odo',          'none')
ubx.cid_table[0x0623]   = (decode_null, None, None, 'cfg/navx5',        'none')
ubx.cid_table[0x0624]   = (decode_null, None, None, 'cfg/nav5',         'none')
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
ubx.cid_table[0x0a04]   = (decode_null, None, None, 'mon/ver',          'none')
ubx.cid_table[0x0a06]   = (decode_null, None, None, 'mon/msgpp',        'none')
ubx.cid_table[0x0a07]   = (decode_null, None, None, 'mon/rxbuf',        'none')
ubx.cid_table[0x0a08]   = (decode_null, None, None, 'mon/txbuf',        'none')
ubx.cid_table[0x0a09]   = (decode_null, None, None, 'mon/hw',           'none')
ubx.cid_table[0x0a0B]   = (decode_null, None, None, 'mon/hw2',          'none')
ubx.cid_table[0x0a21]   = (decode_null, None, None, 'mon/rxr',          'none')
ubx.cid_table[0x0a27]   = (decode_null, None, None, 'mon/patch',        'none')
ubx.cid_table[0x0a28]   = (decode_null, None, None, 'mon/gnss',         'none')
ubx.cid_table[0x0a2e]   = (decode_null, None, None, 'mon/smgr',         'none')
ubx.cid_table[0x0a32]   = (decode_null, None, None, 'mon/batch',        'none')
ubx.cid_table[0x0a36]   = (decode_null, None, None, 'mon/comms',        'none')
ubx.cid_table[0x0a37]   = (decode_null, None, None, 'mon/hw3',          'none')
ubx.cid_table[0x0a38]   = (decode_null, None, None, 'mon/rf',           'none')

ubx.cid_table[0x0D01]   = (decode_null, None, None, 'tim/tp',           'none')
ubx.cid_table[0x0D03]   = (decode_null, None, None, 'tim/tm2',          'none')
ubx.cid_table[0x0D06]   = (decode_null, None, None, 'tim/vrfy',         'none')

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
