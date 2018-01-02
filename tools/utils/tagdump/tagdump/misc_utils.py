#
# Copyright (c) 2017-2018 Eric B. Decker, Daniel J. Maltbie
# All rights reserved.
#
# Misc Utilities
#

import binascii

def buf_str(buf):
    """
    Convert buffer into its display bytes
    """
    i    = 0
    p_ds = ''
    p_s  = binascii.hexlify(buf)
    while (i < (len(p_s))):
        p_ds += p_s[i:i+2] + ' '
        i += 2
    return p_ds


def dump_buf(buf, pre=''):
    bs = buf_str(buf)
    stride = 16         # how many bytes per line

    # 3 chars per byte
    idx = 0
    print(pre + 'rec:  '),
    while(idx < len(bs)):
        max_loc = min(len(bs), idx + (stride * 3))
        print(bs[idx:max_loc])
        idx += (stride * 3)
        if idx < len(bs):              # if more then print counter
            print(pre + '{:04x}: '.format(idx/3)),
