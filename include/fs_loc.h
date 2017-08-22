/*
 * fs_loc.h - mass storage locator information
 * Copyright 2017, Eric B. Decker
 * Mam-Mark Project
 *
 * Locator rewrite.  Rewrite of FileSystem to use regularized start/end
 * with no special cases.  DataBlock is now handled by its own AreaManager.
 *
 * Mass storage is implemented using a SD card, between 2GB and 32GB.
 *
 * The tag uses a very simple file system where a fixed number of files are
 * implemented.  Each file consists of a contiguous number of disk blocks.
 *
 * To assist with moving data off the Tag SD, each file is also contained
 * with in a legit MSDOS Vfat file.  This enables pulling data off the SD
 * easily once the image is mounted on a typical computer system.
 *
 * Areas on the SD managed by the FileSystem include areas for Panic,
 * Configuration, Data Blocks, and Image storage.
 *
 * The FileSystem determines where the different File areas live by
 * accessing the master directory.  This information lives on sector
 * 0 of the SD which is the Master Boot Record.  We use an unused block
 * of space in the middle of the sector.
 *
 * MBR, sector 0, has the file system locator buried that defines all
 * contiguous file areas (panic, config, data, and image blocks).
 *
 * It is assumed that the SD has been formated as a super block, using
 * mkdosfs -F32 -I -n2G -vvv /dev/sdb.
 *
 * Sector 0 is the mbr, boot sector.  Sector 1 is unknown but if
 * modified makes it so the media won't automount on Linux boxes.  The
 * backup boot block is at sector 6.  There are a total of 32 reserved
 * sectors at the front of the file system (0-31, 0 is mbr, etc).
 *
 * multibyte data is stored in little endian order.  This is because
 * the machines we are using are all little endian order and this is
 * much more efficient then dealing with byte swapping.  This means
 * one can't use nx types for these datums which makes sharing the
 * header files easier too.
 *
 * We try as much as possible to make multibyte data have an alignment that
 * allows for efficient access.  That is we want 16 bit quantities
 * (half-words) aligned on 16 bit boundaries and 32 bit quantities
 * (long-words) aligned on 32 bit boundaries.
 */

#ifndef __FS_LOC_H__
#define __FS_LOC_H__

#define FS_LOC_SECTOR 0

#define FS_LOC_SIG    0xdeedbeaf
#define FS_LOC_OFFSET 0x01a8

typedef struct {
  uint32_t start;
  uint32_t end;
} loc_t;


/*
 * fs_area locators, stored little endian order
 */

#define MAX_FS_LOCATORS 8

typedef struct {
  uint32_t loc_sig;
  loc_t    locators[MAX_FS_LOCATORS];
  uint32_t loc_sig_a;
  uint16_t loc_chksum;
} fs_loc_t;

#define FS_LOC_SIZE_SHORTS  (sizeof(fs_loc_t)/2)

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


#endif /* __FS_LOC_H__ */
