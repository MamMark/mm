/* $Id: fatxfc.h,v 1.12 2007/07/11 05:03:47 cire Exp $ */
/*
 * fatxfc.h - Psuedo-Fat File System Interface
 * Copyright 2006, Eric B. Decker
 * Mam-Mark Project
 */

#ifndef _FATXFC_H
#define _FATXFC_H

#include <fs_loc.h>

#define FX_ID 0x20

typedef enum {
    FX_OK		= 0,
    FX_INTERNAL		= (FX_ID | 1),
    FX_BAD_BOOT_SIG	= (FX_ID | 2),
    FX_NO_PARTITION	= (FX_ID | 3),
    FX_SIZE_MISMATCH	= (FX_ID | 4),
    FX_NOT_FAT32	= (FX_ID | 5),
    FX_NOT_FOUND	= (FX_ID | 6),
    FX_NOT_CONTIGUOUS	= (FX_ID | 7),
    FX_NO_ROOM		= (FX_ID | 8),
    FX_EXIST		= (FX_ID | 9),
} fx_rtn;


/*
  Hard defines to simplify the code.  Note if the default formatting
  of the storage chip changes these may be incorrect causing the
  Tag code to panic.

  Alternative is to use variables:

  #define FX_CLUSTER_SIZE	fx_cluster_size
  #define FX_NUM_FATS		fx_num_fats
*/

#define FX_CLUSTER_SIZE		8U
#define FX_NUM_FATS		2U
#define FX_CB_MASK		0xfffU


extern u32_t  fx_clu2sec(u32_t clu);
extern fat_dir_entry_t * f32_get_de(char *name, char *ext, u32_t *rds);
extern void   fx_hard_init(void);
extern fx_rtn fx_init(void);
extern fx_rtn fx_set_buf(void *buf);
extern fx_rtn fx_find_file(char *name, char *ext, u32_t *start, u32_t *end);
extern fx_rtn fx_check_dblk(DIR_ENT *de);
extern fx_rtn fx_cap_dblk(char *name, char *ext, char *n_name, char *n_ext, u32_t size,
			  fat_dir_entry_t **rtn_de);
extern fx_rtn fx_create_contig(char *name, char *ext, u32_t size, u32_t *start, u32_t *end);
extern fx_rtn fx_write_locator(fs_loc_t *fsl);
extern fx_rtn fx_write_panic0(u32_t pstart, u32_t pend);
extern char * fx_dsp_err(fx_rtn err);

#ifdef FX_DEBUG
extern void dbg_mangle_root(void);
#endif

#endif	/* _FATXFC_H */
