/*
 * GPS defines
 *
 * @author Eric B. Decker (cire831@gmail.com)
 */


#ifndef __GPS_H__
#define __GPS_H__

#define GPS_SPEED 4800

/*
 * bit times are calculated assuming a timer tick (jiffy)
 * of 1 uis (ticking at 1 MiHz, 1024*1024 Hz).
 */
#define GPS_4800_15_BITTIME 288
#define GPS_4800_1_BITTIME  192

#if (GPS_SPEED == 4800)
#define GPS_15_BITTIME GPS_4800_15_BITTIME
#define GPS_1_BITTIME  GPS_4800_1_BITTIME
#else
#error "GPS_SPEED not defined"
#endif

#endif /* __GPS_H__ */
