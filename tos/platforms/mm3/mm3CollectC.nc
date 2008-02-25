/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

//#include "hardware.h"
//#include "sensors.h"

configuration mm3CollectC {
  provides interface mm3Collect;
}

implementation {
  components mm3CollectP, MainC;
  mm3Collect = mm3CollectP;
  MainC.SoftwareInit -> mm3CollectP;
}
