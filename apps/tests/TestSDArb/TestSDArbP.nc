/*
 * Copyright (c) 2008, Eric B. Decker
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

//#include "printf.h"

uint16_t wait = 1, erase;

module TestSDArbP {
  provides interface Boot as Out_Boot;	/* out to FileSystem */
  uses {
    interface Boot;			/* incoming from Main */
    interface Boot as FS_OutBoot;	/* incoming from FileSystem */

    interface SDread;
    interface SDwrite;
    interface SDerase;
    interface Resource;
  }
}

implementation {

  typedef enum {
    SDArb_0,
    SDArb_1,
    SDArb_2,
  } sd_arb_state_t;

  uint8_t buff[514];
  sd_arb_state_t sd_arb_state;


  event void Boot.booted() {
    while (wait)
      nop();

    signal Out_Boot.booted();		/* tell FileSystem to do its thing */
  }


  event void FS_OutBoot.booted() {	/* FileSystem has finished. */
    call Resource.request();
  }


  event void Resource.granted() {
    if (erase) {
      call SDerase.erase(0x5000, 0x5000);
      return;
    }
    sd_arb_state = SDArb_0;
    call SDread.read(0, buff);
  }


  event void SDerase.eraseDone(uint32_t blk_start, uint32_t blk_end, error_t error) {
    sd_arb_state = SDArb_0;
    call SDread.read(0, buff);
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *buf, error_t error) {
    uint16_t i;
    uint8_t *d;

    switch (sd_arb_state) {
      case SDArb_0:
	sd_arb_state = SDArb_1;
	call SDread.read(0x5000, buff);
	return;

      case SDArb_1:
	d = buf;
	for (i = 0; i < 512; i++)
	  d[i] = i + 1;

	call SDwrite.write(0x5000, buf);
	return;

      default:
      case SDArb_2:
	call Resource.release();
	return;
    }
  }


  event void SDwrite.writeDone(uint32_t blk_id, uint8_t *buf, error_t error) {
    uint16_t i;
    uint8_t *d;

    d = buf;
    for (i = 0; i < 512; i++)
      d[i] = 0;
    sd_arb_state = SDArb_2;
    call SDread.read(0x5000, buf);
    return;
  }


}
