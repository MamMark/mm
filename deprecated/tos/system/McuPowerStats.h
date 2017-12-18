#ifndef MCUPOWERSTATS_H
#define MCUPOWERSTATS_H
#define MCUSTATS_BUFFER_SIZE 1024

#define MCUSTATS_NUM_STATS 3+13

// special "state" value used to indicate a test packet over the serial link
#define STATE_TEST 0xF0
// special "state" value used to indicate EOM in the log and over the serial link
#define STATE_END 0xFF

// this is what goes into the queue; just a state value and a timestamp
typedef struct mcustat_entry_t {
	mcu_power_t state;
	uint32_t timestamp;
} mcustat_entry_t;

// this is what is recorded in the "statistics" table
//     3 states for the MCU:  ACTIVE, LPM1, LPM3
//     how many states for sirf3_GPS?   c.f. tos/chips/sirf3/SirfP.nc
//     how many states for ADC?         c.f. tos/mm/AdcP.nc : Adc_Power_Up_Down()
//     how many states for uart1?       c.f. tos/comm/mmCommSwP.nc
//     how many states for uart0?       c.f. tos/platforms/mm3/misc/Hpl_MM_hw.nc USE THIS!!!!!

typedef nx_struct mcustat {
	nx_uint8_t state;      // power state
	nx_uint32_t lastupdate;// timestamp of last update to this entry
	nx_uint32_t count;     // count of updates to this entry
	nx_uint32_t min;       // minimum time spent in this state
	nx_uint32_t max;       // maximum time spent in this state
	nx_uint32_t total;     // total time spent in this state
} mcustat_t;

enum {
  AM_MCUSTAT = 0x89,
};

#endif
