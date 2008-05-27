/*
 * GPS defines
 *
 * @author Eric B. Decker (cire831@gmail.com)
 *
 * Currently set up for the ET-312 module using the Sirf-III
 * chipset.
 */


#ifndef __GPS_H__
#define __GPS_H__

#define GPS_RX  mmP1in.gps_rx_in

/*
 * SET_GPS_RX_IN will set the direction of the gps_rx pin to input.  When the
 * gps is on this is where it should be.
 */

#define SET_GPS_RX_IN_MOD do { P1SEL |= 0x08; P1DIR &= ~0x08; } while (0)

/*
 * SET_GPS_RX_OUT_0 will set the direction of gps_rx to output.  And take
 * back control from the timer module.  it is already assumed that the value
 * output will be 0 from initilization.
 */
#define SET_GPS_RX_OUT_0 do { P1SEL &= ~0x08; P1DIR |= 0x08; } while (0)

/*
 * empirically determined to be about 400 mis or so
 * when NMEA is the protocol.  Don't currently know
 * if we are already in binary mode.
 *
 * Maximum time we will wait to see the first char.  If we don't see
 * anything within this time then we time out and assume that the
 * baud rate is wrong.
 */

#define T_GPS_PWR_ON_TIME_OUT 500

/*
 * T_CHAR_DELAY
 *
 * T_CHAR_DELAY is the character delay to wait between receiving characters.
 * If the timer goes off then it says that the GPS has sent all of the bytes
 * it is going to send in one burst.  We use this to detect the end of the
 * start up messages the GPS kicks out on power up.
 *
 * It is set assuming 4800 baud which will give us the longer byte time.
 */

#define T_CHAR_DELAY 10

#endif /* __GPS_H__ */
