/* tos/chips/mems/lisxdh.h
 *
 * Copyright (c) 2019-2020, Eric B. Decker
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
 */

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

/*
 * Control and Status Registers
 * X - configuration, set once
 * C - Control, used in normal processing
 * S - Status, used in normal processing
 * R - Result
 *
 * Reg Name     addr    type   default  Description
 * Aux_Status   07                      status for ADC and/or Temp
 * OUT_ADC      08-0D
 * OUT_TEMP     0C-0D
 * WHO_AM_I     0F              0x33
 * CTRL_REG0    1E      X       0x10    sdo_pu config
 * TEMP_CFG     1F              0x00
 * CTRL_REG1    20      C       0x07    main control, ODR, axis enable
 * CTRL_REG2    21              0x00    high pass filter configuration
 * CTRL_REG3    22              0x00    int1 configuration
 * CTRL_REG4    23              0x00    bdu, full scale, high resolution
 * CTRL_REG5    24      C       0x00    fifo en, other int configuration
 * CTRL_REG6    25              0x00    i2 configuration
 * REFERENCE    26              0x00
 * STATUS       27
 * OUT          28-2D   R
 * FIFO_CTRL    2E      C       0x00    FIFO mode, FifoThreshold
 * FIFO_SRC     2F      S               wtm, ovrn, empty, fifo_count
 * INT1_CFG     30              0x00
 * INT1_SRC     31
 * INT1_THS     32              0x00
 * INT1_DUR     33              0x00
 * INT2_CFG     34              0x00
 * INT2_SRC     35
 * INT2_THS     36              0x00
 * INT2_DUR     37              0x00
 * CLICK_CFG    38              0x00
 * CLICK_SRC    39
 * CLICK_THS    3A              0x00
 * TIME_LIMIT   3B              0x00
 * TIME_LATENCY 3C              0x00
 * TIME_WINDOW  3D              0x00
 * ACT_THS      3E              0x00
 * ACT_DUR      3F              0x00
 */

/* Aux status, indicates data available/overrun for Aux Temp or ADC */
#define LISX_STATUS_REG_AUX 0x07
typedef union {
  struct {
    uint8_t rsvd_01         : 2;
    uint8_t tda             : 1;
    uint8_t rsvd_02         : 3;
    uint8_t tor             : 1;
    uint8_t rsvd_03         : 1;
  } x;
  uint8_t bits;
} lis2dh_status_reg_aux_t;

typedef union {
  struct {
    uint8_t stat_1da        : 1;
    uint8_t stat_2da        : 1;
    uint8_t stat_3da        : 1;
    uint8_t stat_321da      : 1;
    uint8_t stat_1OR        : 1;
    uint8_t stat_2OR        : 1;
    uint8_t stat_3OR        : 1;
    uint8_t stat_321OR      : 1;
  } x;
  uint8_t bits;
} lis3dh_status_reg_aux_t;

#define LIS2DH_OUT_TEMP_L   0x0c
#define LIS2DH_OUT_TEMP_H   0x0d

/* Aux ADC output registers */
#define LIS3DH_OUT_ADC1_L   0x08
#define LIS3DH_OUT_ADC1_H   0x09
#define LIS3DH_OUT_ADC2_L   0x0a
#define LIS3DH_OUT_ADC2_H   0x0b
#define LIS3DH_OUT_ADC3_L   0x0c
#define LIS3DH_OUT_ADC3_H   0x0d


/*
 * ID Register.  Validate SPI xfer by reading this
 * register: Value should equal WHO_I_AM.
 *
 * Both the lis3dh and lis2dh return the same ID.
 */
#define LISX_WHO_AM_I       0x0f
#define LISX_WHO_I_AM       0x33


/* Enable bits for Temp sensor */
#define LIS2DH_TEMP_CFG_REG 0x1f
typedef struct {
  uint8_t rsvd_01           : 6;
  uint8_t temp_en           : 2;
} lis2dh12_temp_cfg_reg_t;

#define LIS2DH_TEMP_EN      3


#define LIS3DH_TEMP_CFG_REG 0x1f
typedef union {
  struct {
    uint8_t rsvd_01         : 6;
    uint8_t temp_en         : 1;
    uint8_t adc_en          : 1;
  } x;
  uint8_t bits;
} lis3dh_temp_cfg_reg_t;

#define LIS3DH_TEMP_EN 1
#define LIS3DH_ADC_EN  1


/*
 * Reg0, SDO_PU disconnect
 * rsvd_01 must be set to 0x10 (0b0010000) for proper operation.
 */
#define LISX_CTRL_REG0      0x1e
typedef union {
  struct {
    uint8_t rsvd_01         : 7;
    uint8_t sdo_pu_disc     : 1;
  } x;
  uint8_t bits;
} lisx_ctrl_reg0_t;

#define LISX_REG0_RSVD_01   0x10


/*
 * CTRL_REG1
 * turns on axises, and set output data rate (ODR).
 * Setting ODR to 0 puts the chip in Power-down mode (draws about .5uA).
 */
#define LISX_CTRL_REG1      0x20
typedef union {
  struct {
    uint8_t xen             : 1;
    uint8_t yen             : 1;
    uint8_t zen             : 1;
    uint8_t lpen            : 1;
    uint8_t odr             : 4;
  } x;
  uint8_t bits;
} lisx_ctrl_reg1_t;

#define  LISX_ODR_OFF       0   /* Sets power down mode */
#define  LISX_ODR_1HZ       1   /* Output data rate: 1Hz */
#define  LISX_ODR_10HZ      2   /* Output data rate: 10Hz */
#define  LISX_ODR_25HZ      3   /* 25Hz */
#define  LISX_ODR_50HZ      4   /* 50Hz */
#define  LISX_ODR_100HZ     5   /* 100Hz */
#define  LISX_ODR_200HZ     6   /* 200Hz */
#define  LISX_ODR_400HZ     7   /* 400Hz */
#define  LISX_ODR_1K600HZ   8   /* 1.6KHz: Low power mode only */
#define  LISX_ODR_1K250HZ   9   /* 1.25KHz: Normal mode only */
#define  LISX_ODR_5KHZ      9   /* 5KHz: Low power mode only */

/*
 * CTRL_REG2
 * Configure high pass filtering
 */
#define LISX_CTRL_REG2      0x21
typedef union {
  struct {
    uint8_t hp_ia1          : 1;
    uint8_t hp_ia2          : 1;
    uint8_t hp_click        : 1;
    uint8_t fds             : 1;
    uint8_t hpcf            : 2;
    uint8_t hpm             : 2;
  } x;
  uint8_t bits;
} lisx_ctrl_reg2_t;


/*
 * CTRL_REG3
 * Configure interrupts. All interrupts are disabled by default.
 */
#define LISX_CTRL_REG3      0x22
typedef union {
  struct {
    uint8_t rsvd_01         : 1;
    uint8_t i1_overrun      : 1;
    uint8_t i1_wtm          : 1;
    uint8_t i1_321da        : 1;
    uint8_t i1_zyxda        : 1;
    uint8_t i1_ia2          : 1;
    uint8_t i1_ia1          : 1;
    uint8_t i1_click        : 1;
  } x;
  uint8_t bits;
} lisx_ctrl_reg3_t;


/*
 * CTRL_REG4
 * Accel data sampling configuration.
 * Note on BDU: When enabled, BDU makes sure that the High/Low pairs
 * for each axis are from the same sample. For example if youread OUT_X_L
 * then OUT_X_H will not be updated until its also been read.
 */
#define LISX_CTRL_REG4      0x23
typedef union {
  struct {
    uint8_t sim             : 1;
    uint8_t st              : 2;
    uint8_t hr              : 1;
    uint8_t fs              : 2;
    uint8_t ble             : 1;
    uint8_t bdu             : 1;
  } x;
  uint8_t bits;
} lisx_ctrl_reg4_t;

#define LISX_STMODE_OFF     0	/* Self test disabled */
#define LISX_STMODE_1       1	/* Self test mode 0 */
#define LISX_STMODE_2       2	/* Self test mode 1 */

#define LISX_FS_2G          0	/* FS = +- 2G */
#define LISX_FS_4G          1	/* FS = +- 4G */
#define LISX_FS_8G          2	/* FS = +- 8G */
#define LISX_FS_16G         3	/* FS = +- 16G */

#define LISX_CTRL_REG5      0x24
typedef union {
  struct {
    uint8_t d4d_int2        : 1;
    uint8_t lir_int2        : 1;
    uint8_t d4d_int1        : 1;
    uint8_t lir_int1        : 1;
    uint8_t rsvd_01         : 2;
    uint8_t fifo_en         : 1;
    uint8_t boot            : 1;
  } x;
  uint8_t bits;
} lisx_ctrl_reg5_t;

#define LISX_CTRL_REG6      0x25
typedef union {
  struct {
    uint8_t rsvd_01         : 1;
    uint8_t int_polarity    : 1;
    uint8_t rsvd_02         : 1;
    uint8_t i2_act          : 1;
    uint8_t i2_boot         : 1;
    uint8_t i2_ia2          : 1;
    uint8_t i2_ia1          : 1;
    uint8_t i2_click        : 1;
  } x;
  uint8_t bits;
} lisx_ctrl_reg6_t;

#define LISX_REFERENCE      0x26

/*
 * STATUS_REG
 * Used to sample Data Available or Overrun on Accel X, Y, Z Axes.
 */
#define LISX_STATUS_REG     0x27
typedef union {
  struct {
    uint8_t xda             : 1;
    uint8_t yda             : 1;
    uint8_t zda             : 1;
    uint8_t zyxda           : 1;
    uint8_t _xor            : 1;
    uint8_t yor             : 1;
    uint8_t zor             : 1;
    uint8_t zyxor           : 1;
  } x;
  uint8_t bits;
} lisx_status_reg_t;

/*
 * Accel X, Y and Z data registers
 */
#define LISX_OUT_X_L        0x28
#define LISX_OUT_X_H        0x29
#define LISX_OUT_Y_L        0x2a
#define LISX_OUT_Y_H        0x2b
#define LISX_OUT_Z_L        0x2c
#define LISX_OUT_Z_H        0x2d

/*
 * FIFO_CTRL_REG
 * Used to control FIFO mode and watermark threshold.
 */
#define LISX_FIFO_CTRL_REG  0x2e
typedef union {
  struct {
    uint8_t fth             : 5;
    uint8_t tr              : 1;
    uint8_t fm              : 2;
  } x;
  uint8_t bits;
} lisx_fifo_ctrl_reg_t;

#define LISX_FIFO_BYPASS    0
#define LISX_FIFO_MODE      1
#define LISX_FIFO_STREAM    2
#define LISX_FIFO_TRIG      3

/*
 * FIFO_SRC_REG
 * Provides FIFO status: Count of samples in FIFO buffer, whether
 * watermark is exceeded and whether FIFO is full or empty.
 */
#define LISX_FIFO_SRC_REG   0x2f
typedef union {
  struct {
    uint8_t fss             : 5;
    uint8_t empty           : 1;
    uint8_t ovrn_fifo       : 1;
    uint8_t wtm             : 1;
  } x;
  uint8_t bits;
} lisx_fifo_src_reg_t;


/*
 * The lis2dh and lis3dh have a fifo that has 32 elements and
 * control cells that are 5 bits.
 */
#define LISX_FIFO_SIZE      32

/*
 * INT1_CFG
 * Control interrupt generation on thresold of direction change
 */
#define LISX_INT1_CFG       0x30
typedef union {
  struct {
    uint8_t xlie            : 1;
    uint8_t xhie            : 1;
    uint8_t ylie            : 1;
    uint8_t yhie            : 1;
    uint8_t zlie            : 1;
    uint8_t zhie            : 1;
    uint8_t int_6d          : 1;
    uint8_t aoi             : 1;
  } x;
  uint8_t bits;
} lisx_int1_cfg_t;

/*
 * INT1_SOURCE
 * interrupt1 status
 */
#define LISX_INT1_SRC       0x31
typedef union {
  struct {
    uint8_t xl              : 1;
    uint8_t xh              : 1;
    uint8_t yl              : 1;
    uint8_t yh              : 1;
    uint8_t zl              : 1;
    uint8_t zh              : 1;
    uint8_t ia              : 1;
    uint8_t rsvd_01         : 1;
  } x;
  uint8_t bits;
} lisx_int1_src_t;


/*
 * More interrupt controls
 */
#define LISX_INT1_THS       0x32
#define LISX_INT1_DURATION  0x33

/* int2 configuration */
#define LISX_INT2_CFG       0x34
typedef union {
  struct {
    uint8_t xlie            : 1;
    uint8_t xhie            : 1;
    uint8_t ylie            : 1;
    uint8_t yhie            : 1;
    uint8_t zlie            : 1;
    uint8_t zhie            : 1;
    uint8_t int_6d          : 1;
    uint8_t aoi             : 1;
  } x;
  uint8_t bits;
} lisx_int2_cfg_t;


#define LISX_INT2_SRC       0x35
typedef union {
  struct {
    uint8_t xl              : 1;
    uint8_t xh              : 1;
    uint8_t yl              : 1;
    uint8_t yh              : 1;
    uint8_t zl              : 1;
    uint8_t zh              : 1;
    uint8_t ia              : 1;
    uint8_t rsvd_01         : 1;
  } x;
  uint8_t bits;
} lisx_int2_src_t;

#define LISX_INT2_THS       0x36
#define LISX_INT2_DURATION  0x37

#define LISX_CLICK_CFG      0x38
typedef union {
  struct {
    uint8_t xs              : 1;
    uint8_t xd              : 1;
    uint8_t ys              : 1;
    uint8_t yd              : 1;
    uint8_t zs              : 1;
    uint8_t zd              : 1;
    uint8_t rsvd_01         : 2;
  } x;
  uint8_t bits;
} lisx_click_cfg_t;

#define LISX_CLICK_SRC      0x39
typedef union {
  struct {
    uint8_t x               : 1;
    uint8_t y               : 1;
    uint8_t z               : 1;
    uint8_t sign            : 1;
    uint8_t sclick          : 1;
    uint8_t dclick          : 1;
    uint8_t ia              : 1;
    uint8_t rsvd_01         : 1;
  } x;
  uint8_t bits;
} lisx_click_src_t;

#define LISX_CLICK_THS      0x3a
#define LISX_TIME_LIMIT     0x3b
#define LISX_TIME_LATENCY   0x3c
#define LISX_TIME_WINDOW    0x3d
#define LISX_ACT_THS        0x3e
#define LISX_ACT_DUR        0x3f

#endif /* __LISXDH_H__ */
