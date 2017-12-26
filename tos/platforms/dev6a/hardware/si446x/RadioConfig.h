/*
 * Copyright (c) 2015-2017 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holder nor the names of
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
 * Author: Eric B. Decker
 */

#ifndef __RADIOCONFIG_H__
#define __RADIOCONFIG_H__

#ifndef RPI_BUILD
#include <Timer.h>
#include <message.h>
#endif

/*
 * Include the WDS generated, platform dependent, and device driver
 * required configuration definitions for the Si446x radio.
 */
#ifdef RPI_BUILD
#include "Si446xConfigPlatform.h"
#include "Si446xConfigWDS.h"
#include "Si446xConfigDevice.h"
#else
#include <Si446xConfigPlatform.h>
#include <Si446xConfigWDS.h>
#include <Si446xConfigDevice.h>
#endif

//#define LOW_POWER_LISTENING

/* TODO: need to figure out correct power value */
#ifndef SI446X_DEF_RFPOWER
#define SI446X_DEF_RFPOWER	31
#endif

/*
 * channel to use for FREQCTRL
 *
 * Freq is set by h/w at 433MHz, single channel.
 */
#ifndef SI446X_DEF_CHANNEL
#define SI446X_DEF_CHANNEL	0
#endif

/* The number of microseconds a sending mote will wait for an acknowledgement */
#ifndef SOFTWAREACK_TIMEOUT
#define SOFTWAREACK_TIMEOUT	800
#endif

/**
 * This is the timer type of the radio alarm interface
 */
#ifndef RPI_BUILD
typedef T32khz   TRadio;
typedef uint16_t tradio_size;
#endif

/**
 * The number of radio alarm ticks per one microsecond .
 */
#define RADIO_ALARM_MICROSEC    1/32


/**
 * The base two logarithm of the number of radio alarm ticks per one millisecond
 * binary milliseconds.
 *
 * 2**5 = 32, 32 ticks in 1mis
 */
#define RADIO_ALARM_MILLI_EXP	5



/**
 * Make PACKET_LINK automaticaly enabled for Ieee154MessageC
 */
#if !defined(TFRAMES_ENABLED) && !defined(PACKET_LINK)
#define PACKET_LINK
#endif

#endif          //__RADIOCONFIG_H__
