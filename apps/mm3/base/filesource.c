#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <message.h>
#include "filesource.h"
#include "serialprotocol.h"
#include "serialpacket.h"
#include "DtSensorDataMsg.h"
#include "mm3DataMsg.h"
#include "SDConstants.h"
#include "SensorConstants.h"

#define SECTOR_SIZE 512
#define SEQ_OFF     508
#define CHKSUM_OFF  510
#define OVERHEAD    4

extern int debug, verbose;

void hexprint(uint8_t *ptr, int len);

typedef enum {
  GS_OK = 0,
  GS_EOF,
  GS_CHKSUM_FAIL,
  GS_SEQ_FAIL,
  GS_BAD_DBLK,
} gs_rtn_t;


/*
 * sns_payload_len: allows an easy conversion from sensor id
 * to how many bytes in the payload.
 */
extern uint8_t sns_payload_len[MM3_NUM_SENSORS];

/*
 * Get Sector
 *
 * Description:         Grabs 512 bytes from file.
 *
 * input: fd		input file descriptor
 *       *dbuff		pointer to a byte array at least
 *			512 bytes long that will hold the
 *			the returned sector data.
 *
 * output: *dbuff	filled in with the sector data
 *	   rtn		GS_OK: worked okay dbuff filled in
 *			GS_EOF
 *			GS_CHKSUM_FAIL
 *
 * A sector is composed of 508 data bytes (which are a part of
 * a continuous data stream broken up into data records (dblks),
 * 2 byte sequence number (little endian, bytes 508 and 509),
 * and a 2 byte checksum (16 bit checksum of the previous
 * 510 bytes, little endian, in bytes 510 and 511).
 *
 * Persistent Data:
 *    cur_seq:	The sequence number of the current sector read.  ie.
 *		the last sector read.
 */

static uint16_t cur_seq = (uint16_t) -1;		//current sequence number.

gs_rtn_t
get_sector(int fd, uint8_t *dbuff) {
  uint16_t i;
  uint16_t chksum;
  uint16_t running_sum;
  ssize_t  num_read;
  uint16_t sector_seq;

  running_sum = 0;                  //summation of first 510 bytes for chksum verification
  num_read = read(fd, dbuff, SECTOR_SIZE);
  if (num_read == -1) {
    perror("*** read failed: ");
    exit(1);
  }
  if (num_read == 0) {
    if (verbose)
      fprintf(stderr, "*** eof\n");
    return(GS_EOF);
  }
  if (num_read != SECTOR_SIZE) {
    /*
     * This is weird.  We must read full sectors.
     * ABORT.
     */
    fprintf(stderr, "*** Bad sector read, wanted %d, got %ld\n",
	    SECTOR_SIZE, (long) num_read);
    exit(1);
  }

  /*
   * We've read 512 bytes (a sector).  Check the sequence number
   */
  cur_seq++;			/* bump to next */
  sector_seq = dbuff[SEQ_OFF] + (dbuff[SEQ_OFF + 1] << 8);
  if (cur_seq != sector_seq) {
    if (verbose | debug)
      fprintf(stderr, "*** Sector sequence error: wanted %d (%04x), got %d (%04x)\n",
	      cur_seq, cur_seq, sector_seq, sector_seq);
    return(GS_SEQ_FAIL);
  }

  for(i = 0; i < SECTOR_SIZE - 2; i++)  
    running_sum += dbuff[i]; 

  chksum = dbuff[CHKSUM_OFF] + (dbuff[CHKSUM_OFF + 1] << 8);
  if (chksum == running_sum)
    return(GS_OK);

  if (verbose | debug)
    fprintf(stderr, "*** checksum failed on sector: %d got %04x wanted %04x\n",
	    cur_seq, chksum, running_sum);
  return(GS_CHKSUM_FAIL);
}


/*
 * get_next_sector_byte
 *
 * return the next byte in a data stream.
 *
 * Persistent Data:
 *    sector_data: data buffer that holds current sector data as returned
 *		by get_sector.
 *
 *    cur_sector_ptr: pointer to the next byte that should be returned
 *		in the data stream.
 *
 *    remaining_bytes: how many bytes remain in the current sector that
 *		are part of the current data stream.
 */

static uint8_t sector_data[SECTOR_SIZE]; //holds current sector being parsed
static uint8_t *cur_sector_ptr;		 //ptr to curr byte in sect
static uint16_t remaining_bytes = 0;	 //number of bytes available to get_next_sect_byte

gs_rtn_t
get_next_sector_byte(int fd, uint8_t *bytep) {
  gs_rtn_t rtn;

  if (remaining_bytes == 0) {
    rtn = get_sector(fd, sector_data);
    if (rtn)
      return(rtn);

    /*
     * OK return is 0.  So we know at this point we got
     * a good sector.  Reset our persistent data.
     */
    cur_sector_ptr = sector_data;
    remaining_bytes = SECTOR_SIZE - OVERHEAD;
  }

  *bytep = *cur_sector_ptr++;
  remaining_bytes--;
  return(GS_OK);
}


/*
 * get_next_dblk
 *
 * return the next data block with a serial packet header prepended.
 *
 * input:	fd	input file descriptor
 *              bp	pointer to the buffer that the
 *			dblk goes into.  It is assumed to
 *			be large enough to handle the largest one.
 *
 * output:	rtn	error code (0 says all okay).
 *
 * The routine reads single bytes from the lower level (this is
 * assumed to be a single data stream that is broken up into dblks).
 * Simple checks are done here and we force the return of OK if
 * things are good.
 *
 * If something doesn't look right we fall through to the end and
 * bail at the bottom.
 */

gs_rtn_t
get_next_dblk(int fd, uint8_t *bp, int *len) {
  int l;
  uint16_t i;
  gs_rtn_t rtn;
  tmsg_t *msg;
  uint16_t cur_dblk_len;
  uint8_t cur_dtype, sns_id;
  uint8_t hdr[3], *dptr;

  *len = 0;

  /*
   * get first two bytes.  This should be the length.
   * big endian order.
   *
   * EOF is okay at the first byte.  Otherwise funny.
   */
  if ((rtn = get_next_sector_byte(fd, &hdr[0])))
    return rtn;

  if ((rtn = get_next_sector_byte(fd, &hdr[1])))
    return rtn;

  cur_dblk_len = (hdr[0] << 8) + hdr[1];

  if ((rtn = get_next_sector_byte(fd, &hdr[2])))
    return rtn;

  cur_dtype = hdr[2];

  if(cur_dtype >= DT_MAX || cur_dblk_len < 3) {
    fprintf(stderr, "*** bad dblk header: type %d, len %d (on dblk fetch, no data)\n",
	    cur_dtype, cur_dblk_len);
    return(GS_BAD_DBLK);
  }

  l = cur_dblk_len + 1 + SPACKET_SIZE;
  bp[0] = SERIAL_TOS_SERIAL_ACTIVE_MESSAGE_ID;
  msg = new_tmsg(bp + 1, l - 1);
  if (!msg) {
    fprintf(stderr, "*** new_tmsg failed (null)\n");
    exit(2);
  }
  spacket_header_dest_set(msg, 0xffff);
  spacket_header_src_set(msg, 0);
  spacket_header_length_set(msg, l);
  spacket_header_group_set(msg, 0);
  spacket_header_type_set(msg, MM3_DATA_MSG_AM_TYPE);
  dptr = (bp + 1) + spacket_data_offset(0);
  dptr[0] = hdr[0];
  dptr[1] = hdr[1];
  dptr[2] = hdr[2];

  for (i = 3; i < cur_dblk_len; i++) {
    if ((rtn = get_next_sector_byte(fd, &dptr[i])))
      return rtn;
  }

  /*
   * jump over the encapsulation so we are looking at the actual dblk data.
   */
  reset_tmsg(msg, ((uint8_t *)tmsg_data(msg)) + SPACKET_SIZE, tmsg_length(msg) - spacket_data_offset(0));
  *len = l;
  rtn = GS_BAD_DBLK;
  switch(cur_dtype) {
    case DT_IGNORE:
      if (cur_dblk_len == 0)
	rtn = GS_OK;
      break;

#ifdef notdef
    case DT_CONFIG:
      /* FIX: check length */
      return(GS_OK);
#endif

    case DT_SYNC:
      if(cur_dblk_len == DT_HDR_SIZE_SYNC)
	rtn = GS_OK;
      break;

    case DT_SYNC_RESTART:
      if(cur_dblk_len == DT_HDR_SIZE_SYNC)
	rtn = GS_OK;
      break;

    case DT_PANIC:
      if(cur_dblk_len == DT_HDR_SIZE_PANIC)
	rtn = GS_OK;
      break;

#ifdef notdef
    case DT_GPS_TIME:
      gps_time_p = (dt_gps_time_pt *) b;
         
      if(cur_dblk_len == DT_HDR_SIZE_GPS_TIME)
	rtn = GS_OK;
      fprintf(stderr, "*** DT_GPS_TIME: bad total length: %d (should be %d)\n",
	      cur_dblk_len, DT_HDR_SIZE_GPS_TIME);
      break;

    case DT_GPS_POS:
      if(cur_dblk_len == DT_HDR_SIZE_GPS_POS)
	rtn = GS_OK;
      break;
#endif

    case DT_SENSOR_DATA:
      sns_id = dt_sensor_data_sns_id_get(msg);
      if (sns_id < 1 || sns_id >= MM3_NUM_SENSORS) {
	fprintf(stderr, "*** DT_SENSOR: bad sensor id: %d\n", sns_id);
	rtn = GS_BAD_DBLK;
	break;
      }
      if (cur_dblk_len != (sns_payload_len[sns_id] + DT_HDR_SIZE_SENSOR_DATA)) {
	fprintf(stderr, "*** DT_SENSOR: sensor %d, bad total length: %d (should be %d)\n",
		sns_id, cur_dblk_len, sns_payload_len[sns_id] + DT_HDR_SIZE_SENSOR_DATA);
	rtn = GS_BAD_DBLK;
      } else
	rtn = GS_OK;
      break;

#ifdef notdef
    case DT_SENSOR_SET:
      /* FIX: check length */
      break;
#endif

    case DT_TEST:
      /* TEST has a variable length so nothing to check here.
       * do other checks later.
       */
      rtn = GS_OK;
      break;

#ifdef notdef
    case DT_CAL_STRING:
      /* FIX check length? */
      break;
#endif

#ifdef notdef
    case DT_GPS_RAW:
      /* FIX put in length check*/
      break;
#endif
    case DT_VERSION:
      if (cur_dblk_len == DT_HDR_SIZE_VERSION)
	rtn = GS_OK;
      break;

    default:
      rtn = GS_BAD_DBLK;
      fprintf(stderr, "*** dblk bad dtype: %d\n", cur_dtype);
      break;
  }
  free_tmsg(msg);
  if (rtn != GS_OK) {
    fprintf(stderr, "*** bad dblk (error %d): ", rtn);
    hexprint(dptr, cur_dblk_len);
  }
  return rtn;
}


/* Returns: file descriptor for file
 */

int
open_file_source(const char *file) {
  int fd;

  fd = open(file, O_RDONLY);
  if (fd < 0)
    return fd;
  return fd;
}


/* Effects: reads packet from serial forwarder on file descriptor fd
   Returns: the packet read (in newly allocated memory), and *len is
     set to the packet length, or NULL for failure
*/

/*
 * max is max dblk (64K) + serial header size.  We fake the serial header
 * so need to provide room for it.
 */
static uint8_t cur_dblk[64 * 1024 + SPACKET_SIZE];

void *read_file_packet(int fd, int *len) {
  int l;
  void *packet;
  gs_rtn_t rtn;

  if ((rtn = get_next_dblk(fd, cur_dblk, &l))) {
    switch(rtn) {
      default:
      case GS_EOF:		/* just stop */
      case GS_CHKSUM_FAIL:	/* critical failure */
      case GS_SEQ_FAIL:		/* critical failure */
	return NULL;

      case GS_BAD_DBLK:		/* keep going */
	break;
    }
  }
  packet = malloc(l);
  if (!packet) {
    fprintf(stderr, "*** malloc failed\n");
    return NULL;
  }
  memcpy(packet, cur_dblk, l);
  *len = l;
  return packet;
}
