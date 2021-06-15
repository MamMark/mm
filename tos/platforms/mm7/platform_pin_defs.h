/*
 * Copyright (c) 2021, Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

#ifndef __PLATFORM_PIN_DEFS__
#define __PLATFORM_PIN_DEFS__

/*
 * Mems Bus, UCB0, SPI
 * LSM6DSOX (complex, accel, gy, mag), LPS22HB (press)
 */
#define MEMS0_ID_LSM6           0
#define MEMS0_ID_LPS22          1

#define MEMS0_SCLK_PORT         P1
#define MEMS0_SCLK_PIN          5
#define MEMS0_SCLK_SEL0         BITBAND_PERI(MEMS0_SCLK_PORT->SEL0,   MEMS0_SCLK_PIN)

#define MEMS0_SIMO_PORT         P1
#define MEMS0_SIMO_PIN          6
#define MEMS0_SIMO_SEL0         BITBAND_PERI(MEMS0_SIMO_PORT->SEL0,   MEMS0_SIMO_PIN)

#define MEMS0_SOMI_PORT         P1
#define MEMS0_SOMI_PIN          7
#define MEMS0_SOMI_SEL0         BITBAND_PERI(MEMS0_SOMI_PORT->SEL0,   MEMS0_SOMI_PIN)

#define MEMS0_LSM6_CSN_PORT     P5
#define MEMS0_LSM6_CSN_PIN      0
#define MEMS0_LSM6_CSN          BITBAND_PERI(MEMS0_LSM6_CSN_PORT->OUT, MEMS0_LSM6_CSN_PIN)
#define MEMS0_LSM6_INT1_PP      0x51

#define MEMS0_LPS22_CSN_PORT    P4
#define MEMS0_LPS22_CSN_PIN     7
#define MEMS0_LPS22_CSN         BITBAND_PERI(MEMS0_LPS22_CSN_PORT->OUT, MEMS0_LPS22_CSN_PIN)
#define MEMS0_LPS22_INT_PP      0x46


/* gps - ublox */

/* define the PIO pin on the GPS used for TXRDY */
#define PLATFORM_UBX_TXRDY_PIN  15

/* also see startup.c(__pins_init), need to turn off PJ.4->SEL0 for DIO */
#define UBX_PWR_PORT            PJ
#define UBX_PWR_PIN             4
#define UBX_PWR                 BITBAND_PERI(UBX_PWR_PORT->OUT,  UBX_PWR_PIN)
#define UBX_PWRD_P              BITBAND_PERI(UBX_PWR_PORT->IN,   UBX_PWR_PIN)

#define UBX_VBCKUP_PORT         PJ
#define UBX_VBCKUP_PIN          2
#define UBX_VBCKUP              BITBAND_PERI(UBX_VBCKUP_PORT->OUT,  UBX_VBCKUP_PIN)

#define UBX_SCLK_PORT           P7
#define UBX_SCLK_PIN            0
#define UBX_SCLK_SEL0           BITBAND_PERI(UBX_SCLK_PORT->SEL0, UBX_SCLK_PIN)
#define UBX_SCLK_REN            BITBAND_PERI(UBX_SCLK_PORT->REN,  UBX_SCLK_PIN)

#define UBX_TM_PORT             P7
#define UBX_TM_PIN              1
#define UBX_TM_SEL0             BITBAND_PERI(UBX_TM_PORT->SEL0, UBX_TM_PIN)
#define UBX_TM_REN              BITBAND_PERI(UBX_TM_PORT->REN,  UBX_TM_PIN)
#define UBX_TM_BIT              (1 << UBX_TM_PIN)
#define UBX_TM_P                (UBX_TM_PORT->IN & UBX_TM_BIT)

/* SOMI is also RXD, gps_tx */
#define UBX_SOMI_PORT           P7
#define UBX_SOMI_PIN            2
#define UBX_SOMI_SEL0           BITBAND_PERI(UBX_SOMI_PORT->SEL0, UBX_SOMI_PIN)
#define UBX_SOMI_REN            BITBAND_PERI(UBX_SOMI_PORT->REN,  UBX_SOMI_PIN)

/* SIMO is also TXD, gps_rx */
#define UBX_SIMO_PORT           P7
#define UBX_SIMO_PIN            3
#define UBX_SIMO_SEL0           BITBAND_PERI(UBX_SIMO_PORT->SEL0, UBX_SIMO_PIN)
#define UBX_SIMO_REN            BITBAND_PERI(UBX_SIMO_PORT->REN,  UBX_SIMO_PIN)

/* DSEL pin grounded and not connected to the processor */

#define UBX_CSN_PORT            P5
#define UBX_CSN_PIN             5
#define UBX_CSN                 BITBAND_PERI(UBX_CSN_PORT->OUT, UBX_CSN_PIN)
#define UBX_CSN_REN             BITBAND_PERI(UBX_CSN_PORT->REN, UBX_CSN_PIN)
#define UBX_CSN_DIR             BITBAND_PERI(UBX_CSN_PORT->DIR, UBX_CSN_PIN)

#define UBX_EXTINT0_PORT        P5
#define UBX_EXTINT0_PIN         6
#define UBX_EXTINT0_REN         BITBAND_PERI(UBX_EXTINT0_PORT->REN, UBX_EXTINT0_PIN)
#define UBX_EXTINT0             BITBAND_PERI(UBX_EXTINT0_PORT->REN, UBX_EXTINT0_PIN)

#define UBX_TXRDY_PORT          P5
#define UBX_TXRDY_PIN           7
#define UBX_TXRDY_REN           BITBAND_PERI(UBX_TXRDY_PORT->REN, UBX_TXRDY_PIN)
#define UBX_TXRDY_BIT           (1 << UBX_TXRDY_PIN)
#define UBX_TXRDY_P             (UBX_TXRDY_PORT->IN & UBX_TXRDY_BIT)
#define UBX_TXRDY_INT_PP        0x57

/* radio - si446x - (B2) */
#define SI446X_CTS_PORT     P4
#define SI446X_CTS_PIN      4
#define SI446X_CTS_BIT      (1 << SI446X_CTS_PIN)
#define SI446X_CTS_P        (SI446X_CTS_PORT->IN & SI446X_CTS_BIT)

#define SI446X_SDN_PORT     P4
#define SI446X_SDN_PIN      3
#define SI446X_SDN_BIT      (1 << SI446X_SDN_PIN)
#define SI446X_SDN_IN       (SI446X_SDN_PORT->IN & SI446X_SDN_BIT)
#define SI446X_SHUTDOWN     BITBAND_PERI(SI446X_SDN_PORT->OUT, SI446X_SDN_PIN) = 1
#define SI446X_UNSHUT       BITBAND_PERI(SI446X_SDN_PORT->OUT, SI446X_SDN_PIN) = 0

#define SI446X_IRQN_PORT    P3
#define SI446X_IRQN_PIN     7
#define SI446X_IRQN_BIT     (1 << SI446X_IRQN_PIN)
#define SI446X_IRQN_P       (P3->IN & SI446X_IRQN_BIT)
#define SI446X_IRQN_PP      0x37

#define SI446X_CSN_PORT     P3
#define SI446X_CSN_PIN      3
#define SI446X_CSN_BIT      (1 << SI446X_CSN_PIN)
#define SI446X_CSN_IN       (SI446X_CSN_PORT->IN & SI446X_CSN_BIT)
#define SI446X_CSN          BITBAND_PERI(SI446X_CSN_PORT->OUT, SI446X_CSN_PIN)


/* Dock A0 */
#define DC_SLAVE_RDY_PORT   P1
#define DC_SLAVE_RDY_PIN    3
#define DC_SLAVE_RDY_BIT    (1 << DC_SLAVE_RDY_PIN)
#define DC_SLAVE_RDY_N      BITBAND_PERI(DC_SLAVE_RDY_PORT->OUT, DC_SLAVE_RDY_PIN)

#define DC_ATTN_PORT        P1
#define DC_ATTN_PIN         4
#define DC_ATTN_BIT         (1 << DC_ATTN_PIN)
#define DC_ATTN_P           (P6->IN & DC_ATTN_BIT)
#define DC_ATTN_INT_PP      0x14

#define DC_MSG_PENDING_PORT P2
#define DC_MSG_PENDING_PIN  0
#define DC_MSG_PENDING_BIT  (1 << DC_MSG_PENDING_PIN)
#define DC_MSG_PENDING      BITBAND_PERI(DC_MSG_PENDING_PORT->OUT, DC_MSG_PENDING_PIN)

#define DC_SCLK_PORT        P2
#define DC_SCLK_PIN         1
#define DC_SCLK_SEL0        BITBAND_PERI(DC_SCLK_PORT->SEL0,   DC_SCLK_PIN)

#define DC_SOMI_PORT        P2
#define DC_SOMI_PIN         2
#define DC_SOMI_SEL0        BITBAND_PERI(DC_SOMI_PORT->SEL0,   DC_SOMI_PIN)

#define DC_SIMO_PORT        P2
#define DC_SIMO_PIN         3
#define DC_SIMO_SEL0        BITBAND_PERI(DC_SIMO_PORT->SEL0,   DC_SIMO_PIN)


/* micro SD A2 */
#define SD0_CSN_PORT        P8
#define SD0_CSN_PIN         1
#define SD0_CSN             BITBAND_PERI(SD0_CSN_PORT->OUT, SD0_CSN_PIN)

/* high true, setting a 1 turns the power on, 0 turns it off. */
#define SD0_PWR_ENA_PORT    P8
#define SD0_PWR_ENA_PIN     0
#define SD0_PWR             BITBAND_PERI(SD0_PWR_ENA_PORT->OUT, SD0_PWR_ENA_PIN)
#define SD0_PWRD_P          BITBAND_PERI(SD0_PWR_ENA_PORT->IN,  SD0_PWR_ENA_PIN)


/*
 * see hardware.h for what port is assigned to SD0 for SPI.
 * The DMA channels used depend on this.  We need RX/TX triggers
 * and the address of what data port to hit.
 */
#define SD0_DMA_TX_CHANNEL 4
#define SD0_DMA_RX_CHANNEL 5
#define SD0_DMA_TX_TRIGGER MSP432_DMA_CH4_A2_TX
#define SD0_DMA_RX_TRIGGER MSP432_DMA_CH5_A2_RX
#define SD0_DMA_TX_ADDR    EUSCI_A2->TXBUF
#define SD0_DMA_RX_ADDR    EUSCI_A2->RXBUF


/*
 * TMP - B3
 *
 * TMP bus consists of two tmp sensors off of an I2C eUSCI.
 * when the TMP bus is powered down we want to set the bus
 * pins (SCL and SDA) to inputs.
 *
 * On initialization the pins are initially set to inputs
 * and then kicked over to the module when the i2c bus
 * is powered up.
 */

#define TMP_SDA_PORT    P6
#define TMP_SDA_PIN     6
#define TMP_SCL_PORT    P6
#define TMP_SCL_PIN     7
#define TMP_PWR_PORT    P1
#define TMP_PWR_PIN     0

#define TMP_PINS_PORT   do { \
    BITBAND_PERI(TMP_SDA_PORT->SEL0, TMP_SDA_PIN) = 0; \
    BITBAND_PERI(TMP_SCL_PORT->SEL0, TMP_SCL_PIN) = 0; \
} while (0)


#define TMP_PINS_MODULE do { \
    BITBAND_PERI(TMP_SDA_PORT->SEL0, TMP_SDA_PIN) = 1; \
    BITBAND_PERI(TMP_SCL_PORT->SEL0, TMP_SCL_PIN) = 1; \
} while (0)


/*
 * always return SCL as being high.  This tells battery_connected that
 * the battery is indeed up.   This is to fake out battery_connected
 * and why we don't actually read SCL.
 */
#define TMP_GET_SCL_MODULE_STATE BITBAND_PERI(TMP_SCL_PORT->SEL0, TMP_SCL_PIN)
#define TMP_GET_SCL              (1)
#define TMP_GET_PWR_STATE        (1)

/* nothing to do always powered on */
#define TMP_I2C_PWR_ON  do { \
} while (0)

#define TMP_I2C_PWR_OFF do { \
} while (0)


#define TELL_PORT       P1
#define TELL_PIN        3
#define TELL_BIT        (1 << TELL_PIN)
#define TELL            BITBAND_PERI(TELL_PORT->OUT, TELL_PIN)
#define TOGGLE_TELL     TELL ^= 1;
#define TELL0           TELL_PORT->OUT = 0;
#define TELL1           TELL_PORT->OUT = TELL_BIT;
#define WIGGLE_TELL     do { TELL = 1; TELL = 0; } while(0)

#define WIGGLE_EXC      do { } while(0)

#endif    /* __PLATFORM_PIN_DEFS__ */
