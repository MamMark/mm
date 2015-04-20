/**
 * sd_cmd.h - low level Secure Digital storage  (definitions)
 *
 * Copyright (c) 2010 Eric B. Decker
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

#ifndef __SD_CMD_H__
#define __SD_CMD_H__

/*
 * hardware interface dependencies can be found in
 * tos/platforms/<platform>/hardware.h and platform_spi_sd.h
 */

typedef struct sd_cmd {
  uint8_t     cmd;
  nx_uint32_t arg;
  uint8_t     crc;
} sd_cmd_t;


#define MSK_IDLE 0x01
#define MSK_ERASE_RST 0x02
#define MSK_ILL_CMD 0x04
#define MSK_CRC_ERR 0x08
#define MSK_ERASE_SEQ_ERR 0x10
#define MSK_ADDR_ERR 0x20
#define MSK_PARAM_ERR 0x40

#define SD_START_TOK 0xfe
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


/******************************** Basic command set **************************/

/*
 * 0x40 is or'd to all cmds to indicate start bit and the cmd bit.
 * This avoids having to do this in the code when a cmd is used.
 */

/* Reset cards to idle state */
#define CMD0 (0 | 0x40)
#define SD_FORCE_IDLE CMD0

/* MMC version of go operational.  Don't use for SD */
#define CMD1 (1 | 0x40)
#define MMC_GO_OP CMD1

/* get simplified voltage supported, and enable SDHC
 * And now for a brief moment of whining:  Why can't
 * they name things in English or any other reasonable
 * language.  Bastard committees!
 */
#define CMD8 (8 | 0x40)
#define SD_SEND_IF_CONDITION CMD8

/* Card sends the CSD, Card Specific Data
 * include CRC (2 bytes) in length
 */
#define CMD9 (9 | 0x40)
#define SD_SEND_CSD CMD9
#define SD_CSD_LEN 18

/* Card sends CID, Card Identification
 * Note, SD_CID_LEN includes a 16 bit CRC on the end.
 */
#define CMD10 (10 | 0x40)
#define SD_SEND_CID CMD10
#define SD_CID_LEN 18

/* Stop a multiblock (stream) read/write operation */
#define CMD12 (12 | 0x40)
#define SD_STOP_TRANS CMD12

/* Get the addressed card's status register */
#define CMD13 (13 | 0x40)
#define SD_SEND_STATUS CMD13


/***************************** Block read commands **************************/

/* Set the block length, how much to read or write */
#define CMD16 (16 | 0x40)
#define SD_SET_BLOCKLEN CMD16

/* Read a single block */
#define CMD17 (17 | 0x40)
#define SD_READ_BLOCK CMD17

/* Read multiple blocks until a CMD12 */
#define CMD18 (18 | 0x40)
#define SD_READ_MULTI CMD18


/***************************** Block write commands *************************/

/* Write a block of blocklen size (see CMD16) */
#define CMD24 (24 | 0x40)
#define SD_WRITE_BLOCK CMD24

/* Multiple block write until a CMD12 */
#define CMD25 (25 | 0x40)
#define SD_WRITE_MULTI CMD25

/* Program the programmable bits of the CSD */
#define CMD27 (27 | 0x40)
#define SD_WRITE_CSD CMD27


/***************************** Write protection *****************************/

/* Set the write protection bit of the addressed group */
#define CMD28 (28 | 0x40)
#define SD_SET_PROTECT CMD28

/* Clear the write protection bit of the addressed group */
#define CMD29 (29 | 0x40)
#define SD_CLR_PROTECT CMD29

/* Ask the card for the status of the write protection bits */
#define CMD30 (30 | 0x40)
#define SD_SEND_PROTECT CMD30


/***************************** Erase commands *******************************/

/* Set the address of the first write block to be erased */
#define CMD32 (32 | 0x40)
#define SD_SET_ERASE_START CMD32

/* Set the address of the last write block to be erased */
#define CMD33 (33 | 0x40)
#define SD_SET_ERASE_END CMD33

/* Erase the selected write blocks */
#define CMD38 (38 | 0x40)
#define SD_ERASE CMD38


/***************************** Lock Card commands ***************************/
/* Commands from 42 to 54, not defined here */


/***************************** Application-specific commands ****************/

/* Flag that the next command is application-specific */
#define CMD55 (55 | 0x40)
#define SD_APP_CMD CMD55

/* General purpose I/O for application-specific commands */
#define CMD56 (56 | 0x40)
#define SD_GEN_CMD CMD56

/* Read the OCR (SPI mode only), Operation Condition Register */
#define CMD58 (58 | 0x40)
#define SD_SEND_OCR CMD58

/* Turn CRC on or off */
#define CMD59 (59 | 0x40)
#define SD_SET_CRC CMD59


/***************************** Application-specific commands ***************/

/* Get the SD card's status */
#define ACMD13 (13 | 0x40)
#define SD_SEND_SD_STATUS ACMD13
#define SD_SEND_SD_STATUS_LEN 64

/* Get the number of written write blocks (Minus errors ) */
#define ACMD22 (22 | 0x40)
#define SD_SEND_WRITTEN_BLOCKS ACMD22

/* Set the number of write blocks to be pre-erased before writing */
#define ACMD23 (23 | 0x40)
#define SD_SET_PRE_ERASE ACMD23

/* SD SPI go operational */
#define ACMD41 (41 | 0x40)
#define SD_GO_OP ACMD41

/* Connect or disconnect the 50kOhm internal pull-up on CD/DAT[3] */
#define ACMD42 (42 | 0x40)
#define SD_SET_CARD_DETECT ACMD42

/* Get the SD configuration register */
#define ACMD51 (51 | 0x40)
#define SD_SEND_SCR ACMD51
#define SD_SCR_LEN 8


#endif /* __SD_CMD_H__ */
