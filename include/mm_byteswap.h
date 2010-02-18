/* $Id: mm_byteswap.h,v 1.4 2006/07/11 03:56:26 cire Exp $ */
/*
 * Conversion from/to little-endian byte order. (no-op on i386/i486)
 *
 * Naming: Ca_b_c, where a: F = from, T = to, b: LE = little-endian,
 * BE = big-endian, c: 16 = short (16 bits), 32 = long (32 bits)
 */

#ifdef _BIG_ENDIAN
#define swap16(v) ((((v) & 0xff) << 8) | (((v) & 0xff00) >> 8))
#define swap32(v) ( ( ( (v) & 0xff) << 24) | (((v) & 0xff00) << 8) | \
		    ( ( (v) & 0xff0000) >> 8) | (((v) & 0xff000000) >> 24))


#define CF_LE_16(v) swap16(v)
#define CF_LE_32(v) swap32(v)
#define CT_LE_16(v) swap16(v)
#define CT_LE_32(v) swap32(v)

#else
#define CF_LE_16(v) (v)
#define CF_LE_32(v) (v)
#define CT_LE_16(v) (v)
#define CT_LE_32(v) (v)
#endif	/* BIG_ENDIAN */
