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

#define SD_READ_TIMEOUT  32768UL
#define SD_WRITE_TIMEOUT 32768UL


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
    uint32_t resvd1    :4;
    uint32_t v16_17    :1;
    uint32_t v17_18    :1;
    uint32_t v18_19    :1;
    uint32_t v19_20    :1;
    uint32_t v20_21    :1;
    uint32_t v21_22    :1;
    uint32_t v22_23    :1;
    uint32_t v23_24    :1;
    uint32_t v24_25    :1;
    uint32_t v25_26    :1;
    uint32_t v26_27    :1;
    uint32_t v27_28    :1;
    uint32_t v28_29    :1;
    uint32_t v29_30    :1;
    uint32_t v30_31    :1;
    uint32_t v31_32    :1;
    uint32_t v32_33    :1;
    uint32_t v33_34    :1;
    uint32_t v34_35    :1;
    uint32_t v35_36    :1;
    uint32_t last      :8;
} sd_ocr_t;


/* CID Card Identification Register 
 * 16 bytes
 * contains a unique card identification number
 * cannot be changed
 */
typedef struct {
    uint8_t mid;
    uint8_t oid[2];
    uint8_t pnm[5];
    uint8_t prv;
    uint8_t psn[4];
    uint8_t mdt_y1 : 4;
    uint8_t rsvd   : 4;
    uint8_t mdt_m  : 4;
    uint8_t mdt_y0 : 4;
    uint8_t last;
} sd_cid_t;


/* CARD SPECIFIC REGISTER (16 Bytes) Contains configuration
 * information required to access the card data.
 *
 *
 */
typedef struct {
    uint8_t rsvd1            :6;
    uint8_t csd_struct       :2;
    
    uint8_t taac;
    
    uint8_t nsac;
    
    uint8_t tran_speed;
    
    uint8_t ccc_high;

    uint8_t rd_bl_len        :4;
    uint8_t ccc_low          :4;

    uint8_t csize_high       :2;
    uint8_t rsvd2            :2;
    uint8_t dsr_imp          :1;
    uint8_t rd_bl_misall     :1;
    uint8_t wt_bl_misall     :1;
    uint8_t rd_bl_partial    :1;
    
    uint8_t csize_mid; 
    
    uint8_t vdd_max_rd_curr  :3;
    uint8_t vdd_min_rd_curr  :3;
    uint8_t csize_low        :2;
    
    uint8_t csize_mlt_high   :2;
    uint8_t vdd_max_w_curr   :3;
    uint8_t vdd_min_w_curr   :3;

    uint8_t sect_size_high   :6; 
    uint8_t erase_blk_enable :1;   
    uint8_t csize_mlt_low    :1;
  
    uint8_t grp_size         :7;
    uint8_t sect_size_low    :1;

    uint8_t wt_blk_len_high  :2;
    uint8_t wt_spd_fact      :3;          
    uint8_t rsvd3            :2;
    uint8_t wp_grp_enable    :1;

    uint8_t rsvd4            :5;
    uint8_t wt_blk_partial   :1;   
    uint8_t wt_blk_len_low   :2;

    uint8_t rsvd5            :2;
    uint8_t file_format      :2;
    uint8_t tmp_wt_prot      :1;
    uint8_t perm_wt_prot     :1;
    uint8_t copy             :1;
    uint8_t file_form_grp    :1;
    
    uint8_t alwaysONE        :1;
    uint8_t crc              :7;   
} sd_csd_t;


/* SD Card Configuration Register (64 bits)contains information 
 * on the cards special features.
 *
 *
 */
typedef struct {
  uint8_t  scr_spec             :4;
  uint8_t  scr_struct           :4;
  uint8_t  sd_bus_widths        :4;
  uint8_t  sd_security          :3;
  uint8_t  d_stat_after_erase   :1;
  uint16_t rsvd1;
  uint32_t rsvd2;
} sd_scr_t;


/*
 * status register.  Obtained in SPI mode
 * by SD_SEND_STATUS (CMD13).  We then get
 * 16 bits (not 32 like in SD mode) back in
 * the response of the cmd block.
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

    uint16_t sd_card_type;

    uint32_t size_prot_area;

    uint8_t the_rest[56];

} sd_scs_t;//512 bits


#endif /* __SD_H__ */
