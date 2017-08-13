/*
 * file_system.h - simple contiguous file system
 * Copyright 2010 Eric B. Decker, Carl Davis
 * Mam-Mark Project
 *
 * split out from stream storage.
 */

#ifndef _FILE_SYSTEM_H
#define _FILE_SYSTEM_H

/*
 * File System Control Structure
 *
 * panic_start: where to write panic information when all hell breaks loose
 * panic_end:   end of panic block.
 * config_start: block number of where the config is located.  must be contiguous
 * config_end:  ending block number of end of config.
 * dblk_start:  where to start writing data collected
 * dblk_end:    last block id of where to write data collected.
 * dblk_nxt:	current block to write.  If we are writing, this is the
 *		block being written.  This is the next blk for the Typed Data stream.
 * image_start: block id of where images start, blk_id of image_root
 * image_end:   ending block_id for image area.
 */

typedef struct {
    uint16_t majik_a;		/* practice safe computing */
    uint32_t panic_start;	/* where to write panic information */
    uint32_t panic_end;
    uint32_t config_start;	/* blk id of configuration */
    uint32_t config_end;
    uint32_t dblk_start;	/* blk id, don't go in front */
    uint32_t dblk_end;		/* blk id, don't go beyond*/
    uint32_t dblk_nxt;		/* blk id, next to write */
    uint32_t image_start;	/* blk id of image area */
    uint32_t image_end;
    uint16_t majik_b;
} fs_control_t;

#define FSC_MAJIK 0x8181


enum {
  FS_AREA_PANIC       = 0,
  FS_AREA_CONFIG      = 1,
  FS_AREA_TYPED_DATA  = 2,
  FS_AREA_IMAGE       = 3,
};

#endif /* _FILE_SYSTEM_H */
