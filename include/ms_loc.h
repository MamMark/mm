/*
 * ms_loc.h - mass storage locator information
 * Copyright 2006, 2010 Eric B. Decker, Carl W. Davis
 * Mam-Mark Project
 *
 * Mass storage has well known sectors that contains information about
 * where contiguous files live for use by the mammark tag.
 *
 * MBR, sector 0, has a dblk locator buried that defines all
 * contiguous file areas (panic, config, and data blocks).
 *
 * PANIC0, sector 1, is a special sector used by panic to locate the
 * panic section of the disk.
 */

#ifndef _MS_LOC_H
#define _MS_LOC_H

#define DBLK_SECTOR 0

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


#define PANIC0_SECTOR 1
#define PANIC0_MAJIK  0x23626223


typedef struct {
  uint32_t sig_a;			/* tombstone */
  uint32_t panic_start;			/* abs blk id */
  uint32_t panic_nxt;			/* abs blk id */
  uint32_t panic_end;			/* abs blk id */
  uint32_t fubar;			/* fell off bottom */
  uint32_t sig_b;			/* tombstone */
  uint16_t chksum;
} panic0_hdr_t;


#endif /* _MS_LOC_H */
