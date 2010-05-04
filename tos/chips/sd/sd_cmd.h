/*
 * sd - low level Secure Digital storage
 */

#ifndef __SD_CMD_H__
#define __SD_CMD_H__

/*
 * hardware interface dependencies can be found in
 * tos/platforms/<platform>/hardware.h and platform_sd_spi.h
 */


/*
 * send_cmd used to handle ACMD too by first sending a CMD55.  This
 * was indicated by ACMD_FLAG being set (high order bit).  It makes
 * more sense to manage this manually and to call a different routine
 * that handles sending the CMD55 and the ACMD.
 *
 * R1B_FLAG is or'd with rsp_len to indicate a busy wait is needed.
*/

#define R1B_FLAG  0x80
#define RSP_LEN_MASK 0x7f

typedef struct sd_cmd {
  uint8_t     cmd;
  nx_uint32_t arg;
  uint8_t     crc;
  uint8_t     rsp[5];
} sd_cmd_t;


typedef struct {
  uint8_t  rsp_len;		/* how long of a response */
  uint8_t  rsp55;
  uint8_t  stage;		/* where did it bail. */
  uint16_t stage_count;	/* timeout value */
} sd_ctl_t;


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
#define SD_SEND_PROTECT CMD30
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
#define ACMD13 13
#define SD_SEND_SCS ACMD13
#define SD_SEND_SCS_R R2_LEN
#define SD_SCS_LEN 64

/* Get the number of written write blocks (Minus errors ) */
#define ACMD22 22
#define SD_SEND_WRITTEN_BLOCKS ACMD22
#define SD_SEND_WRITTEN_BLOCKS_R R1_LEN

/* Set the number of write blocks to be pre-erased before writing */
#define ACMD23 23
#define SD_SET_PRE_ERASE ACMD23
#define SD_SET_PRE_ERASE_R R1_LEN

/* SD SPI go operational */
#define ACMD41 41
#define SD_GO_OP ACMD41
#define SD_GO_OP_R R1_LEN

/* Connect or disconnect the 50kOhm internal pull-up on CD/DAT[3] */
#define ACMD42 42
#define SD_SET_CARD_DETECT ACMD42
#define SD_SET_CARD_DETECT_R R1_LEN

/* Get the SD configuration register */
#define ACMD51 51
#define SD_SEND_SCR ACMD51
#define SD_SEND_SCR_R R1_LEN
#define SD_SCR_LEN 8

#endif /* __SD_CMD_H__ */
