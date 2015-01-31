/*
 * Copyright 2012, 2014 (c) Eric B. Decker
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
 * @author Eric B. Decker
 */

#ifndef _H_PLATFORM_H_
#define _H_PLATFORM_H_

#define REQUIRE_PANIC
#define REQUIRE_PLATFORM
#define FORCE_ATOMIC
#define TRACE_MICRO
//#define TRACE_USE_PLATFORM

#include "platform_panic.h"

/*
 * The msp430 LocalTimeMicro implementation by default uses LocalTimeHybridMicro
 * implementation which is very expensive and busy waits on the 32Khz timer.
 *
 * We don't want this.
 */
#define DISABLE_HYBRID_MICRO

/*
 * The exp5438 motes use a msp430f5438a and when we use -Os h/w access (mem mapped i/o)
 * occurs using single instructions.  So we turn on various port access
 * optimizations if we are compiling using -Os.
 *
 * Well __OPTIMIZE_SIZE__ is supposed to be defined if -Os is specified and
 * looking at stuff with -dM -E seems to say it is defined, but for some
 * reason it doesn't seem to work when we actually try to use it.
 *
 * FORCE_ATOMIC exists to allow overriding.
 */

#if defined(__OPTIMIZE_SIZE__) || defined(FORCE_ATOMIC)
#warning Using low level non-atomic register access
#define MSP430_PINS_ATOMIC_LOWLEVEL
#define MSP430_USCI_ATOMIC_LOWLEVEL
#endif

#endif  /* _H_PLATFORM_H_ */
