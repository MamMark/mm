/*
 * Copyright (c) 2015, 2017 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Author: Eric B. Decker <cire831@gmail.com>
 * Author: Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 * Basic h/w chip definitions for the si446x radio chip.
 */

#ifndef __SI446X_H__
#define __SI446X_H__

/*
 * The API to the si446x chipset is defined by various interactive
 * html documentation.  These can be found at:
 *
 * http://www.silabs.com/Support%20Documents/TechnicalDocs/
 *               {PUBLIC_EZRadioPRO_REVB1B_API_ver_2.0.3.zip,
 *                PUBLIC_EZRadioPRO_REVC2A_A2A_API_ver_2.0.3.zip}
 *
 * I'm not sure how you tell which version of the API applies to what chip.
 * The si4468 only shows up in the REVC2A_A2A_API definitions.  So that
 * is what we are using.
 */

/*
 * Si446x Radio hardware and programming interface description:
 *
 * physical pins: NIRQ, IN_SLEEP(gpio0), CTS (gpio1), CSN (aka NSEL),
 *                SDN (shutdown)
 * SPI pins:      SCLK, MISO (SO), MOSI (SI).
 *
 * HplSi446xC provides the H/W Presentation which includes the SPI
 * to use and access routines for the above physical pins.  HplSi446xC
 * is provided by the platform.
 *
 * Chips supported are the si44631B and si44682A, denoted as <chip>.
 *
 * See README.MD in tos/platforms/<platform>/hardware/si446x for details
 * on radio configuration. Briefly, there are three parts to the radio
 * configuration:
 *  -  WDS generated, configuration from TI WDS program
 *  -  Platform specific, configuration unique to the platform
 *  -  Driver specific, configuration unique to the driver
 *
 * All three configurations are provided by RadioConfig.h file in
 * tos/platforms/<platform>/hardware/si446x.
 *
 *
 * Power States:
 *
 * h/w state    registers       transition      power
 *              preserved       to TX/RX        consumption
 *
 * Shutdown     n               15ms            30nA
 * Standby      y               440us           40nA
 * Sleep        y               440us           740nA
 * SPI Active   y               340us           1.35mA
 * Ready        y               100us           1.8mA
 * TX Tune      y               58us  -> TX     7.8mA
 * RX Tune      y               60us  -> RX     7.6mA
 * TX State     y               100uS -> RX     18mA @ +10dBm
 * RX State     y               100uS -> TX     10.9 or 13.7 mA
 *
 * This is a low power implementation.  We trade off a factor of 4 time
 * cost for 2 orders of magnitude power savings.  We want to spend
 * most of our time in Standby at 40 nA which costs 440uS to go into
 * a TX or RX state.
 *
 * When the radio chip is powered on, the following steps are taken:
 *
 * 1) Take chip out of shutdown, SDN = 0.
 *    (SDN 1 must be held for 10uS for proper shutdown, not a problem)
 *
 *    POR takes 6ms.  CTS (gp1 will go 1 at end of POR)
 *
 * 2) send POWER_UP command.
 *    POWER_UP takes something like 15ms.  We've measured it around 15.8ms
 *    and the timeout is set to 16.5ms.
 * 3) program h/w state.
 * 4) Chip goes to Standby state.
 * 5) Start initial RX.
 * 6) signal Turn_On complete and hang in STATE_RX.
 *
 * This puts the driver into RX s/w state (match h/w rx state).
 *
 * When we talk to the chip via SPI, the chip automatically transitions
 * to SPI Active state.  After talking to the chip, we must take care
 * to transition the chip back to Standby to take advantage of the low
 * current consumption.
 *
 *
 * Basic Packet operations
 *
 * The radio chip can actively be doing only one thing at a time, either
 * transmitting or receiving.  It is not Hear-Self.
 *
 * Packet Format:
 *
 * We don't do 802.15.4, rather we do a simple custom packet format:
 *
 *    len   proto   nm_l   data    FCS
 *     1      2      1      n       2
 *
 *    len is set to n+5.  On transmit, the control block says to send
 *    n+6.  The FCS covers proto through the end of data but does not
 *    include length (len).
 *
 *    If longer packets than 256 bytes are needed, then len can be increased
 *    to 2 bytes by configuration changes.
 *
 * CRC:  CRC is controlled by various cells.
 *
 *   (1200) PKT_CRC_CONFIG seed and which Polynominal
 *   (1210) PKT_FIELD_1_CRC_CONFIG determine how CRC is handled for the fields
 *   (1214) PKT_FIELD_2_CRC_CONFIG
 *   (1234) PKT_RX_FIELD_5_CRC_CONFIG
 *          etc.
 *   CRC_START, CRC_SEND, CHECK_CRC, CRC_ENABLE per field.
 *
 *   On TX, if Len specified in START_TX control block, then F1 controls CRC
 *   If Len 0 (RX and TX) then fields are controlled by Field specs
 *
 * Split FIFO.    64/64 bytes.    controlled by (0003) GLOBAL_CONFIG:FIFO_MODE
 * Unified FIFO.  129 bytes.      alternative mode, not used in this driver
 *
 * TX:
 *
 * 1) Fields.  Only one field is used for TX.  The START_TX control
 *    block explicitly includes the packet size to transmit.  F1
 *    controls what happens on TX when the control block has a non-zero
 *    size.  (1206) PKT_CONFIG1:PH_FIELD_SPLIT (1).
 *
 *    (120D) PKT_FIELD_1 (tx_field), (len) 0001
 *    (120f) PKT_FIELD_1_CONFIG: 04, PN_START
 *    (1210) PKT_FIELD_1_CRC_CONFIG: a2 START | SEND | ENABLE
 *    (1211) PKT_FIELD_2_LEN: 0x0000  (turn off others)
 *
 * 2) Single packet transmit only.  No pipeline support
 *    (another packet is not sent until the first has been signalled
 *    complete).   Only one packet may be in the TxFifo at a time.  If
 *    another TX attempt is made while a transmit is still active, it is
 *    rejected with EBUSY.
 *
 * 3) Typically, tx packets are ack'd and reception of the ack (rx cycle)
 *    must complete before the next packet gets transmitted.  This is
 *    because the ACK is part of the Channel assignment.   ACK's don't
 *    do CCA but assume the channel is available.  The timing budget for
 *    the transmitted packet is supposed to include the time it takes for
 *    the ACK as well.  This sequencing is handled by the upper layers (not
 *    the driver).
 *
 * 4) A START_TX is done.
 *
 * 5) CCA, Clear Channel Assessment.
 *    (204a) MODEM_RSSI_THRESH: is used to set the RSSI threshold.  Above this
 *    value indicates channel is busy.
 *
 *    MODEM_RSSI_CONTROL
 *
 *    GPIO pin (value 27/37).  37 isn't usable because it gets cleared when SYNC
 *    has been detected.  27 causes the pin to be a real time comparison between
 *    CR (current RSSI) and MRT (Modem_RSSI_Thres (p104a).
 *
 *    Latched_RSSI may be compared against this threshold and if below the chip
 *    proceeds to the specified START_RX:NEXT_STATE1:RXTIMEOUT_STATE and generates
 *    a PREAMBLE_INVALID interrupt.  What does this have to do with CCA?  Well,
 *    the latched value if > MRT will indicate we are currently receiving a packet
 *    (maybe for us, maybe not), but regardless the "wire" is busy.
 *
 * 6) It is possible that the transmission is deferred because the channel
 *    is busy.   See above.
 *
 * 7) Deferred TX packets may be tried again by the upper layer.  A deferred
 *    packet is indicated by an EBUSY return.
 *
 * 8) Timestamping.
 *    GPIO0 can be set to SYNC_WORD_DETECT but only works for RX.
 *    We don't do it.  TimeSync needs timing for TX packets and time stamping RX packets
 *    isn't that useful.
 *
 *
 * RX:
 *
 * 1) Receives start when a START_RX is commanded via control block.
 *
 * 2) One packet can be received at a time.  After the data is in the FIFO (or
 *    moves through the FIFO, the chip transitions to RX (but not armed).  That
 *    avoids another RX_TUNE cycle.  Another packet won't be looked for until
 *    another START_RX is done.
 *
 * 3) Fields.  START_RX is called with a length of 0 so all processing is via
 *    the PKT_RX_FIELDs.  Field_1 is set to len 0001 CRC_START, CRC_ENABLE.
 *    Field_2 is set to len 128 (max length), CHECK_CRC, CRC_ENABLE.
 *
 *
 */


/*
 * Units used with RadioAlarm need to be TRadio, which in our case is T32khz.
 *
 * When the chip is brought out of Shutdown (SDN = 1 = > 0), it takes max
 * of 6ms before it can accept commands.  One should also check the value
 * of CTS to make sure the chip is indeed ready to accept commands.
 *
 * Pieces of documentation say max is 5ms for the POR but the si4468 data
 * sheet says 6ms.  We use that instead.  We have observed actual time for
 * POR is 985 us.
 *
 * units are T32khz.   7ms = n/32768 ==> n = 230
 */
#define SI446X_POR_WAIT_TIME    230

/*
 * After turning the chip on, one must issue the POWER_UP command to complete
 * the actual turn on (seems like a strange way to do this).  According to
 * AN633 (Si446x Programming Guide and Sample Codes) this can take
 * approximately 14ms to complete.  We give it 16.5ms.  We've observed that it
 * at least 15.8 but can take some what longer.  16.5 should be long enough.
 * If it isn't, we panic.
 *
 * It is unclear from AN633 whether the 15ms is actually the POR time (5ms)
 * and 6..10ms for the POWER_UP.  We've observed 15-16 ms.  Units are T32khz
 *
 * 16.5ms * 32.768 = 540
 */
#define SI446X_POWER_UP_WAIT_TIME       541

/*
 * max time we look for CTS to come back from command (us). The max we've
 * observed is 95uS.  Power_Up however takes 15ms so we don't use this
 * timeout with that command.
 *
 * maximum time to wait for a tx/rx command to complete. failsafe timer.
 *
 * units are usecs, used with Platform.usecsRaw()
 */
#define SI446X_CTS_TIMEOUT                  10000

/*
 * maximum times to wait for transmit and receive operations to complete
 * (protect against false starts)
 * TX_TIMEOUT = time to wait for packet transmission to complete
 * RX_TIMEOUT = time to wait for packet reception to complete
 *
 * Units T32khz.  100ms * 32.768 = 3277
 */
#define SI446X_TX_TIMEOUT                   32768
#define SI446X_RX_TIMEOUT                   32768

/*
 * initial RSSI_THRESH (threshold) for rssi comparisons.  Stuffed into
 * MODEM_RSSI_THRESH (p204a).  RSSIs below this value will cause an
 * incoming packet to not be received (probably not a packet or signal
 * strength too low.
 */
#define SI446X_INITIAL_RSSI_THRESH      0x20

/*
 * size of TX fifo when empty
 */
#define SI446X_EMPTY_TX_LEN             129

/*
 * Si446x Radio command identifiers
 */
#define SI446X_CMD_NOP                        0x00
#define SI446X_CMD_PART_INFO                  0x01
#define SI446X_CMD_POWER_UP                   0x02
#define SI446X_CMD_PATCH_IMAGE                0x04
#define SI446X_CMD_FUNC_INFO                  0x10
#define SI446X_CMD_SET_PROPERTY               0x11
#define SI446X_CMD_GET_PROPERTY               0x12
#define SI446X_CMD_GPIO_PIN_CFG               0x13
#define SI446X_CMD_GET_ADC_READING            0x14
#define SI446X_CMD_FIFO_INFO                  0x15
#define SI446X_CMD_PACKET_INFO                0x16
#define SI446X_CMD_IRCAL                      0x17
#define SI446X_CMD_PROTOCOL_CFG               0x18
#define SI446X_CMD_GET_INT_STATUS             0x20
#define SI446X_CMD_GET_PH_STATUS              0x21
#define SI446X_CMD_GET_MODEM_STATUS           0x22
#define SI446X_CMD_GET_CHIP_STATUS            0x23
#define SI446X_CMD_START_TX                   0x31
#define SI446X_CMD_START_RX                   0x32
#define SI446X_CMD_REQUEST_DEVICE_STATE       0x33
#define SI446X_CMD_CHANGE_STATE               0x34
#define SI446X_CMD_RX_HOP                     0x36
#define SI446X_CMD_READ_CMD_BUFF              0x44
#define SI446X_CMD_FRR_A                      0x50
#define SI446X_CMD_FRR_B                      0x51
#define SI446X_CMD_FRR_C                      0x53
#define SI446X_CMD_FRR_D                      0x57

/*
 * FRRs configured for fast access, make it simple to access using si446x_read_frr()
 * this is a driver dependent configuration.
 */
#define SI446X_GET_DEVICE_STATE               0x50    /* device state */
#define SI446X_GET_PH_PEND                    0x51    /* packet_handler pending */
#define SI446X_GET_MODEM_PEND                 0x53    /* modem pending */
#define SI446X_GET_LATCHED_RSSI               0x57    /* latched rssi */

#define SI446X_CMD_TX_FIFO_WRITE              0x66
#define SI446X_CMD_RX_FIFO_READ               0x77

//#define SI446X_CMD_PART_INFO                  0x01
#define SI446X_PART_INFO_REPLY_SIZE           8

//#define SI446X_CMD_POWER_UP                   0x02
#define SI446X_PU_EZRADIO_PRO                 0x01

//#define SI446X_CMD_FUNC_INFO                  0x10
#define SI446X_FUNC_INFO_REPLY_SIZE           6

//#define SI446X_CMD_GPIO_PIN_CFG               0x13
#define SI446X_GPIO_CFG_REPLY_SIZE            7

#define SI446X_GPIO_NO_CHANGE                   0
#define SI446X_GPIO_DISABLED                    1
#define SI446X_GPIO_LOW                         2
#define SI446X_GPIO_HIGH                        3
#define SI446X_GPIO_INPUT                       4
#define SI446X_GPIO_32_KHZ_CLOCK                5
#define SI446X_GPIO_BOOT_CLOCK                  6
#define SI446X_GPIO_DIVIDED_MCU_CLOCK           7
#define SI446X_GPIO_CTS                         8
#define SI446X_GPIO_INV_CTS                     9
#define SI446X_GPIO_HIGH_ON_CMD_OVERLAP         10
#define SI446X_GPIO_SPI_DATA_OUT                11
#define SI446X_GPIO_HIGH_AFTER_RESET            12
#define SI446X_GPIO_HIGH_AFTER_CALIBRATION      13
#define SI446X_GPIO_HIGH_AFTER_WUT              14
#define SI446X_GPIO_UNUSED_0                    15
#define SI446X_GPIO_TX_DATA_CLOCK               16
#define SI446X_GPIO_RX_DATA_CLOCK               17
#define SI446X_GPIO_UNUSED_1                    18
#define SI446X_GPIO_TX_DATA                     19
#define SI446X_GPIO_RX_DATA                     20
#define SI446X_GPIO_RX_RAW_DATA                 21
#define SI446X_GPIO_ANTENNA_1_SWITCH            22
#define SI446X_GPIO_ANTENNA_2_SWITCH            23
#define SI446X_GPIO_VALID_PREAMBLE              24
#define SI446X_GPIO_INVALID_PREAMBLE            25
#define SI446X_GPIO_SYNC_DETECTED               26
#define SI446X_GPIO_RSSI_ABOVE_CAT              27
#define SI446X_GPIO_IN_SLEEP                    28
#define SI446X_GPIO_TX_STATE                    32
#define SI446X_GPIO_RX_STATE                    33
#define SI446X_GPIO_RX_FIFO_ALMOST_FULL         34
#define SI446X_GPIO_TX_FIFO_ALMOST_EMPTY        35
#define SI446X_GPIO_BATT_LOW                    36
#define SI446X_GPIO_RSSI_ABOVE_CAT_LOW          37
#define SI446X_GPIO_HOP                         38
#define SI446X_GPIO_HOP_TABLE_WRAPPED           39

//#define SI446X_CMD_FIFO_INFO                  0x15
#define SI446X_FIFO_INFO_REPLY_SIZE           2
#define SI446X_FIFO_FLUSH_RX                  0x2
#define SI446X_FIFO_FLUSH_TX                  0x1

//#define SI446X_CMD_PACKET_INFO                0x16
#define SI446X_PACKET_INFO_REPLY_SIZE         2

/* Warning: 4463 int_status is 8 bytes long, 4468 is 9.  Currently
   we only use 8 bytes and ignore the 9th byte (INFO_FLAGS)
*/
//#define SI446X_CMD_GET_INT_STATUS             0x20
#define SI446X_INT_STATUS_REPLY_SIZE          8

/*
 * Warning: sending no parameters with GET_INT_STATUS will clear all interrupts.
 * Reply stream returned is status of interrupts prior to any clearing that
 * might be requested.  ie. previous interrupt state.
 */
#define SI446X_INT_NO_CLEAR                   0xff

/* interrupt enable (p0100)
 * enable selected interrupts
 */
// Interest bits set to one will enable interrupt
#define SI446X_PH_INTEREST             (SI446X_PH_STATUS_PACKET_SENT | \
                                        SI446X_PH_STATUS_PACKET_RX | \
                                        SI446X_PH_STATUS_CRC_ERROR | \
                                        SI446X_PH_STATUS_TX_FIFO_ALMOST_EMPTY | \
                                        SI446X_PH_STATUS_RX_FIFO_ALMOST_FULL)

#define SI446X_MODEM_INTEREST          (SI446X_MODEM_STATUS_INVALID_SYNC | \
                                        SI446X_MODEM_STATUS_PREAMBLE_DETECT | \
                                        SI446X_MODEM_STATUS_SYNC_DETECT)

#define SI446X_CHIP_INTEREST           (SI446X_CHIP_STATUS_FIFO_UNDER_OVER_ERROR | \
                                        SI446X_CHIP_STATUS_CMD_ERROR)

#define SI446X_PH_RX_CLEAR_MASK        (SI446X_PH_STATUS_FILTER_MATCH | \
                                        SI446X_PH_STATUS_FILTER_MISS | \
                                        SI446X_PH_STATUS_PACKET_RX | \
                                        SI446X_PH_STATUS_CRC_ERROR | \
                                        SI446X_PH_STATUS_RX_FIFO_ALMOST_FULL)

#define SI446X_MODEM_RX_CLEAR_MASK     (SI446X_MODEM_STATUS_POSTAMBLE_DETECT | \
                                        SI446X_MODEM_STATUS_INVALID_SYNC | \
                                        SI446X_MODEM_STATUS_RSSI_JUMP | \
                                        SI446X_MODEM_STATUS_RSSI | \
                                        SI446X_MODEM_STATUS_INVALID_PREAMBLE | \
                                        SI446X_MODEM_STATUS_PREAMBLE_DETECT | \
                                        SI446X_MODEM_STATUS_SYNC_DETECT)

#define SI446X_CHIP_RX_CLEAR_MASK       (SI446X_CHIP_STATUS_FIFO_UNDER_OVER_ERROR | \
                                         SI446X_CHIP_STATUS_STATE_CHANGE | \
                                         SI446X_CHIP_STATUS_CMD_ERROR)

//#define SI446X_CMD_GET_PH_STATUS              0x21
#define SI446X_PH_STATUS_REPLY_SIZE           2

//#define SI446X_CMD_GET_MODEM_STATUS           0x22
#define SI446X_MODEM_STATUS_REPLY_SIZE        8

//#define SI446X_CMD_GET_CHIP_STATUS            0x23
#define SI446X_CHIP_STATUS_REPLY_SIZE         4

//#define SI446X_CMD_START_TX                   0x31
#define SI446X_CONDITION_TX_COMPLETE_STATE      0xf0
#define SI446X_CONDITION_RETRANSMIT_NO          0x00
#define SI446X_CONDITION_RETRANSMIT_YES         0x04
#define SI446X_CONDITION_START_IMMEDIATE        0x00
#define SI446X_CONDITION_START_AFTER_WUT        0x01

//#define SI446X_CMD_START_RX                   0x32
#define SI446X_CONDITION_RX_START_IMMEDIATE     0x00

//#define SI446X_CMD_REQUEST_DEVICE_STATE       0x33
#define SI446X_DEVICE_STATE_REPLY_SIZE          2

typedef enum {
        _NO_STATE   = 0,
        _SLEEP___   = 1,
        _SPI_ACT_   = 2,
        _READY___   = 3,
        _READYA__   = 4,
        _TX_TUNE_   = 5,
        _RX_TUNE_   = 6,
        _TRANSMIT   = 7,
        _RECEIVE_   = 8,
} si446x_idevice_state_t;

typedef enum {
        RC_NO_CHANGE  = 0,
        RC_NO_STATE   = 0,
        RC_SLEEP      = 1,
        RC_SPI_ACT    = 2,
        RC_READY      = 3,
        RC_READYA     = 4,
        RC_TX_TUNE    = 5,
        RC_RX_TUNE    = 6,
        RC_TRANSMIT   = 7,
        RC_RECEIVE    = 8,
        RC_IDLE       = 9, // used by Preamble Sense Mode
} si446x_device_state_t;

//#define SI446X_CMD_READ_BUFF                  0x44
#define SI446X_REPLY_CTS                      0xff

//#define SI446X_CMD_FRR_A                      0x50
#define SI446X_FRR_A                          0x50
#define SI446X_FRR_B                          0x51
#define SI446X_FRR_C                          0x53
#define SI446X_FRR_D                          0x57

// logical definition of register values within an array
typedef enum {
  DEVICE_STATE=0,
  PH_STATUS=1,
  MODEM_STATUS=2,
  LATCHED_RSSI=3,
} frr_map_t;

/*
 * Properties.
 */
#define SI446X_PROP_GLOBAL_XO_TUNE                   0x0000
#define SI446X_PROP_GLOBAL_CLK_CFG                   0x0001
#define SI446X_PROP_GLOBAL_LOW_BATT_THRESH           0x0002
#define SI446X_PROP_GLOBAL_CONFIG                    0x0003
#define SI446X_PROP_GLOBAL_WUT_CONFIG                0x0004
#define SI446X_PROP_GLOBAL_WUT_M_15_8                0x0005
#define SI446X_PROP_GLOBAL_WUT_M_7_0                 0x0006
#define SI446X_PROP_GLOBAL_WUT_R                     0x0007
#define SI446X_PROP_GLOBAL_WUT_LDC                   0x0008
#define SI446X_PROP_GLOBAL_WUT_CAL                   0x0009
#define SI446X_PROP_GLOBAL_BUFCLK_CFG                0x000a

#define SI446X_PROP_INT_CTL_ENABLE                   0x0100
#define SI446X_PROP_INT_CTL_PH_ENABLE                0x0101
#define SI446X_PROP_INT_CTL_MODEM_ENABLE             0x0102
#define SI446X_PROP_INT_CTL_CHIP_ENABLE              0x0103

#define SI446X_PROP_FRR_CTL_A_MODE                   0x0200
#define SI446X_PROP_FRR_CTL_B_MODE                   0x0201
#define SI446X_PROP_FRR_CTL_C_MODE                   0x0202
#define SI446X_PROP_FRR_CTL_D_MODE                   0x0203

#define SI446X_PROP_PREAMBLE_TX_LENGTH               0x1000
#define SI446X_PROP_PREAMBLE_CONFIG_STD_1            0x1001
#define SI446X_PROP_PREAMBLE_CONFIG_NSTD             0x1002
#define SI446X_PROP_PREAMBLE_CONFIG_STD_2            0x1003
#define SI446X_PROP_PREAMBLE_CONFIG                  0x1004
#define SI446X_PROP_PREAMBLE_PATTERN_31_24           0x1005
#define SI446X_PROP_PREAMBLE_PATTERN_23_16           0x1006
#define SI446X_PROP_PREAMBLE_PATTERN_15_8            0x1007
#define SI446X_PROP_PREAMBLE_PATTERN_7_0             0x1008
#define SI446X_PROP_PREAMBLE_POSTAMBLE_CONFIG        0x1009
#define SI446X_PROP_PREAMBLE_POSTAMBLE_PATTERN_A     0x100a
#define SI446X_PROP_PREAMBLE_POSTAMBLE_PATTERN_B     0x100b
#define SI446X_PROP_PREAMBLE_POSTAMBLE_PATTERN_C     0x100c
#define SI446X_PROP_PREAMBLE_POSTAMBLE_PATTERN_D     0x100d

#define SI446X_PROP_SYNC_CONFIG                      0x1100
#define SI446X_PROP_SYNC_BITS_31_24                  0x1101
#define SI446X_PROP_SYNC_BITS_23_16                  0x1102
#define SI446X_PROP_SYNC_BITS_15_8                   0x1103
#define SI446X_PROP_SYNC_BITS_7_0                    0x1104
#define SI446X_PROP_SYNC_CONFIG2                     0x1105
#define SI446X_PROP_SYNC_BITS2_31_24                 0x1106
#define SI446X_PROP_SYNC_BITS2_23_16                 0x1107
#define SI446X_PROP_SYNC_BITS2_15_8                  0x1108
#define SI446X_PROP_SYNC_BITS2_7_0                   0x1109

#define SI446X_PROP_PKT_CRC_CONFIG                   0x1200
#define SI446X_PROP_PKT_WHT_POLY_15                  0x1201
#define SI446X_PROP_PKT_WHT_POLY_7                   0x1202
#define SI446X_PROP_PKT_WHT_SEED_15                  0x1203
#define SI446X_PROP_PKT_WHT_SEED_7                   0x1204
#define SI446X_PROP_PKT_WHT_BIT_NUM                  0x1205
#define SI446X_PROP_PKT_CONFIG1                      0x1206
#define SI446X_PROP_PKT_CONFIG2                      0x1207
#define SI446X_PROP_PKT_LEN                          0x1208
#define SI446X_PROP_PKT_LEN_FIELD_SOURCE             0x1209
#define SI446X_PROP_PKT_LEN_ADJUST                   0x120a

#define SI446X_PROP_PKT_TX_THRESHOLD                 0x120b
#define SI446X_PROP_PKT_RX_THRESHOLD                 0x120c

#define SI446X_PROP_PKT_FIELD_1_LENGTH               0x120d
#define SI446X_PROP_PKT_FIELD_1_LENGTH_12_8          0x120d
#define SI446X_PROP_PKT_FIELD_1_LENGTH_7_0           0x120e
#define SI446X_PROP_PKT_FIELD_1_CONFIG               0x120f
#define SI446X_PROP_PKT_FIELD_1_CRC_CONFIG           0x1210

#define SI446X_PROP_PKT_FIELD_2_LENGTH               0x1211
#define SI446X_PROP_PKT_FIELD_2_LENGTH_12_8          0x1211
#define SI446X_PROP_PKT_FIELD_2_LENGTH_7_0           0x1212
#define SI446X_PROP_PKT_FIELD_2_CONFIG               0x1213
#define SI446X_PROP_PKT_FIELD_2_CRC_CONFIG           0x1214

#define SI446X_PROP_PKT_FIELD_3_LENGTH               0x120d
#define SI446X_PROP_PKT_FIELD_3_LENGTH_12_8          0x1215
#define SI446X_PROP_PKT_FIELD_3_LENGTH_7_0           0x1216
#define SI446X_PROP_PKT_FIELD_3_CONFIG               0x1217
#define SI446X_PROP_PKT_FIELD_3_CRC_CONFIG           0x1218

#define SI446X_PROP_PKT_FIELD_4_LENGTH               0x120d
#define SI446X_PROP_PKT_FIELD_4_LENGTH_12_8          0x1219
#define SI446X_PROP_PKT_FIELD_4_LENGTH_7_0           0x121a
#define SI446X_PROP_PKT_FIELD_4_CONFIG               0x121b
#define SI446X_PROP_PKT_FIELD_4_CRC_CONFIG           0x121c

#define SI446X_PROP_PKT_FIELD_5_LENGTH               0x120d
#define SI446X_PROP_PKT_FIELD_5_LENGTH_12_8          0x121d
#define SI446X_PROP_PKT_FIELD_5_LENGTH_7_0           0x121e
#define SI446X_PROP_PKT_FIELD_5_CONFIG               0x121f
#define SI446X_PROP_PKT_FIELD_5_CRC_CONFIG           0x1220

#define SI446X_PROP_PKT_RX_FIELD_1_LENGTH_12_8       0x1221
#define SI446X_PROP_PKT_RX_FIELD_1_LENGTH_7_0        0x1222
#define SI446X_PROP_PKT_RX_FIELD_1_CONFIG            0x1223
#define SI446X_PROP_PKT_RX_FIELD_1_CRC_CONFIG        0x1224
#define SI446X_PROP_PKT_RX_FIELD_2_LENGTH_12_8       0x1225
#define SI446X_PROP_PKT_RX_FIELD_2_LENGTH_7_0        0x1226
#define SI446X_PROP_PKT_RX_FIELD_2_CONFIG            0x1227
#define SI446X_PROP_PKT_RX_FIELD_2_CRC_CONFIG        0x1228
#define SI446X_PROP_PKT_RX_FIELD_3_LENGTH_12_8       0x1229
#define SI446X_PROP_PKT_RX_FIELD_3_LENGTH_7_0        0x122a
#define SI446X_PROP_PKT_RX_FIELD_3_CONFIG            0x122b
#define SI446X_PROP_PKT_RX_FIELD_3_CRC_CONFIG        0x122c
#define SI446X_PROP_PKT_RX_FIELD_4_LENGTH_12_8       0x122d
#define SI446X_PROP_PKT_RX_FIELD_4_LENGTH_7_0        0x122e
#define SI446X_PROP_PKT_RX_FIELD_4_CONFIG            0x122f
#define SI446X_PROP_PKT_RX_FIELD_4_CRC_CONFIG        0x1230
#define SI446X_PROP_PKT_RX_FIELD_5_LENGTH_12_8       0x1231
#define SI446X_PROP_PKT_RX_FIELD_5_LENGTH_7_0        0x1232
#define SI446X_PROP_PKT_RX_FIELD_5_CONFIG            0x1233
#define SI446X_PROP_PKT_RX_FIELD_5_CRC_CONFIG        0x1234
#define SI446X_PROP_PKT_CRC_SEED_3                   0x1236
#define SI446X_PROP_PKT_CRC_SEED_2                   0x1237
#define SI446X_PROP_PKT_CRC_SEED_1                   0x1238
#define SI446X_PROP_PKT_CRC_SEED_0                   0x1239

#define SI446X_PROP_MODEM_MOD_TYPE                   0x2000
#define SI446X_PROP_MODEM_MAP_CONTROL                0x2001
#define SI446X_PROP_MODEM_DSM_CTRL                   0x2002
#define SI446X_PROP_MODEM_DATA_RATE_2                0x2003
#define SI446X_PROP_MODEM_DATA_RATE_1                0x2004
#define SI446X_PROP_MODEM_DATA_RATE_0                0x2005
#define SI446X_PROP_MODEM_TX_NCO_MODE_3              0x2006
#define SI446X_PROP_MODEM_TX_NCO_MODE_2              0x2007
#define SI446X_PROP_MODEM_TX_NCO_MODE_1              0x2008
#define SI446X_PROP_MODEM_TX_NCO_MODE_0              0x2009
#define SI446X_PROP_MODEM_FREQ_DEV_2                 0x200a
#define SI446X_PROP_MODEM_FREQ_DEV_1                 0x200b
#define SI446X_PROP_MODEM_FREQ_DEV_0                 0x200c
#define SI446X_PROP_MODEM_FREQ_OFFSET_1              0x200d
#define SI446X_PROP_MODEM_FREQ_OFFSET_0              0x200e
#define SI446X_PROP_MODEM_TX_FILTER_COEFF            0x200f
#define SI446X_PROP_MODEM_TX_RAMP_DELAY              0x2018
#define SI446X_PROP_MODEM_MDM_CTRL                   0x2019
#define SI446X_PROP_MODEM_IF_CONTROL                 0x201a
#define SI446X_PROP_MODEM_IF_FREQ_2                  0x201b
#define SI446X_PROP_MODEM_IF_FREQ_1                  0x201c
#define SI446X_PROP_MODEM_IF_FREQ_0                  0x201d
#define SI446X_PROP_MODEM_DECIMATION_CFG1            0x201e
#define SI446X_PROP_MODEM_DECIMATION_CFG0            0x201f
#define SI446X_PROP_MODEM_DECIMATION_CFG2            0x2020
#define SI446X_PROP_MODEM_IFPKD_THRESHOLDS           0x2021
#define SI446X_PROP_MODEM_BCR_OSR_1                  0x2022
#define SI446X_PROP_MODEM_BCR_OSR_0                  0x2023
#define SI446X_PROP_MODEM_BCR_NCO_OFFSET_2           0x2024
#define SI446X_PROP_MODEM_BCR_NCO_OFFSET_1           0x2025
#define SI446X_PROP_MODEM_BCR_NCO_OFFSET_0           0x2026
#define SI446X_PROP_MODEM_BCR_GAIN_1                 0x2027
#define SI446X_PROP_MODEM_BCR_GAIN_0                 0x2028
#define SI446X_PROP_MODEM_BCR_GEAR                   0x2029
#define SI446X_PROP_MODEM_BCR_MISC1                  0x202a
#define SI446X_PROP_MODEM_AFC_GEAR                   0x202c
#define SI446X_PROP_MODEM_AFC_WAIT                   0x202d
#define SI446X_PROP_MODEM_AFC_GAIN_1                 0x202e
#define SI446X_PROP_MODEM_AFC_GAIN_0                 0x202f
#define SI446X_PROP_MODEM_AFC_LIMITER_1              0x2030
#define SI446X_PROP_MODEM_AFC_LIMITER_0              0x2031
#define SI446X_PROP_MODEM_AFC_MISC                   0x2032
#define SI446X_PROP_MODEM_AFC_ZIFOFF                 0x2033
#define SI446X_PROP_MODEM_AFC_CTRL                   0x2034
#define SI446X_PROP_MODEM_AGC_CONTROL                0x2035
#define SI446X_PROP_MODEM_AGC_WINDOW_SIZE            0x2038
#define SI446X_PROP_MODEM_AGC_RFPD_DECAY             0x2039
#define SI446X_PROP_MODEM_AGC_IFPD_DECAY             0x203a
#define SI446X_PROP_MODEM_FSK4_GAIN1                 0x203b
#define SI446X_PROP_MODEM_FSK4_GAIN0                 0x203c
#define SI446X_PROP_MODEM_FSK4_TH1                   0x203d
#define SI446X_PROP_MODEM_FSK4_TH0                   0x203e
#define SI446X_PROP_MODEM_FSK4_MAP                   0x203f
#define SI446X_PROP_MODEM_OOK_PDTC                   0x2040
#define SI446X_PROP_MODEM_OOK_BLOPK                  0x2041
#define SI446X_PROP_MODEM_OOK_CNT1                   0x2042
#define SI446X_PROP_MODEM_OOK_MISC                   0x2043
#define SI446X_PROP_MODEM_RAW_SEARCH                 0x2044
#define SI446X_PROP_MODEM_RAW_CONTROL                0x2045
#define SI446X_PROP_MODEM_RAW_EYE_1                  0x2046
#define SI446X_PROP_MODEM_RAW_EYE_0                  0x2047
#define SI446X_PROP_MODEM_ANT_DIV_MODE               0x2048
#define SI446X_PROP_MODEM_ANT_DIV_CONTROL            0x2049
#define SI446X_PROP_MODEM_RSSI_THRESH                0x204a
#define SI446X_PROP_MODEM_RSSI_JUMP_THRESH           0x204b
#define SI446X_PROP_MODEM_RSSI_CONTROL               0x204c
#define SI446X_PROP_MODEM_RSSI_CONTROL2              0x204d
#define SI446X_PROP_MODEM_RSSI_COMP                  0x204e
#define SI446X_PROP_MODEM_RAW_SEARCH2                0x2050
#define SI446X_PROP_MODEM_CLKGEN_BAND                0x2051
#define SI446X_PROP_MODEM_SPIKE_DET                  0x2054
#define SI446X_PROP_MODEM_ONE_SHOT_AFC               0x2055
#define SI446X_PROP_MODEM_RSSI_HYSTERESIS            0x2056
#define SI446X_PROP_MODEM_RSSI_MUTE                  0x2057
#define SI446X_PROP_MODEM_FAST_RSSI_DELAY            0x2058
#define SI446X_PROP_MODEM_PSM                        0x2059
#define SI446X_PROP_MODEM_DSA_CTRL1                  0x205b
#define SI446X_PROP_MODEM_DSA_CTRL2                  0x205c
#define SI446X_PROP_MODEM_DSA_QUAL                   0x205d
#define SI446X_PROP_MODEM_DSA_RSSI                   0x205e
#define SI446X_PROP_MODEM_DSA_MISC                   0x205f

#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE13_7_0  0x2100
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE12_7_0  0x2101
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE11_7_0  0x2102
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE10_7_0  0x2103
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE9_7_0   0x2104
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE8_7_0   0x2105
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE7_7_0   0x2106
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE6_7_0   0x2107
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE5_7_0   0x2108
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE4_7_0   0x2109
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE3_7_0   0x210a
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE2_7_0   0x210b
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE1_7_0   0x210c
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COE0_7_0   0x210d
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COEM0      0x210e
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COEM1      0x210f
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COEM2      0x2110
#define SI446X_PROP_MODEM_CHFLT_RX1_CHFLT_COEM3      0x2111
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE13_7_0  0x2112
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE12_7_0  0x2113
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE11_7_0  0x2114
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE10_7_0  0x2115
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE9_7_0   0x2116
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE8_7_0   0x2117
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE7_7_0   0x2118
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE6_7_0   0x2119
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE5_7_0   0x211a
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE4_7_0   0x211b
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE3_7_0   0x211c
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE2_7_0   0x211d
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE1_7_0   0x211e
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COE0_7_0   0x211f
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COEM0      0x2120
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COEM1      0x2121
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COEM2      0x2122
#define SI446X_PROP_MODEM_CHFLT_RX2_CHFLT_COEM3      0x2123

#define SI446X_PROP_PA_MODE                          0x2200
#define SI446X_PROP_PA_PWR_LVL                       0x2201
#define SI446X_PROP_PA_BIAS_CLKDUTY                  0x2202
#define SI446X_PROP_PA_TC                            0x2203
#define SI446X_PROP_PA_RAMP_EX                       0x2204
#define SI446X_PROP_PA_DOWN_DELAY                    0x2205
#define SI446X_PROP_PA_DIG_PWR_SEQ_CONFIG            0x2206

#define SI446X_PROP_SYNTH_PFDCP_CPFF                 0x2300
#define SI446X_PROP_SYNTH_PFDCP_CPINT                0x2301
#define SI446X_PROP_SYNTH_VCO_KV                     0x2302
#define SI446X_PROP_SYNTH_LPFILT3                    0x2303
#define SI446X_PROP_SYNTH_LPFILT2                    0x2304
#define SI446X_PROP_SYNTH_LPFILT1                    0x2305
#define SI446X_PROP_SYNTH_LPFILT0                    0x2306
#define SI446X_PROP_SYNTH_VCO_KVCAL                  0x2307

#define SI446X_PROP_MATCH_VALUE_1                    0x3000
#define SI446X_PROP_MATCH_MASK_1                     0x3001
#define SI446X_PROP_MATCH_CTRL_1                     0x3002
#define SI446X_PROP_MATCH_VALUE_2                    0x3003
#define SI446X_PROP_MATCH_MASK_2                     0x3004
#define SI446X_PROP_MATCH_CTRL_2                     0x3005
#define SI446X_PROP_MATCH_VALUE_3                    0x3006
#define SI446X_PROP_MATCH_MASK_3                     0x3007
#define SI446X_PROP_MATCH_CTRL_3                     0x3008
#define SI446X_PROP_MATCH_VALUE_4                    0x3009
#define SI446X_PROP_MATCH_MASK_4                     0x300a
#define SI446X_PROP_MATCH_CTRL_4                     0x300b

#define SI446X_PROP_FREQ_CONTROL_INTE                0x4000
#define SI446X_PROP_FREQ_CONTROL_FRAC_2              0x4001
#define SI446X_PROP_FREQ_CONTROL_FRAC_1              0x4002
#define SI446X_PROP_FREQ_CONTROL_FRAC_0              0x4003
#define SI446X_PROP_FREQ_CONTROL_CHANNEL_STEP_SIZE_1 0x4004
#define SI446X_PROP_FREQ_CONTROL_CHANNEL_STEP_SIZE_0 0x4005
#define SI446X_PROP_FREQ_CONTROL_W_SIZE              0x4006
#define SI446X_PROP_FREQ_CONTROL_VCOCNT_RX_ADJ       0x4007

#define SI446X_PROP_RX_HOP_CONTROL                   0x5000
#define SI446X_PROP_RX_HOP_TABLE_SIZE                0x5001
#define SI446X_PROP_RX_HOP_TABLE_ENTRY_0             0x5002

#define SI446X_PROP_PTI_CTL                          0xf000
#define SI446X_PROP_PTI_BAUD_1                       0xf001
#define SI446X_PROP_PTI_BAUD_0                       0xf002
#define SI446X_PROP_PTI_LOG_EN                       0xf003
#define SI446X_PROP_PTI_LOG_EN_2                     0xf004


/*
 * different chips in the same family (446x family, 4463 vs. 4468)
 * have different length properties.  We put the lengths here
 * and select based on a Platform define for which chip we are
 * using.
 *
 * We collect them all here so easy to maintain.
 *
 * SI446X_CHIP is defined as a hex number in the platform file
 * platforms/<platform>/hardware/si446x/radio_config_<chip>.h
 *
 * ie.  <chip> or <chip>a.  Note the "a" version is a working
 * version which has modifications from the full chip definition
 */
#if SI446X_CHIP == 0x44631B

#define SI446X_GROUP00_SIZE                     0x0a
#define SI446X_GROUP01_SIZE                     0x04
#define SI446X_GROUP02_SIZE                     0x04
#define SI446X_GROUP10_SIZE                     0x0e

/* Group11 4463RevB1B has length 5, 4463RevC2A length 6 */
#define SI446X_GROUP11_SIZE                     0x05
#define SI446X_GROUP12_SIZE                     0x35
#define SI446X_GROUP20_SIZE                     0x52
#define SI446X_GROUP21_SIZE                     0x24
#define SI446X_GROUP22_SIZE                     0x06
#define SI446X_GROUP23_SIZE                     0x08
#define SI446X_GROUP30_SIZE                     0x0c
#define SI446X_GROUP40_SIZE                     0x08
#define SI446X_GROUP50_SIZE                     0x42
#define SI446X_GROUPF0_SIZE                     0x0

#elif SI446X_CHIP == 0x44631Ba

#define SI446X_GROUP00_SIZE                     0x0a
#define SI446X_GROUP01_SIZE                     0x04
#define SI446X_GROUP02_SIZE                     0x04
#define SI446X_GROUP10_SIZE                     0x0e

/* Group11 4463RevB1B has length 5, 4463RevC2A length 6 */
#define SI446X_GROUP11_SIZE                     0x05

/*
 * gr12  1200-1212, (F2_len)    (size 0x13)
 * gr12a 1221-122a, (RX_F3_len) (size 0x0a)
 */
#define SI446X_GROUP12_SIZE                     0x13
#define SI446X_GROUP12a_SIZE                    0x0a
#define SI446X_GROUP20_SIZE                     0x52
#define SI446X_GROUP21_SIZE                     0x24
#define SI446X_GROUP22_SIZE                     0x06
#define SI446X_GROUP23_SIZE                     0x08
#define SI446X_GROUP30_SIZE                     0x00
#define SI446X_GROUP40_SIZE                     0x08
#define SI446X_GROUP50_SIZE                     0x00
#define SI446X_GROUPF0_SIZE                     0x00

#elif SI446X_CHIP == 0x44682A
/* definitions from Si446x/EZRadioPRO_REVC2/Si4468/revA2A/index_all.html */

#define SI446X_GROUP00_SIZE                     0x0b
#define SI446X_GROUP01_SIZE                     0x04
#define SI446X_GROUP02_SIZE                     0x04
#define SI446X_GROUP10_SIZE                     0x0e
#define SI446X_GROUP11_SIZE                     0x0a
#define SI446X_GROUP12_SIZE                     0x3a
#define SI446X_GROUP20_SIZE                     0x60
#define SI446X_GROUP21_SIZE                     0x24
#define SI446X_GROUP22_SIZE                     0x07
#define SI446X_GROUP23_SIZE                     0x08
#define SI446X_GROUP30_SIZE                     0x0c
#define SI446X_GROUP40_SIZE                     0x08
#define SI446X_GROUP50_SIZE                     0x42
#define SI446X_GROUPF0_SIZE                     0x05

#elif SI446X_CHIP == 0x44682Aa
/* RevC2, chip 4468RevA2A */

#define SI446X_GROUP00_SIZE                     0x0b
#define SI446X_GROUP01_SIZE                     0x04
#define SI446X_GROUP02_SIZE                     0x04
#define SI446X_GROUP10_SIZE                     0x0e
#define SI446X_GROUP11_SIZE                     0x0a

/*
 * gr12  1200-1212, (F2_len)    (size 0x13)
 * gr12a 1221-122a, (RX_F3_len) (size 0x0a)
 */
#define SI446X_GROUP12_SIZE                     0x13
#define SI446X_GROUP12a_SIZE                    0x0a
#define SI446X_GROUP20_SIZE                     0x60
#define SI446X_GROUP21_SIZE                     0x24
#define SI446X_GROUP22_SIZE                     0x07
#define SI446X_GROUP23_SIZE                     0x08
#define SI446X_GROUP30_SIZE                     0x00
#define SI446X_GROUP40_SIZE                     0x08
#define SI446X_GROUP50_SIZE                     0x00
#define SI446X_GROUPF0_SIZE                     0x00

#else
#error Unrecognized value for SI446X_CHIP
#endif


// #define SI446X_CMD_GET_INT_STATUS             0x20
#define SI446X_INT_STATUS_CHIP_INT_STATUS                0x04
#define SI446X_INT_STATUS_MODEM_INT_STATUS               0x02
#define SI446X_INT_STATUS_PH_INT_STATUS                  0x01

#define SI446X_PH_STATUS_FILTER_MATCH                    0x80
#define SI446X_PH_STATUS_FILTER_MISS                     0x40
#define SI446X_PH_STATUS_PACKET_SENT                     0x20
#define SI446X_PH_STATUS_PACKET_RX                       0x10
#define SI446X_PH_STATUS_CRC_ERROR                       0x08
#define SI446X_PH_STATUS_TX_FIFO_ALMOST_EMPTY            0x02
#define SI446X_PH_STATUS_RX_FIFO_ALMOST_FULL             0x01

#define SI446X_MODEM_STATUS_POSTAMBLE_DETECT             0x40
#define SI446X_MODEM_STATUS_INVALID_SYNC                 0x20
#define SI446X_MODEM_STATUS_RSSI_JUMP                    0x10
#define SI446X_MODEM_STATUS_RSSI                         0x08
#define SI446X_MODEM_STATUS_INVALID_PREAMBLE             0x04
#define SI446X_MODEM_STATUS_PREAMBLE_DETECT              0x02
#define SI446X_MODEM_STATUS_SYNC_DETECT                  0x01

#define SI446X_CHIP_STATUS_CAL                           0x40
#define SI446X_CHIP_STATUS_FIFO_UNDER_OVER_ERROR         0x20
#define SI446X_CHIP_STATUS_STATE_CHANGE                  0x10
#define SI446X_CHIP_STATUS_CMD_ERROR                     0x08
#define SI446X_CHIP_STATUS_CHIP_READY                    0x04
#define SI446X_CHIP_STATUS_LOW_BATT                      0x02
#define SI446X_CHIP_STATUS_WUT                           0x01

//#define SI446X_PROP_FRR_CTL_A_MODE                   0x0200
//#define SI446X_PROP_FRR_CTL_B_MODE                   0x0201
//#define SI446X_PROP_FRR_CTL_C_MODE                   0x0202
//#define SI446X_PROP_FRR_CTL_D_MODE                   0x0203
#define SI446X_FRR_MODE_DISABLED                         0
#define SI446X_FRR_MODE_GLOBAL_STATUS                    1
#define SI446X_FRR_MODE_GLOBAL_INTERRUPT_PENDING         2
#define SI446X_FRR_MODE_PACKET_HANDLER_STATUS            3
#define SI446X_FRR_MODE_PACKET_HANDLER_INTERRUPT_PENDING 4
#define SI446X_FRR_MODE_MODEM_STATUS                     5
#define SI446X_FRR_MODE_MODEM_INTERRUPT_PENDING          6
#define SI446X_FRR_MODE_CHIP_STATUS                      7
#define SI446X_FRR_MODE_CHIP_INTERRUPT_PENDING           8
#define SI446X_FRR_MODE_CURRENT_STATE                    9
#define SI446X_FRR_MODE_LATCHED_RSSI                     10

//#define SI446X_PROP_INT_CTL_ENABLE                   0x0100
#define SI446X_CHIP_INT_STATUS_EN                        0x04
#define SI446X_MODEM_INT_STATUS_EN                       0x02
#define SI446X_PH_INT_STATUS_EN                          0x01

//#define SI446X_PROP_PREAMBLE_CONFIG                  0x1004
#define SI446X_PREAMBLE_FIRST_1                          0x20
#define SI446X_PREAMBLE_FIRST_0                          0x00
#define SI446X_PREAMBLE_LENGTH_NIBBLES                   0x00
#define SI446X_PREAMBLE_LENGTH_BYTES                     0x10
#define SI446X_PREAMBLE_MAN_CONST                        0x08
#define SI446X_PREAMBLE_MAN_ENABLE                       0x02
#define SI446X_PREAMBLE_NON_STANDARD                     0x00
#define SI446X_PREAMBLE_STANDARD_1010                    0x01
#define SI446X_PREAMBLE_STANDARD_0101                    0x02

//#define SI446X_PROP_SYNC_CONFIG                      0x1100
#define SI446X_SYNC_CONFIG_SKIP_TX                       0x80
#define SI446X_SYNC_CONFIG_RX_ERRORS_MASK                0x70
#define SI446X_SYNC_CONFIG_4FSK                          0x08
#define SI446X_SYNC_CONFIG_MANCH                         0x04
#define SI446X_SYNC_CONFIG_LENGTH_MASK                   0x03

//#define SI446X_PROP_PKT_CRC_CONFIG                   0x1200
#define SI446X_CRC_SEED_ALL_0S                           0x00
#define SI446X_CRC_SEED_ALL_1S                           0x80
#define SI446X_CRC_MASK                                  0x0f
#define SI446X_CRC_NONE                                  0x00
#define SI446X_CRC_ITU_T                                 0x01
#define SI446X_CRC_IEC_16                                0x02
#define SI446X_CRC_BIACHEVA                              0x03
#define SI446X_CRC_16_IBM                                0x04
#define SI446X_CRC_CCITT                                 0x05
#define SI446X_CRC_KOOPMAN                               0x06
#define SI446X_CRC_IEEE_802_3                            0x07
#define SI446X_CRC_CASTAGNOLI                            0x08

//#define SI446X_PROP_PKT_CONFIG1                      0x1206
#define SI446X_PH_FIELD_SPLIT                            0x80
#define SI446X_PH_RX_DISABLE                             0x40
#define SI446X_4FSK_EN                                   0x20
#define SI446X_RX_MULTI_PKT                              0x10
#define SI446X_MANCH_POL                                 0x08
#define SI446X_CRC_INVERT                                0x04
#define SI446X_CRC_ENDIAN                                0x02
#define SI446X_BIT_ORDER                                 0x01

//#define SI446X_PROP_PKT_FIELD_1_CONFIG               0x120f
//#define SI446X_PROP_PKT_FIELD_2_CONFIG               0x1213
//#define SI446X_PROP_PKT_FIELD_3_CONFIG               0x1217
//#define SI446X_PROP_PKT_FIELD_4_CONFIG               0x121b
//#define SI446X_PROP_PKT_FIELD_5_CONFIG               0x121f
#define SI446X_FIELD_CONFIG_4FSK                         0x10
#define SI446X_FIELD_CONFIG_WHITEN                       0x02
#define SI446X_FIELD_CONFIG_MANCH                        0x01

//#define SI446X_PROP_PKT_RX_FIELD_1_CRC_CONFIG        0x1224
//#define SI446X_PROP_PKT_RX_FIELD_2_CRC_CONFIG        0x1228
//#define SI446X_PROP_PKT_RX_FIELD_3_CRC_CONFIG        0x122c
//#define SI446X_PROP_PKT_RX_FIELD_4_CRC_CONFIG        0x1230
//#define SI446X_PROP_PKT_RX_FIELD_5_CRC_CONFIG        0x1234
#define SI446X_FIELD_CONFIG_CRC_START                     0x80
#define SI446X_FIELD_CONFIG_SEND_CRC                      0x20
#define SI446X_FIELD_CONFIG_CHECK_CRC                     0x08
#define SI446X_FIELD_CONFIG_CRC_ENABLE                    0x02


//#define SI446X_PROP_MODEM_MOD_TYPE                   0x2000
#define SI446X_TX_DIRECT_MODE_TYPE_SYNCHRONOUS           0x00
#define SI446X_TX_DIRECT_MODE_TYPE_ASYNCHRONOUS          0x80
#define SI446X_TX_DIRECT_MODE_GPIO0                      0x00
#define SI446X_TX_DIRECT_MODE_GPIO1                      0x20
#define SI446X_TX_DIRECT_MODE_GPIO2                      0x40
#define SI446X_TX_DIRECT_MODE_GPIO3                      0x60
#define SI446X_MOD_SOURCE_PACKET_HANDLER                 0x00
#define SI446X_MOD_SOURCE_DIRECT_MODE                    0x08
#define SI446X_MOD_SOURCE_RANDOM_GENERATOR               0x10
#define SI446X_MOD_TYPE_CW                               0x00
#define SI446X_MOD_TYPE_OOK                              0x01
#define SI446X_MOD_TYPE_2FSK                             0x02
#define SI446X_MOD_TYPE_2GFSK                            0x03
#define SI446X_MOD_TYPE_4FSK                             0x04
#define SI446X_MOD_TYPE_4GFSK                            0x05

//    SI446X_PROP_PA_MODE                          0x2200
#define SI446X_PA_MODE_1_GROUP                           0x04
#define SI446X_PA_MODE_2_GROUPS                          0x08
#define SI446X_PA_MODE_CLASS_E                           0x00
#define SI446X_PA_MODE_SWITCH_CURRENT                    0x01

typedef struct {
  uint8_t chiprev;
  uint8_t part_15;
  uint8_t part_7;
  uint8_t pbuild;
  uint8_t id_15;
  uint8_t id_7;
  uint8_t customer;
  uint8_t romid;
} si446x_part_info_t;                   /* PART_INFO, 0x01 */

typedef struct {
  uint8_t revext;
  uint8_t revbranch;
  uint8_t revint;
  uint8_t patch17;
  uint8_t patch7;
  uint8_t func;
} si446x_func_info_t;                   /* FUNC_INFO, 0x10 */

typedef struct {
  uint8_t gpio0;
  uint8_t gpio1;
  uint8_t gpio2;
  uint8_t gpio3;
  uint8_t nirq;
  uint8_t sdo;
  uint8_t gen_config;                   /* GPIO_PIN_CFG, 0x13 */
} si446x_gpio_cfg_t;

typedef struct {
  uint8_t pend;
  uint8_t status;
  uint8_t ph_pend;
  uint8_t ph_status;
  uint8_t modem_pend;
  uint8_t modem_status;
  uint8_t chip_pend;
  uint8_t chip_status;
//  uint8_t info_flags;                 /* 68 only */
} si446x_int_state_t;                   /* INT_STATUS, 0x20 */

typedef struct {
  uint8_t cmd;
  uint8_t ph_pend;
  uint8_t modem_pend;
  uint8_t chip_pend;
} si446x_int_clr_t;                     /* INT_STATUS, clear flags */

typedef struct {
  uint8_t pend;
  uint8_t status;
} si446x_ph_status_t;                   /* PH_STATUS, 0x21 */

typedef struct {
  uint8_t pend;
  uint8_t status;
  uint8_t curr_rssi;
  uint8_t latched_rssi;
  uint8_t ant1_rssi;
  uint8_t ant2_rssi;
  uint8_t afc_freq_offset15;
  uint8_t afc_freq_offset7;
//  uint8_t info_flags;                 /* 68 only */
} si446x_modem_status_t;                /* MODEM_STATUS, 0x22 */

typedef struct {
  uint8_t pend;
  uint8_t status;
  uint8_t cmd_err_status;
  uint8_t cmd_err_cmd_id;
//  uint8_t info_flags;                 /* 68 only */
} si446x_chip_status_t;                 /* CHIP_STATUS, 0x23 */

typedef struct {
  uint32_t ts;
  uint8_t  cts;
  uint8_t  irqn;
  uint8_t  csn;
  si446x_device_state_t  ds;
  uint8_t  ph;
  uint8_t  modem;
  uint8_t  rssi;
  uint8_t  r;
} rps_t;

typedef struct {
  uint32_t              dump_start;   /* 32 bit us TRadio Localtime timestamp */
  uint32_t              dump_end;     /* 32 bit us TRadio Localtime timestamp */
  uint32_t              delta;        /* how long did dump take */

  uint8_t               CTS_pin;
  uint8_t               IRQN_pin;
  uint8_t               SDN_pin;
  uint8_t               CSN_pin;
  uint16_t              cap_val;
  uint16_t              cap_control;

  si446x_part_info_t    part_info;
  si446x_func_info_t    func_info;
  si446x_gpio_cfg_t     gpio_cfg;

  /* fifoinfo */
  uint8_t               rxfifocnt;
  uint8_t               txfifofree;

  si446x_ph_status_t    ph_status;
  si446x_modem_status_t modem_status;
  si446x_chip_status_t  chip_status;
  si446x_int_state_t    int_state;

  /* request_device_state */
  uint8_t               device_state;
  uint8_t               channel;
  uint8_t               frr[4];

  uint8_t               packet_info_len[2];

  /* properties */
  uint8_t               GLOBAL[SI446X_GROUP00_SIZE];
  uint8_t               INT_CTL[SI446X_GROUP01_SIZE];
  uint8_t               FRR_CTL[SI446X_GROUP02_SIZE];
  uint8_t               PREAMBLE[SI446X_GROUP10_SIZE];
  uint8_t               SYNC[SI446X_GROUP11_SIZE];

  /*
   * group12 defines various properties about packets including
   * various fields and how CRC is handled.  One can dump the
   * entire group.  Alternatively one can use a sparse set of properties
   * for packets and packet fields, ie the TX props for TX and the
   * RX props for RX props.  We reduce GROUP12_SIZE and define
   * GROUP12a_SIZE to minimize how many Packet properites we add to the
   * radio dump.  Group12a starts at 0x1221, PKT_RX_FIELD_1_LENGTH.
   */
  uint8_t               PKT[SI446X_GROUP12_SIZE];
#ifdef SI446X_GROUP12a_SIZE
  uint8_t               gr12a_pkt[SI446X_GROUP12a_SIZE];
#endif
  uint8_t               MODEM[SI446X_GROUP20_SIZE];
  uint8_t               MODEM_CHFLT[SI446X_GROUP21_SIZE];
  uint8_t               PAx[SI446X_GROUP22_SIZE];
  uint8_t               SYNTH[SI446X_GROUP23_SIZE];
  uint8_t               MATCH[SI446X_GROUP30_SIZE];
  uint8_t               FREQ_CONTROL[SI446X_GROUP40_SIZE];
  uint8_t               RX_HOP[SI446X_GROUP50_SIZE];
//  uint8_t              grF0_pti[SI446X_GROUPF0_SIZE];
} radio_dump_t;

typedef struct {
  uint16_t  prop_id;
  uint8_t  *where;
  uint8_t   length;
} dump_prop_desc_t;

typedef enum {
  SPI_REC_UNDEFINED   = 0,
  SPI_REC_READ_FRR    = 1,
  SPI_REC_SEND_CMD    = 2,
  SPI_REC_GET_REPLY   = 3,
  SPI_REC_RX_FIFO     = 4,
  SPI_REC_TX_FIFO     = 5,
  SPI_REC_LAST
} spi_trace_record_t;

#define SPI_TRACE_BUF_MAX  16
typedef struct {
  uint32_t              timestamp;
  spi_trace_record_t    op;
  uint8_t               struct_id;
  uint8_t               length;
  uint8_t               buf[SPI_TRACE_BUF_MAX];
} spi_trace_desc_t;

/*
 * global frr state info and constants for accessing
 */
typedef struct {
  uint8_t       device_state;
  uint8_t       ph_pend;
  uint8_t       modem_pend;
  uint8_t       latched_rssi;
} si446x_frr_info_t;

typedef struct {
  si446x_int_state_t    ints;
  si446x_ph_status_t    ph;
  si446x_modem_status_t modem;
  si446x_chip_status_t  chip;
} si446x_chip_all_t;

typedef struct {
  uint16_t cmd;
  uint16_t t_cts0;
  uint16_t t_cmd0;
  uint16_t d_len0;
  uint16_t t_cts_r;
  uint16_t t_reply;
  uint16_t d_reply_len;
  uint16_t t_elapsed;
  uint8_t  frr[4];
} cmd_timing_t;

 typedef struct {
    uint8_t len;
    uint8_t proto;
    uint16_t da;
    uint16_t sa;
    uint8_t data[];
  } ds_pkt_t;

  enum {
    FCS_SIZE     = 2,
  };

#endif          //__SI446X_H__
