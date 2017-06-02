/* Carl W. Davis, 2/19/11
 * Test of C coded ping.c
 */

#include <stdio.h>
#include <getopt.h>
#include <libgen.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>

#include <netlib.h>
#include <motenet.h>

#define SERVERPORT "50007"

motecom_conn_t mcs_conn;

int main(int argc, char *argv[]) {
  int sockfd;
  int sendbytes, recvbytes, buf_len;
  char *prog_name;
  uint8_t rbuf[2048];		/* for now max is 2048 */
  uint8_t sbuf[2048];
  char    buff[256], *p;
  struct sockaddr *who,     *dest;
  struct sockaddr  who_addr;
  socklen_t        who_len,  dest_len;

  prog_name = basename(argv[0]);
  if (argc != 3) {
    fprintf(stderr,"usage: %s conn_str message\n", prog_name);
    exit(1);
  }
  p = argv[1];

  mn_debug_set(1);
  if (mn_parse_motecom(&mcs_conn, p)) {
    fprintf(stderr, "\nCmd Line/MOTECOM connection string didn't parse\n");
    fprintf(stderr, "Command line: \"%s\"\n", p);
    p = getenv("MOTECOM");
    fprintf(stderr, "MOTECOM: \"%s\"\n\n", (p ? p : "not found"));
//    usage(prog_name);
  }

  fprintf(stderr, "Connecting: %s\n", mn_mcs2str(&mcs_conn, buff, 256));

  sockfd = mn_socket(&mcs_conn, AF_INET, SOCK_DGRAM, 0);
  if (sockfd < 0) {
    fprintf(stderr, "%s: mn_socket: %s (%d)\n", prog_name, strerror(errno), errno);
    exit(1);
  }

  dest = mcs_conn.ai->ai_addr;
  dest_len = mcs_conn.ai->ai_addrlen;

  sendbytes = mn_connect(sockfd, (SA *) dest, dest_len);
  if (sendbytes) {
    fprintf(stderr, "%s: mn_connect: %s (%d)\n", prog_name, strerror(errno), errno);
    exit(1);
  }

  buf_len = 3 + strlen(argv[2]) + 1;
  sbuf[0] = buf_len;		/* set length */
  sbuf[1] = 0;			 /* say PING */
  sbuf[2] = 0x81;		 /* sequence number */
  strncpy((void *) &sbuf[3], argv[2],2048);

  sendbytes = mn_sendto(sockfd, sbuf, buf_len, 0, (SA *) dest, dest_len);
  if (sendbytes == -1) {
    perror("talker:sendto");
    exit(1);
  }
  if (sendbytes != buf_len) {
    perror("did not send full packet");
  }
  else {
    printf("after sendto, sent bytes is:%d\n", sendbytes);
  }


  who = &who_addr;
  who_len = sizeof(who_addr);
  recvbytes = mn_recvfrom(sockfd, rbuf, 2048, 0, (SA *) who, &who_len);
  if (recvbytes == -1) {
    perror("receive failed");
    exit(1);
  }
  if (recvbytes != buf_len) {
    fprintf(stderr, "*** response didn't match, sent %d, got %d\n", strlen(argv[2]), recvbytes);
    exit(1);
  }

  mn_close(sockfd);
  exit(0);
}
