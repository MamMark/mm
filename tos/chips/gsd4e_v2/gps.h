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
 * be > 90 uS.  We use 200ms.  There are also references to the ARM
 * taking 300ms to power up.
 *
 * OSP_WAIT_TIME is how long we wait after sending the go_sirf_bin msg.
 * We have observed 18ms not working but 20 does.  To be on the safe
 * side we use 50ms.  This is a rare occurance.  Normally, the gps stays
 * in SirfBin (OSP).
 */

#define DT_GPS_ON_OFF_PULSE_WIDTH       200
#define DT_GPS_RESET_PULSE_WIDTH        200
#define DT_GPS_RESET_WAIT_TIME          200
#define DT_GPS_OSP_WAIT_TIME            50
#define DT_GPS_SHUTDOWN_CLEAN_TO        1000

#define MAX_GPS_RECONFIG_TRYS   5

#define DT_GPS_EOS_WAIT       512
#define DT_GPS_SEND_TIME_OUT  512

//#define DT_GPS_FINI_WAIT      512
#define DT_GPS_FINI_WAIT      2048


/*
 * DT -> Data, Typed (should have been TD for Typed Data
 * but at this point, probably more trouble than it is worth
 * to change it).
 *
 * GPS_BUF_SIZE is biggest packet (MID 41, 188 bytes observed),
 *   (where did 188 come from?  docs imply 91 bytes)
 *   SirfBin overhead (start, len, chksum, end) 8 bytes
 *   DT overhead (8 bytes).   204 rounded up to 256.
 *
 * The ORG4472/M10478 driver uses SPI which is master/slave.  Access is
 * direct and no interrupts are used.  All accesses are done from
 * syncronous (task) level.
 *
 * GPS_START_OFFSET: offset into the msg buffer where the incoming bytes
 *   should be put.  Skips over DT overhead.
 *
 * SIRF_OVERHEAD: overhead bytes not part of sirf_len.  Includes start_seq (2),
 *   payload_len (2), checksum (2), and end_seq (2).  8 total.
 *
 * GPS_OVERHEAD: space in msg buffer for overhead bytes.  Sum of DT overhead
 *   and osp packet header and trailer.  16 bytes total.
 *
 * BUF_INCOMING_SIZE is the size of the chunk used by the lowest
 *   layer to snarf SPI blocks.  It is the minimum number of bytes we
 *   snarf from the gps via the spi when not doing specific osp packets.
 */

#define GPS_BUF_SIZE		256
#define GPS_START_OFFSET	8
#define SIRF_OVERHEAD		8
#define GPS_OVERHEAD		16
#define BUF_INCOMING_SIZE	32

#endif /* __GPS_H__ */
