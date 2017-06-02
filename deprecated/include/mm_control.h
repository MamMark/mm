/*
 * Copyright (c) 2008, 2010 Eric B. Decker.
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

/**
 * @author Eric B. Decker <cire831@gmail.com>
 * @date April 13, 2010
 */

#ifndef MM_CONTROL_MSG_H
#define MM_CONTROL_MSG_H

#include "message.h"

typedef nx_struct mm_cmd {
  nx_uint8_t len;
  nx_uint8_t cmd;
  nx_uint8_t seq;
  nx_uint8_t  data[0];
} mm_cmd_t;


enum {
  CMD_PING		= 0,
  CMD_WR_NOTE		= 1,
  CMD_RESPONSE		= 0x80,
};


typedef nx_struct mm_cmd_note {
  nx_uint16_t	     year;
  nx_uint8_t	     month;
  nx_uint8_t	     day;
  nx_uint8_t	     hrs;
  nx_uint8_t	     min;
  nx_uint8_t	     sec;
  nx_uint8_t	     len;
  nx_uint8_t	     data[0];
} mm_cmd_note_t;

/*
 * Not actually used.  Only here to make "mig" happy.
 */
enum {
  AM_MM_CMD         = 0xA0,
  AM_MM_CMD_NOTE    = 0xA0,
};

#endif
