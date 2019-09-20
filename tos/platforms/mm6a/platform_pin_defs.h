/*
 * Copyright (c) 2017 Eric B. Decker
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
 * shared power rail (1V8), gps_mems_1V8
 *
 * normally on.  bounched if we need a big hammer.  Will power down
 * the gps, accel, gyro, and mag (the mems devices).  I/O pins must
 * be disconnected (driven low or made inputs) to avoid continuing
 * to power the device.
 */

#define GPS_MEMS_1V8_EN_PORT P5
#define GPS_MEMS_1V8_EN_PIN  0
#define GPS_MEMS_1V8_EN      BITBAND_PERI(GPS_MEMS_1V8_EN_PORT->OUT, GPS_MEMS_1V8_EN_PIN)


/*
 * Mems Bus, UCB1, SPI
 */
#define MEMS0_ID_ACCEL 0
#define MEMS0_ID_GYRO  1
#define MEMS0_ID_MAG   2

#define MEMS0_ACCEL_CSN_PORT    P1
#define MEMS0_ACCEL_CSN_PIN     6
#define MEMS0_ACCEL_CSN_BIT     (1 << MEMS0_ACCEL_CSN_PIN)
#define MEMS0_ACCEL_CSN_IN      (MEMS0_ACCEL_CSN_PORT->IN & MEMS0_ACCEL_CSN_BIT)
#define MEMS0_ACCEL_CSN         BITBAND_PERI(MEMS0_ACCEL_CSN_PORT->OUT, MEMS0_ACCEL_CSN_PIN)
#define MEMS0_ACCEL_CSN_DIR     BITBAND_PERI(MEMS0_ACCEL_CSN_PORT->DIR, MEMS0_ACCEL_CSN_PIN)

#define MEMS0_GYRO_CSN_PORT     P5
#define MEMS0_GYRO_CSN_PIN      7
#define MEMS0_GYRO_CSN_BIT      (1 << MEMS0_GYRO_CSN_PIN)
#define MEMS0_GYRO_CSN_IN       (MEMS0_GYRO_CSN_PORT->IN & MEMS0_GYRO_CSN_BIT)
#define MEMS0_GYRO_CSN          BITBAND_PERI(MEMS0_GYRO_CSN_PORT->OUT, MEMS0_GYRO_CSN_PIN)
#define MEMS0_GYRO_CSN_DIR      BITBAND_PERI(MEMS0_GYRO_CSN_PORT->DIR, MEMS0_GYRO_CSN_PIN)

#define MEMS0_MAG_CSN_PORT      P1
#define MEMS0_MAG_CSN_PIN       5
#define MEMS0_MAG_CSN_BIT       (1 << MEMS0_MAG_CSN_PIN)
#define MEMS0_MAG_CSN_IN        (MEMS0_MAG_CSN_PORT->IN & MEMS0_MAG_CSN_BIT)
#define MEMS0_MAG_CSN           BITBAND_PERI(MEMS0_MAG_CSN_PORT->OUT, MEMS0_MAG_CSN_PIN)
#define MEMS0_MAG_CSN_DIR       BITBAND_PERI(MEMS0_MAG_CSN_PORT->DIR, MEMS0_MAG_CSN_PIN)

#define MEMS0_SCLK_PORT         P6
#define MEMS0_SCLK_PIN          3
#define MEMS0_SCLK_SEL0         BITBAND_PERI(MEMS0_SCLK_PORT->SEL0,   MEMS0_SCLK_PIN)

#define MEMS0_SIMO_PORT         P6
#define MEMS0_SIMO_PIN          4
#define MEMS0_SIMO_SEL0         BITBAND_PERI(MEMS0_SIMO_PORT->SEL0,   MEMS0_SIMO_PIN)

#define MEMS0_SOMI_PORT         P6
#define MEMS0_SOMI_PIN          5
#define MEMS0_SOMI_SEL0         BITBAND_PERI(MEMS0_SOMI_PORT->SEL0,   MEMS0_SOMI_PIN)


/* gps -gsd4e/org */

#define GSD4E_AWAKE_PORT    P6
#define GSD4E_AWAKE_PIN     2
#define GSD4E_AWAKE_BIT     (1 << GSD4E_AWAKE_PIN)
#define GSD4E_AWAKE_P       (GSD4E_AWAKE_PORT->IN & GSD4E_AWAKE_BIT)

#define GSD4E_CTS_PORT      P7
#define GSD4E_CTS_PIN       0
#define GSD4E_CTS           BITBAND_PERI(GSD4E_CTS_PORT->OUT, GSD4E_CTS_PIN)
#define GSD4E_CTS_DIR       BITBAND_PERI(GSD4E_CTS_PORT->DIR, GSD4E_CTS_PIN)
#define GSD4E_CTS_PU        BITBAND_PERI(GSD4E_CTS_PORT->REN, GSD4E_CTS_PIN)

#define GSD4E_ONOFF_PORT    P5
#define GSD4E_ONOFF_PIN     5
#define GSD4E_ONOFF         BITBAND_PERI(GSD4E_ONOFF_PORT->OUT, GSD4E_ONOFF_PIN)
#define GSD4E_ONOFF_DIR     BITBAND_PERI(GSD4E_ONOFF_PORT->DIR, GSD4E_ONOFF_PIN)

#define GSD4E_RESETN_PORT   PJ
#define GSD4E_RESETN_PIN    2
#define GSD4E_RESETN        BITBAND_PERI(GSD4E_RESETN_PORT->OUT, GSD4E_RESETN_PIN)
#define GSD4E_RESETN_FLOAT  BITBAND_PERI(GSD4E_RESETN_PORT->DIR, GSD4E_RESETN_PIN) = 0;
#define GSD4E_RESETN_OUTPUT BITBAND_PERI(GSD4E_RESETN_PORT->DIR, GSD4E_RESETN_PIN) = 1;

#define GSD4E_RTS_PORT      PJ
#define GSD4E_RTS_PIN       3
#define GSD4E_RTS_BIT       (1 << GSD4E_RTS_PIN)
#define GSD4E_RTS_P         (GSD4E_RTS_PORT->IN & GSD4E_RTS_BIT)

#define GSD4E_TM_PORT       P7
#define GSD4E_TM_PIN        1
#define GSD4E_TM_BIT        (1 << GSD4E_TM_PIN)
#define GSD4E_TM_P          (GSD4E_TM_PORT->IN & GSD4E_TM_BIT)

#define GSD4E_PINS_MODULE   do { P7->SEL0 |=  0x0c; } while (0)
#define GSD4E_PINS_PORT     do { P7->SEL0 &= ~0x0c; } while (0)

/* radio - si446x - (B2) */
#define SI446X_TX_PWR_PORT  P4
#define SI446X_TX_PWR_PIN   5
#define SI446X_TX_PWR_BIT   (1 << SI446X_TX_PWR_PIN)
#define SI446X_TX_PWR_OFF   BITBAND_PERI(SI446X_TX_PWR_PORT->OUT, SI446X_TX_PWR_PIN) = 0
#define SI446X_TX_PWR_ON    BITBAND_PERI(SI446X_TX_PWR_PORT->OUT, SI446X_TX_PWR_PIN) = 1
#define SI446X_TX_PWR_ON_P  (SI446X_TX_PWR_PORT->OUT & SI446X_TX_PWR_BIT)

#define SI446X_TX_PWRSEL_PORT  P4
#define SI446X_TX_PWRSEL_PIN   0
#define SI446X_TX_PWRSEL_BIT   (1 << SI446X_TX_PWRSEL_PIN)
#define SI446X_TX_PWR_3V3      BITBAND_PERI(SI446X_TX_PWRSEL_PORT->OUT, SI446X_TX_PWRSEL_PIN) = 1
#define SI446X_TX_PWR_1V8      BITBAND_PERI(SI446X_TX_PWRSEL_PORT->OUT, SI446X_TX_PWRSEL_PIN) = 0
#define SI446X_TX_PWR_HI_P     (SI446X_TX_PWRSEL_PORT->OUT & SI446X_TX_PWRSEL_BIT)

#define SI446X_CTS_PORT     P4
#define SI446X_CTS_PIN      1
#define SI446X_CTS_BIT      (1 << SI446X_CTS_PIN)
#define SI446X_CTS_P        (SI446X_CTS_PORT->IN & SI446X_CTS_BIT)

#define SI446X_SDN_PORT     P3
#define SI446X_SDN_PIN      3
#define SI446X_SDN_BIT      (1 << SI446X_SDN_PIN)
#define SI446X_SDN_IN       (SI446X_SDN_PORT->IN & SI446X_SDN_BIT)
#define SI446X_SHUTDOWN     BITBAND_PERI(SI446X_SDN_PORT->OUT, SI446X_SDN_PIN) = 1
#define SI446X_UNSHUT       BITBAND_PERI(SI446X_SDN_PORT->OUT, SI446X_SDN_PIN) = 0

#define SI446X_IRQN_PORT    P6
#define SI446X_IRQN_PIN     1
#define SI446X_IRQN_BIT     (1 << SI446X_IRQN_PIN)
#define SI446X_IRQN_P       (SI446X_IRQN_PORT->IN & SI446X_IRQN_BIT)
#define SI446X_IRQN_PORT_PIN 0x61

#define SI446X_CSN_PORT     P3
#define SI446X_CSN_PIN      4
#define SI446X_CSN_BIT      (1 << SI446X_CSN_PIN)
#define SI446X_CSN_IN       (SI446X_CSN_PORT->IN & SI446X_CSN_BIT)
#define SI446X_CSN          BITBAND_PERI(SI446X_CSN_PORT->OUT, SI446X_CSN_PIN)


/* micro SDs */
#define SD0_CSN_PORT        P3
#define SD0_CSN_PIN         1
#define SD0_CSN             BITBAND_PERI(SD0_CSN_PORT->OUT, SD0_CSN_PIN)

#define SD0_ACCESS_SENSE_BIT     0x08
#define SD0_ACCESS_SENSE_N       FALSE
#define SD0_ACCESS_ENA_N

/* high true, setting a 1 turns the power on, 0 turns it off. */
#define SD0_PWR_ENA_PORT    P7
#define SD0_PWR_ENA_PIN     6
#define SD0_PWR_ENA_ON      1
#define SD0_PWR_ENA_OFF     0
#define SD0_PWR_ENA         BITBAND_PERI(SD0_PWR_ENA_PORT->OUT, SD0_PWR_ENA_PIN)

/*
 * see hardware.h for what port is assigned to SD0 for SPI.
 * The DMA channels used depend on this.  We need RX/TX triggers
 * and the address of what data port to hit.
 */
#define SD0_DMA_TX_TRIGGER MSP432_DMA_CH4_A2_TX
#define SD0_DMA_RX_TRIGGER MSP432_DMA_CH5_A2_RX
#define SD0_DMA_TX_ADDR    EUSCI_A2->TXBUF
#define SD0_DMA_RX_ADDR    EUSCI_A2->RXBUF

/*
 * SD0 is run at 3V3 and its I/Os are translated to 1V8 levels.  The
 * translator 1V8 side is always powered and holds any signals at
 * a reasonable level.  This means that we don't need to change the
 * state of pins connected to SD0.
 */

/* deprecated */
#define SD0_PINS_PORT  do {                                 \
    BITBAND_PERI(SD0_CSN_PORT->DIR, SD0_CSN_PIN) = 0;       \
    BITBAND_PERI(P2->SEL0, 4) = 0;                          \
    BITBAND_PERI(P3->SEL0, 0) = 0;                          \
    BITBAND_PERI(P7->SEL0, 7) = 0;                          \
  } while (0)

/* deprecated */
#define SD0_PINS_SPI    do {                                \
    BITBAND_PERI(SD0_CSN_PORT->DIR, SD0_CSN_PIN) = 1;       \
    BITBAND_PERI(P2->SEL0, 4) = 1;                          \
    BITBAND_PERI(P3->SEL0, 0) = 1;                          \
    BITBAND_PERI(P7->SEL0, 7) = 1;                          \
} while (0)


/* SD1, dock sd
 * SD1 is on P7,0-2 and sd1_csn is P9.4
 */
#define SD1_CSN_PORT        P1
#define SD1_CSN_PIN         3
#define SD1_CSN             BITBAND_PERI(SD1_CSN_PORT->OUT, SD1_CSN_PIN)

#define SD1_ACCESS_SENSE_BIT     0x08
#define SD1_ACCESS_SENSE_N       FALSE
#define SD1_ACCESS_ENA_N
#define SD1_PWR_ENA

#define SD1_DMA_TX_TRIGGER MSP432_DMA_CH2_A1_TX
#define SD1_DMA_RX_TRIGGER MSP432_DMA_CH3_A1_RX
#define SD1_DMA_TX_ADDR    EUSCI_A1->TXBUF
#define SD1_DMA_RX_ADDR    EUSCI_A1->RXBUF

/*
 * SD1 is on P2.0, 2.3, and 3.2 and sd1_csn is P1.3
 */
#define SD1_PINS_PORT  do {                                 \
    BITBAND_PERI(SD1_CSN_PORT->DIR, SD1_CSN_PIN) = 0;       \
    BITBAND_PERI(P2->SEL0, 0) = 0;                          \
    BITBAND_PERI(P2->SEL0, 3) = 0;                          \
    BITBAND_PERI(P3->SEL0, 2) = 0;                          \
  } while (0)

#define SD1_PINS_SPI    do {                                \
    BITBAND_PERI(SD1_CSN_PORT->DIR, SD1_CSN_PIN) = 1;       \
    BITBAND_PERI(P2->SEL0, 0) = 1;                          \
    BITBAND_PERI(P2->SEL0, 3) = 1;                          \
    BITBAND_PERI(P3->SEL0, 2) = 1;                          \
} while (0)


/*
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
#define TMP_PWR_PORT    P4
#define TMP_PWR_PIN     3

#define TMP_PINS_PORT   do { \
    BITBAND_PERI(TMP_SDA_PORT->SEL1, TMP_SDA_PIN) = 0; \
    BITBAND_PERI(TMP_SCL_PORT->SEL1, TMP_SCL_PIN) = 0; \
} while (0)


#define TMP_PINS_MODULE do { \
    BITBAND_PERI(TMP_SDA_PORT->SEL1, TMP_SDA_PIN) = 1; \
    BITBAND_PERI(TMP_SCL_PORT->SEL1, TMP_SCL_PIN) = 1; \
} while (0)


#define TMP_GET_SCL_MODULE_STATE BITBAND_PERI(TMP_SCL_PORT->SEL1, TMP_SCL_PIN)
#define TMP_GET_SCL              BITBAND_PERI(TMP_SCL_PORT->IN,   TMP_SCL_PIN)
#define TMP_GET_PWR_STATE        BITBAND_PERI(TMP_PWR_PORT->OUT,  TMP_PWR_PIN)


#define TMP_I2C_PWR_ON  do { \
    BITBAND_PERI(TMP_PWR_PORT->OUT, TMP_PWR_PIN) = 1; \
} while (0)


#define TMP_I2C_PWR_OFF do { \
    BITBAND_PERI(TMP_PWR_PORT->OUT, TMP_PWR_PIN) = 0; \
} while (0)


#define TELL_PORT       P1
#define TELL_PIN        2
#define TELL_BIT        (1 << TELL_PIN)
#define TELL            BITBAND_PERI(TELL_PORT->OUT, TELL_PIN)
#define TOGGLE_TELL     TELL ^= 1;
#define TELL0           TELL_PORT->OUT = 0;
#define TELL1           TELL_PORT->OUT = TELL_BIT;
#define WIGGLE_TELL     do { TELL = 1; TELL = 0; } while(0)

#endif    /* __PLATFORM_PIN_DEFS__ */
