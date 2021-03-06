/**
 * sd.h - low level Secure Digital storage (definitions)
 *
 * SD card driver
 *
 * Copyright (c) 2010 Eric B. Decker
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


#ifndef __SD_H__
#define __SD_H__

#define SD_RESET_IDLES  74

#define SD_BLOCKSIZE (512UL)
#define SD_BLOCKSIZE_NBITS 9

/*
 * all data transfers to/from the SD include a 2 byte crc.
 * This CRC is handled outside of the buffer traffic itself.
 *
 * We currently do not know what byte order the CRC is transmitted in
 * didn't find it in the spec.  We currently don't check it and when
 * writing we fake it.  This will have to be sorted out (obviously) if we
 * turn CRCs on.
 */

/*
 * read.read launches a read and then polls the SD card
 * waiting for the card to say it has the data ready.  The
 * SD card starts sending the data using SD_START_TOK.
 * We will poll a maximum of SD_READ_TOK_MAX times before
 * bitching
 */
//#define SD_READ_TOK_MAX 512
#define SD_READ_TOK_MAX 4096


/* Number of times to retry the probe cycle during initialization */
#define SD_INIT_TRY 50

/* SD_GO_OP_MAX
 *
 * when resetting, we periodically send SD_GO_OP to take the card out
 * of reset.   We poll for the result and finish when the card comes
 * out of idle.  GO_OP_MAX is the maximum number of times we try
 * before giving up.
 */

#define SD_GO_OP_MAX 512

/* Hardcoded timeout for commands. */
#define SD_CMD_TIMEOUT 16

/*
 * hardcoded timeout for SDsa write completions
 * ~300ms in uis units.  5*64536 uis ~= 312ms
 * This should be similar to SD_WRITE_BUSY_TIMEOUT
 * which is used for the nornal non-standalone case.
 */
#define SD_WR_TIMEOUT (5*64*1024)


/*
 * dma xfer timeout in ms at 8MHz, 1 bit time is
 * 1/8000000 = 125ns, * 8 is 1us/byte, * 514 = 514uS.
 * 8 times that is the timeout of 4 mS.
 *
 * we further fudge it by a factor of 8
 */
//#define SD_SECTOR_XFER_TIMEOUT	4
#define SD_SECTOR_XFER_TIMEOUT	(4 * 8 * 8)


/*
 * timeout values for Write busy and Erase busy
 *
 * We've observed some strange SD timing where it takes
 * a really long time to write (which causes a timeout).
 * Normally we expect 3-5 ms for the write to happen so
 * a timeout of 120 ms seems plenty, but we've exceeded this
 * (conditions not understood).  A guess is the SD card is
 * actually doing a remapping of somekind which takes a bunch
 * of time.  Observed time of 190 ms.
 *
 * This impacts the tag because the longer the SD is on the
 * more power it consumes.  So we want to see this condition
 * so we can possibly change things.
 *
 * Strategy is to log excess writes.  But use a long time out
 * for the real failure condition.
 *
 * Expected write time is about 3-5 ms.  Warning generated if
 * we take longer than 3*.  And the failure timeout is set
 * to 150 ms.  This is all fairly arbitrary.
 */
#define SD_WRITE_WARN_THRESHOLD	150
#define SD_WRITE_BUSY_TIMEOUT	300
#define SD_ERASE_BUSY_TIMEOUT	20480


/*
 * Definitions for each of the SD registers
 */
/******************************************************
 * OCR is the OPERATING CONDITIONS REGISTER, stores the
 * Vdd voltage profile of the card. The elements of the
 * the structure must be read as follows
 * v16_17 = Voltage 1.6-1.7 and the same applies
 * to all other elements.
 * 32 bits(4 bytes)
 */
typedef struct {
    uint32_t resvd1          :4;
    uint32_t v16_17          :1;
    uint32_t v17_18          :1;
    uint32_t v18_19          :1;
    uint32_t v19_20          :1;
    uint32_t v20_21          :1;
    uint32_t v21_22          :1;
    uint32_t v22_23          :1;
    uint32_t v23_24          :1;
    uint32_t v24_25          :1;
    uint32_t v25_26          :1;
    uint32_t v26_27          :1;
    uint32_t v27_28          :1;
    uint32_t v28_29          :1;
    uint32_t v29_30          :1;
    uint32_t v30_31          :1;
    uint32_t v31_32          :1;
    uint32_t v32_33          :1;
    uint32_t v33_34          :1;
    uint32_t v34_35          :1;
    uint32_t v35_36          :1;
    uint32_t last            :8;
} sd_ocr_t;


/* CID Card Identification Register
 * 16 bytes
 * contains a unique card identification number
 * cannot be changed
 */
typedef struct {
    uint8_t alwaysONE        :1;
    uint8_t crc7             :7;
    uint8_t mdt_m            :4;
    uint8_t mdt_y;
    uint8_t rsvd             :4;
    uint8_t psn[4];
    uint8_t prv;
    uint8_t pnm[5];
    uint8_t oid[2];
    uint8_t mid;
} sd_cid_t;


/* CARD SPECIFIC REGISTER (16 Bytes) Contains configuration
 * information required to access the card data.
 *
 * The following structure matches CSD Version 1.0 only.
 */
typedef struct {
    uint8_t alwaysONE        :1;
    uint8_t crc7             :7;

    uint8_t rsvd1            :2;
    uint8_t file_format      :2;
    uint8_t tmp_wt_prot      :1;
    uint8_t perm_wt_prot     :1;
    uint8_t copy             :1;
    uint8_t file_form_grp    :1;

    uint8_t rsvd2            :5;
    uint8_t wt_blk_partial   :1;
    uint8_t wt_blk_len       :4;

    uint8_t wt_spd_fact      :3;

    uint8_t rsvd3            :2;

    uint8_t wp_grp_enable    :1;
    uint8_t wt_grp_size      :7;

    uint8_t erase_sect_size  :7;
    uint8_t erase_blk_enable :1;

    uint8_t csize_mult       :3;

    uint8_t vdd_max_w_curr   :3;
    uint8_t vdd_min_w_cur    :3;

    uint8_t vdd_max_rd_curr  :3;
    uint8_t vdd_min_rd_curr  :3;

    uint8_t csize_low        :4;
    uint8_t csize_high;

    uint8_t rsvd4            :2;

    uint8_t dsr_imp          :1;          //DSR implemented

    uint8_t rd_bl_misall     :1;
    uint8_t wt_bl_misall     :1;

    uint8_t rd_bl_partial    :1;

    uint8_t rd_bl_len        :4;
    uint8_t ccc_low          :4;

    uint8_t ccc_high;
    uint8_t tran_speed;
    uint8_t nsac;
    uint8_t taac;

    uint8_t rsvd5            :6;
    uint8_t csd_struct       :2;

} sd_csd_V1_t;


/* CARD SPECIFIC REGISTER (16 Bytes) Contains configuration
 * information required to access the card data.
 *
 * The following structure matches CSD Version 2.0.
 * CSC ver 2 is used for SDHC.
 */
typedef struct {
    uint8_t alwaysONE        :1;
    uint8_t crc7             :7;

    uint8_t rsvd1            :2;
    uint8_t file_format      :2;
    uint8_t tmp_wt_prot      :1;
    uint8_t perm_wt_prot     :1;
    uint8_t copy             :1;
    uint8_t file_form_grp    :1;

    uint8_t rsvd2            :5;
    uint8_t wt_blk_partial   :1;
    uint8_t wt_blk_len       :4;

    uint8_t wt_spd_fact      :3;

    uint8_t rsvd3            :2;

    uint8_t wp_grp_enable    :1;
    uint8_t wt_grp_size      :7;

    uint8_t erase_sect_size  :7;
    uint8_t erase_blk_enable :1;

    uint8_t rsvd4            :1;

    uint8_t csize_low        :6;
    uint8_t csize_high[2];

    uint8_t rsvd5            :6;

    uint8_t dsr_imp          :1;

    uint8_t rd_bl_misall     :1;
    uint8_t wt_bl_misall     :1;
    uint8_t rd_bl_partial    :1;

    uint8_t rd_bl_len        :4;
    uint8_t ccc_low          :4;

    uint8_t ccc_high;

    uint8_t tran_speed;
    uint8_t nsac;
    uint8_t taac;

    uint8_t rsvd6            :6;
    uint8_t csd_struct       :2;

} sd_csd_V2_t;


/* SD Card Configuration Register (64 bits)contains information
 * on the cards special features.
 *
 *
 */
typedef struct {
  uint32_t rsvd1;
  uint16_t rsvd2;
  uint8_t  sd_bus_widths        :4;
  uint8_t  sd_security          :3;
  uint8_t  d_stat_after_erase   :1;
  uint8_t  scr_spec             :4;
  uint8_t  scr_struct           :4;
} sd_scr_t;


/*
 * status register.  Obtained in SPI mode
 * by SD_SEND_STATUS (CMD13).  We then get
 * 16 bits (not 32 like in SD mode) back in
 * the response of the cmd block.
 * This is a standard R2 response, the R1
 * response is the lower 8 bits.
 */
typedef struct {
    uint16_t card_is_locked   :1;
    uint16_t wp_erase_skip    :1;
    uint16_t error            :1;
    uint16_t cc_error         :1;
    uint16_t card_ecc_fail    :1;
    uint16_t wp_violation     :1;
    uint16_t erase_param      :1;
    uint16_t out_rge_csd_ovrwt:1;
    uint16_t idle_state       :1;
    uint16_t erase_rst        :1;
    uint16_t illeg_com        :1;
    uint16_t com_crc_err      :1;
    uint16_t erase_seq_err    :1;
    uint16_t address_err      :1;
    uint16_t param_err        :1;
    uint16_t alwaysZero       :1;
} sd_status_t;


/*
 * SD Card Status (SCS).  Obtained in SPI mode
 * by sending SD_SEND_SCS (ACMD13).  512 bits
 * (64 bytes) which is then sent as a data block.
 */
typedef struct {
    uint8_t rsvd1_high        :5;
    uint8_t secured_mode      :1;
    uint8_t data_bus_width    :2;

    uint8_t rsvd1_low;
    uint8_t sd_card_type[2];
    uint8_t size_prot_area[4];
    uint8_t the_rest[56];
} sd_scs_t;				//512 bits


#endif /* __SD_H__ */
