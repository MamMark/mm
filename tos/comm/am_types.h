/*
 * am_types
 *
 * Defines Active Message ports used by the tag.
 */

#ifndef __AM_TYPES_H__
#define __AM_TYPES_H__

/*
 * We assigned values from the TinyOS unreserved block.
 */

enum {
  AM_MM_CONTROL		= 0xA0,
  AM_MM_DATA		= 0xA1,
  AM_MM_DEBUG		= 0xA2,
};

#endif  /* __AM_TYPES_H__ */
