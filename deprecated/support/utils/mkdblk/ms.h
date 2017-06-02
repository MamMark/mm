/*
 * ms.h - Mass Storage Interface (low level)
 * Copyright 2006, 2010, Eric B. Decker
 * Mam-Mark Project
 *
 * Provides a simple abstraction to the h/w.
 *
 * WARNING: This file is now only used for MKDBLK and
 * is no longer used for building a working embeded system.
 */

#ifndef _MS_H
#define _MS_H

#include "ms_loc.h"

/* needs to agree with SECTOR_SIZE and SD_BLOCKSIZE
   MS_BUF_SIZE includes CRC bytes.
   yeah it is stupid and ugly.

   MS_CRITICAL_BUFS is the number of full buffers that
   will force the MS system to take the usart h/w.
*/
#define MS_BLOCK_SIZE 512
#define MS_BUF_SIZE   514
#define MS_NUM_BUFS   4
//#define MS_CRITICAL_BUFS 3


/*
 * Mass Storage Buffer States
 *
 * Free:	available to be assigned.  empty.
 * Alloc:	allocated.  owned by the collector.
 * Full:	full.  waiting to be written.
 * Busy:	being written by the dma engine
 *
 * Buffer sequencing is critical to the data stream remaining
 * consistant.  Data is composed of a single typed stream being
 * written to a single file.  Buffers must be kept in order.
 * There is a single client of the mass storage (the data collector)
 * and everything is written as typed data.  Buffers are handed to
 * the data collector when requested (ms_get_buffer) in strict
 * order and expected to be handed back in the same order as
 * used.
 *
 * A buffer cycle is as follows:
 *
 * 1) Initially a buffer is marked FREE.
 *
 * 2) The data collector requests the buffer via ms_get_buffer and
 *    the buffer transitions to ALLOC.
 *
 * 3) The data collector fills the buffer and hands it off to
 *    the ms_machine via the message msg_ms_Buffer_Full.
 *
 * 4) When the DMA engine is actively writing the buffer it is
 *    marked BUSY.
 *
 * 5) When the DMA engine completes the write, the buffer is
 *    marked DONE.  And the msg_ms_Buffer_Complete message
 *    is sent to the ms_machine.
 *
 * 6) The ms_machine verifies successful completion of the
 *    write.  Otherwise it performs a limited number of retrys.
 *
 * 7) Upon successful completion, the buffer is marked FREE.
 */

typedef enum {
    MS_BUF_STATE_FREE = 0x1561,
    MS_BUF_STATE_ALLOC,
    MS_BUF_STATE_FULL,
    MS_BUF_STATE_WRITING,
    MS_BUF_STATE_DONE,
    MS_BUF_STATE_MAX
} ms_buf_state_t;


#define MS_BUF_MAJIK 0xeaf0

typedef struct {
    uint16_t majik;
    ms_buf_state_t buf_state;
    uint8_t  buf[MS_BUF_SIZE];		/* includes crc */
} ms_handle_t;


/*
 * MS_HANDLE_OFFSET is used to go from a buffer pointer (buf) back
 * to a ms_buf control structure pointer which we use internally.
 */

#define MS_HANDLE_OFFSET 4


typedef enum {
    MS_STATE_OFF = 0xe0,	/* power is off to the MS device */
    MS_STATE_POWERING_UP,	/* in process of turning on */
    MS_STATE_XFER,		/* writing data out to the MS device, dma */
    MS_STATE_IDLE,		/* powered up but idle */
    MS_STATE_MAX
} ms_state_t;


/*
 * Mass Storage Control Structure
 *
 * There is only one consumer/producer of data for mass storage.  That is
 * the data collector.  The data collector gets and sends back buffers
 * completely sequentially.
 *
 * ms_state:	indicates what the main controller is doing, powering up,
 *		writing via dma, etc.
 * out_index:	Buffer being written out via dma to the mass storage device.
 * in_index:	Next buffer that should be coming back from the collector.
 * alloc_index: Next buffer to be given out.
 * num_full:	number of full buffers including the one being written.
 * max_full:	maximum number of full buffers ever
 *
 * panic_start: where to write panic information when all hell breaks loose
 * panic_end:   end of panic block.
 * config_start: block number of where the config is located.  must be contiguous
 * config_end:  ending block number of end of config.
 * dblk_start:  where to start writing data collected
 * dblk_end:    last block id of where to write data collected.
 * dblk_nxt:	current block to write.  If we are writting this is the
 *		block being written.
 */

typedef struct {
    uint16_t   majik_a;		/* practice safe computing */

    ms_state_t ms_state;	/* current state of machine */
    uint8_t    out_index;	/* buffer going out via dma to the sd card */
    uint8_t    in_index;	/* next buffer that should come back from the collector */
    uint8_t    alloc_index;	/* next buffer to be allocated. */
    uint8_t    num_full;	/* number of full buffers including active */
    uint8_t    max_full;	/* maximum that ever went, max */

    uint32_t panic_start;	/* where to write panic information */
    uint32_t panic_end;
    uint32_t config_start;	/* blk id of configuration */
    uint32_t config_end;
    uint32_t dblk_start;	/* blk id, don't go in front */
    uint32_t dblk_end;		/* blk id, don't go beyond*/
    uint32_t dblk_nxt;		/* blk id, next to write */

    /*
     * PANIC0 is a special block used only by the panic subsystem
     * A special block with panic information is located at sector 2
     * (see ms_loc.h).   panic0_blk will be 0 if not found and the
     * actual location (in blk_id) where the PANIC0 block is located.
     */
    uint32_t panic0_blk;	/* where panic0 block is located */

    uint16_t   majik_b;
} ms_control_t;

#define MSC_MAJIK_A 0x9191
#define MSC_MAJIK_B 0xf423


/*
 * Erased sectors show up as zero.  Not sure if this always
 * works but we don't want to deal with erasure.  So we assume
 * that the dblk area of the flash has been initially erased.
 */
 
/*
 * Mass Storage Timer data
 *
 * Used when using timer functions.
 */

typedef struct {
    uint8_t  which;
    uint8_t  fill_a;
    uint16_t fill_b;
} ms_timer_data_t;

#define MS_TIME_WRITE_TIMEOUT 1


/*
 * Return codes returnable from MS layer
 */

#define MS_ID 0x10

typedef enum {
    MS_OK		= 0,
    MS_FAIL		= (MS_ID | 1),
    MS_READONLY		= (MS_ID | 2),
    MS_INTERNAL		= (MS_ID | 3),
    MS_READ_FAIL	= (MS_ID | 4),
    MS_READ_TOO_SHORT	= (MS_ID | 5),
    MS_WRITE_FAIL	= (MS_ID | 6),
    MS_WRITE_TOO_SHORT	= (MS_ID | 7),
} ms_rtn;


/*
 * extern reference to msc for unix utilities.
 */

extern ms_control_t msc;
extern panic0_hdr_t p0c;

extern ms_rtn ms_init(char *device_name);
extern uint8_t *ms_get_buffer(void);
extern ms_rtn ms_read_blk(uint32_t blk_id, void *buf);
extern ms_rtn ms_read_blk_fail(uint32_t blk_id, void *buf);
extern ms_rtn ms_read8(uint32_t blk_id, void *buf);
extern int    ms_set_blocklen(uint32_t length);
extern ms_rtn ms_write_blk(uint32_t blk_id, void *buf);

extern char * ms_dsp_err(ms_rtn err);

#endif /* _MS_H */
