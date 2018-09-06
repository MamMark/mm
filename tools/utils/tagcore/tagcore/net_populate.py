'''assign decoders and emitters for network data types'''

from   dt_defs       import DT_TAGNET
import dt_defs       as     dtd
from   net_headers   import *
from   net_emitters  import *

def decode_default(level, offset, buf, obj):
    return obj.set(buf)

#
dtd.dt_records[DT_TAGNET]           = (  0, decode_default, [ emit_tagnet ],      obj_dt_tagnet(),    'TAGNET',       'obj_dt_tagnet'   )
