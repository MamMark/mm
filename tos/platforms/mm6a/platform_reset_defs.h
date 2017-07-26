/*
 * Copyright (c) 2017 Eric B. Decker
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
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

/*
 * Definitions for Platform Resets
 */

#ifndef __PLATFORM_RESET_DEFS_H__
#define __PLATFORM_RESET_DEFS_H__

#include <sysreboot.h>

enum {
  SYSREBOOT_OW_REQUEST = SYSREBOOT_EXTEND,
};

#define PRD_RESET_KEY   RSTCTL_RESETREQ_RSTKEY_VAL
#define PRD_RESET_HARD  RSTCTL_RESET_REQ_HARD_REQ
#define PRD_RESET_SOFT  RSTCTL_RESET_REQ_SOFT_REQ

#define PRD_RESET_OW_REQ RSTCTL_HARDRESET_STAT_SRC4

#define PRD_PSS_VCCDET  RSTCTL_PSSRESET_STAT_VCCDET
#define PRD_PSS_SVSH    RSTCTL_PSSRESET_STAT_SVSMH
#define PRD_PSS_BGREF   RSTCTL_PSSRESET_STAT_BGREF

#define PRD_CS_DCOR_SHT RSTCTL_CSRESET_STAT_DCOR_SHT

#endif    /* __PLATFORM_RESET_DEFS_H__ */
