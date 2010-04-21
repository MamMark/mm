/*
 * mmping - ping a tag, look for result
 *
 * Copyright 2010 Eric B. Decker
 * Mam-Mark Project
 *
 * @author Eric B. Decker
 */

#include <stdio.h>
#include <getopt.h>
#include <libgen.h>
#include <signal.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

#include <serialsource.h>
#include <sfsource.h>
#include "serialpacket.h"
#include "serialprotocol.h"
#include "am_types.h"
#include "gCmdIDs.h"
#include "mmCmd.h"


#define MAX_PACKET_SIZE 256

#define VERSION "mm_ping: v0.1  (19 Apr 2010)\n"

int debug	= 0,
  verbose	= 0,
  quiet         = 0;

uint16_t timeout;

typedef enum {
  SERIAL_CONN = 1,
  SF_CONN     = 2,
} conn_t;
  

/* options descriptor */
static struct option longopts[] = {
  { "sf",	no_argument, NULL, 1 },
  { "serial",	no_argument, NULL, 2 },
  { NULL,	0,	     NULL, 0 }
};

serial_source   serial_conn;
int		sf_conn;		/* fd for serial forwarder server */
conn_t		conn;
uint16_t	count;
uint16_t	sent, recv;


static void usage(char *name) {
  fprintf(stderr, VERSION);
  fprintf(stderr, "usage: %s [-c count] [-t timeout] [-Dvq] --serial  <serial device>  <baud rate>\n", name);
  fprintf(stderr, "       %s [-c count] [-t timeout] [-Dvq] --sf  <host>  <port>\n\n", name);
  fprintf(stderr, "  -c   set count, defaults to 5\n");
  fprintf(stderr, "  -t   set per packet timeout in secs, defaults to 1 secs\n");
  fprintf(stderr, "  -D   increment debugging level\n");
  fprintf(stderr, "         1 - basic debugging, 2 - dump packet data\n");
  fprintf(stderr, "  -v   verbose mode (increment)\n");
  fprintf(stderr, "  -q   quiet\n");
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


void set_signal(int signo, void (*handler)(void)) {
  struct sigaction sa;

  memset(&sa, 0, sizeof(sa));
  sa.sa_handler = (void (*)(int))handler;
  sa.sa_flags = SA_RESTART;
  sigaction(signo, &sa, NULL);
}


#ifdef notdef
void set_deadline(struct timeval *deadline) {
  gettimeofday(deadline, NULL);
  deadline->tv_sec += timeout;
}
#endif


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


void send_pack(void) {
  uint8_t *tx_packet;
  uint8_t tx_size;
  uint8_t buff[MAX_PACKET_SIZE];
  tmsg_t *msg;

  tx_packet = buff;
  tx_size = SPACKET_SIZE + MM_CMD_SIZE;
  msg = new_tmsg(&tx_packet[SPACKET_SIZE], MAX_PACKET_SIZE - SPACKET_SIZE);
  mm_cmd_len_set(msg, MM_CMD_SIZE);
  mm_cmd_cmd_set(msg, CMD_PING);
  mm_cmd_seq_set(msg, (uint8_t) sent);

  reset_tmsg(msg, ((uint8_t *) tmsg_data(msg)) - SPACKET_SIZE,
	     tmsg_length(msg) + spacket_data_offset(0));
  spacket_header_dispatch_set(msg, SERIAL_TOS_SERIAL_ACTIVE_MESSAGE_ID);
  spacket_header_dest_set(msg, 0xffff);
  spacket_header_src_set(msg, 1);
  spacket_header_length_set(msg, MM_CMD_SIZE);
  spacket_header_group_set(msg, 0);
  spacket_header_type_set(msg, AM_MM_CONTROL);
  sent++;
  switch(conn) {
    case SERIAL_CONN:
      write_serial_packet(serial_conn, tx_packet, tx_size);
      break;

    case SF_CONN:
      write_sf_packet(sf_conn, tx_packet, tx_size);
      break;
  }
}


void finish(void) {
  if (!quiet)
    fprintf(stderr, "\n");
  fprintf(stderr, "sent: %d, recv: %d, %d percent\n", sent, recv, (recv*100)/sent);
  exit(0);
}


void alarm_catcher(void) {
  if (sent) {
    /*
     * if sent non-zero than we have an outstanding packet and
     * have timed out.  Display failure indicator and send next
     * packet.
     */
    if (!quiet)
      fprintf(stderr, ".");
  }
  if (sent >= count) {
    /*
     * already sent the max requested.
     */
    finish();
  }
  send_pack();
  alarm(timeout);
}


int 
main(int argc, char **argv) {
  uint8_t *rx_packet;
  char *prog_name;
  int len;
  int c, bail;
  tmsg_t *msg;
  uint16_t dest, src;
  uint8_t group;
  uint8_t stype;

  serial_conn = NULL;
  sf_conn = 0;
  conn = SERIAL_CONN;
  bail = 0;
  count = 5;
  timeout = 1;
  sent = recv = 0;
  quiet = 0;
  prog_name = basename(argv[0]);
  while ((c = getopt_long(argc, argv, "c:t:Ddvq", longopts, NULL)) != EOF) {
    switch (c) {
      case 1:
	bail = 1;
	conn = SF_CONN;
	break;
      case 2:
	bail = 1;
	conn = SERIAL_CONN;
	break;
      case 'c':
	count = atoi(optarg);
	break;
      case 't':
	timeout = atoi(optarg);
	break;
      case 'D':
	debug++;
	break;
      case 'v':
	verbose++;
	break;
      case 'q':
	quiet++;
	break;
      default:
	usage(prog_name);
    }
    if (bail)
      break;
  }
  argc -= optind;
  argv += optind;

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
      serial_conn = open_serial_source(argv[0], platform_baud_rate(argv[1]), 0, stderr_msg);
      if (!serial_conn) {
	fprintf(stderr, "*** Couldn't open serial port at %s:%s\n",
		argv[0], argv[1]);
	perror("error: ");
	exit(1);
      }
      break;

    case SF_CONN:
      sf_conn = open_sf_source(argv[0], atoi(argv[1]));
      if (sf_conn < 0) {
	fprintf(stderr, "*** Couldn't open serial forwarder at %s:%s\n",
		argv[0], argv[1]);
	perror("error: ");
	exit(1);
      }
      break;
  }

  if (!quiet) {
    fprintf(stderr, "sending %d pings, timeout: %d secs\n", count, timeout);
  }

  set_signal(SIGINT, finish);
  set_signal(SIGALRM, alarm_catcher);

  /*
   * call the alarm_catcher as if we timed out to start things off
   */
  alarm_catcher();

  for(;;) {
    switch(conn) {
      case SERIAL_CONN:
	rx_packet = read_serial_packet(serial_conn, &len);
	break;

      case SF_CONN:
	rx_packet = read_sf_packet(sf_conn, &len);
	break;
    }
    if (!rx_packet) {
      if (verbose)
	fprintf(stderr, "*** timeout\n");
      if (!quiet)
	fprintf(stderr, ".");
      continue;
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
    if (!quiet)
      fprintf(stderr, "!");
    recv++;
    free_tmsg(msg);
    free((void *) rx_packet);
    if (sent >= count)
      finish();
    send_pack();
    alarm(timeout);
  }
  exit(0);
}
