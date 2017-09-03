/*
 * tagdump - dump mm data, debug, or control stream from a file.
 *
 * Copyright 2008, 2010, 2014, 2017: Eric B. Decker
 * All rights reserved.
 *
 * Mam-Mark Project
 *
 * @author Eric B. Decker
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <ctype.h>
#include <getopt.h>
#include <libgen.h>
#include <string.h>
#include <time.h>

#include <typed_data.h>
#include "filesource.h"
#include "ParseSirf.h"

#define VERSION "tagdump: v0.90.1  (20170827)\n"

int debug	= 0,
    verbose	= 0,
    force_events= 0,
    write_data  = 0;

static void usage(char *name) {
  fprintf(stderr, VERSION);
  fprintf(stderr, "usage: %s [-Dev] [-f | --file] <input file>\n", name);
  fprintf(stderr, "  --file | -f (default)\n");
  fprintf(stderr, "           take input from <input file>\n");
  fprintf(stderr, "  -D       increment debugging level\n");
  fprintf(stderr, "             1 - basic debugging, 2 - dump packet data\n");
  fprintf(stderr, "  -e       show event logging\n");
  fprintf(stderr, "  -h | --help\n");
  fprintf(stderr, "  -V | --version\n");
  fprintf(stderr, "  -v       verbose mode (increment)\n");
  exit(2);
}

static char *msgs[] = {
  "unknown_packet_type",
  "ack_timeout"	,
  "sync"	,
  "too_long"	,
  "too_short"	,
  "bad_sync"	,
  "bad_crc"	,
  "closed"	,
  "no_memory"	,
  "unix_error"
};


FILE *fp[MM_NUM_SENSORS];

void stderr_msg(serial_source_msg problem) {
  fprintf(stderr, "*** Note: %s\n", msgs[problem]);
}


/*
 * sns_payload_len: allows an easy conversion from sensor id
 * to how many bytes in the payload.
 */

uint8_t sns_payload_len[MM_NUM_SENSORS] = {
  0,				/* not used */
  BATT_PAYLOAD_SIZE,		/* dock, looks like batt */
  BATT_PAYLOAD_SIZE,		/* batt */
  TEMP_PAYLOAD_SIZE,		/* temp */
  SAL_PAYLOAD_SIZE,		/* salinity */
  ACCEL_PAYLOAD_SIZE,		/* accel */
  PTEMP_PAYLOAD_SIZE,		/* ptemp */
  PRESS_PAYLOAD_SIZE,		/* pressure */
  SPEED_PAYLOAD_SIZE,		/* speed */
  MAG_PAYLOAD_SIZE		/* magnatometer */
};


char *
dtype2str(uint8_t id) {
  switch(id) {
    case DT_IGNORE:	return("ignore");
    case DT_CONFIG:	return("config");
    case DT_SYNC:	return("sync");
    case DT_REBOOT:	return("reboot");
    case DT_PANIC:	return("panic");
    case DT_GPS_RAW:    return("gps_raw");
    case DT_GPS_TIME:	return("gps_time");
    case DT_GPS_POS:	return("gps_pos");
    case DT_SENSOR_DATA:return("sensor_data");
    case DT_SENSOR_SET:	return("sensor_set");
    case DT_TEST:	return("test");
    case DT_NOTE:	return("note");
    case DT_VERSION:	return("version");
    case DT_EVENT:	return("event");
    case DT_DEBUG:	return("debug");
    default:		return("unk");
  }
}

/*
 * assumed to have a maximum size of 5 bytes
 */

#define SNS_NAME_LEN 5

char *
snsid2str(uint8_t id) {
  switch(id) {
    case SNS_ID_CRADLE:
      return("DOCK");
    case SNS_ID_BATT:
      return("BATT");
    case SNS_ID_TEMP:
      return("TEMP");
    case SNS_ID_SAL:
      return("SAL");
    case SNS_ID_ACCEL:
      return("ACCEL");
    case SNS_ID_PTEMP:
      return("PTEMP");
    case SNS_ID_PRESS:
      return("PRESS");
    case SNS_ID_SPEED:
      return("SPEED");
    case SNS_ID_MAG:
      return("MAG");
    default:
      return("UNK");
  }
}

/*
 * write file preamble
 *
 * include some identifing information about the sensor
 * being written out to the file.
 */

void
write_preamble(FILE *fp, uint8_t sns_id) {
  if (sns_id == SNS_ID_CRADLE)
    return;
  fprintf(fp, "%% %s", VERSION);
  fprintf(fp, "%% sensor %d, %s, ", sns_id, snsid2str(sns_id));
  if (sns_payload_len[sns_id] == 2)
    fprintf(fp, "1 value\n");
  else
    fprintf(fp, "%d values\n", sns_payload_len[sns_id]/2);
  fprintf(fp, "%% col 1, time stamp (not sched) in msec from last restart\n");
  fprintf(fp, "%% col 2");
  switch(sns_id) {
    case SNS_ID_BATT:  fprintf(fp, " batt voltage\n"); break;
    case SNS_ID_TEMP:  fprintf(fp, " temp\n"); break;
    case SNS_ID_SAL:   fprintf(fp, "-3: sal 1, sal 2\n"); break;
    case SNS_ID_ACCEL: fprintf(fp, "-4: accel X, Y, Z\n"); break;
    case SNS_ID_PTEMP: fprintf(fp, ": pressure temp\n"); break;
    case SNS_ID_PRESS: fprintf(fp, ": pressure\n"); break;
    case SNS_ID_SPEED: fprintf(fp, "-3: speed 1, speed 2\n"); break;
    case SNS_ID_MAG:   fprintf(fp, "-4: mag XY_A, XY_B, Z_A\n"); break;
    default:           fprintf(fp, ": huh\n");
  }
}


/* Open Files
 *
 * Open data files, 1 for each sensor.  These files are used to
 * hold sensor data (seperate data streams) as data is processed from
 * the input stream.
 *
 * data_<sensor name>_200803202214
 * full name is prefix length (assumed to include
 * any directory slashes) + 5 (data_) + _ + stamp (1 + 15)
 * length of sensor name (5 max)
 */

#define DATA_LEN 5
#define STAMP_LEN 14
#define DATA_FILE_NAME_LEN (DATA_LEN + SNS_NAME_LEN + STAMP_LEN)

void
open_files(char *prefix) {
  int i, len, len2;
  char *name, *sns;
  char *mode;
  struct tm local;
  time_t cur_time;

  mode = "w";
  time(&cur_time);
  localtime_r(&cur_time, &local);
  len = strlen(prefix);
  len2 = len + DATA_FILE_NAME_LEN;
  name = malloc(len2);
  strcpy(name, prefix);
  strcat(name, "data_");
  len += DATA_LEN;
  len += snprintf(&name[len], STAMP_LEN, "%04d%02d%02d%02d%02d_",
		  1900 + local.tm_year, 1 + local.tm_mon, local.tm_mday,
		  local.tm_hour, local.tm_min);
  for (i = 1; i < MM_NUM_SENSORS; i++) {
    if (i == SNS_ID_CRADLE)
      continue;
    name[len] = 0;
    sns = snsid2str(i);
    len2 = strlen(sns);
    strcat(name, sns);
    fp[i] = fopen(name, mode);
    if (!fp[i]) {
      fprintf(stderr, "*** could not open data file for sensor %s (%d)\n",
	      snsid2str(i), i);
      perror("open: ");
      exit(2);
    }
    if (setvbuf(fp[i], NULL, _IONBF, 0)) {
      fprintf(stderr, "*** setvbuf for id %d failed\n", i);
      perror("setvbuf: ");
      exit(2);
    }
    write_preamble(fp[i], i);
  }
  free(name);
}


void
process_ignore(tmsg_t *msg) {
  uint16_t len;
  uint8_t  dtype;

  len = dt_ignore_len_get(msg);
  dtype = dt_ignore_dtype_get(msg);
  if (verbose)
    printf("IGN %04x %02x\n", len, dtype);
}

void
process_config(tmsg_t *msg) {
  if (verbose)
    printf("config\n");
}


void
process_sync(dt_reboot_t *rbtp) {
  int i;
  uint16_t len;
  dtype_t  dtype;
  uint32_t stamp;
  uint32_t majik;
  uint16_t boot_count;
  uint8_t  c;
  char *s;
  int err = 0;

  /*
   * first part of sync and reboot messages are exactly the same.
   * reboot also has boot_count.
   */
  len =   rbtp->len;
  dtype = rbtp->dtype;
  stamp = rbtp->stamp_ms;
  majik = rbtp->sync_majik;
  boot_count = 0;
  if (majik != SYNC_MAJIK)
    err = 1;
  switch (dtype) {
    default:
      /* bitch like hell */
      return;
    case DT_SYNC:
      if (len != sizeof(dt_sync_t))
	err = 1;
      c = 'S';
      s = "sync";
      break;

    case DT_REBOOT:
      if (len != sizeof(dt_reboot_t))
	err = 1;
      c = 'R';
      s = "reboot";
      boot_count = rbtp->boot_count;
      break;
  }
  if (err)
    printf("--- ");
  if (err || verbose || dtype == DT_REBOOT)
    printf("SYNC: %c %d (%x) %08x (%s) bc: %d\n", c, stamp, stamp, majik, s, boot_count);
  if (write_data) {
    for (i = 0; i < MM_NUM_SENSORS; i++) {
      fprintf(fp[i], "%% ");
      if (err)
	fprintf(fp[i], "--- err ");
      fprintf(fp[i], "SYNC: %c %d %08x %s %d\n", c, stamp, majik, s, boot_count);
    }
  }
}

void
process_panic(tmsg_t *msg) {
  uint32_t stamp_ms;
  uint8_t  pcode;
  uint8_t  where;
  uint16_t arg0;
  uint16_t arg1;
  uint16_t arg2;
  uint16_t arg3;

  stamp_ms  = dt_panic_stamp_ms_get(msg);
  pcode     = dt_panic_pcode_get(msg);
  where     = dt_panic_where_get(msg);
  arg0      = dt_panic_arg0_get(msg);
  arg1      = dt_panic_arg1_get(msg);
  arg2      = dt_panic_arg2_get(msg);
  arg3      = dt_panic_arg3_get(msg);
  printf("*** %s:  %u (0x%04x) pcode: %d (0x%0x)  where: %d (0x%02x)  0x%04x 0x%04x 0x%04x 0x%04x\n",
	 ((pcode & 0x80) ? "pWARN" : "PANIC"),
	 stamp_ms, stamp_ms, pcode, pcode, where, where, arg0, arg1, arg2, arg3);
}


void
process_gps_time(tmsg_t *msg) {
  uint32_t stamp_ms;
  uint8_t  chip_type;
  uint8_t  num_svs;
  uint16_t utc_year;
  uint8_t  utc_month;
  uint8_t  utc_day;
  uint8_t  utc_hour;
  uint8_t  utc_min;
  double utc_millsec;           /* s x 1000 */
  double clock_bias;		/* m x 10^2 */
  double clock_drift;		/* m/s x 10^2 */

  stamp_ms  = dt_gps_time_stamp_ms_get(msg);
  chip_type = dt_gps_time_chip_type_get(msg);
  num_svs = dt_gps_time_num_svs_get(msg);
  utc_year = dt_gps_time_utc_year_get(msg);
  utc_month = dt_gps_time_utc_month_get(msg);
  utc_day = dt_gps_time_utc_day_get(msg);
  utc_hour = dt_gps_time_utc_hour_get(msg);
  utc_min = dt_gps_time_utc_min_get(msg);
  utc_millsec = ((double)dt_gps_time_utc_millsec_get(msg))/1000;
  clock_bias =  ((double)dt_gps_time_clock_bias_get(msg))/100;
  clock_drift = ((double)dt_gps_time_clock_drift_get(msg))/100;

  if (verbose) {
    fprintf(stderr, "GPS TIME[%d] %d (0x%04x): nsats: %d  ", chip_type, stamp_ms, stamp_ms, num_svs);
    fprintf(stderr, "%2d/%02d/%04d %2d:%02d:%06.3f\n", utc_month, utc_day, utc_year, utc_hour, utc_min, utc_millsec);
    fprintf(stderr, "  Clock bias: %f  drift: %f\n", clock_bias, clock_drift);
  }
}


void
process_gps_pos(tmsg_t *msg) {
  uint32_t stamp_ms;
  uint8_t  chip_type;
  uint16_t nav_type;
  uint32_t sats_seen;		/* bit mask, sats in solution */
  double gps_lat;		/* + North, x 10^7 degrees */
  double gps_long;		/* + East,  x 10^7 degrees */
  uint8_t  num_svs;		/* number of sv in solution */
  float hdop;		        /* err *5 m x 4 */
  int i;

  stamp_ms  = dt_gps_pos_stamp_ms_get(msg);
  chip_type = dt_gps_pos_chip_type_get(msg);
  num_svs = dt_gps_pos_num_svs_get(msg);
  nav_type = dt_gps_pos_nav_type_get(msg);
  sats_seen = dt_gps_pos_sats_seen_get(msg);
  gps_lat = ((double)dt_gps_pos_gps_lat_get(msg))/10000000;
  gps_long = ((double)dt_gps_pos_gps_long_get(msg))/10000000;
  num_svs = dt_gps_pos_num_svs_get(msg);
  hdop = ((float)dt_gps_pos_hdop_get(msg))/5;

  if (verbose) {
    fprintf(stderr, "GPS POS[%d] %d (0x%04x): nsats %d\n", chip_type, stamp_ms, stamp_ms, num_svs);
    fprintf(stderr,"  Nav type (0x%04x): ", nav_type);
    switch(nav_type & 0x0007) {
      case(0x0):
	fprintf(stderr,"No fix. "); break;
      case(0x1):
	fprintf(stderr,"1 sat soln. "); break;
      case(0x2):
	fprintf(stderr,"2 sat soln. "); break;
      case(0x3):
	fprintf(stderr,"3 sat soln. "); break;
      case(0x4):
	fprintf(stderr,">3 sat soln. "); break;
      case(0x5):
	fprintf(stderr,"2-D least sqr sln. "); break;
      case(0x6):
	fprintf(stderr,"3-d least sqr sln. "); break;
      case(0x7):
	fprintf(stderr,"DR soln. "); break;
    }
    if(nav_type & 0x0008)
      fprintf(stderr,"Trickle pwr. ");
    switch(nav_type & 0x0030) {
      case(0x0):
	fprintf(stderr,"No alt hold. "); break;
      case(0x10):
	fprintf(stderr,"Hold alt from KF. "); break;
      case(0x20):
	fprintf(stderr,"Hold alt from user. "); break;
      case(0x30):
	fprintf(stderr,"Always hold user alt. "); break;
    }
    if(nav_type & 0x0040)
      fprintf(stderr,"DOP exceeds limits. ");
    if(nav_type & 0x0080)
      fprintf(stderr,"DGPS correction applied. ");
    if(nav_type & 0x0100)
      fprintf(stderr,"Sensor DR. ");
    else if (nav_type & 0x0007)
      fprintf(stderr,"Velocity DR. ");
    else
      fprintf(stderr,"DR error. ");
    if(nav_type & 0x0200)
      fprintf(stderr,">4 sat soln. ");
    if(nav_type & 0x0400)
      fprintf(stderr,"Velocity DR timeout. ");
    if(nav_type & 0x0800)
      fprintf(stderr,"Fix edited by MI. ");
    if(nav_type & 0x1000)
      fprintf(stderr,"Invalid velocity. ");
    if(nav_type & 0x2000)
      fprintf(stderr,"Alt. hold disabled. ");
    switch(nav_type & 0xC000) {
      case(0x0):
	fprintf(stderr,"GPS nav only. "); break;
      case(0x4000):
	fprintf(stderr,"DR calibration from GPS. "); break;
      case(0x8000):
	fprintf(stderr,"DR sensor error. "); break;
      case(0xC000):
	fprintf(stderr,"DRin test.. "); break;
    }
    fprintf(stderr, "\n  %d Sats in soln.: ", num_svs);
    for(i=1; i<32; i++) {
      if (sats_seen & 0x00000001)
	fprintf(stderr, "%d ", i);
      sats_seen = sats_seen >> 1;
    }
    fprintf(stderr, "\n  Lat: %.7f  Lon: %.7f  Error: %.2f\n", gps_lat, gps_long, hdop);
  }
}


void
process_gps_raw(tmsg_t *msg) {
  uint32_t stamp;
  uint8_t dtype, chip;
  uint16_t len;

  len   = dt_gps_raw_len_get(msg);
  dtype = dt_gps_raw_dtype_get(msg);
  chip  = dt_gps_raw_chip_get(msg);
  stamp = dt_gps_raw_stamp_ms_get(msg);

  if (verbose) {
    fprintf(stderr, "GPS RAW (%d): t: %d (0x%04x) ", chip, stamp, stamp);
    parseSirf(msg);
  }
}


void
process_sensor_data(tmsg_t *msg) {
  uint16_t i;
  uint32_t sched, stamp;
  uint8_t sns_id;
  uint16_t len;
  uint8_t dtype;

  len = dt_sensor_data_len_get(msg);
  dtype = dt_sensor_data_dtype_get(msg);
  sns_id = dt_sensor_data_sns_id_get(msg);

  dt_sensor_data_sns_id_set(msg, sns_id + 1); /* why is this here? */

  sched = dt_sensor_data_sched_ms_get(msg);
  stamp = dt_sensor_data_stamp_ms_get(msg);
  if (verbose) {
    printf("SNS: %-6s (%d) %8u (%04x/%04x, %3d)",
	   snsid2str(sns_id), sns_id, sched, sched, stamp, stamp-sched);
    if (sns_id < MM_NUM_SENSORS) {
      for (i = 0; i < (sns_payload_len[sns_id]/2); i++)
	printf(" %5d", dt_sensor_data_data_get(msg, i));
      printf("  [ ");
      for (i = 0; i < (sns_payload_len[sns_id]/2); i++)
	printf("%04x ", dt_sensor_data_data_get(msg, i));
      printf("]\n");
    } else
      printf("(unk) %04x\n", dt_sensor_data_data_get(msg, 0));
  }
  if (sns_id > 0 && sns_id < MM_NUM_SENSORS) {
    if (write_data) {
      fprintf(fp[sns_id], "%-8u ", stamp);
      for (i = 0; i < (sns_payload_len[sns_id]/2); i++)
	fprintf(fp[sns_id], "%5d ", dt_sensor_data_data_get(msg, i));
      fprintf(fp[sns_id], "\n");
    }
  }
}


void
process_version(tmsg_t *msg) {
  uint8_t major, minor, build;
  int i;

  major = dt_version_major_get(msg);
  minor = dt_version_minor_get(msg);
  build = dt_version_build_get(msg);
  printf("VER: %d.%d.%d\n", major, minor, build);
  if (write_data)
    for (i = 1; i < MM_NUM_SENSORS; i++)
      fprintf(fp[i], "%% Tag Version: %d.%d.%d\n", major, minor, build);
}


char *
event2str(uint8_t ev) {
  switch(ev) {
    case DT_EVENT_SURFACED:
      return "surfaced";
    case DT_EVENT_SUBMERGED:
      return "submerged";
    case DT_EVENT_DOCKED:
      return "docked";
    case DT_EVENT_UNDOCKED:
      return "undocked";
    case DT_EVENT_GPS_BOOT:
      return "gps_boot";
    case DT_EVENT_GPS_RECONFIG:
      return "gps_reconfig";
    case DT_EVENT_GPS_START:
      return "gps_start";
    case DT_EVENT_GPS_OFF:
      return "gps_off";
    case DT_EVENT_GPS_FAST:
      return "gps_fast";
    case DT_EVENT_GPS_FIRST:
      return "gps_first";
    case DT_EVENT_GPS_SATS_2:
      return "gps_sats(2)";
    case DT_EVENT_GPS_SATS_7:
      return "gps_sats(7)";
    case DT_EVENT_GPS_SATS_29:
      return "gps_sats(29)";
    case DT_EVENT_GPSCM_STATE:
      return "gps c/m state";
    default:
      return "unk";
  }
}


char *
cState2str(uint8_t state) {
  switch(state) {
    case 1:	return "fail";
    case 2:	return "off";
    case 3:	return "reconfig_4800_pwr_down";
    case 4:	return "reconfig_4800_start_delay";
    case 5:	return "reconfig_4800_hunting";
    case 6:	return "reconfig_4800_eos_wait";
    case 7:	return "reconfig_4800_sending";
    case 8:	return "eos_wait";
    case 9:	return "sending";
    case 10:	return "fini_wait";
    case 11:	return "finish";
    case 12:	return "requested";
    case 13:	return "start_delay";
    case 14:	return "hunt_1";
    case 15:	return "hunt_2";
    case 16:	return "on";
    case 17:	return "releasing";
    case 18:	return "back_to_nmea";
    default:	return "unk";
  }
}


char *
mState2str(uint8_t state) {
  switch(state) {
    case 16:	return "down";
    case 17:	return "starting";
    case 18:	return "short";
    case 19:	return "long";
    case 20:	return "stopping";
    default:	return "unk";
  }
}


void
process_event(tmsg_t *msg) {
  uint32_t stamp;
  uint8_t  ev;
  uint16_t arg;

  stamp = dt_event_stamp_ms_get(msg);
  ev = dt_event_ev_get(msg);
  arg = dt_event_arg_get(msg);
  if (verbose || force_events) {
    fprintf(stderr, "EVENT: %8u %-12s (%d) arg: %d (0x%04x)\n", stamp, event2str(ev), ev, arg, arg);
    if (ev == DT_EVENT_GPSCM_STATE) {
      fprintf(stderr, "       collect state: %s (%d),  msg state: %s (%d)\n", cState2str(arg >> 8), (arg >> 8),
	      mState2str(arg & 0xff), arg & 0xff);
    }
  }
}


void
process_unk_dblk(tmsg_t *msg) {
    fprintf(stderr, "*** unknown dblk: ");
    hexprint(tmsg_data(msg), tmsg_length(msg));
}


void
process_dblk(dt_header_t *dblk_p) {
  uint16_t len;
  uint8_t  dtype;

  len   = dblk_p->len;
  dtype = dblk_p->dtype;
  if (debug)
    fprintf(stderr, "    len: %0d (0x%02x)  dtype: %0d (0x%02x) %s\n", len, len, dtype, dtype, dtype2str(dtype));
  switch (dtype) {
    case DT_IGNORE:
      process_ignore(dblk_p);
      break;
    case DT_CONFIG:
      process_config(dblk_p);
      break;
    case DT_SYNC:
    case DT_REBOOT:
      process_sync((dt_reboot_t *) dblk_p);
      break;
    case DT_PANIC:
      process_panic(dblk_p);
      break;
    case DT_GPS_TIME:
      process_gps_time(dblk_p);
      break;
    case DT_GPS_POS:
      process_gps_pos(dblk_p);
      break;
    case DT_SENSOR_DATA:
      process_sensor_data(dblk_p);
      break;
    case DT_SENSOR_SET:
      break;
    case DT_TEST:
      break;
    case DT_NOTE:
      break;
    case DT_GPS_RAW:
      process_gps_raw(dblk_p);
      break;
    case DT_VERSION:
      process_version(dblk_p);
      break;
    case DT_EVENT:
      process_event(dblk_p);
      break;
    default:
      process_unk_dblk(dblk_p);
      break;
  }
}


typedef enum {
  INPUT_FILE   = 1,
} input_src_t;


/* options descriptor */
static struct option longopts[] = {
  { "file",	no_argument, NULL, 'f' },
  { "version",	no_argument, NULL, 'V' },
  { "help",	no_argument, NULL, 'h' },
  { NULL,	0,	     NULL, 0 }
};

int		file_src;	/* fd for input file */

int
main(int argc, char **argv) {
  char *prog_name;
  int len;
  int c, bail;
  input_src_t input_src;
  dt_header_t *dblk_p;

  file_src = 0;
  input_src = INPUT_FILE;
  bail = 0;
  prog_name = basename(argv[0]);
  while ((c = getopt_long(argc, argv, "Devf", longopts, NULL)) != EOF) {
    switch (c) {
      case 'f':
	bail = 1;
	input_src = INPUT_FILE;
	break;
      case 'D':
	debug++;
	break;
      case 'e':
	force_events++;
	break;
      case 'v':
	verbose++;
	break;
      case 'V':
	fprintf(stderr, VERSION);
	exit(2);
      case 'h':
      default:
	usage(prog_name);
    }
    if (bail)
      break;
  }
  argc -= optind;
  argv += optind;

  switch(input_src) {
    case INPUT_FILE:
      if (argc != 1) {
	usage(prog_name);
	exit(2);
      }
      break;
  }

  if (verbose) {
    fprintf(stderr, VERSION);
    fprintf(stderr, "ref build: %d.%d.%d\n", MAJOR, MINOR, REF_BUILD);
    fprintf(stderr, "opening: file@%s\n", argv[0]);
  } else {
    fprintf(stderr, "*** (non-verbose) no data will be displayed\n");
  }

#ifdef notdef
  if (write_data)
    open_files("data/");
#endif

  file_src = open_file_source(argv[0]);
  if (file_src < 0) {
    fprintf(stderr, "*** Couldn't open input file: %s\n", argv[0]);
    perror("error: ");
    exit(1);
  }

  for(;;) {
    dblk_p = read_file_dblk(file_src, &len);
    if (!dblk_p) {
      if (verbose)
	fprintf(stderr, "*** end of stream, terminating\n");
      exit(0);
    }
    if (debug > 1)
      hexprint(dblk_p, len);
    process_dblk(dblk_p);
	break;

      default:
	break;
    }
  }
}
