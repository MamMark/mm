/*
 * file_system.h - simple contiguous file system
 * Copyright 2010 Eric B. Decker, Carl Davis
 * Mam-Mark Project
 *
 * split out from stream storage.
 */

#ifndef __FILE_SYSTEM_H__
#define __FILE_SYSTEM_H__

/*
 * File System Control Structure
 *
 * Each locator is referenced by its index (fs_loc_indicies) and holds
 * a start and end address.
 *
 * ie.  PANIC has fsc.loc[FS_AREA_PANIC].loc_start and loc_end.
 */

enum fs_loc_indicies {
  FS_AREA_PANIC       = 0,
  FS_AREA_CONFIG      = 1,
  FS_AREA_DBLK        = 2,
  FS_AREA_IMAGE       = 3,
  FS_AREA_MAX         = 4,
};

#endif /* __FILE_SYSTEM_H__ */
