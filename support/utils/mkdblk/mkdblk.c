/* $Id: mkdblk.c,v 1.10 2007/07/11 05:03:47 cire Exp $ */
/*
 * mkdblk - create dblk structures on mass storage
 * Copyright 2006-2007, Eric B. Decker
 * Mam-Mark Project
 */

#include "mm_types.h"

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>

#include "mm_byteswap.h"
#include "fat_fs.h"
#include "fatxfc.h"
#include "ms.h"


#define VERSION "mkdblk: (mam_mark) v1.6 10 July 2007\n"

int debug	= 0,
    verbose	= 0,
    config_size =   8*1024,
    panic_size  = 128*1024,
    dblk_size   = 0,
    list        = 0;
    

static void usage(char *name) {
    fprintf(stderr, VERSION);
    fprintf(stderr, "usage: %s [-c <config_size>] [-d <data_size>] [-p <panic size>] [-Dlv] device_file\n", name);
    fprintf(stderr, "  -c <size>    set config size\n");
    fprintf(stderr, "  -D           increment debugging level\n");
    fprintf(stderr, "  -d <size>    set dblk size\n");
    fprintf(stderr, "  -l           list dblk if found\n");
    fprintf(stderr, "  -p <size>    set panic size\n");
    fprintf(stderr, "  -v           verbose mode (increment)\n");
    exit(2);
}


void
display_info(void) {
    fat_dir_entry_t *de;
    u32_t rds;
    
    if (msc.dblk_start)
	fprintf(stderr, "Dblk loc:  p: %lx %lx  c: %lx  %lx    d: %lx  %lx  (nxt) %lx\n",
		msc.panic_start, msc.panic_end, msc.config_start, msc.config_end,
		msc.dblk_start, msc.dblk_end, msc.dblk_nxt);
    else
	fprintf(stderr, "Dblk loc: not found\n");
    de = f32_get_de("PANIC001", "   ", &rds);
    if (de) {
	rds = (CF_LE_16(de->starthi) << 16) | CF_LE_16(de->start);
	fprintf(stderr, "PANIC001:  start  %lx  size: %ld (%lx)\n",
		fx_clu2sec(rds), CF_LE_32(de->size), CF_LE_32(de->size));
    } else
	fprintf(stderr, "PANIC001: not found\n");
    de = f32_get_de("CNFG0001", "   ", &rds);
    if (de) {
	rds = (CF_LE_16(de->starthi) << 16) | CF_LE_16(de->start);
	fprintf(stderr, "CNFG0001:  start  %lx  size: %ld (%lx)\n",
		fx_clu2sec(rds), CF_LE_32(de->size), CF_LE_32(de->size));
    } else
	fprintf(stderr, "CNFG001: not found\n");
    de = f32_get_de("DBLK0001", "   ", &rds);
    if (de) {
	rds = (CF_LE_16(de->starthi) << 16) | CF_LE_16(de->start);
	fprintf(stderr, "DBLK0001:  start  %lx  size: %ld (%lx)\n",
		fx_clu2sec(rds), CF_LE_32(de->size), CF_LE_32(de->size));
    } else
	fprintf(stderr, "DBLK001: not found\n");
}


int main(int argc, char **argv) {
    int     c;
    int     err;
    uint8_t buf[MS_BLOCK_SIZE];
    u32_t   pstart, pend, cstart, cend, dstart, dend;
    
    while ((c = getopt(argc,argv,"c:d:p:Dlv")) != EOF)
	switch (c) {
	  case 'c':
	      fprintf(stderr, "-c not implemented yet, defaults to 8192\n");
	      break;
	  case 'd':
	      fprintf(stderr, "-d not implemented yet, defaults to 0 (rest of partition\n");
	      break;
	  case 'D':
	      debug++;
	      break;
	  case 'l':
	      list++;
	      break;
	  case 'p':
	      fprintf(stderr, "-c not implemented yet, defaults to 128k\n");
	      break;
	  case 'v':
	      verbose++;
	      break;
	  default:
	      usage(argv[0]);
	}
    if (optind != argc - 1)
	usage(argv[0]);

    if (verbose)
	fprintf(stderr, VERSION);
    fx_hard_init();
    err = ms_init(argv[optind]);
    if (err) {
	fprintf(stderr, "ms_init: %s (%x)\n", ms_dsp_err(err), err);
	exit(1);
    }
    err = fx_set_buf(buf);
    if (err) {
	fprintf(stderr, "fx_set_buf: %s (%x)\n", fx_dsp_err(err), err);
	exit(1);
    }
    err = fx_init();
    if (err) {
	fprintf(stderr, "fx_init: %s (%x)\n", fx_dsp_err(err), err);
	exit(1);
    }
    if (list) {
	display_info();
	exit(0);
    }
    err = fx_create_contig("PANIC001", "   ", panic_size, &pstart, &pend);
    if (err) {
	fprintf(stderr, "fx_create_contig: panic: %s (%x)\n", fx_dsp_err(err), err);
	exit(1);
    }
    err = fx_create_contig("CNFG0001", "   ", config_size, &cstart, &cend);
    if (err) {
	fprintf(stderr, "fx_create_contig: cnfg: %s (%x)\n", fx_dsp_err(err), err);
	exit(1);
    }
    err = fx_create_contig("DBLK0001", "   ", dblk_size, &dstart, &dend);
    if (err) {
	fprintf(stderr, "fx_create_contig: dblk: %s (%x)\n", fx_dsp_err(err), err);
	exit(1);
    }
    err = fx_write_locator(pstart, pend, cstart, cend, dstart, dend);
    if (err) {
	fprintf(stderr, "fx_write_locator: %s (%x)\n", fx_dsp_err(err), err);
	exit(1);
    }

    if (verbose)
	display_info();

    err = fx_set_buf(NULL);
    if (err) {
	fprintf(stderr, "fx_set_buf: %s (%x)\n", fx_dsp_err(err), err);
	exit(1);
    }
    return(0);
}

/* Local Variables: */
/* tab-width: 8     */
/* End:             */
