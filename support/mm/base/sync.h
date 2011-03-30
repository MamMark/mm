#ifndef __SYNC_H__
#define __SYNC_H__

/*
 * Make sure this matches the defines in typed_data.h
 * we don't share header files but rather rely on ncg
 * to extract enums but if SYNC_MAJIK is an enum it is
 * generated too large.  NCG should handle large constants
 * by generating UL when needed. The warning is something
 * about an ISO C90 warning.  Screw it.  They aren't likely
 * to change so we #define them.
 */
#define SYNC_MAJIK 0xdedf00ef

#endif		// __SYNC_H__
