/* McuPowerStatsP
 * Implementation of power stats buffering and summary calculation module.
 * Provides a consumer interface (for use by applications) and
 * a producer interface (for use by the McuSleepC module).
 */

#include "McuPowerStats.h"

module McuPowerStatsP {
	provides interface McuPowerStatsProducer;
	provides interface McuPowerStatsConsumer;
	uses interface LocalTime<TMilli> as LocalTime;
	uses interface BigQueue<mcustat_entry_t> as Queue;
}

implementation {
	// keep track of the "current" (i.e., most recent) power state to avoid superfluous inserts of duplicate states
	mcu_power_t curstate;

	// whether the statistics table needs to be initialized
        bool init = TRUE;

	// a copy of the entry at the top of the queue
	mcustat_entry_t lastentry;

	// the statistics table
	mcustat_t stats[MCUSTATS_NUM_STATS];

	// whether or not the statistics table has changed since the last call to updateStats
        bool hasUpdates = FALSE;


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
}


