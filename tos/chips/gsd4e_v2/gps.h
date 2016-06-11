/*
 * GPS platform defines
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 23 May 2012
 * @updated 10 Feb 2014
 *
 * Antenova M10478 module uses SirfStarIV GSD4e-9333.
 */

#ifndef __GPS_H__
#define __GPS_H__

#define GPS_LOG_EVENTS

//#define GPS_NO_SHORT
//#define GPS_SHORT_COUNT 40
//#define GPS_LEAVE_UP 
//#define GPS_STAY_UP

/*
 * The M10478 gets turned on and off using the gps_on_off signal.  Its
 * weird but there it is.   The M10478 documentation says it needs to
 * be > 90 uS.  We use 200ms.
 */

#define DT_GPS_ON_OFF_PULSE_WIDTH       200
#define DT_GPS_RESET_PULSE_WIDTH        200
#define DT_GPS_RESET_WAIT_TIME          200

#define MAX_GPS_RECONFIG_TRYS   5

#define DT_GPS_EOS_WAIT       512
#define DT_GPS_SEND_TIME_OUT  512

//#define DT_GPS_FINI_WAIT      512
#define DT_GPS_FINI_WAIT      2048

#endif /* __GPS_H__ */
