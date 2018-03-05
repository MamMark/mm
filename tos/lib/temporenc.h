/*
temporenc.h
161112 2300

  specifications at https://temporenc.org/


Components
D Date		year, month, day
T Time		hour, minute, second
S Subsecond	milli, micro, or nano

Precision
millisecond	00
microsecond	01
nanosecond	10
none		11

D	  3 bytes	100	100DDDDD DDDDDDDD DDDDDDDD
T	  3 bytes	1010000	1010000T TTTTTTTT TTTTTTTT
DT	  5 bytes	00	00DDDDDD DDDDDDDD DDDDDDDT TTTTTTTT TTTTTTTT
DTZ	  6 bytes	110	110DDDDD DDDDDDDD DDDDDDDD TTTTTTTT TTTTTTTT TZZZZZZZ
DTS	6-9 bytes	01
	millisecond		01PPDDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TTSSSSSS SSSS0000
	microsecond		01PPDDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TTSSSSSS SSSSSSSS SSSSSS00
	nanosecond		01PPDDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TTSSSSSS SSSSSSSS SSSSSSSS SSSSSSSS
	no value		01PPDDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TT000000

	millisecond	0100	0100DDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TTSSSSSS SSSS0000
	microsecond	0101	0101DDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TTSSSSSS SSSSSSSS SSSSSS00
	nanosecond	0110	0110DDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TTSSSSSS SSSSSSSS SSSSSSSS SSSSSSSS
	no value	0111	0111DDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TT000000

DTSZ   7-10 bytes	111
	millisecond		111PPDDD DDDDDDDD DDDDDDDD DDTTTTTT TTTTTTTT TTTSSSSS SSSSSZZZ ZZZZ0000
	microsecond		111PPDDD DDDDDDDD DDDDDDDD DDTTTTTT TTTSSSSS SSSSSSSS SSSSSSSZ ZZZZZZ00
	nanosecond		111PPDDD DDDDDDDD DDDDDDDD DDTTTTTT TTTSSSSS SSSSSSSS SSSSSSSS SZZZZZZZ
	no value		111PPDDD DDDDDDDD DDDDDDDD DDTTTTTT ZZ000000

	millisecond	11100	11100DDD DDDDDDDD DDDDDDDD DDTTTTTT TTTTTTTT TTTSSSSS SSSSSZZZ ZZZZ0000
	microsecond	11101	11101DDD DDDDDDDD DDDDDDDD DDTTTTTT TTTSSSSS SSSSSSSS SSSSSSSZ ZZZZZZ00
	nanosecond	11110	11110DDD DDDDDDDD DDDDDDDD DDTTTTTT TTTSSSSS SSSSSSSS SSSSSSSS SZZZZZZZ
	no value	11111	11111DDD DDDDDDDD DDDDDDDD DDTTTTTT ZZ000000



Parse tree:
DT	  00xxxxxx	00DDDDDD DDDDDDDD DDDDDDDT TTTTTTTT TTTTTTTT
DTS msec  0100xxxx	0100DDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TTSSSSSS SSSS0000
DTS usec  0101xxxx	0101DDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TTSSSSSS SSSSSSSS SSSSSS00
DTS nsec  0110xxxx	0110DDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TTSSSSSS SSSSSSSS SSSSSSSS SSSSSSSS
DTS none  0111xxxx	0111DDDD DDDDDDDD DDDDDDDD DTTTTTTT TTTTTTTT TT000000
D	  100xxxxx	100DDDDD DDDDDDDD DDDDDDDD
T	  1010000x	1010000T TTTTTTTT TTTTTTTT
DTZ	  110xxxxx	110DDDDD DDDDDDDD DDDDDDDD TTTTTTTT TTTTTTTT TZZZZZZZ
DTSZ msec 11100xxx	11100DDD DDDDDDDD DDDDDDDD DDTTTTTT TTTTTTTT TTTSSSSS SSSSSZZZ ZZZZ0000
DTSZ usec 11101xxx	11101DDD DDDDDDDD DDDDDDDD DDTTTTTT TTTTTTTT TTTSSSSS SSSSSSSS SSSSSSSZ ZZZZZZ00
DTSZ nsec 11110xxx	11110DDD DDDDDDDD DDDDDDDD DDTTTTTT TTTTTTTT TTTSSSSS SSSSSSSS SSSSSSSS SSSSSSSS SZZZZZZZ
DTSZ none 11111xxx	11111DDD DDDDDDDD DDDDDDDD DDTTTTTT TTTTTTTT ZZ000000

Date component (21 bits):
Y YYYY YYYY YYYM MMMD DDDD

Time component (17 bits):
H HHHH MMMM MMSS SSSS

  unsigned int	yr;		//0-4095
  unsigned int	mon;		//0-11
  unsigned int	day;		//0-30
  unsigned int	hr;		//0-23
  unsigned int	min;		//0-59
  unsigned int  sec;		//0-59

*/
/*
  DBG_FL bits
  0x0001 pack	first debug pass, partial_pack
  0x0002 pack       subseconds, tempor_freq
  0x0004 pack
  0x0008
  0x0010 unpack
  0x0020 unpack
  0x0040 unpack
  0x0080
  0x0100
  0x0200
  0x0400
  0x0800
  0x1000
  0x2000
  0x4000
  0x8000	error reporting
 */
#define DBG_FL			0xFFE8

#define	FALSE			0
#define TRUE			1

#define PREC_M			0	//msec	00  4 bits padding
#define PREC_U			1	//usec	01  2 bits padding
#define PREC_N			2	//nsec	10  0 bits padding
#define PREC_0			3	//none	11  6 bits padding

#define TBASE_FREQ		1000	//frequency of system timebase (millisec on tag) !!! not universal

// Some values converted from temporenc.py

// ??? Should I shorten these defines?
// ZONE->Z, DATE->D, TIME->T ...
					// *_EMPTY == *_MASK

#define PREC_M_MAX		   999	// milliseconds precision
#define PREC_M_MASK  	         0x3ff	// 10 bits
#define PREC_M_EMPTY	   PREC_M_MASK
#define PREC_M_SHIFT		    10
#define PREC_M_PADDING		     4

#define PREC_U_MAX		999999	// microseconds precision
#define PREC_U_MASK            0xfffff	// 20 bits
#define PREC_U_EMPTY	   PREC_U_MASK
#define PREC_U_SHIFT		    20
#define PREC_U_PADDING		     2

#define PREC_N_MAX           999999999	// nanoseconds precision
#define PREC_N_MASK         0x3fffffff	// 30 bits
#define PREC_N_EMPTY	   PREC_N_MASK
#define PREC_N_SHIFT		    30
#define PREC_N_PADDING		     0

#define PREC_0_MASK		  0x3f	// no subsecond precision
#define PREC_0_SHIFT		     6	// ??? six bits of padding
#define PREC_0_PADDING		     6

#define SECOND_MAX    		    60	// seconds
#define SECOND_EMPTY  		    63
#define SECOND_MASK   		  0x3f  // 06 bits
#define SECOND_BITS		     6
#define SECOND_SHIFT		     0

#define MINUTE_MAX    		    59	// minutes
#define MINUTE_EMPTY  		    63
#define MINUTE_MASK   		  0x3f  // 06 bits
#define MINUTE_BITS		     6
#define MINUTE_SHIFT	 (SECOND_SHIFT + SECOND_BITS)

#define HOUR_MAX      		    23	// hours
#define HOUR_EMPTY    		    31
#define HOUR_MASK     		  0x1f  // 05 bits
#define HOUR_BITS		     5
#define HOUR_SHIFT	 (MINUTE_SHIFT + MINUTE_BITS)

#define TIME_BITS	 (HOUR_SHIFT+HOUR_BITS)
#if (TIME_BITS != 17)
    ERROR TIME_BITS !!!! // DEBUG ONLY
#endif
#define T_BITS		TIME_BITS
#define TIME_MASK	       0x1FFFF	// 17 bits

#define DAY_MAX	      		    30	// Day of Month
#define DAY_EMPTY     		    31
#define DAY_MASK      		  0x1f  // 05 bits
#define DAY_BITS		     5
#define DAY_SHIFT		     0

					// !!! no Day of Week defined !!!!!!!!!!!!!!!!!

#define MONTH_MAX     		    11	// Month
#define MONTH_EMPTY   		    15
#define MONTH_MASK    		  0x0f  // 04 bits
#define MONTH_BITS		     4
#define MONTH_SHIFT	 (DAY_SHIFT + DAY_BITS)

#define YEAR_MAX		  4094	// year
#define YEAR_EMPTY    	          4095
#define YEAR_MASK     		 0xfff	// 12 bits
#define YEAR_BITS		    12
#define YEAR_SHIFT	 (MONTH_SHIFT + MONTH_BITS)

#define DATE_BITS	 (YEAR_SHIFT+YEAR_BITS)
#if (DATE_BITS != 21)
    ERROR DATE_BITS !!!! // DEBUG ONLY
#endif
#define D_BITS		DATE_BITS
#define DATE_MASK	      0x1FFFFF	// 21 bits

#define ZONE_MAX		   125	// Time Zone
#define ZONE_SPECIAL		   126
#define ZONE_EMPTY		   127  // 15 minutes, goes past 12 hours
#define ZONE_MASK		  0x7f
#define ZONE_BITS		     7
#define Z_BITS		ZONE_BITS

#define T_MASK                 0x1ffff // Time, 17 bits 0x15180 seconds/day
#define D_MASK                0x1fffff // Date, 21 bits
#define Z_MASK                    0x7f // Zone,  7 bits

#define TIME_SHIFT	 (HOUR_SHIFT + HOUR_BITS)
#define DATE_SHIFT	 (YEAR_SHIFT + YEAR_BITS)
#define ZONE_SHIFT	 ZONE_BITS

#define PREC_MSEC		     0	// millisecond precision
#define PREC_USEC		     1	// microsecond precision
#define PREC_NSEC		     2	// nanosecond  precision
#define PREC_NONE		     3	// no subsecond precision

					// Number of bytes for each temporenc type
#define D_LEN			     3
#define T_LEN			     3
#define DT_LEN			     5
#define DTZ_LEN			     6

#define DTSM_LEN		     7	// milliseconds
#define DTSU_LEN		     8	// microseconds
#define DTSN_LEN		     9	// nanoseconds
#define DTS0_LEN	             6  // no subseconds

#define DTSZM_LEN		     8	// milliseconds
#define DTSZU_LEN		     9	// microseconds
#define DTSZN_LEN		    10	// nanoseconds
#define DTSZ0_LEN		     7  // no subseconds

#define DTS_LEN		DTSM_LEN
#define DTSZ_LEN	DTSZM_LEN

  // Error codes and bit flags for error codes

#define ERR_PACK_NSEC_MAX       0x0001
#define ERR_PACK_SEC_MAX        0x0002
#define ERR_PACK_MINUTE_MAX     0x0004
#define ERR_PACK_HOUR_MAX       0x0008
#define ERR_PACK_DAY_MAX        0x0010
#define ERR_PACK_MONTH_MAX      0x0020
#define ERR_PACK_YEAR_MAX       0x0040
#define ERR_SUBSEC_2BIG		0x0080

#define ERR_TEMPORENC_TYPE	0x0100	// temporenc type string had an illegal value
#define ERR_PAYLOAD_LEN		0x0200  // payload should be an even number of bytes

#define ERR_NULL_PTR            0x8000

#define ERR_BAD_TEMPRN_TYPE	0x0001	// illegal combination of bits at start of payload


  // bit flags in mask for describing which temporenc types are active
  // used in this implementation, not from python

#define DATE_FL		0x8
#define TIME_FL		0x4
#define SUBS_FL		0x2
#define ZONE_FL		0x1


#define DT_FL    (DATE_FL | TIME_FL                     )
#define DTS_FL   (DATE_FL | TIME_FL | SUBS_FL           )
#define DTSM_FL  (DATE_FL | TIME_FL | SUBS_FL           )
#define DTSU_FL  (DATE_FL | TIME_FL | SUBS_FL           )
#define DTSN_FL  (DATE_FL | TIME_FL | SUBS_FL           )
#define DTS0_FL  (DATE_FL | TIME_FL | SUBS_FL           )
#define D_FL     (DATE_FL  	                        )
#define T_FL     (          TIME_FL 	                )
#define DTZ_FL   (DATE_FL | TIME_FL |	        ZONE_FL )
#define DTSZ_FL  (DATE_FL | TIME_FL | SUBS_FL | ZONE_FL )
#define DTSZM_FL (DATE_FL | TIME_FL | SUBS_FL | ZONE_FL )
#define DTSZU_FL (DATE_FL | TIME_FL | SUBS_FL | ZONE_FL )
#define DTSZN_FL (DATE_FL | TIME_FL | SUBS_FL | ZONE_FL )
#define DTSZ0_FL (DATE_FL | TIME_FL | SUBS_FL | ZONE_FL )

/*
  This enum indexes into the tenc_type array.
  These values are used to specify the type and precsion
  of the temporenc output.
  Use BAD_IDX at end to check for out of bounds
 */

enum tenc_idx { DT_IDX, DTS_IDX, DTSM_IDX, DTSU_IDX, DTSN_IDX, DTS0_IDX,
		D_IDX, T_IDX,
		DTZ_IDX, DTSZ_IDX, DTSMZ_IDX, DTSUZ_IDX, DTSNZ_IDX, DTS0Z_IDX,
		BAD_IDX};

//##################################################################
//
// define structures and types
//
//##################################################################

// default integer types, set to optimize for hardware

#define DEF_UINT	uint16_t
#define DEF_INT		int16_t
/*
  RTC Time does not map directly onto the driverlib RTC_C_Calendar type.
  Nor does it map onto the time structures used by temporenc
  !!! making the structure compatible with temporence will involve
  !!! adding fields for nanosecond, time zone, precision etc.
  !!! or converting subsec to 32 bits
  !!! currently the subsecond field only goes down to mSec
  !!! where temporenc goes down to nSec
  !!! We currently read time from the 32 KHz clock (J32 jiffies)

 */
typedef struct _RTCTime {
  uint16_t	yr;
  uint8_t	mon;
  uint8_t	day;	// day of month not dow
  uint8_t	hr;
  uint8_t	min;
  uint8_t	sec;
  uint32_t	subsec;	// should this be 32k jiffies for efficiency?
}RTCTime;



typedef struct _temporenc_type {
  uint8_t      	field_flags;	// which fields are present: Date, Time, Subsec, Zone
  char          name[6];        // string of type name
  uint8_t	tt_bitlen;	// number of bits in type identifier in packed structure
  uint8_t	ttype_val;	// left shifted type value
  uint8_t	ttype_part;	// right shifted type part
  uint8_t	tt_bitmask;	// left shifted mask
  uint8_t	byte_len;	// number of bytes full structure takes
  uint32_t	freq;		// subsecond clock frequency
  uint8_t	pad_bits;	// number of bits of padding
  uint8_t	zone_bits;	//  bits		??? may not be needed
  uint8_t	subs_bits;	// subsecond bits
  uint8_t	time_bits;	//  bits		??? may not be needed
  uint8_t	date_bits;	//  bits		??? may not be needed
}tenc_type;

/*
  The stream structure is for adding data to a byte stream.
  Data will be right shifted off the least significant byte
  one byte at a time.
  We need to keep track of how bytes are in the byte stream payload.
 */

typedef struct byte_stream_s {
  uint64_t		data_src;	// bitwise data to put in byte stream payload
  int			src_bits;	// number of bits of data (left) in src
  uint8_t		*payload;	// output byte stream
  int			payld_bytes;	// num of bytes in payload
}b_stream;

//*******************************
//
// Function declarations
//
//*******************************
int tag_pack                           (int type_idx,  uint8_t* payload, RTCTime *t_time );
int temporenc_pack  (uint32_t inp_freq, int *payld_len, int type_idx,  uint8_t* payload, RTCTime *t_time );
int tag_unpack                   (int payld_len, uint8_t* payload, RTCTime *t_time );

int temporenc_unpack (uint32_t inp_freq, int payld_len, uint8_t* payload, RTCTime *t_time );
