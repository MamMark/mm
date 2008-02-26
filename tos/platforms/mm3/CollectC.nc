/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

//#include "hardware.h"
//#include "sensors.h"

configuration CollectC {
  provides interface Collect;
}

implementation {
  components CollectP, MainC;
  Collect = CollectP;
  MainC.SoftwareInit -> CollectP;
}
