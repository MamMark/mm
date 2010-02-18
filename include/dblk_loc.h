/*
 * dblk_loc.h - definition of what the dblk locator looks like
 * Copyright 2006, Eric B. Decker
 * Mam-Mark Project
 *
 * Port to TinyOS 2x
 * Copyright 2008, Eric B. Decker
 */

#ifndef _DBLK_LOC_H
#define _DBLK_LOC_H

#define TAG_DBLK_SIG 0xdeedbeaf
#define DBLK_LOC_OFFSET 0x01a8

typedef struct {
  uint32_t sig;
  uint32_t panic_start;
  uint32_t panic_end;
  uint32_t config_start;
  uint32_t config_end;
  uint32_t dblk_start;
  uint32_t dblk_end;
  uint16_t dblk_chksum;
} dblk_loc_t;

#define DBLK_LOC_SIZE 30
#define DBLK_LOC_SIZE_SHORTS 15

#endif /* _DBLK_LOC_H */
