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

typedef enum {
  GPSC_FAIL = 1,
  GPSC_OFF,
  GPSC_WAKING,
  GPSC_SEND_CHECK,
  GPSC_SC_WAIT,
  GPSC_CHECK_NMEA_BIN,
  GPSC_CHECK_BIN_2,
  GPSC_CHECKING,
  GPSC_CONFIG,
  GPSC_CONFIGING,
  GPSC_ON,
  GPSC_RECEIVING,
} gpsc_state_t;

typedef enum {
  GPSW_NONE = 0,
  GPSW_TX_TIMER,
  GPSW_RX_TIMER,
  GPSW_RX_BYTE,
  GPSW_CHANGE_SPEED,
  GPSW_CHECK_TASK,
  GPSW_CONFIG_TASK,
  GPSW_COMM_TASK,
  GPSW_SEND_DONE,
  GPSW_START,
  GPSW_STOP,

  GPSW_RESET_FREE,
  GPSW_MSG_START,
  GPSW_MSG_ADD_BYTE,
  GPSW_MSG_ABORT,
  GPSW_MSG_COMPLETE,
  GPSW_MSG_NEXT,
  GPSW_MSG_RELEASE,
} gps_where_t;

#define GPS_LOG_EVENTS

//#define GPS_NO_SHORT
//#define GPS_SHORT_COUNT 40
//#define GPS_LEAVE_UP
//#define GPS_STAY_UP

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
#define DT_GPS_PWR_UP_DELAY        512

#define DT_GPS_WAKE_UP_DELAY       200


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

#define GPS_LOG_EVENTS

//#define GPS_NO_SHORT
//#define GPS_SHORT_COUNT 40
//#define GPS_LEAVE_UP
//#define GPS_STAY_UP

/*
 * The M10478 gets turned on and off using the gps_on_off signal.  Its
 * weird but there it is.   The M10478 documentation says it needs to
 * be > 90 uS.  We use 200ms.  There are also references to the ARM
 * taking 300ms to power up.
 *
 * OSP_WAIT_TIME is how long we wait after sending the go_sirf_bin msg.
 * We have observed 18ms not working but 20 does.  To be on the safe
 * side we use 50ms.  This is a rare occurance.  Normally, the gps stays
 * in SirfBin (OSP).
 */
#ifdef notdef
#define DT_GPS_OSP_WAIT_TIME            50
#define DT_GPS_SHUTDOWN_CLEAN_TO        1000

//#define DT_GPS_FINI_WAIT       512
#define DT_GPS_FINI_WAIT                2048
#endif

#define DT_GPS_RESET_WAIT               300
#define DT_GPS_ON_OFF_PULSE_WIDTH       300
#define DT_GPS_RESET_PULSE_WIDTH        300
#define DT_GPS_SEND_CHECK_WAIT          120
#define DT_GPS_RECV_CHECK_WAIT          240
#define DT_GPS_CYCLE_CHECK_WAIT         2000

/*
 * gpsr_rx_parse_state_t: states for receive byte-to-msg processing
 */
typedef enum {
  GPSR_NONE = 0,
  GPSR_HUNT,
  GPSR_NMEA,
  GPSR_NMEA_C1,
  GPSR_NMEA_C2,
  GPSR_SIRF,
  GPSR_SIRF_S1,
  GPSR_SIRF_E1,
} gpsr_rx_parse_state_t;

typedef enum {
  GPSR_NMEA_START,
  GPSR_NMEA_END,
  GPSR_BIN_A0,
  GPSR_BIN_A2,
  GPSR_BIN_B0,
  GPSR_BIN_B3,
  GPSR_OTHER,
} gpsr_rx_parse_where_t;

#endif /* __GPS_H__ */
