/*
 * stream_storage.h - Stream Storage Interface (low level)
 * Copyright 2006, Eric B. Decker
 * Mam-Mark Project
 *
 * Port to TinyOS 2x
 * Copyright 2008, Eric B. Decker
 */

#ifndef _STREAM_STORAGE_H
#define _STREAM_STORAGE_H

/* needs to agree with SECTOR_SIZE and SD_BLOCKSIZE
   yeah it is stupid and ugly

   SS_CRITICAL_BUFS is the number of full buffers that
   will force the SS system to take the usart h/w.
*/
#define SS_BLOCK_SIZE 512
#define SS_NUM_BUFS   4
#define SS_CRITICAL_BUFS 3


/*
 * Stream Storage Buffer States
 *
 * Free:	available to be assigned.  empty.
 * Alloc:	allocated.  owned by the collector.
 * Full:	full.  waiting to be written.
 * Busy:	being written by the dma engine
 *
 * Buffer sequencing is critical to the data stream remaining
 * consistant.  Data is composed of a single typed stream being
 * written to a single file.  Buffers must be kept in order.
 * There is a single client of the stream storage (the data collector)
 * and everything is written as typed data.  Buffers are handed to
 * the data collector when requested (get_buffer) in strict
 * order and expected to be handed back in the same order as
 * used.
 *
 * A buffer cycle is as follows:
 *
 * 1) Initially a buffer is marked FREE.
 *
 * 2) The data collector requests the buffer via get_buffer and
 *    the buffer transitions to ALLOC.
 *
 * 3) The data collector fills the buffer and hands it off to
 *    StreamStorage via the command StreamStorage.write_buf.
 *
 * 4) When the DMA engine is actively writing the buffer it is
 *    marked BUSY.
 *
 * 5) When the DMA engine completes the write, the buffer is
 *    marked DONE.  And the event SD.dma_done is sent
 *    back to the StreamStorage implementation.  (This should
 *    happen in the SD driver).
 *
 * 7) Upon successful completion, the buffer is marked FREE.
 */

typedef enum {
    SS_BUF_STATE_FREE = 0x1561,
    SS_BUF_STATE_ALLOC,
    SS_BUF_STATE_FULL,
    SS_BUF_STATE_WRITING,
    SS_BUF_STATE_DONE,
    SS_BUF_STATE_MAX
} ss_buf_state_t;


#define SS_BUF_MAJIK 0xeaf0

typedef struct {
    uint16_t majik;
    ss_buf_state_t buf_state;
    uint8_t  buf[SS_BLOCK_SIZE];
} ss_handle_t;


typedef enum {
  SS_STATE_CRASHED	= 0xe0,	/* something went wrong with stream storage.  hard fail */
  SS_STATE_UNINITILIZED,	/* dblk locator not found */
  SS_STATE_OFF = 0xe0,		/* power is off to the SS device */
  SS_STATE_POWERING_UP,		/* in process of turning on */
  SS_STATE_XFER,		/* writing data out to the SS device, dma */
  SS_STATE_IDLE,		/* powered up but idle */
  SS_STATE_MAX
} ss_state_t;


/*
 * Stream Storage Control Structure
 *
 * There is only one consumer/producer of data for stream storage.  That is
 * the data collector.  The data collector gets and sends back buffers
 * completely sequentially.
 *
 * ss_state:	indicates what the main controller is doing, powering up,
 *		writing via dma, etc.
 * out_index:	Buffer being written out via dma to the stream storage device.
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

    ss_state_t ss_state;	/* current state of machine */
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

    uint16_t   majik_b;
} ss_control_t;

#define SSC_MAJIK_A 0x9191
#define SSC_MAJIK_B 0xf423


/*
 * Erased sectors show up as zero.  Not sure if this always
 * works but we don't want to deal with erasure.  So we assume
 * that the dblk area of the flash has been initially erased.
 */
 
#define TAG_DBLK_SIG 0xdeedbeaf
#define DBLK_LOC_OFFSET 0x01a8

typedef struct {
    uint32_t sig;
    uint32_t panic_start;
    uint32_t panic_end;
    uint32_t config_start;
    uint32_t config_end;
    uint32_t dblk_start;
    uint32_t dblk_end;
    uint16_t dblk_chksum;
} dblk_loc_t;

#define DBLK_LOC_SIZE 30
#define DBLK_LOC_SIZE_SHORTS 15

#endif /* _STREAM_STORAGE_H */
