/*
 * mmping - ping a tag, look for result
 *
 * Copyright 2010-2011 Eric B. Decker
 * Copyright      2011 Carl W. Davis
 * Mam-Mark Project
 *
 * @author Eric B. Decker
 * @author Carl W. Davis
 */

#include <stdio.h>
#include <errno.h>
#include <getopt.h>
#include <libgen.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>
#include <sys/time.h>

#include <netlib.h>
#include <motenet.h>
#include <am.h>
#include <am_types.h>

#include "gCmdIDs.h"
#include "mmCmd.h"


#define MAX_PACKET_SIZE 256

#define VERSION "mmping: v0.75  (23 Feb 2011) motenet\n"

int debug	= 0,
  verbose	= 0,
  quiet         = 0;

uint16_t timeout;


uint16_t	count;
uint16_t	sent_pkts, recv_pkts;
int		sockfd;			/* socket file descriptor */
char	       *prog_name;


static void usage() {
  fprintf(stderr, VERSION);
  fprintf(stderr, "usage: %s [-c count] [-t timeout] [-Dvq] <conn_str>\n\n", prog_name);
  fprintf(stderr, "  -c   set count, defaults to 5\n");
  fprintf(stderr, "  -t   set per packet timeout in secs, defaults to 1 secs\n");
  fprintf(stderr, "  -D   increment debugging level\n");
  fprintf(stderr, "         1 - basic debugging, 2 - dump packet data\n");
  fprintf(stderr, "  -v   verbose mode (increment)\n");
  fprintf(stderr, "  -q   quiet\n");
  exit(2);
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
  uint8_t  tx_size;
  uint8_t  buff[MAX_PACKET_SIZE];
  tmsg_t  *msg;
  int      sent;

  tx_packet = buff;
  tx_size = MM_CMD_SIZE;
  msg = new_tmsg(&tx_packet[0], MAX_PACKET_SIZE);

  sent_pkts++;
  mm_cmd_len_set(msg, MM_CMD_SIZE);	     /* set length */
  mm_cmd_cmd_set(msg, CMD_PING);	     /* send a ping command */
  mm_cmd_seq_set(msg, (uint8_t) sent_pkts);  /* sequence number */
  
  sent = mn_send(sockfd, tx_packet, tx_size, 0);
  if (sent == -1) {
    perror("mn_sendto");
    exit(1);
  }
  if (sent != tx_size) {
    fprintf(stderr, "%s: did not send full packet, sent %d",prog_name, sent);
    exit(1);
  }
  fprintf(stderr, "%s: success sending %d bytes\n", prog_name, sent);
}


void finish(void) {
  if (!quiet)
    fprintf(stderr, "\n");
  fprintf(stderr, "sent: %d, recv: %d, %d percent\n", sent_pkts, recv_pkts, (recv_pkts*100)/sent_pkts);
  exit(0);
}


void alarm_catcher(void) {
  if (sent_pkts) {
    /*
     * if sent non-zero then we have an outstanding packet and
     * have timed out.  Display failure indicator and send next
     * packet.
     */
    if (!quiet)
      fprintf(stderr, ".");
  }
  if (sent_pkts >= count) {
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
  int              c, err, direct;
  int              recvbytes;
  uint8_t          rbuf[MAX_PACKET_SIZE];
//  char             buff[256];
  char             *p;
  motecom_conn_t   mcs_conn;
  struct sockaddr *localp,    *remotep;
  struct sockaddr  local_addr, remote_addr;
  socklen_t        local_len,  remote_len;
  struct sockaddr_am *am_l;

  direct = 0;
  count = 5;
  timeout = 1;
  quiet = 0;
  sent_pkts = recv_pkts = 0;
  prog_name = basename(argv[0]);

  while ((c = getopt_long(argc, argv, "c:t:dvq", NULL, NULL)) != EOF) {
    switch (c) {
      case 'c':
	count = atoi(optarg);
	break;
      case 't':
	timeout = atoi(optarg);
	break;
      case 'd':
	debug++;
	break;
      case 'v':
	verbose++;
	break;
      case 'q':
	quiet++;
	break;
      default:
	usage();
    }
  }
  argc -= optind;
  argv += optind;

  /*
   * at this point we have pulled any option switches off and should be left with either 1 or 2
   * arguments.   If not bitch and bail.
   */
  if (argc < 1 || argc > 2)
    usage();

#ifdef notdef
  if (verbose) {
    fprintf(stderr, VERSION);
    /*
    switch (conn) {
      case SERIAL_CONN:
	fprintf(stderr, "opening: serial@%s:%d\n", argv[0], platform_baud_rate(argv[1]));
	break;
      case SF_CONN:
	fprintf(stderr, "opening: sf@%s:%d\n", argv[0], atoi(argv[1]));
	break;
    }
    */
  }
#endif

  if (!quiet) {
    fprintf(stderr, "sending %d pings, timeout: %d secs\n", count, timeout);
  }

  set_signal(SIGINT, finish);
  set_signal(SIGALRM, alarm_catcher);

  debug++;

  p = argv[0];
  mn_debug_set(debug);
  if (mn_parse_motecom(&mcs_conn, p)) {
    fprintf(stderr, "\nCmd Line/MOTECOM connection string didn't parse\n");
    fprintf(stderr, "Command line: \"%s\"\n", p);
    p = getenv("MOTECOM");
    fprintf(stderr, "MOTECOM: \"%s\"\n\n", (p ? p : "not found"));
    usage();
  }

  //fprintf(stderr, "Connecting: %s\n", mn_mcs2str(&mcs_conn, buff, 256));

  /*
   * direct has only one parameter and we ping that directly.
   * what do we do for the local address side?
   *
   * if through a server or via a serial amgw then we will have two parameters and the
   * first will be a connection string saying how to get to the amgw.   The second parameter
   * will then be strictly an am endpoint (amaddr:amport).
   *
   * Also what do we do for setting our local am_addr?
   * For the time being we force it to be node 1.
   *
   * argc tells the story, if argc is 2 (1 arg) then should be direct
   * if argc is 3 (2 args) then argv[1] is connection string and argv[2]
   * is the am_endpoint.
   */

  remotep = &remote_addr;
  remote_len = sizeof(remote_addr);

  localp = &local_addr;
  am_l = (struct sockaddr_am *) localp;
  am_l->sam_family = AF_AM;
  am_l->sam_addr   = htons(0x0001);
  am_l->sam_grp    = AM_GRP_ANY;
  am_l->sam_type   = AM_MM_CONTROL;	/* mm_control port */
  local_len = sizeof(struct sockaddr_am);

  if (argc == 1) {
    /*
     * Direct connect case.   So destination is the same as the connection
     * string result.
     */
    remotep = mcs_conn.ai->ai_addr;
    remote_len = mcs_conn.ai->ai_addrlen;
    direct = 1;
  } else {
    /*
     * we have a connection string (already parsed into mcs_conn) and we have
     * an am_endpoint (am_addr:am_port).  Parse that and set it as dest.
     */
    direct = 0;
    exit(1);
  }

  sockfd = mn_socket(&mcs_conn, remotep->sa_family, SOCK_DGRAM, 0);
  if (sockfd < 0) {
    fprintf(stderr, "%s: mn_socket: %s (%d)\n", prog_name, strerror(errno), errno);
    exit(1);
  }

  if (!direct) {
    /*
     * If using an AMGW, we must always bind the local address because that
     * forces the type for the entire connection.
     *
     * If direct, then let the underlying kernel chose the local port.
     */
    err = mn_bind(sockfd, localp, local_len);
    if (err) {
      fprintf(stderr, "%s: mn_bind: %s (%d)\n", prog_name, strerror(errno), errno);
      exit(1);
    }
  }

  /* set remote address */
  err = mn_connect(sockfd, remotep, remote_len);
  if (err) {
    fprintf(stderr, "%s: mn_connect: %s (%d)\n", prog_name, strerror(errno), errno);
    exit(1);
  }

  /*
   * call the alarm_catcher as if we timed out to start things off
   */
  alarm_catcher();               /* setup timer and send packet */

  for(;;) {
    recvbytes = mn_recv(sockfd, rbuf, MAX_PACKET_SIZE, 0);
    if (recvbytes == -1) {
      perror("receive failed");
      exit(1);
    }

    /* how many bytes did we receive, display? */

    if (recvbytes <= 0) {
      if (verbose)
	fprintf(stderr, "*** timeout\n");
      if (!quiet)
	fprintf(stderr, ".");
      continue;
    }
    if (sent_pkts >= count)
      finish();
    send_pack();
    alarm(timeout);
  }

  mn_close(sockfd);
  exit(0);
}
