/*
  temporenc.c
  161112 2300

  specifications at https://temporenc.org/
*/

#include <stdint.h>
#include "temporenc.h"

#if DBG_FL
#include <stdio.h>
#endif

/*

  Routines used for converting between time on MamMark tags
  in tinyOS and the temporenc standard for packing time values

  https://temporenc.org/

  It is not, as of yet, a full implementation of temporenc 
  however, it is being written to facilitate that if/when 
  it is needed/wanted.

  !!! Since MamMark is just going to use UTC for everything,
  !!! am not currently making time zone corrections.

  ??? How do we want to handle errors?
  !!! I have, as of yet, not developed an error handling system.

  !!! Even though temporenc can send time in nanosecond precision
  !!! we will break compatibility by not looking at anyting past millisecond

*/

/*
  The M,U,N,0 versions aren't used in the temporenc standard,
  but include the precision bits

  Specify the format of the output by an index into the
  tenc_type array.
  It includes both the fields and the precision of the output.

  This order must match the tenc_idx enum.

  The temporenc precision is encoded in the ttype_val
  but is also an element in the table

*/


// ??? Question, how terse versus how descriptive?
// ??? several of these constants could be shortened
// ??? BYTE to BY, LEN to LN, BITS to B
// ??? the number of bits in each field could be an array
// ??? Also the number of bits in each field is redundant with the flag mask
// ??? but saves recomputing for the shift


/**********************************************************************

Tables, data and global variables used by temporenc

 **********************************************************************/


// !!! in theory we could drop DTS and DTZ from table because they are really DTSM and DTSZM
// !!! must remain in sync with tenc_idx enum
tenc_type	t_types[]= {
// ------------ packing -------------                             ------ unpacking --------
// flag           type   type  type  type  num of                Number of bits used for each field
// fields, name    bits,  val, part, mask, bytes,    freq,       pad,  zone,subs,   time, date
  {DT_FL,   "DT   ",  2, 0x00, 0x00, 0xC0, DT_LEN,             0,  0,      0,  0, T_BITS, D_BITS},	// 	00xxxxxx
  {DTS_FL,  "DTS  ",  4, 0x40, 0x01, 0xC0, DTS_LEN,            0,  0,      0,  0, T_BITS, D_BITS},	// msec 01xxxxxx
  {DTSM_FL, "DTSM ",  4, 0x40, 0x04, 0xF0, DTSM_LEN,        1000,  4,      0, 10, T_BITS, D_BITS},	// msec 0100xxxx
  {DTSU_FL, "DTSU ",  4, 0x50, 0x05, 0xF0, DTSU_LEN,     1000000,  2,      0, 20, T_BITS, D_BITS},	// usec 0101xxxx
  {DTSN_FL, "DTSN ",  4, 0x60, 0x06, 0xF0, DTSN_LEN,  1000000000,  0,      0, 30, T_BITS, D_BITS},	// nsec 0110xxxx
  {DTS0_FL, "DTS0 ",  4, 0x70, 0x07, 0xF0, DTS0_LEN,           0,  6,      0,  0, T_BITS, D_BITS},	// none 0111xxxx
  {D_FL,    "D    ",  3, 0x80, 0x04, 0xE0, D_LEN,              0,  0,      0,  0,      0, D_BITS},	// 	100xxxxx
  {T_FL,    "T    ",  7, 0xA0, 0x50, 0xFE, T_LEN,              0,  0,      0,  0, T_BITS,      0},	//      1010000x
  {DTZ_FL,  "DTZ  ",  3, 0xC0, 0x06, 0xE0, DTZ_LEN,            0,  0, Z_BITS,  0, T_BITS, D_BITS},	//      110xxxxx
  {DTSZ_FL, "DTSZ ",  5, 0xE0, 0x07, 0xE0, DTSZ_LEN,           0,  0, Z_BITS,  0, T_BITS, D_BITS},	//      111xxxxx
  {DTSZM_FL,"DTSZM",  5, 0xE0, 0x1C, 0xF8, DTSZM_LEN,       1000,  4, Z_BITS, 10, T_BITS, D_BITS},	// msec 11100xxx
  {DTSZU_FL,"DTSZU",  5, 0xE8, 0x1D, 0xF8, DTSZU_LEN,    1000000,  2, Z_BITS, 20, T_BITS, D_BITS},	// usec 11101xxx
  {DTSZN_FL,"DTSZN",  5, 0xF0, 0x1E, 0xF8, DTSZN_LEN, 1000000000,  0, Z_BITS, 30, T_BITS, D_BITS},	// nsec 11110xxx
  {DTSZ0_FL,"DTSZ0",  5, 0xF8, 0x1F, 0xF8, DTSZ0_LEN,          0,  6, Z_BITS,  0, T_BITS, D_BITS},	// none 11111xxx
};

uint32_t	subs_mask[] = {PREC_M_MASK, PREC_U_MASK, PREC_N_MASK, 0};	// array of subsecond bits by precision

/**********************************************************************

Debugging code

 **********************************************************************/

#if DBG_FL
//  function to print value of a time structure

void print_rtct (RTCTime *r) {

  printf("y:%04d m:%02d d:%02d %02d:%02d:%02d...%03d ",
	 r->yr, r->mon, r->day, r->hr, r->min, r->sec, r->subsec);
}

// function to print byte stream structure
void print_bstrm (b_stream *b) {
  int		bytes_left = b->payld_bytes;
  uint8_t	*byte = b->payload;
  
#if (DBG_FL & 0x07)
  printf("src = %0llX, bits = %02d, bytes = %02d :", b->data_src, b->src_bits, bytes_left);
// move to right to line up
  bytes_left = 10;
  while (bytes_left > b->payld_bytes){
    printf("   ");
    bytes_left--;
  }
  while (bytes_left) {
    printf(" %02x", *byte++);
    bytes_left--;
  }
  printf(" = ");
#endif
  // move to right to line up
  bytes_left = 10;
  while (bytes_left > b->payld_bytes){
    printf("  ");
    bytes_left--;
  }
    
  // bytes_left == payld_bytes
  byte = b->payload+bytes_left-1;
  printf(" 0x");
  while (bytes_left) {
    printf("%02x", *byte--);
    bytes_left--;
  }
 
  printf("\n");

}

void print_typestruct(tenc_type *type_struct) {

  printf("%s ", type_struct->name);
  printf("fields =   %04x ", type_struct->field_flags);
  printf("type_bits   =     %02d ", type_struct->tt_bitlen);
  printf("\n");
  printf("type_val    =   0x%02x ", type_struct->ttype_val);
  printf("type_part   =   0x%02x ", type_struct->ttype_part);
  printf("type_mask   =   0x%02x ", type_struct->tt_bitmask);
  printf("\n");
  printf("type_bytect =     %02d ", type_struct->byte_len);
  printf("tempor_freq =   %9d", type_struct->freq);
  printf("\n");
  printf("pad_len :%02d ", type_struct->pad_bits	);
  printf("zone_len:%02d ", type_struct->zone_bits);
  printf("subs_len:%02d ", type_struct->subs_bits);
  printf("time_len:%02d ", type_struct->time_bits);
  printf("date_len:%02d ", type_struct->date_bits);
  printf("\n");
}

int main (void) {

  // put test code here
  // ??? How does RTC store day, time etc, how does temporenc
  // ??? We may need to subtract one from each of the values.

  
  // Fill some time structures with data
  // maybe make an array of them
/*
  year:2014, month:10, day:23, hour:10, minute:55, second:45, [ milli:51, micro:44, nano:22 ]


FORMAT           CLOCK                          (LEN) BYTES
date:            2014-10-23                     (3)   0x8fbd36
time:            10:55:45                       (3)   0xa0aded
date_time:       2014-10-23 10:55:45            (5)   0x1f7a6caded
date_time_milli: 2014-10-23 10:55:45.051        (7)   0x47de9b2b7b4330
date_time_micro: 2014-10-23 10:55:45.000044     (8)   0x57de9b2b7b4000b0
date_time_nano:  2014-10-23 10:55:45.000000022  (9)   0x67de9b2b7b40000016
date_time_nano:  ??:??:??.000000022             (9)   0x6fffffffffc0000016
*/    
  RTCTime	test_times00[] = {
    {2014,                10,        23, HOUR_EMPTY, MINUTE_EMPTY, SECOND_EMPTY, PREC_M_EMPTY},
    {YEAR_EMPTY, MONTH_EMPTY, DAY_EMPTY,         10,           55,           45, PREC_M_EMPTY},
    {2014,                10,        23,         10,           55,           45, PREC_M_EMPTY},
    {2014,                10,        23,         10,           55,           45, 51},
    {2014,                10,        23,         10,           55,           45, 44},
    {2014,                10,        23,         10,           55,           45, 22},
    {YEAR_EMPTY, MONTH_EMPTY, DAY_EMPTY, HOUR_EMPTY, MINUTE_EMPTY, SECOND_EMPTY, 22},
    {YEAR_EMPTY, MONTH_EMPTY, DAY_EMPTY, HOUR_EMPTY, MINUTE_EMPTY, SECOND_EMPTY, PREC_N_EMPTY},
    {0,          0,           0,         0,          0,            0,            0}
  };
  
  RTCTime	test_times01[] = {
    {2016, 11, 30, 11, 59, 23, 765},
    {0000, 00, 00, 00, 00, 00, 000}
  };
 
  RTCTime	test_times02[] = {
    {2016, 12, 31, 11, 59, 23, 765},
    {0000, 01, 23, 12, 34, 56, 789},
    {4095, 01, 23, 12, 34, 56, 789},    
    {2016, 00, 31, 11, 59, 23, 765},
    {1970, 13, 23, 12, 34, 56, 789},
    {2016, 12, 31, 11, 59, 60, 765},
    {4095, 12, 31, 23, 59, 23, 999},
    {2016, 12, 31, 11, 59, 23, 765},
    {2016, 13, 31, 11, 59, 23, 765},
    {2016, 12, 32, 11, 59, 23, 765},
    {2016, 12, 31, 24, 59, 23, 765},
    {2016, 12, 31, 11, 60, 23, 765},
    {2016, 12, 31, 11, 59, 61, 765},
    {1970, 01, 23, 12, 34, 56,1000},
    {0000, 00, 00, 00, 00, 00, 000}
  };

  RTCTime	rtc_time;
  uint8_t	payload[8];

  RTCTime	*rtct_p;

  int		type_idx;
  int           payld_len;


  printf("Test the temporenc time functions\n");
  // call pack
  // print the output
  // call unpack on the output
  // print the results
  rtct_p  = test_times00;
  type_idx=6;               // D
  temporenc_pack(  1000, &payld_len, type_idx, payload, rtct_p);
  temporenc_unpack(1000, payld_len, payload, &rtc_time);
  rtct_p++;
  printf("====================================\n");
  type_idx=7;               // T
  temporenc_pack(  1000, &payld_len, type_idx, payload, rtct_p);
  printf("      ----------------------\n");
  temporenc_unpack(1000, payld_len, payload, &rtc_time);
  rtct_p++;
  printf("====================================\n");
  type_idx=0;               // DT
  temporenc_pack(  1000, &payld_len, type_idx, payload, rtct_p);
  printf("      ----------------------\n");
  temporenc_unpack(1000, payld_len, payload, &rtc_time);
  rtct_p++;
  printf("====================================\n");
  type_idx=2;               // DTSM
  temporenc_pack(  1000, &payld_len, type_idx, payload, rtct_p);
  printf("      ----------------------\n");
  temporenc_unpack(1000, payld_len, payload, &rtc_time);
  rtct_p++;
  printf("====================================\n");
  type_idx=3;               // DTSU
  temporenc_pack(  1000000, &payld_len, type_idx, payload, rtct_p);
  printf("      ----------------------\n");
  temporenc_unpack(1000000, payld_len, payload, &rtc_time);
  rtct_p++;
  printf("====================================\n");
  type_idx=4;               // DTSN
  temporenc_pack(  1000000000, &payld_len, type_idx, payload, rtct_p);
  printf("      ----------------------\n");
  temporenc_unpack(1000000000, payld_len, payload, &rtc_time);
  rtct_p++;
#if 0
  for (type_idx = 0; type_idx < BAD_IDX; type_idx++) {	// for each temporenc type
    rtct_p = test_times00;				// test for each entry in table
    while (rtct_p->yr) {
      tag_pack(type_idx, payload, rtct_p);
      rtct_p++;			// next time in array
    }
  }
  for (type_idx = 0; type_idx < BAD_IDX; type_idx++) {	// for each temporenc type
    rtct_p = test_times01;				// test for each entry in table
    while (rtct_p->yr) {
      tag_pack(type_idx, payload, rtct_p);
      rtct_p++;			// next time in array
    }
  }
  for (type_idx = 0; type_idx < BAD_IDX; type_idx++) {	// for each temporenc type
    rtct_p = test_times02;				// test for each entry in table
    while (rtct_p->yr) {
      tag_pack(type_idx, payload, rtct_p);
      rtct_p++;			// next time in array
    }
  }
#else     // silence warnings
  rtct_p = test_times01;				// silence warnings
  rtct_p = test_times02;				// silence warnings
#endif
  return 0;
}

#endif		// DBG_FL

/**********************************************************************

Helper routines

 **********************************************************************/
/*
    Clear the RTC time structure
    ??? may need to use temporenc masks instead
 */
int rtct_time_clr(RTCTime *r) {
  if (r == NULL) {
    return ERR_NULL_PTR;
  }
  r->yr    =0;
  r->mon   =0;
  r->day   =0;
  r->hr    =0;
  r->min   =0;
  r->sec   =0;
  r->subsec=0;
  return 0;
}

/**********************************************************************
  partial_pack() takes data from a uint_64_t data source
  and will transfer as many full bytes of data as it can onto
  the payload byte stream
  The b_stream struct keeps track of how many bits and bytes are used

  for now, returning the unmodified value of data_src
  could also return an error code or void
 **********************************************************************/
uint64_t partial_pack (b_stream *b_stream) {
  int		num_bytes;
  uint8_t	xfer_byte;

#if (DBG_FL & 0x0001)
    printf("partial_pack bits to xfer %02d\n", b_stream->src_bits);
#endif
  num_bytes = b_stream->src_bits/8;
  while (num_bytes > 0) {			// !!! make sure not >= 0
    xfer_byte = b_stream->data_src & 0xff;
    b_stream->payload[b_stream->payld_bytes] = xfer_byte;
    b_stream->payld_bytes++;
    b_stream->data_src = b_stream->data_src>>8;
    b_stream->src_bits-=8;
    num_bytes--;
#if (DBG_FL & 0x0001)
    printf("xfer_byte = %02X, %02d bits left over\n", xfer_byte, b_stream->src_bits);
#endif
  }		// while
  return b_stream->data_src;
}		// partial_pack


/**********************************************************************

pack and unpack

 **********************************************************************/

/**********************************************************************
  Given a time structure, and a temporence type
  create a temporenc byte stream in the specified payload.

  Return 0 on success, or an error code.

  Generally tries to return some form of valid data.

  The temporenc type is the tenc_idx enum, which is an index
  into the tenc_type array.

  The tenc_type array contains all the formatting data for each
  field and precision.

  The byte stream always has an integer number of bytes.

  Note errors, but don't halt execution unless we HAVE to.

  Create the separate parts,
  Combine from the LSB to the MSB based on the type and precision.
  After each two are combined, transfer them by byte boundaries into a byte array
  leaving leftover bytes in the working 64 bit int.
  When done, if there is any space left, pad with zeroes.

  Will need routines that:
     adds a new field to the intermediate int
     moves bytes from intermediate int to array

  ??? If we were to call pack with DTS_IDX, what would happen?
  ??? should it return an error with no precision? Or default to DTS0? or ...???

 tag_pack is a wrapper around temporenc_pack that hardwires the 
 subsecond clock frequency at 1KHz.
  **********************************************************************/

int tag_pack(int type_idx, uint8_t* payload, RTCTime *t_time ){
  int       payld_len;
  return temporenc_pack(1000, &payld_len, type_idx, payload, t_time );
}

int temporenc_pack(uint32_t inp_freq, int *payld_len, int type_idx, uint8_t* payload, RTCTime *t_time ){

  static int	pack_err = 0;	// error flag Static so we can look at it when debugging

  uint32_t	subsec;
  uint8_t	second;
  uint8_t	minute;
  uint8_t	hour;
//  uint8_t	dayOfWeek;
  uint8_t	day;
  uint8_t	month;
  uint16_t	year;

  // flags for fields that are missing
  DEF_UINT      no_subsec	= FALSE;
  DEF_UINT      no_second	= FALSE;
  DEF_UINT      no_minute	= FALSE;
  DEF_UINT      no_hour		= FALSE;
//  DEF_UINT      no_dayOfWeek	= FALSE;
  DEF_UINT      no_day		= FALSE;
  DEF_UINT      no_month	= FALSE;
  DEF_UINT      no_year		= FALSE;

  
  uint8_t	type_prec;	// 2 bits precision + 0empty 10mSec, 20uSec, 30nSec
  uint8_t	tempor_type;	// bit mask of temporenc type
//  uint8_t	inp_prec;	// !!! tag subseconds hard wired to milliseconds
	// !!! tag subseconds hard wired to milliseconds
  uint32_t	freq_ratio;
//  uint8_t	inp_type;


  uint8_t	fields    = 0;	// field_flags which fields are present: Date, Time, Subsec, Zone
  uint8_t	type_bits = 0;	// tt_bitlen   number of bits used by type
  uint8_t	type_val  = 0;	// ttype_val   both type and precision
//  int           foo;
  
//  uint8_t	t_value;
//  ;
  uint8_t       type_value;     // 2-5 bits at start describing the type: left shifted
  uint8_t	type_mask;	// tt_bitmask
  uint8_t	type_bytect;	// byte_len    how many bytes is temporenc message
  uint32_t	tempor_freq; 	// freq        1 / temporance subsec
  uint8_t	pad_len;     	// pad_bits
  uint8_t	zone_len;    	// zone_bits
  uint8_t	subs_len;    	// subs_bits
  uint8_t	time_len;    	// time_bits
  uint8_t	date_len;	// date_bits
  
  
//  uint32_t	type_val;	// 2-5 bits at start describing the type: left shifted
  uint32_t	type_part=0;	// 2-5 bits at start describing the type: right shifted
  uint32_t	date_part=0;	// 21 bits: Y12, M4, D5
  uint32_t	time_part=0;	// 17 bits: H5, M6, S6
  uint32_t	subs_part=0;	// 10 bits milli, 20 bits micro, 30 bits nanosec
  uint32_t	zone_part=0;	// !!! not currently implementing time zones

  tenc_type	*type_struct;

  static b_stream	data_stream = {0, 0, NULL, 0};
//  uint32_t	padding_bits;

//  uint64_t	part_value;	// large int for building data to send to byte stream

#if (DBG_FL & 0x0017)
  printf("temporenc pack, type_idx = %01d\n", type_idx);
#endif


  data_stream.data_src    = 0;                   // bit stream structure
  data_stream.src_bits    = 0;
  data_stream.payld_bytes = 0;
  data_stream.payload = payload;
  // get the input time
  // subsec resolution is defined by inp_prec and possibly subsec_freq
  subsec     = t_time->subsec;
  second     = t_time->sec;
  minute     = t_time->min;
  hour       = t_time->hr;
  day	     = t_time->day-1;   // !!! 0-30
  month      = t_time->mon-1;   // !!! 0-11
  year       = t_time->yr;

  // what format will output be in?
  // Check for legal type_idx
  if (type_idx >= BAD_IDX) {
#if (DBG_FL & 0x8000)
    printf ("err %04X: illegal type index\n", BAD_IDX);
#endif
    return ERR_BAD_TEMPRN_TYPE;
  }
    
  type_struct	= t_types + type_idx;		// point at type_num element of array &t_types[type_idx]
  fields        = type_struct->field_flags;
  type_bits     = type_struct->tt_bitlen;
  type_val      = type_struct->ttype_val;	// both type and precision : left shifted
  type_part     = type_struct->ttype_part;	// both type and precision : right shifted
  type_mask	= type_struct->tt_bitmask;
  type_bytect	= type_struct->byte_len;	// how many bytes is temporenc message
  tempor_freq	= type_struct->freq;		// 1 / temporance subsec  
  pad_len 	= type_struct->pad_bits;
  zone_len      = type_struct->zone_bits;
  subs_len      = type_struct->subs_bits;
  time_len      = type_struct->time_bits;
  date_len	= type_struct->date_bits;

#if (DBG_FL & 0x0017)
  printf("type_idx = %02d\n",type_idx);
  print_typestruct(type_struct);
#endif
#if (DBG_FL )
  printf("%s: ",type_struct->name);
  print_rtct(t_time);
  printf(" : ");
#endif
  //
  type_value  = ((type_val &= type_mask)>>(8-type_bits));	// type and precision
  if (tempor_freq) {
    type_prec = type_value & 0x3;
    type_val = type_value >> 2;                   // clip precision bits off end
  } else {
    type_prec = PREC_0;
  }
#if (DBG_FL & 0x0012)
  printf("type_value = 0x%02X type_val = 0x%02X type_part = 0x%02X type_prec = 0x%02X\n",
         type_value, type_val, type_part, type_prec);
  printf("tempor_freq = %0d, subsec flag = 0x%02X\n",
         tempor_freq, SUBS_FL);
#endif
 

  if ((subsec == PREC_N_EMPTY)||(type_prec==PREC_0)) {
    no_subsec = TRUE;
  } else if ((subsec > PREC_N_MAX) && (subsec > PREC_N_EMPTY)) {
    pack_err |= ERR_PACK_NSEC_MAX;
  }	// subsec range

  if (second > SECOND_MAX) {
    if (second == SECOND_EMPTY)
      no_second = TRUE;
    if (second > SECOND_EMPTY)
      pack_err |= ERR_PACK_SEC_MAX;
  }	// second range

  if (minute > MINUTE_MAX) {
    if (minute == MINUTE_EMPTY) {
      no_minute = TRUE;
      minute = MINUTE_MASK;
    }
    if (minute > MINUTE_EMPTY)
      pack_err |= ERR_PACK_MINUTE_MAX;
  }	// minute range

  if (hour > HOUR_MAX) {
    if (hour == HOUR_EMPTY) {
      no_hour = TRUE;
      hour = HOUR_MASK;
    }
    if (hour > HOUR_EMPTY)
      pack_err |= ERR_PACK_HOUR_MAX;
  }	// hour range

  if (day > DAY_MAX) {
    if (day == DAY_EMPTY) {
      no_day = TRUE;
      day = MONTH_MASK;
    }
    if (day > DAY_EMPTY)
      pack_err |= ERR_PACK_DAY_MAX;
  }	// day range

  if (month > MONTH_MAX) {
    if (month == MONTH_EMPTY) {
      no_month = TRUE;
      month = MONTH_MASK;
    }
    if (month > MONTH_EMPTY)
      pack_err |= ERR_PACK_MONTH_MAX;
  }	// month range

  if (year > YEAR_MAX) {
    if (year == YEAR_EMPTY) {
      no_year = TRUE;
      year = YEAR_MASK;
    }
    if (year > YEAR_EMPTY)
      pack_err |= ERR_PACK_YEAR_MAX;
  }	// year range

#if (DBG_FL & 0x0007)
    printf ("fields checked, pack_err %04X\n", pack_err);
#endif

  // Construct each component

  //******************* date
  
  if (fields & DATE_FL) {	// construct date component
    date_part = (year << YEAR_SHIFT) | (month << MONTH_SHIFT) | (day << DAY_SHIFT);
#if (DBG_FL & 0x0011)
    printf("date_part=0x%04x, year=%04d, month=%02d day=%02d\n", date_part, year, month, day);
#endif
  }	else {
      date_part = 0;
  }// date

  //******************* time
  
  if (fields & TIME_FL) {	// construct time component
    time_part = (hour << HOUR_SHIFT) | (minute << MINUTE_SHIFT) | (second << SECOND_SHIFT);
#if (DBG_FL & 0x0011)
    printf("time_part=ox%04x, hour=%02d, min=%02d sec=%02d\n", time_part, hour, minute, second);
#endif
  } else {
      time_part = 0;
  }// time

  //******************* subsec
  
  // For this pass we will assume that subsecond precsion is in
  // milli, micro or nano seconds : 1000, 10000000, 1000000000
  // and that it can be converted by an integer multiply or divide.
  // At some point, we may need to change it to allow other clockrates
  // Note, that if we convert to float and back, we could just calculate the ratio
  // and multiply.
#if (DBG_FL & 0x0001)
    printf("type_value=%02x, no_subsec=%01x\n", type_value, no_subsec);
#endif
  
  if ((fields & SUBS_FL) && (tempor_freq)) {	// construct subsecond component
							// should not get here if either precision == 3
    if (subsec >= inp_freq) {				// this means subsec > 1 second
      pack_err |= ERR_SUBSEC_2BIG;
#if (DBG_FL & 0x8000)
      printf ("pack_err %04X: subsecond out of range\n", pack_err);
#endif
    }
#if (DBG_FL & 0x0002)
      if (!tempor_freq){
        printf("!!! Error, tempor_freq == 0\n");
      }
#endif
    // if (tempor_freq == inp_freq) multiply by 1
    if (tempor_freq == inp_freq) {
      subs_part = subsec;
    } else if  (tempor_freq > inp_freq) {
      freq_ratio = tempor_freq / inp_freq;
      subs_part = subsec * freq_ratio;
    } else if (inp_freq > tempor_freq) {
      freq_ratio = inp_freq / tempor_freq;
      subs_part = subsec / freq_ratio;
    }
#if (DBG_FL & 0x0011)
    printf("subs_part=0x%d, tempor_freq=%d, inp_freq=%d, subsec=%d freq_ratio=%d\n",
	   subs_part, tempor_freq, inp_freq, subsec, freq_ratio );
#endif
    
  }	// subsec

  //******************* timezone

  if (tempor_type & ZONE_FL) {	// construct timezone component
#if (DBG_FL & 0x0001)
    printf("!!! NOT CURRENTLY SUPPORTING TIMEZONE\n");
#endif
    zone_part = ZONE_MASK;		// No timezone info
  }	else {
    zone_part = 0;
  }     // zone

// Construct the type and precision part

// Merge the parts into a character array

  //least signficant bits are padding
  data_stream.data_src = 0;				// clear source to 0
  data_stream.src_bits = pad_len;			// skip padding

  // Next least significant are zone
  // We aren't implementing zone yet
  if (fields & ZONE_FL) {
    data_stream.data_src |= (zone_part<<data_stream.src_bits);	// Z_MASK means no zone
    data_stream.src_bits += zone_len;
    partial_pack(&data_stream);				// move any full bytes to payload
  }	// zone

  // Add subseconds to payload
  if (fields & SUBS_FL) {
    data_stream.data_src |= (subs_part<<data_stream.src_bits);	//
    data_stream.src_bits += subs_len;
    partial_pack(&data_stream);				// move any full bytes to payload
  }	// subsec flag

  // Add time to payload
  if (fields & TIME_FL) {
    data_stream.data_src |= (time_part<<data_stream.src_bits);	//
    data_stream.src_bits += time_len;
    partial_pack(&data_stream);				// move any full bytes to payload
  }	// time flag

  // Add date to payload
  if (fields & DATE_FL) {
    data_stream.data_src |= (date_part<<data_stream.src_bits);	//
    data_stream.src_bits += date_len;
    partial_pack(&data_stream);				// move any full bytes to payload
  }	// date flag

  // Add type and precision to payload
#if (DBG_FL & 0x0014)
  printf("base=0x%0llX,type_part =0x%02X, type_val =0x%02X shift by %0d \n",
         data_stream.data_src, type_part, type_val, data_stream.src_bits);
#endif

  data_stream.data_src |= (type_part<<data_stream.src_bits);	//
  data_stream.src_bits += type_bits;
#if (DBG_FL & 0x0012)
  printf(" final=0x%0llX, final bits= %0d\n",
         data_stream.data_src, data_stream.src_bits);
#endif
  partial_pack(&data_stream);				// move any full bytes to payload

  if (data_stream.src_bits) {
#if (DBG_FL & 0x0017)
    printf("%02d bits left over\n", data_stream.src_bits);
#endif
    pack_err |= ERR_PAYLOAD_LEN;
  }
#if (DBG_FL)
  print_bstrm(&data_stream);
#endif
#if (DBG_FL & 0x0007)
  if (pack_err){
    printf ("End of pack, pack_err %04X\n", pack_err);
  }
#endif
  *payld_len = data_stream.payld_bytes;
  return pack_err;
}

/*****************************************************************

Given a temporenc data structure, look at the MS byte to determine
type and precision.
This will tell us the formatting of the data.
From there, we can extract data from the LSB end.

First look at upper two bits (mask 0xC0)

0x00: DT_IDX :
0x40: DTS_IDX
	(mask 0x30)>>4 for precision
	index=DTS_IDX+precision
0x80: D_IDX, T_IDX
	D_IDX mask next bit = 0
	T_IDX mask next bit = 1 then next 4 = 0
0xC0: DTZ_IDX, DTSZ_IDX
	DTZ_IDX mask next bit = 0
	DTSZ_IDX mask next bit = 1
		(mask 0x18)>>3 for precision
		index=DTS_IDX+precision


Once we have index into ttype table we have flags for all types present
Fields are always stored in the order DTSZ
		??? remove this line? Need a clean way of taking n bits out of either left or right of byte
  Copy bytes with data into int
  right shift appropriately
  need an array of bit masks for each data type: DTMUNZ

Initialize scratch buffer to 0

pad_len  = type_struct->pad_bits;
zone_len = type_struct->zone_bits;
subs_len = type_struct->subs_bits;
time_len = type_struct->time_bits;
date_len = type_struct->date_bits;

Have 64bit scratch
We know position of lsb and msb in the byte stream
therefore we know how many bits we have in int
we know how many bits in next field
subtract what we have from what are in next field

!!! ??? Do we make sure that the t_time parameter has been properly initialized?
!!! ??? If we don't get a data field, do we write in our own value? Or leave as is?

!!! There is some optimization that could be done by using smaller integers
!!! but that may actually take more machine cycles
!!! ??? what is native format?

??? rather than passing length and a payload pointer, we could make
??? a tlv structure with type_idx, payload_len and either a pointer
??? or a 10 byte array.

************************************************************************/
int temporenc_unpack(uint32_t sys_freq, int payld_len, uint8_t* payload, RTCTime *t_time ){

  uint64_t	scratch	      = 0;	// bit structure where we build it
  DEF_UINT	unpack_err    = 0;	// bit field errors

				// Look at  MS Byte from payload
  DEF_UINT	type_idx;
  DEF_UINT	type_byte;
  DEF_UINT	top_2bits;

  uint32_t	prec     =0;         // initialize to prevent warnings
  uint32_t	date_part=0;
  uint32_t	time_part=0;
  uint32_t	subs_part=0;
  uint32_t	zone_part=0;	// acknowledge but ignore zone

  DEF_UINT	pad_len=0;	// number of bits of padding
  DEF_UINT	zone_len=0;	// number of bits in zone_part
  DEF_UINT	subs_len=0;	// number of bits in subs_part
  DEF_UINT	time_len=0;	// number of bits in time_part
  DEF_UINT	date_len=0;	// number of bits in date_part

#if 0
				// !!! Time formats not sorted out
  uint16_t	yr	= 0;	// t_time->rtc_time.YEAR
  uint8_t	mon	= 0;	// t_time->rtc_time.MONTH
  uint8_t	day	= 0;	// t_time->rtc_time.DAY
  uint8_t	hr	= 0;	// t_time->rtc_time.HOUR
  uint8_t	min	= 0;	// t_time->rtc_time.MIN
  uint8_t	sec	= 0;	// t_time->rtc_time.SEC
  uint32_t	subs	= 0;	// t_time->subsec
				// !!! no zone
#endif    //0
  
  tenc_type	*type_struct;
  b_stream      bs;

  DEF_UINT	bytes_read = 0;	// last byte read of byte array
  DEF_UINT	scr_msb;	// msbit of value in scratch
  DEF_UINT	scr_lsb;	// lsbit of value in scratch
//  DEF_UINT	scr_len;	// num of bits in scratch
  DEF_UINT	need_bits;	// how many bits we need from payload
  DEF_UINT	need_bytes;	// how many bytes we need from payload
  DEF_UINT	bits_got;	// bits from byte stream this field

  uint32_t	new_bytes;	// new bytes from payload
				// in theory we never pull more than
				// 4 bytes from payload

#if (DBG_FL & 0x00F0)
  printf("temporenc_unpack \n");
#endif
  // The first step is to look at the first few msbits in the MSB
  // and determine the type and precision of the data
  // giving us an index into the ttypes table.
  // hard coded masks could be elements in table
  // but flexibility isn't worth the cost

  rtct_time_clr(t_time);
  type_byte = payload[payld_len -1];
  top_2bits = type_byte & 0xC0;
  bs.data_src    = 0;                   // bit stream structure
  bs.src_bits    = payld_len*8;
  bs.payld_bytes = payld_len;
  bs.payload     = payload;
#if (DBG_FL & 0x00F0)
  print_bstrm(&bs);
  printf("\n");
#endif
  switch (top_2bits>>6) {
    case 0:				// 0b_00xxxxxx
      type_idx = DT_IDX;
      break;
      
    case 1:				// 0b_01ppxxxx
      prec = (type_byte & 0x30)>>4;	// DTS[MUN0]
      type_idx = DTSM_IDX + prec;
      break;
      
    case 2:
      if ((type_byte & 0xE0)==0x80) {	//         0b_100	DATE only
					// type_byte & ttypes[D_IDX].ttype_mask ==
					//		ttypes[D_IDX].ttype_mask
	type_idx = D_IDX;
      } else if ((type_byte & 0xFE)==0xA0) {	// 0b_101	TIME only
					// type_byte & ttypes[T_IDX].ttype_mask ==
					//		ttypes[T_IDX].ttype_mask
	type_idx = T_IDX;
      } else {
	unpack_err |= ERR_BAD_TEMPRN_TYPE;
#if DBG_FL
        printf("unpack_err = 0x%04X, Bad temporenc type\n", unpack_err);
#endif
	return unpack_err;
      }	// if date or time
      break;
      
    case 3:				// 0b_11xxxxxx	DTZ or DTSZ  !!! ZONE is in theory unused
      if ((type_byte & 0xE0)==0xC0) {	// 0b_110xxxxx
 					// type_byte & ttypes[DTZ_IDX].ttype_mask ==
					//	ttypes[DTZ_IDX].ttype_mask
	type_idx = DTZ_IDX;
      } else if  ((type_byte & 0xE0)==0xE0) {	// 0b_111xxxxx
 					// type_byte & ttypes[DTZ_IDX].ttype_mask ==
					//	ttypes[DTZ_IDX].ttype_mask
	prec = (type_byte & 0x18)>>3;	// DTS[MUN0]Z
	break;
      }	// if DATE, TIME and ZONE
  }	// switch top_2bits

  // Once we know what the format (type) of the input is
  // we can calculate the bit length of each of the fields

  type_struct	= &t_types[type_idx];	// point at type_num element of array

  pad_len  = type_struct->pad_bits;
  zone_len = type_struct->zone_bits;
  subs_len = type_struct->subs_bits;
  time_len = type_struct->time_bits;
  date_len = type_struct->date_bits;
#if (DBG_FL & 0x0010)
  //for (scr_lsb=0; scr_lsb<BAD_IDX; scr_lsb++){
  //  printf("======= type %0d =====\n", scr_lsb);
  //  print_typestruct(&t_types[scr_lsb]);
  //}
  print_bstrm(&bs);
  printf("top2 = %0d type_byte = 0x%02X, prec = 0x%02X type_idx = %02d\n", top_2bits>>6, type_byte, prec, type_idx);
  print_typestruct(type_struct);
#endif
  scr_msb = 0;				// we have neither gotten nor used any bits
  scr_lsb = 0;

  need_bits  = pad_len + zone_len;	// how many bits do we need?
  need_bytes = need_bits / 8;		// how many bytes is that?
  if (need_bits % 8) need_bytes++;	// if there is a remainder, get an extra byte
  new_bytes = 0;
  bits_got = 0;				// bytes processed each field
					// !!! could do this as a macro
  while(need_bytes) {			// pull bytes from payload
                                        // new_bytes is just temprorary storage
    new_bytes |= (payload[bytes_read] << bits_got);
    bits_got+=8;
    need_bytes--;
    bytes_read++;			// if we know payload length could compare
  }	// need_bytes
  scratch|=(new_bytes<<scr_msb);        // add new bytes on to big end of scratch
  scr_msb += bits_got;
  scratch = scratch >> pad_len;		// if there are padding bits skip them
  scr_msb -= pad_len;
  if (zone_len) {
    zone_part = scratch & Z_MASK;		// Get the zone part, !!! although we don't decode it
    scratch = scratch >> zone_len;
    scr_msb -= zone_len;
#if (DBG_FL & 0x0010)
    printf("zone_len = %0d\n", zone_len);
#endif
  }

  if (subs_len) {			// type_struct->field_flags & SUBS_FL
    need_bits  = subs_len - scr_msb;	// how many more bits do we need?
    need_bytes = need_bits / 8;
    if (need_bits % 8) need_bytes++;	// if any bits left over, get the next byte

    new_bytes = 0;
    bits_got  = 0;			// bits processed each field
    while(need_bytes) {			// pull bytes from payload
      new_bytes |= (payload[bytes_read] << bits_got);
      bits_got+=8;
      need_bytes--;
      bytes_read++;			// if we know payload length could compare
      //scr_msb += 8;			// have 8 more bits in new_bytes
    }	// while

    scratch|=(new_bytes<<scr_msb);        // add new bytes on to big end of scratch
    scr_msb += bits_got;
    subs_part = scratch & subs_mask[prec];
    scratch   = scratch >> subs_len;
    scr_msb  -= subs_len;

    t_time->subsec = subs_part;		// !!! make sure this is in proper precision
#if (DBG_FL & 0x0010)
    printf("subs_part = %0d | ", subs_part);
    print_rtct(t_time);
    printf(": subspart\n");
#endif
  }	// subs_len


  if (time_len) {			// type_struct->field_flags & TIME_FL
    need_bits  = time_len - scr_msb;	// how many more bits do we need?
    need_bytes = need_bits / 8;
    if (need_bits % 8) need_bytes++;	// if any bits left over, get the next byte

    new_bytes = 0;
    bits_got = 0;			// bits processed each field
    while(need_bytes) {			// pull bytes from payload
      new_bytes |= (payload[bytes_read] << bits_got);
      bits_got+=8;
      need_bytes--;
      bytes_read++;			// if we know payload length could compare
      //scr_msb += 8;			// have 8 more bits in new_bytes
    }	// need_bytes

    scratch|=(new_bytes<<scr_msb);        // add new bytes on to big end of scratch
    scr_msb += bits_got;
    time_part = scratch & TIME_MASK;
    scratch   = scratch >> time_len;
    scr_msb  -= time_len;

    //  parse hour, minute, second out of time_part
    t_time->sec = (int)(time_part >> SECOND_SHIFT) & SECOND_MASK;
    t_time->min = (int)(time_part >> MINUTE_SHIFT) & MINUTE_MASK;
    t_time->hr  = (int)(time_part >> HOUR_SHIFT)   & HOUR_MASK;  
#if (DBG_FL & 0x0010)
    printf("time_part = 0x%0X | ", time_part);
    print_rtct(t_time);
    printf(": timepart\n");
#endif
  }	// time_len

  if (date_len) {			// type_struct->field_flags & DATE_FL
    need_bits  = date_len - scr_msb;	// how many more bits do we need?
    need_bytes = need_bits / 8;
    if (need_bits % 8) need_bytes++;	// if any bits left over, get the next byte

    bits_got  = 0;			// bits processed each field
    new_bytes = 0;
    while(need_bytes) {			// pull bytes from payload
      new_bytes |= payload[bytes_read] << bits_got;
      bits_got+=8;
      need_bytes--;
      bytes_read++;			// if we know payload length could compare
      //scr_msb += 8;			// have 8 more bits in new_bytes
    }

    scratch|=(new_bytes<<scr_msb);        // add new bytes on to big end of scratch
    scr_msb += bits_got;
    date_part = scratch & DATE_MASK;
    scratch   = scratch >> date_len;
    scr_msb  -= date_len;

    // parse year, month, day out of date_part
    t_time->day = (int)(date_part >> DAY_SHIFT)+1   & DAY_MASK;
    t_time->mon = (int)(date_part >> MONTH_SHIFT)+1 & MONTH_MASK;
    t_time->yr 	= (int)(date_part >> YEAR_SHIFT)    & YEAR_MASK;

  }	// date_len

#if (DBG_FL /*& 0x0010*/)
  printf("date_part = 0x%0X | ", date_part);
  print_rtct(t_time);
  printf(": all of time struct\n");
#endif

  // !!!!!!!!!!!!!!!!!!!!!!!!!!!!
  // !!! At this point we could check to see that what is left
  // !!! matches type_struct->ttype_val;
#if (DBG_FL)
  if (unpack_err) {
    printf ("End of unpack, unpack_err %04X\n", unpack_err);
  }
#endif
  return unpack_err;

}







