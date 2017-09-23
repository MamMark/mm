/**
 * Copyright (c) 2017 Eric B. Decker, Miles Maltbie
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

/*
 * @author Eric B. Decker
 * @author Miles Maltbie
 *
 * Configuration wiring for ImageManager.  See ImageManagerP for more
 * details on what ImageManager does.
 */

#include <image_mgr.h>

configuration ImageManagerC {
  provides {
    interface  Boot            as Booted;   /* out Booted signal */
    interface  ImageManager    as IM[uint8_t cid];
    interface ImageManagerData as IMD;
  }
  uses interface Boot;			/* incoming signal */
}
implementation {
  components ImageManagerP as IM_P;
  IM     = IM_P;
  IMD    = IM_P;
  Booted = IM_P;
  Boot   = IM_P;

  components FileSystemC as FS;
  IM_P.FS -> FS;

  components new SD0_ArbC() as SD;
  IM_P.SDResource -> SD;
  IM_P.SDread     -> SD;
  IM_P.SDwrite    -> SD;

  components ChecksumM;
  IM_P.Checksum -> ChecksumM;

  components PanicC;
  IM_P.Panic -> PanicC;
}
