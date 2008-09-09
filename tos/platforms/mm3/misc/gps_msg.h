/*
 * GPS MSG defines
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 24 Aug 2008
 *
 * Defines for the Msg machine. Such as how long to look for
 * a fast gps fix.
 */


#ifndef __GPS_MSG_H__
#define __GPS_MSG_H__

/*
 * Short window is the window during which if we get a valid over
 * determined fix we assume that we have updated almanacs and ephemeri.
 *
 * If we don't get a good fix then we assume we need to leave the unit
 * on.  It will stay on for LONG_WINDOW or until we submerge.  Submerging
 * over rides all.
 *
 * short window, 15 secs.
 * Long window,  15 mins (15 mins * 60 sec/min * 1024 tics/sec)
 */
#define GPS_MSG_SHORT_WINDOW (15*1024UL)
#define GPS_MSG_LONG_WINDOW (15*60*1024UL)

#endif /* __GPS_MSG_H__ */
