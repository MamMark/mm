/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

//#include "hardware.h"

configuration mm3PwrC {
  provides interface mm3Pwr[uint8_t client_id];
}

implementation {
  components mm3PwrP;

  mm3Pwr = mm3PwrP;
}
