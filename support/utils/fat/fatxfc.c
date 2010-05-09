/* $Id: fatxfc.c,v 1.28 2007/07/11 05:03:47 cire Exp $ */
/*
 * fatxfc.c - Psuedo-Fat File System Interface
 * Copyright 2006, Eric B. Decker
 * Mam-Mark Project
 *
 * Interface to the FAT file system on the SD card.  Implements very
 * simple access to the FAT filesystem.  Psuedo-FAT since real FAT
 * access is not provided.  Rather the results when complete can be
 * accessed on a system implementing full FAT.
 *
 * This module is written assuming the following:
 *
 * a) very limited processor.  ie.  16 bit or smaller machine.
 *    Handling 64 bit offsets is problematic at best.
 *
 * b) large mass storage devices available.  ie. 1+ Gig and as such
 *    byte offsets would be very large.
 *
 * c) Limited I/O subsystem.  No special provisions for h/w speed ups
 *    or anything else that would make for better mass storage
 *    performance.  There is a strong need to keep everything as
 *    simple as possible.
 *
 * d) FAT overhead is a killer.  The cost of keeping the FAT fs
 *    structures consistent as each write is a major performance hit
 *    wrt writing actual data.
 *
 * The pseudo file system provides the following:
 *
 * 1) Access is via blocks where the block size is chosen based on the
 *    h/w providing the mass storage itself.  typically 512 bytes
 *    (could be a multiple).
 *
 * 2) Block size is also chosen taking into account where the data
 *    lives in i/o memory.  The msp430f1611 has 10k while the
 *    msp430f2618 only 8K.  A block size of 512 seems reasonable.
 *
 * 3) Blocks are referenced via a blk_id.  32 bits max in length.
 *    With a block size of 512 bytes this allows storage of up to
 *    2,199,023,255,552 bytes (2 TiB).
 *
 *    Actual storage size is first limited by the physical h/w and
 *    then by the FAT file system.  FAT32 supports 28 bit clusters.
 *    With 8 sectors/cluster this supports 2,147,483,648 sectors
 *    providing 1,099,511,627,776 (1 TiB) Bytes.
 *
 *    The above is for maximum volume size.  File sizes are actually
 *    limited by the 32 bit FAT directory entry file size field (in
 *    bytes).  This limits any given file to 4,294,967,296 (4 GiB)
 *    bytes.  File size in the directory entry is only used by
 *    other systems (not the TAG) to access previously written data
 *    The psuedo-filesystem knows about and uses all sectors of all
 *    clusters allocated to a file.  When finished, the size field
 *    in the directory entry is updated.
 *
 * 4) Ability to find configuration files in the root directory
 *
 * 5) Ability to find one or more data files (data block, dblk).
 *    A data file has a unique name (ie. data0001) and consists of
 *    contiguous sectors typically the remainder of the storage
 *    device (less any pre-existing files on the device).  The size
 *    is also limited by the size limit of FAT filesystem.  32 bits
 *    of size.
 *
 * 6) Ability to close off a data file at a particular block and
 *    create a new data file that contains the remainder of unused
 *    space from the previous data file.  (Not supported)
 *
 * 7) Long file names are not supported.
 *
 *
 * Provides mechanisms to do the following:
 *
 * init: initilize any internal globals needed to properly access the
 *	on device fat structures.  Can be called multiple times for
 *      instance when doing a recovery after a system failure.
 *
 * hard_init: Called to force a full reset of the FX system.  Like
 *	being powered on for the first time.
 *
 * find_file: locate a file in the root directory.  does not
 *	understand low level directories.  assumes that the file is
 *	contiguous and returns the starting and ending blk_ids for the
 *	file.
 *
 * cap_dblk: cap off a dblk file.  Update fat structures to reflect
 *	true length.  Assigns remainder to a new dblk file.
 *
 * create_dblk: create a new dblk from all available space
 *	on a device.
 *
 * NOTE: Since the gadget is very limited in terms of resources (the MSP430
 * only has 10K of RAM) we need to be quite stingy with RAM.  The idea is
 * any initilization with respect to the file system will be done up front
 * and then absolute sectors (blk_ids) will be used there after.  During
 * initilization a scratch buffer is given to the FX code.  Once complete
 * this buffer is taken away.   fx_set_buf is used for this purpose.
 */


#include "mm_types.h"
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <mm_byteswap.h>
#include <fat_fs.h>
#include <string.h>

#include "fatxfc.h"
#include "ms.h"
#include "util.h"
#include "dblk_loc.h"


extern int debug;

static void  *fx_buf;
static u32_t fx_rdir_start;		/* root dir start sector */
static u32_t fx_rdir_end;		/* root dir end sector */
static u32_t fx_fat_start;		/* fat start, sector */
static u32_t fx_fat_end;		/* fat last sector, 1st fat */

static u32_t fx_max_cluster;		/* last real data cluster, 2 - max */

static u32_t fx_data_start;		/* first actual data sector, could be a dir */
static u32_t fx_data_end;		/* last sector accessable */

static u32_t fx_total_sectors;	/* total in partition */
static u32_t fx_fat_size;		/* in sectors */

static u32_t fx_info_sector;		/* where info lives. */
static u32_t fx_free_clusters;	/* from info sector */
static u32_t fx_next_cluster;	/* next free, from info */

static uint8_t  fx_reserved;		/* sectors */

/* may be replaced with hard defines in fatxfc.h */
static uint8_t  fx_cluster_size;	/* sectors */
static uint8_t  fx_num_fats;


static bool_t
fat32_part(uint8_t type) {
    switch(type) {
      case 0xb:
      case 0xc:
      case 0x1b:
      case 0x1c:
	  return(TRUE);
      default:
	  return(FALSE);
    }
}


static inline u32_t
clu2sec(u32_t clu) {
    return((clu - 2) * FX_CLUSTER_SIZE + fx_data_start);
}


u32_t
fx_clu2sec(u32_t clu) {
    return(clu2sec(clu));
}


/* f32_find_empty
 *
 * find an empty root directory entry
 *
 * i: *de	pointer to a fat_dir_entry_t *ptr.
 *    *rds	pointer to a u32_t for root dir sector
 *
 * o: rtn	FALSE if couldn't find an empty directory entry
 *              TRUE, an empty entry was found.  de and rds updated
 *   *de	written with the pointer to the directory entry found
 *   *rds	written to reflect which root_dir sector is being accessed
 *
 * side effect: fx_buf is modified to contain the current directory
 *		sector that contains the directory entry found.
 */

static bool_t
f32_find_empty(fat_dir_entry_t **rtn_de, u32_t *rtn_rds) {
    fat_dir_entry_t *de;
    u32_t rds;
    int i;

    rds = fx_rdir_start;
    while(rds <= fx_rdir_end) {
	assert(! ms_read_blk(rds, fx_buf));
	de = fx_buf;
	for (i = 0; i < DE_PER_BLK; i++, de++) {
	    if (!de->name[0] || de->name[0] == DELETED_FLAG ||
		  (de->attr & ATTR_LFN) == ATTR_EXT) {
		*rtn_de = de;
		*rtn_rds = rds;
		return(TRUE);
	    }
	}
	rds++;
    }
    *rtn_de = 0;
    *rtn_rds = 0;
    return(FALSE);
}


/* f32_get_chain
 *
 * If contiguous, return starting-ending sector numbers for
 * a cluster chain.
 *
 * i: cluster	cluster to start scan at
 *   *start	pointer to u32_t, start sector
 *   *end	pointer to u32_t, end   sector
 * o: rtn	TRUE -  chain contiguous, start and end set
 *		FALSE - discontiguous, start and end set to 0
 *
 * resources:	uses the global fx_buf buffer.  Caller is responsbile
 *	for rereading prior contents if needed.
 */

static bool_t
f32_get_chain(u32_t cluster, u32_t *start, u32_t *end) {
    u32_t fat_sector, nxt_cluster;
    uint8_t  fat_offset;
    u32_t *fats;

    *start = 0;
    *end = 0;
    cluster &= FAT32_CLUSTER_MASK;
    if (cluster < 2 || cluster > fx_max_cluster) {
      fprintf(stderr, "*** bad cluster, %lu\n", cluster);
      return(FALSE);
    }
    fat_sector = FAT_SECTOR(cluster);
    fat_sector += fx_fat_start;
    if (fat_sector > fx_fat_end) {
      fprintf(stderr, "*** bad fat sector: %lu\n", fat_sector);
      return(FALSE);
    }
    fat_offset = FAT_OFFSET(cluster);
    assert(!ms_read_blk(fat_sector, fx_buf));
    fats = fx_buf;
    *start = clu2sec(cluster);
    nxt_cluster = CF_LE_32(fats[fat_offset]) & FAT32_CLUSTER_MASK;
    while (nxt_cluster < EOF_FAT32 &&
	   nxt_cluster >= 2 &&
	   nxt_cluster == cluster + 1) {
	cluster++;
	fat_offset++;
	if (fat_offset > FAT_MAX_OFFSET) {
	    fat_sector++;
	    fat_offset = 0;
	    if (fat_sector > fx_fat_end) {
	      fprintf(stderr, "*** fat_sector (%lu) > fx_fat_end (%lu)\n", fat_sector, fx_fat_end);
	      return(FALSE);
	    }
	    assert(!ms_read_blk(fat_sector, fx_buf));
	}
	nxt_cluster = CF_LE_32(fats[fat_offset]) & FAT32_CLUSTER_MASK;
	if (nxt_cluster == BAD_FAT32) {
	  fprintf(stderr, "*** nxt_cluster is BAD_FAT32, %lu\n", nxt_cluster);
	  return(FALSE);
	}
    }
    if (nxt_cluster >= EOF_FAT32) {
	*end = clu2sec(cluster + 1) - 1;
	return(TRUE);
    }
    *start = 0;
    *end = 0;
    return(FALSE);
}


static bool_t
fat32_boot_sector(boot_sector_t *bs) {
    uint16_t ss;

    /* do a sanity check assuming it is a boot sector (1st sector of a partition)
     * note:  misaligned so do it one byte at a time.
     */
    ss = (bs->sector_size[1] << 8) | bs->sector_size[0];
    if (ss != SECTOR_SIZE ||				/* 512 */
	  bs->cluster_size == 0 ||			/* non-zero */
	  (bs->fats != 1 && bs->fats != 2) ||		/* only 1 or 2 */
	  *((uint16_t *) bs->dir_entries) != 0 ||	/* non-zero, fat16 */
	  *((uint16_t *) bs->sectors) != 0 ||		/* non-zero, fat16 */
	  bs->fat_length != 0 ||			/* non-zero, fat16 */
//	  bs->media != 0xf8 ||				/* 0xf8, hard disk */
	  bs->fat32_length == 0 ||			/* non-zero, fat32 */
	  bs->root_cluster == 0)			/* non-zero, fat32 */
	return(FALSE);
    return(TRUE);
}


/* f32_get_de
 *
 * Search the root directory for a file.  If found return a pointer
 * to the directory entry.  Uses fx_buf.
 *
 * i:	name	8 bytes, space filled.  Must be 8 bytes null terminated.
 *	ext	3 bytes, space filled.  Null terminated.
 *
 * o:	rtn	NULL, file not found
 *		non-NULL, pointer to directory entry in fx_buf
 */

fat_dir_entry_t *
f32_get_de(char *name, char *ext, u32_t *rds) {
    u32_t root_sec;
    fat_dir_entry_t *de;
    int i;

    for(root_sec = fx_rdir_start; root_sec <= fx_rdir_end; root_sec++) {
	assert(! ms_read_blk(root_sec, fx_buf));
	de = fx_buf;
	for (i = 0; i < DE_PER_BLK; i++, de++) {
	    if (!de->name[0])		/* 0 indicates nothing beyond */
		return(NULL);
	    if (de->name[0] == DELETED_FLAG)
		continue;
	    if ((de->attr & ATTR_LFN) == ATTR_EXT)
		continue;
	    if ((de->attr & ATTR_VOLUME) || (de->attr & ATTR_DIR))
		continue;
	    if (strncmp((char *) de->name, name, 8) != 0)
		continue;
	    if (strncmp((char *) de->ext, ext, 3) != 0)
		continue;
	    *rds = root_sec;
	    return(de);
	}
    }
    return(NULL);
}


/* FX_HARD_INIT
 *
 * Perform any initilization needed for the FATXFC on hard reset.
 */

void
fx_hard_init(void) {
    fx_buf = NULL;
}


/*
 * FX_INIT: Initilize the Psuedo-FAT interface
 *
 * Input:	buf	The buffer to use for any i/o operations.  Assumed to
 *			be at least MS_BLOCK_SIZE bytes.
 *
 * Output:	none
 *
 * Returns:	err	FX_OK (0) if success, otherwise error return.
 *
 * Side effects:
 *
 * Assumptions:
 *   1) mass storage system has been initilized.
 *
 * Notes:
 *
 *   1) Supports both partitioned and non-partioned set ups.  The
 *	partition table (1st sector, MBR) takes up what is thought to
 *	be the first cylinder (hence the "thought", cylinders are a
 *	figment) Anyway on a 1 Gig device, with a MBR/partition table
 *	we lose 0xf5 sectors, 125440 bytes.  This is why the
 *	non-partitioned is "better".
 *
 *	However, by default, WinBloz (XP etc) formats large flash
 *	devices as partitioned.  So we handle it.  In particular, this
 *	comes in handy if support for TAG based initilization is
 *	supported (depends on code space availability).  Support for
 *	partitioning maybe removed in a future release.
 *
 *   2) Only FAT32 is supported.  The number refers to the size in bits
 *	of cluster identifiers.  This size is selected solely
 *	dependent on the total number of data clusters on the device.
 *	With reasonable sized clusters (ie. 4K bytes) devices of 512MB
 *	on up utilize the FAT32 system.  It isn't worth supporting
 *	FAT16 as we will be using large devices predominantly.  FAT12
 *	isn't even worth discussing.
 */

fx_rtn
fx_init(void) {
    boot_sector_t *bs;
    info_sector_t *info;
    mbr_t *mbr;
    u32_t start, size;

    assert(fx_buf);
    assert(! ms_read_blk(0, fx_buf));

    /* First sector is either an MBR or the boot_sector of the partition.  It
     * had better have the 2 byte signature at the end.  ie.  0xaa55.
     *
     * Start by looking for a boot sector rather than the MBR.
     */
    bs = fx_buf;
    if (bs->sig != CT_LE_16(BOOT_SIG))
	return(FX_BAD_BOOT_SIG);

    start = fx_data_start = 0;
    if ( ! fat32_boot_sector(bs)) {
	/*
	 * something doesn't look right.  Look at the sector as an MBR and see
	 * if it makes sense.  We only look at partition 1.
	 */
	mbr = fx_buf;
	start = (mbr->p1.start4[3] << 24) | (mbr->p1.start4[2] << 16) |
	    (mbr->p1.start4[1] << 8)      | mbr->p1.start4[0];
	size  = (mbr->p1.size4[3] << 24)  | (mbr->p1.size4[2] << 16)  |
	    (mbr->p1.size4[1] << 8      ) | mbr->p1.size4[0];

	/* check for reasonableness, boot_ind can be 0x00 or 0x80 */
	if ((mbr->p1.boot_ind != 0 && mbr->p1.boot_ind != 0x80) ||
	      !fat32_part(mbr->p1.part_type) ||		/* reasonable fat32 partition? */
	      start == 0 ||				/* can't start at 0 */
	      size == 0)				/* zero means nothing, bail */
	    return(FX_NO_PARTITION);
	
	assert(! ms_read_blk(start, fx_buf));
	bs = fx_buf;
	if (CF_LE_16(bs->sig) != BOOT_SIG)
	    return(FX_BAD_BOOT_SIG);
	if (!fat32_boot_sector(bs))			/* make sure what we got is good */
	    return(FX_NO_PARTITION);
	/* check mbr partition size vs. total_sect entry in the file system header
	   only accept if the same or if file system size is one less than the partition header
	*/
	if (size != CF_LE_32(bs->total_sect)) {		/* and partition size should match internal */
	    if (debug)
		printf("*** mbr/fs size mismatch: mbr: %lu (%lx), fs: %lu (%lx)\n",
		       size, size, CF_LE_32(bs->total_sect), CF_LE_32(bs->total_sect));
	    if (size != CF_LE_32(bs->total_sect) + 1)
		return(FX_SIZE_MISMATCH);
	}
	fx_data_start = start;
    }

    if (debug)
	printf("Partition start: %lx, size: %lx\n",
		(u32_t) fx_data_start, CF_LE_32(bs->total_sect));

    /* buf contains the boot_sector.  compute total data sectors and make
       sure that it conforms to FAT32. */

    fx_cluster_size  = bs->cluster_size;	/* u8 */
    fx_reserved      = CF_LE_16(bs->reserved);
    fx_num_fats      = bs->fats;		/* u8 */
    fx_total_sectors = CF_LE_32(bs->total_sect);
    fx_fat_size      = CF_LE_32(bs->fat32_length);
    fx_info_sector   = start + CF_LE_16(bs->info_sector);

    fx_data_end      = fx_data_start + fx_total_sectors - 1;
    fx_fat_start     = fx_data_start + fx_reserved;
    fx_fat_end	     = fx_fat_start + fx_fat_size - 1;
    fx_data_start    = fx_fat_start + fx_fat_size * FX_NUM_FATS;

    size = fx_total_sectors;
    size -= (fx_reserved + (fx_fat_size * fx_num_fats));
    fx_max_cluster = size/fx_cluster_size;		/* last cluster */

    if (debug)
	printf("phys data sectors: %lx, phys clusters: %lx, unused sectors: %lx\n",
		size,
		fx_max_cluster,
		size - fx_max_cluster * fx_cluster_size);

    if (fx_max_cluster < 65525)				/* if less, not FAT32 */
	return(FX_NOT_FAT32);

    fx_max_cluster++;					/* make into cluster id */
    fx_data_end = clu2sec(fx_max_cluster + 1) - 1;	/* get last usable data sector */

    if (fx_cluster_size != FX_CLUSTER_SIZE)
      fprintf(stderr, "*** bad fx_cluster_size (%u) should be (%u)\n", fx_cluster_size, FX_CLUSTER_SIZE);
    if (fx_num_fats != FX_NUM_FATS)
      fprintf(stderr, "*** wrong number of FATS: (%u) should be (%u)\n", fx_num_fats, FX_NUM_FATS);

    f32_get_chain(CF_LE_32(bs->root_cluster), &fx_rdir_start, &fx_rdir_end);
    assert(fx_rdir_start && fx_rdir_end);

    assert(!ms_read_blk(fx_info_sector, fx_buf));
    info = fx_buf;
    if (info->boot_sig == CT_LE_16(BOOT_SIG) && IS_FSINFO(info)) {
	fx_free_clusters = CF_LE_32(info->free_clusters);
	fx_next_cluster = CF_LE_32(info->next_cluster);
    } else {
	fx_info_sector = 0;
	fx_free_clusters = (u32_t) -1;
	fx_next_cluster  = (u32_t) -1;
    }

    if (debug) {
	printf("ts: %lx, r: %x, fat_s: %lx, n: %d, ds: %lx\n",
		fx_total_sectors, fx_reserved,  fx_fat_size, fx_num_fats,
		fx_total_sectors-fx_reserved-(fx_num_fats*fx_fat_size));
	printf("fat_size (secs): %lx, (clus) %lx, %lx bytes\n",
		fx_fat_size, fx_fat_size * SECTOR_SIZE / sizeof(u32_t),
		fx_fat_size * SECTOR_SIZE);
	printf("data_start: %lx, end: %lx, usable sectors: %lx, last phys sector: %lx\n",
		fx_data_start,
		fx_data_end,
		fx_data_end - fx_data_start + 1,	/* usable */
		fx_data_start + (fx_total_sectors - fx_reserved -
				 (fx_num_fats * fx_fat_size))  - 1);
	printf("unused fat entries: %lx,  cluster ids: 2 - %lx\n",
		(fx_fat_end - fx_fat_start + 1) * FAT32_CPB - (fx_max_cluster + 1),
		    fx_max_cluster);
	printf("Last cluster: %lx,  sectors: %lx - %lx, fat sector: %lx, off: %lx\n",
		fx_max_cluster,
		clu2sec(fx_max_cluster),
		clu2sec(fx_max_cluster + 1) - 1,
		FAT_SECTOR(fx_max_cluster) + fx_fat_start,
		FAT_OFFSET(fx_max_cluster));
	printf("  fat_start: %5lx, fat_end: %5lx\n", fx_fat_start, fx_fat_end);
	printf("  info: free %5lx, next:    %5lx\n", fx_free_clusters, fx_next_cluster);
    }

    return(FX_OK);
}


/* fx_set_buf
 *
 * Tell the FATXFC code which buffer it can use for its work.
 *
 * i: buf	buffer address, NULL to release previous
 * o: rtn	FX_OK
 *		FX_INTERNAL internal error.  (will be traced later).
 *
 * Note: It is an error to change the buffer without first releasing
 * the current buffer.
 */

fx_rtn
fx_set_buf(void *buf) {
    assert(!(fx_buf && buf));		/* FX_INTERNAL */
    fx_buf = buf;
    return(FX_OK);
}


/* fx_find_file
 *
 * find a file in the root directory.  If found check the file's cluster
 * chain and if contiguous return the start and end.
 *
 * i:	name	8 bytes, space filled.  Must be 8 bytes null terminated.
 *	ext	3 bytes, space filled.  Null terminated.
 *     *start	pointer to u32_t, return for start of cluster chain.
 *     *end	ditto for end
 *
 * o:	rtn	FX_OK, file found, chain contiguous, start and end set
 *		FX_NOT_FOUND, file not found
 *		FX_NOT_CONTIGUOUS, chain not contiguous
 *     *start	set to starting cluster if FX_OK
 *     *end	ditto
 */

fx_rtn
fx_find_file(char *name, char *ext, u32_t *start, u32_t *end) {
    u32_t rds, cluster;
    fat_dir_entry_t *de;

    if(strlen(name) != 8 || strlen(ext) != 3)
	return(FX_INTERNAL);

    de = f32_get_de(name, ext, &rds);
    if (!de)
	return(FX_NOT_FOUND);
    cluster = (CF_LE_16(de->starthi) << 16) | CF_LE_16(de->start);
    if (cluster < 2 || cluster >= BAD_FAT32)
	return(FX_INTERNAL);
    if (!f32_get_chain(cluster, start, end))
	return(FX_NOT_CONTIGUOUS);
    return(FX_OK);
}


/* fx_cap_dblk
 *
 * Set the size of a dblk file, which is assumed to have a contiguous
 * cluster chain.  Size is used to set the directory entry size.  It
 * is also used to find where on the cluster chain to split the file.
 *
 * i:	name	name of a dblk file, null terminated must be 8 bytes
 *		space filled.
 *	ext	ext part of name.  null terminated, 3 bytes, space filled.
 *      n_name	new name for remainder
 *	n_ext   new ext for remainder
 *	size	32 bit size of where to cap the dblk file.
 *
 * o:   rtn	FS_OK
 *
 * The file if found is assumed to be a dblk file with contiguous cluster
 * chains.  The chain is split at size.   The new last cluster is marked
 * with an eof, a new directory entry is found and pointed to the remaining
 * cluster chain.  The name is set by tweaking the original name.  It is
 * assumed the original name is of the form "dblknnnn" where n is a digit
 * between 0 and 9.  The next file in sequence is created.

 1) check file can be found.
 2) check that size is < current size
 3) check that a new empty entry can be found.

 
 */

fx_rtn
fx_cap_dblk(char *name, char *ext, char *n_name, char *n_ext, u32_t size,
	    fat_dir_entry_t **rtn_de) {
    fat_dir_entry_t *de, *n_de;
    u32_t rds, n_rds, o_size, cluster;
    u32_t *fat, fat_sector, fat_offset;

    assert(fx_buf);
    if (strlen(name) != 8 || strlen(ext) != 3 ||
	strlen(n_name) != 8 || strlen(n_ext) != 3)
	return(FX_INTERNAL);

    /* check to see if new name already exists */
    de = f32_get_de(n_name, n_ext, &rds);
    if (de)
	return(FX_EXIST);
    de = f32_get_de(name, ext, &rds);
    if (!de)
	return(FX_NOT_FOUND);
    if (size >= CF_LE_32(de->size))
	return(FX_INTERNAL);
    if (!f32_find_empty(&n_de, &n_rds))
	return(FX_NO_ROOM);
    /*
     * read dir entry of original file and tweak size.
     */
    assert(! ms_read_blk(rds, fx_buf));
    o_size = CF_LE_32(de->size);
    de->size = CT_LE_32(size);
    assert(! ms_write_blk(rds, fx_buf));
    /*
     * compute eof cluster.  write it to eof.
     */
    cluster = (CF_LE_16(de->starthi) << 16) | CF_LE_16(de->start);
    cluster += (size + (FX_CLUSTER_SIZE * SECTOR_SIZE - 1))/(FX_CLUSTER_SIZE * SECTOR_SIZE) - 1;
    fat_sector = FAT_SECTOR(cluster) + fx_fat_start;
    fat_offset = FAT_OFFSET(cluster);
    assert(! ms_read_blk(fat_sector, fx_buf));
    fat = fx_buf;
    fat[fat_offset] = CT_LE_32(EOF_FAT32);
    assert(! ms_write_blk(fat_sector, fx_buf));
    /*
     * now read the directory sector for the new file
     */
    cluster++;
    assert(! ms_read_blk(n_rds, fx_buf));
    memcpy(n_de->name, n_name, 8);
    memcpy(n_de->ext, n_ext, 3);
    n_de->starthi = CT_LE_16(cluster >> 16);
    n_de->start = CT_LE_16(cluster & 0xffff);
    size += (FX_CLUSTER_SIZE * SECTOR_SIZE - 1);
    size &= ~FX_CB_MASK;	/* round up to next cluster */
    n_de->size = CT_LE_32(o_size - size);
    assert(! ms_write_blk(n_rds, fx_buf));
    return(FX_OK);
}


/*
 * fx_create_contig
 *
 * - Scan free clusters in the fat tables on the device
 * - find first contiguous group of free clusters, greater than or equal size.
 * - rewrite the group so it is one chain.
 * - find a free entry in the root directory
 * - write the free entry to create a new file with "name", "ext", and use the chain
 *   free entries are either empty (0), deleted (0xe4), or an LFN entry.
 *
 * s and e are used to return the sector numbers of the start and end of the
 * contiguous file
 *
 * Both FATs are written with the new values.
 */

fx_rtn
fx_create_contig(char *name, char *ext, u32_t size, u32_t *s, u32_t *e) {
    u32_t *fat;
    u32_t max, max_count, start, count;
    u32_t fat_sector, i, limit;
    fat_dir_entry_t *de;
    info_sector_t *info;
    uint8_t offset;
    int done;

    assert(fx_buf);
    if (strlen(name) != 8 || strlen(ext) != 3)
	return(FX_INTERNAL);

    if (fx_find_file(name, ext, &start, &count) != FX_NOT_FOUND)
	return(FX_EXIST);

    fat = fx_buf;
    start = count = max = max_count = done = 0;
    for (fat_sector = fx_fat_start; fat_sector <= fx_fat_end; fat_sector++) {
	assert(!ms_read_blk(fat_sector, fx_buf));
	for (i = (fat_sector == fx_fat_start ? 2 : 0);
	       i <= (fat_sector == fx_fat_end ?
		     (fx_max_cluster & FAT32_CPB_MASK) :
		     FAT32_CPB_MASK);
	       i++) {
	    if ((fat[i] & CT_LE_32(FAT32_CLUSTER_MASK)) == 0) {	/* swap constant, compile time */
		switch(start) {
		  case 0:
		      start = ((fat_sector - fx_fat_start) << FAT32_CPB_BITS) + i;
		      count = 1;
		      break;
		  default:
		      count++;
		      if (size && count * FX_CLUSTER_SIZE * SECTOR_SIZE >= size)
			  done = 1;
		      break;
		}
		if (done)
		    break;
	    } else
		switch(start) {
		  case 0:
		      break;
		  default:
		      if (count > max_count) {
			  max = start;
			  max_count = count;
		      }
		      start = count = 0;
		      break;
		}
	}
	if (done)
	    break;
    }
    if (start && count > max_count) {
	max = start;
	max_count = count;
    }
    if (debug) {
	printf("create_contig: size: %lx   s: %lx, count: %lx\n", size, max, max_count);
	printf("               clusters: %lx-%lx, sectors: %lx-%lx, size: %lx\n",
		max, max + max_count - 1, clu2sec(max), clu2sec(max + max_count) - 1,
		max_count * FX_CLUSTER_SIZE * SECTOR_SIZE);
    }
    *s = clu2sec(max);
    *e = clu2sec(max + max_count) - 1;
    if (max == 0)
	return(FX_NO_ROOM);
    assert(max + max_count - 1 <= fx_data_end);
    if (!f32_find_empty(&de, &i))
	return(FX_NO_ROOM);
    memset(de, 0, sizeof(fat_dir_entry_t));
    strncpy((char *) de->name, name, 8);
    strncpy((char *) de->ext, ext, 3);
    de->attr = ATTR_NONE;
    de->starthi = CT_LE_16(max >> 16);
    de->start = CT_LE_16(max & 0xffff);
    de->size = CT_LE_32(max_count * FX_CLUSTER_SIZE * SECTOR_SIZE);
    assert(! ms_write_blk(i, fx_buf));

    /* now rerun through the FAT changing the chain */
    fat_sector = FAT_SECTOR(max) + fx_fat_start;
    offset = FAT_OFFSET(max);
    assert(!ms_read_blk(fat_sector, fx_buf));
    fat = fx_buf;
    limit = max + max_count;		/* one past last */
    for (start = max + 1; start <= limit; start++) {
	fat[offset] = (start == limit ? CT_LE_32(EOF_FAT32) : CT_LE_32(start));
	offset++;
	if (offset > FAT_MAX_OFFSET) {
	    assert(!ms_write_blk(fat_sector, fx_buf));
	    assert(!ms_write_blk(fat_sector + fx_fat_size, fx_buf));
	    fat_sector++;
	    assert(!ms_read_blk(fat_sector, fx_buf));
	    offset = 0;
	}
    }
    if (offset) {
	assert(!ms_write_blk(fat_sector, fx_buf));
	assert(!ms_write_blk(fat_sector + fx_fat_size, fx_buf));
    }
    if (fx_info_sector) {
	assert(!ms_read_blk(fx_info_sector, fx_buf));
	info = fx_buf;
	if (info->boot_sig == CT_LE_16(BOOT_SIG) && IS_FSINFO(info)) {
	    info->free_clusters = CT_LE_32((u32_t) -1);
	    info->next_cluster = CF_LE_32((u32_t) -1);
	    assert(!ms_write_blk(fx_info_sector, fx_buf));
	} else
	    fx_info_sector = 0;
	fx_free_clusters = (u32_t) -1;
	fx_next_cluster  = (u32_t) -1;
    }
    return(FX_OK);
}


fx_rtn
fx_write_locator(u32_t pstart, u32_t pend, u32_t cstart, u32_t cend, u32_t dstart, u32_t dend) {
    boot_sector_t *bs;
    dblk_loc_t *dbl;
    uint16_t   *p, i, sum;

    assert(fx_buf);
    assert(!ms_read_blk(0, fx_buf));
    bs = fx_buf;
    if (bs->sig != CT_LE_16(BOOT_SIG))
	return(FX_BAD_BOOT_SIG);
    dbl = fx_buf + DBLK_LOC_OFFSET;
    dbl->sig = CT_LE_32(TAG_DBLK_SIG);
    dbl->panic_start = CT_LE_32(pstart);
    msc.panic_start = pstart;
    dbl->panic_end   = CT_LE_32(pend);
    msc.panic_end = pend;
    dbl->config_start = CT_LE_32(cstart);
    msc.config_start = cstart;
    dbl->config_end   = CT_LE_32(cend);
    msc.config_end = cend;
    dbl->dblk_start   = CT_LE_32(dstart);
    msc.dblk_start = dstart;
    dbl->dblk_end     = CT_LE_32(dend);
    msc.dblk_end = dend;
    dbl->dblk_chksum  = 0;
    p = (void *) dbl;
    sum = 0;
    for (i = 0; i < DBLK_LOC_SIZE_SHORTS; i++)
	sum += CF_LE_16(p[i]);
    dbl->dblk_chksum = CT_LE_16((uint16_t) (0 - sum));
    assert(!ms_write_blk(0, fx_buf));

    /* see if there is a backup at sector 6, just assume it is so */
    assert(!ms_read_blk(6, fx_buf));
    bs = fx_buf;
    if (bs->sig != CT_LE_16(BOOT_SIG))		/* if not, its okay */
	return(FX_OK);
    dbl = fx_buf + DBLK_LOC_OFFSET;
    dbl->sig = CT_LE_32(TAG_DBLK_SIG);
    dbl->panic_start = CT_LE_32(pstart);
    dbl->panic_end   = CT_LE_32(pend);
    dbl->config_start = CT_LE_32(cstart);
    dbl->config_end   = CT_LE_32(cend);
    dbl->dblk_start   = CT_LE_32(dstart);
    dbl->dblk_end     = CT_LE_32(dend);
    dbl->dblk_chksum  = 0;
    p = (void *) dbl;
    sum = 0;
    for (i = 0; i < DBLK_LOC_SIZE_SHORTS; i++)
	sum += CF_LE_16(p[i]);
    dbl->dblk_chksum = CT_LE_16((uint16_t) (0 - sum));
    assert(!ms_write_blk(6, fx_buf));
    return(FX_OK);
}


char *
fx_dsp_err(fx_rtn err) {
    switch(err) {
      case FX_OK:		return("ok");
      case FX_INTERNAL:		return("internal");
      case FX_BAD_BOOT_SIG:	return("bad boot sig");
      case FX_NO_PARTITION:	return("no partition");
      case FX_SIZE_MISMATCH:	return("size mismatch");
      case FX_NOT_FAT32:	return("not FAT32");
      case FX_NOT_FOUND:	return("not found");
      case FX_NOT_CONTIGUOUS:	return("not contiguous");
      case FX_NO_ROOM:		return("no room");
      case FX_EXIST:		return("already exists");
    }
    return("unknown");
}


#ifdef FX_DEBUG

void
dbg_mangle_root(void) {
    u32_t rsec, cluster, start, end;
    int writeit, idx;
    fat_dir_entry_t *de;

    for (rsec = fx_rdir_start; rsec <= fx_rdir_end; rsec++) {
	writeit = 0;
	ms_read_blk(rsec, fx_buf);
	de = fx_buf;
	for(idx = 0; idx < DE_PER_BLK; idx++, de++) {
	    if (writeit > 1)		/* bail if writing */
		break;
	    if (!de->name[0])		/* 0 indicates nothing beyond */
		continue;
	    if (de->name[0] == DELETED_FLAG)
		continue;
	    if ((de->attr & ATTR_LFN) == ATTR_EXT)
		continue;
	    if ((de->attr & ATTR_VOLUME) || (de->attr & ATTR_DIR))
		continue;
	    cluster = (CF_LE_16(de->starthi) << 16) | CF_LE_16(de->start);
	    if (cluster < 2 || cluster >= BAD_FAT32)
		continue;
	    if (!f32_get_chain(cluster, &start, &end)) {
		ms_read_blk(rsec, fx_buf);
		continue;
	    }
	    /* MUST reread after get_chain, which uses the buffer */
	    ms_read_blk(rsec, fx_buf);
	    if (start == 0 || end == 0)	/* do nothing */
		continue;
	}
	switch(writeit) {
	  default:
	      break;
	  case 1:
	  case 2:
	      ms_write_blk(rsec, fx_buf);
	      break;
	  case 3:
	      memset(fx_buf, 0, SECTOR_SIZE);
	      ms_write_blk(rsec, fx_buf);
	      break;
	}
    }
}

#endif /* FX_DEBUG */
