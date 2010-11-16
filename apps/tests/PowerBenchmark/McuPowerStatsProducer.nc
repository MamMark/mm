/* McuPowerStatsConsumer
 * Used by McuSleepC to record power state changes.
 *
 * @author John Lee Jacobs <johnj@soe.ucsc.edu>
 */

#include "McuPowerStats.h"

interface McuPowerStatsProducer {
	async command error_t putState(mcu_power_t newstate);
}
