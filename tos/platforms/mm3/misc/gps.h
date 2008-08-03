/*
 * GPS defines
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 27 May 2008
 *
 * Currently set up for the ET-312 module using the Sirf-III
 * chipset.
 */


#ifndef __GPS_H__
#define __GPS_H__

#define GPS_LOG_EVENTS
#define TEST_GPS_FUTZ

/*
 * Define the speed we want to run the gps at.
 *
 * We've tried 115200 but the interrupt latency seems too high.
 * we drop chars now and then.  So we've gone down to 57600.
 *
 * Choices are 115200, 57600, and 4800
 */
#define GPS_SPEED 57600

#define NMEA_START       '$'

/*
 * BOOT_UP_DELAY, PWR_UP_DELAY
 *
 * When the gps is turned on it takes about 300 mis before it starts
 * to transmit.  And when it does it first spits out some debugging
 * information.
 *
 * When we boot we look at the first bytes to see if we are communicating
 * correctly (we know what baud we are at) and initially we want to
 * collect these bytes and put them into the SD for analysis.
 *
 * Later we can futz with the BOOT_UP_DELAY parameter to ignore things
 * if we wish.
 *
 * When turning on for a reading (not boot) then we use PWR_UP_DELAY
 * to delay us until odds are good the gps has reacquired.
 */

#define DT_GPS_BOOT_UP_DELAY  100
#define DT_GPS_PWR_UP_DELAY  1024

/*
 * HUNT_LIMIT
 *
 * When first booting we don't know if the GPS has reverted to NMEA-4800-8N1
 * or if we are still at 115200 and SiRFbin.  So when we boot we power
 * up the gps, wait some time, and then hunt for the start sequence.  If
 * found then we are at 115200.  Otherwise we have to reconfigure for 4800.
 *
 * HUNT_LIMIT places an upper bound on how long we wait before giving up on
 * the hunt.  We don't want to hunt for ever.    The time needs to be long
 * enough so that when the gps is at 4800 and we are switching over from 57600
 * there is a good chance that we will see the new 4800 stream.
 */

#define DT_GPS_HUNT_LIMIT 2048

/*
 * All times unless otherwise noted are in mis.
 *
 * byte times:
 *
 * 115200 bits/sec    10bits  *  secs/115200 = 8.681e-5  ~87us
 * 57600  bits/sec    10bits  *  secs/57600  = 1.736e-4  ~174us
 * 4800   bits/sec    10bits  *  secs/4800   = 2.08e-3   ~2ms
 *
 * The NMEA message (nmea_go_sirf_bin) is 0x1b long so at 57600 takes
 * approximately 4.7 ms so 20 should have been long enough.  But for some
 * reason 20 times out when sending at 57600.  Not sure why.  It's a mystery.
 *
 * Duh!  Nmea_go_sirf_bin is transmitted at 4800 baud so 0x1b bytes takes
 * 54 ms.  Dumb ass.
 *
 * DT_GPS_EOS_WAIT is how long to wait from the start of the window before
 * we guess it is okay to start sending commands.  If we start to send right
 * after we first start receiving bytes from the gps then the commands don't
 * work.  So we wait a while before sending commands.
 */

#define MAX_GPS_BOOT_TRYS       3

#define DT_GPS_PWR_BOUNCE       5
#define DT_GPS_EOS_WAIT       500
#define DT_GPS_SEND_TIME_OUT  256
#define DT_GPS_FINI_WAIT      500

/*
 * MAX_REQUEST_TO: time out if a request isn't satisfied with
 * this amount of time.
 */
#define DT_GPS_MAX_REQUEST_TO 10000

#endif /* __GPS_H__ */
