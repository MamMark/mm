/**
 *  Defines for lis3dh registers for use with its driver's getReg() and setReg().
 *  See p. 26 of the lis3dh datasheet.
 */

#ifndef __LIS3DH_H__
#define __LIS3DH_H__

#define  STATUS_REG_AUX       0x07             // data overrun or new data available

#define  OUT_ADC1_L           0x08
#define  OUT_ADC1_H           0x09
#define  OUT_ADC2_L           0x0A
#define  OUT_ADC2_H           0x0B
#define  OUT_ADC3_L           0x0C
#define  OUT_ADC3_H           0x0D

#define  INT_COUNTER_REG      0x0E
#define  WHO_AM_I             0x0F
#define  TEMP_CFG_REG         0x1F
#define  CTRL_REG1            0x20             // low power enable; enable x,y and z
#define  CTRL_REG2            0x21             // enable on-board filtering & autoreset
#define  CTRL_REG3            0x22             // enable various interrupts
#define  CTRL_REG4            0x23             // scale selection, SPI enable,
                                               // what does high resolution do
#define  CTRL_REG5            0x24             // reboot, fifo/ 4d-6d selection
#define  CTRL_REG6            0x25             // click enabled
#define  REFERENCE            0x26             // reference value for interrupt generation

#define  STATUS_REG2          0x27             // new data for X,Y, Z

#define  OUT_X_L              0x28             // output data, when available
#define  OUT_X_H              0x29
#define  OUT_Y_L              0x2A
#define  OUT_Y_H              0x2B
#define  OUT_Z_L              0x2C
#define  OUT_Z_H              0x2D

#define  FIFO_CTRL_REG        0x2E
#define  FIFO_SRC_REG         0x2F
#define  INT1_CFG             0x30
#define  INT1_SOURCE          0x31
#define  INT1_THS             0x32
#define  INT1_DURATION        0x33
#define  CLICK_CFG            0x38
#define  CLICK_SRC            0x39
#define  CLICK_THS            0x3A
#define  TIME_LIMIT           0x3B
#define  TIME_LATENCY         0x3C
#define  TIME_WINDOW          0x3D

#define  L3DH_MULT            0x40
#define  L3DH_READ            0x80

#define XEN       0x01      // p. 29  CTRL_REG1 bit for x enable
#define YEN       0x20      //                      for y
#define ZEN       0x40      //                      for z
#define LPEN      0x80      //                      for low power enable

#endif  /* __LIS3DH_H__ */
