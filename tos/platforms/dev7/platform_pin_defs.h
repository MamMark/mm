/*
 * Copyright (c) 2020, Eric B. Decker
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

/* radio - si446x - (B2) */
#define SI446X_CTS_PORT     P2
#define SI446X_CTS_PIN      3
#define SI446X_CTS_BIT      (1 << SI446X_CTS_PIN)
#define SI446X_CTS_P        (SI446X_CTS_PORT->IN & SI446X_CTS_BIT)

#define SI446X_SDN_PORT     P5
#define SI446X_SDN_PIN      0
#define SI446X_SDN_BIT      (1 << SI446X_SDN_PIN)
#define SI446X_SDN_IN       (SI446X_SDN_PORT->IN & SI446X_SDN_BIT)
#define SI446X_SHUTDOWN     BITBAND_PERI(SI446X_SDN_PORT->OUT, SI446X_SDN_PIN) = 1
#define SI446X_UNSHUT       BITBAND_PERI(SI446X_SDN_PORT->OUT, SI446X_SDN_PIN) = 0

#define SI446X_IRQN_PORT    P5
#define SI446X_IRQN_PIN     1
#define SI446X_IRQN_BIT     (1 << SI446X_IRQN_PIN)
#define SI446X_IRQN_P       (P5->IN & SI446X_IRQN_BIT)
#define SI446X_IRQN_PORT_PIN 0x51

#define SI446X_CSN_PORT     P5
#define SI446X_CSN_PIN      2
#define SI446X_CSN_BIT      (1 << SI446X_CSN_PIN)
#define SI446X_CSN_IN       (SI446X_CSN_PORT->IN & SI446X_CSN_BIT)
#define SI446X_CSN          BITBAND_PERI(SI446X_CSN_PORT->OUT, SI446X_CSN_PIN)


/* micro SDs */
#define SD0_CSN_PORT        P10
#define SD0_CSN_PIN         0
#define SD0_CSN             BITBAND_PERI(SD0_CSN_PORT->OUT, SD0_CSN_PIN)


/*
 * see hardware.h for what port is assigned to SD0 for SPI.
 * The DMA channels used depend on this.  We need RX/TX triggers
 * and the address of what data port to hit.
 */
#define SD0_DMA_TX_TRIGGER MSP432_DMA_CH6_B3_TX0
#define SD0_DMA_RX_TRIGGER MSP432_DMA_CH7_B3_RX0
#define SD0_DMA_TX_ADDR    EUSCI_B3->TXBUF
#define SD0_DMA_RX_ADDR    EUSCI_B3->RXBUF

/*
 * SD0_PINS_SPI will connect the 3 spi lines on SD0 to the SPI.  This is
 * done by simply switching the pins to the module.  We need to disconnect
 * the pins when we power off the SDs to avoid powering the chip via the
 * input pins.
 *
 * We also need to switch sd_csn (10.0) from input to output, the value
 * should be a 1 which deselects the sd and tri-states.  The output is
 * already set to 1 (for the resistor pull up).  So simply switching from
 * input to output is fine.
 *
 * We assume that sd0_csn is a 1.
 */
#define SD0_PINS_PORT  do {                                 \
    BITBAND_PERI(SD0_CSN_PORT->DIR, SD0_CSN_PIN) = 0;       \
    P10->SEL0 = 0;                                          \
  } while (0)

#define SD0_PINS_SPI    do {                                \
    BITBAND_PERI(SD0_CSN_PORT->DIR, SD0_CSN_PIN) = 1;       \
    P10->SEL0 = 0x0E;                                       \
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

#define TMP_SDA_PORT    P1
#define TMP_SDA_PIN     6
#define TMP_SCL_PORT    P1
#define TMP_SCL_PIN     7
#define TMP_PWR_PORT
#define TMP_PWR_PIN

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


#define TELL_PORT       P8
#define TELL_PIN        6
#define TELL_BIT        (1 << TELL_PIN)
#define TELL            BITBAND_PERI(TELL_PORT->OUT, TELL_PIN)
#define TOGGLE_TELL     TELL ^= 1;
#define TELL0           TELL_PORT->OUT = 0;
#define TELL1           TELL_PORT->OUT = TELL_BIT;
#define WIGGLE_TELL     do { TELL = 1; TELL = 0; } while(0)

#endif    /* __PLATFORM_PIN_DEFS__ */
