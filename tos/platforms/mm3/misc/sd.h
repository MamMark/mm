/*
 * sd - low level Secure Digital storage
 *
 * SD card driver
 */


#ifndef __SD_H__
#define __SD_H__

/*
 * when reseting the SD we don't want to be any faster
 * then 400KHz.  We divide by 11 to be on the safe side.
 * Normal operation we run with the maximum clock rate which
 * is /2.  Which is the minimum UBR allowed.
 */

#define SPI_400K_DIV 11
#define SPI_2M_DIV    2
#define SD_RESET_IDLES  74

#define SD_BLOCKSIZE 512
#define SD_BLOCKSIZE_NBITS 9

#define SD_READ_TIMEOUT  32768UL
#define SD_WRITE_TIMEOUT 32768UL


/*
 * Return codes returnable from MS layer
 */

#define SD_ID 0x30

typedef enum {
    SD_OK		= 0,
    SD_RETRY		= (SD_ID | 1),
    SD_FAIL		= (SD_ID | 2),
    SD_INTERNAL		= (SD_ID | 3),
    SD_CMD_FAIL		= (SD_ID | 4),
    SD_BAD_RESPONSE	= (SD_ID | 5),
    SD_INIT_TIMEOUT	= (SD_ID | 6),
    SD_BAD_PWR		= (SD_ID | 7),
    SD_WRITE_ERR	= (SD_ID | 8),
    SD_READ_ERR		= (SD_ID | 9),
    SD_CRC_FAIL		= (SD_ID | 10),
} sd_rtn;


/* ACMD_FLAG is or'd in with cmd to indicate CMD55 is needed first
   R1B_FLAG is or'd with rsp_len to indicate a busy wait is needed.
*/

#define ACMD_FLAG 0x80
#define CMD_MASK  0x7f
#define R1B_FLAG  0x80
#define RSP_LEN_MASK 0x7f

typedef struct {
    uint8_t  cmd;		/* high bit says acmd */
    uint8_t  rsp_len;		/* how long of a response */
    uint8_t  arg[4];
    uint8_t  rsp[5];
    uint8_t  rsp55;
    uint8_t  stage;		/* where did it bail. */
    uint16_t stage_count;	/* timeout value */
} sd_cmd_blk_t;

extern bool  sd_busyflag;

extern sd_cmd_blk_t sd_cmd;

extern uint16_t sd_r1b_timeout;
extern uint16_t sd_rd_timeout;
extern uint16_t sd_wr_timeout;
extern uint16_t sd_reset_timeout;
extern uint16_t sd_busy_timeout;

#define SD_CMD_INST_MAX 10

typedef struct {
    sd_cmd_blk_t cmd;
    uint8_t  aux_rsp;
    uint16_t rep_count;
} sd_cmd_inst_t;


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


/* Response Lengths */
#define R1_LEN	1
#define R1B_LEN (1 | R1B_FLAG)
#define R2_LEN	2
#define R3_LEN	5

#define MSK_IDLE 0x01
#define MSK_ERASE_RST 0x02
#define MSK_ILL_CMD 0x04
#define MSK_CRC_ERR 0x08
#define MSK_ERASE_SEQ_ERR 0x10
#define MSK_ADDR_ERR 0x20
#define MSK_PARAM_ERR 0x40

#define SD_TOK_READ_STARTBLOCK 0xFE
#define SD_TOK_WRITE_STARTBLOCK 0xFE
#define SD_TOK_READ_STARTBLOCK_M 0xFE
#define SD_TOK_WRITE_STARTBLOCK_M 0xFC
#define SD_TOK_STOP_MULTI 0xFD

/* Error token is 000XXXXX */
#define MSK_TOK_DATAERROR 0xE0

/* Bit fields */
#define MSK_TOK_ERROR 0x01
#define MSK_TOK_CC_ERROR 0x02
#define MSK_TOK_ECC_FAILED 0x04
#define MSK_TOK_CC_OUTOFRANGE 0x08
#define MSK_TOK_CC_LOCKED 0x10

/* Mask off the bits in the OCR corresponding to voltage range 3.2V to
   3.4V, OCR bits 20 and 21
*/
#define MSK_OCR_33 0xC0

/* Number of times to retry the probe cycle during initialization */
#define SD_INIT_TRY 50

/* Number of tries to wait for the card to go idle during initialization */
#define SD_IDLE_WAIT_MAX 512

/* Hardcoded timeout for commands. */
#define SD_CMD_TIMEOUT 1024

/******************************** Basic command set **************************/

/* Reset cards to idle state */
#define CMD0 0
#define SD_FORCE_IDLE CMD0
#define SD_FORCE_IDLE_R R1_LEN

/* MMC version of go operational.  Don't use for SD */
#define CMD1 1
#define MMC_GO_OP CMD1
#define MMC_GO_OP_R R1_LEN

/* Card sends the CSD, Card Specific Data */
#define CMD9 9
#define SD_SEND_CSD CMD9
#define SD_SEND_CSD_R R1_LEN
#define SD_CSD_LEN 16

/* Card sends CID, Card Identification */
#define CMD10 10
#define SD_SEND_CID CMD10
#define SD_SEND_CID_R R1_LEN
#define SD_CID_LEN 16

/* Stop a multiblock (stream) read/write operation */
#define CMD12 12
#define SD_STOP_TRANS CMD12
#define SD_STOP_TRANS_R R1B_LEN

/* Get the addressed card's status register */
#define CMD13 13
#define SD_SEND_STATUS CMD13
#define SD_SEND_STATUS_R R2_LEN

/***************************** Block read commands **************************/

/* Set the block length, how much to read or write */
#define CMD16 16
#define SD_SET_BLOCKLEN CMD16
#define SD_SET_BLOCKLEN_R R1_LEN

/* Read a single block */
#define CMD17 17
#define SD_READ_BLOCK CMD17
#define SD_READ_BLOCK_R R1_LEN

/* Read multiple blocks until a CMD12 */
#define CMD18 18
#define SD_READ_MULTI CMD18
#define SD_READ_MULTI_R R1_LEN

/***************************** Block write commands *************************/

/* Write a block of blocklen size (see CMD16) */
#define CMD24 24
#define SD_WRITE_BLOCK CMD24
#define SD_WRITE_BLOCK_R R1_LEN

/* Multiple block write until a CMD12 */
#define CMD25 25
#define SD_WRITE_MULTI CMD25
#define SD_WRITE_MULTI_R R1_LEN

/* Program the programmable bits of the CSD */
#define CMD27 27
#define SD_WRITE_CSD CMD27
#define SD_WRITE_CSD_R R1_LEN

/***************************** Write protection *****************************/

/* Set the write protection bit of the addressed group */
#define CMD28 28
#define SD_SET_PROTECT CMD28
#define SD_SET_PROTECT_R R1B_LEN

/* Clear the write protection bit of the addressed group */
#define CMD29 29
#define SD_CLR_PROTECT CMD29
#define SD_CLR_PROTECT_R R1B_LEN

/* Ask the card for the status of the write protection bits */
#define CMD30 30
#define SD_SEND_PROTECT CMD29
#define SD_SEND_PROTECT_R R1_LEN

/***************************** Erase commands *******************************/

/* Set the address of the first write block to be erased */
#define CMD32 32
#define SD_SET_ERASE_START CMD32
#define SD_SET_ERASE_START_R R1_LEN

/* Set the address of the last write block to be erased */
#define CMD33 33
#define SD_SET_ERASE_END CMD33
#define SD_SET_ERASE_END_R R1_LEN

/* Erase the selected write blocks */
#define CMD38 38
#define SD_ERASE CMD38
#define SD_ERASE_R R1B_LEN

/***************************** Lock Card commands ***************************/
/* Commands from 42 to 54, not defined here */

/***************************** Application-specific commands ****************/

/* Flag that the next command is application-specific */
#define CMD55 55
#define SD_APP_CMD CMD55
#define SD_APP_CMD_R R1_LEN

/* General purpose I/O for application-specific commands */
#define CMD56 56
#define SD_GEN_CMD CMD56
#define SD_GEN_CMD_R R1_LEN

/* Read the OCR (SPI mode only), Operation Condition Register */
#define CMD58 58
#define SD_SEND_OCR CMD58
#define SD_SEND_OCR_R R3_LEN

/* Turn CRC on or off */
#define CMD59 59
#define SD_SET_CRC CMD59
#define SD_SET_CRC_R R1_LEN

/***************************** Application-specific commands ***************/

/* Get the SD card's status */
#define ACMD13 (13 | ACMD_FLAG)
#define SD_SEND_SCS ACMD13
#define SD_SEND_SCS_R R2_LEN
#define SD_SCS_LEN 64

/* Get the number of written write blocks (Minus errors ) */
#define ACMD22 (22 | ACMD_FLAG)
#define SD_SEND_WRITTEN_BLOCKS ACMD22
#define SD_SEND_WRITTEN_BLOCKS_R R1_LEN

/* Set the number of write blocks to be pre-erased before writing */
#define ACMD23 (23 | ACMD_FLAG)
#define SD_SET_PRE_ERASE ACMD23
#define SD_SET_PRE_ERASE_R R1_LEN

/* SD SPI go operational */
#define ACMD41 (41 | ACMD_FLAG)
#define SD_GO_OP ACMD41
#define SD_GO_OP_R R1_LEN

/* Connect or disconnect the 50kOhm internal pull-up on CD/DAT[3] */
#define ACMD42 (42 | ACMD_FLAG)
#define SD_SET_CARD_DETECT ACMD42
#define SD_SET_CARD_DETECT_R R1_LEN

/* Get the SD configuration register */
#define ACMD51 (51 | ACMD_FLAG)
#define SD_SEND_SCR ACMD51
#define SD_SEND_SCR_R R1_LEN
#define SD_SCR_LEN 8

#endif /* __SD_H__ */
