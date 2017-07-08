from __future__ import print_function   # python3 print function

# from builtins import *

from construct import *

import binascii

"""
This module contains details of all data structures exposed by
the Si446x Radio chip. The radio provides its configuration and
status information through an SPI interface. The radio operates by
accepting commands and returning responses using a shared 16 byte
memory buffer exposed by the SPI interface. Additionally, the
radio provides SPI access to its transmit and receive fifos as
well as its fast response registers.

This module uses the 'construct' Python module for defining
the information provided by the radio. each command, response,
and property group describes a bit field oriented structure
presented by the radio. Methods for parsing, building, and
iterating on these structures are provided by the construct base
classes.

The structures defined in this module include:
- commands,
- responses,
- property groups,
- fast response registers,
- Timeout values,
- GPIO pin definitions
- and various other constants

'Helper' Structures and Methods for accessing and formatting the
radio data structures are also included. In particular, enums,
functions, and  dictionaries provide translations to access these
routines with some known attribute, e.g., the Si446x name string,
the Si446x numeric identifier, or the structure name. This includes:

- radio_group_ids        = (enum) convert group name to identifier
- radio_groups           = (dict) identifier : group structure
- radio_cmd_ids          = (enum) convert command name to identifer
- radio_commands         = (dict) identifier : (cmd structure,
                                                rsp structure)
- radio_display_structs  = (dict) structure : display function
- class RadioTraceIds    = (func) identifer <-> name

Other includes:
- DBus name constants
"""

#################################################################
#
#
# object_path includes interface/unit numbering
#
BUS_NAME = 'org.tagnet.si446x'
OBJECT_PATH = '/org/tagnet/si446x/0/0'


#################################################################
#
# radio operation wait times, in seconds. Used to set alarms
#
POWER_ON_WAIT_TIME     = 0.010         # wait after SDN=enabled
POWER_UP_WAIT_TIME     = 0.020         # wait after PWRON command
TX_WAIT_TIME           = 0.100         # wait for tx failure
RX_WAIT_TIME           = 0.100         # wait for rx failure

# radio fifo limits
#
TX_FIFO_MAX            = 64
TX_FIFO_EMPTY          = 0
RX_FIFO_MAX            = 64
RX_FIFO_EMPTY          = 0

# RPi GPIO Pin Assignments, radio needs to be configured as well
#
GPIO_CTS               = 16
GPIO_NIRQ              = 22
GPIO_SDN               = 18

# maximum size of radio response buffer, excluding the CTS byte
#
MAX_RADIO_RSP          = 15

# maximum number of group properties that can be set in one command
#
MAX_GROUP_WRITE        = 12

#################################################################
#
# Enumerations
#
def Si446xCmds_t(code):
    return Enum(code,
                NOP                    = 0,
                POWER_UP               = 0x02,
                PART_INFO              = 0x01,
                FUNC_INFO              = 0x10,
                SET_PROPERTY           = 0x11,
                GET_PROPERTY           = 0x12,
                GPIO_PIN_CFG           = 0x13,
                FIFO_INFO              = 0x15,
                GET_INT_STATUS         = 0x20,
                REQUEST_DEVICE_STATE   = 0x33,
                CHANGE_STATE           = 0x34,
                READ_CMD_BUFF          = 0x44,
                FRR_A_READ             = 0x50,
                FRR_B_READ             = 0x51,
                FRR_C_READ             = 0x53,
                FRR_D_READ             = 0x57,
                IRCAL                  = 0x17,
                IRCAL_MANUAL           = 0x1a,
                START_TX               = 0x31,
                WRITE_TX_FIFO          = 0x66,
                PACKET_INFO            = 0x16,
                GET_MODEM_STATUS       = 0x22,
                START_RX               = 0x32,
                RX_HOP                 = 0x36,
                READ_RX_FIFO           = 0x77,
                GET_ADC_READING        = 0x14,
                GET_PH_STATUS          = 0x21,
                GET_CHIP_STATUS        = 0x23,
            )
#end def

radio_cmd_ids = Si446xCmds_t(Byte('radio_cmd_ids'))


def Si446xPropGroups_t(subcon):
    return Enum(subcon,
                GLOBAL                 = 0x00,
                INT_CTL                = 0x01,
                FRR_CTL                = 0x02,
                PREAMBLE               = 0x10,
                SYNC                   = 0x11,
                PKT                    = 0x12,
                MODEM                  = 0x20,
                MODEM_CHFLT            = 0x21,
                PA                     = 0x22,
                SYNTH                  = 0x23,
                MATCH                  = 0x30,
                FREQ_CTL               = 0x40,
                RX_HOP                 = 0x50,
            )
#end def

radio_group_ids = Si446xPropGroups_t(Byte('radio_config_group_ids'))

def Si446xFrrCtlMode_t(subcon):
    return Enum(subcon,
                DISABLED               = 0,
                INT_PH_PEND            = 4,
                INT_MODEM_PEND         = 6,
                CURRENT_STATE          = 9,
                LATCHED_RSSI           = 10,
                _default_              = 0,
            )
#end def

def Si446xNextStates_t(subcon):
    return Enum(subcon,
                NOCHANGE               = 0,
                SLEEP                  = 1,
                SPI_ACTIVE             = 2,
                READY                  = 3,
                READY2                 = 4,
                TX_TUNE                = 5,
                RX_TUNE                = 6,
                TX                     = 7,
                RX                     = 8,
                _default_              = 0,
            )
#end def

def Si446xCommandErrorStatus_t(subcon):
    return Enum(subcon,
                NO_ERROR               = 0,
                BAD_COMMAND            = 16,
                BAD_ARG                = 17,
                COMMAND_BUSY           = 18,
                BAD_BOOTMODE           = 49,
                BAD_PROPERTY           = 64,
                BAD_UNKNOWN            = 240,
    )

#################################################################
#
# structures defined to encode/decode packet format

#
group_s = Struct('group_s',
                 Si446xPropGroups_t(Byte("group")),
                 Byte('num_props'),
                 Byte('start_prop'),
)

ph_pend_s = Struct('ph_pend_s',
                   BitStruct('ph_pend',
                             Flag('FILTER_MATCH'),
                             Flag('FILTER_MISS'),
                             Flag('PACKET_SENT'),
                             Flag('PACKET_RX'),
                             Flag('CRC_ERROR'),
                             Padding(1),
                             Flag('TX_FIFO_ALMOST_EMPTY'),
                             Flag('RX_FIFO_ALMOST_FULL'),
                   ),
)
ph_status_s = Struct('ph_status_s',
                     BitStruct('ph_status',
                               Flag('FILTER_MATCH'),
                               Flag('FILTER_MISS'),
                               Flag('PACKET_SENT'),
                               Flag('PACKET_RX'),
                               Flag('CRC_ERROR'),
                               Padding(1),
                               Flag('TX_FIFO_ALMOST_EMPTY'),
                               Flag('RX_FIFO_ALMOST_FULL'),
                     ),
)
modem_pend_s = Struct('modem_pend_s',
                      BitStruct('modem_pend',
                                Padding(1),
                                Flag('POSTAMBLE_DETECT'),
                                Flag('INVALID_SYNC'),
                                Flag('RSSI_JUMP'),
                                Flag('RSSI'),
                                Flag('INVALID_PREAMBLE'),
                                Flag('PREAMBLE_DETECT'),
                                Flag('SYNC_DETECT'),
                      ),
)
modem_status_s = Struct('modem_status_s',
                        BitStruct('modem_status',
                                  Padding(1),
                                  Flag('POSTAMBLE_DETECT'),
                                  Flag('INVALID_SYNC'),
                                  Flag('RSSI_JUMP'),
                                  Flag('RSSI'),
                                  Flag('INVALID_PREAMBLE'),
                                  Flag('PREAMBLE_DETECT'),
                                  Flag('SYNC_DETECT'),
                        ),
)
chip_pend_s = Struct('chip_pend_s',
                     BitStruct('chip_pend',
                               Padding(1),
                               Flag('CAL'),
                               Flag('FIFO_UNDERFLOW_OVERFLOW_ERROR'),
                               Flag('STATE_CHANGE'),
                               Flag('CMD_ERROR'),
                               Flag('CHIP_READY'),
                               Flag('LOW_BATT'),
                               Flag('WUT'),
                     ),
)
chip_status_s = Struct('chip_status_s',
                       BitStruct('chip_status',
                                 Padding(1),
                                 Flag('CAL'),
                                 Flag('FIFO_UNDERFLOW_OVERFLOW_ERROR'),
                                 Flag('STATE_CHANGE'),
                                 Flag('CMD_ERROR'),
                                 Flag('CHIP_READY'),
                                 Flag('LOW_BATT'),
                                 Flag('WUT'),
                       )
)

clr_pend_int_s = Struct('clr_pend_int_s',
                          Embedded(ph_pend_s),
                          Embedded(modem_pend_s),
                          Embedded(chip_pend_s),
                          )

def _display_clr_pend_int(str, buf):
    rsp  = clr_pend_int_s.parse(buf)
    s    = ''
    s += _display_items('ph_pend', rsp.ph_pend.items)
    s += _display_items('modem_pend', rsp.modem_pend.items)
    s += _display_items('chip_pend', rsp.chip_pend.items)
    return s

change_state_cmd_s = Struct('change_state_cmd_s',
                            Si446xCmds_t(UBInt8("cmd")),
                            Si446xNextStates_t(Byte("state")),
                        )

def _display_change_state_cmd(str, buf):
    cmd = str.parse(buf)
    s = 'Next state: {}'.format(cmd.state)
    return s

change_state_rsp_s = Struct('change_state_rsp_s',
                            Byte('cts'),
                        )

config_frr_cmd_s = Struct('config_frr_cmd_s',
                          Si446xCmds_t(UBInt8("cmd")),
                          Embedded(group_s),
                          Si446xFrrCtlMode_t(Byte('a_mode')),
                          Si446xFrrCtlMode_t(Byte('b_mode')),
                          Si446xFrrCtlMode_t(Byte('c_mode')),
                          Si446xFrrCtlMode_t(Byte('d_mode')),
                      )

fast_frr_s = Struct('fast_frr_s',
                       Si446xNextStates_t(Byte('state')),
                       Embedded(ph_pend_s),
                       Embedded(modem_pend_s),
                       Byte('rssi'),
                   )

def _display_fast_frr(str, buf):
    if (len(buf) < fast_frr_s.sizeof()):
        return binascii.hexlify(buf)
    rsp = fast_frr_s.parse(buf)
    ste = rsp.state
    ph = _display_items('ph_pend', rsp.ph_pend.items)
    mdm = _display_items('modem_pend', rsp.modem_pend.items)
    rs = rsp.rssi
    s = 'state: {}, {}, {}, rssi: {}'.format(ste, ph, mdm, rs)
    return s

fast_frr_rsp_s = Struct('fast_frr_rsp_s',
                       Byte('cts'),
                       Embedded(fast_frr_s),
                   )

def _display_fast_frr_rsp(str, buf):
    return _display_fast_frr(str, buf[1:])

fifo_info_cmd_s = Struct('fifo_info_cmd_s',
                         Si446xCmds_t(UBInt8("cmd")),
                         BitStruct('state',
                                   Padding(6),
                                   Flag('rx_reset'),
                                   Flag('tx_reset'),
                               ),
                    )


fifo_info_rsp_s = Struct('fifo_info_rsp_s',
                         Byte('cts'),
                         Byte('rx_fifo_count'),
                         Byte('tx_fifo_space'),
                    )


get_clear_int_cmd_s = Struct('get_clear_int_cmd_s',
                            Si446xCmds_t(UBInt8("cmd")),
                            Embedded(clr_pend_int_s),
                        )

def _display_get_clear_int_cmd(str, buf):
    return _display_clr_pend_int(str, buf[1:])

get_property_cmd_s = Struct('get_property_cmd_s',
                            Si446xCmds_t(UBInt8("cmd")),
                            Embedded(group_s),
                        )

get_property_rsp_s = Struct('get_property_rsp_s',
                            Byte('cts'),
                            GreedyRange(Byte('data'))
                        )

gpio_cfg_s =  BitStruct('gpio_cfg_s',
                        Enum(BitField('state',1),
                             INACTIVE = 0,
                             ACTIVE = 1,
                             ),
                        Enum(BitField('pull_ctl',1),
                             PULL_DIS = 0,
                             PULL_EN = 1,
                             ),
                        Enum(BitField('mode',6),
                             DONOTHING = 0,
                             TRISTATE = 1,
                             DRIVE0 = 2,
                             DRIVE1 = 3,
                             INPUT = 4,
                             C32K_CLK = 5,
                             BOOT_CLK = 6,
                             DIV_CLK = 7,
                             CTS = 8,
                             INV_CTS = 9,
                             CMD_OVERLAP = 10,
                             SDO = 11,
                             POR = 12,
                             CAL_WUT = 13,
                             WUT = 14,
                             EN_PA = 15,
                             TX_DATA_CLK = 16,
                             RX_DATA_CLK = 17,
                             EN_LNA = 18,
                             TX_DATA = 19,
                             RX_DATA = 20,
                             RX_RAW_DATA = 21,
                             ANTENNA_1_SW = 22,
                             ANTENNA_2_SW = 23,
                             VALID_PREAMBLE = 24,
                             INVALID_PREAMBLE = 25,
                             SYNC_WORD_DETECT = 26,
                             CCA = 27,
                             IN_SLEEP = 28,
                             TX_STATE = 32,
                             RX_STATE = 33,
                             RX_FIFO_FULL = 34,
                             TX_FIFO_EMPTY = 35,
                             LOW_BATT = 36,
                             CCA_LATCH = 37,
                             HOPPED = 38,
                             HOP_TABLE_WRAP = 39,
                         ),
                        )

nirq_cfg_s =  BitStruct('nirq_cfg_s',
                        Enum(BitField('state',1),
                             INACTIVE = 0,
                             ACTIVE = 1,
                             ),
                        Enum(BitField('pull_ctl',1),
                             PULL_DIS = 0,
                             PULL_EN = 1,
                             ),
                        Enum(BitField('mode',6),
                             DONOTHING = 0,
                             TRISTATE = 1,
                             DRIVE0 = 2,
                             DRIVE1 = 3,
                             INPUT = 4,
                             DIV_CLK = 7,
                             CTS = 8,
                             SDO = 11,
                             POR = 12,
                             EN_PA = 15,
                             TX_DATA_CLK = 16,
                             RX_DATA_CLK = 17,
                             EN_LNA = 18,
                             TX_DATA = 19,
                             RX_DATA = 20,
                             RX_RAW_DATA = 21,
                             ANTENNA_1_SW = 22,
                             ANTENNA_2_SW = 23,
                             VALID_PREAMBLE = 24,
                             INVALID_PREAMBLE = 25,
                             SYNC_WORD_DETECT = 26,
                             CCA = 27,
                             NIRQ = 39,
                         ),
                        )

sdo_cfg_s =  BitStruct('sdo_cfg_s',
                        Enum(BitField('state',1),
                             INACTIVE = 0,
                             ACTIVE = 1,
                             ),
                        Enum(BitField('pull_ctl',1),
                             PULL_DIS = 0,
                             PULL_EN = 1,
                             ),
                        Enum(BitField('mode',6),
                             DONOTHING = 0,
                             TRISTATE = 1,
                             DRIVE0 = 2,
                             DRIVE1 = 3,
                             INPUT = 4,
                             C32K_CLK = 5,
                             DIV_CLK = 7,
                             CTS = 8,
                             SDO = 11,
                             POR = 12,
                             WUT = 14,
                             EN_PA = 15,
                             TX_DATA_CLK = 16,
                             RX_DATA_CLK = 17,
                             EN_LNA = 18,
                             TX_DATA = 19,
                             RX_DATA = 20,
                             RX_RAW_DATA = 21,
                             ANTENNA_1_SW = 22,
                             ANTENNA_2_SW = 23,
                             VALID_PREAMBLE = 24,
                             INVALID_PREAMBLE = 25,
                             SYNC_WORD_DETECT = 26,
                             CCA = 27,
                         ),
                        )

set_gpio_pin_cfg_cmd_s = Struct('set_gpio_pin_cfg_cmd_s',
                                Si446xCmds_t(UBInt8("cmd")),
                                Rename('gpio1', gpio_cfg_s),
                                Rename('gpio2', gpio_cfg_s),
                                Rename('gpio3', gpio_cfg_s),
                                Rename('gpio4', gpio_cfg_s),
                                nirq_cfg_s,
                                sdo_cfg_s,
                                BitStruct('gen_config',
                                          Padding(1),
                                          Enum(BitField('drive_strength',2),
                                               HIGH = 0,
                                               MED_HIGH = 1,
                                               MED_LOW = 2,
                                               LOW = 3,
                                               ),
                                          Padding(5),
                                          ),
                                )

get_gpio_pin_cfg_rsp_s = Struct('get_gpio_pin_cfg_rsp_s',
                                Byte('cts'),
                                Array(4, gpio_cfg_s),
                                nirq_cfg_s,
                                sdo_cfg_s,
                                BitStruct('gen_config',
                                          Padding(1),
                                          Enum(BitField('drive_strength',2),
                                               HIGH = 0,
                                               MED_HIGH = 1,
                                               MED_LOW = 2,
                                               LOW = 3,
                                               ),
                                          Padding(5),
                                          ),
                                )

def _display_gpio_pin_cfg_rsp(str, buf):
    rsp  = str.parse(buf)
    s    = ''
    n    = 0
    for k,v in rsp.gen_config.items():
        s += ', {} {}'.format(k,v)
    for item in rsp.gpio_cfg_s:
        s += ', pin[{}]({}:{}) {}'.format(n, item.mode, item.state, item.pull_ctl)
        n += 1
    item = rsp.nirq_cfg_s
    s += ', {} {} / {}'.format(item.mode, item.state, item.pull_ctl)
    item = rsp.sdo_cfg_s
    s += ', {} {} / {}'.format(item.mode, item.state, item.pull_ctl)
    return s

int_status_rsp_s = Struct('int_status_rsp_s',
                          Byte('cts'),
                          BitStruct('int_pend',
                                    Padding(5),
                                    Flag('CHIP_INT'),
                                    Flag('MODEM_INT'),
                                    Flag('PH_INT'),
                                ),
                          BitStruct('int_status',
                                    Padding(5),
                                    Flag('CHIP_INT_STATUS'),
                                    Flag('MODEM_INT_STATUS'),
                                    Flag('PH_INT_STATUS'),
                                ),
                          Embedded(ph_pend_s),
                          Embedded(ph_status_s),
                          Embedded(modem_pend_s),
                          Embedded(modem_status_s),
                          Embedded(chip_pend_s),
                          Embedded(chip_status_s),
                          )

def _display_int_status_rsp(str, buf):
    rsp  = str.parse(buf)
    s    = ''
    s += _display_items('ph_pend', rsp.ph_pend.items)
    s += _display_items('modem_pend', rsp.modem_pend.items)
    s += _display_items('chip_pend', rsp.chip_pend.items)
    s += _display_items('ph_status', rsp.ph_status.items)
    s += _display_items('modem_status', rsp.modem_status.items)
    s += _display_items('chip_status', rsp.chip_status.items)
    return s

packet_info_cmd_s = Struct('packet_info_cmd_s',
                           Si446xCmds_t(UBInt8("cmd")),
                           BitStruct('field',
                                     Padding(2),
                                     Enum(BitField('field_number',6),
                                          NO_OVERRIDE = 0,
                                          PKT_FIELD_1 = 1,
                                          PKT_FIELD_2 = 2,
                                          PKT_FIELD_3 = 4,
                                          PKT_FIELD_4 = 8,
                                          PKT_FIELD_5 = 16,
                                      )
                                 )
                       )

packet_info_rsp_s = Struct('packet_info_rsp_s',
                           Byte('cts'),
                           UBInt16('length'),
                       )

# command=
# ox00  cmd=Si446xCmds.POWER_UP
# ox01  boot_options=[patch(7)patch=NO_PATCH(0), (5:0)FUNC=PRO(1)]
# 0x02  xtal_options=[(0)TCXO=XTAL(0)]
# 0x03  xofreq=0x01C9C380  x0[31:24]
# 0x04                     XO_FREQ[23:16]
# 0x05                     XO_FREQ[15:8]
# 0x06                     XO_FREQ[7:0]
# response=
# 0x00  cts=  0xff=NOT_READY
#
power_up_cmd_s = Struct('power_up_cmd_s',
                        Si446xCmds_t(UBInt8("cmd")),
                        BitStruct('boot_options',
                                  Flag('patch'),
                                  Padding(1),
                                  BitField('func',6)
                              ),
                        BitStruct('xtal_options',
                                  Padding(6),
                                  BitField('txcO', 2)
                              ),
                        UBInt32('xo_freq')
                    )

read_cmd_s = Struct('read_cmd_s',
                    Si446xCmds_t(UBInt8("cmd")
                ),
)

def _display_read_cmd(str, buf):
    cmd = str.parse(buf)
    s = 'command: {}'.format(cmd.cmd)
    return s

read_cmd_buff_rsp_s = Struct('read_cmd_buff_rsp_s',
                             Byte('cts'),
                             Field('cmd_buff', lambda ctx: 15)
                         )

read_func_info_rsp_s = Struct('read_func_info_rsp_s',
                              Byte('cts'),
                              Byte('revext'),
                              Byte('revbranch'),
                              Byte('revint'),
                              UBInt16('patch'),
                              Byte('func'),
                          )

def _display_read_func_info_rsp(str, buf):
    response = str.parse(buf)
    return ("Firmware: %d.%d.%d, patch: 0x%x, func: 0x%x"%
              (response.revext, response.revbranch, response.revint, response.patch, response.func))

read_part_info_rsp_s = Struct('read_part_info_rsp_s',
                              Byte('cts'),
                              Byte('chiprev'),
                              UBInt16('part'),
                              Byte('pbuild'),
                              UBInt16('id'),
                              Byte('customer'),
                              Byte('romid'),
                          )

def _display_read_part_info_rsp(str, buf):
    response = str.parse(buf)
    return ("Part Number: %x, rev: 0x%x, id: 0x%x, romid: 0x%x"%
              (response.part, response.chiprev, response.id, response.romid))

set_property_cmd_s = Struct('set_property_cmd_s',
                            Si446xCmds_t(UBInt8("cmd")),
                            Embedded(group_s),
                        )

#
start_rx_cmd_s = Struct('start_rx_cmd_s',
                        Si446xCmds_t(UBInt8("cmd")),
                        Byte('channel'),
                        BitStruct('condition',
                                  Padding(6),
                                  Enum(BitField('start',2),
                                       IMMEDIATE = 0,
                                       WUT = 1,
                                   ),
                              ),
                        UBInt16('rx_len'),
                        Si446xNextStates_t(Byte("next_state1")),
                        Si446xNextStates_t(Byte("next_state2")),
                        Si446xNextStates_t(Byte("next_state3")),
                    )

#
start_tx_cmd_s = Struct('start_tx_cmd_s',
                        Si446xCmds_t(UBInt8("cmd")),
                        Byte('channel'),
                        BitStruct('condition',
                                  Enum(BitField('txcomplete_state',4),
                                       NOCHANGE = 0,
                                       SLEEP = 1,
                                       SPI_ACTIVE = 2,
                                       READY = 3,
                                       READY2 = 4,
                                       TX_TUNE = 5,
                                       RX_TUNE = 6,
                                       RX = 8,
                                   ),
                                  Padding(1),
                                  Enum(BitField('retransmit',1),
                                       NO = 0,
                                       YES = 1,
                                   ),
                                  Enum(BitField('start',2),
                                       IMMEDIATE = 0,
                                       WUT = 1,
                                   ),
                              ),
                        UBInt16('tx_len'),
                    )

get_chip_status_cmd_s = Struct('get_chip_status_cmd_s',
                               Si446xCmds_t(UBInt8("cmd")),
                               Embedded(chip_pend_s),
)

get_chip_status_rsp_s = Struct('get_chip_status_rsp_s',
                               Byte('cts'),
                               Embedded(chip_pend_s),
                               Embedded(chip_status_s),
                               Si446xCommandErrorStatus_t(Byte('err_status')),
                               Byte('err_cmd_id'),
)

def _display_get_chip_status_rsp(str, buf):
    rsp = str.parse(buf)
    s    = ''
    s += _display_items('chip_pend', rsp.chip_pend.items)
    s += _display_items('chip_status', rsp.chip_status.items)
    s += ', error: {}'.format(rsp.err_status)
    return s



#################################################################
#
# Radio Property Group definitions
#
global_group_s = Struct('global_group_s',
                        Byte('xo_tune'),
                        BitStruct('clk_cfg',
                                  Padding(1),
                                  Enum(BitField('divided_clk_en',1),
                                       DISABLE     = 0,
                                       ENABLE      = 1,
                                  ),
                                  Enum(BitField('divided_clk_sel',3),
                                       DIV_1       = 0,
                                       DIV_2       = 1,
                                       DIV_3       = 2,
                                       DIV_7_5     = 3,
                                       DIV_10      = 4,
                                       DIV_15      = 5,
                                       DIV_30      = 6,
                                  ),
                                  Padding(1),
                                  Enum(BitField('clk_32k_sel',2),
                                       OFF         = 0,
                                       RC          = 1,
                                       CRYSTAL     = 2,
                                  ),
                        ),
                        Byte('low_batt_thresh'),
                        BitStruct('global_config',
                                  Padding(2),
                                  Enum(BitField('sequencer_mode',1),
                                       GUARANTEED  = 0,
                                       FAST        = 1,
                                  ),
                                  Enum(BitField('fifo_mode',1),
                                       SPLIT_FIFO  = 0,
                                       HALF_DUPLEX = 1,
                                  ),
                                  Enum(BitField('protocol',3),
                                       GENERIC     = 0,
                                       IE154G      = 1,
                                  ),
                                  Enum(BitField('power_mode',1),
                                       HIGH_PERF    = 0,
                                       LOW_POWER    = 1,
                                  ),
                        ),
                        BitStruct('wut_config',
                                  Enum(BitField('wut_ldc_enable',2),
                                       DISABLE     = 0,
                                       RX_LDC      = 1,
                                  ),
                                  Enum(BitField('wut_cal_period',3),
                                       _1_SEC      = 0,
                                       _2_SEC      = 1,
                                       _4_SEC      = 2,
                                       _8_SEC      = 3,
                                       _16_SEC     = 4,
                                       _32_SEC     = 5,
                                       _64_SEC     = 6,
                                       _128_SEC    = 7,
                                  ),
                                  Enum(BitField('wut_lbd_en',1),
                                       DISABLE     = 0,
                                       ENABLE      = 1,
                                  ),
                                  Enum(BitField('wut_en',1),
                                       DISABLE     = 0,
                                       ENABLE      = 1,
                                  ),
                                  Enum(BitField('cal_en',1),
                                       DISABLE     = 0,
                                       ENABLE      = 1,
                                  ),
                        ),
                        UBInt16('wut_m'),
                        BitStruct('wut_r',
                                  Enum(BitField('RESERVED_WRITE_ONE',2),
                                       ZERO        = 0,
                                       ONE         = 1,
                                  ),
                                  Enum(BitField('wut_sleep',1),
                                       READY       = 0,
                                       SLEEP       = 1,
                                  ),
                                  BitField('wut_r_',5)
                        ),
                        Byte('wut_ldc'),
                        Byte('wut_cal'),
)
def _display_global_group(str, buf):
    return global_group_s.parse(buf)

int_ctl_group_s = Struct('int_ctl_group_s',
                         BitStruct('enable',
                                   Padding(5),
                                   Flag('CHIP_INT_STATUS_EN'),
                                   Flag('MODEM_INT_STATUS_EN'),
                                   Flag('PH_INT_STATUS_EN'),
                         ),
                         Embedded(ph_pend_s),
                         Embedded(modem_pend_s),
                         Embedded(chip_pend_s),
)

def _display_int_ctl_group(str, buf):
    rsp  = str.parse(buf)
    s    = ''
    s += _display_items('enable', rsp.enable.items)
    s += _display_items('ph_pend', rsp.ph_pend.items)
    s += _display_items('modem_pend', rsp.modem_pend.items)
    s += _display_items('chip_pend', rsp.chip_pend.items)
    return s

frr_ctl_group_s = Struct('frr_ctl_group_s',
                         Si446xFrrCtlMode_t(Byte('a_mode')),
                         Si446xFrrCtlMode_t(Byte('b_mode')),
                         Si446xFrrCtlMode_t(Byte('c_mode')),
                         Si446xFrrCtlMode_t(Byte('d_mode')),
)

def _display_frr_ctl_group(str, buf):
    rsp  = str.parse(buf)
    s    = '{}  {}  {}  {}'.format(rsp.a_mode, rsp.b_mode, rsp.c_mode, rsp.d_mode)
    return s

preamble_group_s = Struct('preamble_group_s',
                          Byte('tx_length'),
                          BitStruct('config_std_1',
                                    Enum(BitField('skip_sync_to',1),
                                         DISABLE     = 0,
                                         ENABLE      = 1,
                                    ),
                                    BitField('wut_r_',7)
                          ),
                          BitStruct('config_nstd',
                                    BitField('rx_errors',3),
                                    BitField('pattern_length',5),
                          ),
                          BitStruct('config_std_2',
                                    BitField('rx_preamble_timeout_extend',4),
                                    BitField('rx_preamble_timeout',4),
                          ),
                          BitStruct('config',
                                    Padding(2),
                                    Enum(BitField('pream_frist_1_or_0',1),
                                         First_0     = 0,
                                         First_1     = 1,
                                    ),
                                    Enum(BitField('length_config',1),
                                         NIBBLE      = 0,
                                         BYTE        = 1,
                                    ),
                                    Enum(BitField('man_const',1),
                                         NO_CON      = 0,
                                         CONST       = 1,
                                    ),
                                    Enum(BitField('man_en',1),
                                         NO_MAN      = 0,
                                         EN_MAN      = 1,
                                    ),
                                    Enum(BitField('standard_pream',2),
                                         PRE_NS      = 0,
                                         PRE_1010    = 1,
                                         PRE_0101    = 2,
                                    ),
                          ),
                          UBInt32('pattern'),
                          BitStruct('postamble_config',
                                    Enum(BitField('postamble_enable',1),
                                         DISABLE     = 0,
                                         ENABLE      = 1,
                                    ),
                                    Enum(BitField('pkt_valid_on_postamble',1),
                                         TRUE        = 0,
                                         FALSE       = 1,
                                    ),
                                    Padding(4),
                                    Enum(BitField('postamble_size',2),
                                         _8_BITS     = 0,
                                         _16_BITS    = 0,
                                         _24_BITS    = 0,
                                         _32_BITS    = 0,
                                    ),
                          ),
                          UBInt32('postamble_pattern'),
)

def _display_preamble_group(str, buf):
    return preamble_group_s.parse(buf)

sync_group_s = Struct('sync_group_s',
                      BitStruct('config',
                                Enum(BitField('skip_tx',1),
                                     SYNC_XMIT    = 0,
                                     NO_SYNC_XMIT = 1,
                                ),
                                BitField('rx_errors',3),
                                Enum(BitField('4fsk',1),
                                     DISABLE     = 0,
                                     ENABLE      = 1,
                                ),
                                Enum(BitField('manch',1),
                                     DISABLE     = 0,
                                     ENABLE      = 1,
                                ),
                                Enum(BitField('length',2),
                                     LEN_1_BYTES = 0,
                                     LEN_2_BYTES = 1,
                                     LEN_3_BYTES = 2,
                                     LEN_4_BYTES = 3,
                                ),
                      ),
                      UBInt32('sync_bits'),
)

def _display_sync_group(str, buf):
    return sync_group_s.parse(buf)

pkt_field_s = Struct('pkt_field_s',
                     UBInt16('length'),
                     BitStruct('config',
                               Padding(3),
                               Enum(BitField('4fsk',1),
                                    DISABLE      = 0,
                                    ENABLE       = 1,
                               ),
                               Padding(1),
                               Enum(BitField('pn_start',1),
                                    CONTINUE     = 0,
                                    LOAD         = 1,
                               ),
                               Enum(BitField('whiten',1),
                                    DISABLE      = 0,
                                    ENABLE       = 1,
                               ),
                               Enum(BitField('manch',1),
                                    DISABLE      = 0,
                                    ENABLE       = 1,
                               ),
                     ),
                     BitStruct('crc_config',
                               Enum(BitField('crc_start',1),
                                    DISABLE      = 0,
                                    ENABLE       = 1,
                               ),
                               Padding(1),
                               Enum(BitField('send_crc',1),
                                    DISABLE      = 0,
                                    ENABLE       = 1,
                               ),
                               Padding(1),
                               Enum(BitField('check_crc',1),
                                    DISABLE      = 0,
                                    ENABLE       = 1,
                               ),
                               Padding(1),
                               Enum(BitField('crc_enable',1),
                                    DISABLE      = 0,
                                    ENABLE       = 1,
                               ),
                               Padding(1),
                     ),
)

pkt_group_s = Struct('pkt_group_s',
                     BitStruct('crc_config',
                               Enum(BitField('crc_seed',1),
                                    CRC_SEED_0   = 0,
                                    CRC_SEED_1   = 1,
                               ),
                               Padding(3),
                               Enum(BitField('crc_polynomial',4),
                                    NO_CRC       = 0,
                                    ITU_T_CRC8   = 1,
                                    IEC_16       = 2,
                                    BAICHEVA_16  = 3,
                                    CRC_16_IBM   = 4,
                                    CCITT_16     = 5,
                                    KOOPMAN      = 6,
                                    IEEE_802_3   = 7,
                                    CASTAGNOLI   = 8,
                                    CRC_16_DNP   = 9,
                               ),
                     ),
                     UBInt16('wht_poly'),
                     UBInt16('wht_seed'),
                     BitStruct('wht_bit_num',
                               Enum(BitField('sw_wht_ctrl',1),
                                    DISABLE     = 0,
                                    ENABLE      = 1,
                               ),
                               Enum(BitField('sw_crc_ctrl',1),
                                    DISABLE     = 0,
                                    ENABLE      = 1,
                               ),
                               Padding(2),
                               Enum(BitField('wht_bit_num_',4),
                                    ENUM_0       = 0,
                                    ENUM_1       = 1,
                                    ENUM_2       = 2,
                                    ENUM_3       = 3,
                                    ENUM_4       = 4,
                                    ENUM_5       = 5,
                                    ENUM_6       = 6,
                                    ENUM_7       = 7,
                                    ENUM_8       = 8,
                                    ENUM_9       = 9,
                                    ENUM_10      = 10,
                                    ENUM_11      = 11,
                                    ENUM_12      = 12,
                                    ENUM_13      = 13,
                                    ENUM_14      = 14,
                                    ENUM_15      = 15,
                               ),
                     ),
                     BitStruct('config1',
                               Enum(BitField('ph_field_split',1),
                                    FIELD_SHARED = 0,
                                    FIELD_SPLIT  = 1,
                               ),
                               Enum(BitField('ph_rx_disable',1),
                                    RX_ENABLED   = 0,
                                    RX_DISABLED  = 1,
                               ),
                               Enum(BitField('4fsk_en',1),
                                    DISABLE      = 0,
                                    ENABLE       = 1,
                               ),
                               Padding(1),
                               Enum(BitField('manch_pol',1),
                                    PATTERN_10   = 0,
                                    PATTERN_01   = 1,
                               ),
                               Enum(BitField('crc_invert',1),
                                    NO_INVERT    = 0,
                                    INVERT_CRC   = 1,
                               ),
                               Enum(BitField('crc_endian',1),
                                    LSBYTE_FIRST = 0,
                                    MSBYTE_FIRST = 1,
                               ),
                               Enum(BitField('bit_order',1),
                                    LSBIT_FIRST  = 0,
                                    MSBIT_FIRST  = 1,
                               ),
                     ),
                     Padding(1),
                     BitStruct('length',
                               Padding(2),
                               Enum(BitField('endian',1),
                                    LITTLE        = 0,
                                    BIG           = 1,
                               ),
                               Enum(BitField('size',1),
                                    ONE_BYTE      = 0,
                                    TWO_BYTES     = 1,
                               ),
                               Enum(BitField('in_fifo',1),
                                    CUT_OUT       = 0,
                                    LEAVE_IN      = 1,
                               ),
                               Enum(BitField('dst_field',3),
                                    FIXED_LENGTH  = 0,
                                    NOT_ALLOWED   = 1,
                                    FIELD_2       = 2,
                                    FIELD_3       = 3,
                                    FIELD_4       = 4,
                                    FIELD_5       = 5,
                                    FIXED_CAPTURE = 6,
                                    FIXED_CAPTURE2 = 7,
                               ),
                     ),
                     BitStruct('len_field_source',
                               Padding(5),
                               Enum(BitField('src_field',3),
                                    FIELD_1       = 0,
                                    FIELD_1_      = 1,
                                    FIELD_2       = 2,
                                    FIELD_3       = 3,
                                    FIELD_4       = 4,
                                    DISALLOWED    = 5,
                               ),
                     ),
                     Byte('len_adjust'),
                     Byte('tx_threshold'),
                     Byte('rx_threshold'),
                     Rename('tx1', pkt_field_s),
                     Rename('tx2', pkt_field_s),
                     Rename('tx3', pkt_field_s),
                     Rename('tx4', pkt_field_s),
                     Rename('tx5', pkt_field_s),
                     Rename('rx1', pkt_field_s),
                     Rename('rx2', pkt_field_s),
                     Rename('rx3', pkt_field_s),
                     Rename('rx4', pkt_field_s),
                     Rename('rx5', pkt_field_s),
)

def _display_pkt_group(str, buf):
    return pkt_group_s.parse(buf)

modem_group_s = Struct('modem_group_s',
                       BitStruct('mod_type',
                                 Enum(BitField('tx_direct_mode_type',1),
                                      SYNC          = 0,
                                      ASYNC         = 1,
                                 ),
                                 Enum(BitField('tx_driect_mode_gpio',2),
                                      GPIO_1        = 0,
                                      GPIO_2        = 1,
                                      GPIO_3        = 2,
                                      GPIO_4        = 3,
                                 ),
                                 Enum(BitField('mod_source',2),
                                      PACKET        = 0,
                                      DIRECT        = 1,
                                      PSEUDO        = 2,
                                 ),
                                 Enum(BitField('mod_type',3),
                                      CW            = 0,
                                      OOK           = 1,
                                      _2FSK         = 2,
                                      _2GFSK        = 3,
                                      _4FSK         = 4,
                                      _4GFSK        = 5,
                                 ),
                       ),
                       BitStruct('map_control',
                                 Enum(BitField('enmanch',1),
                                      DISABLE       = 0,
                                      ENABLE        = 1,
                                 ),
                                 Enum(BitField('eninv_rxbit',1),
                                      NO_INVERT     = 0,
                                      INVERT        = 1,
                                 ),
                                 Enum(BitField('eninv_txbit',1),
                                      NO_INVERT     = 0,
                                      INVERT        = 1,
                                 ),
                                 Enum(BitField('eninv_fd',1),
                                      NO_INVERT_POL = 0,
                                      INVERT_POL    = 1,
                                 ),
                                 Padding(4),
                       ),
                       BitStruct('dsm_ctrl',
                                 Enum(BitField('dsmclk_sel',1),
                                      PLL           = 0,
                                      CRYSTAL       = 1,
                                 ),
                                 Enum(BitField('dsm_mode',1),
                                      MASH          = 0,
                                      LOOP          = 1,
                                 ),
                                 Enum(BitField('dsmdt_en',1),
                                      DISABLE       = 0,
                                      ENABLE        = 1,
                                 ),
                                 Enum(BitField('rsmdttp',1),
                                      ZERO          = 0,
                                      MINUS_ONE     = 1,
                                 ),
                                 Enum(BitField('dsm_rst',1),
                                      ENABLE        = 0,
                                      RESET         = 1,
                                 ),
                                 Enum(BitField('dsm_lsb',1),
                                      UNALTERED     = 0,
                                      FORCED_HIGH   = 1,
                                 ),
                                 Enum(BitField('dsm_order',2),
                                      ZERO_CONT     = 0,
                                      FIRST_ORDER   = 1,
                                      SECOND_ORDER  = 2,
                                      THIRD_ORDER   = 3,
                                 ),
                       ),
                       BitStruct('data_rate',
                                 BitField('m',24),
                       ),
#                       Field('data_rate', 3),
                       BitStruct('tx_nco_mode',
                                 Padding(4),
                                 Enum(BitField('txosr',2),
                                      GAUSS_10X   = 0,
                                      GAUSS_40X   = 1,
                                      GAUSS_20X   = 2,
                                      RESERVED    = 3,
                                 ),
                                 BitField('ncomod',26),
                       ),
                       BitStruct('freq_dev',
                                 Padding(7),
                                 BitField('freqdev',17),
                       ),
                       UBInt16('freq_offset'),
                       Field('filter_coeff', 9),
                       Byte('tx_ramp_delay'),
                       Byte('mdm_ctrl'),
                       BitStruct('if_control',
                                 Padding(3),
                                 Enum(BitField('zeroif',1),
                                      NORMAL      = 0,
                                      ZERO        = 1,
                                 ),
                                 Enum(BitField('fixif',1),
                                      SCALED      = 0,
                                      FIXED       = 1,
                                 ),
                                 Padding(3),
                       ),
                       BitStruct('if_freq',
                                 BitField('hertz',24),
                       ),
#                       Field('if_freq',3),
                       Byte('decimation_cfg1'),
                       Byte('decimation_cfg0'),
                       Padding(2),
                       UBInt16('bcr_osr'),
                       BitStruct('bcr_nco',
                                 BitField('offset',24),
                       ),
#                       Field('bcr_nco_offset',3),
                       UBInt16('bcr_gain'),
                       Byte('bcr_gear'),
                       Byte('bcr_misc1'),
                       Byte('bcr_misc0'),
                       Byte('afc_gear'),
                       Byte('afc_wait'),
                       UBInt16('afc_gain'),
                       UBInt16('afc_limiter'),
                       Byte('afc_misc'),
                       Byte('afc_zipoff'),
                       Byte('adc_ctrl'),
                       Byte('agc_control'),
                       Padding(2),
                       Byte('agc_window_size'),
                       Byte('agc_rffpd_decay'),
                       Byte('agc_ifpd_decay'),
                       Byte('fsk4_gain1'),
                       Byte('fsk4_gain0'),
                       UBInt16('fsk4_th'),
                       Byte('fsk4_map'),
                       Byte('ook_pdtc'),
                       Byte('ook_blopk'),
                       Byte('ook_cnt1'),
                       Byte('ook_misc'),
                       Byte('raw_search'),
                       Byte('raw_control'),
                       UBInt16('raw_eye'),
                       Byte('ant_div_mode'),
                       Byte('ant_div_control'),
                       Byte('rssi_thresh'),
                       Byte('rssi_jump_thesh'),
                       BitStruct('rssi_control',
                                 Padding(2),
                                 Enum(BitField('check_thresh_at_latch',1),
                                      DISABLE     = 0,
                                      ENABLE      = 1,
                                 ),
                                 Enum(BitField('average',2),
                                      AVERAGE4    = 0,
                                      BIT1        = 1,
                                 ),
                                 Enum(BitField('latch',3),
                                      DISABLED    = 0,
                                      PREAMBLE    = 1,
                                      SYNC        = 2,
                                      RX_STATE1   = 3,
                                      RX_STATE2   = 4,
                                      RX_STATE3   = 5,
                                      RX_STATE4   = 6,
                                      RX_STATE5   = 7,
                                 ),
                       ),
                       BitStruct('rssi_control2',
                                 Padding(2),
                                 Enum(BitField('rssijmp_dwn',1),
                                      DISABLE     = 0,
                                      ENABLE      = 1,
                                 ),
                                 Enum(BitField('rssijmp_up',1),
                                      DISABLE     = 0,
                                      ENABLE      = 1,
                                 ),
                                 Enum(BitField('enrssijmp',1),
                                      DISABLE     = 0,
                                      ENABLE      = 1,
                                 ),
                                 Enum(BitField('jmpdlylen',1),
                                      _2_Tb       = 0,
                                      _4_Tb       = 1,
                                 ),
                                 Enum(BitField('enjmprx',1),
                                      NO_RESET    = 0,
                                      RESETE      = 1,
                                 ),
                                 Padding(1),
                       ),
                       Byte('rssi_comp'),
                       Padding(2),
                       Byte('clkgen_band'),
)

def _display_modem_group(str, buf):
    return modem_group_s.parse(buf)

modem_chflt_group_s = Struct('modem_chflt_group_s',
                             Field('chflt_rx1_chflt_coe', 18),
                             Field('chflt_rx2_chflt_coe', 18),
)

def _display_modem_chflt_group(str, buf):
    return modem_chflt_group_s.parse(buf)

pa_group_s = Struct('pa_group_s',
                    BitStruct('mode',
                              Enum(BitField('ext_pa_ramp',1),
                                   DISABLE     = 0,
                                   ENABLE      = 1,
                              ),
                              Padding(1),
                              BitField('pa_sel',4),
                              Padding(1),
                              Enum(BitField('pa_mode',1),
                                   CLASS_E     = 0,
                                   SW_CURRENT  = 1,
                              ),
                    ),
                    BitStruct('pwr_lvl',
                              Padding(1),
                              BitField('ddac',7),
                    ),
                    BitStruct('bias_clkduty',
                              Enum(BitField('clk_duty',2),
                                   DIFF_50     = 0,
                                   SINGLE_25   = 3,
                              ),
                              BitField('ob',6),
                    ),
                    BitStruct('fsk_mod_dly',
                              Enum(BitField('fsk_mod_dly',3),
                                   _2_US       = 0,
                                   _6_US       = 1,
                                   _10_US      = 2,
                                   _14_US      = 3,
                                   _18_US      = 4,
                                   _22_US      = 5,
                                   _26_US      = 6,
                                   _30_US      = 7,
                              ),
                              BitField('tc',5),
                    ),
                    BitStruct('ramp_ex',
                              Padding(4),
                              BitField('tc',4),
                    ),
                    Byte('ramp_down_delay'),
)
def _display_pa_group(str, buf):
     pa_g = pa_group_s.parse(buf)
     s = 'power level: {}'.format(pa_g.pwr_lvl.ddac)
     return s


synth_group_s = Struct('synth_group_s',
                       Byte('pfdcp_cpff'),
                       Byte('pfdcp_cpint'),
                       Byte('vco_kv'),
                       Byte('lpfilt3'),
                       Byte('lpfilt2'),
                       Byte('lpfilt1'),
                       Byte('lpfilt0'),
                       Byte('vco_kvcal'),
                       )

def _display_synth_group(str, buf):
    return synth_group_s.parse(buf)

match_field_s = Struct('match_field_s',
                       Byte('value'),
                       Byte('mask'),
                       Byte('ctrl'),
                       )
match_group_s = Struct('match_group_s',
                       Array(4, match_field_s),
                       )

def _display_match_group(str, buf):
    return match_group_s.parse(buf)

freq_control_group_s = Struct('freq_control_group_s',
                        Byte('inte'),
                        BitStruct('frac',
                                 BitField('i',24),
                        ),
#                        Field('frac', 3),
                        UBInt16('channel_step_size'),
                        Byte('w_size'),
                        Byte('vcocnt_rx_adj'),
                        )

def _display_freq_control_group(str, buf):
    return freq_control_group_s.parse(buf)

rx_hop_group_s = Struct('rx_hop_group_s',
                        Byte('control'),
                        Byte('table_size'),
                        Field('table_entries', 64),
                        )

def _display_rx_hop_group(str, buf):
    return rx_hop_group_s.parse(buf)

def _status_part_info(cmd):
    request = read_cmd_s.parse('\x00' * read_cmd_s.sizeof())
    request.cmd='PART_INFO'
    return read_cmd_s.build(request)

def _status_default(cmd):
    request = read_cmd_s.parse('\x00' * read_cmd_s.sizeof())
    request.cmd=cmd
    return read_cmd_s.build(request)

def _status_ints(cmd):
    request = get_clear_int_cmd_s.parse('\x00' + ('\xff' * (int(get_clear_int_cmd_s.sizeof())-1)))
    request.cmd = 'GET_INT_STATUS'
    return read_cmd_s.build(request)

def _display_items(title, lst):
    """
    Radio Configuration Group Structure Display Routines
    """
    sx = ''
    for item in lst():
        if (item[1]): sx += ' {}'.format(item[0])
    if (sx): sx = ' {}: {}'.format(title, sx)
    return sx

def insert_space(st):
    """
    Convert byte array into string and insert space periodically to
    break up long string
    """
    p_ds = ''
    ix = 4
    i = 0
    p_s = binascii.hexlify(st)
    while (i < (len(st) * 2)):
        p_ds += p_s[i:i+ix] + ' '
        i += ix
    return p_ds

def _display_default(str, buf):
    """
    Radio Command and Response Structure Display Routines
    """
    try:
        s = str.parse(buf).__repr__()
    except:
        s = 'PARSE ERROR: {}  {}'.format(str.name, insert_space(buf))
    return s

radio_command_structs = {
    radio_cmd_ids.build('POWER_UP'): (power_up_cmd_s, None),
    radio_cmd_ids.build('SET_PROPERTY'): (set_property_cmd_s, None),
    radio_cmd_ids.build('GET_PROPERTY'): (get_property_cmd_s, get_property_rsp_s),
    radio_cmd_ids.build('PART_INFO'): (read_cmd_s, read_part_info_rsp_s),
    radio_cmd_ids.build('FUNC_INFO'): (read_cmd_s, read_func_info_rsp_s),
    radio_cmd_ids.build('GPIO_PIN_CFG'): (read_cmd_s, get_gpio_pin_cfg_rsp_s),
    radio_cmd_ids.build('FIFO_INFO'): (read_cmd_s, fifo_info_rsp_s),
    radio_cmd_ids.build('GET_INT_STATUS'): (read_cmd_s, int_status_rsp_s),
    radio_cmd_ids.build('REQUEST_DEVICE_STATE'): (None, None),
    radio_cmd_ids.build('READ_CMD_BUFF'): (None, None),
    radio_cmd_ids.build('FRR_A_READ'): (None, None),
    radio_cmd_ids.build('FRR_B_READ'): (None, None),
    radio_cmd_ids.build('FRR_C_READ'): (None, None),
    radio_cmd_ids.build('FRR_D_READ'): (None, None),
    radio_cmd_ids.build('PACKET_INFO'): (read_cmd_s, packet_info_rsp_s),
    radio_cmd_ids.build('GET_MODEM_STATUS'): (read_cmd_s, None),
    radio_cmd_ids.build('GET_ADC_READING'): (read_cmd_s, None),
    radio_cmd_ids.build('GET_PH_STATUS'): (read_cmd_s, None),
    radio_cmd_ids.build('GET_CHIP_STATUS'): (read_cmd_s, get_chip_status_rsp_s),
}

radio_group_structs = {
    radio_group_ids.build('GLOBAL'): global_group_s,
    radio_group_ids.build('INT_CTL'): int_ctl_group_s,
    radio_group_ids.build('FRR_CTL'): frr_ctl_group_s,
    radio_group_ids.build('PREAMBLE'): preamble_group_s,
    radio_group_ids.build('SYNC'): sync_group_s,
    radio_group_ids.build('PKT'): pkt_group_s,
    radio_group_ids.build('MODEM'): modem_group_s,
    radio_group_ids.build('MODEM_CHFLT'): modem_chflt_group_s,
    radio_group_ids.build('PA'): pa_group_s,
    radio_group_ids.build('SYNTH'): synth_group_s,
    radio_group_ids.build('MATCH'): match_group_s,
    radio_group_ids.build('FREQ_CTL'): freq_control_group_s,
    radio_group_ids.build('RX_HOP'): rx_hop_group_s
}

radio_display_funcs = {
    change_state_cmd_s    : _display_change_state_cmd,
    change_state_rsp_s    : _display_default,
    clr_pend_int_s        : _display_clr_pend_int,
    config_frr_cmd_s      : _display_default,
    fast_frr_rsp_s        : _display_fast_frr_rsp,
    fast_frr_s            : _display_fast_frr,
    fifo_info_cmd_s       : _display_default,
    fifo_info_rsp_s       : _display_default,
    freq_control_group_s  : _display_freq_control_group,
    frr_ctl_group_s       : _display_frr_ctl_group,
    get_chip_status_rsp_s : _display_get_chip_status_rsp,
    get_clear_int_cmd_s   : _display_get_clear_int_cmd,
    get_gpio_pin_cfg_rsp_s: _display_gpio_pin_cfg_rsp,
    get_property_cmd_s    : _display_default,
    get_property_rsp_s    : _display_default,
    gpio_cfg_s            : _display_default,
    global_group_s        : _display_global_group,
    int_ctl_group_s       : _display_int_ctl_group,
    int_status_rsp_s      : _display_int_status_rsp,
    match_group_s         : _display_match_group,
    modem_chflt_group_s   : _display_modem_chflt_group,
    modem_group_s         : _display_modem_group,
    nirq_cfg_s            : _display_default,
    pa_group_s            : _display_pa_group,
    packet_info_cmd_s     : _display_default,
    packet_info_rsp_s     : _display_default,
    pkt_group_s           : _display_pkt_group,
    preamble_group_s      : _display_preamble_group,
    power_up_cmd_s        : _display_default,
    read_cmd_buff_rsp_s   : _display_default,
    read_cmd_s            : _display_read_cmd,
    read_func_info_rsp_s  : _display_read_func_info_rsp,
    read_part_info_rsp_s  : _display_read_part_info_rsp,
    rx_hop_group_s        : _display_rx_hop_group,
    sdo_cfg_s             : _display_default,
    set_gpio_pin_cfg_cmd_s: _display_default,
    set_property_cmd_s    : _display_default,
    start_rx_cmd_s        : _display_default,
    start_tx_cmd_s        : _display_default,
    sync_group_s          : _display_sync_group,
    synth_group_s         : _display_synth_group,
}

radio_status_structs = {
    radio_cmd_ids.build('PART_INFO'): (_status_part_info, read_part_info_rsp_s),
    radio_cmd_ids.build('FUNC_INFO'): (_status_default, read_func_info_rsp_s),
    radio_cmd_ids.build('GPIO_PIN_CFG'): (_status_default, get_gpio_pin_cfg_rsp_s),
    radio_cmd_ids.build('FIFO_INFO'): (_status_default, fifo_info_rsp_s),
    radio_cmd_ids.build('GET_INT_STATUS'): (_status_ints, int_status_rsp_s),
    radio_cmd_ids.build('REQUEST_DEVICE_STATE'): (None, None),
    radio_cmd_ids.build('READ_CMD_BUFF'): (None, None),
    radio_cmd_ids.build('FRR_A_READ'): (None, None),
    radio_cmd_ids.build('FRR_B_READ'): (None, None),
    radio_cmd_ids.build('FRR_C_READ'): (None, None),
    radio_cmd_ids.build('FRR_D_READ'): (None, None),
    radio_cmd_ids.build('PACKET_INFO'): (_status_default, packet_info_rsp_s),
    radio_cmd_ids.build('GET_MODEM_STATUS'): (None, None),
    radio_cmd_ids.build('GET_ADC_READING'): (None, None),
    radio_cmd_ids.build('GET_PH_STATUS'): (None, None),
    radio_cmd_ids.build('GET_CHIP_STATUS'): (_status_default, get_chip_status_rsp_s),
}

class RadioTraceIds(object):
    RADIO_ERROR            = 0
    RADIO_CMD              = 1
    RADIO_RSP              = 2
    RADIO_GROUP            = 3
    RADIO_RX_FIFO          = 4
    RADIO_TX_FIFO          = 5
    RADIO_FRR              = 6
    RADIO_FSM              = 7
    RADIO_INT              = 8
    RADIO_DUMP             = 9
    RADIO_ACTION           = 10
    RADIO_IOC              = 11
    RADIO_CHIP             = 12
    RADIO_GPIO             = 13
    RADIO_INIT_ERROR       = 14
    RADIO_CMD_ERROR        = 15
    RADIO_CTS_ERROR        = 16
    RADIO_RSP_ERROR        = 17
    RADIO_RX_TOO_LONG      = 18
    RADIO_TX_TOO_LONG      = 19
    RADIO_FRR_TOO_LONG     = 20
    RADIO_PEND             = 21
    def by_value(self, v):
        for a,b in RadioTraceIds().__class__.__dict__.iteritems():
            if a.startswith('__'): continue
            if (b == v): return a
    def by_name(self, n):
        for a,b in RadioTraceIds().__class__.__dict__.iteritems():
            if a.startswith('__'): continue
            if (a == n): return b

radio_trace_ids = RadioTraceIds()


test_group_list = [('INT_CTL', '\x03\x3b\x2b\x00'),
                   ('GLOBAL', '\x52\x00\x18\x60\x00\x00\x01\x60\x00\x00'),
                   ('FRR_CTL', '\x00\x00\x00\x00'),
                   ('PREAMBLE', '\x08\x14\x00\x0f\x31\x00\x00\x00\x00\x00\x00\x00\x00\x00'),
                   ('PKT', '\x85\x01\x08\xff\xff\x00\x82\x00\x2a\x01\x00\x30\x30\x00\x01\x04\xa2\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x04\x82\x00\x81\x00\x0a\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'),
                   ('MODEM_CHFLT', '\xa2\x81\x26\xaf\x3f\xee\xc8\xc7\xdb\xf2\x02\x08\x07\x03\x15\xfc\x0f\x00\xa2\x81\x26\xaf\x3f\xee\xc8\xc7\xdb\xf2\x02\x08\x07\x03\x15\xfc\x0f\x00'),
                   ('MODEM','\x03\x00\x07\x06\x1a\x80\x05\xc9\xc3\x80\x00\x05\x76\x00\x00\x67\x60\x4d\x36\x21\x11\x08\x03\x01\x01\x80\x08\x03\x80\x00\x20\x20\x00\x00\x01\x77\x01\x5d\x86\x00\xaf\x02\xc2\x00\x04\x36\x80\x1d\x10\x04\x80\x00\x00\xe2\x00\x00\x11\x52\x52\x00\x1a\xff\xff\x00\x2a\x0c\xa4\x02\xd6\x83\x00\xad\x01\x80\x20\x0c\x25\x00\x40\x03\x00\x0a'),
                   ('SYNTH', '\x2c\x0e\x0b\x04\x0c\x73\x03\x05'),
                   ('PA','\x08\x7f\x00\x3d\x00\x23'),
                   ('RX_HOP', '\x04\x01\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f'),
                   ('MATCH', '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'),
]

test_cmd_list = []

test_rsp_list = []

def test_structs(lst):
    for p_n, data in lst:
        p_id = radio_group_ids.build(p_n)
        p_g = radio_groups[p_id]
        p_da = p_g.parse(data)
        p_di = p_g.build(p_da)
        pp = radio_display_structs[p_g](p_g, data)
        print(pp)


def si446xdef_test():
    assert(radio_trace_ids.by_name('RADIO_GPIO') == 13)
    assert(radio_trace_ids.by_value(13) == 'RADIO_GPIO')
    r = RadioTraceIds()
    assert(r.by_name('RADIO_FRR') == 6)
    assert(r.by_value(r.by_name('RADIO_FRR')))
    test_structs(test_group_list)
    test_structs(test_cmd_list)
    test_structs(test_rsp_list)
    return r


if __name__ == '__main__':
    r = si446xdef_test()
