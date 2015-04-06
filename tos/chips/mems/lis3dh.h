/*
 * lis3dh.h
 */

/* SPI Flag Bits */
#define READ_REG         0x80
#define WRITE_REG        0x00
#define MULT_ADDR        0x40
#define SINGLE_ADDR      0x00

/* Aux register indicates data available or overrun for the Aux ADC */
#define STATUS_REG_AUX   0x07
#define STAT_1DA         0x01
#define STAT_2DA         0x02
#define STAT_3DA         0x04
#define STAT_321DA       0x08
#define STAT_1OR         0x10
#define STAT_2OR         0x20
#define STAT_3OR         0x40
#define STAT_321OR       0x80

/* Aux ADC output registers */
#define OUT_ADC1_L       0x08
#define OUT_ADC1_H       0x09
#define OUT_ADC2_L       0x0a
#define OUT_ADC2_H       0x0b
#define OUT_ADC3_L       0x0c
#define OUT_ADC3_H       0x0d


#define INT_COUNTER_REG  0x0e

/* 
 * Register with ID value. Validate SPI xfer by reading this
 * register: Value should equal WHO_I_AM.
 */
#define WHO_AM_I         0x0f
#define WHO_I_AM         0x33

/* Enable bits for Temp sensor and Aux ADC */
#define TEMP_CFG_REG     0x1f
#define TEMP_EN          0x40	/* Temp sensor enable */
#define ADC_PD           0x80	/* Aux ADC enable */

/*
 * CTRL_REG1
 * Use to enable to Accel ADC and set output data rate.
 * Setting ODR to 0 puts the chip in Power-down mode (draws about .5uA).
 */
#define CTRL_REG1        0x20
#define XEN              0x01	/* Accel X axis enable */
#define YEN              0x02	/* Accel Y axis enable */
#define ZEN              0x04	/* Accel Z axis enable */
#define LPEN             0x08	/* Low power mode enable */
#define ODR_MASK         0xf0	/* Output data rate mask */
#define  ODR_OFF         0x00	/* Sets power down mode */
#define  ODR_1HZ         0x10	/* Output data rate: 1Hz */
#define  ODR_10HZ        0x20	/* Output data rate: 10Hz */
#define  ODR_25HZ        0x30	/* 25Hz */
#define  ODR_50HZ        0x40	/* 50Hz */
#define  ODR_100HZ       0x50	/* 100Hz */
#define  ODR_200HZ       0x60	/* 200Hz */
#define  ODR_400HZ       0x70	/* 400Hz */
#define  ODR_1K600HZ	 0x80	/* 1.6KHz: Low power mode only */
#define  ODR_1K250HZ	 0x90	/* 1.25KHz: Normal mode only */
#define  ODR_5KHZ	 0x90	/* 5KHz: Low power mode only */

/*
 * CTRL_REG2
 * Configure high pass filtering
 */
#define CTRL_REG2        0x21
#define HPIS1            0x01
#define HPIS2            0x02
#define HPCLICK          0x04
#define FDS              0x08
#define HPCF             0x30
#define HPM              0xc0

/*
 * CTRL_REG3
 * Configure interrupts. All interrupts are disabled by default.
 */
#define CTRL_REG3        0x22
#define I1OVERRUN        0x02
#define I1WTM            0x04
#define I1DRDY2          0x08
#define I1DRDY1          0x10
#define I1AOI2           0x20
#define I1AOI1           0x40
#define I1CLICK          0x80

/*
 * CTRL_REG4
 * Accel data sampling configuration.
 * Note on BDU: When enabled, BDU makes sure that the High/Low pairs
 * for each axis are from the same sample. For example if youread OUT_X_L
 * then OUT_X_H will not be updated until its also been read.
 */
#define CTRL_REG4        0x23
#define SIM              0x01	/* Serial mode: 0:4-wire, 1:3-wire */
#define STMODE_MASK      0x06	/* Self test mask */
#define  STMODE_DISABLE  0x00	/* Self test disabled */
#define  STMODE_1        0x02	/* Self test mode 0 */
#define  STMODE_2        0x04	/* Self test mode 1 */
#define HR               0x08	/* High Res output. Enable for normal mode */
#define FS_MASK          0x30	/* Full-scale selection mask */
#define  FS_2G           0x00	/* FS = +- 2G */
#define  FS_4G           0x10	/* FS = +- 4G */
#define  FS_8G           0x20	/* FS = +- 8G */
#define  FS_16G          0x30	/* FS = +- 16G */
#define BLE              0x40	/* Big/Little Endian: 0:LE, 1:BE */
#define BDU              0x80	/* Block Data Update enable */

#define CTRL_REG5        0x24
#define D4D_INT1         0x04
#define LIR_INT1         0x08
#define FIFO_EN          0x40	/* Enable FIFO. Default = 0 (disabled) */
#define BOOT             0x80

#define CTRL_REG6        0x25
#define H_LACTIVE        0x02
#define BOOT_I1          0x10
#define I2_INT1          0x40
#define I2_CLICKEN       0x80

#define REFERENCE        0x26

/*
 * STATUS_REG
 * Used to sample Data Available or Overrun on Accel X, Y, Z Axes.
 */
#define STATUS_REG       0x27
#define XDA              0x01	/* X Axis new data available */
#define YDA              0x02	/* Y Axis new data available */
#define ZDA              0x04	/* Z Axis new data available */
#define XYZDA            0x08	/* XYZ Axes data available */
#define XOR              0x10	/* X Axis data overwritten */
#define YOR              0x20	/* Y Axis data overwritten */
#define ZOR              0x40	/* Z Axis data overwritten */
#define XYZOR            0x80	/* XYZ Axes data overwritten */

/*
 * Accel X, Y and Z data registers
 */
#define OUT_X_L          0x28
#define OUT_X_H          0x29
#define OUT_Y_L          0x2a
#define OUT_Y_H          0x2b
#define OUT_Z_L          0x2c
#define OUT_Z_H          0x2d

/*
 * FIFO_CTRL_REG
 * Used to control FIFO mode and watermark threshold.
 */
#define FIFO_CTRL_REG    0x2e
#define FTH              0x1f	/* FIFO watermark thresold value */
#define TRIG_SEL         0x20	/* Trigger select: 0=INT1, 1=INT2 */
#define FIFO_MODE_MASK   0xc0	/* FIFO mode selection mask */
#define  FIFO_BYPASS     0x00
#define  FIFO_MODE       0x40
#define  FIFO_STREAM     0x80
#define  FIFO_TRIG       0xc0

/*
 * FIFO_SRC_REG
 * Provides FIFO status: Count of samples in FIFO buffer, whether
 * watermark is exceeded and whether FIFO is full or empty.
 */
#define FIFO_SRC_REG     0x2f
#define FSS_MASK         0x1f	/* FIFO sample count mask */
#define EMPTY            0x20	/* FIFO empty flag */
#define OVRN_FIFO        0x40	/* FIFO overrun flag */
#define WTM              0x80	/* FIFO watermark exceeded flag */

/*
 * INT1_CFG
 * Control interrupt generation on thresold of direction change
 */
#define INT1_CFG         0x30
#define XLIE             0x01
#define XHIE             0x02
#define YLIE             0x04
#define YHIE             0x08
#define ZLIE             0x10
#define ZHIE             0x20
#define INT_6D           0x40
#define AOI              0x80

/*
 * INT1_SOURCE
 * Check interrupt status
 */
#define INT1_SOURCE      0x31
#define XL               0x01
#define XH               0x02
#define YL               0x04
#define YH               0x08
#define ZL               0x10
#define ZH               0x20
#define IA               0x40

/*
 * More interrupt controls
 */
#define INT1_THS         0x32
#define INT1_DURATION    0x33
#define CLICK_CFG        0x38
#define CLICK_SRC        0x39
#define CLICK_THS        0x3a
#define TIME_LIMIT       0x3b
#define TIME_LATENCY     0x3c
#define TIME_WINDOW      0x3d


