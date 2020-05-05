/*
 * Copyright (c) 2020, Eric B. Decker
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
 */

/*
 * GPS platform defines
 */

#ifndef __GPS__UBLOX_H__
#define __GPS__UBLOX_H__

#define GPS_LOG_EVENTS
#define GPS_TARGET_SPEED   9600


/*
 * PWR_UP_DELAY
 *
 * When the GPS has been powered off, we need to wait for power
 * stabilization and a further delay for the chip to be ready for its first
 * ON_OFF toggle.  See GSD4eUP.nc for additional details.
 *
 * PWR_UP_DELAY:    time from pwr_on to ON_OFF okay.
 * WAKE_UP_DELAY:   time from ON_OFF to ARM boot (minimum).  We use this
 *                  window to look for a message that indicates we are
 *                  communicating properly.  ie.  at all.
 *
 * When the gps chip is in hibernate the ARM7 is shutdown.  When we toggle
 * ON_OFF, it takes some time for the ARM7 to come back.  WAKE_UP_DELAY is
 * the time we know about when first powering the chip up before the ARM7
 * is booted.  We don't know what this time looks like when the gps chip is
 * sleeping (hibernating) rather then powering up.
 *
 * After the gps chip is powered up or if reset, ON_OFF must be toggled to
 * bring the chip out of sleep.  This starts the WAKE_UP_DELAY window.  We
 * set this window large enough (200ms) so that the gps's Ok_To_Send (OTS)
 * message falls completely inside this window.
 *
 * During this window, we look for the OTS packet.  (ie. rx interrupts are
 * on and the Protocol state machine will receive bytes).  If we see the
 * start of the OTS packet, we transition to MSG_WAIT to wait for the
 * remainder of the packet.  Once received, we then transition to ON and
 * generate a gps_booted signal to tell the upper layers that the GPS is
 * up and communicating.
 *
 * However, if the OTS window times out, we send a PEEK packet.  The PEEK
 * packet is a minimal packet that elicits a response.
 *
 * If the PEEK times out, we send successive comm configuration messages
 * from the probe_table to attempt a comm reconfiguration.  Each
 * configuration message is followed by a PEEK at the target baud rate.
 *
 * Once we start receiving a message (GPSProto.msgStart has been signalled)
 * we have a RXTimer running to make sure we see the end (deadman timer).
 * If we timeout waiting for the end, we will try GPS_CHK_MAX_TRYS times to
 * send the PEEK and wait for the response.  We assume since we saw the
 * start of the message that something hickuped and trying again is
 * reasonable.
 */

/* ms units */
#define DT_GPS_PWR_UP_DELAY     1024
#define DT_GPS_WAKE_UP_DELAY    205

#define DT_GPS_RESET_PULSE_WIDTH_US 105
#define DT_GPS_ON_OFF_WIDTH_US      105

#define GPS_CHK_MAX_TRYS 4


/*
 * TA_WAIT
 *
 * Turn Around Wait.  When we change the communications configuration
 * ie. baud rate, protocol, we give the gps chip sufficient time to
 * turn around and get ready.  If this time gets too short, things
 * no workie.
 */
#define DT_GPS_TA_WAIT 24

/*
 * TX and RX LIMITs.
 *
 * timing limits are set so when transitting or receiving we never
 * get stuck and hang the GPS subsystem.  We may not know what to
 * do with a hung GPS but at least we will know that it happened.
 *
 * Time out limits are calculated based on the byte time @ the
 * target baud, the size of the message, and a factor that accounts
 * for different baud rates.  When calculating time outs we enforce
 * a minimum timeout of 2ms.
 *
 * DT_GPS_BYTE_TIME is the byte time @ target baud in nsecs.  When
 * we calculate we consider this usecs * 1000 and we divide the result
 * by 1000 before using it.
 *
 * For example the byte time at 115200 is 86.805 us (86805ns).  If we need
 * binary time for the time outs, ie. binary msecs (mis, 1/1024 secs) then
 * we need to multiply this number by 1024/1000.
 */

/*
 * DT_GPS_BYTE_TIME: a byte time at the target baud in nano units
 * 10bits @ 115200 bps
 *
 * binary time, 86805 * 1024/1000 = 88889nis
 */
//#define DT_GPS_BYTE_TIME        88889

/*
 * binary time, 1041667 * 1024/1000 = 1066667nis
 * 10bits @ 9600 bps
 */
#define DT_GPS_BYTE_TIME        1066667

#define DT_GPS_MIN_TX_TIMEOUT   5
#define DT_GPS_MAX_RX_TIMEOUT   1024

#endif /* __GPS__UBLOX_H__ */
