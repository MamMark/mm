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

#define SIRF_BIN_START   0xa0
#define SIRF_BIN_START_2 0xa2
#define SIRF_BIN_END     0xb0
#define SIRF_BIN_END_2   0xb3

#define NMEA_START       '$'

/*
 * BOOT_UP_DELAY, PWR_UP_DELAY
 *
 * When the gps is first turned on it takes about 300 mis before it
 * starts to talk.  And then it sends out debugging data.  So we first
 * power up and then wait with interrupts off until we know that the
 * gps is talking.  By having interrupts off and the cpu sleeping we
 * can leave the cpu asleep until the gps comes up.
 *
 * Later we can modify this time to leave the cpu asleep until the odds
 * are good the gps has reacquired.  (PWR_UP_DELAY).
 *
 *
 * HUNT_TIME_OUT
 *
 * When first booting we don't know if the GPS has reverted to NMEA-4800-8N1
 * or if we are still at 115200 and SiRFbin.  So when we boot we power
 * up the gps, wait some time, and then hunt for the start sequence.  If
 * found then we are at 115200.  Otherwise we have to reconfigure for 4800.
 *
 * The hunt window starts when we turn power on to the gps.  When it expires
 * we decide that we aren't communicating and send cool hand luke to the
 * prison farm (either fail or try to reconfigure to 4800).
 *
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
 * DT_GPS_SEND_WAIT is how long to wait from the start of the window before
 * we guess it is okay to start sending commands.  If we start to send right
 * after we first start receiving bytes from the gps then the commands don't
 * work.  So we wait a while before sending commands.
 */

#define DT_GPS_PWR_BOUNCE 5
#define DT_GPS_HUNT_WINDOW 600
#define DT_GPS_SEND_WAIT 500
#define DT_GPS_SEND_TIME_OUT 100

#define DT_GPS_HUNT_TIME_OUT  500

#define DT_GPS_BOOT_UP_DELAY  350
#define DT_GPS_PWR_UP_DELAY  1000

#endif /* __GPS_H__ */
