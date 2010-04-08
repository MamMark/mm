/*
 * rawDump - dump from serial or serial forwarder sensor data.
 *
 * Copyright 2008, 2010 Eric B. Decker
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

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

#include <serialsource.h>
#include <sfsource.h>


int debug	= 0,
    verbose	= 0,
    write_data  = 0,
    raw         = 0;

static void usage(char *name) {
  fprintf(stderr, "usage: %s [-Dv] --serial  <serial device>  <baud rate>\n", name);
  fprintf(stderr, "       %s [-Dv] --sf  <host>  <port>\n", name);
  fprintf(stderr, "       %s [-Dv] -r   <serial device>  <baud rate>\n", name);
  fprintf(stderr, "  -D           increment debugging level\n");
  fprintf(stderr, "  -v           verbose mode (increment)\n");
  fprintf(stderr, "  -r           raw, direct to serial port, all bytes\n");
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


tcflag_t parse_baudrate(int requested) {
  int baudrate;

  switch (requested) {
#ifdef B50
    case 50: baudrate = B50; break;
#endif
#ifdef B75
    case 75: baudrate = B75; break;
#endif
#ifdef B110
    case 110: baudrate = B110; break;
#endif
#ifdef B134
    case 134: baudrate = B134; break;
#endif
#ifdef B150
    case 150: baudrate = B150; break;
#endif
#ifdef B200
    case 200: baudrate = B200; break;
#endif
#ifdef B300
    case 300: baudrate = B300; break;
#endif
#ifdef B600
    case 600: baudrate = B600; break;
#endif
#ifdef B1200
    case 1200: baudrate = B1200; break;
#endif
#ifdef B1800
    case 1800: baudrate = B1800; break;
#endif
#ifdef B2400
    case 2400: baudrate = B2400; break;
#endif
#ifdef B4800
    case 4800: baudrate = B4800; break;
#endif
#ifdef B9600
    case 9600: baudrate = B9600; break;
#endif
#ifdef B19200
    case 19200: baudrate = B19200; break;
#endif
#ifdef B38400
    case 38400: baudrate = B38400; break;
#endif
#ifdef B57600
    case 57600: baudrate = B57600; break;
#endif
#ifdef B115200
    case 115200: baudrate = B115200; break;
#endif
#ifdef B230400
    case 230400: baudrate = B230400; break;
#endif
#ifdef B460800
    case 460800: baudrate = B460800; break;
#endif
#ifdef B500000
    case 500000: baudrate = B500000; break;
#endif
#ifdef B576000
    case 576000: baudrate = B576000; break;
#endif
#ifdef B921600
    case 921600: baudrate = B921600; break;
#endif
#ifdef B1000000
    case 1000000: baudrate = B1000000; break;
#endif
#ifdef B1152000
    case 1152000: baudrate = B1152000; break;
#endif
#ifdef B1500000
    case 1500000: baudrate = B1500000; break;
#endif
#ifdef B2000000
    case 2000000: baudrate = B2000000; break;
#endif
#ifdef B2500000
    case 2500000: baudrate = B2500000; break;
#endif
#ifdef B3000000
    case 3000000: baudrate = B3000000; break;
#endif
#ifdef B3500000
    case 3500000: baudrate = B3500000; break;
#endif
#ifdef B4000000
    case 4000000: baudrate = B4000000; break;
#endif
    default:
      baudrate = 0;
    }
  return baudrate;
}


typedef enum {
  INPUT_SERIAL = 1,
  INPUT_SF     = 2,
  INPUT_RAW    = 3,
} input_src_t;


/* options descriptor */
static struct option longopts[] = {
  { "sf",	no_argument,	NULL, 1 },
  { "serial",	no_argument,	NULL, 2 },
  { NULL,	0,		NULL, 0 }
};

serial_source   serial_src;
int		sf_src;		/* fd for serial forwarder server */
int             raw_fd;

int 
main(int argc, char **argv) {
  int i;
  uint8_t *packet;
  char *prog_name;
  int len;
  int c, bail;
  input_src_t input_src;
  struct termios newtio;
  tcflag_t baudflag;
  int cnt;
  uint8_t *buf;

  serial_src = NULL;
  sf_src = 0;
  input_src = INPUT_RAW;
  bail = 0;
  prog_name = basename(argv[0]);
  while ((c = getopt_long(argc, argv, "Dvr", longopts, NULL)) != EOF) {
    switch (c) {
      case 1:
	bail = 1;
	input_src = INPUT_SF;
	break;
      case 2:
	bail = 1;
	input_src = INPUT_SERIAL;
	break;
      case 'D':
	debug++;
	break;
      case 'v':
	verbose++;
	break;
      case 'r':
	raw++;
	input_src = INPUT_RAW;
	break;
      default:
	usage(prog_name);
    }
    if (bail)
      break;
  }
  argc -= optind;
  argv += optind;

  if (argc != 2) {
    usage(prog_name);
    exit(2);
  }

  if (input_src == INPUT_RAW) {
    baudflag = parse_baudrate(platform_baud_rate(argv[1]));
    if (!baudflag) {
      fprintf(stderr, "couldn't figure out the baud rate\n");
      exit(2);
    }
    raw_fd = open(argv[0], O_RDWR | O_NOCTTY);
    if (raw_fd < 0)
      exit(2);

    /* Serial port setting */
    memset(&newtio, 0, sizeof(newtio));
    newtio.c_cflag = CS8 | CLOCAL | CREAD;
    newtio.c_iflag = IGNPAR | IGNBRK;
    cfsetispeed(&newtio, baudflag);
    cfsetospeed(&newtio, baudflag);

    /* Raw output_file */
    newtio.c_oflag = 0;

    if (tcflush(raw_fd, TCIFLUSH) >= 0 && tcsetattr(raw_fd, TCSANOW, &newtio) >= 0) {
      buf = malloc(256);
      while(1) {
	cnt = read(raw_fd, buf, 1);
	if (cnt == 0)
	  continue;
	fprintf(stderr, "%02x ", buf[0]);
      }
    } else
      close(raw_fd);
    exit(0);
  }

  switch(input_src) {
    case INPUT_SERIAL:
      serial_src = open_serial_source(argv[0], platform_baud_rate(argv[1]), 0, stderr_msg);
      if (!serial_src) {
	fprintf(stderr, "*** Couldn't open serial port at %s:%s\n", argv[0], argv[1]);
	perror("error: ");
	exit(1);
      }
      break;

    case INPUT_SF:
      sf_src = open_sf_source(argv[0], atoi(argv[1]));
      if (sf_src < 0) {
	fprintf(stderr, "*** Couldn't open serial forwarder at %s:%s\n", argv[0], argv[1]);
	perror("error: ");
	exit(1);
      }
      break;

    default:
      fprintf(stderr, "shouldn't be here\n");
      exit(1);
  }
  for(;;) {
    switch(input_src) {
      case INPUT_SERIAL:
	packet = read_serial_packet(serial_src, &len);
	break;

      case INPUT_SF:
	packet = read_sf_packet(sf_src, &len);
	break;

      default:
	fprintf(stderr, "shouldn't be here\n");
	exit(1);
    }
    if (!packet)
      exit(0);

    for (i = 0; i < len; i++)
      fprintf(stderr, "%02x ", packet[i]);
    fprintf(stderr, "\n");
    free((void *)packet);
  }
}
