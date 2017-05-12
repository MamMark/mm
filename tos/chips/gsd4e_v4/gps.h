/*
 * Copyright (c) 2017, Eric B. Decker, Daniel J. Maltbie
 * GPS platform defines
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 * @date 27 May 2008
 * @updated Mar 2017 for UART based GSD4e chips
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
 * WAKE_UP_DELAY:   time from ON_OFF to ARM boot
 *
 * When the gps chip is in hibernate the ARM7 is shutdown.  When we toggle
 * ON_OFF, it takes some time for the ARM7 to come back.  WAKE_UP_DELAY is
 * the time we know about when first powering the chip up before the ARM7
 * is booted.  We don't know what this time looks like when the gps chip is
 * sleeping (hibernating) rather then powering up.
 */

/* ms units */
#define DT_GPS_PWR_UP_DELAY     1024
#define DT_GPS_WAKE_UP_DELAY    103

#define DT_GPS_RESET_PULSE_WIDTH_US 105
#define DT_GPS_ON_OFF_WIDTH_US      105

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
 * When receiving messages from the GPS we never want to hang.  For example
 * if we lose bytes in the middle of a message the SirfBin Proto engine
 * won't see enough bytes.  If a new message shows up it will blow up
 * properly.  But if no message shows up, then we want to time it out.  We
 * use MAX_RX_TIMEOUT to put an upper bound on this timeout.
 *
 * See sirf.h for SIRFBIN_MAX_MSG.   The transit time for a max gps msg is
 * then:
 *
 *     T_t = (length * DT_GPS_BYTE_TIME + 500000) / 1000000
 *     where length = SIRFBIN_MAX_MSG
 *
 * so for a 200 byte max message we get: 17ms or 18mis.  If we roughly
 * triple this we get around 50ms/mis.  That should work.
 *
 * Similarily the SWVER_TX_TIMEOUT is calculated using the size of the
 * sw_ver message (this is the request, not the response).  Len 10.
 * transmitted at the target baud, T_t of such a short message is less
 * than 1ms so we just bump it up to 4.
 *
 * SWVER_TX_TIMEOUT = (10 * byte_time * 4 + 500000)/1e6
 * SWVER_RX_TIMEOUT = (88 * byte_time * 4 + 500000)/1e6
 *
 * SWVER_RX_TIMEOUT is ~32ms.   We just use MAX_RX_TIMEOUT.  close enough.
 */

#define MAX_RX_TIMEOUT   50
#define SWVER_TX_TIMEOUT  4

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
