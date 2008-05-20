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

#include <stdio.h>

#define GPS_SPEED 4800

/*
 * bit times are calculated assuming a timer tick (jiffy)
 * of 1 uis (ticking at 1 MiHz, 1024*1024 Hz).
 */
#define GPS_4800_15_BITTIME 328
#define GPS_4800_1_BITTIME  218

#define GPS_9600_15_BITTIME 164
#define GPS_9600_1_BITTIME  109

#define GPS_57600_15_BITTIME 27
#define GPS_57600_1_BITTIME  18

#if (GPS_SPEED == 4800)
#define GPS_15_BITTIME GPS_4800_15_BITTIME
#define GPS_1_BITTIME  GPS_4800_1_BITTIME
#elif (GPS_SPEED == 9600)
#define GPS_15_BITTIME GPS_9600_15_BITTIME
#define GPS_1_BITTIME  GPS_9600_1_BITTIME
#elif (GPS_SPEED == 57600)
#define GPS_15_BITTIME GPS_57600_15_BITTIME
#define GPS_1_BITTIME  GPS_57600_1_BITTIME
#else
#error "GPS_SPEED not defined"
#endif

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
 * empirically determined to be about 300 mis or so
 * when NMEA is the protocol.  Don't currently know
 * if we are already in binary mode.
 *
 * how long in binary milliseconds to wait from the time we
 * power the gps up until we start looking for the first character.
 */

#define GPS_PWR_ON_DELAY 200

#endif /* __GPS_H__ */
