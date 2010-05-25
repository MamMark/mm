/*
 * sd - low level Secure Digital storage
 *
 * SD card driver
 */


#ifndef __SD_H__
#define __SD_H__

/*
 * hardware interface dependencies can be found in
 * tos/platforms/<platform>/hardware.h and platform_sd_spi.h
 */

#define SD_RESET_IDLES  74

#define SD_BLOCKSIZE 512
#define SD_BLOCKSIZE_NBITS 9

/*
 * all data transfers to/from the SD include a 2 byte crc which is
 * assumed to be included in any buffers passed into the SD driver.
 */
#define SD_BUF_SIZE 514

/*
 * read.read launches a read and then polls the SD card
 * waiting for the card to say it has the data ready.  The
 * SD card starts sending the data using a START_TOKEN.
 * We will poll a maximum of SD_READ_TOK_MAX times before
 * bitching
 */
#define SD_READ_TOK_MAX 512


#define SD_WRITE_TIMEOUT 32768UL


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
#define SD_CMD_TIMEOUT 1024


/* dma xfer timeout in mis (binary milliseconds) */
#define SD_SECTOR_XFER_TIMEOUT	4


/* timeout values for Write busy and Erase busy */
#define SD_WRITE_BUSY_TIMEOUT	120
#define SD_ERASE_BUSY_TIMEOUT	10240


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
