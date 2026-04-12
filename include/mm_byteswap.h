#ifndef MM_BYTESWAP_H
#define MM_BYTESWAP_H

/*
 * Conversion from/to little-endian byte order. (no-op on i386/i486)
 *
 * Naming: Ca_b_c, where a: F = from, T = to, b: LE = little-endian,
 * BE = big-endian, c: 16 = short (16 bits), 32 = long (32 bits)
 *
 * handles both endianess as well as alignment issues.
 */

/* swap addr */
#define _sa(v) ((uint8_t *)&(v))

#define CF_LE_16(v) ((_sa(v)[1] <<  8) | _sa(v)[0])
#define CF_LE_32(v) ((_sa(v)[3] << 24) | (_sa(v)[2] << 16) | (_sa(v)[1] << 8) | _sa(v)[0])
#define CT_LE_16(v) CF_LE_16(v)
#define CT_LE_32(v) CF_LE_32(v)

#define CF_BE_16(v) ((_sa(v)[0] <<  8) | _sa(v)[1])
#define CF_BE_32(v) ((_sa(v)[0] << 24) | (_sa(v)[1] << 16) | (_sa(v)[2] << 8) | _sa(v)[3])
#define CT_BE_16(v) CF_BE_16(v)
#define CT_BE_32(v) CF_BE_32(v)

#endif          /* MM_BYTESWAP_H */
