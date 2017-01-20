/*
 * GPS platform defines
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

//#define GPS_NO_SHORT
//#define GPS_SHORT_COUNT 40
//#define GPS_LEAVE_UP
//#define GPS_STAY_UP

/*
 * Define the speed we want to run the gps at.
 *
 * We've tried 115200 but the interrupt latency seems too high.
 * we drop chars now and then.  So we've gone down to 57600.
 *
 * Choices are 1228800, 115200, 57600, and 9600
 */
#define GPS_SPEED 57600

#define NMEA_START       '$'

/*
 * PWR_UP_DELAY
 *
 * When the gps is turned on it takes about 300 mis before it starts
 * to transmit.  And when it does it first spits out some debugging
 * information.
 *
 * When booting we want to get some information from the gps but have
 * to wait because sending early gets ignored.
 *
 * When starting we look at the first bytes to see if we are communicating
 * correctly (we know what baud we are at) and initially we want to
 * collect these bytes and put them into the SD for analysis.
 *
 * After the pwr_up_delay, we hunt for the start up sequence.  If we time
 * out we will try to reconfigure from nmea-4800 baud to sirfbin-57600.
 */

//#define DT_GPS_PWR_UP_DELAY   100
#define DT_GPS_PWR_UP_DELAY   512


/*
 * HUNT_LIMIT
 *
 * HUNT_LIMIT places an upper bound on how long we wait before giving up on
 * the hunt.  We don't want to hunt for ever.    The time needs to be long
 * enough so that when the gps is at 4800 and we are switching over from 57600
 * there is a good chance that we will see the new 4800 stream.
 */

#define DT_GPS_HUNT_LIMIT (4 * 1024UL)

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

#define MAX_GPS_RECONFIG_TRYS   5

#define DT_GPS_PWR_BOUNCE       5
#define DT_GPS_EOS_WAIT       512
#define DT_GPS_SEND_TIME_OUT  512

//#define DT_GPS_FINI_WAIT      512
#define DT_GPS_FINI_WAIT      2048

#endif /* __GPS_H__ */
