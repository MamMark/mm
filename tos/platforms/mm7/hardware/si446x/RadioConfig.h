/*
 * Copyright (c) 2015-2018 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 *          Daniel J. Maltbie <dmaltbie@daloma.org>
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
#include "Si446xConfigDevice.h"
#else
#include <Si446xConfigPlatform.h>
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
