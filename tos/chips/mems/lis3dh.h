/*
 * lis3dh.h
 */

#define READ_REG         0x80
#define WRITE_REG        0x00
#define MULT_ADDR        0x40
#define SINGLE_ADDR      0x00

#define STATUS_REG_AUX   0x07
#define STAT_1DA         0x01
#define STAT_2DA         0x02
#define STAT_3DA         0x04
#define STAT_321DA       0x08
#define STAT_1OR         0x10
#define STAT_2OR         0x20
#define STAT_3OR         0x40
#define STAT_321OR       0x80

#define OUT_1_L          0x08
#define OUT_1_H          0x09
#define OUT_2_L          0x0a
#define OUT_2_H          0x0b
#define OUT_3_L          0x0c
#define OUT_3_H          0x0d

#define INT_COUNTER_REG  0x0e

#define WHO_AM_I         0x0f
#define WHO_I_AM         0x33

#define TEMP_CFG_REG     0x1f
#define TEMP_EN          0x40
#define ADC_PD           0x80

#define CTRL_REG1        0x20
#define XEN              0x01
#define YEN              0x02
#define ZEN              0x04
#define LPEN             0x08
#define ODR              0xf0

#define CTRL_REG2        0x21
#define HPIS1            0x01
#define HPIS2            0x02
#define HPCLICK          0x04
#define FDS              0x08
#define HPCF             0x30
#define HPM              0xc0

#define CTRL_REG3        0x22
#define I1OVERRUN        0x02
#define I1WTM            0x04
#define I1DRDY2          0x08
#define I1DRDY1          0x10
#define I1AOI2           0x20
#define I1AOI1           0x40
#define I1CLICK          0x80

#define CTRL_REG4        0x23
#define SIM              0x01
#define STMODE           0x06
#define HR               0x08
#define FS               0x30
#define BLE              0x40
#define BDU              0x80

#define ST_NORMAL        0x00
#define ST1              0x02
#define ST2              0x04

#define CTRL_REG5        0x24
#define D4D_INT1         0x04
#define LIR_INT1         0x08
#define FIFO_EN          0x40
#define BOOT             0x80

#define CTRL_REG6        0x25
#define H_LACTIVE        0x02
#define BOOT_I1          0x10
#define I2_INT1          0x40
#define I2_CLICKEN       0x80

#define REFERENCE        0x26

#define STATUS_REG2      0x27
#define XDA              0x01
#define YDA              0x02
#define ZDA              0x04
#define XYZDA            0x08
#define XOR              0x10
#define YOR              0x20
#define ZOR              0x40
#define XYZOR            0x80

#define OUT_X_L          0x28
#define OUT_X_H          0x29
#define OUT_Y_L          0x2a
#define OUT_Y_H          0x2b
#define OUT_Z_L          0x2c
#define OUT_Z_H          0x2d

#define FIFO_CTRL_REG    0x2e
#define FTH              0x1f
#define TRIG_SEL         0x20
#define FIFO_MODE_SEL    0xc0

#define FIFO_BYPASS      0x00
#define FIFO_MODE        0x40
#define FIFO_STREAM      0x80
#define FIFO_TRIG        0xc0

#define FIFO_SRC_REG     0x2f
#define FSS              0x1F
#define OVRN_FIFO        0x40
#define WTM              0x80

#define INT1_CFG         0x30
#define XLIE             0x01
#define XHIE             0x02
#define YLIE             0x04
#define YHIE             0x08
#define ZLIE             0x10
#define ZHIE             0x20
#define INT_6D           0x40
#define AOI              0x80

#define INT1_SOURCE      0x31
#define XL               0x01
#define XH               0x02
#define YL               0x04
#define YH               0x08
#define ZL               0x10
#define ZH               0x20
#define IA               0x40

#define INT1_THS         0x32
#define INT1_DURATION    0x33

#define CLICK_CFG        0x38
#define CLICK_SRC        0x39
#define CLICK_THS        0x3a
#define TIME_LIMIT       0x3b
#define TIME_LATENCY     0x3c
#define TIME_WINDOW      0x3d


