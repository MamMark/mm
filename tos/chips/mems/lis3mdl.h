/*
 * lis3mdl.h
 */

/* 
 * Register with ID value. Validate SPI xfer by reading this
 * register: Value should equal WHO_I_AM.
 */
#define WHO_AM_I         0x0f
#define WHO_I_AM         0x3d

/*
 * CTRL_REG1
 * - Temperature enable
 * - Set performance level (power consumption)
 * - Set output data rate
 * - Enable self-test
 */
#define CTRL_REG1        0x20
#define TEMP_EN          0x80	/* Temp sensor enable */
#define OP_MODE_MASK     0x60   /* Operating mode mask */
#define  OP_LOW_PWR      0x00   /*  Low power operating mode */
#define  OP_MED_PERF     0x20   /*  Medium performance mode */
#define  OP_HIGH_PERF    0x40   /*  High performance mode */
#define  OP_ULTRA_PERF   0x60   /*  Ultra-high performance mode */
#define ODR_MASK         0x1c   /* Output data rate mask */
#define  ODR_0_625HZ     0x00   /*  ODR = 0.625 Hz */
#define  ODR_1_25HZ      0x04   /*  ODR = 1.25 Hz */
#define  ODR_2_5HZ       0x08   /*  ODR = 2.5 Hz */
#define  ODR_5_HZ        0x0c   /*  ODR = 5 Hz */
#define  ODR_10_HZ       0x10   /*  ODR = 10 Hz */
#define  ODR_20_HZ       0x14   /*  ODR = 20 Hz */
#define  ODR_40_HZ       0x18   /*  ODR = 40 Hz */
#define  ODR_80_HZ       0x1c   /*  ODR = 80 Hz */
#define SELF_TEST        0x01   /* Self-test: 1=self-test enabled */

/*
 * CTRL_REG2
 * - Set full scale deflection
 * - Reboot memory content
 * - Reset registers
 */
#define CTRL_REG2        0x21
#define FS_MASK          0x60   /* Full scale deflection mask */
#define  FS_4G           0x00   /*  FS = +- 4 Gauss */
#define  FS_8G           0x20   /*  FS = +- 8 Gauss */
#define  FS_12G          0x40   /*  FS = +- 12 Gauss */
#define  FS_16G          0x60   /*  FS = +- 16 Gauss */
#define REBOOT           0x08   /* Reboot memory content */
#define SOFT_RESET       0x04   /* Registers reset */

/*
 * CTRL_REG3
 * - Set low power mode
 * - Set SPI mode (4-wire or 3-wire)
 * - Set conversion mode
 */
#define CTRL_REG3        0x22
#define LP_MODE          0x20   /* Low power mode */
#define SIM              0x04   /* SPI mode (0=4wire, 1=3wire) */
#define CONV_MODE_MASK   0x03   /* Conversion mode mask */
#define  CONV_CONT       0x00   /*  Continuous conversion mode */
#define  CONV_SINGLE     0x01   /*  Single conversion mode */
#define  CONV_PD1        0x02   /*  Power down mode */
#define  CONV_PD2        0x03   /*  Power down mode */

/*
 * CTRL_REG4
 * - Z axis performance mode
 * - Big/little endian select
 */
#define CTRL_REG4        0x23
#define OMZ_MASK         0x0c   /* Z-axis operation mode */
#define  OMZ_LP          0x00   /*  Z-axis low power mode */
#define  OMZ_MED_PERF    0x04   /*  Z-axis medium performance mode */
#define  OMZ_HIGH_PERF   0x08   /*  Z-axis high performance mode */
#define  OMZ_ULTRA_PERF  0x0c   /*  Z-axis ultra-high performance mode */
#define BLE              0x02   /* Big/little endian select */

/*
 * CTRL_REG5
 * - Block data update mode
 */
#define CTRL_REG5        0x24
#define BDU              0x40   /* Block data update mode */

/*
 * STATUS_REG
 * - XYZ data output overrun status
 * - XYZ data output available status
 */
#define STATUS_REG       0x27
#define ZYXOR            0x80	/* ZYX axes output overrun */
#define ZOR              0x40   /* Z axis output overrun */
#define YOR              0x20   /* Y axis output overrun */
#define XOR              0x10   /* X axis output overrun */
#define ZYXDA            0x08   /* ZYX axes output data available */
#define ZDA              0x04   /* Z axis output data available */
#define YDA              0x02   /* Y axis output data available */
#define XDA              0x01   /* X axis output data available */

/*
 * X, Y, Z data output register
 */
#define OUT_X_L          0x28
#define OUT_X_H          0x29
#define OUT_Y_L          0x2a
#define OUT_Y_H          0x2b
#define OUT_Z_L          0x2c
#define OUT_Z_H          0x2d

/*
 * Temperature sensor data output
 */
#define TEMP_OUT_L       0x2e
#define TEMP_OUT_H       0x2f

/*
 * INT_CFG
 * - Configure and enable interrupts
 * - Request interrupt latch
 * - Interrupt active status
 */
#define INT_CFG          0x30
#define XIEN             0x80	/* X axis interrupt enable */
#define YIEN             0x40   /* Y axis interrupt enable */
#define ZIEN             0x20   /* Z axis interrupt enable */
#define IEA              0x04   /* Interrupt active */
#define INT_LATCH        0x02   /* Latch interrupt request */
#define IEN              0x01   /* Interrupt enable */

/*
 * INT_SRC
 * - Indicates source of interrupt
 */
#define INT_SRC          0x31
#define PTH_X            0x80   /* +ve x threshold exceeded */
#define PTH_Y            0x40   /* +ve y threshold exceeded */
#define PTH_Z            0x20   /* +ve z threshold exceeded */
#define NTH_X            0x10   /* -ve x threshold exceeded */
#define NTH_Y            0x08   /* +ve y threshold exceeded */
#define NTH_Z            0x04   /* +ve z threshold exceeded */
#define MROI             0x02   /* measurement overflow */
#define INT_EVENT        0x01   /* signals interrupt event */

/*
 * Interrupt threshold
 * - 16-bit unsigned value
 * - Sets absolute value of positive and negative interrupt threshold
 */
#define INT_THS_L        0x32
#define INT_THS_H        0x33
