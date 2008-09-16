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

#include "sd.h"

/* needs to agree with SECTOR_SIZE and SD_BLOCKSIZE
   yeah it is stupid and ugly
*/
#define SS_BLOCK_SIZE 512
#define SSW_NUM_BUFS   4
#define SSR_NUM_REQS   4


/*
 * Stream Storage Buffer States
 * used for both Reader and Writer interfaces
 *
 * Free:	available to be assigned.  empty.
 * Alloc:	allocated.  owned by the collector.
 * Full:	full.  waiting to be written.
 * Writing:	being written by the dma engine
 * Reading:	being read by the dma engine.
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
 * Reading is done on a per block basis and doesn't have the
 * strict sequencing criteria.  Requests are processed in order.
 *
 * A buffer cycle is as follows:
 *
 * 1) Initially a buffer or request is marked FREE.
 *
 * 2) The data collector requests the buffer via get_buffer and
 *    the buffer transitions to ALLOC.
 *
 * 3) The data collector fills the buffer and hands it off to
 *    StreamStorage via the command StreamStorage.buffer_full
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
 *
 *
 * Read cycle.
 *
 * 1) Initially all read request blocks are marked FREE
 *
 * 2) The caller will request a particular block and provide a buffer
 *    for the data.
 *
 * 3) The request will be placed in the next free read request block.
 *    and the reader semaphore will be kicked to wake up the reader.
 */

typedef enum {
    SS_REQ_STATE_FREE = 0x1561,
    SS_REQ_STATE_ALLOC,
    SS_REQ_STATE_FULL,
    SS_REQ_STATE_WRITING,
    SS_REQ_STATE_READING,
    SS_REQ_STATE_DONE,
    SS_REQ_STATE_MAX
} ss_req_state_t;


#define SS_REQ_MAJIK 0xeaf0

typedef struct {
    uint16_t majik;
    ss_req_state_t req_state;
    uint32_t stamp;
    uint8_t  buf[SS_BLOCK_SIZE + 2]; /* include room for CRC */
} ss_wr_req_t;


typedef struct {
  uint16_t majik;
  ss_req_state_t  req_state;
  uint32_t stamp;
  uint32_t blk;
  uint8_t *buf;
} ss_rd_req_t;


typedef enum {
  SS_STATE_CRASHED	= 0x10,	/* something went wrong with stream storage.  hard fail */
  SS_STATE_OFF,			/* power is off to the SS device */
  SS_STATE_XFER_R,		/* reading data from the SD */
  SS_STATE_XFER_W,		/* writing data out to the SS device, dma */
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
 * ssw_out:	Buffer being written out via dma to the stream storage device.
 * ssw_in:	Next buffer that should be coming back from the collector.
 * ssw_alloc:   Next buffer to be given out.
 * ssw_num_full:number of full buffers including the one being written.
 * ssw_max_full:maximum number of full buffers ever
 *
 * ssr_in:	request that will be used next
 * ssr_out:	request being processed
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

    uint8_t    ssw_out;		/* buffer going out via dma to the sd card */
    uint8_t    ssw_in;		/* next buffer that should come back from the collector */
    uint8_t    ssw_alloc;	/* next buffer to be allocated. */
    uint8_t    ssw_num_full;	/* number of full buffers including active */
    uint8_t    ssw_max_full;	/* maximum that ever went, max */

    uint8_t    ssr_in;		/* next request to use */
    uint8_t    ssr_out;		/* next request to process */

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
 

/*
 * StreamStorage also has an interface that allows reading
 * of raw blocks.  Raw because it is simple.  Yes this is a
 * wart that goes around the StreamStorage abstraction, but
 * StreamStorage is what knows about where things (panic, config,
 * data areas).  So it is a compromise to sit on top of Stream
 * Storage.
 */

enum {
  SS_AREA_PANIC  = 0,
  SS_AREA_CONFIG = 1,
  SS_AREA_DATA   = 2,
};

#endif /* _STREAM_STORAGE_H */
