/*
 * Copyright (c) 2008, 2014 Eric B. Decker
 *
 * GPS MSG defines
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 24 Aug 2008
 *
 * Updated 08 Feb 2014: switch to decimal time.
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
 * short window, 20 secs.
 * Long window,  5 mins (5 mins * 60 sec/min * 1000 tics/sec)
 */

#define GPS_MSG_SHORT_WINDOW (20*1000UL)
#define GPS_MSG_LONG_WINDOW  (5*60*1000UL)

#endif /* __GPS_MSG_H__ */
