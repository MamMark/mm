/*
 * tagfmtsd - create dblk structures on mass storage
 * Copyright 2006-2008, 2010, 2017 Eric B. Decker
 * Mam-Mark Project
 *
 * typical usage: (format SD media on the Tag)
 *
 * vfat format:     mkdosfs -F 32 -I -n"TagTest" -v /dev/sdb
 * create locators: tagfmtsd -w /dev/sdb
 */

#include <mm_types.h>

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <string.h>
#include <time.h>

#include <mm_byteswap.h>
#include <fat_fs.h>
#include <fatxfc.h>
#include <ms.h>

#include <dblk_dir.h>


extern fs_loc_t loc;


#define VERSION "tagfmtsd: v4.3.0  2018/01/07\n"

int debug	= 0,
    verbose	= 0,
    do_write	= 0,
    force       = 0;

const uint8_t *dblk_id_str = (void *) "DBLK";

const char *dow_strs[] = {
/*  0      1      2      3      4      5      6   */
  "sun", "mon", "tue", "wed", "thu", "fri", "sat"
};


const char *dow2str(uint8_t dow) {
  if (dow > 6)
    return "unk";
  return dow_strs[dow];
}


/*
 * all sizes in bytes.
 *
 * image_size is set to include all image slots (at 128KiB each) and
 * the directory sector (512 bytes).
 *
 * panic size is 16 panic blocks.  each block can be up to 150 sectors
 * long.  150 sectors is ~75KiB.  We also need one sector for the Panic
 * Directory sector.
 */
uint32_t config_size = 8*1024,
         panic_slots = 32,
         panic_block_size = 150,
         img_slots   = 4,
	 dblk_size   = 0;


static struct option longopts[] = {
  { "version",	no_argument, NULL, 'V' },
  { "help",	no_argument, NULL, 'h' },
  { NULL,	0,	     NULL, 0 }
};


static void usage(char *name) {
    fprintf(stderr, VERSION);
    fprintf(stderr, "usage: %s [-c <config_size>] [-d <data_size>] [-p <panic size>] [-Dfvw] device_file\n", name);
    fprintf(stderr, "  -c <size>    set config size\n");
    fprintf(stderr, "  -d <size>    set dblk size\n");
    fprintf(stderr, "  -f           force (rewrite dirs)\n");
    fprintf(stderr, "  -h           this usage\n");
    fprintf(stderr, "  --help\n");
    fprintf(stderr, "  -i <n slots> set number of image slots (n x 128KiB\n");
    fprintf(stderr, "  -p <size>    set panic size\n\n");
    fprintf(stderr, "  -D           increment debugging level\n");
    fprintf(stderr, "  -v           verbose mode (increment)\n");
    fprintf(stderr, "  -V           display version\n");
    fprintf(stderr, "  --version\n");
    fprintf(stderr, "  -w           enable write of any changes needed\n");
    fprintf(stderr, "               otherwise just list what is there\n");
    exit(2);
}


void
display_info(uint8_t *buf) {
    fat_dir_entry_t *de;
    u32_t rds;
    dblk_dir_t *ddp;
    uint32_t    sum, *p32;
    int err, i;

    fprintf(stderr, "fs_loc:  p:   s: %-8x   e: %x\n",
            loc.locators[FS_LOC_PANIC].start,
            loc.locators[FS_LOC_PANIC].end);
    fprintf(stderr, "         c:   s: %-8x   e: %x\n",
            loc.locators[FS_LOC_CONFIG].start,
            loc.locators[FS_LOC_CONFIG].end);
    fprintf(stderr, "         i:   s: %-8x   e: %x\n",
            loc.locators[FS_LOC_IMAGE].start,
            loc.locators[FS_LOC_IMAGE].end);
    rds = 0;
    if (msc_dblk_nxt)
      rds = msc_dblk_nxt - loc.locators[FS_LOC_DBLK].start;
    fprintf(stderr, "         d:   s: %-8x   e: %-8x  nxt: %x  (%d blks)\n",
            loc.locators[FS_LOC_DBLK].start,
            loc.locators[FS_LOC_DBLK].end,
            msc_dblk_nxt, rds);

    de = f32_get_de("PANIC001", "   ", &rds);
    if (de) {
	rds = (CF_LE_16(de->starthi) << 16) | CF_LE_16(de->start);
	fprintf(stderr, "PANIC001:  start  0x%04x  size: %10u (0x%x)\n",
                fx_clu2sec(rds),  CF_LE_32(de->size), CF_LE_32(de->size));
    } else
	fprintf(stderr, "PANIC001: not found\n");
    de = f32_get_de("CNFG0001", "   ", &rds);
    if (de) {
	rds = (CF_LE_16(de->starthi) << 16) | CF_LE_16(de->start);
	fprintf(stderr, "CNFG0001:  start  0x%04x  size: %10u (0x%x)\n",
                fx_clu2sec(rds),  CF_LE_32(de->size), CF_LE_32(de->size));
    } else
	fprintf(stderr, "CNFG0001: not found\n");
    de = f32_get_de("IMAGE001", "   ", &rds);
    if (de) {
	rds = (CF_LE_16(de->starthi) << 16) | CF_LE_16(de->start);
	fprintf(stderr, "IMAGE001:  start  0x%04x  size: %10u (0x%x)\n",
		fx_clu2sec(rds), CF_LE_32(de->size), CF_LE_32(de->size));
    } else
	fprintf(stderr, "IMAGE001: not found\n");
    de = f32_get_de("DBLK0001", "   ", &rds);
    if (de) {
	rds = (CF_LE_16(de->starthi) << 16) | CF_LE_16(de->start);
	fprintf(stderr, "DBLK0001:  start  0x%04x  size: %10u (0x%x)\n",
		fx_clu2sec(rds), CF_LE_32(de->size), CF_LE_32(de->size));
        /*
         * examine the dblk dir
         */
        err = ms_read_blk(loc.locators[FS_LOC_DBLK].start, buf);
        if (err)
          fprintf(stderr, "could not read dblk dir: %s (0x%x)\n",
                  fx_dsp_err(err), err);
        else {
          ddp = (void *) buf;
          p32 = (void *) buf;
          sum = 0;
          for (i = 0; i < DBLK_DIR_QUADS; i++)
            sum += *p32++;
          i = strncmp((void *) dblk_id_str, (void *) ddp->dblk_id, DBLK_ID_SIZE);
          fprintf(stderr,
                  "  dir:    id: %s  idx: %d   checksum: 0x%08x (0x%08x)",
                  (i ? (char *) "unk " : (char *) dblk_id_str), ddp->file_idx,
                  ddp->chksum, sum);
          if (sum) fprintf(stderr, "  <bad>\n");
          else     fprintf(stderr, "  <good>\n");
          fprintf(stderr, "  sigs:   %08x/%08x  low/high: 0x%04x/%08x\n",
                  ddp->dblk_dir_sig, ddp->dblk_dir_sig_a,
                  ddp->dblk_low, ddp->dblk_high);
          fprintf(stderr, "  incept: %04d/%02d/%02d-(%s)-%02d:%02d:%02d UTC\n",
              ddp->incept_date.yr,  ddp->incept_date.mon, ddp->incept_date.day,
              dow2str(ddp->incept_date.dow), ddp->incept_date.hr,
              ddp->incept_date.min, ddp->incept_date.sec);
        }
    } else
	fprintf(stderr, "DBLK0001: not found\n");
}


/*
 * write_dblk_dir: create and write out the dblk directory.
 *
 * Create the directory.  Includes:
 * o start and end (low/high)
 * o incept date in datetime format.  (creation date)
 *
 * write directory out to first sector of the dblk area.
 */
int write_dblk_dir(uint8_t *buf, uint8_t file_idx) {
  dblk_dir_t *ddp;
  struct tm   split_gmtime, *gmp;
  time_t      time_secs;
  uint32_t    sum, *p32;
  int err, i;

  gmp = &split_gmtime;
  time_secs = time(NULL);
  if (gmtime_r(&time_secs, gmp) == NULL)
    fprintf(stderr, "*** write_dblk_dir: gmtime_r failed.\n");

  /*
   * modify what is returned to make it conform to what dateTime
   * expects.  TI RTC format.
   */
  if (gmp->tm_sec > 59)                 /* check for leap sec */
    gmp->tm_sec = 59;                   /* ignore it */
  gmp->tm_mon++;
  gmp->tm_year += 1900;                 /* adjust to current century */

  memset(buf, 0, MS_BUF_SIZE);
  ddp = (void *) buf;
  ddp->dblk_id[0]       = 'D';
  ddp->dblk_id[1]       = 'B';
  ddp->dblk_id[2]       = 'L';
  ddp->dblk_id[3]       = 'K';
  ddp->dblk_dir_sig     = DBLK_DIR_SIG;
  ddp->dblk_low         = loc.locators[FS_LOC_DBLK].start;
  ddp->dblk_high        = loc.locators[FS_LOC_DBLK].end;
  ddp->incept_date.yr   = gmp->tm_year;
  ddp->incept_date.mon  = gmp->tm_mon;
  ddp->incept_date.day  = gmp->tm_mday;
  ddp->incept_date.hr   = gmp->tm_hour;
  ddp->incept_date.min  = gmp->tm_min;
  ddp->incept_date.sec  = gmp->tm_sec;
  ddp->incept_date.dow  = gmp->tm_wday;
  ddp->file_idx         = file_idx;
  ddp->dblk_dir_sig_a   = DBLK_DIR_SIG;
  ddp->chksum           = 0;
  p32 = (void *) buf;
  for (i = 0; i < DBLK_DIR_QUADS; i++)
    sum += *p32++;
  ddp->chksum = (uint32_t) (0 - sum);
  err = ms_write_blk(loc.locators[FS_LOC_DBLK].start, buf);
  if (err)
    fprintf(stderr, "write_dblk_dir: DBLK0001: could not write dblk dir: %s (0x%x)\n",
            fx_dsp_err(err), err);
  return err;
}


int main(int argc, char **argv) {
    int     c;
    int     err;
    uint8_t buf[MS_BUF_SIZE];
    u32_t   image_size;
    u32_t   panic_size;
    int     do_fs_loc;

    while ((c = getopt_long(argc,argv,"c:d:i:p:DfhvVw", longopts, NULL)) != EOF)
	switch (c) {
	  case 'c':
	      fprintf(stderr, "-c not implemented yet, defaults to 8192\n");
	      break;
	  case 'd':
	      fprintf(stderr, "-d not implemented yet, defaults to 0 (rest of partition)\n");
	      break;
	  case 'D':
	      debug++;
	      break;
          case 'f':
              force++;
              break;
	  case 'h':
	      usage(argv[0]);
	      break;
	  case 'i':
	      fprintf(stderr, "-i not implemented yet, defaults to 4 slots, 128k each\n");
	      break;
	  case 'p':
	      fprintf(stderr, "-p not implemented yet, defaults to 128k\n");
	      break;
	  case 'v':
	      verbose++;
	      break;
	  case 'V':
	      fprintf(stderr, VERSION);
	      exit(0);
	      break;
	  case 'w':
	      do_write++;
	      break;
	  default:
	      usage(argv[0]);
	      break;
	}
    if (optind != argc - 1)
	usage(argv[0]);

    if (verbose)
	fprintf(stderr, VERSION);
    fx_hard_init();
    err = ms_init(argv[optind]);
    if (err == MS_READONLY) {
      fprintf(stderr, "tagfmtsd: %s is read only\n", argv[optind]);
      err = MS_OK;
      do_write = 0;
    }
    if (err) {
	fprintf(stderr, "ms_init: %s (0x%x)\n", ms_dsp_err(err), err);
	exit(1);
    }
    err = fx_set_buf(buf);
    if (err) {
	fprintf(stderr, "fx_set_buf: %s (0x%x)\n", fx_dsp_err(err), err);
	exit(1);
    }
    err = fx_init();
    if (err) {
	fprintf(stderr, "fx_init: %s (0x%x)\n", fx_dsp_err(err), err);
	exit(1);
    }
    if (!do_write) {
	display_info(buf);
	exit(0);
    }
    do_fs_loc = 1;
    panic_size = (panic_slots * panic_block_size + 1) * 512;
    err = fx_create_contig("PANIC001", "   ", panic_size,
                           &loc.locators[FS_LOC_PANIC].start,
                           &loc.locators[FS_LOC_PANIC].end);
    if (err) {
	fprintf(stderr, "fx_create_contig: PANIC001: %s (0x%x)\n", fx_dsp_err(err), err);
	do_fs_loc = 0;
    }
    if (do_fs_loc || force) {
      /*
       * also need to force the directory sector (the first sector in the region) to zero.
       */
      if (verbose)
        fprintf(stderr, "*** zeroing PANIC directory\n");
      memset(buf, 0, MS_BUF_SIZE);
      err = ms_write_blk(loc.locators[FS_LOC_PANIC].start, buf);
      if (err) {
	fprintf(stderr, "fx_create_contig: PANIC001: could not zero dir: %s (0x%x)\n", fx_dsp_err(err), err);
	do_fs_loc = 0;
      }
    }
    err = fx_create_contig("CNFG0001", "   ", config_size,
                           &loc.locators[FS_LOC_CONFIG].start,
                           &loc.locators[FS_LOC_CONFIG].end);
    if (err) {
	fprintf(stderr, "fx_create_contig: CNFG0001: %s (0x%x)\n", fx_dsp_err(err), err);
	do_fs_loc = 0;
    }

    /*
     * each slot is 128KiB (128 * 1024) bytes + 512, directory sector.
     */
    image_size = img_slots * 128 * 1024 + 512;
    err = fx_create_contig("IMAGE001", "   ", image_size,
                           &loc.locators[FS_LOC_IMAGE].start,
                           &loc.locators[FS_LOC_IMAGE].end);
    if (err) {
	fprintf(stderr, "fx_create_contig: IMAGE001: %s (0x%x)\n", fx_dsp_err(err), err);
	do_fs_loc = 0;
    }
    if (do_fs_loc || force) {
      /*
       * also need to force the directory sector (the first sector in the region) to zero.
       */
      if (verbose)
        fprintf(stderr, "*** zeroing IMAGE directory\n");
      memset(buf, 0, MS_BUF_SIZE);
      err = ms_write_blk(loc.locators[FS_LOC_IMAGE].start, buf);
      if (err) {
	fprintf(stderr, "fx_create_contig: IMAGE001: could not zero dir: %s (0x%x)\n", fx_dsp_err(err), err);
	do_fs_loc = 0;
      }
    }
    err = fx_create_contig("DBLK0001", "   ", dblk_size,
                           &loc.locators[FS_LOC_DBLK].start,
                           &loc.locators[FS_LOC_DBLK].end);
    if (err) {
	fprintf(stderr, "fx_create_contig: DBLK0001: %s (0x%x)\n", fx_dsp_err(err), err);
	do_fs_loc = 0;
    }
    if (do_fs_loc || force) {
      if (verbose)
        fprintf(stderr, "*** writing DBLK directory\n");
      if (write_dblk_dir(buf, 1))
        do_fs_loc = 0;
    }
    if (do_fs_loc) {
      fprintf(stderr, "*** writing fs locator\n");
      err = fx_write_locator(&loc);
      if (err) {
	fprintf(stderr, "fx_write_locator: %s (0x%x)\n", fx_dsp_err(err), err);
	exit(1);
      }
    }

    display_info(buf);

    if (!do_fs_loc)
      fprintf(stderr, "*** locator not written\n");
    if (force)
      fprintf(stderr, "*** directories rewritten\n");

    return(0);
}

/* Local Variables: */
/* tab-width: 8     */
/* End:             */
