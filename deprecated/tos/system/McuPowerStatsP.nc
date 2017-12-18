/* McuPowerStatsP
 * Implementation of power stats buffering and summary calculation module.
 * Provides a consumer interface (for use by applications) and
 * a producer interface (for use by the McuSleepC module).
 */

#include "McuPowerStats.h"

module McuPowerStatsP {
	provides {
		interface McuPowerStatsProducer;
		interface McuPowerStatsConsumer;
		interface Init;
	}
	uses {
		interface LocalTime<TMilli> as LocalTime;
		interface BigQueue<mcustat_entry_t> as Queue;
		interface StreamStorageWrite as SSW;
		interface Panic;
	}
}

implementation {
	// most recent power state; avoid superfluous inserts of duplicate states
	mcu_power_t curstate_mcu;

	gpsc_state_t curstate_gps;

	uint8_t curstate_adc;
	uint8_t curstate_vref;
	uint8_t curstate_vdiff;

	comm_state_t curstate_comm;

	// whether the statistics table needs to be initialized
        bool init = TRUE;

	// a copy of the entry at the top of the queue
	mcustat_entry_t lastentry;

	// the statistics table
	mcustat_t stats[MCUSTATS_NUM_STATS];

	// whether or not the statistics table has changed since the last call to updateStats
        bool hasUpdates = FALSE;

	// stream storage management struct
	dc_control_t dcc;

	command error_t Init.init() {
		dcc.majik_a = DC_MAJIK_A;
		dcc.handle = NULL;
		dcc.cur_buf = NULL;
		dcc.cur_ptr = NULL;
		dcc.remaining = 0;
		dcc.chksum  = 0;
		dcc.seq = 0;
		dcc.majik_b = DC_MAJIK_B;
		return SUCCESS;
	}

	// command used by McuSleepC to insert state changes into the queue
	async command error_t McuPowerStatsProducer.putState(mcu_power_t newstate) {
		mcustat_entry_t newentry;
		atomic {
			if (newstate == curstate) {
				return SUCCESS;
			}
		}
		newentry.state = newstate;
		newentry.timestamp = call LocalTime.get();
		atomic {
			if ((call Queue.enqueue(newentry)) == FAIL) {
				return FAIL;
			}
		}
		curstate = newstate;
		return SUCCESS;
	}

	// internal function, used to fetch first entry from the queue
	error_t getState(mcustat_entry_t *getstate) {
		if (!(getstate) || (call Queue.empty())) {
			return FAIL;
		}

		*getstate = call Queue.dequeue();
		return SUCCESS;
	}

	// command used by the application to update statistics table
	// causes queue to be drained, and all fields of statistics table updated
	// for each power state that currently has an entry in the queue
	// signals statsUpdated() event back to the application at the end of execution
	command void McuPowerStatsConsumer.updateStats() {
		mcustat_entry_t nextstate;

		while (getState(&nextstate) != FAIL) {
			mcu_power_t prevstate = 0;
			uint32_t elapsed = 0;
			hasUpdates = TRUE;
			
			// measure time since the previous entry
			// if this is the first entry encountered, set this to zero
                        if (init) {
				int i;
				// zero out the stats table
				bzero(stats, MCUSTATS_NUM_STATS*sizeof(mcustat_entry_t));
				for (i = 0; i < MCUSTATS_NUM_STATS; i++) {
					stats[i].state = i;
				}
				atomic {
					// assume we always start in state 0 (ACTIVE) ?
					prevstate = 0;
					elapsed = 0;
					init = FALSE;
				}
			}
			else {
				atomic {
					elapsed = nextstate.timestamp - lastentry.timestamp;
					prevstate = lastentry.state;
				}
			}

			stats[prevstate].total += elapsed;
			stats[prevstate].count++;
			stats[prevstate].lastupdate = lastentry.timestamp;
			if (elapsed < stats[prevstate].min) {
				stats[prevstate].min = elapsed;
			}
			if (elapsed > stats[prevstate].max) {
				stats[prevstate].max = elapsed;
			}

			lastentry.state = nextstate.state;
			lastentry.timestamp = nextstate.timestamp;
		}
		signal McuPowerStatsConsumer.statsUpdated(stats, hasUpdates);
                hasUpdates = FALSE;
	}

	command void McuPowerStatsConsumer.Record(uint8_t *data, uint16_t dlen) {
		uint16_t num_copied, i;
		if (dcc.majik_a != DC_MAJIK_A || dcc.majik_b != DC_MAJIK_B)
			call Panic.reboot(PANIC_SS, 2, dcc.majik_a, dcc.majik_b, 0, 0);
		if (dcc.remaining > DC_BLK_SIZE)
			call Panic.reboot(PANIC_SS, 3, dcc.remaining, 0, 0, 0);

		while (dlen > 0) {
			if (dcc.cur_buf == NULL) {
				dcc.handle = call SSW.get_free_buf_handle();
				dcc.cur_ptr = dcc.cur_buf = call SSW.buf_handle_to_buf(dcc.handle);
				dcc.remaining = DC_BLK_SIZE;
				dcc.chksum = 0;
			}
			num_copied = ((dlen < dcc.remaining) ? dlen : dcc.remaining);
			for (i = 0; i < num_copied; i++) {
				dcc.chksum += *data;
				*dcc.cur_ptr = *data;
				dcc.cur_ptr++;
				data++;
			}
			dlen -= num_copied;
			dcc.remaining -= num_copied;
			if (dcc.remaining == 0) {
				dcc.chksum += (dcc.seq & 0xff);
				dcc.chksum += (dcc.seq >> 8);
				(*(uint16_t *) dcc.cur_ptr) = dcc.seq++;
				dcc.cur_ptr += 2;
				(*(uint16_t *) dcc.cur_ptr) = dcc.chksum;
				call SSW.buffer_full(dcc.handle);
				dcc.handle = NULL;
				dcc.cur_buf = NULL;
				dcc.cur_ptr = NULL;
			}
		}
	}
}
