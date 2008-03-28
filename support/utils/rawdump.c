/*
 * rawDump - dump from serial or serial forwarder sensor data.
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

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

int debug	= 0,
    verbose	= 0,
    write_data  = 0,
    raw         = 0;

static void usage(char *name) {
  fprintf(stderr, "usage: %s [-Dv] --serial  <serial device>  <baud rate>\n", name);
  fprintf(stderr, "       %s [-Dv] --sf  <host>  <port>\n", name);
  fprintf(stderr, "  -D           increment debugging level\n");
  fprintf(stderr, "  -v           verbose mode (increment)\n");
  exit(2);
}

#ifdef notdef
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
#endif


#ifdef notdef
void stderr_msg(serial_source_msg problem) {
  fprintf(stderr, "Note: %s\n", msgs[problem]);
}
#endif

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

/* options descriptor */
static struct option longopts[] = {
  { "sf",	no_argument,	NULL, 1 },
  { "serial",	no_argument,	NULL, 2 },
  { NULL,	0,		NULL, 0 }
};

int 
main(int argc, char **argv) {
  char *prog_name;
  int c, use_serial, bail;
  struct termios newtio;
  int fd;
  tcflag_t baudflag;
  int cnt;
  uint8_t *buf;

  use_serial = 1;
  bail = 0;
  prog_name = basename(argv[0]);
  while ((c = getopt_long(argc, argv, "Dv", longopts, NULL)) != EOF) {
    switch (c) {
      case 1:
	bail = 1;
	use_serial = 0;
	break;
      case 2:
	bail = 1;
	use_serial = 1;
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
  
  if (argc != 2) {
    usage(prog_name);
    exit(2);
  }

  baudflag = parse_baudrate(atoi(argv[1]));
  if (!baudflag)
    exit(2);

//    fd = open(argv[0], O_RDWR | O_NOCTTY | O_NONBLOCK);
  fd = open(argv[0], O_RDWR | O_NOCTTY);
  if (fd < 0)
    exit(2);

  /* Serial port setting */
  memset(&newtio, 0, sizeof(newtio));
  newtio.c_cflag = CS8 | CLOCAL | CREAD;
  newtio.c_iflag = IGNPAR | IGNBRK;
  cfsetispeed(&newtio, baudflag);
  cfsetospeed(&newtio, baudflag);

  /* Raw output_file */
  newtio.c_oflag = 0;

  if (tcflush(fd, TCIFLUSH) >= 0 &&
      tcsetattr(fd, TCSANOW, &newtio) >= 0) {
    buf = malloc(256);
    while(1) {
      cnt = read(fd, buf, 1);
      if (cnt == 0)
	continue;
      fprintf(stderr, "%02x ", buf[0]);
    }
  } else
    close(fd);
  exit(0);
}
