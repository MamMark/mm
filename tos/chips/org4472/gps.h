/*
 * GPS platform defines
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 23 May 2012
 *
 * Currently set up for Origin ORG-4472 gps module which
 * incorporates a SirfStarIV chip.
 */

#ifndef __GPS_H__
#define __GPS_H__

#define GPS_LOG_EVENTS

//#define GPS_NO_SHORT
//#define GPS_SHORT_COUNT 40
//#define GPS_LEAVE_UP
//#define GPS_STAY_UP

#define NMEA_START       '$'

/*
 * PWR_UP_DELAY
 *
 * When the gps is turned on it takes about 300 ms before it starts
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

// not used.
//#define DT_GPS_PWR_UP_DELAY   100
//#define DT_GPS_PWR_UP_DELAY   512

/*
 * The ORG4472 gets turned on and off using the gps_on_off signal.  Its
 * weird but there it is.   This signal gets pulsed for about 100ms
 * to turn on or off.
 */

#define DT_GPS_ON_OFF_PULSE_WIDTH 100


/*
 * HUNT_LIMIT
 *
 * HUNT_LIMIT places an upper bound on how long we wait before giving up on
 * the hunt.  We don't want to hunt for ever.    The time needs to be long
 * enough so that when the gps is at 4800 and we are switching over from 57600
 * there is a good chance that we will see the new 4800 stream.
 */

#define DT_GPS_HUNT_LIMIT (4 * 1024UL)

#define MAX_GPS_RECONFIG_TRYS   5

#define DT_GPS_PWR_BOUNCE       5
#define DT_GPS_EOS_WAIT       512
#define DT_GPS_SEND_TIME_OUT  512

//#define DT_GPS_FINI_WAIT      512
#define DT_GPS_FINI_WAIT      2048

#endif /* __GPS_H__ */
