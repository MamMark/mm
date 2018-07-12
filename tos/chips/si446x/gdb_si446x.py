from si446xdef import *
from binascii import hexlify
import operator

# Setup required to use this module
#
# add the following python packages
#   sudo pip install future
#   sudo pip install construct==2.5.2
#
# copy gdb_si446x.py to <app>/.gdb_si446x.py
# and add "source ../../.gdb_si446x.py" to the <app>/.gdbinit file.
#
# also copy si446xdef.py into the gdb data directory
#    "/usr/gcc-arm-none-eabi-4_9-2015q3/arm-none-eabi/share/gdb/python"
#    this install should happen on a TagNet tree install.
#    or add this copy into the mm/tools/00_gdb/copy_gdb which will check
#    for correct source and permissions.

# convert byte array into hexlify'd string
#  with space between every two bytes (4 hex chars)
#
def get_spi_hex_helper(rb):
    """
    Return a printable string of hex array with
    spaces between every two hex digits
    """
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
    """
    Find the cmd in the struct enum list of si446x Radio
    commands and return information to use it.

    Returns a function to generate a Radio cmd msg along
    with the struct needed to interpret the response msg.

    Return (Cmd bytecode, (req msg, rsp struct))
    """
    for k,v in radio_config_cmd_ids.encoding.iteritems():
        if (v == cmd):
            try:
                cid = radio_config_cmd_ids.build(k)
                return radio_status_commands[cid]
            except:
                return (None, None)
    return (None, None)

def get_buf_repr(b, l):
    """
    Convert the byte array input into a hex ascii string.
    Limited by length l  and size of buffer b.

    Returns both a byte array of the input as well as a
    hex ascii string representation.
    """
    m = l if (l < b.type.sizeof) else b.type.sizeof
    x = 0
    b_s = bytearray()
    h_s = bytearray()
    for x in range(m):
        da = int(b[x])
        b_s.append(da)
    if (m): h_s = get_spi_hex_helper(b_s)
    return b_s, h_s

def get_spi_trace_row_repr(i):
    """
    Get a row from the trace table using GDB parse_and_eval. Then
    format ascii string with results.

    Information presented:
    Radio SPI Operation
    Entry ID, timestamp, struct name, hexbytes, <container or decoded info>

    Example return values:
    SPI_REC_GET_REPLY
    59  0x20e4237  fifo_info_rsp_s  1c40   Container({'rx_fifo_count': 28, 'tx_fifo_space': 64, 'cts': 255})
    62  0x20e47ad  SPI_REC_RX_FIFO  0x0    0x1c  70ff 2a04 bf04 490a 70ff 221a 5470 4725
    SPI_REC_READ_FRR
    63  0x20e48b1  fast_frr_s  0800 0078   state: RX, rssi: 120
    """
    st = bytearray()
    row = 'g_radio_spi_trace[' + hex(i) + ']'
    rt = gdb.parse_and_eval(row) # get gdb object for the row in the trace array
    if (rt['timestamp'] == 0) or (rt['op'] == 0) or (rt['op'] >= 6):
        return st                # nothing useful in the row object
    st += '{}  '.format(str(i))
    rt_b, rt_h = get_buf_repr(rt['buf'], rt['length'])
    c_str, r_str = get_cmd_structs(rt['struct_id'])
    st += '{}  '.format(str(rt['timestamp']))
#    print(rt['op'])
    if (rt['op'] == 2) and (c_str):    # SEND_CMD
        try:
            st += '{}  {}'.format(rt_h, radio_display_structs[r_str](r_str, rt_b))
        except:
            st += '{} {}'.format(rt['struct_id'], rt_h)
        return st
    if (rt['op'] == 3) and (r_str):  # GET_REPLY
        st += "blen:slen {}:{}, ".format(len(rt_b), r_str.sizeof()-1)
        if (len(rt_b) == (r_str.sizeof() - 1)):
            st += '{}  {}  {}'.format(r_str.name, rt_h,
                    radio_display_structs[r_str](r_str, bytearray('\xff') + rt_b))
            return st
    if (rt['op'] == 1):  # READ_FRR
        r_str = fast_frr_s
        if (len(rt_b) > 1):
            tt = radio_display_structs[r_str](r_str, rt_b)
        else:
            tt = ''
        st += '{}  {}  {}'.format(r_str.name, rt_h, tt)
        return st

    ba = bytearray()
    ba.append(int(rt['struct_id']))
    try:
        bx = radio_config_cmd_ids.parse(ba)
        bxa = radio_config_commands[radio_config_cmd_ids.build(bx)][1].parse(rt_b)
    except:
        bx = hexlify(ba)
        bxa = ''
    st += '|| {}  {}  {}  {}  {}'.format(rt['op'], bx, rt['length'], rt_h, bxa)
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

def GetArgs(args, count):
    alist   = args.split()
    a_start = 0
    a_end   = count
    if (len(alist) == 1):
        a_start = count - int(alist[0])
    elif (len(alist) == 2):
        a_start = count - int(alist[1])
        a_end   = a_start + int(alist[0])
    return a_start, a_end, alist

class RadioSPI (gdb.Command):
    """ Dump radio SPI transfer trace records"""
    def __init__ (self):
        super (RadioSPI, self).__init__("radiospi", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        i_this   = int(gdb.parse_and_eval('g_radio_spi_trace_next'))
        i_prev   = int(gdb.parse_and_eval('g_radio_spi_trace_prev'))
        i_max    = int(gdb.parse_and_eval('g_radio_spi_trace_max'))
        i_count  = int(gdb.parse_and_eval('g_radio_spi_trace_count'))
        if (i_count < i_max): i_this = 0
#        print("queue: this:{}, prev:{}, max:{}, count:{}".format(i_this, i_prev, i_max, i_count))
        a_start, a_end, alist = GetArgs(args, i_count)
#        print('args({},{}): {}'.format(a_start, a_end, alist))
        for i_loop in range(i_count):
            ss = None
            if (i_loop > a_start) and (i_loop <= a_end):
                ss = get_spi_trace_row_repr(i_this)
#            else:
#                print("{}.{}.{}".format(a_start,i_loop,a_end))
            if (ss): print ss
            if (i_this == i_prev): break
            i_this += 1
            if (i_this >= i_max):
                i_this = 0


class RadioGroups (gdb.Command):
    """
    Dump all radio device configuration and status groups

    If no arguments, then display all groups. Else display specific
    groups identified by arguments.
    """
    def __init__ (self):
        super (RadioGroups, self).__init__("radiogroups", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        rd = gdb.parse_and_eval('g_radio_dump')
        for grp, __ in radio_config_group_ids.encoding.iteritems():
            if (args) and (grp not in args): continue
            bgrp = 'PAx' if (grp == 'PA') else grp
            str = radio_config_groups[radio_config_group_ids.build(grp)]
            r_a, r_s = get_buf_repr(rd[bgrp], str.sizeof())
            print grp, bgrp, str, r_s
            print radio_display_structs[str](str, r_a)


class RadioStats (gdb.Command):
    """
    Dump out radio software stats, error counters etc.
    """
    def __init__ (self):
        super (RadioStats, self).__init__("radiostats", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        rd = gdb.parse_and_eval('Si446xDriverLayerP__global_ioc')
        st = "pRxMsg:\t\t{}\tpTxMsg:\t\t{}".format(rd['pRxMsg'], rd['pTxMsg'])
        print st
        print "rc_readys:\t\t" + str(rd['rc_readys'])
        print "tx_packets:\t\t" + str(rd['tx_packets'])
        print "tx_reports:\t\t" + str(rd['tx_reports'])
        print "tx_timeouts:\t\t" + str(rd['tx_timeouts'])
        print "tx_underruns:\t\t" + str(rd['tx_underruns'])
        print
        print "rx_packets:\t\t" + str(rd['rx_packets'])
        print "rx_reports:\t\t" + str(rd['rx_reports'])
        print "rx_bad_crcs:\t\t" + str(rd['rx_bad_crcs'])
        print "rx_timeouts:\t\t" + str(rd['rx_timeouts'])
        print "rx_inv_syncs:\t\t" + str(rd['rx_inv_syncs'])
        print "rx_errors:\t\t" + str(rd['rx_errors'])
        print
        print "rx_overruns:\t\t" + str(rd['rx_overruns'])
        print "rx_active_overruns:\t" + str(rd['rx_active_overruns'])
        print "rx_crc_overruns:\t" + str(rd['rx_crc_overruns'])
        print "rx_crc_packet_rx:\t" + str(rd['rx_crc_packet_rx'])
        print "tx_send_wait_time:\t" + str(rd['send_wait_time'])
        print "tx_send_max_wait:\t" + str(rd['send_max_wait'])

class RadioRaw (gdb.Command):
    """
    Dump out radio hardware context.
    """
    def __init__ (self):
        super (RadioRaw, self).__init__("radioraw", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        arglist = gdb.string_to_argv(args.upper())
        print('args',arglist)
        if 'GROUPS' in arglist:
            print('GROUPS')
            rd = gdb.parse_and_eval('g_radio_dump')
            dg = {}
            group_order = sorted(radio_config_group_ids.encoding.items(),
                                 key=operator.itemgetter(1))
            for grp in radio_config_group_ids.encoding.keys():
                bgrp = 'PAx' if (grp == 'PA') else grp  # fixup construct module bug
                buf = radio_config_groups[radio_config_group_ids.build(grp)]
                r_a, r_s = get_buf_repr(rd[bgrp], buf.sizeof)
                dg[radio_config_group_ids.build(grp)] = r_a
                print(grp, radio_config_group_ids.build(grp), r_s, r_a)
            print(dg)

class RadioInfo (gdb.Command):
    """
    Dump out radio hardware context.
    """
    def __init__ (self):
        super (RadioInfo, self).__init__("radioinfo", gdb.COMMAND_USER)

    def invoke (self, args, from_tty):
        arglist = gdb.string_to_argv(args.upper())
        for cmd_id in ['part_info', 'func_info']:
            info_buf = gdb.parse_and_eval('g_radio_dump.' + cmd_id)
            print(info_buf)


RadioGroups()
RadioSPI()
RadioFSM()
RadioStats()
RadioRaw()
RadioInfo()
