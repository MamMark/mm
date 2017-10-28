/*
 * stream_storage.h - Stream Storage Interface (low level)
 * Copyright (c) 2006, 2010 Eric B. Decker, Carl Davis
 * Copyright (c) 2017, Eric B. Decker
 * Mam-Mark Project
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

#ifndef __STREAM_STORAGE_H__
#define __STREAM_STORAGE_H__

#include "sd.h"

/* Clients should only know about SS_BLOCK_SIZE. */
#define SS_BLOCK_SIZE (SD_BLOCKSIZE)
#define SSW_NUM_BUFS   5

/*
 * SSW_GROUP defines how many buffers to group together before trying to fire up the SD
 * to write them out.   Amortizes the turn on cost over this many buffers.  Note that there
 * need to be more than this number of buffers so the collection system has something to
 * write into while the writes are happening.
 */
#define SSW_GROUP  3

/*
 * Stream Storage Buffer States
 *
 * Free:	available to be assigned.  empty.
 * Alloc:	allocated.  owned by the collector.
 * Full:	full.  waiting to be written.
 * Writing:	being written
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
 *    StreamStorage via the command SSWrite.buffer_full
 *
 * 4) Full buffers are handed to the SD driver in the order they
 *    are received (filled up).  marked WRITING.
 *
 * 5) Upon successful completion, the buffer is marked FREE.
 */

typedef enum {
    SS_BUF_STATE_FREE = 0,
    SS_BUF_STATE_ALLOC,
    SS_BUF_STATE_FULL,
    SS_BUF_STATE_WRITING,
    SS_BUF_STATE_DONE,
    SS_BUF_STATE_MAX,
    SS_BUF_STATE_16 = 0xffff,
} ss_buf_state_t;

typedef enum {
  SS_BUF_SANE = 0x1af0
} ss_buf_majik_t;

typedef struct {
  ss_buf_majik_t majik;
  ss_buf_state_t buf_state;
  uint32_t stamp;
  uint8_t  buf[SD_BLOCKSIZE] __attribute__ ((aligned (4)));     /* 512 */
} ss_wr_buf_t;


/*
 * Stream Storage Control Structure
 *
 * There is only one consumer/producer of data for stream storage.  That is
 * the data collector.  The data collector gets and sends back buffers
 * completely sequentially.
 *
 * state:	 state of the writer
 * dblk:	 block id of where to put the nxt buffer
 * ssw_out: 	 Buffer being written out via dma to the stream storage device.
 * ssw_in:	 Next buffer that should be coming back from the collector.
 * ssw_alloc:    Next buffer to be given out.
 * ssw_num_full: number of full buffers including the one being written.
 * ssw_max_full: maximum number of full buffers ever
 */

typedef enum {
  SSW_IDLE	= 0,
  SSW_REQUESTED,
  SSW_WRITING,
  SSW_16 = 0xffff,              /* force to 16 bit enum */
} ssw_state_t;


typedef struct {
  uint16_t    majik_a;		/* practice safe computing */

  ssw_state_t state;		/* state of the writer. */
  uint32_t    dblk;		/* our idea of where to put the nxt block */
  ss_wr_buf_t *cur_handle;	/* which buffer is being worked on */
  uint8_t     ssw_out;		/* next buffer to be written to mass storage */
  uint8_t     ssw_in;		/* next buffer that should come back from the collector */
  uint8_t     ssw_alloc;	/* next buffer to be allocated. */
  uint8_t     ssw_num_full;	/* number of full buffers including active */
  uint8_t     ssw_max_full;	/* maximum that ever went, max */
  uint8_t     pad;

  uint16_t    majik_b;		/* tombstone */
} ss_control_t;

#define SSC_MAJIK 0x9191

#endif /* __STREAM_STORAGE_H__ */
