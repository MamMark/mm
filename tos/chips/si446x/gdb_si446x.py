from si446xdef import *
from binascii import hexlify

def get_spi_hex_helper(rb):
    r_s  = bytearray()
    x    = 0
    i    = 4
    r    = 0
    buf  = hexlify(rb)
    while (x < len(buf)):
        r = i if (x+i < len(buf)) else len(buf[x:])
        r_s += buf[x:x+r] + ' '
        x += r
    return r_s

def get_cmd_structs(cmd):
    for k,v in radio_cmd_ids.encoding.iteritems():
        if (v == cmd):
            try:
                cid = radio_cmd_ids.build(k)
                return radio_command_structs[cid]
            except:
                return (None, None)
    return (None, None)

def get_spi_buf_repr(b, l):
    m = l if (l < b.type.sizeof) else b.type.sizeof
    x = 0
    b_s = bytearray()
    r_s = bytearray()
    for x in range(m):
        da = int(b[x])
        b_s.append(da)
    if (m): r_s = get_spi_hex_helper(b_s)
    return b_s, r_s

def get_spi_trace_row_repr(i):
    st = bytearray()
    row = 'g_radio_spi_trace[' + hex(i) + ']'
    rt = gdb.parse_and_eval(row)
    if (rt['timestamp'] == 0) or (rt['op'] == 0) and (rt['op'] >= 6):
        return st
    st += '{}  '.format(str(i))
    rt_b_a, rt_b_s = get_spi_buf_repr(rt['buf'], rt['length'])
    c_str, r_str = get_cmd_structs(rt['struct_id'])
    st += '{}  '.format(str(rt['timestamp']))
    print(rt['op'])
    if (rt['op'] == 2) and (c_str):    # SEND_CMD
        st += '{}  {}  {}'.format(c_str.name, rt_b_s, radio_display_funcs[c_str](c_str, rt_b_a))
    elif (rt['op'] == 3) and (r_str):  # GET_REPLY
        st += '{}  {}  {}'.format(r_str.name, rt_b_s, radio_display_funcs[r_str](r_str, bytearray('\xff') + rt_b_a))
    elif (rt['op'] == 1):  # READ_FRR
        r_str = fast_frr_s
        tt = radio_display_funcs[r_str](r_str, rt_b_a)
        st += '{}  {}  {}'.format(r_str.name, rt_b_s, tt)
    else:
        ba = bytearray()
        ba.append(int(rt['op']))
        try:
            bx = radio_cmd_ids.parse(ba)
        except:
            bx = ''
        st += '{}  {}  {}  {}  {}'.format(rt['op'], rt['struct_id'], bx, rt['length'], rt_b_s)
    return st


class RadioFSM (gdb.Command):
    """ Dump all radio device finite state machine transitions"""
    def __init__ (self):
        super (RadioFSM, self).__init__("radiofsm", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        i_loop = 0
        i_this = int(gdb.parse_and_eval('Si446xDriverLayerP__fsm_tc'))
        i_prev = int(gdb.parse_and_eval('Si446xDriverLayerP__fsm_tp'))
        i_max = int(gdb.parse_and_eval('Si446xDriverLayerP__fsm_max'))
        i_count = int(gdb.parse_and_eval('Si446xDriverLayerP__fsm_count'))
        if (i_count < i_max): i_this = 0
        print i_this, i_prev, i_max
        while (i_loop < i_max):
            rd = gdb.parse_and_eval('Si446xDriverLayerP__fsm_trace_array[{}]'.format(hex(i_this)))
            print 't{:6d}: time:{:10s}({:6s}) {:>18s}  {:<18s} {:>18s}  {:<18s}'.format(
                int(i_this),
                rd['ts_start'], rd['elapsed'],
                rd['ev'].__str__().replace('Si446xDriverLayerP__',''),
                rd['cs'].__str__().replace('Si446xDriverLayerP__',''),
                rd['ac'].__str__().replace('Si446xDriverLayerP__',''),
                rd['ns'].__str__().replace('Si446xDriverLayerP__',''))
            if (i_this == i_prev): break
            i_this += 1
            if (i_this >= i_max):
                i_this = 0
            i_loop += 1


class RadioSPI (gdb.Command):
    """ Dump radio SPI transfer trace records"""
    def __init__ (self):
        super (RadioSPI, self).__init__("radiospi", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        i_loop   = 0
        i_this   = int(gdb.parse_and_eval('g_radio_spi_trace_next'))
        i_prev   = int(gdb.parse_and_eval('g_radio_spi_trace_prev'))
        i_max    = int(gdb.parse_and_eval('g_radio_spi_trace_max'))
        i_count  = int(gdb.parse_and_eval('g_radio_spi_trace_count'))
        if (i_count < i_max): i_this = 0
        print i_this, i_prev, i_max
        while (i_loop < i_max):
            ss =  get_spi_trace_row_repr(i_this)
            if (ss): print ss
            if (i_this == i_prev): break
            i_this += 1
            if (i_this >= i_max):
                i_this = 0
            i_loop += 1


class RadioGroups (gdb.Command):
    """ Dump all radio device configuration and status"""
    def __init__ (self):
        super (RadioGroups, self).__init__("radiogroups", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        rd = gdb.parse_and_eval('g_radio_dump')
        for grp, _ in radio_config_group_ids.encoding.iteritems():
            if (args) and (grp not in args): continue
            bgrp = 'PAx' if (grp == 'PA') else grp
            str = radio_config_groups[radio_config_group_ids.build(grp)]
            r_a, r_s = get_spi_buf_repr(rd[bgrp], str.sizeof)
            print grp, bgrp, str, r_s
            print radio_display_structs[str](str, r_a)


RadioGroups ()
RadioSPI ()
RadioFSM ()
