/* $Id: fat_fs.h,v 1.6 2007/07/22 17:49:45 cire Exp $ */
/*
  Defines about the generic fat file system.  From Linux.
*/

#include "mm_types.h"

#ifndef _FAT_FS_H
#define _FAT_FS_H

#define SECTOR_SIZE     512 /* sector size (bytes) */
#define SECTOR_BITS	9 /* log2(SECTOR_SIZE) */
#define MSDOS_DPB	(MSDOS_DPS) /* dir entries per block */
#define MSDOS_DPB_BITS	4 /* log2(MSDOS_DPB) */
#define MSDOS_DPS	(SECTOR_SIZE/sizeof(fat_dir_entry_t))
#define MSDOS_DPS_BITS	4 /* log2(MSDOS_DPS) */
#define MSDOS_DIR_BITS	5 /* log2(sizeof(struct fat_dir_entry_t)) */

#define DE_PER_BLK (SECTOR_SIZE/sizeof(fat_dir_entry_t))

#define FAT32_CPB	(SECTOR_SIZE/sizeof(uint32_t))
#define FAT32_CPB_BITS	7
#define FAT32_CPB_MASK	0x7f

#define FAT_SECTOR(x) ((x) >> FAT32_CPB_BITS)
#define FAT_OFFSET(x) ((x) & FAT32_CPB_MASK)
#define FAT_MAX_OFFSET (FAT32_CPB_MASK)

#define ATTR_RO      0x01	/* read-only */
#define ATTR_HIDDEN  0x02	/* hidden */
#define ATTR_SYS     0x04	/* system */
#define ATTR_VOLUME  0x08	/* volume label */
#define ATTR_DIR     0x10	/* directory */
#define ATTR_ARCH    0x20	 /* archived */

#define ATTR_LFN     0x3f

#define ATTR_NONE    0 /* no attribute bits */
#define ATTR_UNUSED  (ATTR_VOLUME | ATTR_ARCH | ATTR_SYS | ATTR_HIDDEN)
	/* attribute bits that are copied "as is" */
#define ATTR_EXT     (ATTR_RO | ATTR_HIDDEN | ATTR_SYS | ATTR_VOLUME)
	/* bits that are used by the Windows 95/Windows NT extended FAT */

#define ATTR_DIR_READ_BOTH 512 /* read both short and long names from the
				* vfat filesystem.  This is used by Samba
				* to export the vfat filesystem with correct
				* shortnames. */
#define ATTR_DIR_READ_SHORT 1024

#define CASE_LOWER_BASE 8	/* base is lower case */
#define CASE_LOWER_EXT  16	/* extension is lower case */

#define SCAN_ANY     0  /* either hidden or not */
#define SCAN_HID     1  /* only hidden */
#define SCAN_NOTHID  2  /* only not hidden */
#define SCAN_NOTANY  3  /* test name, then use SCAN_HID or SCAN_NOTHID */

#define DELETED_FLAG 0xe5 /* marks file as deleted when in name[0] */
#define IS_FREE(n) (!*(n) || *(const unsigned char *) (n) == DELETED_FLAG)

#define MSDOS_VALID_MODE (S_IFREG | S_IFDIR | S_IRWXU | S_IRWXG | S_IRWXO)
	/* valid file mode bits */


#define MSDOS_NAME 11 /* maximum name length */
#define MSDOS_LONGNAME 256 /* maximum name length */
#define MSDOS_SLOTS 21  /* max # of slots needed for short and long names */
#define MSDOS_DOT    ".          "	/* ".", padded to MSDOS_NAME chars */
#define MSDOS_DOTDOT "..         "	/* "..", padded to MSDOS_NAME chars */

#define MSDOS_FAT12 4084 /* maximum number of clusters in a 12 bit FAT */

#define BAD_FAT12 0xFF7
#define BAD_FAT16 0xFFF7
#define BAD_FAT32 0xFFFFFF7
#define BAD_FAT(s) ((s)->fat_bits == 32 ? BAD_FAT32 : \
	(s)->fat_bits == 16 ? BAD_FAT16 : BAD_FAT12)

#define EOF_FAT12 0xFF8		/* standard EOF */
#define EOF_FAT16 0xFFF8
#define EOF_FAT32 0xFFFFFF8
#define EOF_FAT(s) ((s)->fat_bits == 32 ? EOF_FAT32 : \
	(s)->fat_bits == 16 ? EOF_FAT16 : EOF_FAT12)

#define FAT32_CLUSTER_MASK	0x0fffffff


/* If we are looking at a MBR sector (1st sector on the disk), there is room
 * for 4 partition descriptor in the last few bytes of the sector.  These
 * partitions start at 0x1be.
 */

#ifdef __ICC430__
#define PACKED
#define PRAGMA_PACK #pragma pack(1)
#else
#define PACKED __attribute__((__packed__))
#endif


#define BOOT_SIG 0xaa55

typedef struct {
    uint8_t boot_ind;			/* 0x80 - active */
    uint8_t head;			/* starting head */
    uint8_t sector;			/* starting sector */
    uint8_t cyl;			/* starting cylinder */
    uint8_t part_type;			/* What partition type */
    uint8_t end_head;			/* end head */
    uint8_t end_sector;			/* end sector */
    uint8_t end_cyl;			/* end cylinder */
    uint8_t start4[4];		        /* starting sector counting from 0 */
    uint8_t size4[4];		        /* nr of sectors in partition */
} PACKED partition_t;


typedef struct {
    uint8_t ignore[0x1be];		/* space out until partition descriptors */
    partition_t p1;
    partition_t p2;
    partition_t p3;
    partition_t p4;
    uint16_t sig;			/* should be last 2 bytes */
} PACKED mbr_t;


typedef struct {
    __u8	ignored[3];		/* Boot strap short or near jump */
    __u8	system_id[8];		/* Name - can be used to special case */
					/* partition manager volumes */
    __u8	sector_size[2];		/* bytes per logical sector */
    __u8	cluster_size;		/* sectors/cluster */
    __u16	reserved;		/* reserved sectors */
    __u8	fats;			/* number of FATs */
    __u8	dir_entries[2];		/* root directory entries */
    __u8	sectors[2];		/* number of sectors */
    __u8	media;			/* media code (unused) */
    __u16	fat_length;		/* sectors/FAT */
    __u16	secs_track;		/* sectors per track */
    __u16	heads;			/* number of heads */
    __u32	hidden;			/* hidden sectors (unused) */
    __u32	total_sect;		/* number of sectors (if sectors == 0) */

    /* The following fields are only used by FAT32 */
    __u32	fat32_length;		/* sectors/FAT */
    __u16	flags;			/* bit 8: fat mirroring, low 4: active fat */
    __u8	version[2];		/* major, minor filesystem version */
    __u32	root_cluster;		/* first cluster in root directory */
    __u16	info_sector;		/* filesystem info sector */
    __u16	backup_boot;		/* backup boot sector */
    __u16	reserved2[6];		/* Unused */

    /* fill up to 512 bytes */
    __u8	junk[446];
    __u16	sig;			/* should be 0xaa55 */
}  PACKED boot_sector_t;


#define FAT_FSINFO_SIG1		0x41615252
#define FAT_FSINFO_SIG2		0x61417272
#define IS_FSINFO(x)		((x)->signature1 == CT_LE_32(FAT_FSINFO_SIG1)	 \
				 && (x)->signature2 == CT_LE_32(FAT_FSINFO_SIG2))

typedef struct {
    __u32	signature1;	/* Magic for info sector ('RRaA') */
    __u8	junk[0x1dc];
    __u32	reserved1;	/* Nothing as far as I can tell */
    __u32	signature2;	/* 0x61417272 ('rrAa') */
    __u32	free_clusters;	/* Free cluster count.  -1 if unknown */
    __u32	next_cluster;	/* Most recently allocated cluster. */
    __u32	reserved2[3];
    __u16	reserved3;
    __u16	boot_sig;
} PACKED info_sector_t;


typedef struct {
    __u8	name[8],ext[3];	/* name and extension */
    __u8	attr;		/* attribute bits */
    __u8	lcase;		/* Case for base and extension */
    __u8	ctime_ms;	/* Creation time, milliseconds */
    __u16	ctime;		/* Creation time */
    __u16	cdate;		/* Creation date */
    __u16	adate;		/* Last access date */
    __u16	starthi;	/* High 16 bits of cluster in FAT32 */
    __u16	time,date,start;/* time, date and first cluster */
    __u32	size;		/* file size (in bytes) */
} PACKED fat_dir_entry_t;

typedef fat_dir_entry_t DIR_ENT;


/* Up to 13 characters of the name */
struct msdos_dir_slot {
	__u8    id;		/* sequence number for slot */
	__u8    name0_4[10];	/* first 5 characters in name */
	__u8    attr;		/* attribute byte */
	__u8    reserved;	/* always 0 */
	__u8    alias_checksum;	/* checksum for 8.3 alias */
	__u8    name5_10[12];	/* 6 more characters in name */
	__u16   start;		/* starting cluster number, 0 in long slots */
	__u8    name11_12[4];	/* last 2 characters in name */
} PACKED ;

#endif /* _FAT_FS_H */
