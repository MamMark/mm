/* tos/chips/mems/lsm6dsox.h
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
 * lsm6dsox.h
 *
 * Include file for STMicro LSM6DSOX complex sensor (gyro/accel plus
 * sensor hub (4 additional i2c)).
 *
 * Mostly copied from STMicro open source:
 *   https://github.com/STMicroelectronics/STMems_Standard_C_drivers.git
 *     master/lsm6dsox_STdC/driver/lsm6dsox_reg.h
 */

#ifndef __LSM6DSOX_H__
#define __LSM6DSOX_H__

/* LSM6DSOX Data Types: fifo is typed */
enum {
  LSM6DSOX_GYRO         = 0x01,
  LSM6DSOX_ACCEL        = 0x02,
  LSM6DSOX_MAG          = 0x0E,

  LSM6DSOX_DT_GYRO_NC   = 0x01,         /* gyro, no compression */
  LSM6DSOX_DT_ACCEL_NC  = 0x02,         /* accel, no compression */
  LSM6DSOX_DT_TEMP      = 0x03,         /* temp sensor */
  LSM6DSOX_DT_TIMESTAMP = 0x04,         /* timestamp */
  LSM6DSOX_DT_CFG_CHG   = 0x05,         /* config change */
  LSM6DSOX_DT_SHUB_0    = 0x0e,         /* slave hub 0, read/write */
  LSM6DSOX_DT_SHUB_1    = 0x0f,         /* slave nub 1, mag read   */
  LSM6DSOX_DT_SHUB_2    = 0x10,
  LSM6DSOX_DT_SHUB_3    = 0x11,
  LSM6DSOX_DT_STEP_CNT  = 0x12,
  LSM6DSOX_DT_GAME_ROT  = 0x13,
  LSM6DSOX_DT_GEOMAG_ROT= 0x14,
  LSM6DSOX_DT_ROTATION  = 0x15,
  LSM6DSOX_DT_SNS_NACK  = 0x19,         /* shub nack */
};

/* the size in bytes of each fifo element */
#define LSM6DSOX_FIFO_ELM_SIZE     7

#define LSM6DSOX_DT_GYRO  LSM6DSOX_DT_GYRO_NC
#define LSM6DSOX_DT_ACCEL LSM6DSOX_DT_ACCEL_NC
#define LSM6DSOX_DT_MAG   LSM6DSOX_DT_SHUB_0


/** I2C Device Address 8 bit format  if SA0=0 -> D5 if SA0=1 -> D7 **/
#define LSM6DSOX_I2C_ADD_L                    0xD4U
#define LSM6DSOX_I2C_ADD_H                    0xD6U

/** Device Identification (Who am I) **/
#define LSM6DSOX_ID                           0x6C
#define LSM6DSOX_WHO_I_AM                     0x6C

#define LSM6DSOX_FUNC_CFG_ACCESS              0x01U
#define LSM6DSOX_MAIN_REGS                    0
#define LSM6DSOX_SHUB_REGS                    0x40

#define LSM6DSOX_PIN_CTRL                     0x02U
typedef union {
  struct {
    uint8_t not_used_01              : 6;
    uint8_t sdo_pu_en                : 1;
    uint8_t ois_pu_dis               : 1;
  } x;
  uint8_t bits;
} lsm6dsox_pin_ctrl_t;

#define LSM6DSOX_S4S_TPH_L                    0x04U
typedef union {
  struct {
    uint8_t tph_l                    : 7;
    uint8_t tph_h_sel                : 1;
  } x;
  uint8_t bits;
} lsm6dsox_s4s_tph_l_t;

#define LSM6DSOX_S4S_TPH_H                    0x05U
#define LSM6DSOX_S4S_RR                       0x06U

/* WTM (fifo watermark) is FIFO_CTRL2.wtm | FIFO_CTRL1 */
#define LSM6DSOX_FIFO_CTRL1                   0x07U
#define LSM6DSOX_FIFO_CTRL2                   0x08U
typedef union {
  struct {
    uint8_t wtm_b8                   : 1;         /* bit 8 */
    uint8_t uncoptr_rate             : 2;
    uint8_t not_used_01              : 1;
    uint8_t odrchg_en                : 1;
    uint8_t not_used_02              : 1;
    uint8_t fifo_compr_rt_en         : 1;
    uint8_t stop_on_wtm              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fifo_ctrl2_t;

#define LSM6DSOX_FIFO_CTRL3                   0x09U
typedef union {
  struct {
    uint8_t bdr_xl                   : 4;
    uint8_t bdr_gy                   : 4;
  } x;
  uint8_t bits;
} lsm6dsox_fifo_ctrl3_t;

#define LSM6DSOX_FIFO_CTRL4                   0x0AU
typedef union {
  struct {
    uint8_t fifo_mode                : 3;
    uint8_t not_used_01              : 1;
    uint8_t odr_t_batch              : 2;
    uint8_t odr_ts_batch             : 2;
  } x;
  uint8_t bits;
} lsm6dsox_fifo_ctrl4_t;


/* FIFO Mode */
enum {
  LSM6DSOX_FM_BYPASS               = 0,
  LSM6DSOX_FM_FIFO                 = 1,
  LSM6DSOX_FM_STREAM_TO_FIFO       = 3,
  LSM6DSOX_FM_BYPASS_TO_STREAM     = 4,
  LSM6DSOX_FM_STREAM               = 6,
  LSM6DSOX_FM_BYPASS_TO_FIFO       = 7,
};


enum {
  LSM6DSOX_TEMP_NOT_BATCHED        = 0,         /* default */
  LSM6DSOX_TEMP_BATCHED_AT_1Hz6    = 1,
  LSM6DSOX_TEMP_BATCHED_AT_12Hz5   = 2,
  LSM6DSOX_TEMP_BATCHED_AT_52Hz    = 3,
};


/* timestamp decimation in fifo */
enum {
  LSM6DSOX_NO_DEC                  = 0,
  LSM6DSOX_DEC_1                   = 1,
  LSM6DSOX_DEC_8                   = 2,
  LSM6DSOX_DEC_32                  = 3,
};


#define LSM6DSOX_COUNTER_BDR_REG1             0x0BU
typedef union {
  struct {
    uint8_t cnt_bdr_th_upper         : 3;         /* bits 10-8 */
    uint8_t not_used_01              : 2;
    uint8_t trig_counter_bdr         : 1;
    uint8_t rst_counter_bdr          : 1;
    uint8_t dataready_pulsed         : 1;
  } x;
  uint8_t bits;
} lsm6dsox_counter_bdr_reg1_t;

/* cnt_bdr_th, bits 7-0 */
#define LSM6DSOX_COUNTER_BDR_REG2             0x0CU

#define LSM6DSOX_INT1_CTRL                    0x0DU
typedef union {
  struct {
    uint8_t int1_drdy_xl             : 1;
    uint8_t int1_drdy_g              : 1;
    uint8_t int1_boot                : 1;
    uint8_t int1_fifo_th             : 1;
    uint8_t int1_fifo_ovr            : 1;
    uint8_t int1_fifo_full           : 1;
    uint8_t int1_cnt_bdr             : 1;
    uint8_t den_drdy_flag            : 1;
  } x;
  uint8_t bits;
}lsm6dsox_int1_ctrl_t;

#define LSM6DSOX_INT2_CTRL                    0x0EU
typedef union {
  struct {
    uint8_t int2_drdy_xl             : 1;
    uint8_t int2_drdy_g              : 1;
    uint8_t int2_drdy_temp           : 1;
    uint8_t int2_fifo_th             : 1;
    uint8_t int2_fifo_ovr            : 1;
    uint8_t int2_fifo_full           : 1;
    uint8_t int2_cnt_bdr             : 1;
    uint8_t not_used_01              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_int2_ctrl_t;

/*
 * ID Register.  Validate SPI xfer by reading this
 * register: Value should equal WHO_I_AM.
 */
#define LSM6DSOX_WHO_AM_I                     0x0FU

#define LSM6DSOX_CTRL1_XL                     0x10U
typedef union {
  struct {
    uint8_t not_used_01              : 1;
    uint8_t lpf2_xl_en               : 1;
    uint8_t fs_xl                    : 2;
    uint8_t odr_xl                   : 4;
  } x;
  uint8_t bits;
} lsm6dsox_ctrl1_xl_t;

#define LSM6DSOX_CTRL2_G                      0x11U
typedef union {
  struct {
    uint8_t not_used_01              : 1;
    uint8_t fs_g                     : 3;       /* includes fs_125 */
    uint8_t odr_g                    : 4;
  } x;
  uint8_t bits;
} lsm6dsox_ctrl2_g_t;

#define LSM6DSOX_CTRL3_C                      0x12U
typedef union {
  struct {
    uint8_t sw_reset                 : 1;
    uint8_t not_used_01              : 1;
    uint8_t if_inc                   : 1;
    uint8_t sim                      : 1;
    uint8_t pp_od                    : 1;
    uint8_t h_lactive                : 1;
    uint8_t bdu                      : 1;
    uint8_t boot                     : 1;
  } x;
  uint8_t bits;
} lsm6dsox_ctrl3_c_t;

#define LSM6DSOX_CTRL4_C                      0x13U
typedef union {
  struct {
    uint8_t not_used_01              : 1;
    uint8_t lpf1_sel_g               : 1;
    uint8_t i2c_disable              : 1;
    uint8_t drdy_mask                : 1;
    uint8_t not_used_02              : 1;
    uint8_t int2_on_int1             : 1;
    uint8_t sleep_g                  : 1;
    uint8_t not_used_03              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_ctrl4_c_t;

#define LSM6DSOX_CTRL5_C                      0x14U
typedef union {
  struct {
    uint8_t st_xl                    : 2;
    uint8_t st_g                     : 2;
    uint8_t rounding_status          : 1;
    uint8_t rounding                 : 2;
    uint8_t xl_ulp_en                : 1;
  } x;
  uint8_t bits;
} lsm6dsox_ctrl5_c_t;

#define LSM6DSOX_CTRL6_C                      0x15U
typedef union {
  struct {
    uint8_t ftype                    : 3;
    uint8_t usr_off_w                : 1;
    uint8_t xl_hm_mode               : 1;
    uint8_t den_mode                 : 3;   /* trig_en + lvl1_en + lvl2_en */
  } x;
  uint8_t bits;
} lsm6dsox_ctrl6_c_t;

#define LSM6DSOX_CTRL7_G                      0x16U
typedef union {
  struct {
    uint8_t ois_on                   : 1;
    uint8_t usr_off_on_out           : 1;
    uint8_t ois_on_en                : 1;
    uint8_t not_used_01              : 1;
    uint8_t hpm_g                    : 2;
    uint8_t hp_en_g                  : 1;
    uint8_t g_hm_mode                : 1;
  } x;
  uint8_t bits;
} lsm6dsox_ctrl7_g_t;

#define LSM6DSOX_CTRL8_XL                     0x17U
typedef union {
  struct {
    uint8_t low_pass_on_6d           : 1;
    uint8_t xl_fs_mode               : 1;
    uint8_t hp_slope_xl_en           : 1;
    uint8_t fastsettl_mode_xl        : 1;
    uint8_t hp_ref_mode_xl           : 1;
    uint8_t hpcf_xl                  : 3;
  } x;
  uint8_t bits;
} lsm6dsox_ctrl8_xl_t;

#define LSM6DSOX_CTRL9_XL                     0x18U
typedef union {
  struct {
    uint8_t not_used_01              : 1;
    uint8_t i3c_disable              : 1;
    uint8_t den_lh                   : 1;
    uint8_t den_xl_g                 : 2;   /* den_xl_en + den_xl_g */
    uint8_t den_z                    : 1;
    uint8_t den_y                    : 1;
    uint8_t den_x                    : 1;
  } x;
  uint8_t bits;
} lsm6dsox_ctrl9_xl_t;

#define LSM6DSOX_CTRL10_C                     0x19U
typedef union {
  struct {
    uint8_t not_used_01              : 5;
    uint8_t timestamp_en             : 1;
    uint8_t not_used_02              : 2;
  } x;
  uint8_t bits;
} lsm6dsox_ctrl10_c_t;

#define LSM6DSOX_ALL_INT_SRC                  0x1AU
typedef union {
  struct {
    uint8_t ff_ia                    : 1;
    uint8_t wu_ia                    : 1;
    uint8_t single_tap               : 1;
    uint8_t double_tap               : 1;
    uint8_t d6d_ia                   : 1;
    uint8_t sleep_change_ia          : 1;
    uint8_t not_used_01              : 1;
    uint8_t timestamp_endcount       : 1;
  } x;
  uint8_t bits;
} lsm6dsox_all_int_src_t;

#define LSM6DSOX_WAKE_UP_SRC                  0x1BU
typedef union {
  struct {
    uint8_t z_wu                     : 1;
    uint8_t y_wu                     : 1;
    uint8_t x_wu                     : 1;
    uint8_t wu_ia                    : 1;
    uint8_t sleep_state              : 1;
    uint8_t ff_ia                    : 1;
    uint8_t sleep_change_ia          : 2;
  } x;
  uint8_t bits;
} lsm6dsox_wake_up_src_t;

#define LSM6DSOX_TAP_SRC                      0x1CU
typedef union {
  struct {
    uint8_t z_tap                    : 1;
    uint8_t y_tap                    : 1;
    uint8_t x_tap                    : 1;
    uint8_t tap_sign                 : 1;
    uint8_t double_tap               : 1;
    uint8_t single_tap               : 1;
    uint8_t tap_ia                   : 1;
    uint8_t not_used_01              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_tap_src_t;

#define LSM6DSOX_D6D_SRC                      0x1DU
typedef union {
  struct {
    uint8_t xl                       : 1;
    uint8_t xh                       : 1;
    uint8_t yl                       : 1;
    uint8_t yh                       : 1;
    uint8_t zl                       : 1;
    uint8_t zh                       : 1;
    uint8_t d6d_ia                   : 1;
    uint8_t den_drdy                 : 1;
  } x;
  uint8_t bits;
} lsm6dsox_d6d_src_t;

#define LSM6DSOX_STATUS_REG                   0x1EU
typedef union {
  struct {
    uint8_t xlda                     : 1;
    uint8_t gda                      : 1;
    uint8_t tda                      : 1;
    uint8_t not_used_01              : 5;
  } x;
  uint8_t bits;
} lsm6dsox_status_reg_t;

#define LSM6DSOX_OUT_TEMP_L                   0x20U
#define LSM6DSOX_OUT_TEMP_H                   0x21U

#define LSM6DSOX_OUTX_L_G                     0x22U
#define LSM6DSOX_OUTX_H_G                     0x23U
#define LSM6DSOX_OUTY_L_G                     0x24U
#define LSM6DSOX_OUTY_H_G                     0x25U
#define LSM6DSOX_OUTZ_L_G                     0x26U
#define LSM6DSOX_OUTZ_H_G                     0x27U

#define LSM6DSOX_OUTX_L_A                     0x28U
#define LSM6DSOX_OUTX_H_A                     0x29U
#define LSM6DSOX_OUTY_L_A                     0x2AU
#define LSM6DSOX_OUTY_H_A                     0x2BU
#define LSM6DSOX_OUTZ_L_A                     0x2CU
#define LSM6DSOX_OUTZ_H_A                     0x2DU

#define LSM6DSOX_EMB_FUNC_STATUS_MAINPAGE     0x35U
typedef union {
  struct {
    uint8_t not_used_01             : 3;
    uint8_t is_step_det             : 1;
    uint8_t is_tilt                 : 1;
    uint8_t is_sigmot               : 1;
    uint8_t not_used_02             : 1;
    uint8_t is_fsm_lc               : 1;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_status_mainpage_t;

#define LSM6DSOX_FSM_STATUS_A_MAINPAGE        0x36U
#define LSM6DSOX_FSM_STATUS_B_MAINPAGE        0x37U
#define LSM6DSOX_MLC_STATUS_MAINPAGE          0x38U

/* See lsm6dsox_status_master in SHUB section */
#define LSM6DSOX_STATUS_MASTER_MAINPAGE       0x39U

/*fifo len is STATUS2.diff_fifo_upper | STATUS1 */
#define LSM6DSOX_FIFO_STATUS1                 0x3AU
#define LSM6DSOX_FIFO_STATUS2                 0x3BU
typedef union {
  struct {
    uint8_t diff_fifo_upper          : 2;         /* bits 9-8 */
    uint8_t not_used_01              : 1;
    uint8_t fifo_ovr_latched         : 1;
    uint8_t counter_bdr_ia           : 1;
    uint8_t fifo_full_ia             : 1;
    uint8_t fifo_ovr_ia              : 1;
    uint8_t fifo_wtm_ia              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fifo_status2_t;

/* 4 bytes */
#define LSM6DSOX_TIMESTAMP0                   0x40U

#define LSM6DSOX_UI_STATUS_REG_OIS            0x49U
typedef union {
  struct {
    uint8_t xlda                     : 1;
    uint8_t gda                      : 1;
    uint8_t gyro_settling            : 1;
    uint8_t not_used_01              : 5;
  } x;
  uint8_t bits;
} lsm6dsox_ui_status_reg_ois_t;

#define LSM6DSOX_UI_OUTX_L_G_OIS              0x4AU
#define LSM6DSOX_UI_OUTX_H_G_OIS              0x4BU
#define LSM6DSOX_UI_OUTY_L_G_OIS              0x4CU
#define LSM6DSOX_UI_OUTY_H_G_OIS              0x4DU
#define LSM6DSOX_UI_OUTZ_L_G_OIS              0x4EU
#define LSM6DSOX_UI_OUTZ_H_G_OIS              0x4FU
#define LSM6DSOX_UI_OUTX_L_A_OIS              0x50U
#define LSM6DSOX_UI_OUTX_H_A_OIS              0x51U
#define LSM6DSOX_UI_OUTY_L_A_OIS              0x52U
#define LSM6DSOX_UI_OUTY_H_A_OIS              0x53U
#define LSM6DSOX_UI_OUTZ_L_A_OIS              0x54U
#define LSM6DSOX_UI_OUTZ_H_A_OIS              0x55U

#define LSM6DSOX_TAP_CFG0                     0x56U
typedef union {
  struct {
    uint8_t lir                      : 1;
    uint8_t tap_z_en                 : 1;
    uint8_t tap_y_en                 : 1;
    uint8_t tap_x_en                 : 1;
    uint8_t slope_fds                : 1;
    uint8_t sleep_status_on_int      : 1;
    uint8_t int_clr_on_read          : 1;
    uint8_t not_used_01              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_tap_cfg0_t;

#define LSM6DSOX_TAP_CFG1                     0x57U
typedef union {
  struct {
    uint8_t tap_ths_x                : 5;         /* tap threshold */
    uint8_t tap_priority             : 3;
  } x;
  uint8_t bits;
} lsm6dsox_tap_cfg1_t;

#define LSM6DSOX_TAP_CFG2                     0x58U
typedef union {
  struct {
    uint8_t tap_ths_y                : 5;         /* threshold */
    uint8_t inact_en                 : 2;
    uint8_t interrupts_enable        : 1;         /* 6d/4d, FF, WU, Tap, inactivity */
  } x;
  uint8_t bits;
} lsm6dsox_tap_cfg2_t;

#define LSM6DSOX_TAP_THS_6D                   0x59U
typedef union {
  struct {
    uint8_t tap_ths_z                : 5;         /* threshold */
    uint8_t sixd_ths                 : 2;         /* threshold */
    uint8_t d4d_en                   : 1;         /* 0 - z-axis enabled */
  } x;
  uint8_t bits;
} lsm6dsox_tap_ths_6d_t;

#define LSM6DSOX_INT_DUR2                     0x5AU
typedef union {
  struct {
    uint8_t shock                    : 2;
    uint8_t quiet                    : 2;
    uint8_t dur                      : 4;
  } x;
  uint8_t bits;
} lsm6dsox_int_dur2_t;

#define LSM6DSOX_WAKE_UP_THS                  0x5BU
typedef union {
  struct {
    uint8_t wk_ths                   : 6;         /* threshold */
    uint8_t usr_off_on_wu            : 1;
    uint8_t single_double_tap        : 1;         /* 0 - single tap only */
  } x;
  uint8_t bits;
} lsm6dsox_wake_up_ths_t;

#define LSM6DSOX_WAKE_UP_DUR                  0x5CU
typedef union {
  struct {
    uint8_t sleep_dur                : 4;
    uint8_t wake_ths_w               : 1;
    uint8_t wake_dur                 : 2;
    uint8_t ff_dur                   : 1;
  } x;
  uint8_t bits;
} lsm6dsox_wake_up_dur_t;

#define LSM6DSOX_FREE_FALL                    0x5DU
typedef union {
  struct {
    uint8_t ff_ths                   : 3;
    uint8_t ff_dur                   : 5;
  } x;
  uint8_t bits;
} lsm6dsox_free_fall_t;

#define LSM6DSOX_MD1_CFG                      0x5EU
typedef union {
  struct {
    uint8_t int1_shub                : 1;
    uint8_t int1_emb_func            : 1;
    uint8_t int1_6d                  : 1;
    uint8_t int1_double_tap          : 1;
    uint8_t int1_ff                  : 1;
    uint8_t int1_wu                  : 1;
    uint8_t int1_single_tap          : 1;
    uint8_t int1_sleep_change        : 1;
  } x;
  uint8_t bits;
} lsm6dsox_md1_cfg_t;

#define LSM6DSOX_MD2_CFG                      0x5FU
typedef union {
  struct {
    uint8_t int2_timestamp           : 1;
    uint8_t int2_emb_func            : 1;
    uint8_t int2_6d                  : 1;
    uint8_t int2_double_tap          : 1;
    uint8_t int2_ff                  : 1;
    uint8_t int2_wu                  : 1;
    uint8_t int2_single_tap          : 1;
    uint8_t int2_sleep_change        : 1;
  } x;
  uint8_t bits;
} lsm6dsox_md2_cfg_t;

#define LSM6DSOX_S4S_ST_CMD_CODE              0x60U
#define LSM6DSOX_S4S_DT_REG                   0x61U

#define LSM6DSOX_I3C_BUS_AVB                  0x62U
typedef union {
  struct {
    uint8_t pd_dis_int1              : 1;
    uint8_t not_used_01              : 2;
    uint8_t i3c_bus_avb_sel          : 2;
    uint8_t not_used_02              : 3;
  } x;
  uint8_t bits;
} lsm6dsox_i3c_bus_avb_t;

#define LSM6DSOX_INTERNAL_FREQ_FINE           0x63U

#define LSM6DSOX_UI_INT_OIS                   0x6FU
typedef union {
  struct {
    uint8_t not_used_01              : 3;
    uint8_t spi2_read_en             : 1;
    uint8_t not_used_02              : 1;
    uint8_t den_lh_ois               : 1;
    uint8_t lvl2_ois                 : 1;
    uint8_t int2_drdy_ois            : 1;
  } x;
  uint8_t bits;
} lsm6dsox_ui_int_ois_t;

#define LSM6DSOX_UI_CTRL1_OIS                 0x70U
typedef union {
  struct {
    uint8_t ois_en_spi2              : 1;
    uint8_t fs_125_ois               : 1;
    uint8_t fs_g_ois                 : 2;
    uint8_t mode4_en                 : 1;
    uint8_t sim_ois                  : 1;
    uint8_t lvl1_ois                 : 1;
    uint8_t not_used_01              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_ui_ctrl1_ois_t;

#define LSM6DSOX_UI_CTRL2_OIS                 0x71U
typedef union {
  struct {
    uint8_t hp_en_ois                : 1;
    uint8_t ftype_ois                : 2;
    uint8_t not_used_01              : 1;
    uint8_t hpm_ois                  : 2;
    uint8_t not_used_02              : 2;
  } x;
  uint8_t bits;
} lsm6dsox_ui_ctrl2_ois_t;

#define LSM6DSOX_UI_CTRL3_OIS                 0x72U
typedef union {
  struct {
    uint8_t st_ois_clampdis          : 1;
    uint8_t not_used_01              : 2;
    uint8_t filter_xl_conf_ois       : 3;
    uint8_t fs_xl_ois                : 2;
  } x;
  uint8_t bits;
} lsm6dsox_ui_ctrl3_ois_t;

#define LSM6DSOX_X_OFS_USR                    0x73U
#define LSM6DSOX_Y_OFS_USR                    0x74U
#define LSM6DSOX_Z_OFS_USR                    0x75U

#define LSM6DSOX_FIFO_DATA_OUT_TAG            0x78U
typedef union {
  struct {
    uint8_t tag_parity               : 1;
    uint8_t tag_cnt                  : 2;
    uint8_t tag_sensor               : 5;
  } x;
  uint8_t bits;
} lsm6dsox_fifo_data_out_tag_t;

#define LSM6DSOX_FIFO_DATA                    0x79
#define LSM6DSOX_FIFO_DATA_OUT_X_L            0x79
#define LSM6DSOX_FIFO_DATA_OUT_X_H            0x7A
#define LSM6DSOX_FIFO_DATA_OUT_Y_L            0x7B
#define LSM6DSOX_FIFO_DATA_OUT_Y_H            0x7C
#define LSM6DSOX_FIFO_DATA_OUT_Z_L            0x7D
#define LSM6DSOX_FIFO_DATA_OUT_Z_H            0x7E

#define LSM6DSOX_SPI2_WHO_AM_I                0x0F

#define LSM6DSOX_SPI2_STATUS_REG_OIS          0x1E
typedef union {
  struct {
    uint8_t xlda                     : 1;
    uint8_t gda                      : 1;
    uint8_t gyro_settling            : 1;
    uint8_t not_used_01              : 5;
  } x;
  uint8_t bits;
} lsm6dsox_spi2_status_reg_ois_t;

#define LSM6DSOX_SPI2_OUT_TEMP_L              0x20
#define LSM6DSOX_SPI2_OUT_TEMP_H              0x21

#define LSM6DSOX_SPI2_OUTX_L_G_OIS            0x22
#define LSM6DSOX_SPI2_OUTX_H_G_OIS            0x23
#define LSM6DSOX_SPI2_OUTY_L_G_OIS            0x24
#define LSM6DSOX_SPI2_OUTY_H_G_OIS            0x25
#define LSM6DSOX_SPI2_OUTZ_L_G_OIS            0x26
#define LSM6DSOX_SPI2_OUTZ_H_G_OIS            0x27

#define LSM6DSOX_SPI2_OUTX_L_A_OIS            0x28
#define LSM6DSOX_SPI2_OUTX_H_A_OIS            0x29
#define LSM6DSOX_SPI2_OUTY_L_A_OIS            0x2A
#define LSM6DSOX_SPI2_OUTY_H_A_OIS            0x2B
#define LSM6DSOX_SPI2_OUTZ_L_A_OIS            0x2C
#define LSM6DSOX_SPI2_OUTZ_H_A_OIS            0x2D

#define LSM6DSOX_SPI2_INT_OIS                 0x6F
typedef union {
  struct {
    uint8_t st_xl_ois                : 2;
    uint8_t not_used_01              : 3;
    uint8_t den_lh_ois               : 1;
    uint8_t lvl2_ois                 : 1;
    uint8_t int2_drdy_ois            : 1;
  } x;
  uint8_t bits;
} lsm6dsox_spi2_int_ois_t;

#define LSM6DSOX_SPI2_CTRL1_OIS               0x70U
typedef union {
  struct {
    uint8_t ois_en_spi2              : 1;
    uint8_t fs_125_ois               : 1;
    uint8_t fs_g_ois                 : 2;
    uint8_t mode4_en                 : 1;
    uint8_t sim_ois                  : 1;
    uint8_t lvl1_ois                 : 1;
    uint8_t not_used_01              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_spi2_ctrl1_ois_t;

#define LSM6DSOX_SPI2_CTRL2_OIS               0x71U
typedef union {
  struct {
    uint8_t hp_en_ois                : 1;
    uint8_t ftype_ois                : 2;
    uint8_t not_used_01              : 1;
    uint8_t hpm_ois                  : 2;
    uint8_t not_used_02              : 2;
  } x;
  uint8_t bits;
} lsm6dsox_spi2_ctrl2_ois_t;

#define LSM6DSOX_SPI2_CTRL3_OIS               0x72U
typedef union {
  struct {
    uint8_t st_ois_clampdis          : 1;
    uint8_t st_ois                   : 2;
    uint8_t filter_xl_conf_ois       : 3;
    uint8_t fs_xl_ois                : 2;
  } x;
  uint8_t bits;
} lsm6dsox_spi2_ctrl3_ois_t;

/* low bit must be 1 */
#define LSM6DSOX_PAGE_SEL                     0x02U

#define LSM6DSOX_EMB_FUNC_EN_A                0x04U
typedef union {
  struct {
    uint8_t not_used_01              : 3;
    uint8_t pedo_en                  : 1;
    uint8_t tilt_en                  : 1;
    uint8_t sign_motion_en           : 1;
    uint8_t not_used_02              : 2;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_en_a_t;

#define LSM6DSOX_EMB_FUNC_EN_B                0x05U
typedef union {
  struct {
    uint8_t fsm_en                   : 1;
    uint8_t not_used_01              : 2;
    uint8_t fifo_compr_en            : 1;
    uint8_t mlc_en                   : 1;
    uint8_t not_used_02              : 3;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_en_b_t;

#define LSM6DSOX_PAGE_ADDRESS                 0x08U
#define LSM6DSOX_PAGE_VALUE                   0x09U

#define LSM6DSOX_EMB_FUNC_INT1                0x0AU
typedef union {
  struct {
    uint8_t not_used_01              : 3;
    uint8_t int1_step_detector       : 1;
    uint8_t int1_tilt                : 1;
    uint8_t int1_sig_mot             : 1;
    uint8_t not_used_02              : 1;
    uint8_t int1_fsm_lc              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_int1_t;

#define LSM6DSOX_FSM_INT1_A                   0x0BU
#define LSM6DSOX_FSM_INT1_B                   0x0CU
#define LSM6DSOX_MLC_INT1                     0x0DU

#define LSM6DSOX_EMB_FUNC_INT2                0x0EU
typedef union {
  struct {
    uint8_t not_used_01              : 3;
    uint8_t int2_step_detector       : 1;
    uint8_t int2_tilt                : 1;
    uint8_t int2_sig_mot             : 1;
    uint8_t not_used_02              : 1;
    uint8_t int2_fsm_lc              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_int2_t;

#define LSM6DSOX_FSM_INT2_A                   0x0FU
#define LSM6DSOX_FSM_INT2_B                   0x10U
#define LSM6DSOX_MLC_INT2                     0x11U

#define LSM6DSOX_EMB_FUNC_STATUS              0x12U
typedef union {
  struct {
    uint8_t not_used_01              : 3;
    uint8_t is_step_det              : 1;
    uint8_t is_tilt                  : 1;
    uint8_t is_sigmot                : 1;
    uint8_t not_used_02              : 1;
    uint8_t is_fsm_lc                : 1;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_status_t;

#define LSM6DSOX_FSM_STATUS_A                 0x13U
#define LSM6DSOX_FSM_STATUS_B                 0x14U
#define LSM6DSOX_MLC_STATUS                   0x15U

#define LSM6DSOX_PAGE_RW                      0x17U
typedef union {
  struct {
    uint8_t not_used_01              : 5;
    uint8_t page_read                : 1;
    uint8_t page_write               : 1;
    uint8_t emb_func_lir             : 1;
  } x;
  uint8_t bits;
} lsm6dsox_page_rw_t;

#define LSM6DSOX_EMB_FUNC_FIFO_CFG            0x44U
typedef union {
  struct {
    uint8_t not_used_00              : 6;
    uint8_t pedo_fifo_en             : 1;
    uint8_t not_used_01              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_fifo_cfg_t;

#define LSM6DSOX_FSM_ENABLE_A                 0x46U
#define LSM6DSOX_FSM_ENABLE_B                 0x47U
#define LSM6DSOX_FSM_LONG_COUNTER_L           0x48U
#define LSM6DSOX_FSM_LONG_COUNTER_H           0x49U

#define LSM6DSOX_FSM_LONG_COUNTER_CLEAR       0x4AU
typedef union {
  struct {
    uint8_t fsm_lc_clear             : 1;         /* set to 1 to clear */
    uint8_t fsm_lc_cleard            : 1;         /* reads 1 when done */
    uint8_t not_used_01              : 6;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_long_counter_clear_t;

#define LSM6DSOX_FSM_OUTS1                    0x4CU
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs1_t;

#define LSM6DSOX_FSM_OUTS2                    0x4DU
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs2_t;

#define LSM6DSOX_FSM_OUTS3                    0x4EU
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs3_t;

#define LSM6DSOX_FSM_OUTS4                    0x4FU
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs4_t;

#define LSM6DSOX_FSM_OUTS5                    0x50U
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs5_t;

#define LSM6DSOX_FSM_OUTS6                    0x51U
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs6_t;

#define LSM6DSOX_FSM_OUTS7                    0x52U
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs7_t;

#define LSM6DSOX_FSM_OUTS8                    0x53U
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs8_t;

#define LSM6DSOX_FSM_OUTS9                    0x54U
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs9_t;

#define LSM6DSOX_FSM_OUTS10                   0x55U
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs10_t;

#define LSM6DSOX_FSM_OUTS11                   0x56U
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs11_t;

#define LSM6DSOX_FSM_OUTS12                   0x57U
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs12_t;

#define LSM6DSOX_FSM_OUTS13                   0x58U
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs13_t;

#define LSM6DSOX_FSM_OUTS14                   0x59U
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs14_t;

#define LSM6DSOX_FSM_OUTS15                   0x5AU
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs15_t;

#define LSM6DSOX_FSM_OUTS16                   0x5BU
typedef union {
  struct {
    uint8_t n_v                      : 1;
    uint8_t p_v                      : 1;
    uint8_t n_z                      : 1;
    uint8_t p_z                      : 1;
    uint8_t n_y                      : 1;
    uint8_t p_y                      : 1;
    uint8_t n_x                      : 1;
    uint8_t p_x                      : 1;
  } x;
  uint8_t bits;
} lsm6dsox_fsm_outs16_t;

#define LSM6DSOX_EMB_FUNC_ODR_CFG_B           0x5FU
typedef union {
  struct {
    uint8_t not_used_01              : 3;
    uint8_t fsm_odr                  : 2;
    uint8_t not_used_02              : 3;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_odr_cfg_b_t;

#define LSM6DSOX_EMB_FUNC_ODR_CFG_C           0x60U
typedef union {
  struct {
    uint8_t not_used_01             : 4;
    uint8_t mlc_odr                 : 2;
    uint8_t not_used_02             : 2;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_odr_cfg_c_t;

#define LSM6DSOX_STEP_COUNTER_L               0x62U
#define LSM6DSOX_STEP_COUNTER_H               0x63U

#define LSM6DSOX_EMB_FUNC_SRC                 0x64U
typedef union {
  struct {
    uint8_t not_used_01              : 2;
    uint8_t stepcounter_bit_set      : 1;
    uint8_t step_overflow            : 1;
    uint8_t step_count_delta_ia      : 1;
    uint8_t step_detected            : 1;
    uint8_t not_used_02              : 1;
    uint8_t pedo_rst_step            : 1;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_src_t;

#define LSM6DSOX_EMB_FUNC_INIT_A              0x66U
typedef union {
  struct {
    uint8_t not_used_01               : 3;
    uint8_t step_det_init             : 1;
    uint8_t tilt_init                 : 1;
    uint8_t sig_mot_init              : 1;
    uint8_t not_used_02               : 2;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_init_a_t;

#define LSM6DSOX_EMB_FUNC_INIT_B              0x67U
typedef union {
  struct {
    uint8_t fsm_init                 : 1;
    uint8_t not_used_01              : 2;
    uint8_t fifo_compr_init          : 1;
    uint8_t mlc_init                 : 1;
    uint8_t not_used_02              : 3;
  } x;
  uint8_t bits;
} lsm6dsox_emb_func_init_b_t;

#define LSM6DSOX_MLC0_SRC                     0x70U
#define LSM6DSOX_MLC1_SRC                     0x71U
#define LSM6DSOX_MLC2_SRC                     0x72U
#define LSM6DSOX_MLC3_SRC                     0x73U
#define LSM6DSOX_MLC4_SRC                     0x74U
#define LSM6DSOX_MLC5_SRC                     0x75U
#define LSM6DSOX_MLC6_SRC                     0x76U
#define LSM6DSOX_MLC7_SRC                     0x77U

#define LSM6DSOX_MAG_SENSITIVITY_L            0xBAU
#define LSM6DSOX_MAG_SENSITIVITY_H            0xBBU

#define LSM6DSOX_MAG_OFFX_L                   0xC0U
#define LSM6DSOX_MAG_OFFX_H                   0xC1U
#define LSM6DSOX_MAG_OFFY_L                   0xC2U
#define LSM6DSOX_MAG_OFFY_H                   0xC3U
#define LSM6DSOX_MAG_OFFZ_L                   0xC4U
#define LSM6DSOX_MAG_OFFZ_H                   0xC5U

#define LSM6DSOX_MAG_SI_XX_L                  0xC6U
#define LSM6DSOX_MAG_SI_XX_H                  0xC7U
#define LSM6DSOX_MAG_SI_XY_L                  0xC8U
#define LSM6DSOX_MAG_SI_XY_H                  0xC9U
#define LSM6DSOX_MAG_SI_XZ_L                  0xCAU
#define LSM6DSOX_MAG_SI_XZ_H                  0xCBU
#define LSM6DSOX_MAG_SI_YY_L                  0xCCU
#define LSM6DSOX_MAG_SI_YY_H                  0xCDU
#define LSM6DSOX_MAG_SI_YZ_L                  0xCEU
#define LSM6DSOX_MAG_SI_YZ_H                  0xCFU
#define LSM6DSOX_MAG_SI_ZZ_L                  0xD0U
#define LSM6DSOX_MAG_SI_ZZ_H                  0xD1U

#define LSM6DSOX_MAG_CFG_A                    0xD4U
typedef union {
  struct {
    uint8_t mag_z_axis               : 3;
    uint8_t not_used_01              : 1;
    uint8_t mag_y_axis               : 3;
    uint8_t not_used_02              : 1;
  } x;
  uint8_t bits;
} lsm6dsox_mag_cfg_a_t;

#define LSM6DSOX_MAG_CFG_B                    0xD5U
typedef union {
  struct {
    uint8_t mag_x_axis               : 3;
    uint8_t not_used_01              : 5;
  } x;
  uint8_t bits;
} lsm6dsox_mag_cfg_b_t;

#define LSM6DSOX_FSM_LC_TIMEOUT_L             0x17AU
#define LSM6DSOX_FSM_LC_TIMEOUT_H             0x17BU

#define LSM6DSOX_FSM_PROGRAMS                 0x17CU

#define LSM6DSOX_FSM_START_ADD_L              0x17EU
#define LSM6DSOX_FSM_START_ADD_H              0x17FU

#define LSM6DSOX_PEDO_CMD_REG                 0x183U
typedef union {
  struct {
    uint8_t ad_det_en                : 1;
    uint8_t not_used_01              : 1;
    uint8_t fp_rejection_en          : 1;
    uint8_t carry_count_en           : 1;
    uint8_t not_used_02              : 4;
  } x;
  uint8_t bits;
} lsm6dsox_pedo_cmd_reg_t;

#define LSM6DSOX_PEDO_DEB_STEPS_CONF          0x184U
#define LSM6DSOX_PEDO_SC_DELTAT_L             0x1D0U
#define LSM6DSOX_PEDO_SC_DELTAT_H             0x1D1U

#define LSM6DSOX_MLC_MAG_SENSITIVITY_L        0x1E8U
#define LSM6DSOX_MLC_MAG_SENSITIVITY_H        0x1E9U

#define LSM6DSOX_SENSOR_HUB_1                 0x02U
#define LSM6DSOX_SENSOR_HUB_2                 0x03U
#define LSM6DSOX_SENSOR_HUB_3                 0x04U
#define LSM6DSOX_SENSOR_HUB_4                 0x05U
#define LSM6DSOX_SENSOR_HUB_5                 0x06U
#define LSM6DSOX_SENSOR_HUB_6                 0x07U
#define LSM6DSOX_SENSOR_HUB_7                 0x08U
#define LSM6DSOX_SENSOR_HUB_8                 0x09U
#define LSM6DSOX_SENSOR_HUB_9                 0x0AU
#define LSM6DSOX_SENSOR_HUB_10                0x0BU
#define LSM6DSOX_SENSOR_HUB_11                0x0CU
#define LSM6DSOX_SENSOR_HUB_12                0x0DU
#define LSM6DSOX_SENSOR_HUB_13                0x0EU
#define LSM6DSOX_SENSOR_HUB_14                0x0FU
#define LSM6DSOX_SENSOR_HUB_15                0x10U
#define LSM6DSOX_SENSOR_HUB_16                0x11U
#define LSM6DSOX_SENSOR_HUB_17                0x12U
#define LSM6DSOX_SENSOR_HUB_18                0x13U

#define LSM6DSOX_MASTER_CONFIG                0x14U
typedef union {
  struct {
    uint8_t aux_sens_on              : 2;
    uint8_t master_on                : 1;
    uint8_t shub_pu_en               : 1;
    uint8_t pass_through_mode        : 1;
    uint8_t start_config             : 1;
    uint8_t write_once               : 1;
    uint8_t rst_master_regs          : 1;
  } x;
  uint8_t bits;
} lsm6dsox_master_config_t;

typedef union {
  struct {
    uint8_t numop                    : 3;
    uint8_t batch_ext_sens_en        : 1;
    uint8_t not_used_01              : 2;
    uint8_t shub_odr                 : 2;       /* only slave0_config */
  } x;
  uint8_t bits;
} lsm6dsox_slv_config_t;

/*
 * low order bit of ADDR is R/W in SLV0_ADDR and
 * R enable in SLV1-3.ADDR.
 */

#define SHUB_READ                             1

#define LSM6DSOX_SLV0_ADDR                    0x15U
#define LSM6DSOX_SLV0_REG                     0x16U
#define LSM6DSOX_SLV0_CONFIG                  0x17U
#define LSM6DSOX_SLV1_ADDR                    0x18U
#define LSM6DSOX_SLV1_REG                     0x19U
#define LSM6DSOX_SLV1_CONFIG                  0x1AU
#define LSM6DSOX_SLV2_ADDR                    0x1BU
#define LSM6DSOX_SLV2_REG                     0x1CU
#define LSM6DSOX_SLV2_CONFIG                  0x1DU
#define LSM6DSOX_SLV3_ADDR                    0x1EU
#define LSM6DSOX_SLV3_REG                     0x1FU
#define LSM6DSOX_SLV3_CONFIG                  0x20U
#define LSM6DSOX_DATAWRITE_SLV0               0x21U

#define LSM6DSOX_STATUS_MASTER                0x22U
typedef union {
  struct {
    uint8_t endop                    : 1;
    uint8_t not_used_01              : 2;
    uint8_t slave0_nack              : 1;
    uint8_t slave1_nack              : 1;
    uint8_t slave2_nack              : 1;
    uint8_t slave3_nack              : 1;
    uint8_t wr_once_done             : 1;
  } x;
  uint8_t bits;
} lsm6dsox_status_master_t;

#define LSM6DSOX_START_FSM_ADD                0x0400U

enum {
  LSM6DSOX_2g   = 0,
  LSM6DSOX_16g  = 1, /* if XL_FS_MODE = ‘1’ -> LSM6DSOX_2g */
  LSM6DSOX_4g   = 2,
  LSM6DSOX_8g   = 3,
};

enum {
  LSM6DSOX_XL_ODR_OFF    = 0,
  LSM6DSOX_XL_ODR_12Hz5  = 1,
  LSM6DSOX_XL_ODR_26Hz   = 2,
  LSM6DSOX_XL_ODR_52Hz   = 3,
  LSM6DSOX_XL_ODR_104Hz  = 4,
  LSM6DSOX_XL_ODR_208Hz  = 5,
  LSM6DSOX_XL_ODR_416Hz  = 6,
  LSM6DSOX_XL_ODR_833Hz  = 7,
  LSM6DSOX_XL_ODR_1666Hz = 8,
  LSM6DSOX_XL_ODR_3333Hz = 9,
  LSM6DSOX_XL_ODR_6666Hz = 10,
  LSM6DSOX_XL_ODR_1Hz6   = 11, /* (low power only) */
};

enum {
  LSM6DSOX_250dps   = 0,
  LSM6DSOX_125dps   = 1,
  LSM6DSOX_500dps   = 2,
  LSM6DSOX_1000dps  = 4,
  LSM6DSOX_2000dps  = 6,
};

enum {
  LSM6DSOX_GY_ODR_OFF    = 0,
  LSM6DSOX_GY_ODR_12Hz5  = 1,
  LSM6DSOX_GY_ODR_26Hz   = 2,
  LSM6DSOX_GY_ODR_52Hz   = 3,
  LSM6DSOX_GY_ODR_104Hz  = 4,
  LSM6DSOX_GY_ODR_208Hz  = 5,
  LSM6DSOX_GY_ODR_416Hz  = 6,
  LSM6DSOX_GY_ODR_833Hz  = 7,
  LSM6DSOX_GY_ODR_1666Hz = 8,
  LSM6DSOX_GY_ODR_3333Hz = 9,
  LSM6DSOX_GY_ODR_6666Hz = 10,
};

enum {
  LSM6DSOX_LSB_1mg  = 0,
  LSM6DSOX_LSB_16mg = 1,
};


enum {
  LSM6DSOX_NO_ROUND      = 0,
  LSM6DSOX_ROUND_XL      = 1,
  LSM6DSOX_ROUND_GY      = 2,
  LSM6DSOX_ROUND_GY_XL   = 3,
};

enum {
  LSM6DSOX_STAT_RND_DISABLE  = 0,
  LSM6DSOX_STAT_RND_ENABLE   = 1,
};

enum {
  LSM6DSOX_HP_FILTER_NONE     = 0x00,
  LSM6DSOX_HP_FILTER_16mHz    = 0x80,
  LSM6DSOX_HP_FILTER_65mHz    = 0x81,
  LSM6DSOX_HP_FILTER_260mHz   = 0x82,
  LSM6DSOX_HP_FILTER_1Hz04    = 0x83,
};

enum {
  LSM6DSOX_SH_ODR_104Hz = 0,
  LSM6DSOX_SH_ODR_52Hz  = 1,
  LSM6DSOX_SH_ODR_26Hz  = 2,
  LSM6DSOX_SH_ODR_13Hz  = 3,
};

#endif /* __LSM6DSOX_H__ */
