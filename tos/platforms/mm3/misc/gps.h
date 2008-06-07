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

#define SIRF_BIN_START   0xa0
#define SIRF_BIN_START_2 0xa2
#define SIRF_BIN_END     0xb0
#define SIRF_BIN_END_2   0xb3

#define NMEA_START       '$'

/*
 * FIRST_CHAR_TIME_OUT
 *
 * empirically determined to be about 400 mis or so when NMEA is the
 * protocol.
 *
 * Maximum time we will wait to see the first char.  If we don't see
 * anything within this time then we time out and assume that the
 * baud rate is wrong.
 *
 * Should be longer than the time to first char sent after power up.
 */

#define T_GPS_FIRST_CHAR_TIME_OUT 500

/*
 * T_CHAR_DELAY
 *
 * T_CHAR_DELAY is the character delay to wait between receiving characters.
 * If the timer goes off then it says that the GPS has sent all of the bytes
 * it is going to send in one burst.  We use this to detect the end of the
 * start up messages the GPS kicks out on power up.
 *
 * It is set assuming 4800 baud which will give us the longer byte time.
 *
 * byte times:
 *
 * 115200 bits/sec    10bits  *  secs/115200 = 8.681e-5  ~87us
 * 57600  bits/sec    10bits  *  secs/57600  = 1.736e-4  ~174us
 *
 * So 32 ms should be way more than enough.  Is there a problem with 10?

 */

#define T_CHAR_DELAY 32

#endif /* __GPS_H__ */
