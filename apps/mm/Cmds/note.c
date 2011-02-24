/*
 * mmnote - write a time stamped note to the tag.  Will go into the
 * data store.
 *
 * Copyright 2010 Eric B. Decker
 * Mam-Mark Project
 *
 * @author Eric B. Decker
 */

#include <stdio.h>
#include <getopt.h>
#include <libgen.h>
#include <string.h>
#include <time.h>

#include <serialsource.h>
#include <sfsource.h>
#include <am_types.h>
#include "serialpacket.h"
#include "serialprotocol.h"
#include "gCmdIDs.h"
#include "mmCmd.h"
#include "mmCmdNote.h"


#define MAX_PACKET_SIZE 256

#define VERSION "mm_note: v0.1  (19 Apr 2010)\n"

int debug	= 0,
    verbose	= 0;

static void usage(char *name) {
  fprintf(stderr, VERSION);
  fprintf(stderr, "usage: %s [-Dv] -n<note> --serial  <serial device>  <baud rate>\n", name);
  fprintf(stderr, "       %s [-Dv] -n<note> --sf  <host>  <port>\n", name);
  fprintf(stderr, "  -D   increment debugging level\n");
  fprintf(stderr, "         1 - basic debugging, 2 - dump packet data\n");
  fprintf(stderr, "  -v   verbose mode (increment)\n");
  fprintf(stderr, "  -n or --note\n");
  fprintf(stderr, "       specify the note string to write (required)\n");
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


void stderr_msg(serial_source_msg problem) {
  fprintf(stderr, "*** Note: %s\n", msgs[problem]);
}


void
hexprint(uint8_t *ptr, int len) {
  int i;

  for (i = 0; i < len; i++) {
    if ((i % 32) == 0) {
      if (i == 0)
	fprintf(stderr, "*** ");
      else
	fprintf(stderr, "\n    ");
    }
    fprintf(stderr, "%02x ", ptr[i]);
  }
  fprintf(stderr, "\n");
}


typedef enum {
  SERIAL_CONN = 1,
  SF_CONN     = 2,
} conn_t;
  

/* options descriptor */
static struct option longopts[] = {
  { "sf",	no_argument,       NULL, 1   },
  { "serial",	no_argument,       NULL, 2   },
  { "note",     required_argument, NULL, 'n' },
  { NULL,	0,	     NULL, 0 }
};

serial_source   serial_src;
int		sf_src;		/* fd for serial forwarder server */


int 
main(int argc, char **argv) {
  uint8_t *rx_packet;
  char *prog_name;
  int len;
  int c, bail;
  conn_t conn;
  tmsg_t *msg;
  uint16_t dest, src;
  uint8_t group;
  uint8_t stype;

  uint8_t *tx_packet;
  uint8_t  tx_size;
  uint8_t  note_size;
  uint8_t  buff[MAX_PACKET_SIZE];
  time_t   now;
  struct tm *now_tm;

  /*
   * packet format:
   *
   * serial header | cmd header | note header | note
   *       8             3            8           n
   */
  tx_packet = buff;
  tx_size = SPACKET_SIZE + MM_CMD_SIZE + MM_CMD_NOTE_SIZE;
  note_size = 0;

  serial_src = NULL;
  sf_src = 0;
  conn = SERIAL_CONN;
  bail = 0;
  prog_name = basename(argv[0]);
  while ((c = getopt_long(argc, argv, "Dvn:", longopts, NULL)) != EOF) {
    switch (c) {
      case 1:
	bail = 1;
	conn = SF_CONN;
	break;
      case 2:
	bail = 1;
	conn = SERIAL_CONN;
	break;
      case 'n':
	note_size = strlen(optarg);
	strcpy((char *) &buff[tx_size], optarg);
	tx_size += note_size;
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

  if (!note_size) {
    fprintf(stderr, "\n*** -n or --note must be specified to denote note string\n\n");
    usage(prog_name);
    exit(2);
  }

  switch(conn) {
    case SERIAL_CONN:
    case SF_CONN:
      if (argc != 2) {
	usage(prog_name);
	exit(2);
      }
      break;
  }

  if (verbose) {
    fprintf(stderr, VERSION);
    switch (conn) {
      case SERIAL_CONN:
	fprintf(stderr, "opening: serial@%s:%d\n", argv[0], platform_baud_rate(argv[1]));
	break;
      case SF_CONN:
	fprintf(stderr, "opening: sf@%s:%d\n", argv[0], atoi(argv[1]));
	break;
    }
  }

  switch(conn) {
    case SERIAL_CONN:
      serial_src = open_serial_source(argv[0], platform_baud_rate(argv[1]), 0, stderr_msg);
      if (!serial_src) {
	fprintf(stderr, "*** Couldn't open serial port at %s:%s\n",
		argv[0], argv[1]);
	perror("error: ");
	exit(1);
      }
      break;

    case SF_CONN:
      sf_src = open_sf_source(argv[0], atoi(argv[1]));
      if (sf_src < 0) {
	fprintf(stderr, "*** Couldn't open serial forwarder at %s:%s\n",
		argv[0], argv[1]);
	perror("error: ");
	exit(1);
      }
      break;
  }

  /*
   * start out pointing at the mm_cmd_note header.
   * Data for the note was filled in during cmd line option
   * processing.
   */
  msg = new_tmsg(&tx_packet[SPACKET_SIZE + MM_CMD_SIZE],
		 MAX_PACKET_SIZE - MM_CMD_SIZE - SPACKET_SIZE);
  now = time(NULL);
  now_tm = localtime(&now);
  fprintf(stderr, "current time: %s\n", ctime(&now));
  mm_cmd_note_year_set(msg,  now_tm->tm_year + 1900);
  mm_cmd_note_month_set(msg, now_tm->tm_mon + 1);
  mm_cmd_note_day_set(msg,   now_tm->tm_mday);
  mm_cmd_note_hrs_set(msg,   now_tm->tm_hour);
  mm_cmd_note_min_set(msg,   now_tm->tm_min);
  mm_cmd_note_sec_set(msg,   now_tm->tm_sec);
  mm_cmd_note_len_set(msg,   note_size);

  /*
   * now move back to the cmd
   */
  reset_tmsg(msg, ((uint8_t *) tmsg_data(msg)) - MM_CMD_SIZE,
	     tmsg_length(msg) + mm_cmd_data_offset(0));
  mm_cmd_len_set(msg, MM_CMD_SIZE + MM_CMD_NOTE_SIZE + note_size);
  mm_cmd_cmd_set(msg, CMD_WR_NOTE);
  mm_cmd_seq_set(msg, 0);

  reset_tmsg(msg, ((uint8_t *) tmsg_data(msg)) - SPACKET_SIZE,
	     tmsg_length(msg) + spacket_data_offset(0));
  spacket_header_dispatch_set(msg, SERIAL_TOS_SERIAL_ACTIVE_MESSAGE_ID);
  spacket_header_dest_set(msg, 0xffff);
  spacket_header_src_set(msg, 1);
  spacket_header_length_set(msg, MM_CMD_SIZE + MM_CMD_NOTE_SIZE + note_size);
  spacket_header_group_set(msg, 0);
  spacket_header_type_set(msg, AM_MM_CONTROL);
  switch(conn) {
    case SERIAL_CONN:
      write_serial_packet(serial_src, tx_packet, tx_size);
      break;

    case SF_CONN:
      write_serial_packet(serial_src, tx_packet, tx_size);
      break;
  }
  for(;;) {
    switch(conn) {
      case SERIAL_CONN:
	rx_packet = read_serial_packet(serial_src, &len);
	break;

      case SF_CONN:
	rx_packet = read_sf_packet(sf_src, &len);
	break;
    }
    if (!rx_packet) {
      if (verbose)
	fprintf(stderr, "*** end of stream, terminating\n");
      exit(0);
    }
    msg = new_tmsg(rx_packet, len);
    if (!msg) {
      fprintf(stderr, "*** new_tmsg failed (null)\n");
      exit(2);
    }
    c = spacket_header_dispatch_get(msg);
    if (len < SPACKET_SIZE || c != SERIAL_TOS_SERIAL_ACTIVE_MESSAGE_ID) {
      fprintf(stderr, "*** non-AM packet (type %d, len %d (%0x)): ",
	      rx_packet[0], len, len);
      hexprint(rx_packet, len);
      continue;
    }
    if (debug > 1)
      hexprint(rx_packet, len);
    dest = spacket_header_dest_get(msg);
    src  = spacket_header_src_get(msg);
    len  = spacket_header_length_get(msg);
    group= spacket_header_group_get(msg);
    stype= spacket_header_type_get(msg);

    /*
     * move over serial header
     */
    reset_tmsg(msg, ((uint8_t *) tmsg_data(msg)) + SPACKET_SIZE,
	       tmsg_length(msg) - spacket_data_offset(0));
    free_tmsg(msg);
    free((void *) rx_packet);
  }
}
