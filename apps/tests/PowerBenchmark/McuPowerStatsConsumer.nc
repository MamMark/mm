/* McuPowerStatsConsumer
 * Used by applications to trigger power state summary calculations
 * and to fetch the results.
 *
 * @author John Lee Jacobs <johnj@soe.ucsc.edu>
 */

#include "McuPowerStats.h"

interface McuPowerStatsConsumer {
	event void statsUpdated(mcustat_t *stats, bool updates);
	command void updateStats();
}
