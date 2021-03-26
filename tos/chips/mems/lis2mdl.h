/* tos/chips/mems/lis2mdl.h
 *
 * Copyright (c) 2021, Eric B. Decker
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
 * lis2mdl.h
 *
 * Include file for STMicro LIS2MDL magnetometer.
 *
 * Mostly copied from STMicro open source:
 *   https://github.com/STMicroelectronics/STMems_Standard_C_drivers.git
 *     master/lis2mdl_STdC/driver/lis2mdl_reg.h
 */

#ifndef __LIS2MDL_H__
#define __LIS2MDL_H__

/** I2C Device Address 8 bit format **/
#define LIS2MDL_ADDR                    0x3CU

/** Device Identification (Who am I) **/
#define LIS2MDL_ID                      0x40U

#define LIS2MDL_OFFSET_X_REG_L          0x45U
#define LIS2MDL_OFFSET_X_REG_H          0x46U
#define LIS2MDL_OFFSET_Y_REG_L          0x47U
#define LIS2MDL_OFFSET_Y_REG_H          0x48U
#define LIS2MDL_OFFSET_Z_REG_L          0x49U
#define LIS2MDL_OFFSET_Z_REG_H          0x4AU
#define LIS2MDL_WHO_AM_I                0x4FU

#define LIS2MDL_CFG_REG_A               0x60U
typedef union {
  struct {
    uint8_t md                     : 2;
    uint8_t odr                    : 2;
    uint8_t lp                     : 1;
    uint8_t soft_rst               : 1;
    uint8_t reboot                 : 1;
    uint8_t comp_temp_en           : 1;
  } x;
  uint8_t bits;
} lis2mdl_cfg_reg_a_t;

#define LIS2MDL_CFG_REG_B               0x61U
typedef union {
  struct {
    uint8_t lpf                    : 1;
    uint8_t set_rst                : 2; /* OFF_CANC + Set_FREQ */
    uint8_t int_on_dataoff         : 1;
    uint8_t off_canc_one_shot      : 1;
    uint8_t not_used_01            : 3;
  } x;
  uint8_t bits;
} lis2mdl_cfg_reg_b_t;

#define LIS2MDL_CFG_REG_C               0x62U
typedef union {
  struct {
    uint8_t drdy_on_pin            : 1;
    uint8_t self_test              : 1;
    uint8_t _4wspi                 : 1;
    uint8_t ble                    : 1;
    uint8_t bdu                    : 1;
    uint8_t i2c_dis                : 1;
    uint8_t int_on_pin             : 1;
    uint8_t not_used_02            : 1;
  } x;
  uint8_t bits;
} lis2mdl_cfg_reg_c_t;

#define LIS2MDL_INT_CRTL_REG            0x63U
typedef union {
  struct {
    uint8_t ien                    : 1;
    uint8_t iel                    : 1;
    uint8_t iea                    : 1;
    uint8_t not_used_01            : 2;
    uint8_t zien                   : 1;
    uint8_t yien                   : 1;
    uint8_t xien                   : 1;
  } x;
  uint8_t bits;
} lis2mdl_int_crtl_reg_t;

#define LIS2MDL_INT_SOURCE_REG          0x64U
typedef union {
  struct {
    uint8_t _int                   : 1;
    uint8_t mroi                   : 1;
    uint8_t n_th_s_z               : 1;
    uint8_t n_th_s_y               : 1;
    uint8_t n_th_s_x               : 1;
    uint8_t p_th_s_z               : 1;
    uint8_t p_th_s_y               : 1;
    uint8_t p_th_s_x               : 1;
  } x;
  uint8_t bits;
} lis2mdl_int_source_reg_t;

#define LIS2MDL_INT_THS_L_REG           0x65U
#define LIS2MDL_INT_THS_H_REG           0x66U

#define LIS2MDL_STATUS_REG              0x67U
typedef union {
  struct {
    uint8_t xda                    : 1;
    uint8_t yda                    : 1;
    uint8_t zda                    : 1;
    uint8_t zyxda                  : 1;
    uint8_t _xor                   : 1;
    uint8_t yor                    : 1;
    uint8_t zor                    : 1;
    uint8_t zyxor                  : 1;
  } x;
  uint8_t bits;
} lis2mdl_status_reg_t;

#define LIS2MDL_OUTX_L_REG              0x68U
#define LIS2MDL_OUTX_H_REG              0x69U
#define LIS2MDL_OUTY_L_REG              0x6AU
#define LIS2MDL_OUTY_H_REG              0x6BU
#define LIS2MDL_OUTZ_L_REG              0x6CU
#define LIS2MDL_OUTZ_H_REG              0x6DU
#define LIS2MDL_TEMP_OUT_L_REG          0x6EU
#define LIS2MDL_TEMP_OUT_H_REG          0x6FU

typedef enum {
  LIS2MDL_CONTINUOUS_MODE  = 0,
  LIS2MDL_SINGLE_TRIGGER   = 1,
  LIS2MDL_POWER_DOWN       = 2,
} lis2mdl_md_t;

typedef enum {
  LIS2MDL_ODR_10Hz   = 0,
  LIS2MDL_ODR_20Hz   = 1,
  LIS2MDL_ODR_50Hz   = 2,
  LIS2MDL_ODR_100Hz  = 3,
} lis2mdl_odr_t;

#endif /* __LIS2MDL_H__ */

