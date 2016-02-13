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
 * PANIC0, sector 2, is a special sector used by panic to locate the
 * panic section of the disk.
 *
 * It is assumed that the SD has been formated as a super block, using
 * mkdosfs -F32 -I -n2G -vvv /dev/sdb.
 *
 * Sector 0 is the mbr, boot sector.  Sector 1 is unknown but if
 * modified make it so the media won't automount on Linux boxes.  The
 * backup boot block is at sector 6.  There are a total of 32 reserved
 * sectors at the front of the file system (0-31, 0 is mbr, etc).
 *
 * multibyte data is stored in little endian order.  This is because
 * the machines we are using are all little endian order and this is
 * much more efficient then dealing with byte swapping.  This means
 * one can't use nx types for these datums which makes sharing the
 * header files easier too.
 */

#ifndef _MS_LOC_H
#define _MS_LOC_H

#define DBLK_SECTOR 0

#define TAG_DBLK_SIG 0xdeedbeaf
#define DBLK_LOC_OFFSET 0x01a8

/*
 * dblock locator, stored little endian order
 */
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


#define PANIC0_SECTOR UINT32_C(2)
#define PANIC0_MAJIK  UINT32_C(0x23626223)
#define PANIC0_SIZE_SHORTS 13

#define FUBAR_REALLY_REALLY_FUBARD UINT32_C(0x08313108)


/*
 * Panic0 block, stored little endian order
 */
typedef struct {
  uint32_t sig_a;			/* tombstone */
  uint32_t panic_start;			/* abs blk id */
  uint32_t panic_nxt;			/* abs blk id */
  uint32_t panic_end;			/* abs blk id */
  uint32_t fubar;			/* fell off bottom */
  uint32_t sig_b;			/* tombstone */
  uint16_t chksum;

  /* end of actual panic0 struct */

  uint16_t pad[16];
  uint32_t really_really_fubard_sig;    /* special wartage */
  uint32_t sig_c;
} panic0_hdr_t;


#endif /* _MS_LOC_H */
