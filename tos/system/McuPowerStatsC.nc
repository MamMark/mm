/* McuPowerStatsC
 * Configuration for the McuPowerStats module.
 *
 * @author John Lee Jacobs <johnj@soe.ucsc.edu>
 */

#include "McuPowerStats.h"

configuration McuPowerStatsC {
	// interface used by McuSleepC to record state changes in the queue
	provides interface McuPowerStatsProducer;
	// interface used by the application to drain the queue, produce stats, and take
	// snapshots of stats table for storage to flash
	provides interface McuPowerStatsConsumer;
}

implementation {
	components McuPowerStatsP;
	components McuSleepC;
	components new BigQueueC(mcustat_entry_t, MCUSTATS_BUFFER_SIZE) as QueueC;
	components HilTimerMilliC;
	components StreamStorageC;

	McuPowerStatsP.Queue -> QueueC;
	McuPowerStatsP.LocalTime -> HilTimerMilliC;
	McuPowerStatsP.SSW -> StreamStorageC;
	McuSleepC.McuPowerStatsProducer -> McuPowerStatsP;

	McuPowerStatsProducer = McuPowerStatsP;
	McuPowerStatsConsumer = McuPowerStatsP;
}
