/*
 * Copyright (c) 2017, Eric B. Decker, Daniel J. Maltbie
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

/*
 * GPS platform defines
 */

#ifndef __GPS_H__
#define __GPS_H__

#define GPS_LOG_EVENTS

#define GPS_TARGET_SPEED 115200


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
 * remainder of the packet.  Once received, we then send a SWVER request
 * and transition to ON.
 *
 * However, if the OTS window times out, we send a PEEK packet.  The PEEK
 * packet is a minimal packet that elicits a response.
 *
 * If the PEEK times out, we send successive comm configuration messages
 * from the probe_table to attempt a comm reconfiguration.  Each
 * configuration message is followed by a PEEK at the target baud rate.
 */

/* ms units */
#define DT_GPS_PWR_UP_DELAY     1024
#define DT_GPS_WAKE_UP_DELAY    205

#define DT_GPS_RESET_PULSE_WIDTH_US 105
#define DT_GPS_ON_OFF_WIDTH_US      105

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
 * For example the byte time at 115200 is 86.805 us (86805).  If we need
 * binary time for the time outs, ie. binary msecs (mis, 1/1024 secs) then
 * we need to multiply this number by 1024/1000.
 */

/*
 * DT_GPS_BYTE_TIME: a byte time at the target baud.
 *
 * binary time, 86805 * 1024/1000 = 88889mis
 */
#define DT_GPS_BYTE_TIME        88889

/*
 * MAX_RX_TIMEOUT is the upper limit we use under normal circumstances just
 * to keep things simple (and to avoid doing calculations that don't
 * matter).
 *
 * Due to some hardware issues, gps_send_block returns with two bytes on
 * the h/w in the process of being transmitted.  RX timeout starts timing
 * on return from gps_send_block.  Therefore RX timeouts need to take into
 * account the extra two byte times.  This two byte times will be at
 * whatever baud rate is currently selected.
 *
 * When receiving messages from the GPS we never want to hang.  For example
 * if we lose bytes in the middle of a message the SirfBin Proto engine
 * won't see enough bytes.  If a new message shows up it will blow up
 * properly.  But if no message shows up, then we want to time it out.  We
 * use MAX_RX_TIMEOUT to put an upper bound on this timeout.
 *
 * See sirf_msg.h for SIRFBIN_MAX_MSG.   The transit time for a max gps msg is
 * then:
 *
 *     T_t = (length * DT_GPS_BYTE_TIME + 500000) / 1000000
 *     where length = SIRFBIN_MAX_MSG
 *
 * so for a 200 byte max message we get: 17ms or 18mis.  If we roughly
 * triple this we get around 50ms (52mis).  That should work.
 *
 * We use the PEEK command to force a response.  PEEK_TX_TIMEOUT is
 * calculated using the size of the PEEK command (20 bytes).
 *
 * Similarily the SWVER_TX_TIMEOUT is calculated using the size of the
 * sw_ver message (this is the request, not the response).  Len 10.
 * transmitted at the target baud, T_t of such a short message is less
 * than 1ms so we just bump it up to 4.
 *
 * (115200 target)
 * SWVER_TX_TRANSIT = (10 * byte_time + 500000)/1e6 = ~1ms  (.87ms)
 *  PEEK_TX_TRANSIT = (20 * byte_time + 500000)/1e6 = ~2mis (1.7ms)
 * PEEK_RSP_TRANSIT = (19 * byte_time + 500000)/1e6 = ~2mis (1.7ms) ***
 */

#define DT_GPS_MIN_TX_TIMEOUT   5
#define DT_GPS_PEEK_RSP_TIMEOUT 52
#define DT_GPS_MAX_RX_TIMEOUT   52

/*
 * All times unless otherwise noted are in decimal time (us and
 * ms).  Baud rates are from ORG447X Series datasheet.
 *
 * byte times: (numbers in parens are error numbers)
 *
 * 1843200 bps (0.86%) 10bits * secs/1843200 = 5.425e-6    ~6us
 * 1228800 bps (0.07%) 10bits * secs/1228800 = 8.138e-6    ~8us
 *  921600 bps (2.30%) 10bits * secs/921600  = 1.085e-5   ~11us
 *  307200 bps (0.01%) 10bits * secs/307200  = 3.255e-5   ~33us
 *  115200 bps (0.24%) 10bits * secs/115200  = 8.681e-5   ~87us
 *   57600 bps (0.64%) 10bits * secs/57600   = 1.736e-4  ~174us
 *    9600 bps (0.00%) 10bits * secs/9600    = 1.042e-3 ~1.04ms
 *    4800 bps (0.06%) 10bits * secs/4800    = 2.083e-3 ~2.08ms
 *
 * the max speed we can run at depends on the path length of the
 * interrupt handler.
 */

#endif /* __GPS_H__ */
