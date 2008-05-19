/*
 * mm3dump - dump mm3 data, debug, or control stream from
 * file, serial, or serial forwarder.
 *
 * Copyright 2008 Eric B. Decker
 * Mam-Mark Project
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <ctype.h>
#include <getopt.h>
#include <libgen.h>
#include <string.h>
#include <time.h>

#include <serialsource.h>
#include <sfsource.h>
#include <message.h>
#include "filesource.h"
#include "serialpacket.h"
#include "serialprotocol.h"
#include "mm3DataMsg.h"
#include "SensorConstants.h"
#include "SDConstants.h"
#include "DtIgnoreMsg.h"
#include "DtSyncMsg.h"
#include "DtPanicMsg.h"
#include "DtSensorDataMsg.h"
#include "DtVersionMsg.h"

#define VERSION "mm3dump: v0.7 185 May 2008\n"

int debug	= 0,
    verbose	= 0,
    write_data  = 0;

static void usage(char *name) {
  fprintf(stderr, VERSION);
  fprintf(stderr, "usage: %s [-Dv] --serial  <serial device>  <baud rate>\n", name);
  fprintf(stderr, "       %s [-Dv] --sf  <host>  <port>\n", name);
  fprintf(stderr, "       %s [-Dv] [-f][--file] <input file>\n", name);
  fprintf(stderr, "  -D   increment debugging level\n");
  fprintf(stderr, "  -v   verbose mode (increment)\n");
  fprintf(stderr, "  -d   write data files for each sensor\n");
  fprintf(stderr, "  -f   take input from <input file>\n");
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


FILE *fp[MM3_NUM_SENSORS];

void stderr_msg(serial_source_msg problem) {
  fprintf(stderr, "*** Note: %s\n", msgs[problem]);
}


/*
 * sns_payload_len: allows an easy conversion from sensor id
 * to how many bytes in the payload.
 */

uint8_t sns_payload_len[MM3_NUM_SENSORS] = {
  0,				/* not used */
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
    case DT_SYNC_RESTART:return("sync_restart");
    case DT_PANIC:	return("panic");
    case DT_GPS_TIME:	return("gps_time");
    case DT_GPS_POS:	return("gps_pos");
    case DT_SENSOR_DATA:return("sensor_data");
    case DT_SENSOR_SET:	return("sensor_set");
    case DT_TEST:	return("test");
    case DT_CAL_STRING:	return("cal_string");
    case DT_GPS_RAW:	return("gps_raw");
    case DT_VERSION:	return("version");
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
  for (i = 1; i < MM3_NUM_SENSORS; i++) {
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
hexprint(uint8_t *ptr, int len) {
  int i;

  for (i = 0; i < len; i++) {
    if ((i % 16) == 0) {
      if (i == 0)
	fprintf(stderr, "\n*** ");
      else
	fprintf(stderr, "\n    ");
    }
    fprintf(stderr, "%02x ", ptr[i]);
  }
  fprintf(stderr, "\n");
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


/*
 * Make sure this matches the defines in sd_block.h
 * we don't share header files but rather rely on ncg
 * to extract enums but if we make these enums they
 * are too big and generate an ISO C90 warning.  Screw
 * it.  They aren't likely to change so we #define them.
 */
#define SYNC_MAJIK 0xdedf00ef
#define SYNC_RESTART_MAJIK 0xdaffd00f

void
process_sync(tmsg_t *msg) {
  int i;
  uint16_t len;
  uint8_t dtype;
  uint32_t stamp;
  uint32_t majik;
  uint8_t c;
  char *s;

  len = dt_sync_len_get(msg);
  dtype = dt_sync_dtype_get(msg);
  stamp = dt_sync_stamp_mis_get(msg);
  majik = dt_sync_sync_majik_get(msg);
  switch (majik) {
    case SYNC_MAJIK:
      c = 'S';
      s = "sync";
      break;

    case SYNC_RESTART_MAJIK:
      c = 'R';
      s = "restart";
      break;

    default:
      c = '?';
      s = "unknown";
      break;
  }
  if (verbose) {
    printf("SYNC: %c %d (%x) %08x (%s)\n",
	   c, stamp, stamp, majik, s);
  }
  if (write_data) {
    for (i = 0; i < MM3_NUM_SENSORS; i++) {
      fprintf(fp[i], "%% SYNC: %c %d %08x %s\n",
	      c, stamp, majik, s);
    }
  }
}

void
process_panic(tmsg_t *msg) {
  uint32_t stamp_mis;
  uint8_t  pcode;
  uint8_t  where;
  uint16_t arg0;
  uint16_t arg1;
  uint16_t arg2;
  uint16_t arg3;

  stamp_mis = dt_panic_stamp_mis_get(msg);
  pcode     = dt_panic_pcode_get(msg);
  where     = dt_panic_where_get(msg);
  arg0      = dt_panic_arg0_get(msg);
  arg1      = dt_panic_arg1_get(msg);
  arg2      = dt_panic_arg2_get(msg);
  arg3      = dt_panic_arg3_get(msg);
  printf("*** PANIC:  %u pcode: %02x  where: %02x  %04x %04x %04x %04x\n",
	 stamp_mis, pcode, where, arg0, arg1, arg2, arg3);
}

#ifdef notdef
void
process_gps_time(dt_gps_time_pt *gps_time_p) {
    mm_time_t stamp;
    uint32_t tow;
    float *fp;

    get_packed_time(&stamp, &gps_time_p->stamp);
    if(gps_time_p->dtype == DT_GPS_TIME) {
	tow = CF_LE_32(gps_time_p->gps_tow);
	fp = (float *)(&tow);
        fprintf(stderr, "GPS TIME:  tow: %6.0f, week: %4d(from jan 5, 1980)(%u.%lu.%u)\n",
		*fp, CF_LE_16(gps_time_p->gps_week),
		gps_time_p->stamp.epoch, gps_time_p->stamp.mis, gps_time_p->stamp.ticks);
    }
    else
        fprintf(stderr, "*** unknown gps time block\n");
}


void
process_gps_pos(dt_gps_pos_pt *gps_pos_p) {
    mm_time_t stamp;
    uint32_t lat;
    uint32_t longitude;
    float *fplat;
    float *fplong;
    char nflag;
    char eflag;

    get_packed_time(&stamp, &gps_pos_p->stamp);
    if(gps_pos_p->dtype == DT_GPS_POS ) {
        lat = CF_LE_32(gps_pos_p->gps_lat);
        fplat = (float *)(&lat);
        if(fplat > 0) {
            *fplat = *fplat * 57.2957795;
            nflag = 'N';
        }
        else {
            *fplat = *fplat * -1.0 * 57.2957795;
            nflag = 'S';
        }
        longitude = CF_LE_32(gps_pos_p->gps_long);
        fplong = (float *)(&longitude);
        if(fplong < 0) {
            *fplong = *fplong * 57.2957795;
            eflag = 'E';
        }
        else {
            *fplong = *fplong * -1.0 * 57.2957795;
            eflag = 'W';
        }
	fprintf(stderr, "GPS LOC: lat: %6.10f %c, long: %6.10f %c (%u.%lu.%u)\n", 
		*fplat, nflag, *fplong, eflag,
                gps_pos_p->stamp.epoch, gps_pos_p->stamp.mis, gps_pos_p->stamp.ticks); 
    }
    else
       	fprintf(stderr, "*** unknown gps pos block\n");
}


void
process_gps_raw(dt_gps_raw_pt *gps_raw_p) {
    uint16_t i;

    if(gps_raw_p->dtype == DT_GPS_RAW) {
        fprintf(stderr, "GPS RAW: ");
        for (i = 0; i < (gps_raw_p->len - DT_HDR_SIZE_GPS_RAW); i++) {
            fprintf(stderr, "%02x ", gps_raw_p->data[i]);  
        }
        fprintf(stderr, "\n");
    }
    else {
        fprintf(stderr, "Unknown Data Block\n");
    }
}
#endif


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

  sched = dt_sensor_data_sched_mis_get(msg);
  stamp = dt_sensor_data_stamp_mis_get(msg);
  if (verbose) {
    printf("SNS: %-6s (%d) %8u (%04x/%04x, %3d)",
	   snsid2str(sns_id), sns_id, sched, sched, stamp, stamp-sched);
    if (sns_id < MM3_NUM_SENSORS) {
      for (i = 0; i < (sns_payload_len[sns_id]/2); i++)
	printf(" %5d", dt_sensor_data_data_get(msg, i));
      printf("  [ ");
      for (i = 0; i < (sns_payload_len[sns_id]/2); i++)
	printf("%04x ", dt_sensor_data_data_get(msg, i));
      printf("]\n");
    } else
      printf("(unk) %04x\n", dt_sensor_data_data_get(msg, 0));
  }
  if (sns_id > 0 && sns_id < MM3_NUM_SENSORS) {
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
  uint8_t major, minor, tweak;
  int i;

  major = dt_version_major_get(msg);
  minor = dt_version_minor_get(msg);
  tweak = dt_version_tweak_get(msg);
  printf("VER: %d.%d.%d\n", major, minor, tweak);
  if (write_data)
    for (i = 1; i < MM3_NUM_SENSORS; i++)
      fprintf(fp[i], "%% Tag Version: %d.%d.%d\n", major, minor, tweak);
}


void
process_unk_dblk(tmsg_t *msg) {
    fprintf(stderr, "*** unknown dblk: ");
    hexprint(tmsg_data(msg), tmsg_length(msg));
}


void
process_mm3_data(tmsg_t *msg) {
  uint16_t len;
  uint8_t  dtype;

  len = dt_ignore_len_get(msg);
  dtype = dt_ignore_dtype_get(msg);
  if (debug)
    fprintf(stderr, "    len: %0d (%02x)  dtype: %0d (%02x) %s\n", len, len, dtype, dtype, dtype2str(dtype));
  switch (dtype) {
    case DT_IGNORE:
      process_ignore(msg);
      break;
    case DT_CONFIG:
      process_config(msg);
      break;
    case DT_SYNC:
    case DT_SYNC_RESTART:
      process_sync(msg);
      break;
    case DT_PANIC:
      process_panic(msg);
      break;
    case DT_GPS_TIME:
      break;
    case DT_GPS_POS:
      break;
    case DT_SENSOR_DATA:
      process_sensor_data(msg);
      break;
    case DT_SENSOR_SET:
      break;
    case DT_TEST:
      break;
    case DT_CAL_STRING:
      break;
    case DT_GPS_RAW:
      break;
    case DT_VERSION:
      process_version(msg);
      break;
    default:
      process_unk_dblk(msg);
      break;
  }
}


typedef enum {
  INPUT_SERIAL = 1,
  INPUT_SF     = 2,
  INPUT_FILE   = 3,
} input_src_t;
  

/* options descriptor */
static struct option longopts[] = {
  { "sf",	no_argument, NULL, 1 },
  { "serial",	no_argument, NULL, 2 },
  { "file",	no_argument, NULL, 'f' },
  { NULL,	0,	     NULL, 0 }
};

serial_source   serial_src;
int		sf_src;		/* fd for serial forwarder server */
int		file_src;	/* fd for input file */

int 
main(int argc, char **argv) {
  uint8_t *packet;
  char *prog_name;
  int len;
  int c, bail;
  input_src_t input_src;
  tmsg_t *msg;
  uint16_t dest, src;
  uint8_t group;
  uint8_t stype;

  serial_src = NULL;
  sf_src = 0;
  file_src = 0;
  input_src = INPUT_SERIAL;
  bail = 0;
  prog_name = basename(argv[0]);
  while ((c = getopt_long(argc, argv, "Ddvf", longopts, NULL)) != EOF) {
    switch (c) {
      case 1:
	bail = 1;
	input_src = INPUT_SF;
	break;
      case 2:
	bail = 1;
	input_src = INPUT_SERIAL;
	break;
      case 'f':
	bail = 1;
	input_src = INPUT_FILE;
	break;
      case 'd':
	write_data = 1;
	break;
      case 'D':
	debug++;
	break;
      case 'v':
	verbose++;
	break;
      default:
	usage(prog_name);
    }
    if (bail)
      break;
  }
  argc -= optind;
  argv += optind;

  switch(input_src) {
    case INPUT_SERIAL:
    case INPUT_SF:
      if (argc != 2) {
	usage(prog_name);
	exit(2);
      }
      break;

    case INPUT_FILE:
      if (argc != 1) {
	usage(prog_name);
	exit(2);
      }
      break;
  }

  if (verbose) {
    fprintf(stderr, VERSION);
    fprintf(stderr, "arg1: %s  arg2: %s\n", argv[0], argv[1]);
  }

  if (write_data)
    open_files("data/");

  switch(input_src) {
    case INPUT_SERIAL:
      serial_src = open_serial_source(argv[0], platform_baud_rate(argv[1]), 0, stderr_msg);
      if (!serial_src) {
	fprintf(stderr, "*** Couldn't open serial port at %s:%s\n",
		argv[0], argv[1]);
	perror("error: ");
	exit(1);
      }
      break;

    case INPUT_SF:
      sf_src = open_sf_source(argv[0], atoi(argv[1]));
      if (sf_src < 0) {
	fprintf(stderr, "*** Couldn't open serial forwarder at %s:%s\n",
		argv[0], argv[1]);
	perror("error: ");
	exit(1);
      }
      break;

    case INPUT_FILE:
      file_src = open_file_source(argv[0]);
      if (file_src < 0) {
	fprintf(stderr, "*** Couldn't open input file: %s\n", argv[0]);
	perror("error: ");
	exit(1);
      }
      break;
  }

  for(;;) {
    switch(input_src) {
      case INPUT_SERIAL:
	packet = read_serial_packet(serial_src, &len);
	break;

      case INPUT_SF:
	packet = read_sf_packet(sf_src, &len);
	break;

      case INPUT_FILE:
	packet = read_file_packet(file_src, &len);
	break;
    }
    if (!packet)
      exit(0);
    if (debug) {
      fprintf(stderr, "encapsulated pak: ");
      hexprint(packet, len);
    }
    if (len < 1 + SPACKET_SIZE ||
	packet[0] != SERIAL_TOS_SERIAL_ACTIVE_MESSAGE_ID) {
      fprintf(stderr, "*** non-AM packet (type %d, len %d (%0x)): ",
	      packet[0], len, len);
      hexprint(packet, len);
      continue;
    }
    msg = new_tmsg(packet + 1, len - 1);
    if (!msg) {
      fprintf(stderr, "*** new_tmsg failed (null)\n");
      exit(2);
    }
    dest = spacket_header_dest_get(msg);
    src  = spacket_header_src_get(msg);
    len  = spacket_header_length_get(msg);
    group= spacket_header_group_get(msg);
    stype= spacket_header_type_get(msg);
    if (debug) {
      fprintf(stderr, "*** dest %04x, src %04x, len %02x, group %02x, type %02x\n",
	     dest, src, len, group, stype);
    }
    reset_tmsg(msg, ((uint8_t *)tmsg_data(msg)) + SPACKET_SIZE, tmsg_length(msg) - spacket_data_offset(0));
    switch(stype) {
      case MM3_DATA_MSG_AM_TYPE:
	process_mm3_data(msg);
	break;

      default:
	break;
    }
    free_tmsg(msg);
    free((void *)packet);
  }
}
