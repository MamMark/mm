/*
 * lisxdh.h
 * updated from ST Micro public source.
 *
 * Include file for STMicroelectronics, lis2dh and lis3dh accelerometers.
 *
 * The lis3dh is a superset of the lis2dh.  The lis3dh includes 3 ADC
 * channels and a temp sensor wired into the 3rd ADC channel.
 */

#ifndef __LISXDH_H__
#define __LISXDH_H__

#ifdef __cplusplus
  extern "C" {
#endif

/* Aux register indicates data available or overrun for the Aux ADC */
#define LISX_STATUS_REG_AUX 0x07

typedef struct {
  uint8_t rsvd_01           : 2;
  uint8_t tda               : 1;
  uint8_t rsvd_02           : 3;
  uint8_t tor               : 1;
  uint8_t rsvd_03           : 1;
} lis2dh12_status_reg_aux_t;

typedef struct {
  uint8_t stat_1da          : 1;
  uint8_t stat_2da          : 1;
  uint8_t stat_3da          : 1;
  uint8_t stat_321da        : 1;
  uint8_t stat_1OR          : 1;
  uint8_t stat_2OR          : 1;
  uint8_t stat_3OR          : 1;
  uint8_t stat_321OR        : 1;
} lis3dh_status_reg_aux_t;

/* Aux ADC output registers */
#define LIS3DH_OUT_ADC1_L   0x08
#define LIS3DH_OUT_ADC1_H   0x09
#define LIS3DH_OUT_ADC2_L   0x0a
#define LIS3DH_OUT_ADC2_H   0x0b
#define LIS3DH_OUT_ADC3_L   0x0c
#define LIS3DH_OUT_ADC3_H   0x0d

#define LIS2DH_OUT_TEMP_L   0x0c
#define LIS2DH_OUT_TEMP_H   0x0d

/*
 * Register with ID value. Validate SPI xfer by reading this
 * register: Value should equal WHO_I_AM.
 *
 * Both the lis3dh and lis2dh return the same ID.
 */
#define LISX_WHO_AM_I       0x0f
#define WHO_I_AM            0x33

#define LIS2DH_CTRL_REG0    0x1e

typedef struct {
  uint8_t rsvd_01           : 7;
  uint8_t sdo_pu_disc       : 1;
} lis2dh12_ctrl_reg0_t;


/* Enable bits for Temp sensor and Aux ADC */
#define LISX_TEMP_CFG_REG   0x1f

typedef struct {
  uint8_t rsvd_01           : 6;
  uint8_t temp_en           : 2;
} lis2dh12_temp_cfg_reg_t;

typedef struct {
  uint8_t rsvd_01           : 6;
  uint8_t temp_en           : 1;
  uint8_t adc_en            : 1;
} lis3dh_temp_cfg_reg_t;


/*
 * CTRL_REG1
 * Use to enable to Accel ADC and set output data rate.
 * Setting ODR to 0 puts the chip in Power-down mode (draws about .5uA).
 */
#define LISX_CTRL_REG1      0x20

typedef struct {
  uint8_t xen               : 1;
  uint8_t yen               : 1;
  uint8_t zen               : 1;
  uint8_t lpen              : 1;
  uint8_t odr               : 4;
} lisx_ctrl_reg1_t;

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
#define LISX_CTRL_REG2      0x21

typedef struct {
  uint8_t hp_ia1            : 1;
  uint8_t hp_ia2            : 1;
  uint8_t hp_click          : 1;
  uint8_t fds               : 1;
  uint8_t hpcf              : 2;
  uint8_t hpm               : 2;
} lisx_ctrl_reg2_t;


/*
 * CTRL_REG3
 * Configure interrupts. All interrupts are disabled by default.
 */
#define LISX_CTRL_REG3      0x22

typedef struct {
  uint8_t rsvd_01           : 1;
  uint8_t i1_overrun        : 1;
  uint8_t i1_wtm            : 1;
  uint8_t i1_321da          : 1;
  uint8_t i1_zyxda          : 1;
  uint8_t i1_ia2            : 1;
  uint8_t i1_ia1            : 1;
  uint8_t i1_click          : 1;
} lisx_ctrl_reg3_t;


/*
 * CTRL_REG4
 * Accel data sampling configuration.
 * Note on BDU: When enabled, BDU makes sure that the High/Low pairs
 * for each axis are from the same sample. For example if youread OUT_X_L
 * then OUT_X_H will not be updated until its also been read.
 */
#define LISX_CTRL_REG4      0x23

typedef struct {
  uint8_t sim               : 1;
  uint8_t st                : 2;
  uint8_t hr                : 1;
  uint8_t fs                : 2;
  uint8_t ble               : 1;
  uint8_t bdu               : 1;
} lisx_ctrl_reg4_t;

#define STMODE_MASK      0x06	/* Self test mask */
#define  STMODE_DISABLE  0x00	/* Self test disabled */
#define  STMODE_1        0x02	/* Self test mode 0 */
#define  STMODE_2        0x04	/* Self test mode 1 */

#define FS_MASK          0x30	/* Full-scale selection mask */
#define  FS_2G           0x00	/* FS = +- 2G */
#define  FS_4G           0x10	/* FS = +- 4G */
#define  FS_8G           0x20	/* FS = +- 8G */
#define  FS_16G          0x30	/* FS = +- 16G */

#define LISX_CTRL_REG5   0x24

typedef struct {
  uint8_t d4d_int2          : 1;
  uint8_t lir_int2          : 1;
  uint8_t d4d_int1          : 1;
  uint8_t lir_int1          : 1;
  uint8_t rsvd_01           : 2;
  uint8_t fifo_en           : 1;
  uint8_t boot              : 1;
} lisx_ctrl_reg5_t;

#define LISX_CTRL_REG6      0x25

typedef struct {
  uint8_t rsvd_01           : 1;
  uint8_t int_polarity      : 1;
  uint8_t rsvd_02           : 1;
  uint8_t i2_act            : 1;
  uint8_t i2_boot           : 1;
  uint8_t i2_ia2            : 1;
  uint8_t i2_ia1            : 1;
  uint8_t i2_click          : 1;
} lisx_ctrl_reg6_t;

#define LISX_REFERENCE      0x26

/*
 * STATUS_REG
 * Used to sample Data Available or Overrun on Accel X, Y, Z Axes.
 */
#define LISX_STATUS_REG     0x27

typedef struct {
  uint8_t xda               : 1;
  uint8_t yda               : 1;
  uint8_t zda               : 1;
  uint8_t zyxda             : 1;
  uint8_t _xor              : 1;
  uint8_t yor               : 1;
  uint8_t zor               : 1;
  uint8_t zyxor             : 1;
} lisx_status_reg_t;

/*
 * Accel X, Y and Z data registers
 */
#define OUT_X_L             0x28
#define OUT_X_H             0x29
#define OUT_Y_L             0x2a
#define OUT_Y_H             0x2b
#define OUT_Z_L             0x2c
#define OUT_Z_H             0x2d

/*
 * FIFO_CTRL_REG
 * Used to control FIFO mode and watermark threshold.
 */
#define FIFO_CTRL_REG    0x2e

typedef struct {
  uint8_t fth               : 5;
  uint8_t tr                : 1;        /* 0 - int1, 1 - int 2 */
  uint8_t fm                : 2;
} lisx_fifo_ctrl_reg_t;

#define LISX_FIFO_MODE_MASK 0xc0	/* FIFO mode selection mask */
#define  LISX_FIFO_BYPASS   0x00
#define  LISX_FIFO_MODE     0x40
#define  LISX_FIFO_STREAM   0x80
#define  LISX_FIFO_TRIG     0xc0

/*
 * FIFO_SRC_REG
 * Provides FIFO status: Count of samples in FIFO buffer, whether
 * watermark is exceeded and whether FIFO is full or empty.
 */
#define LISX_FIFO_SRC_REG   0x2f

typedef struct {
  uint8_t fss               : 5;
  uint8_t empty             : 1;
  uint8_t ovrn_fifo         : 1;
  uint8_t wtm               : 1;
} lisx_fifo_src_reg_t;

/*
 * INT1_CFG
 * Control interrupt generation on thresold of direction change
 */
#define LISX_INT1_CFG       0x30

typedef struct {
  uint8_t xlie              : 1;
  uint8_t xhie              : 1;
  uint8_t ylie              : 1;
  uint8_t yhie              : 1;
  uint8_t zlie              : 1;
  uint8_t zhie              : 1;
  uint8_t int_6d            : 1;
  uint8_t aoi               : 1;
} lisx_int1_cfg_t;

/*
 * INT1_SOURCE
 * Check interrupt status
 */
#define LISX_INT1_SRC       0x31

typedef struct {
  uint8_t xl                : 1;
  uint8_t xh                : 1;
  uint8_t yl                : 1;
  uint8_t yh                : 1;
  uint8_t zl                : 1;
  uint8_t zh                : 1;
  uint8_t ia                : 1;
  uint8_t rsvd_01           : 1;
} lisx_int1_src_t;


/*
 * More interrupt controls
 */
#define LISX_INT1_THS       0x32
#define LISX_INT1_DURATION  0x33

#define LISX_INT2_CFG       0x34

typedef struct {
  uint8_t xlie              : 1;
  uint8_t xhie              : 1;
  uint8_t ylie              : 1;
  uint8_t yhie              : 1;
  uint8_t zlie              : 1;
  uint8_t zhie              : 1;
  uint8_t int_6d            : 1;
  uint8_t aoi               : 1;
} lisx_int2_cfg_t;


#define LISX_INT2_SRC       0x35

typedef struct {
  uint8_t xl                : 1;
  uint8_t xh                : 1;
  uint8_t yl                : 1;
  uint8_t yh                : 1;
  uint8_t zl                : 1;
  uint8_t zh                : 1;
  uint8_t ia                : 1;
  uint8_t rsvd_01           : 1;
} lisx_int2_src_t;

#define LISX_INT2_THS       0x36
#define LISX_INT2_DURATION  0x37

#define LISX_CLICK_CFG      0x38

typedef struct {
  uint8_t xs                : 1;
  uint8_t xd                : 1;
  uint8_t ys                : 1;
  uint8_t yd                : 1;
  uint8_t zs                : 1;
  uint8_t zd                : 1;
  uint8_t rsvd_01           : 2;
} lisx_click_cfg_t;

#define LISX_CLICK_SRC      0x39

typedef struct {
  uint8_t x                 : 1;
  uint8_t y                 : 1;
  uint8_t z                 : 1;
  uint8_t sign              : 1;
  uint8_t sclick            : 1;
  uint8_t dclick            : 1;
  uint8_t ia                : 1;
  uint8_t rsvd_01           : 1;
} lisx_click_src_t;

#define LISX_CLICK_THS      0x3a
#define LISX_TIME_LIMIT     0x3b
#define LISX_TIME_LATENCY   0x3c
#define LISX_TIME_WINDOW    0x3d
#define LISX_ACT_THS        0x3e
#define LISX_ACT_DUR        0x3f

#endif /* __LISXDH_H__ */
